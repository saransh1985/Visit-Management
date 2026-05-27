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
    static void visitorSelectorReturnsOwnerAndSearchesActiveUsers() {
        Account accountRecord = new Account(Name = 'Visit Flow Visitor Selector Account');
        insert accountRecord;

        User currentUser = [
            SELECT Id, Username
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String usernameSearch = currentUser.Username.left(Math.min(4, currentUser.Username.length()));

        Test.startTest();
        List<VisitFlowUserSelectorController.UserOption> teamUsers =
            VisitFlowUserSelectorController.getAccountTeamUsers(accountRecord.Id);
        List<VisitFlowUserSelectorController.UserOption> searchResults =
            VisitFlowUserSelectorController.searchActiveUsers(usernameSearch, new List<Id>());
        List<VisitFlowUserSelectorController.UserOption> hydratedUsers =
            VisitFlowUserSelectorController.getUsersByIds(new List<Id>{ currentUser.Id });
        List<VisitFlowUserSelectorController.UserOption> shortSearchResults =
            VisitFlowUserSelectorController.searchActiveUsers('a', new List<Id>());
        List<VisitFlowUserSelectorController.UserOption> emptyHydratedUsers =
            VisitFlowUserSelectorController.getUsersByIds(new List<Id>());
        Test.stopTest();

        System.assert(!teamUsers.isEmpty(), 'The Account owner should be returned as a selected visitor option.');
        System.assertEquals(currentUser.Id, teamUsers[0].userId);
        System.assertEquals(true, teamUsers[0].owner);
        System.assert(!searchResults.isEmpty(), 'Active user search should find the running user by username.');
        System.assertEquals(1, hydratedUsers.size(), 'Selected user hydration should return active users by id.');
        System.assertEquals(0, shortSearchResults.size(), 'Short search terms should not return all active users.');
        System.assertEquals(0, emptyHydratedUsers.size(), 'Empty hydration requests should return no users.');
    }

    @IsTest
    static void visitedPartySelectorReturnsOnlyAccountContacts() {
        Account accountRecord = new Account(Name = 'Visit Flow Visited Party Account');
        Account otherAccount = new Account(Name = 'Visit Flow Other Visited Party Account');
        insert new List<Account>{ accountRecord, otherAccount };

        Contact accountContact = new Contact(AccountId = accountRecord.Id, LastName = 'Flow Contact');
        Contact otherContact = new Contact(AccountId = otherAccount.Id, LastName = 'Other Contact');
        insert new List<Contact>{ accountContact, otherContact };

        Test.startTest();
        List<VisitFlowVisitedPartySelectorController.ContactOption> options =
            VisitFlowVisitedPartySelectorController.getAccountContacts(accountRecord.Id);
        Test.stopTest();

        System.assertEquals(1, options.size(), 'Visited party options should be scoped to the source Account.');
        System.assertEquals(accountContact.Id, options[0].contactId);
    }

    @IsTest
    static void actionPlanFlowActionValidatesRequiredInputsBeforeDml() {
        System.assertEquals(0, VisitFlowActionPlanSaveAction.createActionPlan(null).size());

        try {
            VisitFlowActionPlanSaveAction.createActionPlan(
                new List<VisitFlowActionPlanSaveAction.Request>{ null }
            );
            System.assert(false, 'Expected null Action Plan request validation.');
        } catch (VisitFlowActionPlanSaveAction.VisitFlowActionPlanException e) {
            System.assert(e.getMessage().contains('Action Plan request is required'));
        }

        VisitFlowActionPlanSaveAction.Request request = new VisitFlowActionPlanSaveAction.Request();
        try {
            VisitFlowActionPlanSaveAction.createActionPlan(new List<VisitFlowActionPlanSaveAction.Request>{ request });
            System.assert(false, 'Expected required Action Plan target validation.');
        } catch (VisitFlowActionPlanSaveAction.VisitFlowActionPlanException e) {
            System.assert(e.getMessage().contains('Target Record is required'));
        }

        request.visitId = (Id) '0Z5000000000001';
        try {
            VisitFlowActionPlanSaveAction.createActionPlan(new List<VisitFlowActionPlanSaveAction.Request>{ request });
            System.assert(false, 'Expected required Action Plan name validation.');
        } catch (VisitFlowActionPlanSaveAction.VisitFlowActionPlanException e) {
            System.assert(e.getMessage().contains('Action Plan Name is required'));
        }

        request.name = 'Flow Action Plan';
        try {
            VisitFlowActionPlanSaveAction.createActionPlan(new List<VisitFlowActionPlanSaveAction.Request>{ request });
            System.assert(false, 'Expected required Action Plan start date validation.');
        } catch (VisitFlowActionPlanSaveAction.VisitFlowActionPlanException e) {
            System.assert(e.getMessage().contains('Start Date is required'));
        }

        request.startDate = Date.today();
        try {
            VisitFlowActionPlanSaveAction.createActionPlan(new List<VisitFlowActionPlanSaveAction.Request>{ request });
            System.assert(false, 'Expected required Action Plan template validation.');
        } catch (VisitFlowActionPlanSaveAction.VisitFlowActionPlanException e) {
            System.assert(e.getMessage().contains('Action Plan Template is required'));
        }

        request.actionPlanTemplateVersionId = (Id) '0PT000000000001';
        request.status = 'Not Started';
        try {
            VisitFlowActionPlanSaveAction.createActionPlan(
                new List<VisitFlowActionPlanSaveAction.Request>{ request }
            );
            System.assert(false, 'Expected existing controller validation before Action Plan DML.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'Controller errors should remain readable.');
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
