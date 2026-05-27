public inherited sharing class VisitFlowActionPlanSaveAction {
    public class Request {
        @InvocableVariable(label='Visit Id' required=true)
        public Id visitId;

        @InvocableVariable(label='Target Record Id')
        public Id targetRecordId;

        @InvocableVariable(label='Name' required=true)
        public String name;

        @InvocableVariable(label='Start Date' required=true)
        public Date startDate;

        @InvocableVariable(label='Action Plan Template Version Id' required=true)
        public Id actionPlanTemplateVersionId;

        @InvocableVariable(label='Status')
        public String status;
    }

    public class Response {
        @InvocableVariable(label='Action Plan Id')
        public Id actionPlanId;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Create Visit Action Plan From Flow'
        description='Creates an Action Plan attached to a Visit created by the V5 Visit Screen Flow.'
    )
    public static List<Response> createActionPlan(List<Request> requests) {
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

        Map<String, Object> payload = new Map<String, Object>{
            'visitId' => request.visitId,
            'targetRecordId' => request.targetRecordId == null ? request.visitId : request.targetRecordId,
            'name' => request.name,
            'startDate' => String.valueOf(request.startDate),
            'actionPlanTemplateVersionId' => request.actionPlanTemplateVersionId,
            'status' => request.status
        };

        VisitWizardController.ActionPlanSaveResponse saveResponse =
            VisitWizardController.saveActionPlan(JSON.serialize(payload));

        Response response = new Response();
        response.actionPlanId = saveResponse.actionPlanId;
        response.message = saveResponse.message;
        return response;
    }

    private static void validateRequest(Request request) {
        if (request == null) {
            throw new VisitFlowActionPlanException('Action Plan request is required.');
        }
        if (request.visitId == null) {
            throw new VisitFlowActionPlanException('Target Record is required.');
        }
        if (String.isBlank(request.name)) {
            throw new VisitFlowActionPlanException('Action Plan Name is required.');
        }
        if (request.startDate == null) {
            throw new VisitFlowActionPlanException('Start Date is required.');
        }
        if (request.actionPlanTemplateVersionId == null) {
            throw new VisitFlowActionPlanException('Action Plan Template is required.');
        }
    }

    public class VisitFlowActionPlanException extends Exception {
    }
}
