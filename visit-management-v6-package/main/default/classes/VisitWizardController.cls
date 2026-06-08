public inherited sharing class VisitWizardController {
    private static final String VISIT_OBJECT = 'Visit';
    private static final String VISITOR_OBJECT = 'Visitor';
    private static final String VISITED_PARTY_OBJECT = 'VisitedParty';
    private static final String ACTION_PLAN_OBJECT = 'ActionPlan';
    private static final String ACTION_PLAN_TEMPLATE_VERSION_OBJECT = 'ActionPlanTemplateVersion';
    @TestVisible private static String visitObjectApiName = VISIT_OBJECT;
    @TestVisible private static String visitorObjectApiName = VISITOR_OBJECT;
    @TestVisible private static String visitedPartyObjectApiName = VISITED_PARTY_OBJECT;
    @TestVisible private static String actionPlanObjectApiName = ACTION_PLAN_OBJECT;
    @TestVisible private static String visitAccountFieldApiName = 'AccountId';
    @TestVisible private static String visitVisitorFieldApiName = 'VisitorId';
    @TestVisible private static String visitorVisitFieldApiName = 'VisitId';
    @TestVisible private static String visitorAssigneeFieldApiName = 'AssigneeId';
    @TestVisible private static String visitedPartyVisitFieldApiName = 'VisitId';
    @TestVisible private static String visitedPartyContactFieldApiName = 'ContactId';
    @TestVisible private static SObject testActionPlanTemplateVersionForVisit;
    @TestVisible private static Boolean testForceAddressSearchFallback = false;
    @TestVisible private static Boolean testForceAccountAddressSearchFallback = false;
    @TestVisible private static Boolean testForceAccountAddressSearchEmptyFallback = false;
    @TestVisible private static Boolean testForceDefaultAccountAddressFallback = false;
    @TestVisible private static Boolean testForceAddressInfoFallback = false;
    @TestVisible private static Boolean testForceAccountInfoFallback = false;
    @TestVisible private static Boolean testForceAccountTeamFallback = false;

    public class RecordTypeOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String developerName;
        @AuraEnabled public Boolean defaultRecordTypeMapping;
        @AuraEnabled public Boolean master;
    }

    public class FieldMetadata {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean required;
        @AuraEnabled public String value;
    }

    public class AccountInfo {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String customerAccountNumber;
        @AuraEnabled public AddressCandidate defaultAddress;
    }

    public class AccountCandidate {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String customerAccountNumber;
        @AuraEnabled public String dealerCode;
    }

    public class AddressCandidate {
        @AuraEnabled public Id addressId;
        @AuraEnabled public String name;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        @AuraEnabled public String displayAddress;
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class UserCandidate {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String title;
        @AuraEnabled public String department;
        @AuraEnabled public String role;
        @AuraEnabled public String source;
        @AuraEnabled public Boolean selected;
        @AuraEnabled public Boolean locked;
    }

    public class ContactCandidate {
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String title;
    }

    public class SaveRequest {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountIdText;
        @AuraEnabled public String sourceAccountId;
        @AuraEnabled public Id recordTypeId;
        @AuraEnabled public Map<String, Object> visitFields;
        @AuraEnabled public List<Id> visitorUserIds;
        @AuraEnabled public List<Id> visitedContactIds;
        @AuraEnabled public List<String> visitedContactIdStrings;
        @AuraEnabled public String visitedContactIdText;
        @AuraEnabled public String action;
    }

    public class SaveResponse {
        @AuraEnabled public Id visitId;
        @AuraEnabled public String message;
    }

    public class ActionPlanTemplateOption {
        @AuraEnabled public Id templateVersionId;
        @AuraEnabled public Id templateId;
        @AuraEnabled public String name;
        @AuraEnabled public String templateName;
        @AuraEnabled public String status;
        @AuraEnabled public String actionPlanType;
        @AuraEnabled public Integer versionNumber;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    public class ActionPlanStartInfo {
        @AuraEnabled public String targetRecordId;
        @AuraEnabled public List<PicklistOption> statusOptions;
        @AuraEnabled public String defaultStatus;
        @AuraEnabled public List<ActionPlanTemplateOption> recentTemplates;
    }

    public class ActionPlanSaveRequest {
        @AuraEnabled public Id visitId;
        @AuraEnabled public Id targetRecordId;
        @AuraEnabled public String name;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Id actionPlanTemplateVersionId;
        @AuraEnabled public String status;
    }

    public class ActionPlanSaveResponse {
        @AuraEnabled public Id actionPlanId;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordTypeOption> getVisitRecordTypes() {
        return getAvailableVisitRecordTypes();
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordTypeOption> getVisitRecordTypesV4() {
        return getAvailableVisitRecordTypes();
    }

    @TestVisible
    private static List<RecordTypeOption> getAvailableVisitRecordTypes() {
        Schema.SObjectType visitType = getObjectType(visitObjectApiName);
        if (visitType == null) {
            throw userError('The Visit object is not available in this org. Enable Automotive Cloud Visit Management before using this component.');
        }

        List<RecordTypeOption> options = new List<RecordTypeOption>();
        for (Schema.RecordTypeInfo info : visitType.getDescribe().getRecordTypeInfos()) {
            if (info.isMaster() || !info.isAvailable() || !info.isActive()) {
                continue;
            }

            RecordTypeOption option = new RecordTypeOption();
            option.label = info.getName();
            option.value = String.valueOf(info.getRecordTypeId());
            option.developerName = info.getDeveloperName();
            option.defaultRecordTypeMapping = info.isDefaultRecordTypeMapping();
            option.master = info.isMaster();
            options.add(option);
        }

        if (options.isEmpty()) {
            throw userError('No Visit record types are available for your user. Ask your Salesforce admin to assign a Visit record type.');
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldMetadata> getVisitFieldMetadata(Id recordTypeId) {
        Schema.SObjectType visitType = getRequiredObjectType(visitObjectApiName);
        Map<String, Schema.SObjectField> fields = visitType.getDescribe().fields.getMap();
        List<FieldMetadata> metadata = new List<FieldMetadata>();
        Set<String> included = new Set<String>{
            normalizeFieldName('AccountId'),
            normalizeFieldName('RecordTypeId'),
            normalizeFieldName('VisitorId'),
            normalizeFieldName('PlaceId')
        };

        for (String fieldName : fields.keySet()) {
            Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
            if (isRequiredCreateField(describe) && !included.contains(normalizeFieldName(describe.getName()))) {
                metadata.add(toFieldMetadata(describe));
                included.add(normalizeFieldName(describe.getName()));
            }
        }

        List<String> preferredVisitFields = new List<String>{
            'PlannedVisitStartTime',
            'PlannedVisitEndTime',
            'VisitPriority',
            'ContextId',
            'InstructionDescription',
            'Status'
        };

        for (String fieldName : preferredVisitFields) {
            if (!fields.containsKey(fieldName) || included.contains(normalizeFieldName(fieldName))) {
                continue;
            }

            Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
            if (describe.isCreateable()) {
                metadata.add(toFieldMetadata(describe));
                included.add(normalizeFieldName(describe.getName()));
            }
        }

        return metadata;
    }

    @AuraEnabled(cacheable=true)
    public static AccountInfo getAccountInfo(Id accountId) {
        if (accountId == null) {
            throw userError('Account Id is required.');
        }
        return queryAccountInfo(accountId);
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountCandidate> searchAccounts(String searchTerm) {
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        Boolean canReadCustomerNumber =
            accountFields.containsKey('Customer_Account_Number__c') &&
            accountFields.get('Customer_Account_Number__c').getDescribe().isAccessible();
        Boolean canReadDealerCode =
            accountFields.containsKey('Dealer_Code__c') &&
            accountFields.get('Dealer_Code__c').getDescribe().isAccessible();

        List<String> selectFields = new List<String>{ 'Id', 'Name' };
        List<String> filters = new List<String>{ 'Name LIKE :term' };
        if (canReadCustomerNumber) {
            selectFields.add('Customer_Account_Number__c');
            filters.add('Customer_Account_Number__c LIKE :term');
        }
        if (canReadDealerCode) {
            selectFields.add('Dealer_Code__c');
            filters.add('Dealer_Code__c LIKE :term');
        }

        String term = searchTermLikeValue(searchTerm);
        String queryText = 'SELECT ' + String.join(selectFields, ',') +
            ' FROM Account WHERE (' + String.join(filters, ' OR ') + ')' +
            ' ORDER BY Name LIMIT 50';
        List<SObject> accounts = Database.queryWithBinds(queryText, new Map<String, Object>{ 'term' => term }, AccessLevel.USER_MODE);

        List<AccountCandidate> candidates = new List<AccountCandidate>();
        for (SObject accountRecord : accounts) {
            AccountCandidate candidate = new AccountCandidate();
            candidate.accountId = (Id) accountRecord.get('Id');
            candidate.name = (String) accountRecord.get('Name');
            if (canReadCustomerNumber) {
                candidate.customerAccountNumber = (String) accountRecord.get('Customer_Account_Number__c');
            }
            if (canReadDealerCode) {
                candidate.dealerCode = (String) accountRecord.get('Dealer_Code__c');
            }
            candidates.add(candidate);
        }
        return candidates;
    }

    @AuraEnabled(cacheable=true)
    public static List<AddressCandidate> searchAddresses(String searchTerm) {
        if (getObjectType('Address') == null) {
            return new List<AddressCandidate>();
        }

        String term = searchTermLikeValue(searchTerm);
        try {
            if (Test.isRunningTest() && testForceAddressSearchFallback) {
                throw new QueryException('Forced Address fallback');
            }
            return addressCandidates(Database.queryWithBinds(
                'SELECT Id, Name, Street, City, State, PostalCode, Country ' +
                'FROM Address WHERE Name LIKE :term OR Street LIKE :term OR City LIKE :term ' +
                'OR State LIKE :term OR PostalCode LIKE :term OR Country LIKE :term ' +
                'ORDER BY LastModifiedDate DESC LIMIT 50',
                new Map<String, Object>{ 'term' => term },
                AccessLevel.USER_MODE
            ));
        } catch (QueryException e) {
            return addressCandidates(Database.queryWithBinds(
                'SELECT Id, Name FROM Address WHERE Name LIKE :term ORDER BY LastModifiedDate DESC LIMIT 50',
                new Map<String, Object>{ 'term' => term },
                AccessLevel.USER_MODE
            ));
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<AddressCandidate> searchAccountAddresses(Id accountId, String searchTerm) {
        if (accountId == null || getObjectType('Address') == null || getObjectType('AssociatedLocation') == null) {
            return new List<AddressCandidate>();
        }

        String term = searchTermLikeValue(searchTerm);
        String accountAddressFilter =
            'ParentId IN (SELECT LocationId FROM AssociatedLocation WHERE ParentRecordId = :accountId)';
        try {
            if (Test.isRunningTest() && testForceAccountAddressSearchFallback) {
                throw new QueryException('Forced Account Address fallback');
            }
            return addressCandidates(Database.queryWithBinds(
                'SELECT Id, Name, Street, City, State, PostalCode, Country ' +
                'FROM Address WHERE ' + accountAddressFilter +
                ' AND (Name LIKE :term OR Street LIKE :term OR City LIKE :term ' +
                'OR State LIKE :term OR PostalCode LIKE :term OR Country LIKE :term) ' +
                'ORDER BY LastModifiedDate DESC LIMIT 50',
                new Map<String, Object>{ 'accountId' => accountId, 'term' => term },
                AccessLevel.USER_MODE
            ));
        } catch (QueryException e) {
            try {
                if (Test.isRunningTest() && testForceAccountAddressSearchEmptyFallback) {
                    throw new QueryException('Forced Account Address empty fallback');
                }
                return addressCandidates(Database.queryWithBinds(
                    'SELECT Id, Name FROM Address WHERE ' + accountAddressFilter +
                    ' AND Name LIKE :term ORDER BY LastModifiedDate DESC LIMIT 50',
                    new Map<String, Object>{ 'accountId' => accountId, 'term' => term },
                    AccessLevel.USER_MODE
                ));
            } catch (QueryException fallbackError) {
                return new List<AddressCandidate>();
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static AddressCandidate getDefaultAccountAddress(Id accountId) {
        if (accountId == null || getObjectType('Address') == null || getObjectType('AssociatedLocation') == null) {
            return null;
        }

        List<SObject> associatedLocations = Database.queryWithBinds(
            'SELECT LocationId, Type FROM AssociatedLocation WHERE ParentRecordId = :accountId ' +
            'AND LocationId != null ORDER BY LastModifiedDate DESC LIMIT 200',
            new Map<String, Object>{ 'accountId' => accountId },
            AccessLevel.USER_MODE
        );
        if (associatedLocations.isEmpty()) {
            return null;
        }

        Set<Id> allLocationIds = new Set<Id>();
        Set<Id> preferredLocationIds = new Set<Id>();
        for (SObject associatedLocation : associatedLocations) {
            Id locationId = (Id) associatedLocation.get('LocationId');
            if (locationId == null) {
                continue;
            }
            allLocationIds.add(locationId);
            String typeValue = String.valueOf(associatedLocation.get('Type')).toLowerCase();
            if (typeValue.contains('ship') || typeValue.contains('physical') || typeValue.contains('permanent')) {
                preferredLocationIds.add(locationId);
            }
        }
        if (allLocationIds.isEmpty()) {
            return null;
        }

        List<SObject> addresses;
        try {
            if (Test.isRunningTest() && testForceDefaultAccountAddressFallback) {
                throw new QueryException('Forced default Address fallback');
            }
            addresses = Database.queryWithBinds(
                'SELECT Id, Name, ParentId, AddressType, Street, City, State, PostalCode, Country ' +
                'FROM Address WHERE ParentId IN :allLocationIds ' +
                'ORDER BY LastModifiedDate DESC LIMIT 200',
                new Map<String, Object>{ 'allLocationIds' => allLocationIds },
                AccessLevel.USER_MODE
            );
        } catch (QueryException e) {
            addresses = Database.queryWithBinds(
                'SELECT Id, Name, ParentId FROM Address WHERE ParentId IN :allLocationIds ' +
                'ORDER BY LastModifiedDate DESC LIMIT 200',
                new Map<String, Object>{ 'allLocationIds' => allLocationIds },
                AccessLevel.USER_MODE
            );
        }

        if (addresses.isEmpty()) {
            return null;
        }

        SObject selectedAddress = firstPreferredAddress(addresses, preferredLocationIds);
        return addressCandidates(new List<SObject>{ selectedAddress })[0];
    }

    @AuraEnabled(cacheable=true)
    public static AddressCandidate getAddressInfo(Id addressId) {
        if (addressId == null || getObjectType('Address') == null) {
            return null;
        }

        try {
            if (Test.isRunningTest() && testForceAddressInfoFallback) {
                throw new QueryException('Forced Address info fallback');
            }
            List<AddressCandidate> candidates = addressCandidates(Database.queryWithBinds(
                'SELECT Id, Name, Street, City, State, PostalCode, Country FROM Address WHERE Id = :addressId LIMIT 1',
                new Map<String, Object>{ 'addressId' => addressId },
                AccessLevel.USER_MODE
            ));
            return candidates.isEmpty() ? null : candidates[0];
        } catch (QueryException e) {
            List<AddressCandidate> candidates = addressCandidates(Database.queryWithBinds(
                'SELECT Id, Name FROM Address WHERE Id = :addressId LIMIT 1',
                new Map<String, Object>{ 'addressId' => addressId },
                AccessLevel.USER_MODE
            ));
            return candidates.isEmpty() ? null : candidates[0];
        }
    }

    @TestVisible
    private static AccountInfo queryAccountInfo(Id accountId) {
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        Boolean hasCanField = accountFields.containsKey('Customer_Account_Number__c');
        String queryText = 'SELECT Id, Name, OwnerId, Owner.Name' +
            (hasCanField ? ', Customer_Account_Number__c' : '') +
            ' FROM Account WHERE Id = :accountId LIMIT 1';
        List<SObject> accounts;
        try {
            if (Test.isRunningTest() && testForceAccountInfoFallback) {
                throw new QueryException('Forced Account info fallback');
            }
            accounts = Database.queryWithBinds(
                queryText,
                new Map<String, Object>{ 'accountId' => accountId },
                AccessLevel.USER_MODE
            );
        } catch (QueryException e) {
            if (!hasCanField) {
                throw e;
            }
            hasCanField = false;
            accounts = Database.queryWithBinds(
                'SELECT Id, Name, OwnerId, Owner.Name FROM Account WHERE Id = :accountId LIMIT 1',
                new Map<String, Object>{ 'accountId' => accountId },
                AccessLevel.USER_MODE
            );
        }
        if (accounts.isEmpty()) {
            throw userError('The selected Account could not be found.');
        }

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, accounts);
        SObject accountRecord = decision.getRecords()[0];
        AccountInfo info = new AccountInfo();
        info.accountId = (Id) accountRecord.get('Id');
        info.name = (String) accountRecord.get('Name');
        info.ownerId = (Id) accountRecord.get('OwnerId');
        SObject ownerRecord = accountRecord.getSObject('Owner');
        info.ownerName = ownerRecord == null ? null : (String) ownerRecord.get('Name');
        if (hasCanField && decision.getRemovedFields().get('Account')?.contains('Customer_Account_Number__c') != true) {
            info.customerAccountNumber = (String) accountRecord.get('Customer_Account_Number__c');
        }
        info.defaultAddress = getDefaultAccountAddress(info.accountId);
        return info;
    }

    @AuraEnabled(cacheable=true)
    public static List<UserCandidate> getInitialVisitorCandidates(Id accountId) {
        if (accountId == null) {
            throw userError('Account Id is required.');
        }

        Map<Id, UserCandidate> candidatesByUserId = new Map<Id, UserCandidate>();
        SObject accountRecord = Database.query('SELECT Id, OwnerId FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1');
        Id ownerId = (Id) accountRecord.get('OwnerId');
        SObject owner = null;
        List<User> owners = [
            SELECT Id, Name, Email, Title, Department, UserRole.Name
            FROM User
            WHERE Id = :ownerId
            AND IsActive = true
            AND IsPortalEnabled = false
            WITH USER_MODE
            LIMIT 1
        ];
        if (!owners.isEmpty()) {
            owner = owners[0];
            candidatesByUserId.put(ownerId, toUserCandidate(ownerId, owner, 'Account Owner', true, true));
        }

        if (getObjectType('AccountTeamMember') != null) {
            try {
                if (Test.isRunningTest() && testForceAccountTeamFallback) {
                    throw new QueryException('Forced Account Team fallback');
                }
                for (SObject teamMember : Database.query(
                    'SELECT UserId, TeamMemberRole, User.Name, User.Email, User.Title, User.Department, User.UserRole.Name ' +
                    'FROM AccountTeamMember WHERE AccountId = :accountId AND User.IsActive = true ' +
                    'AND User.IsPortalEnabled = false ' +
                    'WITH USER_MODE ORDER BY User.Name LIMIT 200'
                )) {
                    Id userId = (Id) teamMember.get('UserId');
                    if (candidatesByUserId.containsKey(userId)) {
                        continue;
                    }

                    String role = (String) teamMember.get('TeamMemberRole');
                    String source = String.isBlank(role) ? 'Account Team' : 'Account Team - ' + role;
                    candidatesByUserId.put(userId, toUserCandidate(userId, teamMember.getSObject('User'), source, false, false));
                }
            } catch (QueryException ignored) {
                // Account Teams can be disabled or unavailable for the running user.
            }
        }

        return candidatesByUserId.values();
    }

    @AuraEnabled(cacheable=true)
    public static List<UserCandidate> searchUsers(String searchTerm, List<Id> excludedUserIds) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 3) {
            return new List<UserCandidate>();
        }
        String normalizedTerm = '%' + searchTerm.trim() + '%';
        Set<Id> excludedIds = new Set<Id>();
        if (excludedUserIds != null) {
            excludedIds.addAll(excludedUserIds);
        }

        List<UserCandidate> results = new List<UserCandidate>();
        for (User userRecord : [
            SELECT Id, Name, Email, Title, Department, UserRole.Name
            FROM User
            WHERE IsActive = true
            AND IsPortalEnabled = false
            AND Id NOT IN :excludedIds
            AND (Name LIKE :normalizedTerm OR Email LIKE :normalizedTerm)
            WITH USER_MODE
            ORDER BY Name
            LIMIT 25
        ]) {
            results.add(toUserCandidate(userRecord.Id, userRecord, 'Manual', false, false));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getContactRecordTypeDescriptions() {
        Map<String, String> descriptionsById = new Map<String, String>();
        for (RecordType recordType : [
            SELECT Id, Description
            FROM RecordType
            WHERE SObjectType = 'Contact'
            AND IsActive = true
            WITH USER_MODE
        ]) {
            descriptionsById.put(String.valueOf(recordType.Id), recordType.Description);
        }
        return descriptionsById;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContactCandidate> searchContacts(Id accountId, String searchTerm, List<Id> excludedContactIds) {
        if (accountId == null) {
            throw userError('Account Id is required.');
        }

        String normalizedTerm = String.isBlank(searchTerm) ? '%' : '%' + searchTerm.trim() + '%';
        Set<Id> excludedIds = new Set<Id>();
        if (excludedContactIds != null) {
            excludedIds.addAll(excludedContactIds);
        }

        List<ContactCandidate> results = new List<ContactCandidate>();
        for (Contact contactRecord : [
            SELECT Id, AccountId, Name, Email, Phone, Title
            FROM Contact
            WHERE AccountId = :accountId
            AND Id NOT IN :excludedIds
            AND (Name LIKE :normalizedTerm OR Email LIKE :normalizedTerm)
            WITH USER_MODE
            ORDER BY Name
            LIMIT 25
        ]) {
            ContactCandidate candidate = new ContactCandidate();
            candidate.contactId = contactRecord.Id;
            candidate.accountId = contactRecord.AccountId;
            candidate.name = contactRecord.Name;
            candidate.email = contactRecord.Email;
            candidate.phone = contactRecord.Phone;
            candidate.title = contactRecord.Title;
            results.add(candidate);
        }
        return results;
    }

    @AuraEnabled
    public static SaveResponse saveVisit(SaveRequest request) {
        normalizeSaveRequest(request);
        validateSaveRequest(request);

        Schema.SObjectType visitType = getRequiredObjectType(visitObjectApiName);
        Schema.SObjectType visitorType = getRequiredObjectType(visitorObjectApiName);
        Schema.SObjectType visitedPartyType = getRequiredObjectType(visitedPartyObjectApiName);

        Map<String, Schema.SObjectField> visitFields = visitType.getDescribe().fields.getMap();
        SObject visitRecord = visitType.newSObject();
        safePut(visitRecord, visitFields, 'RecordTypeId', request.recordTypeId);
        safePut(visitRecord, visitFields, visitAccountFieldApiName, request.accountId);
        safePut(visitRecord, visitFields, visitVisitorFieldApiName, request.visitorUserIds[0]);

        if (request.visitFields != null) {
            Set<String> managedVisitFields = new Set<String>{
                'Id',
                'RecordTypeId',
                visitAccountFieldApiName,
                visitVisitorFieldApiName
            };
            for (String fieldName : request.visitFields.keySet()) {
                if (managedVisitFields.contains(fieldName)) {
                    continue;
                }
                if (!visitFields.containsKey(fieldName)) {
                    continue;
                }

                Schema.DescribeFieldResult describe = visitFields.get(fieldName).getDescribe();
                if (describe.isCreateable()) {
                    visitRecord.put(fieldName, coerceValue(request.visitFields.get(fieldName), describe.getType()));
                }
            }
        }

        applyStatusForAction(visitRecord, visitFields, request.action);

        Savepoint savePoint = Database.setSavepoint();
        try {
            SObjectAccessDecision visitDecision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ visitRecord }
            );
            insert visitDecision.getRecords();
            Id visitId = visitDecision.getRecords()[0].Id;

            Set<Id> visitorIds = new Set<Id>(request.visitorUserIds);
            Set<Id> contactIds = new Set<Id>(request.visitedContactIds);
            List<SObject> relatedRecords = new List<SObject>();
            relatedRecords.addAll(buildVisitorRecords(visitorType, visitId, visitorIds, getUserNames(visitorIds)));
            relatedRecords.addAll(buildVisitedPartyRecords(visitedPartyType, visitId, contactIds, getContactNames(contactIds)));

            if (!relatedRecords.isEmpty()) {
                SObjectAccessDecision relatedDecision = Security.stripInaccessible(AccessType.CREATABLE, relatedRecords);
                insert relatedDecision.getRecords();
            }

            SaveResponse response = new SaveResponse();
            response.visitId = visitId;
            response.message = request.action == 'Draft' ? 'Visit saved as draft.' : 'Visit submitted.';
            return response;
        } catch (DmlException e) {
            Database.rollback(savePoint);
            throw userError(firstDmlMessage(e));
        }
    }

    @AuraEnabled
    public static SaveResponse saveVisitV3(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw userError('Save request is required.');
        }

        try {
            return saveVisit(saveRequestFromJson(JSON.deserializeUntyped(requestJson)));
        } catch (JSONException e) {
            throw userError('Save request could not be read.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static ActionPlanStartInfo getActionPlanStartInfo(Id visitId) {
        Schema.SObjectType actionPlanType = getRequiredObjectType(actionPlanObjectApiName);
        Map<String, Schema.SObjectField> actionPlanFields = actionPlanType.getDescribe().fields.getMap();
        requireCreateableField(actionPlanFields, 'ActionPlanTemplateVersionId', ACTION_PLAN_OBJECT);
        requireCreateableField(actionPlanFields, 'TargetId', ACTION_PLAN_OBJECT);
        requireCreateableField(actionPlanFields, 'ActionPlanState', ACTION_PLAN_OBJECT);

        ActionPlanStartInfo info = new ActionPlanStartInfo();
        info.targetRecordId = visitId == null ? null : String.valueOf(visitId);
        info.statusOptions = picklistOptions(actionPlanFields.get('ActionPlanState'));
        info.defaultStatus = defaultPicklistValue(actionPlanFields.get('ActionPlanState'));
        info.recentTemplates = recentActionPlanTemplateOptions();
        return info;
    }

    @AuraEnabled
    public static ActionPlanSaveResponse saveActionPlan(String requestJson) {
        if (String.isBlank(requestJson)) {
            throw userError('Meeting Template request is required.');
        }

        try {
            return saveActionPlanRequest(actionPlanRequestFromJson(JSON.deserializeUntyped(requestJson)));
        } catch (JSONException e) {
            throw userError('Meeting Template request could not be read.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getActionPlanTemplateType(Id templateVersionId) {
        SObject templateVersion = actionPlanTemplateVersionForVisit(templateVersionId);
        SObject template = actionPlanTemplateForVersion(templateVersion);
        return template == null ? null : (String) template.get('ActionPlanType');
    }

    @TestVisible
    private static SaveRequest saveRequestFromJson(Object rawPayload) {
        if (!(rawPayload instanceof Map<String, Object>)) {
            return null;
        }

        Map<String, Object> payload = (Map<String, Object>) rawPayload;
        SaveRequest request = new SaveRequest();
        request.accountId = idFromJson(payload.get('accountId'));
        request.accountIdText = stringFromJson(payload.get('accountIdText'));
        request.sourceAccountId = stringFromJson(payload.get('sourceAccountId'));
        request.recordTypeId = idFromJson(payload.get('recordTypeId'));
        request.visitFields = mapFromJson(payload.get('visitFields'));
        request.visitorUserIds = idsFromJson(payload.get('visitorUserIds'));
        request.visitedContactIds = idsFromJson(payload.get('visitedContactIds'));
        request.visitedContactIdStrings = stringsFromJson(payload.get('visitedContactIdStrings'));
        request.visitedContactIdText = stringFromJson(payload.get('visitedContactIdText'));
        request.action = stringFromJson(payload.get('action'));
        return request;
    }

    @TestVisible
    private static ActionPlanSaveRequest actionPlanRequestFromJson(Object rawPayload) {
        if (!(rawPayload instanceof Map<String, Object>)) {
            return null;
        }

        Map<String, Object> payload = (Map<String, Object>) rawPayload;
        ActionPlanSaveRequest request = new ActionPlanSaveRequest();
        request.visitId = idFromJson(payload.get('visitId'));
        request.targetRecordId = idFromJson(payload.get('targetRecordId'));
        request.name = stringFromJson(payload.get('name'));
        request.startDate = dateFromJson(payload.get('startDate'));
        request.actionPlanTemplateVersionId = idFromJson(payload.get('actionPlanTemplateVersionId'));
        request.status = stringFromJson(payload.get('status'));
        return request;
    }

    @TestVisible
    private static Map<String, Object> mapFromJson(Object value) {
        return value instanceof Map<String, Object> ? (Map<String, Object>) value : null;
    }

    @TestVisible
    private static String stringFromJson(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    @TestVisible
    private static Id idFromJson(Object value) {
        String rawValue = stringFromJson(value);
        return String.isBlank(rawValue) ? null : (Id) rawValue;
    }

    @TestVisible
    private static Date dateFromJson(Object value) {
        String rawValue = stringFromJson(value);
        return String.isBlank(rawValue) ? null : Date.valueOf(rawValue.left(10));
    }

    @TestVisible
    private static List<Id> idsFromJson(Object value) {
        List<Id> ids = new List<Id>();
        if (value == null) {
            return ids;
        }

        if (value instanceof List<Object>) {
            for (Object item : (List<Object>) value) {
                Id itemId = idFromJson(item);
                if (itemId != null) {
                    ids.add(itemId);
                }
            }
        } else {
            Id itemId = idFromJson(value);
            if (itemId != null) {
                ids.add(itemId);
            }
        }
        return ids;
    }

    @TestVisible
    private static List<String> stringsFromJson(Object value) {
        List<String> strings = new List<String>();
        if (value == null) {
            return strings;
        }

        if (value instanceof List<Object>) {
            for (Object item : (List<Object>) value) {
                String itemValue = stringFromJson(item);
                if (String.isNotBlank(itemValue)) {
                    strings.add(itemValue);
                }
            }
        } else {
            String itemValue = stringFromJson(value);
            if (String.isNotBlank(itemValue)) {
                strings.add(itemValue);
            }
        }
        return strings;
    }

    @TestVisible
    private static void validateSaveRequest(SaveRequest request) {
        if (request == null) {
            throw userError('Save request is required.');
        }
        if (request.accountId == null) {
            throw userError('Account Id is required.');
        }
        if (request.visitorUserIds == null || request.visitorUserIds.isEmpty()) {
            throw userError('Select at least one visitor.');
        }
        request.visitorUserIds = dedupeIdsPreserveOrder(request.visitorUserIds);

        if (request.visitedContactIds == null) {
            request.visitedContactIds = new List<Id>();
        }
        request.visitedContactIds = dedupeIdsPreserveOrder(request.visitedContactIds);

        if (request.action == 'Submit' && request.visitedContactIds.isEmpty()) {
            throw userError('Select at least one visited party before submitting.');
        }

        assertActiveUsers(request.visitorUserIds);
        assertContactsBelongToAccount(request.accountId, request.visitedContactIds);
    }

    @TestVisible
    private static ActionPlanSaveResponse saveActionPlanRequest(ActionPlanSaveRequest request) {
        validateActionPlanRequest(request);

        Schema.SObjectType actionPlanType = getRequiredObjectType(actionPlanObjectApiName);
        Map<String, Schema.SObjectField> actionPlanFields = actionPlanType.getDescribe().fields.getMap();
        requireCreateableField(actionPlanFields, 'Name', ACTION_PLAN_OBJECT);
        requireCreateableField(actionPlanFields, 'StartDate', ACTION_PLAN_OBJECT);
        requireCreateableField(actionPlanFields, 'ActionPlanTemplateVersionId', ACTION_PLAN_OBJECT);
        requireCreateableField(actionPlanFields, 'TargetId', ACTION_PLAN_OBJECT);
        requireCreateableField(actionPlanFields, 'ActionPlanState', ACTION_PLAN_OBJECT);
        requireCreateableField(actionPlanFields, 'ActionPlanType', ACTION_PLAN_OBJECT);

        SObject templateVersion = actionPlanTemplateVersionForVisit(request.actionPlanTemplateVersionId);
        SObject template = actionPlanTemplateForVersion(templateVersion);
        String actionPlanTypeValue = (String) template.get('ActionPlanType');
        if (!isActivePicklistValue(actionPlanFields.get('ActionPlanType'), actionPlanTypeValue)) {
            throw userError('The selected Meeting Template has an unsupported Meeting Template Type.');
        }

        String statusValue = String.isBlank(request.status)
            ? defaultPicklistValue(actionPlanFields.get('ActionPlanState'))
            : request.status;
        if (!isActivePicklistValue(actionPlanFields.get('ActionPlanState'), statusValue)) {
            throw userError('Select a valid Meeting Template status.');
        }

        SObject actionPlan = actionPlanType.newSObject();
        actionPlan.put('Name', request.name.left(255));
        actionPlan.put('StartDate', request.startDate);
        actionPlan.put('ActionPlanTemplateVersionId', request.actionPlanTemplateVersionId);
        actionPlan.put('TargetId', request.visitId);
        actionPlan.put('ActionPlanState', statusValue);
        actionPlan.put('ActionPlanType', actionPlanTypeValue);

        try {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ actionPlan }
            );
            insert decision.getRecords();

            ActionPlanSaveResponse response = new ActionPlanSaveResponse();
            response.actionPlanId = decision.getRecords()[0].Id;
            response.message = 'Meeting Template created.';
            return response;
        } catch (DmlException e) {
            throw userError(firstDmlMessage(e));
        }
    }

    @TestVisible
    private static void validateActionPlanRequest(ActionPlanSaveRequest request) {
        if (request == null) {
            throw userError('Meeting Template request is required.');
        }

        if (request.visitId == null) {
            request.visitId = request.targetRecordId;
        }
        if (request.visitId == null) {
            throw userError('Target Record is required.');
        }
        if (String.isBlank(request.name)) {
            throw userError('Meeting Template Name is required.');
        }
        if (request.startDate == null) {
            throw userError('Start Date is required.');
        }
        if (request.actionPlanTemplateVersionId == null) {
            throw userError('Meeting Template is required.');
        }

        Schema.SObjectType visitType = getObjectType(visitObjectApiName);
        if (visitType == null) {
            throw userError('The Visit object is not available in this org.');
        }

        Id visitId = request.visitId;
        if (Database.query('SELECT Id FROM Visit WHERE Id = :visitId WITH USER_MODE LIMIT 1').isEmpty()) {
            throw userError('The selected Target Record could not be found.');
        }
    }

    @TestVisible
    private static void normalizeSaveRequest(SaveRequest request) {
        if (request == null) {
            return;
        }

        request.visitedContactIds = collectVisitedContactIds(request);

        if (request.accountId == null) {
            request.accountId = firstAccountIdFromValues(new List<Object>{
                request.accountIdText,
                request.sourceAccountId,
                accountIdFromVisitFields(request.visitFields)
            });
        }

        if (request.accountId != null) {
            return;
        }

        if (request.visitedContactIds.isEmpty()) {
            return;
        }

        List<Contact> contacts = [
            SELECT AccountId
            FROM Contact
            WHERE Id IN :request.visitedContactIds
            AND AccountId != null
            WITH USER_MODE
            LIMIT 1
        ];
        if (!contacts.isEmpty()) {
            request.accountId = contacts[0].AccountId;
        }
    }

    @TestVisible
    private static Id accountIdFromVisitFields(Map<String, Object> visitFields) {
        if (visitFields == null || visitFields.isEmpty()) {
            return null;
        }

        Id accountId = firstAccountIdFromValue(visitFields.get('AccountId'));
        if (accountId != null) {
            return accountId;
        }

        return firstAccountIdFromValues(visitFields.values());
    }

    @TestVisible
    private static List<Id> collectVisitedContactIds(SaveRequest request) {
        List<Id> contactIds = new List<Id>();
        if (request.visitedContactIds != null) {
            contactIds.addAll(request.visitedContactIds);
        }

        if (request.visitedContactIdStrings != null) {
            for (String rawValue : request.visitedContactIdStrings) {
                addIdsFromValue(contactIds, rawValue, '003');
            }
        }
        addIdsFromValue(contactIds, request.visitedContactIdText, '003');
        return dedupeIdsPreserveOrder(contactIds);
    }

    @TestVisible
    private static Id firstAccountIdFromValues(Iterable<Object> values) {
        if (values == null) {
            return null;
        }

        for (Object value : values) {
            Id accountId = firstAccountIdFromValue(value);
            if (accountId != null) {
                return accountId;
            }
        }
        return null;
    }

    @TestVisible
    private static Id firstAccountIdFromValue(Object value) {
        List<Id> accountIds = new List<Id>();
        addIdsFromValue(accountIds, value, '001');
        return accountIds.isEmpty() ? null : accountIds[0];
    }

    @TestVisible
    private static void addIdsFromValue(List<Id> ids, Object value, String prefix) {
        if (ids == null || value == null || String.isBlank(prefix)) {
            return;
        }

        String rawValue = String.valueOf(value);
        if (String.isBlank(rawValue)) {
            return;
        }

        Matcher matcher = Pattern.compile(prefix + '[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?').matcher(rawValue);
        while (matcher.find()) {
            ids.add((Id) matcher.group(0));
        }
    }

    @TestVisible
    private static void assertActiveUsers(List<Id> userIds) {
        Set<Id> uniqueIds = new Set<Id>(userIds);
        if (uniqueIds.isEmpty()) {
            return;
        }

        Integer activeUserCount = [
            SELECT COUNT()
            FROM User
            WHERE Id IN :uniqueIds
            AND IsActive = true
            WITH USER_MODE
        ];

        if (activeUserCount != uniqueIds.size()) {
            throw userError('One or more selected visitors are inactive or unavailable.');
        }
    }

    @TestVisible
    private static List<Id> dedupeIdsPreserveOrder(List<Id> ids) {
        List<Id> orderedIds = new List<Id>();
        if (ids == null) {
            return orderedIds;
        }

        Set<Id> seenIds = new Set<Id>();
        for (Id recordId : ids) {
            if (recordId != null && !seenIds.contains(recordId)) {
                seenIds.add(recordId);
                orderedIds.add(recordId);
            }
        }
        return orderedIds;
    }

    @TestVisible
    private static void assertContactsBelongToAccount(Id accountId, List<Id> contactIds) {
        Set<Id> uniqueIds = new Set<Id>(contactIds);
        if (uniqueIds.isEmpty()) {
            return;
        }

        Integer contactCount = [
            SELECT COUNT()
            FROM Contact
            WHERE Id IN :uniqueIds
            AND AccountId = :accountId
            WITH USER_MODE
        ];

        if (contactCount != uniqueIds.size()) {
            throw userError('Visited parties must be contacts on the source account.');
        }
    }

    @TestVisible
    private static List<ActionPlanTemplateOption> recentActionPlanTemplateOptions() {
        if (
            getObjectType(ACTION_PLAN_TEMPLATE_VERSION_OBJECT) == null ||
            getObjectType('ActionPlanTemplate') == null
        ) {
            return new List<ActionPlanTemplateOption>();
        }

        List<ActionPlanTemplateOption> options = new List<ActionPlanTemplateOption>();
        try {
            List<SObject> templateVersions = Database.query(
                'SELECT Id, Name, Status, Version, LastModifiedDate, ActionPlanTemplateId ' +
                'FROM ActionPlanTemplateVersion ' +
                'WHERE Status = \'Final\' ' +
                'AND ActionPlanTemplateId != null ' +
                'WITH USER_MODE ' +
                'ORDER BY LastModifiedDate DESC ' +
                'LIMIT 25'
            );
            Set<Id> templateIds = new Set<Id>();
            for (SObject templateVersion : templateVersions) {
                templateIds.add((Id) templateVersion.get('ActionPlanTemplateId'));
            }

            Map<Id, SObject> templatesById = actionPlanTemplatesById(templateIds);
            for (SObject templateVersion : templateVersions) {
                SObject template = templatesById.get((Id) templateVersion.get('ActionPlanTemplateId'));
                if (!isPublishedTemplateForSelection(template)) {
                    continue;
                }
                options.add(toActionPlanTemplateOption(templateVersion, template));
                if (options.size() == 3) {
                    break;
                }
            }
        } catch (QueryException ignored) {
            return new List<ActionPlanTemplateOption>();
        }
        return options;
    }

    @TestVisible
    private static SObject actionPlanTemplateVersionForVisit(Id templateVersionId) {
        List<SObject> templateVersions = Test.isRunningTest() && testActionPlanTemplateVersionForVisit != null
            ? new List<SObject>{ testActionPlanTemplateVersionForVisit }
            : Database.query(
                'SELECT Id, Name, Status, ActionPlanTemplateId ' +
                'FROM ActionPlanTemplateVersion ' +
                'WHERE Id = :templateVersionId ' +
                'WITH USER_MODE ' +
                'LIMIT 1'
            );

        if (templateVersions.isEmpty()) {
            throw userError('The selected Meeting Template could not be found.');
        }

        SObject templateVersion = templateVersions[0];
        SObject template = actionPlanTemplateForVersion(templateVersion);
        if (template == null) {
            throw userError('The selected Meeting Template could not be found.');
        }
        Map<String, Object> populatedTemplateFields = template.getPopulatedFieldsAsMap();
        if (populatedTemplateFields.containsKey('TargetEntityType') && (String) template.get('TargetEntityType') != 'Visit') {
            throw userError('Select a Meeting Template for Visit records.');
        }
        if ((String) templateVersion.get('Status') != 'Final' || (String) template.get('Status') != 'Final') {
            throw userError('Select a published Meeting Template.');
        }
        if (String.isBlank((String) template.get('ActionPlanType'))) {
            throw userError('The selected Meeting Template is missing Meeting Template Type.');
        }

        return templateVersion;
    }

    @TestVisible
    private static ActionPlanTemplateOption toActionPlanTemplateOption(SObject templateVersion) {
        return toActionPlanTemplateOption(templateVersion, templateVersion.getSObject('ActionPlanTemplate'));
    }

    @TestVisible
    private static ActionPlanTemplateOption toActionPlanTemplateOption(SObject templateVersion, SObject template) {
        ActionPlanTemplateOption option = new ActionPlanTemplateOption();
        option.templateVersionId = (Id) templateVersion.get('Id');
        option.templateId = (Id) templateVersion.get('ActionPlanTemplateId');
        option.name = template == null ? (String) templateVersion.get('Name') : (String) template.get('Name');
        option.templateName = option.name;
        option.status = (String) templateVersion.get('Status');
        option.actionPlanType = template == null ? null : (String) template.get('ActionPlanType');
        option.versionNumber = (Integer) templateVersion.get('Version');
        option.lastModifiedDate = (Datetime) templateVersion.get('LastModifiedDate');
        return option;
    }

    @TestVisible
    private static SObject actionPlanTemplateForVersion(SObject templateVersion) {
        if (templateVersion == null) {
            return null;
        }
        SObject relationshipTemplate = templateVersion.getSObject('ActionPlanTemplate');
        if (relationshipTemplate != null) {
            return relationshipTemplate;
        }
        Id templateId = (Id) templateVersion.get('ActionPlanTemplateId');
        if (templateId == null) {
            return null;
        }
        return actionPlanTemplatesById(new Set<Id>{ templateId }).get(templateId);
    }

    @TestVisible
    private static Map<Id, SObject> actionPlanTemplatesById(Set<Id> templateIds) {
        Map<Id, SObject> templatesById = new Map<Id, SObject>();
        if (templateIds == null || templateIds.isEmpty()) {
            return templatesById;
        }
        for (SObject template : Database.query(
            'SELECT Id, Name, Status, ActionPlanType ' +
            'FROM ActionPlanTemplate ' +
            'WHERE Id IN :templateIds ' +
            'WITH USER_MODE'
        )) {
            templatesById.put((Id) template.get('Id'), template);
        }
        return templatesById;
    }

    @TestVisible
    private static Boolean isPublishedTemplateForSelection(SObject template) {
        return template != null &&
            (String) template.get('Status') == 'Final' &&
            !String.isBlank((String) template.get('ActionPlanType'));
    }

    @TestVisible
    private static List<SObject> buildVisitorRecords(Schema.SObjectType visitorType, Id visitId, Set<Id> userIds, Map<Id, String> userNames) {
        Map<String, Schema.SObjectField> fields = visitorType.getDescribe().fields.getMap();
        requireCreateableField(fields, visitorVisitFieldApiName, VISITOR_OBJECT);
        requireCreateableField(fields, visitorAssigneeFieldApiName, VISITOR_OBJECT);

        List<SObject> records = new List<SObject>();
        for (Id userId : userIds) {
            SObject record = visitorType.newSObject();
            record.put(visitorVisitFieldApiName, visitId);
            record.put(visitorAssigneeFieldApiName, userId);
            putNameIfCreateable(record, fields, userNames.get(userId));
            records.add(record);
        }
        return records;
    }

    @TestVisible
    private static List<SObject> buildVisitedPartyRecords(Schema.SObjectType visitedPartyType, Id visitId, Set<Id> contactIds, Map<Id, String> contactNames) {
        Map<String, Schema.SObjectField> fields = visitedPartyType.getDescribe().fields.getMap();
        requireCreateableField(fields, visitedPartyVisitFieldApiName, VISITED_PARTY_OBJECT);
        requireCreateableField(fields, visitedPartyContactFieldApiName, VISITED_PARTY_OBJECT);

        List<SObject> records = new List<SObject>();
        for (Id contactId : contactIds) {
            SObject record = visitedPartyType.newSObject();
            record.put(visitedPartyVisitFieldApiName, visitId);
            record.put(visitedPartyContactFieldApiName, contactId);
            putNameIfCreateable(record, fields, contactNames.get(contactId));
            records.add(record);
        }
        return records;
    }

    @TestVisible
    private static Map<Id, String> getUserNames(Set<Id> userIds) {
        Map<Id, String> namesById = new Map<Id, String>();
        if (userIds.isEmpty()) {
            return namesById;
        }

        for (User userRecord : [
            SELECT Id, Name
            FROM User
            WHERE Id IN :userIds
            WITH USER_MODE
        ]) {
            namesById.put(userRecord.Id, userRecord.Name);
        }
        return namesById;
    }

    @TestVisible
    private static Map<Id, String> getContactNames(Set<Id> contactIds) {
        Map<Id, String> namesById = new Map<Id, String>();
        if (contactIds.isEmpty()) {
            return namesById;
        }

        for (Contact contactRecord : [
            SELECT Id, Name
            FROM Contact
            WHERE Id IN :contactIds
            WITH USER_MODE
        ]) {
            namesById.put(contactRecord.Id, contactRecord.Name);
        }
        return namesById;
    }

    @TestVisible
    private static void putNameIfCreateable(SObject record, Map<String, Schema.SObjectField> fields, String nameValue) {
        if (!fields.containsKey('Name') || !fields.get('Name').getDescribe().isCreateable()) {
            return;
        }

        record.put('Name', String.isBlank(nameValue) ? 'Visit Participant' : nameValue.left(255));
    }

    @TestVisible
    private static Boolean isRequiredCreateField(Schema.DescribeFieldResult describe) {
        return describe.isCreateable()
            && !describe.isNillable()
            && !describe.isDefaultedOnCreate()
            && describe.getType() != Schema.DisplayType.ID
            && !describe.isAutoNumber()
            && describe.getName() != 'OwnerId';
    }

    @TestVisible
    private static FieldMetadata toFieldMetadata(Schema.DescribeFieldResult describe) {
        FieldMetadata metadata = new FieldMetadata();
        metadata.apiName = describe.getName();
        metadata.label = describe.getLabel();
        metadata.required = isRequiredCreateField(describe);
        metadata.value = defaultVisitFieldValue(describe);
        return metadata;
    }

    @TestVisible
    private static String defaultVisitFieldValue(Schema.DescribeFieldResult describe) {
        if (describe == null) {
            return null;
        }

        if (describe.getName() == 'PlannedVisitStartTime') {
            return System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        }
        if (describe.getName() == 'VisitPriority') {
            return 'Medium';
        }
        return null;
    }

    @TestVisible
    private static String searchTermLikeValue(String searchTerm) {
        return String.isBlank(searchTerm) ? '%' : '%' + searchTerm.trim() + '%';
    }

    @TestVisible
    private static List<AddressCandidate> addressCandidates(List<SObject> records) {
        List<AddressCandidate> candidates = new List<AddressCandidate>();
        for (SObject addressRecord : records) {
            AddressCandidate candidate = new AddressCandidate();
            candidate.addressId = (Id) addressRecord.get('Id');
            candidate.name = (String) addressRecord.get('Name');
            candidate.street = sObjectString(addressRecord, 'Street');
            candidate.city = sObjectString(addressRecord, 'City');
            candidate.state = sObjectString(addressRecord, 'State');
            candidate.postalCode = sObjectString(addressRecord, 'PostalCode');
            candidate.country = sObjectString(addressRecord, 'Country');
            candidate.displayAddress = formattedAddress(candidate);
            candidates.add(candidate);
        }
        return candidates;
    }

    @TestVisible
    private static SObject firstPreferredAddress(List<SObject> addresses, Set<Id> preferredLocationIds) {
        SObject firstPreferredLocationAddress;
        SObject firstShippingAddress;
        SObject firstAddress = addresses.isEmpty() ? null : addresses[0];

        for (SObject addressRecord : addresses) {
            Id parentId;
            try {
                parentId = (Id) addressRecord.get('ParentId');
            } catch (SObjectException e) {
                parentId = null;
            }

            String addressType = sObjectString(addressRecord, 'AddressType');
            Boolean shippingAddress = !String.isBlank(addressType) &&
                addressType.toLowerCase().contains('ship');
            Boolean preferredLocation = parentId != null && preferredLocationIds != null && preferredLocationIds.contains(parentId);

            if (preferredLocation && shippingAddress) {
                return addressRecord;
            }
            if (firstPreferredLocationAddress == null && preferredLocation) {
                firstPreferredLocationAddress = addressRecord;
            }
            if (firstShippingAddress == null && shippingAddress) {
                firstShippingAddress = addressRecord;
            }
        }

        if (firstPreferredLocationAddress != null) {
            return firstPreferredLocationAddress;
        }
        if (firstShippingAddress != null) {
            return firstShippingAddress;
        }
        return firstAddress;
    }

    private static String sObjectString(SObject record, String fieldName) {
        try {
            Object value = record.get(fieldName);
            return value == null ? null : String.valueOf(value);
        } catch (SObjectException e) {
            return null;
        }
    }

    private static String formattedAddress(AddressCandidate candidate) {
        List<String> parts = new List<String>();
        for (String value : new List<String>{ candidate.street, candidate.city, candidate.state, candidate.postalCode, candidate.country }) {
            if (!String.isBlank(value)) {
                parts.add(value);
            }
        }
        return parts.isEmpty() ? candidate.name : String.join(parts, ', ');
    }

    @TestVisible
    private static List<PicklistOption> picklistOptions(Schema.SObjectField fieldToken) {
        List<PicklistOption> options = new List<PicklistOption>();
        if (fieldToken == null) {
            return options;
        }

        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }

            PicklistOption option = new PicklistOption();
            option.label = entry.getLabel();
            option.value = entry.getValue();
            options.add(option);
        }
        return options;
    }

    @TestVisible
    private static String defaultPicklistValue(Schema.SObjectField fieldToken) {
        if (fieldToken == null) {
            return null;
        }

        String firstActiveValue;
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            if (firstActiveValue == null) {
                firstActiveValue = entry.getValue();
            }
            if (entry.isDefaultValue()) {
                return entry.getValue();
            }
        }
        return firstActiveValue;
    }

    @TestVisible
    private static Boolean isActivePicklistValue(Schema.SObjectField fieldToken, String value) {
        if (fieldToken == null || String.isBlank(value)) {
            return false;
        }

        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    @TestVisible
    private static String normalizeFieldName(String fieldName) {
        return String.isBlank(fieldName) ? '' : fieldName.toLowerCase();
    }

    @TestVisible
    private static UserCandidate toUserCandidate(Id userId, SObject userRecord, String source, Boolean selected, Boolean locked) {
        UserCandidate candidate = new UserCandidate();
        candidate.userId = userId;
        candidate.name = userRecord == null ? String.valueOf(userId) : (String) userRecord.get('Name');
        candidate.email = userRecord == null ? null : (String) userRecord.get('Email');
        candidate.title = userRecord == null ? null : (String) userRecord.get('Title');
        candidate.department = userRecord == null ? null : (String) userRecord.get('Department');
        try {
            SObject userRole = userRecord == null ? null : userRecord.getSObject('UserRole');
            candidate.role = userRole == null ? null : (String) userRole.get('Name');
        } catch (SObjectException ignored) {
            candidate.role = null;
        }
        candidate.source = source;
        candidate.selected = selected;
        candidate.locked = locked;
        return candidate;
    }

    @TestVisible
    private static void safePut(SObject record, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (value == null || !fields.containsKey(fieldName)) {
            return;
        }

        Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
        if (describe.isCreateable()) {
            record.put(fieldName, coerceValue(value, describe.getType()));
        }
    }

    @TestVisible
    private static Object coerceValue(Object value, Schema.DisplayType fieldType) {
        if (value == null) {
            return null;
        }

        String stringValue = String.valueOf(value);
        if (String.isBlank(stringValue)) {
            return null;
        }

        if (fieldType == Schema.DisplayType.DATE) {
            return Date.valueOf(stringValue);
        }
        if (fieldType == Schema.DisplayType.DATETIME) {
            return (DateTime) JSON.deserialize(JSON.serialize(stringValue), DateTime.class);
        }
        if (fieldType == Schema.DisplayType.BOOLEAN) {
            return value instanceof Boolean ? value : Boolean.valueOf(stringValue);
        }
        if (
            fieldType == Schema.DisplayType.CURRENCY ||
            fieldType == Schema.DisplayType.DOUBLE ||
            fieldType == Schema.DisplayType.PERCENT
        ) {
            return Decimal.valueOf(stringValue);
        }
        if (fieldType == Schema.DisplayType.INTEGER) {
            return Integer.valueOf(stringValue);
        }
        if (fieldType == Schema.DisplayType.LONG) {
            return Long.valueOf(stringValue);
        }

        return value;
    }

    @TestVisible
    private static void applyStatusForAction(SObject visitRecord, Map<String, Schema.SObjectField> fields, String action) {
        if (!fields.containsKey('Status') || !fields.get('Status').getDescribe().isCreateable()) {
            return;
        }

        Schema.DescribeFieldResult statusDescribe = fields.get('Status').getDescribe();
        Set<String> activeValues = new Set<String>();
        for (Schema.PicklistEntry entry : statusDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                activeValues.add(entry.getValue());
            }
        }

        Object currentStatus = visitRecord.get('Status');
        if (action == 'Draft' && activeValues.contains('None')) {
            visitRecord.put('Status', 'None');
        } else if (action == 'Submit' && (currentStatus == null || String.valueOf(currentStatus) == 'None') && activeValues.contains('Planned')) {
            visitRecord.put('Status', 'Planned');
        }
    }

    @TestVisible
    private static void requireCreateableField(Map<String, Schema.SObjectField> fields, String fieldName, String objectName) {
        if (!fields.containsKey(fieldName) || !fields.get(fieldName).getDescribe().isCreateable()) {
            throw userError(objectName + '.' + fieldName + ' is required but is not createable for the running user.');
        }
    }

    @TestVisible
    private static Schema.SObjectType getRequiredObjectType(String objectName) {
        Schema.SObjectType objectType = getObjectType(objectName);
        if (objectType == null) {
            throw userError('The ' + objectName + ' object is not available in this org.');
        }
        if (!objectType.getDescribe().isCreateable()) {
            throw userError('You do not have create access to ' + objectName + '.');
        }
        return objectType;
    }

    @TestVisible
    private static Schema.SObjectType getObjectType(String objectName) {
        return Schema.getGlobalDescribe().get(objectName);
    }

    @TestVisible
    private static String firstDmlMessage(DmlException e) {
        return e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
    }

    @TestVisible
    private static AuraHandledException userError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }
}
