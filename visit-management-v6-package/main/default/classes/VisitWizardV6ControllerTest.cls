@IsTest
private class VisitWizardV6ControllerTest {
    @IsTest
    static void launchContextReturnsAccountDefaults() {
        Account accountRecord = new Account(Name = 'V6 Launch Account');
        insert accountRecord;

        Test.startTest();
        VisitWizardV6Controller.LaunchContext context =
            VisitWizardV6Controller.getLaunchContext(String.valueOf(accountRecord.Id));
        Test.stopTest();

        System.assertEquals('NEW', context.mode);
        System.assertEquals(accountRecord.Id, context.accountId);
        System.assertNotEquals(null, context.recordTypes);
        System.assertNotEquals(null, context.visitorCandidates);
    }

    @IsTest
    static void saveResumeTasksOpportunityAndComplete() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'V6 Save Account');
        insert accountRecord;
        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'V6 Attendee',
            Email = 'v6-attendee@example.com'
        );
        insert contactRecord;

        Id recordTypeId = defaultVisitRecordTypeId();
        Id locationId = createLocation();
        System.assertNotEquals(null, recordTypeId, 'A Visit record type should be available for the V6 test.');
        System.assertNotEquals(null, locationId, 'A Location should be available for Visit.PlaceId.');

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => accountRecord.Id,
            'recordTypeId' => recordTypeId,
            'visitorUserIds' => new List<String>{ UserInfo.getUserId() },
            'visitedContactIds' => new List<String>{ String.valueOf(contactRecord.Id) },
            'resumePage' => 'Visitors',
            'stateJson' => '{"resume":"Visitors"}',
            'validateRequired' => true,
            'visitFields' => new Map<String, Object>{
                'AccountId' => accountRecord.Id,
                'PlaceId' => locationId,
                'PlannedVisitStartTime' => System.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
                'PlannedVisitEndTime' => System.now().addDays(1).addHours(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
                'VisitPriority' => 'Medium'
            }
        };

        VisitWizardV6Controller.SaveResponse saveResponse =
            VisitWizardV6Controller.saveForLater(JSON.serialize(payload));
        VisitWizardV6Controller.LaunchContext resumeContext =
            VisitWizardV6Controller.getLaunchContext(String.valueOf(saveResponse.visitId));

        System.assertNotEquals(null, saveResponse.visitId);
        System.assertNotEquals(null, saveResponse.visitName);
        System.assertEquals('Visitors', saveResponse.resumePage);
        System.assertEquals('EDIT', resumeContext.mode);
        System.assertEquals(saveResponse.visitName, resumeContext.visitName);
        System.assertEquals(accountRecord.Id, resumeContext.accountId);
        System.assertEquals('InProgress', resumeContext.visitStatus);
        System.assertEquals(1, resumeContext.selectedVisitors.size());
        System.assertEquals(1, resumeContext.selectedContacts.size());

        if (hasObjects(new Set<String>{ 'ActionPlan' })) {
            VisitWizardController.ActionPlanStartInfo actionPlanStartInfo =
                VisitWizardV6Controller.getActionPlanStartInfo(saveResponse.visitId);
            if (hasPicklistOption(actionPlanStartInfo.statusOptions, 'In Progress')) {
                System.assertEquals('In Progress', actionPlanStartInfo.defaultStatus);
            }
        }

        if (canCreateGenericVisitTask()) {
            VisitWizardV6Controller.TaskListResponse customTopicResponse =
                VisitWizardV6Controller.createCustomTopic(JSON.serialize(new Map<String, Object>{
                    'visitId' => saveResponse.visitId,
                    'name' => 'Customer-created Topic',
                    'description' => 'Created from the V6 New Topic action',
                    'required' => false
                }));
            System.assert(
                taskNamed(customTopicResponse.tasks, 'Customer-created Topic'),
                'The V6 New Topic action should create a Generic Visit Task tied to the Visit.'
            );
        }

        Id taskId = createGenericVisitTask(saveResponse.visitId, true);
        if (taskId != null) {
            String taskStartDateTime = System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            String taskEndDateTime = System.now().addHours(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            VisitWizardV6Controller.TaskListResponse started =
                VisitWizardV6Controller.startTask(saveResponse.visitId, null, taskId);
            System.assert(!started.tasks.isEmpty(), 'The started task list should include the test Generic Visit Task.');
            VisitWizardV6Controller.TaskListResponse restarted =
                VisitWizardV6Controller.startTask(saveResponse.visitId, null, taskId);
            System.assert(!restarted.tasks.isEmpty(), 'Starting an already in-progress task should reopen without another status write.');

            if (hasObjects(new Set<String>{ 'ContentNote', 'ContentDocumentLink' })) {
                try {
                    VisitWizardV6Controller.saveTask(JSON.serialize(new Map<String, Object>{
                        'visitId' => saveResponse.visitId,
                        'genericTaskId' => taskId,
                        'description' => 'Completed without a note',
                        'startDateTime' => taskStartDateTime,
                        'endDateTime' => taskEndDateTime,
                        'complete' => true
                    }));
                    System.assert(false, 'Expected task completion to require a note.');
                } catch (AuraHandledException e) {
                    System.assert(e.getMessage().contains('note'), 'The error should explain that a note is required.');
                }

                List<VisitWizardV6Controller.NoteSummary> notes =
                    VisitWizardV6Controller.saveTaskNote(JSON.serialize(new Map<String, Object>{
                        'genericTaskId' => taskId,
                        'title' => 'V6 Task Note',
                        'body' => '<p>Rich visit task note</p>'
                    }));
                List<VisitWizardV6Controller.NoteSummary> reloadedNotes =
                    VisitWizardV6Controller.getTaskNotes(taskId);

                System.assert(!notes.isEmpty(), 'The saved enhanced note should be returned.');
                System.assert(!reloadedNotes.isEmpty(), 'The enhanced note should reload from the task.');
                System.assert(reloadedNotes[0].body.contains('Rich visit task note'), 'The rich note body should be preserved.');
            }

            VisitWizardV6Controller.TaskListResponse completed =
                VisitWizardV6Controller.saveTask(JSON.serialize(new Map<String, Object>{
                    'visitId' => saveResponse.visitId,
                    'genericTaskId' => taskId,
                    'description' => 'Completed in test',
                    'startDateTime' => taskStartDateTime,
                    'endDateTime' => taskEndDateTime,
                    'complete' => true
                }));
            SObject savedTask = Database.query(
                'SELECT Status, Description FROM GenericVisitTask WHERE Id = :taskId LIMIT 1'
            );
            VisitWizardV6Controller.LaunchContext review =
                VisitWizardV6Controller.getReview(saveResponse.visitId, null);
            VisitWizardV6Controller.SaveResponse completeResponse =
                VisitWizardV6Controller.completeVisit(saveResponse.visitId, null);

            System.assertEquals(true, completed.requiredTasksComplete);
            System.assertEquals('Completed', savedTask.get('Status'));
            System.assertEquals('Completed in test', savedTask.get('Description'));
            System.assert(!review.tasks.isEmpty(), 'The review should show the task snapshot.');
            System.assertEquals('Visit completed.', completeResponse.message);
        }

        if (Opportunity.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            VisitWizardV6Controller.OpportunityDefaults defaults =
                VisitWizardV6Controller.getOpportunityDefaults(saveResponse.visitId);

            System.assertEquals(accountRecord.Id, defaults.accountId);
            System.assert(String.isNotBlank(defaults.stageName), 'Opportunity defaults should still provide a stage.');
        }
    }

    @IsTest
    static void visitedPartySaveHandlesRemovedCreatedContactState() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'V6 Visited Party Account');
        insert accountRecord;
        Contact createdThenRemovedContact = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'V6 Created Then Removed',
            Email = 'v6-created-removed@example.com'
        );
        Contact existingContact = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'V6 Existing Party',
            Email = 'v6-existing-party@example.com'
        );
        insert new List<Contact>{ createdThenRemovedContact, existingContact };

        Id recordTypeId = defaultVisitRecordTypeId();
        Id locationId = createLocation();
        System.assertNotEquals(null, recordTypeId, 'A Visit record type should be available.');
        System.assertNotEquals(null, locationId, 'A Location should be available for Visit.PlaceId.');

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => accountRecord.Id,
            'recordTypeId' => recordTypeId,
            'visitorUserIds' => new List<String>{ UserInfo.getUserId() },
            'visitedContactIds' => new List<String>{
                String.valueOf(createdThenRemovedContact.Id),
                String.valueOf(createdThenRemovedContact.Id),
                String.valueOf(existingContact.Id)
            },
            'resumePage' => 'VisitedParties',
            'stateJson' => '{"resume":"VisitedParties"}',
            'validateRequired' => true,
            'visitFields' => new Map<String, Object>{
                'AccountId' => accountRecord.Id,
                'PlaceId' => locationId,
                'PlannedVisitStartTime' => System.now().addDays(3).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
                'PlannedVisitEndTime' => System.now().addDays(3).addHours(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
                'VisitPriority' => 'Medium'
            }
        };

        Test.startTest();
        VisitWizardV6Controller.SaveResponse created =
            VisitWizardV6Controller.saveVisitProgress(JSON.serialize(payload));
        payload.put('visitId', created.visitId);
        payload.put('resumePage', 'ActionPlan');
        payload.put('visitedContactIds', new List<String>{
            String.valueOf(existingContact.Id),
            String.valueOf(existingContact.Id)
        });
        VisitWizardV6Controller.SaveResponse updated =
            VisitWizardV6Controller.saveVisitProgress(JSON.serialize(payload));
        Test.stopTest();

        List<SObject> rows = visitedPartyRows(updated.visitId);
        System.assertEquals(1, rows.size(), 'Removing one visited party and adding an existing contact should save one row.');
        System.assertEquals(existingContact.Id, (Id) rows[0].get('ContactId'));
        if (VisitWizardV6Controller.hasField('VisitedParty', 'IsPrimaryContact')) {
            System.assertEquals(1, primaryVisitedPartyCount(rows), 'The saved visited party should be the single primary contact.');
        }
        System.assertEquals(1, VisitWizardV6Controller.uniqueIdsPreserveOrder(new List<Id>{ existingContact.Id, existingContact.Id }).size());
        System.assert(
            VisitWizardV6Controller.firstExceptionMessage(new TestSqlException('ORA-01427: single-row subquery returns more than one row')).contains('Visited parties'),
            'The raw database error should be converted to a visited-party message.'
        );
    }

    @IsTest
    static void validationErrorsAreReadable() {
        Account accountRecord = new Account(Name = 'V6 Validation Account');
        insert accountRecord;

        Test.startTest();
        try {
            VisitWizardV6Controller.saveForLater(JSON.serialize(new Map<String, Object>()));
            System.assert(false, 'Expected an Account validation error.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account'));
        }

        try {
            VisitWizardV6Controller.createOpportunity(JSON.serialize(new Map<String, Object>()));
            System.assert(false, 'Expected an Opportunity validation error.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visit'));
        }

        try {
            VisitWizardV6Controller.getOpportunityDefaults(null);
            System.assert(false, 'Expected Opportunity default Visit validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visit Id'));
        }

        try {
            VisitWizardV6Controller.createOpportunity(JSON.serialize(new Map<String, Object>{
                'visitId' => accountRecord.Id,
                'accountId' => accountRecord.Id,
                'closeDate' => String.valueOf(Date.today().addDays(30))
            }));
            System.assert(false, 'Expected Opportunity required field validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Opportunity Name'));
        }

        try {
            VisitWizardV6Controller.saveTaskNote(JSON.serialize(new Map<String, Object>()));
            System.assert(false, 'Expected note task validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Task Id'));
        }

        try {
            VisitWizardV6Controller.saveTaskNote(JSON.serialize(new Map<String, Object>{
                'genericTaskId' => UserInfo.getUserId(),
                'body' => '<p>&nbsp;</p>'
            }));
            System.assert(false, 'Expected note body validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('note content'));
        }

        try {
            VisitWizardV6Controller.completeVisit(null, null);
            System.assert(false, 'Expected complete Visit Id validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visit Id'));
        }
        Test.stopTest();
    }

    @IsTest
    static void lightweightWrappersAndTopicErrorsAreReadable() {
        Account accountRecord = new Account(Name = 'V6 Wrapper Account');
        insert accountRecord;
        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'V6 Wrapper Contact',
            Email = 'v6-wrapper@example.com'
        );
        insert contactRecord;

        Id recordTypeId = defaultVisitRecordTypeId();

        Test.startTest();
        VisitWizardV6Controller.LaunchContext newContext = VisitWizardV6Controller.getLaunchContext(null);
        VisitWizardV6Controller.LaunchContext unsupportedContext =
            VisitWizardV6Controller.getLaunchContext(String.valueOf(UserInfo.getUserId()));
        VisitWizardController.AccountInfo accountInfo = VisitWizardV6Controller.getAccountInfo(accountRecord.Id);
        List<VisitWizardController.UserCandidate> userResults =
            VisitWizardV6Controller.searchUsers(UserInfo.getName(), new List<Id>());
        List<VisitWizardController.ContactCandidate> contactResults =
            VisitWizardV6Controller.searchContacts(accountRecord.Id, 'Wrapper', new List<Id>());
        List<VisitWizardController.AddressCandidate> addressResults =
            VisitWizardV6Controller.searchAccountAddresses(accountRecord.Id, '');
        VisitWizardV6Controller.TaskListResponse emptyTasks = VisitWizardV6Controller.getTaskList(null, null);
        if (recordTypeId != null) {
            System.assertNotEquals(null, VisitWizardV6Controller.getVisitFieldMetadata(recordTypeId));
        }
        System.assertNotEquals(null, VisitWizardV6Controller.getInitialVisitorCandidates(accountRecord.Id));

        try {
            VisitWizardV6Controller.saveActionPlanAndLoadTasks(JSON.serialize(new Map<String, Object>()));
            System.assert(false, 'Expected Meeting Template Visit validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visit Id'));
        }

        try {
            VisitWizardV6Controller.createCustomTopic(JSON.serialize(new Map<String, Object>()));
            System.assert(false, 'Expected Topic Visit validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visit Id'));
        }

        try {
            VisitWizardV6Controller.createCustomTopic(JSON.serialize(new Map<String, Object>{
                'visitId' => accountRecord.Id
            }));
            System.assert(false, 'Expected Topic Name validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Topic Name'));
        }
        Test.stopTest();

        System.assertEquals('NEW', newContext.mode);
        System.assertEquals('NEW', unsupportedContext.mode);
        System.assertEquals(accountRecord.Name, accountInfo.name);
        System.assertNotEquals(null, userResults);
        System.assertNotEquals(null, addressResults);
        System.assert(!contactResults.isEmpty(), 'The wrapper contact should be found by contact search.');
        System.assertEquals(true, emptyTasks.requiredTasksComplete);
    }

    @IsTest
    static void publicWrappersCoverLookupProgressOpportunityAndActionPlanBranches() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'V6 Lookup Progress Account');
        insert accountRecord;
        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'V6 Lookup Contact',
            Email = 'v6-lookup@example.com'
        );
        insert contactRecord;

        Id recordTypeId = defaultVisitRecordTypeId();
        Id locationId = createLocation();
        Id addressId = createAccountAddress(accountRecord.Id);
        System.assertNotEquals(null, recordTypeId, 'A Visit record type should be available.');
        System.assertNotEquals(null, locationId, 'A Location should be available for Visit.PlaceId.');

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => accountRecord.Id,
            'recordTypeId' => recordTypeId,
            'visitorUserIds' => new List<String>{ UserInfo.getUserId() },
            'visitedContactIds' => new List<String>{ String.valueOf(contactRecord.Id) },
            'resumePage' => 'VisitDetails',
            'stateJson' => '{"resume":"VisitDetails"}',
            'validateRequired' => true,
            'visitFields' => new Map<String, Object>{
                'AccountId' => accountRecord.Id,
                'PlaceId' => locationId,
                'PlannedVisitStartTime' => System.now().addDays(2).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
                'PlannedVisitEndTime' => System.now().addDays(2).addHours(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
                'VisitPriority' => 'Medium'
            }
        };

        Test.startTest();
        List<VisitWizardController.AccountCandidate> accounts =
            VisitWizardV6Controller.searchAccounts('V6 Lookup Progress');
        List<VisitWizardController.AddressCandidate> addresses =
            VisitWizardV6Controller.searchAddresses('Visit Wizard');
        List<VisitWizardController.AddressCandidate> accountAddresses =
            VisitWizardV6Controller.searchAccountAddresses(accountRecord.Id, 'Visit Wizard');
        VisitWizardController.AddressCandidate defaultAddress =
            VisitWizardV6Controller.getDefaultAccountAddress(accountRecord.Id);
        VisitWizardController.AddressCandidate addressInfo =
            addressId == null ? null : VisitWizardV6Controller.getAddressInfo(addressId);
        Map<String, String> contactRecordTypeDescriptions =
            VisitWizardV6Controller.getContactRecordTypeDescriptions();

        VisitWizardV6Controller.SaveResponse created =
            VisitWizardV6Controller.saveVisitProgress(JSON.serialize(payload));
        payload.put('visitId', created.visitId);
        payload.put('resumePage', 'VisitedParties');
        payload.put('stateJson', '{"resume":"VisitedParties"}');
        payload.put('visitedContactIds', new List<String>());
        VisitWizardV6Controller.SaveResponse updated =
            VisitWizardV6Controller.saveVisitProgress(JSON.serialize(payload));

        Map<String, Object> defaultingPayload = new Map<String, Object>(payload);
        defaultingPayload.remove('visitId');
        defaultingPayload.remove('recordTypeId');
        defaultingPayload.remove('visitorUserIds');
        defaultingPayload.put('visitedContactIds', new List<String>());
        VisitWizardV6Controller.SaveResponse defaulted =
            VisitWizardV6Controller.saveVisitProgress(JSON.serialize(defaultingPayload));

        VisitWizardV6Controller.OpportunitySummary opportunitySummary = null;
        if (Opportunity.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            opportunitySummary = VisitWizardV6Controller.createOpportunity(JSON.serialize(new Map<String, Object>{
                'visitId' => created.visitId,
                'accountId' => accountRecord.Id,
                'name' => 'V6 Visit Opportunity',
                'closeDate' => String.valueOf(Date.today().addDays(30)),
                'amount' => '2500',
                'type' => 'New Business',
                'description' => 'Created from V6 test coverage'
            }));
        }

        Id templateVersionId = createActionPlanTemplateVersion();
        if (templateVersionId != null) {
            VisitWizardController.testActionPlanTemplateVersionForVisit =
                publishedTemplateVersionStub(templateVersionId);
        }
        Id actionPlanId;
        VisitWizardV6Controller.TaskListResponse actionPlanTasks = null;
        if (templateVersionId != null) {
            actionPlanTasks = VisitWizardV6Controller.saveActionPlanAndLoadTasks(JSON.serialize(new Map<String, Object>{
                'visitId' => created.visitId,
                'name' => 'Created V6 Meeting Template',
                'startDate' => String.valueOf(Date.today()),
                'actionPlanTemplateVersionId' => templateVersionId,
                'status' => 'In Progress',
                'stateJson' => '{"resume":"Tasks"}'
            }));
            actionPlanId = actionPlanTasks.actionPlanId;
            actionPlanTasks = VisitWizardV6Controller.saveActionPlanAndLoadTasks(JSON.serialize(new Map<String, Object>{
                'visitId' => created.visitId,
                'actionPlanId' => actionPlanId,
                'name' => 'Updated V6 Meeting Template',
                'status' => 'In Progress',
                'stateJson' => '{"resume":"Tasks"}'
            }));
        }
        if (actionPlanId == null) {
            actionPlanId = createActionPlan(created.visitId);
        }
        if (actionPlanId != null) {
            VisitWizardV6Controller.getReview(created.visitId, actionPlanId);
        }
        Id taskId = createGenericVisitTask(created.visitId, true);
        Id actionPlanItemId = actionPlanId == null || taskId == null ? null : createActionPlanItem(actionPlanId, taskId);
        if (actionPlanItemId != null && taskId != null) {
            VisitWizardV6Controller.startTask(created.visitId, actionPlanItemId, taskId);
        }
        if (taskId != null) {
            try {
                VisitWizardV6Controller.completeVisit(created.visitId, actionPlanId);
                System.assert(false, 'Expected required topic completion validation.');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('required'));
            }
        }
        VisitWizardV6Controller.LaunchContext review =
            VisitWizardV6Controller.getReview(created.visitId, actionPlanId);
        Test.stopTest();

        System.assert(!accounts.isEmpty(), 'Account wrapper should find the test account.');
        System.assertNotEquals(null, addresses, 'Address wrapper should be callable.');
        System.assertNotEquals(null, accountAddresses, 'Account Address wrapper should be callable.');
        System.assertNotEquals(null, contactRecordTypeDescriptions, 'Contact record type descriptions should be callable.');
        if (addressId != null) {
            System.assertEquals(addressId, defaultAddress.addressId);
            System.assertEquals(addressId, addressInfo.addressId);
        }
        System.assertEquals(created.visitId, updated.visitId);
        System.assertNotEquals(null, defaulted.visitId);
        if (opportunitySummary != null) {
            System.assertEquals('V6 Visit Opportunity', opportunitySummary.name);
        }
        if (actionPlanTasks != null) {
            System.assertEquals(actionPlanId, actionPlanTasks.actionPlanId);
        }
        System.assertEquals(created.visitId, review.visitId);
        VisitWizardController.testActionPlanTemplateVersionForVisit = null;
    }

    @IsTest
    static void statusDefaultsPreferInProgress() {
        VisitWizardController.PicklistOption notStarted = new VisitWizardController.PicklistOption();
        notStarted.label = 'Not Started';
        notStarted.value = 'Not Started';
        VisitWizardController.PicklistOption inProgress = new VisitWizardController.PicklistOption();
        inProgress.label = 'In Progress';
        inProgress.value = 'In Progress';

        System.assertEquals(
            'In Progress',
            VisitWizardV6Controller.preferredActionPlanState(
                new List<VisitWizardController.PicklistOption>{ notStarted, inProgress },
                'Not Started'
            )
        );
        System.assertEquals(
            'Not Started',
            VisitWizardV6Controller.preferredActionPlanState(null, 'Not Started')
        );

        if (hasObjects(new Set<String>{ 'ActionPlan' })) {
            System.assertEquals(
                'In Progress',
                VisitWizardV6Controller.actionPlanStateValue(null, 'In Progress')
            );
            System.assertEquals(
                'In Progress',
                VisitWizardV6Controller.actionPlanStateValue('Unexpected', 'In Progress')
            );
            System.assertEquals(
                'Completed',
                VisitWizardV6Controller.actionPlanStateValue('Completed', 'Completed')
            );
        }
    }

    @IsTest
    static void testVisibleUtilityHelpersCoverEdgeBranches() {
        Account accountRecord = new Account(Name = 'V6 Helper Account');
        insert accountRecord;
        Contact contactRecord = new Contact(AccountId = accountRecord.Id, LastName = 'V6 Helper Contact');
        insert contactRecord;

        VisitWizardV6Controller.TaskSummary requiredIncomplete = new VisitWizardV6Controller.TaskSummary();
        requiredIncomplete.required = true;
        requiredIncomplete.completed = false;
        VisitWizardV6Controller.TaskSummary optionalIncomplete = new VisitWizardV6Controller.TaskSummary();
        optionalIncomplete.required = false;
        optionalIncomplete.completed = false;
        VisitWizardV6Controller.TaskSummary requiredComplete = new VisitWizardV6Controller.TaskSummary();
        requiredComplete.required = true;
        requiredComplete.completed = true;

        System.assertEquals(false, VisitWizardV6Controller.requiredTasksComplete(new List<VisitWizardV6Controller.TaskSummary>{ requiredIncomplete }));
        System.assertEquals(true, VisitWizardV6Controller.requiredTasksComplete(new List<VisitWizardV6Controller.TaskSummary>{ optionalIncomplete, requiredComplete }));
        System.assertEquals('Sales', VisitWizardV6Controller.deriveTaskCategory('Sales Follow Up'));
        System.assertEquals(null, VisitWizardV6Controller.deriveTaskCategory('Service Follow Up'));
        System.assertEquals('Hello', VisitWizardV6Controller.stripHtml('<p>&nbsp;Hello</p>'));
        System.assertEquals('fallback', VisitWizardV6Controller.valueOrDefault('', 'fallback'));
        System.assertEquals('actual', VisitWizardV6Controller.valueOrDefault('actual', 'fallback'));
        System.assertEquals(null, VisitWizardV6Controller.blankToNull(' '));
        System.assertEquals('value', VisitWizardV6Controller.blankToNull('value'));

        Map<String, Object> parsed = VisitWizardV6Controller.parseRequest('{"name":"Helper"}', 'Required');
        System.assertEquals('Helper', parsed.get('name'));
        System.assertEquals(0, VisitWizardV6Controller.asMap(new List<Object>()).size());
        try {
            VisitWizardV6Controller.parseRequest(null, 'Required');
            System.assert(false, 'Expected blank request validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Required'));
        }
        try {
            VisitWizardV6Controller.parseRequest('not json', 'Required');
            System.assert(false, 'Expected malformed request validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Request could not be read.'));
        }

        System.assertEquals(0, VisitWizardV6Controller.idsFromList(null).size());
        System.assertEquals(0, VisitWizardV6Controller.idsFromList(String.valueOf(accountRecord.Id)).size());
        System.assertEquals(1, VisitWizardV6Controller.idsFromList(new List<Object>{ String.valueOf(accountRecord.Id), 'bad' }).size());
        System.assertEquals(accountRecord.Id, VisitWizardV6Controller.toId('record=' + accountRecord.Id));
        System.assertEquals(null, VisitWizardV6Controller.toId(null));
        System.assertEquals(null, VisitWizardV6Controller.toId(' '));
        System.assertEquals(null, VisitWizardV6Controller.toId('not an id'));
        System.assertEquals(null, VisitWizardV6Controller.toId('000000000000000'));
        System.assertEquals(Date.today(), VisitWizardV6Controller.toDate(String.valueOf(Date.today())));
        System.assertEquals(null, VisitWizardV6Controller.toDate(null));
        System.assertNotEquals(null, VisitWizardV6Controller.toDateTime('2026-01-01T00:00:00.000Z'));
        System.assertEquals(null, VisitWizardV6Controller.toDateTime(null));
        try {
            VisitWizardV6Controller.toDateTime('not a date');
            System.assert(false, 'Expected date-time validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('valid date and time'));
        }
        System.assertEquals(Decimal.valueOf('12.5'), VisitWizardV6Controller.toDecimal('12.5'));
        System.assertEquals(null, VisitWizardV6Controller.toDecimal(null));

        Map<String, Schema.SObjectField> accountFields = VisitWizardV6Controller.objectFields('Account');
        SObject accountSObject = Account.SObjectType.newSObject(accountRecord.Id);
        VisitWizardV6Controller.putIfCreateable(accountSObject, accountFields, 'Name', 'Created Name');
        VisitWizardV6Controller.putIfCreateable(accountSObject, accountFields, 'Missing__c', 'Ignored');
        VisitWizardV6Controller.putIfUpdateable(accountSObject, accountFields, 'Name', 'Updated Name');
        VisitWizardV6Controller.putIfUpdateable(accountSObject, accountFields, 'Missing__c', 'Ignored');
        VisitWizardV6Controller.putIfWritable(accountSObject, accountFields, 'Name', 'Writable Name', true);
        VisitWizardV6Controller.putIfWritable(accountSObject, accountFields, 'Name', 'Writable Update', false);
        VisitWizardV6Controller.putIfUpdateableWhenChanged(accountSObject, accountFields, 'Missing__c', 'Ignored', 'Old Value');
        VisitWizardV6Controller.putIfUpdateableWhenChanged(accountSObject, accountFields, 'Name', 'Writable Update', 'Writable Update');
        VisitWizardV6Controller.putIfUpdateableWhenChanged(accountSObject, accountFields, 'Name', 'Changed Again', 'Writable Update');
        System.assertEquals(true, VisitWizardV6Controller.hasField('Account', 'Name'));
        System.assertEquals(false, VisitWizardV6Controller.hasField('Account', 'Missing__c'));
        System.assertEquals('Changed Again', VisitWizardV6Controller.fieldValue(accountSObject, 'Name'));
        System.assertEquals(null, VisitWizardV6Controller.fieldValue(accountSObject, 'Missing__c'));
        System.assertEquals(0, VisitWizardV6Controller.objectFields('Missing__c').size());

        System.assertEquals(null, VisitWizardV6Controller.coerceValue(null, Schema.DisplayType.STRING));
        System.assertEquals(Date.today(), VisitWizardV6Controller.coerceValue(String.valueOf(Date.today()), Schema.DisplayType.DATE));
        System.assertNotEquals(null, VisitWizardV6Controller.coerceValue('2026-01-01T00:00:00.000Z', Schema.DisplayType.DATETIME));
        System.assertEquals(true, VisitWizardV6Controller.coerceValue('true', Schema.DisplayType.BOOLEAN));
        System.assertEquals(Decimal.valueOf('3.5'), VisitWizardV6Controller.coerceValue('3.5', Schema.DisplayType.DOUBLE));
        System.assertEquals(7, VisitWizardV6Controller.coerceValue('7', Schema.DisplayType.INTEGER));
        System.assertEquals(Long.valueOf('8'), VisitWizardV6Controller.coerceValue('8', Schema.DisplayType.LONG));
        System.assertEquals('Text', VisitWizardV6Controller.coerceValue('Text', Schema.DisplayType.STRING));

        System.assertEquals(null, VisitWizardV6Controller.firstActivePicklistValue(null));
        System.assertNotEquals(null, VisitWizardV6Controller.firstActivePicklistValue(Opportunity.StageName));
        System.assertEquals(null, VisitWizardV6Controller.activePicklistValue(null, 'Any'));
        System.assertEquals(null, VisitWizardV6Controller.activePicklistValue(accountFields.get('Type'), null));
        String activeStage = VisitWizardV6Controller.firstActivePicklistValue(Opportunity.StageName);
        System.assertEquals(activeStage, VisitWizardV6Controller.activeOpportunityStage(activeStage));
        System.assert(String.isNotBlank(VisitWizardV6Controller.activeOpportunityStage('Definitely_Not_Active')));
        System.assertEquals(null, VisitWizardV6Controller.visitDisplayName(null));
        System.assertEquals(String.valueOf(accountRecord.Id), VisitWizardV6Controller.visitDisplayName(accountRecord.Id));
        System.assertEquals(null, VisitWizardV6Controller.currentGenericTaskStatus(null));
        if (Schema.getGlobalDescribe().containsKey('GenericVisitTask')) {
            System.assertEquals(null, VisitWizardV6Controller.currentGenericTaskStatus(fakeId('GenericVisitTask')));
        }
        System.assertEquals(false, VisitWizardV6Controller.hasEnhancedTaskNote(null));
        System.assertEquals(null, VisitWizardV6Controller.latestActionPlanId(null));
        System.assertEquals(1, VisitWizardV6Controller.nextTopicSequence(null));
        System.assertNotEquals(null, VisitWizardV6Controller.visitFormFieldNames());

        VisitWizardV6Controller.LaunchContext blankContext = new VisitWizardV6Controller.LaunchContext();
        VisitWizardV6Controller.applyAccountContext(blankContext);
        blankContext.accountId = fakeId('Account');
        VisitWizardV6Controller.applyAccountContext(blankContext);
        System.assertEquals(String.valueOf(blankContext.accountId), blankContext.accountName);
        VisitWizardV6Controller.loadActionPlanContext(new VisitWizardV6Controller.LaunchContext());
        System.assertEquals(0, VisitWizardV6Controller.selectedVisitors(null).size());
        System.assertEquals(0, VisitWizardV6Controller.selectedContacts(null).size());
        System.assertEquals(0, VisitWizardV6Controller.queryGenericTasks(null).size());
        try {
            VisitWizardV6Controller.queryVisit(null);
            System.assert(false, 'Expected query Visit Id validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visit Id'));
        }
        try {
            VisitWizardV6Controller.defaultVisitRecordTypeId();
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'Record type helper should return a readable error.');
        }

        VisitWizardV6Controller.assertActiveUsers(new List<Id>());
        VisitWizardV6Controller.assertContactsBelongToAccount(accountRecord.Id, new List<Id>());
        try {
            VisitWizardV6Controller.assertContactsBelongToAccount(accountRecord.Id, new List<Id>{ fakeId('Contact') });
            System.assert(false, 'Expected contact account validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visited parties'));
        }

        try {
            VisitWizardV6Controller.validateTaskCompletion(null, null, null);
            System.assert(false, 'Expected task start validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Start Date Time'));
        }
        try {
            VisitWizardV6Controller.validateTaskCompletion(null, System.now(), null);
            System.assert(false, 'Expected task end validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('End Date Time'));
        }
        try {
            VisitWizardV6Controller.validateTaskCompletion(null, System.now(), System.now().addMinutes(-1));
            System.assert(false, 'Expected task date order validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('after Start Date Time'));
        }

        VisitWizardV6Controller.saveWizardMarkers(null, 'Review', '{}', null);
        try {
            insert new Account();
            System.assert(false, 'Expected DML validation.');
        } catch (DmlException e) {
            System.assert(String.isNotBlank(VisitWizardV6Controller.firstDmlMessage(e)));
        }
        System.assertEquals('Helper error', VisitWizardV6Controller.userError('Helper error').getMessage());
    }

    private static Boolean hasObjects(Set<String> objectNames) {
        Map<String, Schema.SObjectType> objects = Schema.getGlobalDescribe();
        for (String objectName : objectNames) {
            if (!objects.containsKey(objectName)) {
                return false;
            }
        }
        return true;
    }

    private static Id createLocation() {
        Schema.SObjectType locationType = Schema.getGlobalDescribe().get('Location');
        if (locationType == null || !locationType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            return null;
        }

        Map<String, Schema.SObjectField> fields = locationType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        SObject locationRecord = locationType.newSObject();
        if (fields.containsKey('Name') && fields.get('Name').getDescribe().isCreateable()) {
            locationRecord.put('Name', 'V6 Test Location');
        }
        if (fields.containsKey('LocationType') && fields.get('LocationType').getDescribe().isCreateable()) {
            locationRecord.put('LocationType', firstPicklistValue(fields.get('LocationType')));
        }
        insert locationRecord;
        return locationRecord.Id;
    }

    private static Id createGenericVisitTask(Id visitId, Boolean required) {
        Schema.SObjectType taskType = Schema.getGlobalDescribe().get('GenericVisitTask');
        if (taskType == null || !taskType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            return null;
        }

        Map<String, Schema.SObjectField> fields = taskType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        SObject taskRecord = taskType.newSObject();
        putIfCreateable(taskRecord, fields, 'Name', 'Sales Follow Up');
        putIfCreateable(taskRecord, fields, 'VisitId', visitId);
        putIfCreateable(taskRecord, fields, 'IsRequired', required);
        putIfCreateable(taskRecord, fields, 'Sequence', 1);
        putIfCreateable(taskRecord, fields, 'Status', 'Not Started');
        insert taskRecord;
        return taskRecord.Id;
    }

    private static Boolean canCreateGenericVisitTask() {
        Schema.SObjectType taskType = Schema.getGlobalDescribe().get('GenericVisitTask');
        return taskType != null && taskType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable();
    }

    private static List<SObject> visitedPartyRows(Id visitId) {
        String fields = 'Id, ContactId';
        if (VisitWizardV6Controller.hasField('VisitedParty', 'IsPrimaryContact')) {
            fields += ', IsPrimaryContact';
        }
        return Database.query('SELECT ' + fields + ' FROM VisitedParty WHERE VisitId = :visitId ORDER BY CreatedDate, Id');
    }

    private static Integer primaryVisitedPartyCount(List<SObject> rows) {
        Integer count = 0;
        for (SObject row : rows) {
            if (Boolean.valueOf(String.valueOf(row.get('IsPrimaryContact')))) {
                count++;
            }
        }
        return count;
    }

    private class TestSqlException extends Exception {}

    private static Id createAccountAddress(Id accountId) {
        if (accountId == null || !hasObjects(new Set<String>{ 'Location', 'Address', 'AssociatedLocation' })) {
            return null;
        }

        Schema.SObjectType addressType = Schema.getGlobalDescribe().get('Address');
        Schema.SObjectType associationType = Schema.getGlobalDescribe().get('AssociatedLocation');
        if (!addressType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable() ||
            !associationType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            return null;
        }

        try {
            Id locationId = createLocation();
            if (locationId == null) {
                return null;
            }

            Map<String, Schema.SObjectField> addressFields =
                addressType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
            SObject addressRecord = addressType.newSObject();
            putIfCreateable(addressRecord, addressFields, 'ParentId', locationId);
            putIfCreateable(addressRecord, addressFields, 'AddressType', firstPicklistValue(addressFields.get('AddressType')));
            putIfCreateable(addressRecord, addressFields, 'LocationType', firstPicklistValue(addressFields.get('LocationType')));
            putIfCreateable(addressRecord, addressFields, 'Street', 'Visit Wizard Test Street');
            putIfCreateable(addressRecord, addressFields, 'City', 'Visit Wizard City');
            insert addressRecord;

            Map<String, Schema.SObjectField> associationFields =
                associationType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
            SObject associationRecord = associationType.newSObject();
            putIfCreateable(associationRecord, associationFields, 'ParentRecordId', accountId);
            putIfCreateable(associationRecord, associationFields, 'LocationId', locationId);
            putIfCreateable(associationRecord, associationFields, 'Type', firstPicklistValue(associationFields.get('Type')));
            insert associationRecord;

            return addressRecord.Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Id createActionPlanTemplateVersion() {
        if (!hasObjects(new Set<String>{ 'ActionPlanTemplate', 'ActionPlanTemplateVersion' })) {
            return null;
        }

        Schema.SObjectType templateType = Schema.getGlobalDescribe().get('ActionPlanTemplate');
        Schema.SObjectType versionType = Schema.getGlobalDescribe().get('ActionPlanTemplateVersion');
        if (!templateType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable() ||
            !versionType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            return null;
        }

        try {
            Map<String, Schema.SObjectField> templateFields =
                templateType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
            SObject templateRecord = templateType.newSObject();
            String uniqueName = 'V6_Template_' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
            putIfCreateable(templateRecord, templateFields, 'Name', 'V6 Coverage Template');
            putIfCreateable(templateRecord, templateFields, 'UniqueName', uniqueName);
            putIfCreateable(templateRecord, templateFields, 'ActionPlanType', firstActionPlanType());
            putIfCreateable(templateRecord, templateFields, 'TargetEntityType', 'Visit');
            putIfCreateable(templateRecord, templateFields, 'Status', 'Final');
            insert templateRecord;

            Map<String, Schema.SObjectField> versionFields =
                versionType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
            SObject versionRecord = versionType.newSObject();
            putIfCreateable(versionRecord, versionFields, 'Name', 'V6 Coverage Template Version');
            putIfCreateable(versionRecord, versionFields, 'ActionPlanTemplateId', templateRecord.Id);
            putIfCreateable(versionRecord, versionFields, 'Status', 'Final');
            putIfCreateable(versionRecord, versionFields, 'Version', 1);
            putIfCreateable(versionRecord, versionFields, 'VersionNumber', 1);
            insert versionRecord;
            return versionRecord.Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static SObject publishedTemplateVersionStub(Id templateVersionId) {
        return (SObject) JSON.deserialize(
            '{"attributes":{"type":"ActionPlanTemplateVersion"},' +
            '"Id":"' + String.valueOf(templateVersionId) + '",' +
            '"Name":"Published Visit Template Version",' +
            '"ActionPlanTemplateId":"0PR000000000001",' +
            '"Status":"Final",' +
            '"Version":1,' +
            '"LastModifiedDate":"2026-01-01T00:00:00.000Z",' +
            '"ActionPlanTemplate":{' +
                '"attributes":{"type":"ActionPlanTemplate"},' +
                '"Id":"0PR000000000001",' +
                '"Name":"Published Visit Template",' +
                '"ActionPlanType":"' + firstActionPlanType() + '",' +
                '"Status":"Final",' +
                '"TargetEntityType":"Visit"' +
            '}}',
            SObject.class
        );
    }

    private static Id createActionPlan(Id visitId) {
        if (visitId == null || !hasObjects(new Set<String>{ 'ActionPlan', 'ActionPlanTemplateVersion' })) {
            return null;
        }

        Schema.SObjectType planType = Schema.getGlobalDescribe().get('ActionPlan');
        if (!planType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            return null;
        }

        Id versionId = createActionPlanTemplateVersion();
        if (versionId == null) {
            return null;
        }

        try {
            Map<String, Schema.SObjectField> fields = planType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
            SObject planRecord = planType.newSObject();
            putIfCreateable(planRecord, fields, 'Name', 'V6 Coverage Meeting Template');
            putIfCreateable(planRecord, fields, 'TargetId', visitId);
            putIfCreateable(planRecord, fields, 'ActionPlanTemplateVersionId', versionId);
            putIfCreateable(planRecord, fields, 'ActionPlanType', firstActionPlanType());
            putIfCreateable(planRecord, fields, 'ActionPlanState', 'In Progress');
            putIfCreateable(planRecord, fields, 'StartDate', Date.today());
            insert planRecord;
            return planRecord.Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Id createActionPlanItem(Id actionPlanId, Id taskId) {
        if (actionPlanId == null || !hasObjects(new Set<String>{ 'ActionPlanItem' })) {
            return null;
        }

        Schema.SObjectType itemType = Schema.getGlobalDescribe().get('ActionPlanItem');
        if (!itemType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            return null;
        }

        try {
            Map<String, Schema.SObjectField> fields = itemType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
            SObject itemRecord = itemType.newSObject();
            putIfCreateable(itemRecord, fields, 'Name', 'V6 Coverage Topic Item');
            putIfCreateable(itemRecord, fields, 'ActionPlanId', actionPlanId);
            putIfCreateable(itemRecord, fields, 'ItemId', taskId);
            putIfCreateable(itemRecord, fields, 'ItemState', 'Pending');
            putIfCreateable(itemRecord, fields, 'IsRequired', true);
            putIfCreateable(itemRecord, fields, 'DisplayOrder', 1);
            insert itemRecord;
            return itemRecord.Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Id defaultVisitRecordTypeId() {
        try {
            List<VisitWizardController.RecordTypeOption> recordTypes =
                VisitWizardV6Controller.getVisitRecordTypesV6();
            for (VisitWizardController.RecordTypeOption recordType : recordTypes) {
                if (recordType.defaultRecordTypeMapping) {
                    return (Id) recordType.value;
                }
            }
            return recordTypes.isEmpty() ? null : (Id) recordTypes[0].value;
        } catch (Exception e) {
            return null;
        }
    }

    private static void putIfCreateable(SObject record, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (fields.containsKey(fieldName) && fields.get(fieldName).getDescribe().isCreateable()) {
            record.put(fieldName, value);
        }
    }

    private static String firstPicklistValue(Schema.SObjectField fieldToken) {
        if (fieldToken == null) {
            return null;
        }
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static String firstActionPlanType() {
        Map<String, Schema.SObjectField> fields = VisitWizardV6Controller.objectFields('ActionPlan');
        if (fields.containsKey('ActionPlanType')) {
            for (Schema.PicklistEntry entry : fields.get('ActionPlanType').getDescribe().getPicklistValues()) {
                if (entry.isActive() && entry.getValue() == 'Retail') {
                    return entry.getValue();
                }
            }
        }
        return firstPicklistValue(fields.get('ActionPlanType'));
    }

    private static Id fakeId(String objectApiName) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        String prefix = objectType == null ? '001' : objectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix();
        return (Id) (prefix + '000000000001AAA');
    }

    private static Boolean hasPicklistOption(List<VisitWizardController.PicklistOption> options, String value) {
        if (options == null) {
            return false;
        }
        for (VisitWizardController.PicklistOption option : options) {
            if (option.value == value) {
                return true;
            }
        }
        return false;
    }

    private static Boolean taskNamed(List<VisitWizardV6Controller.TaskSummary> tasks, String taskName) {
        for (VisitWizardV6Controller.TaskSummary task : tasks) {
            if (task.name == taskName) {
                return true;
            }
        }
        return false;
    }
}
