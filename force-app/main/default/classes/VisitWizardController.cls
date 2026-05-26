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
        Set<String> included = new Set<String>{ normalizeFieldName('AccountId'), normalizeFieldName('RecordTypeId'), normalizeFieldName('VisitorId') };

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
            'VisitTypeId',
            'PlaceId',
            'ContextId',
            'InstructionDescription',
            'Status',
            'StatusRemarks'
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
    public static List<UserCandidate> getInitialVisitorCandidates(Id accountId) {
        if (accountId == null) {
            throw userError('Account Id is required.');
        }

        Map<Id, UserCandidate> candidatesByUserId = new Map<Id, UserCandidate>();
        SObject accountRecord = Database.query('SELECT Id, OwnerId FROM Account WHERE Id = :accountId LIMIT 1');
        Id ownerId = (Id) accountRecord.get('OwnerId');
        SObject owner = null;
        List<User> owners = [
            SELECT Id, Name, Email, Title, Department
            FROM User
            WHERE Id = :ownerId
            AND IsActive = true
            LIMIT 1
        ];
        if (!owners.isEmpty()) {
            owner = owners[0];
            candidatesByUserId.put(ownerId, toUserCandidate(ownerId, owner, 'Account Owner', true, true));
        }

        if (getObjectType('AccountTeamMember') != null) {
            try {
                for (SObject teamMember : Database.query(
                    'SELECT UserId, TeamMemberRole, User.Name, User.Email, User.Title, User.Department ' +
                    'FROM AccountTeamMember WHERE AccountId = :accountId AND User.IsActive = true ORDER BY User.Name LIMIT 200'
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
        String normalizedTerm = String.isBlank(searchTerm) ? '%' : '%' + searchTerm.trim() + '%';
        Set<Id> excludedIds = new Set<Id>();
        if (excludedUserIds != null) {
            excludedIds.addAll(excludedUserIds);
        }

        List<UserCandidate> results = new List<UserCandidate>();
        for (User userRecord : [
            SELECT Id, Name, Email, Title, Department
            FROM User
            WHERE IsActive = true
            AND Id NOT IN :excludedIds
            AND (Name LIKE :normalizedTerm OR Email LIKE :normalizedTerm)
            ORDER BY Name
            LIMIT 25
        ]) {
            results.add(toUserCandidate(userRecord.Id, userRecord, 'Manual', false, false));
        }
        return results;
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
            throw userError('Action Plan request is required.');
        }

        try {
            return saveActionPlanRequest(actionPlanRequestFromJson(JSON.deserializeUntyped(requestJson)));
        } catch (JSONException e) {
            throw userError('Action Plan request could not be read.');
        }
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
        SObject template = templateVersion.getSObject('ActionPlanTemplate');
        String actionPlanTypeValue = (String) template.get('ActionPlanType');
        if (!isActivePicklistValue(actionPlanFields.get('ActionPlanType'), actionPlanTypeValue)) {
            throw userError('The selected Action Plan Template has an unsupported Action Plan Type.');
        }

        String statusValue = String.isBlank(request.status)
            ? defaultPicklistValue(actionPlanFields.get('ActionPlanState'))
            : request.status;
        if (!isActivePicklistValue(actionPlanFields.get('ActionPlanState'), statusValue)) {
            throw userError('Select a valid Action Plan status.');
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
            response.message = 'Action Plan created.';
            return response;
        } catch (DmlException e) {
            throw userError(firstDmlMessage(e));
        }
    }

    @TestVisible
    private static void validateActionPlanRequest(ActionPlanSaveRequest request) {
        if (request == null) {
            throw userError('Action Plan request is required.');
        }

        if (request.visitId == null) {
            request.visitId = request.targetRecordId;
        }
        if (request.visitId == null) {
            throw userError('Target Record is required.');
        }
        if (String.isBlank(request.name)) {
            throw userError('Action Plan Name is required.');
        }
        if (request.startDate == null) {
            throw userError('Start Date is required.');
        }
        if (request.actionPlanTemplateVersionId == null) {
            throw userError('Action Plan Template is required.');
        }

        Schema.SObjectType visitType = getObjectType(visitObjectApiName);
        if (visitType == null) {
            throw userError('The Visit object is not available in this org.');
        }

        Id visitId = request.visitId;
        if (Database.query('SELECT Id FROM Visit WHERE Id = :visitId LIMIT 1').isEmpty()) {
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
            for (SObject templateVersion : Database.query(
                'SELECT Id, Name, Status, Version, LastModifiedDate, ActionPlanTemplateId, ' +
                'ActionPlanTemplate.Name, ActionPlanTemplate.ActionPlanType, ' +
                'ActionPlanTemplate.Status, ActionPlanTemplate.TargetEntityType ' +
                'FROM ActionPlanTemplateVersion ' +
                'WHERE Status = \'Final\' ' +
                'AND ActionPlanTemplate.Status = \'Final\' ' +
                'AND ActionPlanTemplate.TargetEntityType = \'Visit\' ' +
                'ORDER BY LastModifiedDate DESC ' +
                'LIMIT 3'
            )) {
                options.add(toActionPlanTemplateOption(templateVersion));
            }
        } catch (QueryException ignored) {
            return new List<ActionPlanTemplateOption>();
        }
        return options;
    }

    @TestVisible
    private static SObject actionPlanTemplateVersionForVisit(Id templateVersionId) {
        List<SObject> templateVersions = Database.query(
            'SELECT Id, Name, Status, ActionPlanTemplateId, ' +
            'ActionPlanTemplate.Name, ActionPlanTemplate.ActionPlanType, ' +
            'ActionPlanTemplate.Status, ActionPlanTemplate.TargetEntityType ' +
            'FROM ActionPlanTemplateVersion ' +
            'WHERE Id = :templateVersionId ' +
            'LIMIT 1'
        );

        if (templateVersions.isEmpty()) {
            throw userError('The selected Action Plan Template could not be found.');
        }

        SObject templateVersion = templateVersions[0];
        SObject template = templateVersion.getSObject('ActionPlanTemplate');
        if (template == null || (String) template.get('TargetEntityType') != 'Visit') {
            throw userError('Select an Action Plan Template for Visit records.');
        }
        if ((String) templateVersion.get('Status') != 'Final' || (String) template.get('Status') != 'Final') {
            throw userError('Select a published Action Plan Template.');
        }
        if (String.isBlank((String) template.get('ActionPlanType'))) {
            throw userError('The selected Action Plan Template is missing Action Plan Type.');
        }

        return templateVersion;
    }

    @TestVisible
    private static ActionPlanTemplateOption toActionPlanTemplateOption(SObject templateVersion) {
        SObject template = templateVersion.getSObject('ActionPlanTemplate');
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
        return metadata;
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
