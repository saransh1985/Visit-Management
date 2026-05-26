Contact contactRecord = [
    SELECT Id, AccountId
    FROM Contact
    WHERE AccountId != null
    LIMIT 1
];
Id accountId = contactRecord.AccountId;
Id recordTypeId = [
    SELECT Id
    FROM RecordType
    WHERE SobjectType = 'Visit'
    AND IsActive = true
    LIMIT 1
].Id;
Id ownerUserId = UserInfo.getUserId();
Id contactId = contactRecord.Id;
Id placeId = [
    SELECT Id
    FROM Location
    LIMIT 1
].Id;
Id visitId;

try {
    VisitWizardController.SaveRequest request = new VisitWizardController.SaveRequest();
    request.accountId = null;
    request.accountIdText = 'recordId=' + accountId;
    request.sourceAccountId = 'source=' + accountId;
    request.recordTypeId = recordTypeId;
    request.visitorUserIds = new List<Id>{ ownerUserId };
    request.visitedContactIds = null;
    request.visitedContactIdStrings = new List<String>{ String.valueOf(contactId) };
    request.visitedContactIdText = 'selected=' + contactId;
    request.action = 'Submit';
    request.visitFields = new Map<String, Object>{
        'PlannedVisitStartTime' => System.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
        'PlannedVisitEndTime' => System.now().addDays(1).addHours(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
        'PlaceId' => placeId
    };

    VisitWizardController.SaveResponse response = VisitWizardController.saveVisitV3(JSON.serialize(request));
    visitId = response.visitId;

    SObject visitRecord = Database.query('SELECT Id, AccountId FROM Visit WHERE Id = :visitId LIMIT 1');
    System.assertEquals(accountId, (Id) visitRecord.get('AccountId'), 'Visit should be tied to the source account.');

    Integer visitorCount = Database.countQuery('SELECT COUNT() FROM Visitor WHERE VisitId = :visitId AND AssigneeId = :ownerUserId');
    System.assertEquals(1, visitorCount, 'Visitor should be tied to the created Visit.');

    Integer visitedPartyCount = Database.countQuery('SELECT COUNT() FROM VisitedParty WHERE VisitId = :visitId AND ContactId = :contactId');
    System.assertEquals(1, visitedPartyCount, 'Visited party should be tied to the created Visit.');

    System.debug('VISIT_WIZARD_PROBE_SUCCESS visitId=' + visitId);
} finally {
    if (visitId != null) {
        Database.delete(Database.query('SELECT Id FROM VisitedParty WHERE VisitId = :visitId'), false);
        Database.delete(Database.query('SELECT Id FROM Visitor WHERE VisitId = :visitId'), false);
        Database.delete(Database.query('SELECT Id FROM Visit WHERE Id = :visitId'), false);
    }
}
