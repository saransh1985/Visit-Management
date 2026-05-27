@IsTest
private class VisitFlowActionsTest {
    @IsTest
    static void contextActionReturnsAccountAndVisitRecordTypeContext() {
        Account accountRecord = new Account(Name = 'Visit Flow Context Account');
        insert accountRecord;

        VisitFlowContextAction.Request request = new VisitFlowContextAction.Request();
        request.accountId = accountRecord.Id;

        Test.startTest();
        List<VisitFlowContextAction.Response> responses = VisitFlowContextAction.getContext(
            new List<VisitFlowContextAction.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(accountRecord.Id, responses[0].accountId);
        System.assertEquals('Visit Flow Context Account', responses[0].accountName);
        System.assert(responses[0].accountTeamUserIds.contains(UserInfo.getUserId()));
        if (Schema.getGlobalDescribe().containsKey('Visit')) {
            System.assertEquals(true, responses[0].hasVisitRecordTypes);
            System.assert(!responses[0].availableRecordTypeIds.isEmpty());
        }
    }

    @IsTest
    static void saveActionValidatesRequiredInputsBeforeDml() {
        try {
            VisitFlowSaveAction.createVisit(new List<VisitFlowSaveAction.Request>{ new VisitFlowSaveAction.Request() });
            System.assert(false, 'Expected required input validation.');
        } catch (VisitFlowSaveAction.VisitFlowException e) {
            System.assert(e.getMessage().contains('Account Id is required'));
        }
    }

    @IsTest
    static void saveActionCreatesVisitGraphWhenAutomotiveObjectsExist() {
        if (!hasObjects(new Set<String>{ 'Visit', 'Visitor', 'VisitedParty', 'Location' })) {
            return;
        }

        Account accountRecord = new Account(Name = 'Visit Flow Save Account');
        insert accountRecord;

        Contact contactRecord = new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Flow Visited Party'
        );
        insert contactRecord;

        Id locationId = createLocation();
        System.assertNotEquals(null, locationId, 'A test Location should be available for Visit.PlaceId.');

        VisitFlowSaveAction.Request request = new VisitFlowSaveAction.Request();
        request.accountId = accountRecord.Id;
        request.recordTypeId = defaultVisitRecordTypeId();
        request.placeId = locationId;
        request.plannedVisitStartTime = System.now().addDays(1);
        request.plannedVisitEndTime = System.now().addDays(1).addHours(1);
        request.additionalVisitorIds = String.valueOf(UserInfo.getUserId());
        request.visitedContactIds = String.valueOf(contactRecord.Id);

        Test.startTest();
        List<VisitFlowSaveAction.Response> responses = VisitFlowSaveAction.createVisit(
            new List<VisitFlowSaveAction.Request>{ request }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertNotEquals(null, responses[0].visitId);

        Id visitId = responses[0].visitId;
        System.assertEquals(1, Database.countQuery('SELECT COUNT() FROM Visit WHERE Id = :visitId'));
        System.assertEquals(1, Database.countQuery('SELECT COUNT() FROM Visitor WHERE VisitId = :visitId'));
        System.assertEquals(1, Database.countQuery('SELECT COUNT() FROM VisitedParty WHERE VisitId = :visitId'));
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
            locationRecord.put('Name', 'Visit Flow Test Location');
        }
        if (fields.containsKey('LocationType') && fields.get('LocationType').getDescribe().isCreateable()) {
            locationRecord.put('LocationType', firstPicklistValue(fields.get('LocationType')));
        }
        insert locationRecord;
        return locationRecord.Id;
    }

    private static Id defaultVisitRecordTypeId() {
        List<VisitWizardController.RecordTypeOption> recordTypes = VisitWizardController.getVisitRecordTypes();
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
}
