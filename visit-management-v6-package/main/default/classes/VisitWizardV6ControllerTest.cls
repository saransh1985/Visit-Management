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
    static void validationErrorsAreReadable() {
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
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
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
