public inherited sharing class VisitWizardV6Controller {
    private static final String VISIT_OBJECT = 'Visit';
    private static final String VISITOR_OBJECT = 'Visitor';
    private static final String VISITED_PARTY_OBJECT = 'VisitedParty';
    private static final String ACTION_PLAN_OBJECT = 'ActionPlan';
    private static final String ACTION_PLAN_ITEM_OBJECT = 'ActionPlanItem';
    private static final String GENERIC_VISIT_TASK_OBJECT = 'GenericVisitTask';
    private static final String CONTENT_NOTE_OBJECT = 'ContentNote';
    private static final String CONTENT_DOCUMENT_LINK_OBJECT = 'ContentDocumentLink';
    private static final String RESUME_FIELD = 'Visit_Wizard_Resume_Page__c';
    private static final String STATE_FIELD = 'Visit_Wizard_State__c';
    private static final String ACTION_PLAN_ID_FIELD = 'Visit_Wizard_Action_Plan_Id__c';
    private static final String OPPORTUNITY_VISIT_FIELD = 'Visit__c';
    private static final String VISIT_STATUS_IN_PROGRESS = 'InProgress';
    private static final String VISIT_STATUS_IN_PROGRESS_LABEL = 'In Progress';
    private static final String ACTION_PLAN_STATE_IN_PROGRESS = 'In Progress';
    private static final String ACTION_PLAN_STATE_COMPLETED = 'Completed';

    public class LaunchContext {
        @AuraEnabled public String mode;
        @AuraEnabled public Boolean canEdit;
        @AuraEnabled public Boolean completed;
        @AuraEnabled public Id sourceRecordId;
        @AuraEnabled public Id visitId;
        @AuraEnabled public String visitName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String customerAccountNumber;
        @AuraEnabled public Id recordTypeId;
        @AuraEnabled public String visitStatus;
        @AuraEnabled public String resumePage;
        @AuraEnabled public String stateJson;
        @AuraEnabled public Id actionPlanId;
        @AuraEnabled public String actionPlanName;
        @AuraEnabled public Date actionPlanStartDate;
        @AuraEnabled public Id actionPlanTemplateVersionId;
        @AuraEnabled public String actionPlanStatus;
        @AuraEnabled public Map<String, Object> visitValues;
        @AuraEnabled public List<VisitWizardController.RecordTypeOption> recordTypes;
        @AuraEnabled public List<VisitWizardController.UserCandidate> visitorCandidates;
        @AuraEnabled public List<VisitWizardController.UserCandidate> selectedVisitors;
        @AuraEnabled public List<VisitWizardController.ContactCandidate> selectedContacts;
        @AuraEnabled public List<TaskSummary> tasks;
        @AuraEnabled public List<OpportunitySummary> opportunities;
    }

    public class SaveResponse {
        @AuraEnabled public Id visitId;
        @AuraEnabled public String visitName;
        @AuraEnabled public String resumePage;
        @AuraEnabled public String message;
    }

    public class TaskSummary {
        @AuraEnabled public Id actionPlanItemId;
        @AuraEnabled public Id genericTaskId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String itemState;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Integer sequence;
        @AuraEnabled public String category;
        @AuraEnabled public String description;
        @AuraEnabled public Datetime startDateTime;
        @AuraEnabled public Datetime endDateTime;
        @AuraEnabled public Boolean completed;
        @AuraEnabled public Boolean salesTask;
    }

    public class NoteSummary {
        @AuraEnabled public Id contentNoteId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String body;
        @AuraEnabled public String textPreview;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String createdByName;
    }

    public class TaskListResponse {
        @AuraEnabled public Id actionPlanId;
        @AuraEnabled public List<TaskSummary> tasks;
        @AuraEnabled public Boolean requiredTasksComplete;
    }

    public class OpportunityDefaults {
        @AuraEnabled public Id visitId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String stageName;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public String warning;
    }

    public class OpportunitySummary {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String name;
        @AuraEnabled public String stageName;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public Decimal amount;
    }

    @AuraEnabled(cacheable=true)
    public static List<VisitWizardController.RecordTypeOption> getVisitRecordTypesV6() {
        return VisitWizardController.getVisitRecordTypesV4();
    }

    @AuraEnabled(cacheable=true)
    public static List<VisitWizardController.FieldMetadata> getVisitFieldMetadata(Id recordTypeId) {
        return VisitWizardController.getVisitFieldMetadata(recordTypeId);
    }

    @AuraEnabled(cacheable=true)
    public static VisitWizardController.AccountInfo getAccountInfo(Id accountId) {
        return VisitWizardController.getAccountInfo(accountId);
    }

    @AuraEnabled(cacheable=true)
    public static List<VisitWizardController.AccountCandidate> searchAccounts(String searchTerm) {
        return VisitWizardController.searchAccounts(searchTerm);
    }

    @AuraEnabled(cacheable=true)
    public static List<VisitWizardController.AddressCandidate> searchAddresses(String searchTerm) {
        return VisitWizardController.searchAddresses(searchTerm);
    }

    @AuraEnabled(cacheable=true)
    public static List<VisitWizardController.AddressCandidate> searchAccountAddresses(Id accountId, String searchTerm) {
        return VisitWizardController.searchAccountAddresses(accountId, searchTerm);
    }

    @AuraEnabled(cacheable=true)
    public static VisitWizardController.AddressCandidate getDefaultAccountAddress(Id accountId) {
        return VisitWizardController.getDefaultAccountAddress(accountId);
    }

    @AuraEnabled(cacheable=true)
    public static VisitWizardController.AddressCandidate getAddressInfo(Id addressId) {
        return VisitWizardController.getAddressInfo(addressId);
    }

    @AuraEnabled(cacheable=true)
    public static List<VisitWizardController.UserCandidate> getInitialVisitorCandidates(Id accountId) {
        return VisitWizardController.getInitialVisitorCandidates(accountId);
    }

    @AuraEnabled(cacheable=true)
    public static List<VisitWizardController.UserCandidate> searchUsers(String searchTerm, List<Id> excludedUserIds) {
        return VisitWizardController.searchUsers(searchTerm, excludedUserIds);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getContactRecordTypeDescriptions() {
        return VisitWizardController.getContactRecordTypeDescriptions();
    }

    @AuraEnabled(cacheable=true)
    public static List<VisitWizardController.ContactCandidate> searchContacts(Id accountId, String searchTerm, List<Id> excludedContactIds) {
        return VisitWizardController.searchContacts(accountId, searchTerm, excludedContactIds);
    }

    @AuraEnabled(cacheable=true)
    public static VisitWizardController.ActionPlanStartInfo getActionPlanStartInfo(Id visitId) {
        VisitWizardController.ActionPlanStartInfo info = VisitWizardController.getActionPlanStartInfo(visitId);
        info.defaultStatus = preferredActionPlanState(info.statusOptions, info.defaultStatus);
        return info;
    }

    @AuraEnabled
    public static LaunchContext getLaunchContext(String recordIdText) {
        Id recordId = toId(recordIdText);
        LaunchContext context = new LaunchContext();
        context.sourceRecordId = recordId;
        context.recordTypes = getVisitRecordTypesV6();
        context.visitValues = new Map<String, Object>();
        context.visitorCandidates = new List<VisitWizardController.UserCandidate>();
        context.selectedVisitors = new List<VisitWizardController.UserCandidate>();
        context.selectedContacts = new List<VisitWizardController.ContactCandidate>();
        context.tasks = new List<TaskSummary>();
        context.opportunities = new List<OpportunitySummary>();
        context.canEdit = true;
        context.completed = false;

        if (recordId == null) {
            context.mode = 'NEW';
            context.resumePage = context.recordTypes.size() == 1 ? 'VisitDetails' : 'RecordType';
            if (context.recordTypes.size() == 1) {
                context.recordTypeId = (Id) context.recordTypes[0].value;
            }
            return context;
        }

        if (recordId.getSObjectType() == Account.SObjectType) {
            context.mode = 'NEW';
            context.accountId = recordId;
            applyAccountContext(context);
            context.resumePage = context.recordTypes.size() == 1 ? 'VisitDetails' : 'RecordType';
            if (context.recordTypes.size() == 1) {
                context.recordTypeId = (Id) context.recordTypes[0].value;
                context.visitValues.put('RecordTypeId', context.recordTypeId);
            }
            return context;
        }

        if (String.valueOf(recordId.getSObjectType()) == VISIT_OBJECT) {
            context.mode = 'EDIT';
            context.visitId = recordId;
            loadVisitContext(context);
            return context;
        }

        context.mode = 'NEW';
        context.resumePage = context.recordTypes.size() == 1 ? 'VisitDetails' : 'RecordType';
        return context;
    }

    @AuraEnabled
    public static SaveResponse saveForLater(String requestJson) {
        return saveVisitProgress(requestJson, true);
    }

    @AuraEnabled
    public static SaveResponse saveVisitProgress(String requestJson) {
        return saveVisitProgress(requestJson, false);
    }

    @AuraEnabled
    public static TaskListResponse saveActionPlanAndLoadTasks(String requestJson) {
        Map<String, Object> request = parseRequest(requestJson, 'Meeting Template request is required.');
        Id visitId = toId(request.get('visitId'));
        if (visitId == null) {
            throw userError('Visit Id is required before creating a Meeting Template.');
        }

        Id actionPlanId = toId(request.get('actionPlanId'));
        request.put('status', actionPlanStateValue(request.get('status'), ACTION_PLAN_STATE_IN_PROGRESS));
        if (actionPlanId == null) {
            VisitWizardController.ActionPlanSaveResponse response = VisitWizardController.saveActionPlan(JSON.serialize(new Map<String, Object>{
                'visitId' => visitId,
                'targetRecordId' => valueOrDefault(request.get('targetRecordId'), visitId),
                'name' => request.get('name'),
                'startDate' => request.get('startDate'),
                'actionPlanTemplateVersionId' => request.get('actionPlanTemplateVersionId'),
                'status' => request.get('status')
            }));
            actionPlanId = response.actionPlanId;
        } else {
            updateExistingActionPlan(actionPlanId, request);
        }

        saveWizardMarkers(visitId, 'Tasks', String.valueOf(request.get('stateJson')), actionPlanId);
        return taskListResponse(visitId, actionPlanId);
    }

    @AuraEnabled
    public static TaskListResponse getTaskList(Id visitId, Id actionPlanId) {
        return taskListResponse(visitId, actionPlanId);
    }

    @AuraEnabled
    public static TaskListResponse createCustomTopic(String requestJson) {
        Map<String, Object> request = parseRequest(requestJson, 'Topic request is required.');
        Id visitId = toId(request.get('visitId'));
        if (visitId == null) {
            throw userError('Visit Id is required before creating a Topic.');
        }

        String topicName = blankToNull(request.get('name'));
        if (String.isBlank(topicName)) {
            throw userError('Topic Name is required.');
        }

        Schema.SObjectType taskType = Schema.getGlobalDescribe().get(GENERIC_VISIT_TASK_OBJECT);
        if (taskType == null) {
            throw userError('Topics are not available in this org.');
        }
        if (!taskType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            throw userError('You do not have access to create Topics.');
        }

        Map<String, Schema.SObjectField> fields = objectFields(GENERIC_VISIT_TASK_OBJECT);
        if (!fields.containsKey('Name') ||
            !fields.get('Name').getDescribe().isCreateable() ||
            !fields.containsKey('VisitId') ||
            !fields.get('VisitId').getDescribe().isCreateable()) {
            throw userError('You do not have access to create a Topic for this Visit.');
        }

        SObject topicRecord = taskType.newSObject();
        putIfCreateable(topicRecord, fields, 'Name', topicName.left(255));
        putIfCreateable(topicRecord, fields, 'VisitId', visitId);
        putIfCreateable(topicRecord, fields, 'Description', blankToNull(request.get('description')));
        putIfCreateable(
            topicRecord,
            fields,
            'IsRequired',
            Boolean.valueOf(String.valueOf(valueOrDefault(request.get('required'), false)))
        );
        putIfCreateable(topicRecord, fields, 'Sequence', nextTopicSequence(visitId));

        String statusValue = activePicklistValue(fields.get('Status'), 'Not Started');
        if (String.isBlank(statusValue)) {
            statusValue = firstActivePicklistValue(fields.get('Status'));
        }
        if (!String.isBlank(statusValue)) {
            putIfCreateable(topicRecord, fields, 'Status', statusValue);
        }

        Database.insert(Security.stripInaccessible(AccessType.CREATABLE, new List<SObject>{ topicRecord }).getRecords(), AccessLevel.USER_MODE);
        return taskListResponse(visitId, toId(request.get('actionPlanId')));
    }

    @AuraEnabled
    public static TaskListResponse startTask(Id visitId, Id actionPlanItemId, Id genericTaskId) {
        updateTaskStatus(actionPlanItemId, genericTaskId, 'In Progress', 'InProgress');
        return taskListResponse(visitId, null);
    }

    @AuraEnabled
    public static TaskListResponse saveTask(String requestJson) {
        Map<String, Object> request = parseRequest(requestJson, 'Task request is required.');
        Id visitId = toId(request.get('visitId'));
        Id actionPlanItemId = toId(request.get('actionPlanItemId'));
        Id genericTaskId = toId(request.get('genericTaskId'));
        Boolean complete = Boolean.valueOf(String.valueOf(valueOrDefault(request.get('complete'), false)));
        Datetime startDateTime = toDateTime(request.get('startDateTime'));
        Datetime endDateTime = toDateTime(request.get('endDateTime'));

        if (complete) {
            validateTaskCompletion(genericTaskId, startDateTime, endDateTime);
        }

        Map<String, Schema.SObjectField> fields = objectFields(GENERIC_VISIT_TASK_OBJECT);
        if (genericTaskId != null && !fields.isEmpty()) {
            SObject taskRecord = Schema.getGlobalDescribe().get(GENERIC_VISIT_TASK_OBJECT).newSObject(genericTaskId);
            putIfUpdateable(taskRecord, fields, 'Description', request.get('description'));
            putIfUpdateable(taskRecord, fields, 'StartDateTime', startDateTime);
            putIfUpdateable(taskRecord, fields, 'EndDateTime', endDateTime);
            String currentStatus = currentGenericTaskStatus(genericTaskId);
            if (complete) {
                putIfUpdateableWhenChanged(taskRecord, fields, 'Status', 'Completed', currentStatus);
            } else {
                putIfUpdateableWhenChanged(taskRecord, fields, 'Status', valueOrDefault(request.get('status'), 'In Progress'), currentStatus);
            }
            if (taskRecord.getPopulatedFieldsAsMap().size() > 1) {
                Database.update(Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ taskRecord }).getRecords(), AccessLevel.USER_MODE);
            }
        }

        updateTaskStatus(
            actionPlanItemId,
            genericTaskId,
            complete ? 'Completed' : String.valueOf(valueOrDefault(request.get('status'), 'In Progress')),
            complete ? 'Completed' : 'InProgress'
        );
        TaskListResponse response = taskListResponse(visitId, toId(request.get('actionPlanId')));
        completeActionPlanIfRequiredTasksComplete(response);
        return response;
    }

    @AuraEnabled
    public static List<NoteSummary> getTaskNotes(Id genericTaskId) {
        return taskNotes(genericTaskId);
    }

    @AuraEnabled
    public static List<NoteSummary> saveTaskNote(String requestJson) {
        Map<String, Object> request = parseRequest(requestJson, 'Task note request is required.');
        Id genericTaskId = toId(request.get('genericTaskId'));
        String title = String.valueOf(valueOrDefault(request.get('title'), 'Visit Task Note')).trim();
        String body = String.valueOf(valueOrDefault(request.get('body'), '')).trim();
        if (genericTaskId == null) {
            throw userError('Task Id is required to save a note.');
        }
        if (String.isBlank(stripHtml(body))) {
            throw userError('Enter note content before saving.');
        }
        if (Schema.getGlobalDescribe().get(CONTENT_NOTE_OBJECT) == null ||
            Schema.getGlobalDescribe().get(CONTENT_DOCUMENT_LINK_OBJECT) == null) {
            throw userError('Enhanced Notes are not available in this org.');
        }
        if (!Schema.getGlobalDescribe().get(CONTENT_NOTE_OBJECT).getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable() ||
            !Schema.getGlobalDescribe().get(CONTENT_DOCUMENT_LINK_OBJECT).getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            throw userError('You do not have access to create enhanced notes.');
        }

        ContentNote noteRecord = new ContentNote();
        noteRecord.Title = title.left(255);
        noteRecord.Content = Blob.valueOf(body);
        if (ContentNote.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap().containsKey('SharingPrivacy')) {
            noteRecord.SharingPrivacy = 'N';
        }
        List<SObject> creatableNotes = Security.stripInaccessible(AccessType.CREATABLE, new List<SObject>{ noteRecord }).getRecords();
        Database.insert(creatableNotes, AccessLevel.USER_MODE);

        ContentDocumentLink linkRecord = new ContentDocumentLink();
        linkRecord.ContentDocumentId = creatableNotes[0].Id;
        linkRecord.LinkedEntityId = genericTaskId;
        linkRecord.ShareType = 'V';
        linkRecord.Visibility = 'AllUsers';
        Database.insert(Security.stripInaccessible(AccessType.CREATABLE, new List<SObject>{ linkRecord }).getRecords(), AccessLevel.USER_MODE);
        return taskNotes(genericTaskId);
    }

    @AuraEnabled(cacheable=true)
    public static OpportunityDefaults getOpportunityDefaults(Id visitId) {
        if (visitId == null) {
            throw userError('Visit Id is required.');
        }

        SObject visitRecord = queryVisit(visitId);
        OpportunityDefaults defaults = new OpportunityDefaults();
        defaults.visitId = visitId;
        defaults.accountId = (Id) visitRecord.get('AccountId');
        defaults.closeDate = Date.today().addDays(30);
        defaults.stageName = activeOpportunityStage('Draft');
        if (defaults.stageName != 'Draft') {
            defaults.warning = 'Draft is not active on Opportunity Stage. The first active stage was selected.';
        }
        if (defaults.accountId != null) {
            try {
                VisitWizardController.AccountInfo accountInfo = VisitWizardController.getAccountInfo(defaults.accountId);
                defaults.accountName = accountInfo.name;
            } catch (Exception ignored) {
                defaults.accountName = String.valueOf(defaults.accountId);
            }
        }
        return defaults;
    }

    @AuraEnabled
    public static OpportunitySummary createOpportunity(String requestJson) {
        Map<String, Object> request = parseRequest(requestJson, 'Opportunity request is required.');
        Id visitId = toId(request.get('visitId'));
        Id accountId = toId(request.get('accountId'));
        String name = String.valueOf(request.get('name'));
        Date closeDate = toDate(request.get('closeDate'));
        if (!Opportunity.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            throw userError('You do not have create access to Opportunity.');
        }
        if (visitId == null || accountId == null) {
            throw userError('Visit and Account are required to create an Opportunity.');
        }
        if (String.isBlank(name) || closeDate == null) {
            throw userError('Opportunity Name and Close Date are required.');
        }

        Map<String, Schema.SObjectField> fields = Opportunity.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        Opportunity opportunityRecord = new Opportunity();
        opportunityRecord.Name = name.left(120);
        opportunityRecord.AccountId = accountId;
        opportunityRecord.CloseDate = closeDate;
        opportunityRecord.StageName = activeOpportunityStage('Draft');
        if (fields.containsKey(OPPORTUNITY_VISIT_FIELD) && fields.get(OPPORTUNITY_VISIT_FIELD).getDescribe().isCreateable()) {
            opportunityRecord.put(OPPORTUNITY_VISIT_FIELD, visitId);
        }
        if (fields.containsKey('Amount') && request.containsKey('amount')) {
            opportunityRecord.Amount = toDecimal(request.get('amount'));
        }
        if (fields.containsKey('Type') && request.containsKey('type')) {
            opportunityRecord.Type = blankToNull(request.get('type'));
        }
        if (fields.containsKey('Description') && request.containsKey('description')) {
            opportunityRecord.Description = blankToNull(request.get('description'));
        }

        List<SObject> creatableOpportunities = Security.stripInaccessible(AccessType.CREATABLE, new List<SObject>{ opportunityRecord }).getRecords();
        Database.insert(creatableOpportunities, AccessLevel.USER_MODE);
        return toOpportunitySummary((Opportunity) creatableOpportunities[0]);
    }

    @AuraEnabled
    public static LaunchContext getReview(Id visitId, Id actionPlanId) {
        LaunchContext context = getLaunchContext(String.valueOf(visitId));
        TaskListResponse tasks = taskListResponse(visitId, actionPlanId);
        completeActionPlanIfRequiredTasksComplete(tasks);
        context.tasks = tasks.tasks;
        context.opportunities = opportunitySummaries(visitId);
        return context;
    }

    @AuraEnabled
    public static SaveResponse completeVisit(Id visitId, Id actionPlanId) {
        if (visitId == null) {
            throw userError('Visit Id is required.');
        }
        TaskListResponse tasks = taskListResponse(visitId, actionPlanId);
        if (!tasks.requiredTasksComplete) {
            throw userError('Complete all required topics before completing the Visit.');
        }
        completeActionPlanIfRequiredTasksComplete(tasks);

        Map<String, Schema.SObjectField> fields = objectFields(VISIT_OBJECT);
        SObject visitRecord = Schema.getGlobalDescribe().get(VISIT_OBJECT).newSObject(visitId);
        putIfUpdateable(visitRecord, fields, 'Status', 'Completed');
        putIfUpdateable(visitRecord, fields, RESUME_FIELD, 'Review');
        Database.update(Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ visitRecord }).getRecords(), AccessLevel.USER_MODE);

        SaveResponse response = new SaveResponse();
        response.visitId = visitId;
        response.visitName = visitDisplayName(visitId);
        response.resumePage = 'Review';
        response.message = 'Visit completed.';
        return response;
    }

    private static SaveResponse saveVisitProgress(String requestJson, Boolean savedForLater) {
        Map<String, Object> request = parseRequest(requestJson, 'Visit request is required.');
        Id visitId = toId(request.get('visitId'));
        Id accountId = toId(request.get('accountId'));
        Id recordTypeId = toId(request.get('recordTypeId'));
        Map<String, Object> visitValues = asMap(request.get('visitFields'));
        List<Id> visitorUserIds = idsFromList(request.get('visitorUserIds'));
        List<Id> visitedContactIds = idsFromList(request.get('visitedContactIds'));
        String resumePage = String.isBlank((String) request.get('resumePage')) ? 'VisitDetails' : (String) request.get('resumePage');
        String stateJson = String.valueOf(valueOrDefault(request.get('stateJson'), null));
        Boolean validateRequired = Boolean.valueOf(String.valueOf(valueOrDefault(request.get('validateRequired'), false)));

        if (accountId == null) {
            accountId = toId(visitValues.get('AccountId'));
        }
        if (accountId == null) {
            throw userError('Account is required.');
        }
        if (recordTypeId == null) {
            recordTypeId = defaultVisitRecordTypeId();
        }
        if (visitorUserIds.isEmpty()) {
            visitorUserIds.add(UserInfo.getUserId());
        }
        assertActiveUsers(visitorUserIds);
        assertContactsBelongToAccount(accountId, visitedContactIds);

        Map<String, Schema.SObjectField> fields = objectFields(VISIT_OBJECT);
        Schema.DescribeSObjectResult visitDescribe = Schema.getGlobalDescribe().get(VISIT_OBJECT).getDescribe();
        if (visitId == null && !visitDescribe.isCreateable()) {
            throw userError('You do not have create access to Visit.');
        }
        if (visitId != null && !visitDescribe.isUpdateable()) {
            throw userError('You do not have update access to Visit.');
        }
        SObject visitRecord = visitId == null
            ? Schema.getGlobalDescribe().get(VISIT_OBJECT).newSObject()
            : Schema.getGlobalDescribe().get(VISIT_OBJECT).newSObject(visitId);
        if (visitId == null) {
            putIfCreateable(visitRecord, fields, 'RecordTypeId', recordTypeId);
            putIfCreateable(visitRecord, fields, 'AccountId', accountId);
            putIfCreateable(visitRecord, fields, 'VisitorId', visitorUserIds[0]);
        } else {
            putIfUpdateable(visitRecord, fields, 'RecordTypeId', recordTypeId);
            putIfUpdateable(visitRecord, fields, 'AccountId', accountId);
            putIfUpdateable(visitRecord, fields, 'VisitorId', visitorUserIds[0]);
        }

        for (String fieldName : visitValues.keySet()) {
            if (new Set<String>{ 'Id', 'RecordTypeId', 'AccountId', 'VisitorId' }.contains(fieldName)) {
                continue;
            }
            if (visitId == null) {
                putIfCreateable(visitRecord, fields, fieldName, visitValues.get(fieldName));
            } else {
                putIfUpdateable(visitRecord, fields, fieldName, visitValues.get(fieldName));
            }
        }
        putVisitStatusInProgress(visitRecord, fields, visitId == null);
        putIfWritable(visitRecord, fields, RESUME_FIELD, resumePage, visitId == null);
        putIfWritable(visitRecord, fields, STATE_FIELD, stateJson, visitId == null);
        putIfWritable(visitRecord, fields, ACTION_PLAN_ID_FIELD, request.get('actionPlanId'), visitId == null);

        if (validateRequired) {
            validateRequiredVisitFields(visitRecord, fields);
        }

        Savepoint savePoint = Database.setSavepoint();
        try {
            if (visitId == null) {
                List<SObject> creatableVisits = Security.stripInaccessible(AccessType.CREATABLE, new List<SObject>{ visitRecord }).getRecords();
                Database.insert(creatableVisits, AccessLevel.USER_MODE);
                visitId = creatableVisits[0].Id;
            } else {
                Database.update(Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ visitRecord }).getRecords(), AccessLevel.USER_MODE);
            }
            replaceVisitorRows(visitId, visitorUserIds);
            replaceVisitedPartyRows(visitId, visitedContactIds);
        } catch (DmlException e) {
            Database.rollback(savePoint);
            throw userError(firstDmlMessage(e));
        } catch (Exception e) {
            Database.rollback(savePoint);
            throw userError(firstExceptionMessage(e));
        }

        SaveResponse response = new SaveResponse();
        response.visitId = visitId;
        response.visitName = visitDisplayName(visitId);
        response.resumePage = resumePage;
        response.message = savedForLater ? 'Visit saved for later.' : 'Visit progress saved.';
        return response;
    }

    private static void loadVisitContext(LaunchContext context) {
        SObject visitRecord = queryVisit(context.visitId);
        context.visitName = (String) visitRecord.get('Name');
        context.recordTypeId = (Id) visitRecord.get('RecordTypeId');
        context.accountId = (Id) visitRecord.get('AccountId');
        context.visitStatus = (String) visitRecord.get('Status');
        context.completed = context.visitStatus == 'Completed';
        context.canEdit = !context.completed;
        context.resumePage = fieldValue(visitRecord, RESUME_FIELD) == null ? 'VisitDetails' : (String) fieldValue(visitRecord, RESUME_FIELD);
        context.stateJson = (String) fieldValue(visitRecord, STATE_FIELD);
        context.actionPlanId = toId(fieldValue(visitRecord, ACTION_PLAN_ID_FIELD));
        context.visitValues.put('Id', context.visitId);
        for (String fieldName : visitFormFieldNames()) {
            if (hasField(VISIT_OBJECT, fieldName)) {
                context.visitValues.put(fieldName, visitRecord.get(fieldName));
            }
        }
        applyAccountContext(context);
        context.selectedVisitors = selectedVisitors(context.visitId);
        context.visitorCandidates = context.accountId == null
            ? new List<VisitWizardController.UserCandidate>()
            : VisitWizardController.getInitialVisitorCandidates(context.accountId);
        context.selectedContacts = selectedContacts(context.visitId);
        loadActionPlanContext(context);
        context.tasks = taskListResponse(context.visitId, context.actionPlanId).tasks;
        context.opportunities = opportunitySummaries(context.visitId);
    }

    @TestVisible
    private static void applyAccountContext(LaunchContext context) {
        if (context.accountId == null) {
            return;
        }
        try {
            VisitWizardController.AccountInfo accountInfo = VisitWizardController.getAccountInfo(context.accountId);
            context.accountName = accountInfo.name;
            context.customerAccountNumber = accountInfo.customerAccountNumber;
            context.visitValues.put('AccountId', context.accountId);
            if (!context.visitValues.containsKey('PlaceId') && accountInfo.defaultAddress != null) {
                context.visitValues.put('PlaceId', accountInfo.defaultAddress.addressId);
            }
            context.visitorCandidates = VisitWizardController.getInitialVisitorCandidates(context.accountId);
            if (context.selectedVisitors == null || context.selectedVisitors.isEmpty()) {
                context.selectedVisitors = new List<VisitWizardController.UserCandidate>();
                for (VisitWizardController.UserCandidate candidate : context.visitorCandidates) {
                    if (candidate.selected) {
                        context.selectedVisitors.add(candidate);
                    }
                }
            }
        } catch (Exception ignored) {
            context.accountName = String.valueOf(context.accountId);
        }
    }

    @SuppressWarnings('PMD.ApexSOQLInjection')
    @TestVisible
    private static SObject queryVisit(Id visitId) {
        if (visitId == null) {
            throw userError('Visit Id is required.');
        }
        Set<String> queryFields = new Set<String>{ 'Id', 'Name', 'RecordTypeId', 'AccountId', 'Status' };
        queryFields.addAll(visitFormFieldNames());
        for (String optionalField : new List<String>{ RESUME_FIELD, STATE_FIELD, ACTION_PLAN_ID_FIELD }) {
            if (hasField(VISIT_OBJECT, optionalField)) {
                queryFields.add(optionalField);
            }
        }
        List<String> orderedFields = new List<String>(queryFields);
        orderedFields.sort();
        String queryText = 'SELECT ' + String.join(orderedFields, ',') + ' FROM Visit WHERE Id = :visitId WITH USER_MODE LIMIT 1';
        List<SObject> records = Database.query(queryText);
        if (records.isEmpty()) {
            throw userError('Visit could not be found.');
        }
        return records[0];
    }

    @SuppressWarnings('PMD.ApexSOQLInjection')
    @TestVisible
    private static void loadActionPlanContext(LaunchContext context) {
        if (context.visitId == null || Schema.getGlobalDescribe().get(ACTION_PLAN_OBJECT) == null) {
            return;
        }
        Id visitId = context.visitId;
        String queryText = 'SELECT Id, Name, StartDate, ActionPlanTemplateVersionId, ActionPlanState ' +
            'FROM ActionPlan WHERE TargetId = :visitId WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1';
        List<SObject> plans = Database.query(queryText);
        if (plans.isEmpty()) {
            return;
        }
        SObject plan = plans[0];
        context.actionPlanId = (Id) plan.get('Id');
        context.actionPlanName = (String) plan.get('Name');
        context.actionPlanStartDate = (Date) plan.get('StartDate');
        context.actionPlanTemplateVersionId = (Id) plan.get('ActionPlanTemplateVersionId');
        context.actionPlanStatus = (String) plan.get('ActionPlanState');
    }

    @TestVisible
    private static List<VisitWizardController.UserCandidate> selectedVisitors(Id visitId) {
        List<VisitWizardController.UserCandidate> selected = new List<VisitWizardController.UserCandidate>();
        if (visitId == null || Schema.getGlobalDescribe().get(VISITOR_OBJECT) == null) {
            return selected;
        }
        Set<Id> userIds = new Set<Id>();
        for (SObject row : Database.query('SELECT Id, Name, AssigneeId FROM Visitor WHERE VisitId = :visitId WITH USER_MODE ORDER BY CreatedDate')) {
            Id assigneeId = (Id) row.get('AssigneeId');
            if (assigneeId != null && String.valueOf(assigneeId).startsWith('005')) {
                userIds.add(assigneeId);
            }
        }
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name, Email, Title, Department
            FROM User
            WHERE Id IN :userIds
            WITH USER_MODE
        ]);
        for (Id userId : userIds) {
            User userRecord = users.get(userId);
            VisitWizardController.UserCandidate candidate = new VisitWizardController.UserCandidate();
            candidate.userId = userId;
            candidate.name = userRecord == null ? String.valueOf(userId) : userRecord.Name;
            candidate.email = userRecord == null ? null : userRecord.Email;
            candidate.title = userRecord == null ? null : userRecord.Title;
            candidate.department = userRecord == null ? null : userRecord.Department;
            candidate.source = 'Saved Visitor';
            candidate.selected = true;
            candidate.locked = false;
            selected.add(candidate);
        }
        return selected;
    }

    @TestVisible
    private static List<VisitWizardController.ContactCandidate> selectedContacts(Id visitId) {
        List<VisitWizardController.ContactCandidate> selected = new List<VisitWizardController.ContactCandidate>();
        if (visitId == null || Schema.getGlobalDescribe().get(VISITED_PARTY_OBJECT) == null) {
            return selected;
        }
        for (SObject row : Database.query(
            'SELECT Id, ContactId, Contact.AccountId, Contact.Name, Contact.Email, Contact.Phone, Contact.Title ' +
            'FROM VisitedParty WHERE VisitId = :visitId WITH USER_MODE ORDER BY CreatedDate'
        )) {
            SObject contactRecord = row.getSObject('Contact');
            if (contactRecord == null) {
                continue;
            }
            VisitWizardController.ContactCandidate candidate = new VisitWizardController.ContactCandidate();
            candidate.contactId = (Id) row.get('ContactId');
            candidate.accountId = (Id) contactRecord.get('AccountId');
            candidate.name = (String) contactRecord.get('Name');
            candidate.email = (String) contactRecord.get('Email');
            candidate.phone = (String) contactRecord.get('Phone');
            candidate.title = (String) contactRecord.get('Title');
            selected.add(candidate);
        }
        return selected;
    }

    private static TaskListResponse taskListResponse(Id visitId, Id actionPlanId) {
        TaskListResponse response = new TaskListResponse();
        response.actionPlanId = actionPlanId;
        response.tasks = new List<TaskSummary>();
        if (visitId == null) {
            response.requiredTasksComplete = true;
            return response;
        }

        if (actionPlanId == null) {
            actionPlanId = latestActionPlanId(visitId);
            response.actionPlanId = actionPlanId;
        }
        Map<Id, SObject> tasksById = queryGenericTasks(visitId);
        Map<Id, SObject> itemByTaskId = new Map<Id, SObject>();
        if (actionPlanId != null && Schema.getGlobalDescribe().get(ACTION_PLAN_ITEM_OBJECT) != null) {
            for (SObject item : Database.query(
                'SELECT Id, Name, ActionPlanId, ItemId, ItemState, IsRequired, DisplayOrder ' +
                'FROM ActionPlanItem WHERE ActionPlanId = :actionPlanId WITH USER_MODE ORDER BY DisplayOrder, CreatedDate'
            )) {
                Id itemId = (Id) item.get('ItemId');
                if (itemId != null && String.valueOf(itemId).startsWith('0py')) {
                    itemByTaskId.put(itemId, item);
                }
            }
        }

        Set<Id> emittedTaskIds = new Set<Id>();
        for (Id taskId : itemByTaskId.keySet()) {
            response.tasks.add(toTaskSummary(tasksById.get(taskId), itemByTaskId.get(taskId)));
            emittedTaskIds.add(taskId);
        }
        for (Id taskId : tasksById.keySet()) {
            if (!emittedTaskIds.contains(taskId)) {
                response.tasks.add(toTaskSummary(tasksById.get(taskId), null));
            }
        }
        response.requiredTasksComplete = requiredTasksComplete(response.tasks);
        return response;
    }

    @TestVisible
    private static Map<Id, SObject> queryGenericTasks(Id visitId) {
        Map<Id, SObject> tasks = new Map<Id, SObject>();
        if (visitId == null || Schema.getGlobalDescribe().get(GENERIC_VISIT_TASK_OBJECT) == null) {
            return tasks;
        }
        for (SObject task : Database.query(
            'SELECT Id, Name, VisitId, Description, Status, StatusCode, StartDateTime, EndDateTime, IsRequired, Sequence ' +
            'FROM GenericVisitTask WHERE VisitId = :visitId WITH USER_MODE ORDER BY Sequence, CreatedDate'
        )) {
            tasks.put((Id) task.get('Id'), task);
        }
        return tasks;
    }

    private static TaskSummary toTaskSummary(SObject task, SObject item) {
        TaskSummary summary = new TaskSummary();
        if (item != null) {
            summary.actionPlanItemId = (Id) item.get('Id');
            summary.itemState = (String) item.get('ItemState');
            summary.required = (Boolean) item.get('IsRequired');
            summary.sequence = (Integer) item.get('DisplayOrder');
            summary.name = (String) item.get('Name');
        }
        if (task != null) {
            summary.genericTaskId = (Id) task.get('Id');
            summary.name = (String) valueOrDefault(task.get('Name'), summary.name);
            summary.status = (String) task.get('Status');
            summary.description = (String) task.get('Description');
            summary.startDateTime = (Datetime) task.get('StartDateTime');
            summary.endDateTime = (Datetime) task.get('EndDateTime');
            summary.required = summary.required == null ? (Boolean) task.get('IsRequired') : summary.required;
            summary.sequence = summary.sequence == null ? (Integer) task.get('Sequence') : summary.sequence;
        }
        summary.category = deriveTaskCategory(summary.name);
        summary.salesTask = summary.category == 'Sales';
        summary.completed = summary.status == 'Completed' || summary.itemState == 'Completed';
        summary.required = summary.required == null ? false : summary.required;
        return summary;
    }

    private static void updateTaskStatus(Id actionPlanItemId, Id genericTaskId, String taskStatus, String itemState) {
        if (actionPlanItemId != null && Schema.getGlobalDescribe().get(ACTION_PLAN_ITEM_OBJECT) != null) {
            Map<String, Schema.SObjectField> itemFields = objectFields(ACTION_PLAN_ITEM_OBJECT);
            SObject itemRecord = Schema.getGlobalDescribe().get(ACTION_PLAN_ITEM_OBJECT).newSObject(actionPlanItemId);
            putIfUpdateable(itemRecord, itemFields, 'ItemState', itemState);
            update Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ itemRecord }).getRecords();
        }
        if (genericTaskId != null && Schema.getGlobalDescribe().get(GENERIC_VISIT_TASK_OBJECT) != null) {
            Map<String, Schema.SObjectField> taskFields = objectFields(GENERIC_VISIT_TASK_OBJECT);
            SObject taskRecord = Schema.getGlobalDescribe().get(GENERIC_VISIT_TASK_OBJECT).newSObject(genericTaskId);
            String currentTaskStatus = currentGenericTaskStatus(genericTaskId);
            putIfUpdateableWhenChanged(taskRecord, taskFields, 'Status', taskStatus, currentTaskStatus);
            if (taskRecord.getPopulatedFieldsAsMap().size() > 1) {
                Database.update(Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ taskRecord }).getRecords(), AccessLevel.USER_MODE);
            }
        }
    }

    private static void updateExistingActionPlan(Id actionPlanId, Map<String, Object> request) {
        Map<String, Schema.SObjectField> fields = objectFields(ACTION_PLAN_OBJECT);
        SObject planRecord = Schema.getGlobalDescribe().get(ACTION_PLAN_OBJECT).newSObject(actionPlanId);
        putIfUpdateable(planRecord, fields, 'Name', request.get('name'));
        String stateValue = actionPlanStateValue(request.get('status'), ACTION_PLAN_STATE_IN_PROGRESS);
        if (!String.isBlank(stateValue)) {
            putIfUpdateable(planRecord, fields, 'ActionPlanState', stateValue);
        }
        Database.update(Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ planRecord }).getRecords(), AccessLevel.USER_MODE);
    }

    private static void completeActionPlanIfRequiredTasksComplete(TaskListResponse response) {
        if (response == null || response.actionPlanId == null || !response.requiredTasksComplete) {
            return;
        }

        Map<String, Schema.SObjectField> fields = objectFields(ACTION_PLAN_OBJECT);
        if (!fields.containsKey('ActionPlanState') || !fields.get('ActionPlanState').getDescribe().isUpdateable()) {
            return;
        }

        String completedState = actionPlanStateValue(ACTION_PLAN_STATE_COMPLETED, ACTION_PLAN_STATE_COMPLETED);
        if (String.isBlank(completedState)) {
            return;
        }

        SObject planRecord = Schema.getGlobalDescribe().get(ACTION_PLAN_OBJECT).newSObject(response.actionPlanId);
        putIfUpdateable(planRecord, fields, 'ActionPlanState', completedState);
        Database.update(Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ planRecord }).getRecords(), AccessLevel.USER_MODE);
    }

    private static void replaceVisitorRows(Id visitId, List<Id> visitorUserIds) {
        if (Schema.getGlobalDescribe().get(VISITOR_OBJECT) == null) {
            return;
        }
        Schema.DescribeSObjectResult visitorDescribe = Schema.getGlobalDescribe().get(VISITOR_OBJECT).getDescribe();
        List<SObject> existing = Database.query('SELECT Id FROM Visitor WHERE VisitId = :visitId');
        if (!existing.isEmpty()) {
            if (!visitorDescribe.isDeletable()) {
                throw userError('You do not have delete access to Visitor.');
            }
            Database.delete(existing, AccessLevel.USER_MODE);
        }

        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name
            FROM User
            WHERE Id IN :visitorUserIds
            WITH USER_MODE
        ]);
        Map<String, Schema.SObjectField> fields = objectFields(VISITOR_OBJECT);
        List<SObject> rows = new List<SObject>();
        for (Id userId : new Set<Id>(visitorUserIds)) {
            SObject row = Schema.getGlobalDescribe().get(VISITOR_OBJECT).newSObject();
            putIfCreateable(row, fields, 'VisitId', visitId);
            putIfCreateable(row, fields, 'AssigneeId', userId);
            putIfCreateable(row, fields, 'Name', users.containsKey(userId) ? users.get(userId).Name : 'Visit Visitor');
            rows.add(row);
        }
        if (!rows.isEmpty()) {
            if (!visitorDescribe.isCreateable()) {
                throw userError('You do not have create access to Visitor.');
            }
            Database.insert(Security.stripInaccessible(AccessType.CREATABLE, rows).getRecords(), AccessLevel.USER_MODE);
        }
    }

    private static void replaceVisitedPartyRows(Id visitId, List<Id> contactIds) {
        if (Schema.getGlobalDescribe().get(VISITED_PARTY_OBJECT) == null) {
            return;
        }
        List<Id> uniqueContactIds = uniqueIdsPreserveOrder(contactIds);
        Schema.DescribeSObjectResult visitedPartyDescribe = Schema.getGlobalDescribe().get(VISITED_PARTY_OBJECT).getDescribe();
        List<SObject> existing = Database.query('SELECT Id FROM VisitedParty WHERE VisitId = :visitId');
        if (!existing.isEmpty()) {
            if (!visitedPartyDescribe.isDeletable()) {
                throw userError('You do not have delete access to VisitedParty.');
            }
            Database.delete(existing, AccessLevel.USER_MODE);
        }

        Map<Id, Contact> contacts = new Map<Id, Contact>([
            SELECT Id, Name
            FROM Contact
            WHERE Id IN :uniqueContactIds
            WITH USER_MODE
        ]);
        Map<String, Schema.SObjectField> fields = objectFields(VISITED_PARTY_OBJECT);
        List<SObject> rows = new List<SObject>();
        Integer rowIndex = 0;
        for (Id contactId : uniqueContactIds) {
            if (!contacts.containsKey(contactId)) {
                continue;
            }
            SObject row = Schema.getGlobalDescribe().get(VISITED_PARTY_OBJECT).newSObject();
            putIfCreateable(row, fields, 'VisitId', visitId);
            putIfCreateable(row, fields, 'ContactId', contactId);
            putIfCreateable(row, fields, 'Name', contacts.get(contactId).Name);
            putIfCreateable(row, fields, 'IsPrimaryContact', rowIndex == 0);
            rows.add(row);
            rowIndex++;
        }
        if (!rows.isEmpty()) {
            if (!visitedPartyDescribe.isCreateable()) {
                throw userError('You do not have create access to VisitedParty.');
            }
            Database.insert(Security.stripInaccessible(AccessType.CREATABLE, rows).getRecords(), AccessLevel.USER_MODE);
        }
    }

    private static List<OpportunitySummary> opportunitySummaries(Id visitId) {
        List<OpportunitySummary> summaries = new List<OpportunitySummary>();
        if (visitId == null || !hasField('Opportunity', OPPORTUNITY_VISIT_FIELD)) {
            return summaries;
        }
        for (Opportunity opportunityRecord : Database.query(
            'SELECT Id, Name, StageName, CloseDate, Amount FROM Opportunity WHERE Visit__c = :visitId WITH USER_MODE ORDER BY CreatedDate DESC'
        )) {
            summaries.add(toOpportunitySummary(opportunityRecord));
        }
        return summaries;
    }

    private static OpportunitySummary toOpportunitySummary(Opportunity opportunityRecord) {
        OpportunitySummary summary = new OpportunitySummary();
        summary.opportunityId = opportunityRecord.Id;
        summary.name = opportunityRecord.Name;
        summary.stageName = opportunityRecord.StageName;
        summary.closeDate = opportunityRecord.CloseDate;
        summary.amount = opportunityRecord.Amount;
        return summary;
    }

    private static List<NoteSummary> taskNotes(Id genericTaskId) {
        List<NoteSummary> notes = new List<NoteSummary>();
        if (genericTaskId == null ||
            Schema.getGlobalDescribe().get(CONTENT_NOTE_OBJECT) == null ||
            Schema.getGlobalDescribe().get(CONTENT_DOCUMENT_LINK_OBJECT) == null) {
            return notes;
        }

        Set<Id> noteIds = new Set<Id>();
        for (ContentDocumentLink linkRecord : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :genericTaskId
            AND ContentDocument.FileType = 'SNOTE'
            WITH USER_MODE
            ORDER BY SystemModstamp DESC
            LIMIT 50
        ]) {
            noteIds.add(linkRecord.ContentDocumentId);
        }
        if (noteIds.isEmpty()) {
            return notes;
        }

        for (ContentNote noteRecord : [
            SELECT Id, Title, Content, TextPreview, CreatedDate, CreatedBy.Name
            FROM ContentNote
            WHERE Id IN :noteIds
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            NoteSummary summary = new NoteSummary();
            summary.contentNoteId = noteRecord.Id;
            summary.contentDocumentId = noteRecord.Id;
            summary.title = noteRecord.Title;
            summary.body = noteRecord.Content == null ? null : noteRecord.Content.toString();
            summary.textPreview = noteRecord.TextPreview;
            summary.createdDate = noteRecord.CreatedDate;
            summary.createdByName = noteRecord.CreatedBy == null ? null : noteRecord.CreatedBy.Name;
            notes.add(summary);
        }
        return notes;
    }

    @TestVisible
    private static void validateTaskCompletion(Id genericTaskId, Datetime startDateTime, Datetime endDateTime) {
        if (startDateTime == null) {
            throw userError('Start Date Time is required to complete a task.');
        }
        if (endDateTime == null) {
            throw userError('End Date Time is required to complete a task.');
        }
        if (endDateTime < startDateTime) {
            throw userError('End Date Time must be after Start Date Time.');
        }
        if (genericTaskId == null || !hasEnhancedTaskNote(genericTaskId)) {
            throw userError('Add a note before completing the topic.');
        }
    }

    @TestVisible
    private static Boolean hasEnhancedTaskNote(Id genericTaskId) {
        if (genericTaskId == null ||
            Schema.getGlobalDescribe().get(CONTENT_DOCUMENT_LINK_OBJECT) == null) {
            return false;
        }
        return ![
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :genericTaskId
            AND ContentDocument.FileType = 'SNOTE'
            WITH USER_MODE
            LIMIT 1
        ].isEmpty();
    }

    @TestVisible
    private static void saveWizardMarkers(Id visitId, String resumePage, String stateJson, Id actionPlanId) {
        if (visitId == null) {
            return;
        }
        Map<String, Schema.SObjectField> fields = objectFields(VISIT_OBJECT);
        SObject visitRecord = Schema.getGlobalDescribe().get(VISIT_OBJECT).newSObject(visitId);
        putIfUpdateable(visitRecord, fields, RESUME_FIELD, resumePage);
        putIfUpdateable(visitRecord, fields, STATE_FIELD, stateJson);
        putIfUpdateable(visitRecord, fields, ACTION_PLAN_ID_FIELD, actionPlanId);
        Database.update(Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject>{ visitRecord }).getRecords(), AccessLevel.USER_MODE);
    }

    @TestVisible
    private static Id latestActionPlanId(Id visitId) {
        if (visitId == null || Schema.getGlobalDescribe().get(ACTION_PLAN_OBJECT) == null) {
            return null;
        }
        List<SObject> plans = Database.query('SELECT Id FROM ActionPlan WHERE TargetId = :visitId WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1');
        return plans.isEmpty() ? null : (Id) plans[0].get('Id');
    }

    @TestVisible
    private static Boolean requiredTasksComplete(List<TaskSummary> tasks) {
        for (TaskSummary task : tasks) {
            if (task.required && !task.completed) {
                return false;
            }
        }
        return true;
    }

    @TestVisible
    private static Integer nextTopicSequence(Id visitId) {
        Map<String, Schema.SObjectField> fields = objectFields(GENERIC_VISIT_TASK_OBJECT);
        if (visitId == null ||
            !fields.containsKey('Sequence') ||
            !fields.get('Sequence').getDescribe().isAccessible()) {
            return 1;
        }

        List<SObject> tasks = Database.query(
            'SELECT Sequence FROM GenericVisitTask WHERE VisitId = :visitId WITH USER_MODE ORDER BY Sequence DESC NULLS LAST LIMIT 1'
        );
        if (tasks.isEmpty() || tasks[0].get('Sequence') == null) {
            return 1;
        }
        return ((Integer) tasks[0].get('Sequence')) + 1;
    }

    @TestVisible
    private static void validateRequiredVisitFields(SObject visitRecord, Map<String, Schema.SObjectField> fields) {
        List<String> missingLabels = new List<String>();
        for (String fieldName : fields.keySet()) {
            Schema.DescribeFieldResult describe = fields.get(fieldName).getDescribe();
            if (
                describe.isCreateable() &&
                !describe.isNillable() &&
                !describe.isDefaultedOnCreate() &&
                describe.getType() != Schema.DisplayType.ID &&
                !describe.isAutoNumber() &&
                describe.getName() != 'OwnerId' &&
                visitRecord.get(describe.getName()) == null
            ) {
                missingLabels.add(describe.getLabel());
            }
        }
        if (!missingLabels.isEmpty()) {
            throw userError('Complete required Visit fields: ' + String.join(missingLabels, ', '));
        }
    }

    @TestVisible
    private static void assertActiveUsers(List<Id> userIds) {
        Set<Id> uniqueIds = new Set<Id>(userIds);
        if (uniqueIds.isEmpty()) {
            return;
        }
        Integer activeCount = [
            SELECT COUNT()
            FROM User
            WHERE Id IN :uniqueIds
            AND IsActive = true
            WITH USER_MODE
        ];
        if (activeCount != uniqueIds.size()) {
            throw userError('Only active Salesforce Users can be selected as Visitors.');
        }
    }

    @TestVisible
    private static void assertContactsBelongToAccount(Id accountId, List<Id> contactIds) {
        Set<Id> uniqueIds = new Set<Id>(contactIds);
        if (accountId == null || uniqueIds.isEmpty()) {
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
            throw userError('Visited parties must be contacts on the selected Account.');
        }
    }

    @TestVisible
    private static List<String> visitFormFieldNames() {
        List<String> fields = new List<String>{
            'AccountId',
            'RecordTypeId',
            'VisitorId',
            'PlaceId',
            'PlannedVisitStartTime',
            'PlannedVisitEndTime',
            'ActualVisitStartTime',
            'ActualVisitEndTime',
            'VisitPriority',
            'ContextId',
            'InstructionDescription',
            'Status'
        };
        List<String> available = new List<String>();
        for (String fieldName : fields) {
            if (hasField(VISIT_OBJECT, fieldName)) {
                available.add(fieldName);
            }
        }
        return available;
    }

    @TestVisible
    private static void putVisitStatusInProgress(SObject record, Map<String, Schema.SObjectField> fields, Boolean creating) {
        if (!fields.containsKey('Status')) {
            return;
        }

        Schema.DescribeFieldResult describe = fields.get('Status').getDescribe();
        if ((creating && !describe.isCreateable()) || (!creating && !describe.isUpdateable())) {
            return;
        }

        String statusValue = activePicklistValue(fields.get('Status'), VISIT_STATUS_IN_PROGRESS);
        if (statusValue == null) {
            statusValue = activePicklistValue(fields.get('Status'), VISIT_STATUS_IN_PROGRESS_LABEL);
        }
        if (statusValue != null) {
            record.put('Status', statusValue);
        }
    }

    @TestVisible
    private static String actionPlanStateValue(Object requestedValue, String preferredValue) {
        String requestedText = blankToNull(requestedValue);
        Map<String, Schema.SObjectField> fields = objectFields(ACTION_PLAN_OBJECT);
        Schema.SObjectField stateField = fields.get('ActionPlanState');
        if (!String.isBlank(requestedText) && activePicklistValue(stateField, requestedText) != null) {
            return requestedText;
        }

        String preferred = activePicklistValue(stateField, preferredValue);
        if (preferred != null) {
            return preferred;
        }
        return firstActivePicklistValue(stateField);
    }

    @TestVisible
    private static String preferredActionPlanState(List<VisitWizardController.PicklistOption> options, String fallbackValue) {
        if (options != null) {
            for (VisitWizardController.PicklistOption option : options) {
                if (option.value == ACTION_PLAN_STATE_IN_PROGRESS) {
                    return option.value;
                }
            }
        }
        return fallbackValue;
    }

    @TestVisible
    private static String firstActivePicklistValue(Schema.SObjectField fieldToken) {
        if (fieldToken == null) {
            return null;
        }
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    @TestVisible
    private static String activeOpportunityStage(String preferredStage) {
        Map<String, Schema.SObjectField> fields = Opportunity.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        String preferred = activePicklistValue(fields.get('StageName'), preferredStage);
        if (preferred != null) {
            return preferred;
        }
        for (Schema.PicklistEntry entry : fields.get('StageName').getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return 'Prospecting';
    }

    @TestVisible
    private static String activePicklistValue(Schema.SObjectField fieldToken, String value) {
        if (fieldToken == null || String.isBlank(value)) {
            return null;
        }
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == value) {
                return entry.getValue();
            }
        }
        return null;
    }

    @TestVisible
    private static Id defaultVisitRecordTypeId() {
        for (VisitWizardController.RecordTypeOption recordType : getVisitRecordTypesV6()) {
            if (recordType.defaultRecordTypeMapping) {
                return (Id) recordType.value;
            }
        }
        List<VisitWizardController.RecordTypeOption> recordTypes = getVisitRecordTypesV6();
        return recordTypes.isEmpty() ? null : (Id) recordTypes[0].value;
    }

    @TestVisible
    private static String deriveTaskCategory(String taskName) {
        return !String.isBlank(taskName) && taskName.toLowerCase().contains('sales') ? 'Sales' : null;
    }

    @TestVisible
    private static String visitDisplayName(Id visitId) {
        if (visitId == null) {
            return null;
        }
        try {
            SObject visitRecord = queryVisit(visitId);
            return (String) visitRecord.get('Name');
        } catch (Exception ignored) {
            return String.valueOf(visitId);
        }
    }

    @TestVisible
    private static String stripHtml(String value) {
        return String.isBlank(value) ? '' : value.replaceAll('<[^>]+>', '').replace('&nbsp;', ' ').trim();
    }

    @TestVisible
    private static Map<String, Object> parseRequest(String requestJson, String message) {
        if (String.isBlank(requestJson)) {
            throw userError(message);
        }
        try {
            return asMap(JSON.deserializeUntyped(requestJson));
        } catch (JSONException e) {
            throw userError('Request could not be read.');
        }
    }

    @TestVisible
    private static Map<String, Object> asMap(Object value) {
        return value instanceof Map<String, Object> ? (Map<String, Object>) value : new Map<String, Object>();
    }

    @TestVisible
    private static List<Id> idsFromList(Object value) {
        List<Id> ids = new List<Id>();
        if (!(value instanceof List<Object>)) {
            return ids;
        }
        Set<Id> seen = new Set<Id>();
        for (Object rawValue : (List<Object>) value) {
            Id idValue = toId(rawValue);
            if (idValue != null && !seen.contains(idValue)) {
                ids.add(idValue);
                seen.add(idValue);
            }
        }
        return ids;
    }

    @TestVisible
    private static List<Id> uniqueIdsPreserveOrder(List<Id> rawIds) {
        List<Id> ids = new List<Id>();
        Set<Id> seen = new Set<Id>();
        List<Id> sourceIds = rawIds == null ? new List<Id>() : rawIds;
        for (Id rawId : sourceIds) {
            if (rawId != null && !seen.contains(rawId)) {
                ids.add(rawId);
                seen.add(rawId);
            }
        }
        return ids;
    }

    @TestVisible
    private static Id toId(Object value) {
        if (value == null) {
            return null;
        }
        String rawValue = String.valueOf(value);
        if (String.isBlank(rawValue)) {
            return null;
        }
        Matcher matcher = Pattern.compile('[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?').matcher(rawValue);
        if (!matcher.find()) {
            return null;
        }
        try {
            return (Id) matcher.group(0);
        } catch (Exception ignored) {
            return null;
        }
    }

    @TestVisible
    private static Date toDate(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }
        return Date.valueOf(String.valueOf(value));
    }

    @TestVisible
    private static Datetime toDateTime(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }
        try {
            return (Datetime) JSON.deserialize(JSON.serialize(String.valueOf(value)), Datetime.class);
        } catch (JSONException e) {
            throw userError('Enter a valid date and time.');
        }
    }

    @TestVisible
    private static Decimal toDecimal(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(value));
    }

    @TestVisible
    private static String blankToNull(Object value) {
        return value == null || String.isBlank(String.valueOf(value)) ? null : String.valueOf(value);
    }

    @TestVisible
    private static Object valueOrDefault(Object value, Object fallback) {
        return value == null || String.valueOf(value) == '' ? fallback : value;
    }

    @TestVisible
    private static Object fieldValue(SObject record, String fieldName) {
        return record != null && hasField(String.valueOf(record.getSObjectType()), fieldName) ? record.get(fieldName) : null;
    }

    @TestVisible
    private static Map<String, Schema.SObjectField> objectFields(String objectName) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        return objectType == null ? new Map<String, Schema.SObjectField>() : objectType.getDescribe().fields.getMap();
    }

    @TestVisible
    private static Boolean hasField(String objectName, String fieldName) {
        return objectFields(objectName).containsKey(fieldName);
    }

    @TestVisible
    private static void putIfCreateable(SObject record, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (fields.containsKey(fieldName) && fields.get(fieldName).getDescribe().isCreateable()) {
            record.put(fieldName, coerceValue(value, fields.get(fieldName).getDescribe().getType()));
        }
    }

    @TestVisible
    private static void putIfUpdateable(SObject record, Map<String, Schema.SObjectField> fields, String fieldName, Object value) {
        if (fields.containsKey(fieldName) && fields.get(fieldName).getDescribe().isUpdateable()) {
            record.put(fieldName, coerceValue(value, fields.get(fieldName).getDescribe().getType()));
        }
    }

    @TestVisible
    private static void putIfUpdateableWhenChanged(
        SObject record,
        Map<String, Schema.SObjectField> fields,
        String fieldName,
        Object value,
        String currentValue
    ) {
        if (!fields.containsKey(fieldName) || !fields.get(fieldName).getDescribe().isUpdateable()) {
            return;
        }
        String nextValue = value == null ? null : String.valueOf(value);
        if (nextValue == currentValue || (String.isBlank(nextValue) && String.isBlank(currentValue))) {
            return;
        }
        record.put(fieldName, coerceValue(value, fields.get(fieldName).getDescribe().getType()));
    }

    @TestVisible
    private static void putIfWritable(SObject record, Map<String, Schema.SObjectField> fields, String fieldName, Object value, Boolean creating) {
        if (creating) {
            putIfCreateable(record, fields, fieldName, value);
        } else {
            putIfUpdateable(record, fields, fieldName, value);
        }
    }

    @TestVisible
    private static String currentGenericTaskStatus(Id genericTaskId) {
        Map<String, Schema.SObjectField> fields = objectFields(GENERIC_VISIT_TASK_OBJECT);
        if (genericTaskId == null ||
            !fields.containsKey('Status') ||
            !fields.get('Status').getDescribe().isAccessible()) {
            return null;
        }
        List<SObject> records = Database.query(
            'SELECT Status FROM GenericVisitTask WHERE Id = :genericTaskId WITH USER_MODE LIMIT 1'
        );
        if (records.isEmpty()) {
            return null;
        }
        Object value = records[0].get('Status');
        return value == null ? null : String.valueOf(value);
    }

    @TestVisible
    private static Object coerceValue(Object value, Schema.DisplayType fieldType) {
        if (value == null || String.valueOf(value) == '') {
            return null;
        }
        if (fieldType == Schema.DisplayType.DATE) {
            return Date.valueOf(String.valueOf(value));
        }
        if (fieldType == Schema.DisplayType.DATETIME) {
            if (value instanceof Datetime) {
                return value;
            }
            return (DateTime) JSON.deserialize(JSON.serialize(String.valueOf(value)), DateTime.class);
        }
        if (fieldType == Schema.DisplayType.BOOLEAN) {
            return value instanceof Boolean ? value : Boolean.valueOf(String.valueOf(value));
        }
        if (fieldType == Schema.DisplayType.CURRENCY || fieldType == Schema.DisplayType.DOUBLE || fieldType == Schema.DisplayType.PERCENT) {
            return Decimal.valueOf(String.valueOf(value));
        }
        if (fieldType == Schema.DisplayType.INTEGER) {
            return Integer.valueOf(String.valueOf(value));
        }
        if (fieldType == Schema.DisplayType.LONG) {
            return Long.valueOf(String.valueOf(value));
        }
        return value;
    }

    @TestVisible
    private static String firstDmlMessage(DmlException e) {
        return e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
    }

    @TestVisible
    private static String firstExceptionMessage(Exception e) {
        String message = e == null ? null : e.getMessage();
        if (String.isBlank(message)) {
            return 'Visit could not be saved. Please try again.';
        }
        if (message.contains('ORA-01427') || message.contains('single-row subquery returns more than one row')) {
            return 'Visited parties could not be saved because Salesforce found more than one matching contact row. Remove the visited party, add it again, and click Next.';
        }
        return message;
    }

    @TestVisible
    private static AuraHandledException userError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }
}
