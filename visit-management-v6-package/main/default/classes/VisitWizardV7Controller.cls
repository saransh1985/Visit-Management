public inherited sharing class VisitWizardV7Controller {
    private static final String VISIT_OBJECT = 'Visit';
    private static final String VISIT_STATUS_DRAFT = 'Draft';
    private static final String VISIT_STATUS_DRAFT_FALLBACK = 'Planned';

    public class AccountCandidate {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String customerAccountNumber;
        @AuraEnabled public String dealerCode;
        @AuraEnabled public String primaryCan;
    }

    public class TopicContextResult {
        @AuraEnabled public Id contextId;
        @AuraEnabled public Id relationId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountCandidate> searchAccounts(String searchTerm) {
        Map<String, Schema.SObjectField> accountFields = Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        Boolean canReadCustomerNumber = isReadable(accountFields, 'Customer_Account_Number__c');
        Boolean canReadDealerCode = isReadable(accountFields, 'Dealer_Code__c');
        Boolean canReadPrimaryCan = isReadable(accountFields, 'Primary_CAN__c');

        List<String> selectFields = new List<String>{ 'Id', 'Name' };
        Map<String, Object> binds = new Map<String, Object>();
        String normalizedTerm = String.valueOf(searchTerm == null ? '' : searchTerm).trim();
        String term = '%' + normalizedTerm + '%';
        binds.put('nameTerm', term);
        List<String> filters = new List<String>{ 'Name LIKE :nameTerm' };
        if (canReadCustomerNumber) {
            selectFields.add('Customer_Account_Number__c');
            addSearchFilter(filters, binds, accountFields.get('Customer_Account_Number__c'), 'Customer_Account_Number__c', 'customerNumber', normalizedTerm, term);
        }
        if (canReadDealerCode) {
            selectFields.add('Dealer_Code__c');
            addSearchFilter(filters, binds, accountFields.get('Dealer_Code__c'), 'Dealer_Code__c', 'dealerCode', normalizedTerm, term);
        }
        if (canReadPrimaryCan) {
            selectFields.add('Primary_CAN__c');
            addSearchFilter(filters, binds, accountFields.get('Primary_CAN__c'), 'Primary_CAN__c', 'primaryCan', normalizedTerm, term);
        }

        String queryText =
            'SELECT ' + String.join(selectFields, ',') +
            ' FROM Account WHERE (' + String.join(filters, ' OR ') + ')' +
            ' ORDER BY Name LIMIT 50';
        List<SObject> accounts = Database.queryWithBinds(queryText, binds, AccessLevel.USER_MODE);

        List<AccountCandidate> candidates = new List<AccountCandidate>();
        for (SObject accountRecord : accounts) {
            AccountCandidate candidate = new AccountCandidate();
            candidate.accountId = (Id) accountRecord.get('Id');
            candidate.name = toDisplayText(accountRecord.get('Name'));
            if (canReadCustomerNumber) {
                candidate.customerAccountNumber = toDisplayText(accountRecord.get('Customer_Account_Number__c'));
            }
            if (canReadDealerCode) {
                candidate.dealerCode = toDisplayText(accountRecord.get('Dealer_Code__c'));
            }
            if (canReadPrimaryCan) {
                candidate.primaryCan = toDisplayText(accountRecord.get('Primary_CAN__c'));
            }
            candidates.add(candidate);
        }
        return candidates;
    }

    @AuraEnabled
    public static VisitWizardV6Controller.SaveResponse saveForLater(String requestJson) {
        VisitWizardV6Controller.SaveResponse response = VisitWizardV6Controller.saveForLater(requestJson);
        setVisitStatusDraftEquivalent(response?.visitId);
        return response;
    }

    @AuraEnabled
    public static VisitWizardV6Controller.SaveResponse saveVisitProgress(String requestJson) {
        VisitWizardV6Controller.SaveResponse response = VisitWizardV6Controller.saveVisitProgress(requestJson);
        setVisitStatusDraftEquivalent(response?.visitId);
        return response;
    }

    @AuraEnabled
    public static TopicContextResult saveTopicContext(String requestJson) {
        Map<String, Object> request = parseRequest(requestJson, 'Topic context request is required.');
        Id genericTaskId = toId(request.get('genericTaskId'));
        Id productId = toId(request.get('productId'));
        if (genericTaskId == null) {
            throw userError('Topic Id is required to save Topic Context.');
        }
        if (productId == null) {
            return null;
        }
        if (!GenericVisitTaskContext.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable() ||
            !GnrcVstTaskContextRelation.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            throw userError('You do not have access to save Topic Context.');
        }

        List<GenericVisitTask> taskRows = [
            SELECT Id, Name, VisitId
            FROM GenericVisitTask
            WHERE Id = :genericTaskId
            WITH USER_MODE
            LIMIT 1
        ];
        if (taskRows.isEmpty()) {
            throw userError('Topic could not be found.');
        }
        List<Product2> productRows = [
            SELECT Id, Name
            FROM Product2
            WHERE Id = :productId
            AND IsActive = true
            WITH USER_MODE
            LIMIT 1
        ];
        if (productRows.isEmpty()) {
            throw userError('Select an active Product for Topic Context.');
        }

        TopicContextResult existing = existingTopicContext(genericTaskId, productId, productRows[0].Name);
        if (existing != null) {
            return existing;
        }

        Savepoint savePoint = Database.setSavepoint();
        try {
            GenericVisitTaskContext contextRecord = new GenericVisitTaskContext();
            contextRecord.Name = contextName(productRows[0].Name);
            contextRecord.ContextId = productId;
            contextRecord.VisitId = taskRows[0].VisitId;
            String statusValue = activePicklistValue(
                GenericVisitTaskContext.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap().get('Status'),
                'In Progress'
            );
            if (statusValue != null) {
                contextRecord.Status = statusValue;
            }
            List<SObject> creatableContexts = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ contextRecord }
            ).getRecords();
            Database.insert(creatableContexts, AccessLevel.USER_MODE);

            GnrcVstTaskContextRelation relationRecord = new GnrcVstTaskContextRelation();
            relationRecord.VisitTaskId = genericTaskId;
            relationRecord.VisitTaskContextId = (Id) creatableContexts[0].get('Id');
            List<SObject> creatableRelations = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ relationRecord }
            ).getRecords();
            Database.insert(creatableRelations, AccessLevel.USER_MODE);

            TopicContextResult result = new TopicContextResult();
            result.contextId = (Id) creatableContexts[0].get('Id');
            result.relationId = (Id) creatableRelations[0].get('Id');
            result.productId = productRows[0].Id;
            result.productName = productRows[0].Name;
            return result;
        } catch (DmlException e) {
            Database.rollback(savePoint);
            throw userError(firstDmlMessage(e));
        } catch (Exception e) {
            Database.rollback(savePoint);
            throw userError(String.isBlank(e.getMessage()) ? 'Topic Context could not be saved.' : e.getMessage());
        }
    }

    private static Boolean isReadable(Map<String, Schema.SObjectField> fields, String fieldName) {
        return fields.containsKey(fieldName) && fields.get(fieldName).getDescribe().isAccessible();
    }

    private static void addSearchFilter(
        List<String> filters,
        Map<String, Object> binds,
        Schema.SObjectField fieldToken,
        String fieldName,
        String bindName,
        String normalizedTerm,
        String likeTerm
    ) {
        Schema.DisplayType fieldType = fieldToken.getDescribe().getType();
        if (isLikeSearchable(fieldType)) {
            binds.put(bindName, likeTerm);
            filters.add(fieldName + ' LIKE :' + bindName);
            return;
        }

        Object exactValue = exactSearchValue(normalizedTerm, fieldType);
        if (exactValue != null) {
            binds.put(bindName, exactValue);
            filters.add(fieldName + ' = :' + bindName);
        }
    }

    private static Boolean isLikeSearchable(Schema.DisplayType fieldType) {
        return new Set<Schema.DisplayType>{
            Schema.DisplayType.STRING,
            Schema.DisplayType.TEXTAREA,
            Schema.DisplayType.EMAIL,
            Schema.DisplayType.PHONE,
            Schema.DisplayType.URL,
            Schema.DisplayType.ENCRYPTEDSTRING
        }.contains(fieldType);
    }

    private static Object exactSearchValue(String normalizedTerm, Schema.DisplayType fieldType) {
        if (String.isBlank(normalizedTerm)) {
            return null;
        }
        try {
            if (fieldType == Schema.DisplayType.INTEGER) {
                return Integer.valueOf(normalizedTerm);
            }
            if (fieldType == Schema.DisplayType.LONG) {
                return Long.valueOf(normalizedTerm);
            }
            if (new Set<Schema.DisplayType>{
                Schema.DisplayType.CURRENCY,
                Schema.DisplayType.DOUBLE,
                Schema.DisplayType.PERCENT
            }.contains(fieldType)) {
                return Decimal.valueOf(normalizedTerm);
            }
            if (fieldType == Schema.DisplayType.BOOLEAN) {
                String lowerTerm = normalizedTerm.toLowerCase();
                if (lowerTerm == 'true' || lowerTerm == 'false') {
                    return Boolean.valueOf(lowerTerm);
                }
            }
            if (fieldType == Schema.DisplayType.DATE) {
                return Date.valueOf(normalizedTerm);
            }
        } catch (Exception ignored) {
            return null;
        }
        return null;
    }

    private static String toDisplayText(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static TopicContextResult existingTopicContext(Id genericTaskId, Id productId, String productName) {
        Set<Id> contextIds = new Set<Id>();
        Map<Id, Id> contextIdToRelationId = new Map<Id, Id>();
        for (GnrcVstTaskContextRelation relationRecord : [
            SELECT Id, VisitTaskContextId
            FROM GnrcVstTaskContextRelation
            WHERE VisitTaskId = :genericTaskId
            WITH USER_MODE
        ]) {
            if (relationRecord.VisitTaskContextId != null) {
                contextIds.add(relationRecord.VisitTaskContextId);
                contextIdToRelationId.put(relationRecord.VisitTaskContextId, relationRecord.Id);
            }
        }
        if (contextIds.isEmpty()) {
            return null;
        }

        for (GenericVisitTaskContext contextRecord : [
            SELECT Id, ContextId
            FROM GenericVisitTaskContext
            WHERE Id IN :contextIds
            AND ContextId = :productId
            WITH USER_MODE
            LIMIT 1
        ]) {
            TopicContextResult result = new TopicContextResult();
            result.contextId = contextRecord.Id;
            result.relationId = contextIdToRelationId.get(contextRecord.Id);
            result.productId = productId;
            result.productName = productName;
            return result;
        }
        return null;
    }

    private static String contextName(String productName) {
        String baseName = String.isBlank(productName) ? 'Topic Context' : 'Topic Context - ' + productName;
        return baseName.left(255);
    }

    private static Map<String, Object> parseRequest(String requestJson, String message) {
        if (String.isBlank(requestJson)) {
            throw userError(message);
        }
        try {
            Object rawValue = JSON.deserializeUntyped(requestJson);
            return rawValue instanceof Map<String, Object> ? (Map<String, Object>) rawValue : new Map<String, Object>();
        } catch (JSONException e) {
            throw userError('Request could not be read.');
        }
    }

    private static Id toId(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }
        Matcher matcher = Pattern.compile('[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?').matcher(String.valueOf(value));
        if (!matcher.find()) {
            return null;
        }
        try {
            return (Id) matcher.group(0);
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String firstDmlMessage(DmlException e) {
        return e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
    }

    private static void setVisitStatusDraftEquivalent(Id visitId) {
        if (visitId == null) {
            return;
        }
        Schema.SObjectType visitType = Schema.getGlobalDescribe().get(VISIT_OBJECT);
        if (visitType == null) {
            throw userError('The Visit object is not available in this org.');
        }
        Map<String, Schema.SObjectField> fields = visitType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        if (!fields.containsKey('Status') || !fields.get('Status').getDescribe().isUpdateable()) {
            return;
        }
        String statusValue = activePicklistValue(fields.get('Status'), VISIT_STATUS_DRAFT);
        if (statusValue == null) {
            statusValue = activePicklistValue(fields.get('Status'), VISIT_STATUS_DRAFT_FALLBACK);
        }
        if (statusValue == null) {
            return;
        }
        SObject visitRecord = visitType.newSObject(visitId);
        visitRecord.put('Status', statusValue);
        Database.update(Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ visitRecord }).getRecords(), AccessLevel.USER_MODE);
    }

    private static String activePicklistValue(Schema.SObjectField fieldToken, String value) {
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == value) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static AuraHandledException userError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }
}
