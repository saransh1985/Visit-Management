public inherited sharing class VisitFlowUserSelectorController {
    public class UserOption {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String email;
        @AuraEnabled public String username;
        @AuraEnabled public String source;
        @AuraEnabled public Boolean owner;
    }

    @AuraEnabled(cacheable=true)
    public static List<UserOption> getAccountTeamUsers(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }

        List<Account> accounts = [
            SELECT Id, OwnerId, Owner.Name, Owner.Title, Owner.Email, Owner.Username
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new AuraHandledException('The source Account could not be found.');
        }

        Account accountRecord = accounts[0];
        List<UserOption> options = new List<UserOption>();
        Set<Id> includedUserIds = new Set<Id>();
        if (accountRecord.OwnerId != null) {
            options.add(toOption(accountRecord.Owner, 'Owner', true));
            includedUserIds.add(accountRecord.OwnerId);
        }

        for (AccountTeamMember teamMember : [
            SELECT UserId, TeamMemberRole, User.Name, User.Title, User.Email, User.Username
            FROM AccountTeamMember
            WHERE AccountId = :accountRecord.Id
            AND User.IsActive = true
            WITH USER_MODE
            ORDER BY User.Name
        ]) {
            if (includedUserIds.contains(teamMember.UserId)) {
                continue;
            }
            String source = String.isBlank(teamMember.TeamMemberRole) ? 'Account Team' : teamMember.TeamMemberRole;
            options.add(toOption(teamMember.User, source, false));
            includedUserIds.add(teamMember.UserId);
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<UserOption> searchActiveUsers(String searchTerm, List<Id> excludeUserIds) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<UserOption>();
        }

        Set<Id> excludedIds = excludeUserIds == null ? new Set<Id>() : new Set<Id>(excludeUserIds);
        String likeTerm = '%' + searchTerm.trim() + '%';
        List<UserOption> options = new List<UserOption>();
        for (User userRecord : [
            SELECT Id, Name, Title, Email, Username
            FROM User
            WHERE IsActive = true
            AND Id NOT IN :excludedIds
            AND (
                Name LIKE :likeTerm
                OR Email LIKE :likeTerm
                OR Username LIKE :likeTerm
            )
            WITH USER_MODE
            ORDER BY Name
            LIMIT 10
        ]) {
            options.add(toOption(userRecord, 'Search Result', false));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<UserOption> getUsersByIds(List<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new List<UserOption>();
        }

        Set<Id> requestedIds = new Set<Id>(userIds);
        List<UserOption> options = new List<UserOption>();
        for (User userRecord : [
            SELECT Id, Name, Title, Email, Username
            FROM User
            WHERE Id IN :requestedIds
            AND IsActive = true
            WITH USER_MODE
            ORDER BY Name
        ]) {
            options.add(toOption(userRecord, 'Selected User', false));
        }
        return options;
    }

    private static UserOption toOption(User userRecord, String source, Boolean owner) {
        UserOption option = new UserOption();
        option.userId = userRecord.Id;
        option.name = userRecord.Name;
        option.title = userRecord.Title;
        option.email = userRecord.Email;
        option.username = userRecord.Username;
        option.source = source;
        option.owner = owner;
        return option;
    }
}
