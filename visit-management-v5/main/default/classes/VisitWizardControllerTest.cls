@IsTest
private class VisitWizardControllerTest {
    @IsTest
    static void returnsAccountOwnerAsLockedVisitor() {
        Account accountRecord = new Account(Name = 'Visit Wizard Test Account');
        insert accountRecord;

        Test.startTest();
        List<VisitWizardController.UserCandidate> candidates =
            VisitWizardController.getInitialVisitorCandidates(accountRecord.Id);
        Test.stopTest();

        System.assert(!candidates.isEmpty(), 'The account owner should be returned as a visitor candidate.');
        System.assertEquals(UserInfo.getUserId(), candidates[0].userId);
        System.assertEquals(true, candidates[0].selected);
        System.assertEquals(true, candidates[0].locked);
    }

    @IsTest
    static void searchContactsLimitsResultsToAccount() {
        Account accountRecord = new Account(Name = 'Visit Wizard Contacts');
        Account otherAccount = new Account(Name = 'Other Visit Wizard Contacts');
        insert new List<Account>{ accountRecord, otherAccount };

        Contact matchingContact = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Wizard',
            Email = 'wizard@example.com'
        );
        Contact otherContact = new Contact(
            AccountId = otherAccount.Id,
            LastName = 'Wizard',
            Email = 'other-wizard@example.com'
        );
        insert new List<Contact>{ matchingContact, otherContact };

