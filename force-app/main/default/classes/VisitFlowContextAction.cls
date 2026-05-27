public inherited sharing class VisitFlowContextAction {
    public class Request {
        @InvocableVariable(label='Account Id' required=true)
        public Id accountId;
    }

    public class Response {
        @InvocableVariable(label='Account Id')
        public Id accountId;

        @InvocableVariable(label='Account Name')
        public String accountName;

        @InvocableVariable(label='Account Owner Id')
        public Id accountOwnerId;

        @InvocableVariable(label='Account Owner Name')
        public String accountOwnerName;

        @InvocableVariable(label='Account Team User Ids')
        public List<String> accountTeamUserIds;

        @InvocableVariable(label='Account Team Summary')
        public String accountTeamSummary;

        @InvocableVariable(label='Available Visit Record Type Ids')
        public List<String> availableRecordTypeIds;

        @InvocableVariable(label='Default Visit Record Type Id')
        public Id defaultRecordTypeId;

        @InvocableVariable(label='Has Visit Record Types')
        public Boolean hasVisitRecordTypes;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Get Visit Flow Context'
        description='Returns Account, Account Team, and user-available Visit record type context for the V5 Visit Screen Flow.'
    )
    public static List<Response> getContext(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null) {
            return responses;
        }

        for (Request request : requests) {
            responses.add(buildResponse(request));
        }
        return responses;
    }

    private static Response buildResponse(Request request) {
        Response response = new Response();
        response.accountTeamUserIds = new List<String>();
        response.availableRecordTypeIds = new List<String>();
        response.hasVisitRecordTypes = false;

        if (request == null || request.accountId == null) {
            response.errorMessage = 'Account Id is required.';
            return response;
        }

        List<Account> accounts = [
            SELECT Id, Name, OwnerId, Owner.Name
            FROM Account
            WHERE Id = :request.accountId
            WITH USER_MODE
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            response.errorMessage = 'The source Account could not be found.';
            return response;
        }

        Account accountRecord = accounts[0];
        response.accountId = accountRecord.Id;
        response.accountName = accountRecord.Name;
        response.accountOwnerId = accountRecord.OwnerId;
        response.accountOwnerName = accountRecord.Owner == null ? null : accountRecord.Owner.Name;

        Map<Id, String> teamNamesByUserId = new Map<Id, String>();
        if (accountRecord.OwnerId != null) {
            teamNamesByUserId.put(accountRecord.OwnerId, accountDisplayName(response.accountOwnerName, accountRecord.OwnerId, 'Owner'));
        }

        for (AccountTeamMember teamMember : [
            SELECT UserId, User.Name, TeamMemberRole
            FROM AccountTeamMember
            WHERE AccountId = :accountRecord.Id
            AND User.IsActive = true
            WITH USER_MODE
            ORDER BY User.Name
        ]) {
            String role = String.isBlank(teamMember.TeamMemberRole) ? 'Account Team' : teamMember.TeamMemberRole;
            teamNamesByUserId.put(teamMember.UserId, accountDisplayName(teamMember.User.Name, teamMember.UserId, role));
        }

        List<String> summaryLines = new List<String>();
        for (Id userId : teamNamesByUserId.keySet()) {
            response.accountTeamUserIds.add(String.valueOf(userId));
            summaryLines.add(teamNamesByUserId.get(userId));
        }
        response.accountTeamSummary = summaryLines.isEmpty()
            ? 'No active Account Team users were found. The Account owner is still included automatically when available.'
            : String.join(summaryLines, '\n');

        populateRecordTypeContext(response);
        return response;
    }

    private static String accountDisplayName(String name, Id userId, String source) {
        String displayName = String.isBlank(name) ? String.valueOf(userId) : name;
        return displayName + ' (' + source + ')';
    }

    private static void populateRecordTypeContext(Response response) {
        Schema.SObjectType visitType = Schema.getGlobalDescribe().get('Visit');
        if (visitType == null) {
            response.errorMessage = 'The Visit object is not available in this org. Enable Automotive Cloud Visit Management before using this flow.';
            return;
        }

        for (Schema.RecordTypeInfo info : visitType.getDescribe().getRecordTypeInfos()) {
            if (info.isMaster() || !info.isAvailable() || !info.isActive()) {
                continue;
            }

            String recordTypeId = String.valueOf(info.getRecordTypeId());
            response.availableRecordTypeIds.add(recordTypeId);
            if (info.isDefaultRecordTypeMapping()) {
                response.defaultRecordTypeId = info.getRecordTypeId();
            }
        }

        if (response.defaultRecordTypeId == null && !response.availableRecordTypeIds.isEmpty()) {
            response.defaultRecordTypeId = (Id) response.availableRecordTypeIds[0];
        }

        response.hasVisitRecordTypes = !response.availableRecordTypeIds.isEmpty();
        if (!response.hasVisitRecordTypes) {
            response.errorMessage = 'No Visit record types are available for your user. Ask your Salesforce admin to assign a Visit record type.';
        }
    }
}
