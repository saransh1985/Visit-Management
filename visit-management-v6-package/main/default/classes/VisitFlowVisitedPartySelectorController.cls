public inherited sharing class VisitFlowVisitedPartySelectorController {
    public class ContactOption {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String email;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContactOption> getAccountContacts(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }

        List<ContactOption> options = new List<ContactOption>();
        for (Contact contactRecord : [
            SELECT Id, Name, Title, Email
            FROM Contact
            WHERE AccountId = :accountId
            WITH USER_MODE
            ORDER BY Name
            LIMIT 200
        ]) {
            ContactOption option = new ContactOption();
            option.contactId = contactRecord.Id;
            option.name = contactRecord.Name;
            option.title = contactRecord.Title;
            option.email = contactRecord.Email;
            options.add(option);
        }
        return options;
    }
}
