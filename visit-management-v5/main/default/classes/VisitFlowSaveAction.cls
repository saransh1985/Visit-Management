public inherited sharing class VisitFlowSaveAction {
    public class Request {
        @InvocableVariable(label='Account Id' required=true)
        public Id accountId;

        @InvocableVariable(label='Visit Record Type Id' required=true)
        public Id recordTypeId;

        @InvocableVariable(label='Place Id' required=true)
        public Id placeId;

        @InvocableVariable(label='Planned Start Time' required=true)
        public Datetime plannedVisitStartTime;

        @InvocableVariable(label='Planned End Time')
        public Datetime plannedVisitEndTime;

        @InvocableVariable(label='Visit Priority')
        public String visitPriority;

        @InvocableVariable(label='Status Remarks')
        public String statusRemarks;

        @InvocableVariable(label='Special Instructions')
        public String instructionDescription;

        @InvocableVariable(label='Selected Account Team Visitor Ids')
        public String accountTeamVisitorIds;

        @InvocableVariable(label='Additional Visitor Ids')
        public String additionalVisitorIds;

        @InvocableVariable(label='Visited Contact Ids' required=true)
        public String visitedContactIds;
    }

    public class Response {
        @InvocableVariable(label='Visit Id')
        public Id visitId;

        @InvocableVariable(label='Visit URL')
        public String visitUrl;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Create Visit From Flow'
        description='Creates a Visit, Visitor records, and Visited Party records from the V5 Visit Screen Flow.'
    )
    public static List<Response> createVisit(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null) {
            return responses;
        }

        for (Request request : requests) {
            responses.add(createOne(request));
        }
        return responses;
    }

    private static Response createOne(Request request) {
        validateRequest(request);
        assertRecordTypeAvailable(request.recordTypeId);

        List<Id> visitorIds = new List<Id>();
        visitorIds.add(accountOwnerId(request.accountId));
        visitorIds.addAll(parseIds(request.accountTeamVisitorIds, '005'));
        visitorIds.addAll(parseIds(request.additionalVisitorIds, '005'));

        Map<String, Object> visitFields = new Map<String, Object>{
            'AccountId' => request.accountId,
            'PlaceId' => request.placeId,
            'PlannedVisitStartTime' => request.plannedVisitStartTime
        };

        if (request.plannedVisitEndTime != null) {
            visitFields.put('PlannedVisitEndTime', request.plannedVisitEndTime);
        }
        putIfNotBlank(visitFields, 'VisitPriority', request.visitPriority);
        putIfNotBlank(visitFields, 'StatusRemarks', request.statusRemarks);
        putIfNotBlank(visitFields, 'InstructionDescription', request.instructionDescription);

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => request.accountId,
            'recordTypeId' => request.recordTypeId,
            'visitFields' => visitFields,
            'visitorUserIds' => visitorIds,
            'visitedContactIds' => parseIds(request.visitedContactIds, '003'),
            'action' => 'Submit'
        };

        VisitWizardController.SaveResponse saveResponse = VisitWizardController.saveVisitV3(JSON.serialize(payload));

        Response response = new Response();
        response.visitId = saveResponse.visitId;
        response.visitUrl = '/' + String.valueOf(saveResponse.visitId);
        response.message = saveResponse.message;
        return response;
    }

    private static void validateRequest(Request request) {
        if (request == null) {
            throw new VisitFlowException('Save request is required.');
        }
        if (request.accountId == null) {
            throw new VisitFlowException('Account Id is required.');
        }
        if (request.recordTypeId == null) {
            throw new VisitFlowException('Visit Record Type is required.');
        }
        if (request.placeId == null) {
            throw new VisitFlowException('Place is required.');
        }
        if (request.plannedVisitStartTime == null) {
            throw new VisitFlowException('Planned Start Time is required.');
        }
        if (parseIds(request.visitedContactIds, '003').isEmpty()) {
            throw new VisitFlowException('Select at least one visited party before finishing.');
        }
    }

    private static void assertRecordTypeAvailable(Id recordTypeId) {
        Schema.SObjectType visitType = Schema.getGlobalDescribe().get('Visit');
        if (visitType == null) {
            throw new VisitFlowException('The Visit object is not available in this org. Enable Automotive Cloud Visit Management before using this flow.');
        }

        for (Schema.RecordTypeInfo info : visitType.getDescribe().getRecordTypeInfos()) {
            if (info.getRecordTypeId() == recordTypeId && !info.isMaster() && info.isAvailable() && info.isActive()) {
                return;
            }
        }
        throw new VisitFlowException('The selected Visit record type is not available for your user.');
    }

    private static Id accountOwnerId(Id accountId) {
        List<Account> accounts = [
            SELECT OwnerId
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];
        if (accounts.isEmpty() || accounts[0].OwnerId == null) {
            throw new VisitFlowException('The source Account could not be found or does not have an owner.');
        }
        return accounts[0].OwnerId;
    }

    private static void putIfNotBlank(Map<String, Object> valuesByFieldName, String fieldName, String value) {
        if (String.isNotBlank(value)) {
            valuesByFieldName.put(fieldName, value);
        }
    }

    @TestVisible
    private static List<Id> parseIds(String rawValue, String prefix) {
        List<Id> ids = new List<Id>();
        if (String.isBlank(rawValue) || String.isBlank(prefix)) {
            return ids;
        }

        Matcher matcher = Pattern.compile(prefix + '[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?').matcher(rawValue);
        Set<Id> seenIds = new Set<Id>();
        while (matcher.find()) {
            Id parsedId = (Id) matcher.group(0);
            if (!seenIds.contains(parsedId)) {
                seenIds.add(parsedId);
                ids.add(parsedId);
            }
        }
        return ids;
    }

    public class VisitFlowException extends Exception {
    }
}
