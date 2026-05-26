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
    static void saveActionPlanValidatesRequiredFields() {
        if (!hasObjects(new Set<String>{ 'ActionPlan' })) {
            return;
        }

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