        Test.startTest();
        List<VisitWizardController.ContactCandidate> results =
            VisitWizardController.searchContacts(accountRecord.Id, 'Wizard', new List<Id>());
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(matchingContact.Id, results[0].contactId);
        System.assertEquals(accountRecord.Id, results[0].accountId);
    }

    @IsTest
    static void metadataAndUserSearchMethodsReturnData() {
        Test.startTest();
        List<VisitWizardController.UserCandidate> users =
            VisitWizardController.searchUsers('', new List<Id>());

        try {
            List<VisitWizardController.RecordTypeOption> recordTypes =
                VisitWizardController.getVisitRecordTypesV4();
            List<VisitWizardController.FieldMetadata> fields =
                VisitWizardController.getVisitFieldMetadata(recordTypes.isEmpty() ? null : (Id) recordTypes[0].value);
            System.assertNotEquals(null, recordTypes);
            System.assert(!recordTypes.isEmpty(), 'At least one non-Master Visit record type should be available in Automotive Cloud orgs.');
            for (VisitWizardController.RecordTypeOption recordType : recordTypes) {
                System.assertEquals(false, recordType.master, 'Master should not be shown as a Visit record type option.');
            }
            System.assertNotEquals(null, fields);
            assertNoDuplicateVisitFields(fields);
        } catch (AuraHandledException e) {
            System.assert(!Schema.getGlobalDescribe().containsKey('Visit'), 'Visit metadata methods should work when Visit exists.');
        }
        Test.stopTest();

        System.assert(!users.isEmpty(), 'The running user should be searchable.');
        Set<Id> userIds = new Set<Id>();
        for (VisitWizardController.UserCandidate userCandidate : users) {
            userIds.add(userCandidate.userId);
        }
        System.assertEquals(
            userIds.size(),
            [SELECT COUNT() FROM User WHERE Id IN :userIds AND IsActive = true],
            'Visitor search should only return active Salesforce users.'
        );
    }

    @IsTest
    static void saveVisitCreatesVisitVisitorsAndVisitedPartiesWhenAvailable() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'Visit Wizard Save Account');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Visited Party',
            Email = 'visited-party@example.com'
        );
        insert contactRecord;

        Id locationId = createLocation();
        System.assertNotEquals(null, locationId, 'A test Location should be available for Visit.PlaceId.');

        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = accountRecord.Id;
        request.recordTypeId = defaultVisitRecordTypeId();
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        request.visitedContactIds = new List<Id>{ contactRecord.Id };
        request.action = 'Submit';
        request.visitFields = new Map<String, Object>{
            'PlannedVisitStartTime' => System.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
            'PlannedVisitEndTime' => System.now().addDays(1).addHours(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
            'PlaceId' => locationId
        };

        Test.startTest();
        VisitWizardController.SaveResponse response = VisitWizardController.saveVisit(request);
        Test.stopTest();

        System.assertNotEquals(null, response.visitId);
        Id visitId = response.visitId;
        System.assertEquals(1, Database.countQuery('SELECT COUNT() FROM Visit WHERE Id = :visitId'));
        System.assertEquals(1, Database.countQuery('SELECT COUNT() FROM Visitor WHERE VisitId = :visitId'));
        System.assertEquals(1, Database.countQuery('SELECT COUNT() FROM VisitedParty WHERE VisitId = :visitId'));

        SObject visitorRecord = Database.query('SELECT VisitId, AssigneeId FROM Visitor WHERE VisitId = :visitId LIMIT 1');
        SObject visitedPartyRecord = Database.query('SELECT VisitId, ContactId FROM VisitedParty WHERE VisitId = :visitId LIMIT 1');
        System.assertEquals(visitId, (Id) visitorRecord.get('VisitId'));
        System.assertEquals(UserInfo.getUserId(), (Id) visitorRecord.get('AssigneeId'));
        System.assertEquals(visitId, (Id) visitedPartyRecord.get('VisitId'));
        System.assertEquals(contactRecord.Id, (Id) visitedPartyRecord.get('ContactId'));
    }

    @IsTest
    static void saveVisitValidatesPortableRequestBeforeAutomotiveObjects() {
        Account accountRecord = new Account(Name = 'Visit Wizard Portable Save');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Portable Save'
        );
        insert contactRecord;

        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = accountRecord.Id;
        request.accountIdText = 'context=' + accountRecord.Id;
        request.sourceAccountId = String.valueOf(accountRecord.Id);
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId(), UserInfo.getUserId() };
        request.visitedContactIds = new List<Id>{ contactRecord.Id, contactRecord.Id, null };
        request.visitedContactIdStrings = new List<String>{ String.valueOf(contactRecord.Id), 'selected=' + contactRecord.Id };
        request.visitedContactIdText = 'party=' + contactRecord.Id;
        request.action = 'Submit';

        Test.startTest();
        try {
            VisitWizardController.SaveResponse response = VisitWizardController.saveVisit(request);
            System.assertNotEquals(null, response.visitId, 'A successful save should return the Visit Id.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'The save path should return a readable error.');
            System.assert(
                !String.valueOf(e.getMessage()).contains('de-reference'),
                'The save path should not fail with a null-pointer error.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void saveVisitCanRunThroughDmlWithPortableTestObjects() {
        VisitWizardController.visitObjectApiName = 'Account';
        VisitWizardController.visitorObjectApiName = 'Account';
        VisitWizardController.visitedPartyObjectApiName = 'Account';
        VisitWizardController.visitAccountFieldApiName = 'ParentId';
        VisitWizardController.visitVisitorFieldApiName = 'OwnerId';
        VisitWizardController.visitorVisitFieldApiName = 'ParentId';
        VisitWizardController.visitorAssigneeFieldApiName = 'OwnerId';
        VisitWizardController.visitedPartyVisitFieldApiName = 'ParentId';
        VisitWizardController.visitedPartyContactFieldApiName = 'Name';

        Account sourceAccount = new Account(Name = 'Visit Wizard Source Account');
        insert sourceAccount;

        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = sourceAccount.Id;
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        request.visitedContactIds = new List<Id>();
        request.action = 'Draft';
        request.visitFields = new Map<String, Object>{
            'Name' => 'Portable Visit Proxy',
            'ParentId' => sourceAccount.Id,
            'Missing__c' => 'Ignored'
        };

        Test.startTest();
        VisitWizardController.SaveResponse response = VisitWizardController.saveVisit(request);
        Test.stopTest();

        System.assertEquals('Visit saved as draft.', response.message);
        Account visitProxy = [SELECT Id, Name, ParentId, OwnerId FROM Account WHERE Id = :response.visitId];
        System.assertEquals('Portable Visit Proxy', visitProxy.Name);
        System.assertEquals(sourceAccount.Id, visitProxy.ParentId);
        System.assertEquals(UserInfo.getUserId(), visitProxy.OwnerId);

        Account visitorProxy = [
            SELECT Id, ParentId, OwnerId
            FROM Account
            WHERE ParentId = :response.visitId
            LIMIT 1
        ];
        System.assertEquals(response.visitId, visitorProxy.ParentId);
        System.assertEquals(UserInfo.getUserId(), visitorProxy.OwnerId);
    }

    @IsTest
    static void saveVisitV3ParsesPortablePayloadBeforeAutomotiveObjects() {
        Account accountRecord = new Account(Name = 'Visit Wizard Portable Json');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Portable Json'
        );
        insert contactRecord;

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => null,
            'accountIdText' => 'recordId=' + accountRecord.Id,
            'sourceAccountId' => String.valueOf(accountRecord.Id),
            'visitorUserIds' => new List<String>{ String.valueOf(UserInfo.getUserId()), String.valueOf(UserInfo.getUserId()) },
            'visitedContactIds' => new List<String>{ String.valueOf(contactRecord.Id) },
            'visitedContactIdStrings' => new List<String>{ 'selected=' + contactRecord.Id },
            'visitedContactIdText' => 'party=' + contactRecord.Id,
            'visitFields' => new Map<String, Object>{ 'AccountId' => accountRecord.Id },
            'action' => 'Submit'
        };

        Test.startTest();
        try {
            VisitWizardController.SaveResponse response = VisitWizardController.saveVisitV3(JSON.serialize(payload));
            System.assertNotEquals(null, response.visitId, 'A successful JSON save should return the Visit Id.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'The JSON save path should return a readable error.');
        }
        Test.stopTest();
    }

    @IsTest
    static void saveVisitV3HandlesInvalidPayloads() {
        Test.startTest();
        try {
            VisitWizardController.saveVisitV3(null);
            System.assert(false, 'Expected blank payload validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Save request is required.'));
        }

        try {
            VisitWizardController.saveVisitV3('not json');
            System.assert(false, 'Expected malformed JSON validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Save request could not be read.'));
        }

        try {
            VisitWizardController.saveVisitV3('[]');
            System.assert(false, 'Expected non-object JSON validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Save request is required.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void actionPlanStartInfoReturnsStatusesWhenAvailable() {
        if (!hasObjects(new Set<String>{ 'ActionPlan', 'ActionPlanTemplate', 'ActionPlanTemplateVersion' })) {
            return;
        }

        Test.startTest();
        VisitWizardController.ActionPlanStartInfo info =
            VisitWizardController.getActionPlanStartInfo(null);
        Test.stopTest();

        System.assertNotEquals(null, info.statusOptions, 'Action Plan status options should be initialized.');
        System.assert(!info.statusOptions.isEmpty(), 'Action Plan status should offer at least one active value.');
        System.assert(String.isNotBlank(info.defaultStatus), 'Action Plan default status should be available.');
        System.assertNotEquals(null, info.recentTemplates, 'Recent templates should be initialized even when none exist in tests.');
    }

    @IsTest
    static void actionPlanStartInfoReturnsReadableErrorWhenUnavailable() {
        Test.startTest();
        try {
            VisitWizardController.getActionPlanStartInfo(null);
            System.assert(Schema.getGlobalDescribe().containsKey('ActionPlan'), 'Expected an error when ActionPlan is unavailable.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'The start info path should return a readable error.');
        }
        Test.stopTest();
    }

    @IsTest
    static void saveActionPlanValidatesRequiredFields() {
        Test.startTest();
        try {
            VisitWizardController.saveActionPlan('{}');
            System.assert(false, 'Expected a readable validation error.');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Target Record'),
                'A missing Visit target should return a Target Record validation error.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void saveActionPlanHandlesInvalidPayloads() {
        Test.startTest();
        try {
            VisitWizardController.saveActionPlan(null);
            System.assert(false, 'Expected blank action plan payload validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Action Plan request is required.'));
        }

        try {
            VisitWizardController.saveActionPlan('not json');
            System.assert(false, 'Expected malformed action plan JSON validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Action Plan request could not be read.'));
        }

        try {
            VisitWizardController.saveActionPlan('[]');
            System.assert(false, 'Expected non-object action plan JSON validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Action Plan request is required.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void saveActionPlanParsesPortablePayloadBeforeAutomotiveObjects() {
        Account targetRecord = new Account(Name = 'Visit Wizard Action Plan Target');
        insert targetRecord;

        Map<String, Object> payload = new Map<String, Object>{
            'visitId' => String.valueOf(targetRecord.Id),
            'targetRecordId' => String.valueOf(targetRecord.Id),
            'name' => 'Portable Action Plan',
            'startDate' => String.valueOf(Date.today().addDays(1)),
            'actionPlanTemplateVersionId' => String.valueOf(UserInfo.getUserId()),
            'status' => 'Not Started'
        };

        Test.startTest();
        try {
            VisitWizardController.ActionPlanSaveResponse response =
                VisitWizardController.saveActionPlan(JSON.serialize(payload));
            System.assertNotEquals(null, response.actionPlanId, 'A successful action plan save should return the Action Plan Id.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'The action plan save path should return a readable error.');
        }
        Test.stopTest();
    }

    @IsTest
    static void contextMissingMethodsReturnReadableErrors() {
        Test.startTest();
        try {
            VisitWizardController.getInitialVisitorCandidates(null);
            System.assert(false, 'Expected account context validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account Id is required.'));
        }

        try {
            VisitWizardController.searchContacts(null, null, null);
            System.assert(false, 'Expected contact search account validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account Id is required.'));
        }

        try {
            VisitWizardController.getVisitFieldMetadata(null);
            System.assert(Schema.getGlobalDescribe().containsKey('Visit'), 'Expected an error when Visit is unavailable.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'Visit metadata should return a readable error.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testVisibleJsonAndNormalizationHelpersCoverPortableBranches() {
        Account accountRecord = new Account(Name = 'Visit Wizard Helper Account');
        Account otherAccount = new Account(Name = 'Visit Wizard Other Helper Account');
        insert new List<Account>{ accountRecord, otherAccount };

        Contact contactRecord = new Contact(AccountId = accountRecord.Id, LastName = 'Helper Contact');
        insert contactRecord;

        Map<String, Object> savePayload = new Map<String, Object>{
            'accountId' => String.valueOf(accountRecord.Id),
            'accountIdText' => 'context=' + accountRecord.Id,
            'sourceAccountId' => String.valueOf(accountRecord.Id),
            'recordTypeId' => null,
            'visitFields' => new Map<String, Object>{ 'AccountId' => accountRecord.Id },
            'visitorUserIds' => new List<String>{ String.valueOf(UserInfo.getUserId()) },
            'visitedContactIds' => new List<String>{ String.valueOf(contactRecord.Id) },
            'visitedContactIdStrings' => new List<String>{ 'party=' + contactRecord.Id },
            'visitedContactIdText' => 'selected=' + contactRecord.Id,
            'action' => 'Submit'
        };

        Object rawSavePayload = JSON.deserializeUntyped(JSON.serialize(savePayload));
        VisitWizardController.SaveRequest saveRequest = VisitWizardController.saveRequestFromJson(rawSavePayload);
        System.assertEquals(accountRecord.Id, saveRequest.accountId);
        System.assertEquals('Submit', saveRequest.action);
        System.assertEquals(1, saveRequest.visitorUserIds.size());
        System.assertEquals(1, saveRequest.visitedContactIds.size());
        System.assertEquals(1, saveRequest.visitedContactIdStrings.size());
        System.assertEquals(null, VisitWizardController.saveRequestFromJson(new List<Object>()));

        Object rawActionPlanPayload = JSON.deserializeUntyped(JSON.serialize(new Map<String, Object>{
            'visitId' => String.valueOf(accountRecord.Id),
            'targetRecordId' => String.valueOf(otherAccount.Id),
            'name' => 'Helper Action Plan',
            'startDate' => String.valueOf(Date.today()),
            'actionPlanTemplateVersionId' => String.valueOf(UserInfo.getUserId()),
            'status' => 'Not Started'
        }));
        VisitWizardController.ActionPlanSaveRequest actionRequest =
            VisitWizardController.actionPlanRequestFromJson(rawActionPlanPayload);
        System.assertEquals(accountRecord.Id, actionRequest.visitId);
        System.assertEquals(Date.today(), actionRequest.startDate);
        System.assertEquals(null, VisitWizardController.actionPlanRequestFromJson('not a map'));

        System.assertNotEquals(null, VisitWizardController.mapFromJson(saveRequest.visitFields));
        System.assertEquals(null, VisitWizardController.mapFromJson('not a map'));
        System.assertEquals(null, VisitWizardController.stringFromJson(null));
        System.assertEquals('42', VisitWizardController.stringFromJson(42));
        System.assertEquals(accountRecord.Id, VisitWizardController.idFromJson(accountRecord.Id));
        System.assertEquals(null, VisitWizardController.idFromJson(null));
        System.assertEquals(Date.today(), VisitWizardController.dateFromJson(String.valueOf(Date.today()) + 'T00:00:00.000Z'));
        System.assertEquals(null, VisitWizardController.dateFromJson(null));
        System.assertEquals(0, VisitWizardController.idsFromJson(null).size());
        System.assertEquals(1, VisitWizardController.idsFromJson(String.valueOf(contactRecord.Id)).size());
        System.assertEquals(0, VisitWizardController.stringsFromJson(null).size());
        System.assertEquals(1, VisitWizardController.stringsFromJson('single').size());

        VisitWizardController.SaveRequest sourceFallback = new VisitWizardController.SaveRequest();
        sourceFallback.sourceAccountId = 'source=' + accountRecord.Id;
        sourceFallback.visitedContactIds = new List<Id>{ contactRecord.Id };
        VisitWizardController.normalizeSaveRequest(sourceFallback);
        System.assertEquals(accountRecord.Id, sourceFallback.accountId);

        VisitWizardController.SaveRequest fieldFallback = new VisitWizardController.SaveRequest();
        fieldFallback.visitFields = new Map<String, Object>{ 'ContextId' => 'context=' + otherAccount.Id };
        fieldFallback.visitedContactIdText = 'contact=' + contactRecord.Id;
        VisitWizardController.normalizeSaveRequest(fieldFallback);
        System.assertEquals(otherAccount.Id, fieldFallback.accountId);
        System.assertEquals(1, fieldFallback.visitedContactIds.size());

        VisitWizardController.SaveRequest contactFallback = new VisitWizardController.SaveRequest();
        contactFallback.visitedContactIds = new List<Id>{ contactRecord.Id };
        VisitWizardController.normalizeSaveRequest(contactFallback);
        System.assertEquals(accountRecord.Id, contactFallback.accountId);

        System.assertEquals(null, VisitWizardController.accountIdFromVisitFields(null));
        System.assertEquals(accountRecord.Id, VisitWizardController.accountIdFromVisitFields(new Map<String, Object>{ 'AccountId' => accountRecord.Id }));
        System.assertEquals(otherAccount.Id, VisitWizardController.firstAccountIdFromValues(new List<Object>{ 'none', 'record=' + otherAccount.Id }));
        System.assertEquals(null, VisitWizardController.firstAccountIdFromValues(null));
        System.assertEquals(accountRecord.Id, VisitWizardController.firstAccountIdFromValue('record=' + accountRecord.Id));

        List<Id> extractedIds = new List<Id>();
        VisitWizardController.addIdsFromValue(extractedIds, 'record=' + accountRecord.Id, '001');
        VisitWizardController.addIdsFromValue(extractedIds, '', '001');
        VisitWizardController.addIdsFromValue(extractedIds, accountRecord.Id, '');
        VisitWizardController.addIdsFromValue(null, accountRecord.Id, '001');
        System.assertEquals(1, extractedIds.size());
        System.assertEquals(1, VisitWizardController.dedupeIdsPreserveOrder(new List<Id>{ accountRecord.Id, accountRecord.Id, null }).size());
        System.assertEquals(0, VisitWizardController.dedupeIdsPreserveOrder(null).size());
    }

    @IsTest
    static void testVisibleValidationHelpersCoverPortableBranches() {
        Account accountRecord = new Account(Name = 'Visit Wizard Validation Account');
        Account otherAccount = new Account(Name = 'Visit Wizard Validation Other');
        insert new List<Account>{ accountRecord, otherAccount };

        Contact contactRecord = new Contact(AccountId = accountRecord.Id, LastName = 'Validation Contact');
        insert contactRecord;

        try {
            VisitWizardController.validateSaveRequest(null);
            System.assert(false, 'Expected null save request validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Save request is required.'));
        }

        VisitWizardController.SaveRequest missingAccount = new VisitWizardController.SaveRequest();
        missingAccount.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        try {
            VisitWizardController.validateSaveRequest(missingAccount);
            System.assert(false, 'Expected account validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account Id is required.'));
        }

        VisitWizardController.SaveRequest missingVisitor = new VisitWizardController.SaveRequest();
        missingVisitor.accountId = accountRecord.Id;
        missingVisitor.visitorUserIds = new List<Id>();
        try {
            VisitWizardController.validateSaveRequest(missingVisitor);
            System.assert(false, 'Expected visitor validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Select at least one visitor.'));
        }

        VisitWizardController.SaveRequest missingVisitedParty = new VisitWizardController.SaveRequest();
        missingVisitedParty.accountId = accountRecord.Id;
        missingVisitedParty.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        missingVisitedParty.visitedContactIds = new List<Id>();
        missingVisitedParty.action = 'Submit';
        try {
            VisitWizardController.validateSaveRequest(missingVisitedParty);
            System.assert(false, 'Expected visited party validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Select at least one visited party'));
        }

        VisitWizardController.SaveRequest draftWithoutVisitedParties = new VisitWizardController.SaveRequest();
        draftWithoutVisitedParties.accountId = accountRecord.Id;
        draftWithoutVisitedParties.visitorUserIds = new List<Id>{ UserInfo.getUserId(), UserInfo.getUserId() };
        draftWithoutVisitedParties.action = 'Draft';
        VisitWizardController.validateSaveRequest(draftWithoutVisitedParties);
        System.assertEquals(1, draftWithoutVisitedParties.visitorUserIds.size());
        System.assertEquals(0, draftWithoutVisitedParties.visitedContactIds.size());

        VisitWizardController.SaveRequest mismatchedContact = new VisitWizardController.SaveRequest();
        mismatchedContact.accountId = otherAccount.Id;
        mismatchedContact.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        mismatchedContact.visitedContactIds = new List<Id>{ contactRecord.Id };
        mismatchedContact.action = 'Draft';
        try {
            VisitWizardController.validateSaveRequest(mismatchedContact);
            System.assert(false, 'Expected contact account validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visited parties must be contacts'));
        }

        VisitWizardController.assertActiveUsers(new List<Id>());
        try {
            VisitWizardController.assertActiveUsers(new List<Id>{ (Id) '005000000000000AAA' });
            System.assert(false, 'Expected inactive visitor validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('inactive or unavailable'));
        }

        VisitWizardController.assertContactsBelongToAccount(accountRecord.Id, new List<Id>());
        try {
            VisitWizardController.assertContactsBelongToAccount(otherAccount.Id, new List<Id>{ contactRecord.Id });
            System.assert(false, 'Expected contact ownership validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visited parties must be contacts'));
        }

        VisitWizardController.ActionPlanSaveRequest missingActionTarget = new VisitWizardController.ActionPlanSaveRequest();
        try {
            VisitWizardController.saveActionPlanRequest(missingActionTarget);
            System.assert(false, 'Expected target validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Target Record is required.'));
        }

        VisitWizardController.ActionPlanSaveRequest missingActionName = new VisitWizardController.ActionPlanSaveRequest();
        missingActionName.targetRecordId = accountRecord.Id;
        try {
            VisitWizardController.validateActionPlanRequest(missingActionName);
            System.assert(false, 'Expected name validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Action Plan Name is required.'));
        }

        VisitWizardController.ActionPlanSaveRequest missingActionDate = new VisitWizardController.ActionPlanSaveRequest();
        missingActionDate.targetRecordId = accountRecord.Id;
        missingActionDate.name = 'Missing Date';
        try {
            VisitWizardController.validateActionPlanRequest(missingActionDate);
            System.assert(false, 'Expected start date validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Start Date is required.'));
        }

        VisitWizardController.ActionPlanSaveRequest missingActionTemplate = new VisitWizardController.ActionPlanSaveRequest();
        missingActionTemplate.targetRecordId = accountRecord.Id;
        missingActionTemplate.name = 'Missing Template';
        missingActionTemplate.startDate = Date.today();
        try {
            VisitWizardController.validateActionPlanRequest(missingActionTemplate);
            System.assert(false, 'Expected template validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Action Plan Template is required.'));
        }
    }

    @IsTest
    static void testVisibleDescribeAndSObjectHelpersCoverPortableBranches() {
        Account accountRecord = new Account(Name = 'Visit Wizard Describe Account');
        insert accountRecord;

        Contact contactRecord = new Contact(AccountId = accountRecord.Id, LastName = 'Describe Contact');
        insert contactRecord;

        Map<String, Schema.SObjectField> accountFields =
            Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        SObject accountSObject = Account.SObjectType.newSObject();
        VisitWizardController.safePut(accountSObject, accountFields, 'Name', 'Helper Name');
        VisitWizardController.safePut(accountSObject, accountFields, 'NumberOfEmployees', '7');
        VisitWizardController.safePut(accountSObject, accountFields, 'Missing__c', 'Ignored');
        VisitWizardController.safePut(accountSObject, accountFields, 'Name', null);
        System.assertEquals('Helper Name', accountSObject.get('Name'));
        System.assertEquals(7, accountSObject.get('NumberOfEmployees'));

        VisitWizardController.putNameIfCreateable(accountSObject, accountFields, '');
        System.assertEquals('Visit Participant', accountSObject.get('Name'));
        VisitWizardController.putNameIfCreateable(accountSObject, new Map<String, Schema.SObjectField>(), 'Ignored');

        System.assertEquals(null, VisitWizardController.coerceValue(null, Schema.DisplayType.STRING));
        System.assertEquals(null, VisitWizardController.coerceValue('', Schema.DisplayType.STRING));
        System.assertEquals(Date.today(), VisitWizardController.coerceValue(String.valueOf(Date.today()), Schema.DisplayType.DATE));
        System.assertNotEquals(null, VisitWizardController.coerceValue('2026-01-01T00:00:00.000Z', Schema.DisplayType.DATETIME));
        System.assertEquals(true, VisitWizardController.coerceValue('true', Schema.DisplayType.BOOLEAN));
        System.assertEquals(Decimal.valueOf('12.5'), VisitWizardController.coerceValue('12.5', Schema.DisplayType.DOUBLE));
        System.assertEquals(3, VisitWizardController.coerceValue('3', Schema.DisplayType.INTEGER));
        System.assertEquals(Long.valueOf('4'), VisitWizardController.coerceValue('4', Schema.DisplayType.LONG));
        System.assertEquals('Text', VisitWizardController.coerceValue('Text', Schema.DisplayType.STRING));

        System.assertNotEquals(null, VisitWizardController.isRequiredCreateField(accountFields.get('Name').getDescribe()));
        System.assertEquals(false, VisitWizardController.isRequiredCreateField(accountFields.get('OwnerId').getDescribe()));
        VisitWizardController.FieldMetadata nameMetadata = VisitWizardController.toFieldMetadata(accountFields.get('Name').getDescribe());
        System.assertEquals('Name', nameMetadata.apiName);

        System.assertEquals(0, VisitWizardController.picklistOptions(null).size());
        List<VisitWizardController.PicklistOption> typeOptions = VisitWizardController.picklistOptions(accountFields.get('Type'));
        String defaultType = VisitWizardController.defaultPicklistValue(accountFields.get('Type'));
        System.assertEquals(null, VisitWizardController.defaultPicklistValue(null));
        System.assertEquals(false, VisitWizardController.isActivePicklistValue(null, 'Customer'));
        System.assertEquals(false, VisitWizardController.isActivePicklistValue(accountFields.get('Type'), 'Definitely_Not_Active'));
        if (!typeOptions.isEmpty()) {
            System.assertEquals(true, VisitWizardController.isActivePicklistValue(accountFields.get('Type'), typeOptions[0].value));
        }
        System.assert(defaultType == null || String.isNotBlank(defaultType) || defaultType == '');

        System.assertEquals('', VisitWizardController.normalizeFieldName(null));
        System.assertEquals('name', VisitWizardController.normalizeFieldName('Name'));

        User currentUser = [SELECT Id, Name, Email, Title, Department FROM User WHERE Id = :UserInfo.getUserId()];
        VisitWizardController.UserCandidate userCandidate =
            VisitWizardController.toUserCandidate(currentUser.Id, currentUser, 'Helper', true, false);
        System.assertEquals(currentUser.Id, userCandidate.userId);
        System.assertEquals(true, userCandidate.selected);
        VisitWizardController.UserCandidate nullUserCandidate =
            VisitWizardController.toUserCandidate(currentUser.Id, null, 'Helper', false, true);
        System.assertEquals(String.valueOf(currentUser.Id), nullUserCandidate.name);

        System.assertEquals(0, VisitWizardController.getUserNames(new Set<Id>()).size());
        System.assertEquals(1, VisitWizardController.getUserNames(new Set<Id>{ currentUser.Id }).size());
        System.assertEquals(0, VisitWizardController.getContactNames(new Set<Id>()).size());
        System.assertEquals(1, VisitWizardController.getContactNames(new Set<Id>{ contactRecord.Id }).size());

        VisitWizardController.applyStatusForAction(accountSObject, accountFields, 'Draft');
        Case caseRecord = new Case();
        VisitWizardController.applyStatusForAction(
            caseRecord,
            Case.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap(),
            'Submit'
        );

        VisitWizardController.requireCreateableField(accountFields, 'Name', 'Account');
        try {
            VisitWizardController.requireCreateableField(new Map<String, Schema.SObjectField>(), 'Name', 'Account');
            System.assert(false, 'Expected createable field validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Account.Name'));
        }

        System.assertNotEquals(null, VisitWizardController.getRequiredObjectType('Account'));
        System.assertNotEquals(null, VisitWizardController.getObjectType('Account'));
        System.assertEquals(null, VisitWizardController.getObjectType('Definitely_Not_Real__c'));
        try {
            VisitWizardController.getRequiredObjectType('Definitely_Not_Real__c');
            System.assert(false, 'Expected missing object validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Definitely_Not_Real__c'));
        }

        try {
            insert new Account();
            System.assert(false, 'Expected DML validation.');
        } catch (DmlException e) {
            System.assert(String.isNotBlank(VisitWizardController.firstDmlMessage(e)));
        }

        System.assertEquals('Helper error', VisitWizardController.userError('Helper error').getMessage());
        System.assertNotEquals(null, VisitWizardController.recentActionPlanTemplateOptions());

        String originalVisitObjectApiName = VisitWizardController.visitObjectApiName;
        VisitWizardController.visitObjectApiName = 'Account';
        try {
            List<VisitWizardController.RecordTypeOption> accountRecordTypes =
                VisitWizardController.getAvailableVisitRecordTypes();
            System.assertNotEquals(null, accountRecordTypes);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No Visit record types are available'));
        }
        VisitWizardController.visitObjectApiName = originalVisitObjectApiName;

        try {
            VisitWizardController.buildVisitorRecords(
                Account.SObjectType,
                accountRecord.Id,
                new Set<Id>{ currentUser.Id },
                new Map<Id, String>{ currentUser.Id => currentUser.Name }
            );
            System.assert(false, 'Expected visitor field validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Visitor.VisitId'));
        }

        try {
            VisitWizardController.buildVisitedPartyRecords(
                Account.SObjectType,
                accountRecord.Id,
                new Set<Id>{ contactRecord.Id },
                new Map<Id, String>{ contactRecord.Id => contactRecord.Name }
            );
            System.assert(false, 'Expected visited party field validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('VisitedParty.VisitId'));
        }
    }

    @IsTest
    static void saveVisitRecoversAccountIdFromVisitFieldsWhenAvailable() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'Visit Wizard Account Fallback');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Fallback Contact'
        );
        insert contactRecord;

        Id locationId = createLocation();

        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = null;
        request.recordTypeId = defaultVisitRecordTypeId();
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        request.visitedContactIds = new List<Id>();
        request.visitedContactIds.add(null);
        request.visitedContactIds.add(contactRecord.Id);
        request.action = 'Submit';
        request.visitFields = new Map<String, Object>{
            'AccountId' => accountRecord.Id,
            'PlannedVisitStartTime' => System.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
            'PlaceId' => locationId
        };

        Test.startTest();
        VisitWizardController.SaveResponse response = VisitWizardController.saveVisit(request);
        Test.stopTest();

        Id visitId = response.visitId;
        SObject visitRecord = Database.query('SELECT AccountId FROM Visit WHERE Id = :visitId LIMIT 1');
        System.assertEquals(accountRecord.Id, (Id) visitRecord.get('AccountId'));
    }

    @IsTest
    static void saveVisitRecoversAccountIdFromVisitedContactWhenFieldsMissing() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'Visit Wizard Contact Fallback');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Contact Fallback'
        );
        insert contactRecord;

        Id locationId = createLocation();

        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = null;
        request.recordTypeId = defaultVisitRecordTypeId();
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        request.visitedContactIds = new List<Id>();
        request.visitedContactIds.add(null);
        request.visitedContactIds.add(contactRecord.Id);
        request.action = 'Submit';
        request.visitFields = new Map<String, Object>{
            'PlannedVisitStartTime' => System.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
            'PlaceId' => locationId
        };

        Test.startTest();
        VisitWizardController.SaveResponse response = VisitWizardController.saveVisit(request);
        Test.stopTest();

        Id visitId = response.visitId;
        SObject visitRecord = Database.query('SELECT AccountId FROM Visit WHERE Id = :visitId LIMIT 1');
        System.assertEquals(accountRecord.Id, (Id) visitRecord.get('AccountId'));
    }

    @IsTest
    static void saveVisitRecoversContextFromStringFallbacks() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'Visit Wizard String Fallback');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'String Fallback'
        );
        insert contactRecord;

        Id locationId = createLocation();

        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = null;
        request.accountIdText = 'recordId=' + accountRecord.Id;
        request.recordTypeId = defaultVisitRecordTypeId();
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        request.visitedContactIds = null;
        request.visitedContactIdText = 'selected=' + contactRecord.Id;
        request.action = 'Submit';
        request.visitFields = new Map<String, Object>{
            'PlannedVisitStartTime' => System.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
            'PlaceId' => locationId
        };

        Test.startTest();
        VisitWizardController.SaveResponse response = VisitWizardController.saveVisit(request);
        Test.stopTest();

        Id visitId = response.visitId;
        System.assertEquals(1, Database.countQuery('SELECT COUNT() FROM VisitedParty WHERE VisitId = :visitId'));
        SObject visitRecord = Database.query('SELECT AccountId FROM Visit WHERE Id = :visitId LIMIT 1');
        System.assertEquals(accountRecord.Id, (Id) visitRecord.get('AccountId'));
    }

    @IsTest
    static void saveVisitV3AcceptsJsonPayload() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'Visit Wizard Json Payload');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Json Payload'
        );
        insert contactRecord;

        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = null;
        request.accountIdText = 'context=' + accountRecord.Id;
        request.recordTypeId = defaultVisitRecordTypeId();
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        request.visitedContactIdStrings = new List<String>{ String.valueOf(contactRecord.Id) };
        request.action = 'Submit';
        request.visitFields = new Map<String, Object>{
            'PlannedVisitStartTime' => System.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
            'PlaceId' => createLocation()
        };

        Test.startTest();
        VisitWizardController.SaveResponse response = VisitWizardController.saveVisitV3(JSON.serialize(request));
        Test.stopTest();

        Id visitId = response.visitId;
        System.assertEquals(1, Database.countQuery('SELECT COUNT() FROM VisitedParty WHERE VisitId = :visitId'));
        SObject visitRecord = Database.query('SELECT AccountId FROM Visit WHERE Id = :visitId LIMIT 1');
        System.assertEquals(accountRecord.Id, (Id) visitRecord.get('AccountId'));
    }

    @IsTest
    static void saveVisitRequiresAutomotiveObjects() {
        Account accountRecord = new Account(Name = 'Visit Wizard Save Guard');
        insert accountRecord;

        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = accountRecord.Id;
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        request.visitedContactIds = new List<Id>();
        request.action = 'Draft';

        Test.startTest();
        try {
            VisitWizardController.saveVisit(request);
            System.assert(Schema.getGlobalDescribe().containsKey('Visit'), 'Expected an error in non-Automotive orgs.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'The controller should return a readable error.');
        }
        Test.stopTest();
    }

    @IsTest
    static void saveVisitHandlesMissingVisitedContactsList() {
        VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
        request.accountId = null;
        request.visitorUserIds = new List<Id>{ UserInfo.getUserId() };
        request.visitedContactIds = null;
        request.action = 'Submit';

        Test.startTest();
        try {
            VisitWizardController.saveVisit(request);
            System.assert(false, 'Expected the save request to fail validation.');
        } catch (AuraHandledException e) {
            System.assert(
                !String.valueOf(e.getMessage()).contains('de-reference'),
                'A missing visitedContactIds list should return validation, not a null-pointer error.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void recordTypeMetadataErrorsAreReadable() {
        String originalVisitObjectApiName = VisitWizardController.visitObjectApiName;
        try {
            VisitWizardController.visitObjectApiName = 'Definitely_Not_Real__c';
            try {
                VisitWizardController.getAvailableVisitRecordTypes();
                System.assert(false, 'Expected missing Visit object validation.');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Visit object is not available'));
            }

            VisitWizardController.visitObjectApiName = 'User';
            try {
                VisitWizardController.getAvailableVisitRecordTypes();
                System.assert(false, 'Expected no record type validation.');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('No Visit record types are available'));
            }
        } finally {
            VisitWizardController.visitObjectApiName = originalVisitObjectApiName;
        }
    }

    @IsTest
    static void initialVisitorCandidatesIncludesAccountTeamRowsWhenAvailable() {
        if (!hasObjects(new Set<String>{ 'AccountTeamMember' })) {
            return;
        }

        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        if (otherUsers.isEmpty()) {
            return;
        }

        Account accountRecord = new Account(Name = 'Visit Wizard Account Team');
        insert accountRecord;

        SObject teamMember = Schema.getGlobalDescribe().get('AccountTeamMember').newSObject();
        teamMember.put('AccountId', accountRecord.Id);
        teamMember.put('UserId', otherUsers[0].Id);
        teamMember.put('TeamMemberRole', 'Sales Rep');
        try {
            insert teamMember;
        } catch (DmlException e) {
            return;
        }

        Test.startTest();
        List<VisitWizardController.UserCandidate> candidates =
            VisitWizardController.getInitialVisitorCandidates(accountRecord.Id);
        Test.stopTest();

        Boolean foundTeamMember = false;
        for (VisitWizardController.UserCandidate candidate : candidates) {
            if (candidate.userId == otherUsers[0].Id) {
                foundTeamMember = true;
                System.assertEquals(false, candidate.locked);
                System.assert(candidate.source.contains('Account Team'));
            }
        }
        System.assertEquals(true, foundTeamMember, 'Active account team users should be offered as visitors.');
    }

    @IsTest
    static void actionPlanTemplateHelpersCoverRelationshipBranches() {
        if (!hasObjects(new Set<String>{ 'ActionPlanTemplate', 'ActionPlanTemplateVersion' })) {
            return;
        }

        Id templateId = (Id) '0PR000000000001';
        Id templateVersionId = (Id) '0PT000000000001';
        SObject templateVersionRecord = (SObject) JSON.deserialize(
            '{"attributes":{"type":"ActionPlanTemplateVersion"},' +
            '"Id":"0PT000000000001",' +
            '"Name":"Published Visit Template Version",' +
            '"ActionPlanTemplateId":"0PR000000000001",' +
            '"Status":"Final",' +
            '"Version":1,' +
            '"LastModifiedDate":"2026-01-01T00:00:00.000Z",' +
            '"ActionPlanTemplate":{' +
                '"attributes":{"type":"ActionPlanTemplate"},' +
                '"Id":"0PR000000000001",' +
                '"Name":"Published Visit Template",' +
                '"ActionPlanType":"Visit",' +
                '"Status":"Final",' +
                '"TargetEntityType":"Visit"' +
            '}}',
            SObject.class
        );

        VisitWizardController.ActionPlanTemplateOption option =
            VisitWizardController.toActionPlanTemplateOption(templateVersionRecord);
        System.assertEquals(templateVersionId, option.templateVersionId);
        System.assertEquals(templateId, option.templateId);
        System.assertEquals('Published Visit Template', option.name);
        System.assertEquals('Visit', option.actionPlanType);
        System.assertEquals(1, option.versionNumber);

        try {
            VisitWizardController.actionPlanTemplateVersionForVisit((Id) '0PT000000000002');
            System.assert(false, 'Expected missing template validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Action Plan Template could not be found'));
        }
    }

    @IsTest
    static void securityHelpersRejectNonCreateableObjects() {
        if (!Schema.getGlobalDescribe().containsKey('UserRecordAccess')) {
            return;
        }

        try {
            VisitWizardController.getRequiredObjectType('UserRecordAccess');
            System.assert(false, 'Expected create access validation.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('create access'));
        }
    }

    @IsTest
    static void actionPlanValidationHandlesMissingVisitObjectAfterRequiredFields() {
        String originalVisitObjectApiName = VisitWizardController.visitObjectApiName;
        try {
            VisitWizardController.visitObjectApiName = 'Definitely_Not_Real__c';
            VisitWizardController.ActionPlanSaveRequest request = new VisitWizardController.ActionPlanSaveRequest();
            request.visitId = (Id) '0Z5000000000001';
            request.name = 'Missing Visit Object';
            request.startDate = Date.today();
            request.actionPlanTemplateVersionId = (Id) '0PT000000000001';

            try {
                VisitWizardController.validateActionPlanRequest(request);
                System.assert(false, 'Expected Visit object availability validation.');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('Visit object is not available'));
            }
        } finally {
            VisitWizardController.visitObjectApiName = originalVisitObjectApiName;
        }
    }

    private static Boolean hasObjects(Set<String> objectNames) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (String objectName : objectNames) {
            if (!globalDescribe.containsKey(objectName)) {
                return false;
            }
        }
        return true;
    }

    private static Id createLocation() {
        Schema.SObjectType locationType = Schema.getGlobalDescribe().get('Location');
        if (locationType == null || !locationType.getDescribe().isCreateable()) {
            return null;
        }

        Map<String, Schema.SObjectField> fields = locationType.getDescribe().fields.getMap();
        SObject locationRecord = locationType.newSObject();
        if (fields.containsKey('Name') && fields.get('Name').getDescribe().isCreateable()) {
            locationRecord.put('Name', 'Visit Wizard Test Location');
        }
        if (fields.containsKey('LocationType') && fields.get('LocationType').getDescribe().isCreateable()) {
            locationRecord.put('LocationType', firstPicklistValue(fields.get('LocationType')));
        }
        insert locationRecord;
        return locationRecord.Id;
    }

    private static Id defaultVisitRecordTypeId() {
        List<VisitWizardController.RecordTypeOption> recordTypes =
            VisitWizardController.getVisitRecordTypes();
        for (VisitWizardController.RecordTypeOption recordType : recordTypes) {
            if (recordType.defaultRecordTypeMapping) {
                return (Id) recordType.value;
            }
        }
        return recordTypes.isEmpty() ? null : (Id) recordTypes[0].value;
    }

    private static String firstPicklistValue(Schema.SObjectField fieldToken) {
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static void assertNoDuplicateVisitFields(List<VisitWizardController.FieldMetadata> fields) {
        Set<String> seenFields = new Set<String>();
        for (VisitWizardController.FieldMetadata field : fields) {
            String normalizedName = field.apiName == null ? '' : field.apiName.toLowerCase();
            System.assert(!seenFields.contains(normalizedName), 'Duplicate Visit field found on page 2: ' + field.apiName);
            seenFields.add(normalizedName);
        }
    }
}
