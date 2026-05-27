@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.NcssCount,PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters,PMD.OperationWithHighCostInLoop,PMD.ApexDoc')
public inherited sharing class AutomationControlService {
    private static final String CUSTOM_PERMISSION = 'Manage_Automation_Control_Center';
    private static final String ALL_OBJECTS = '__ALL_OBJECTS__';
    private static final String TYPE_VALIDATION_RULE = 'Validation Rule';
    private static final String TYPE_FLOW = 'Flow';
    private static final String ACTION_BULK_DISABLE = 'Bulk Disable';
    private static final String ACTION_BULK_REENABLE = 'Bulk Re-enable';
    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE = 200;
    private static final Integer MAX_BULK_ITEMS = 250;
    private static final Integer PREVIEW_ROW_LIMIT = 50;

    @TestVisible private static Boolean bypassPermissionCheck = false;

    public class ObjectOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String apiName;
        @AuraEnabled public String objectLabel;
    }

    @SuppressWarnings('PMD.TooManyFields')
    public class AutomationRow {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String metadataType;
        @AuraEnabled public String toolingId;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String metadataApiName;
        @AuraEnabled public String metadataLabel;
        @AuraEnabled public String description;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Boolean active;
        @AuraEnabled public String status;
        @AuraEnabled public String flowType;
        @AuraEnabled public Integer activeVersionNumber;
        @AuraEnabled public Integer latestVersionNumber;
        @AuraEnabled public String lastModifiedByName;
        @AuraEnabled public String lastModifiedDate;
        @AuraEnabled public String manageableState;
        @AuraEnabled public Boolean actionDisabled;
        @AuraEnabled public String actionLabel;
    }

    public class PageResult {
        @AuraEnabled public List<AutomationRow> rows;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Boolean hasPrevious;
        @AuraEnabled public Boolean hasNext;
        @AuraEnabled public String summary;
    }

    public class BulkPreviewResult {
        @AuraEnabled public String metadataType;
        @AuraEnabled public String actionType;
        @AuraEnabled public String scopeLabel;
        @AuraEnabled public Integer affectedCount;
        @AuraEnabled public List<AutomationRow> previewRows;
    }

    public class OperationResult {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String historyId;
        @AuraEnabled public String metadataType;
        @AuraEnabled public String toolingId;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String metadataApiName;
        @AuraEnabled public String metadataLabel;
        @AuraEnabled public String previousStatus;
        @AuraEnabled public String newStatus;
        @AuraEnabled public Integer previousVersionNumber;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        public String metadataBackupJson;
    }

    public class BulkActionResult {
        @AuraEnabled public String batchId;
        @AuraEnabled public Integer requestedCount;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer failureCount;
        @AuraEnabled public String message;
        @AuraEnabled public List<OperationResult> results;
    }

    public class HistoryBatch {
        @AuraEnabled public String batchId;
        @AuraEnabled public String label;
        @AuraEnabled public String metadataType;
        @AuraEnabled public String scopeLabel;
        @AuraEnabled public Datetime disabledDate;
        @AuraEnabled public String disabledByName;
        @AuraEnabled public Integer itemCount;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public Integer reenabledCount;
    }

    public static List<ObjectOption> getObjectOptions(String searchTerm) {
        requireAccess();
        String normalizedTerm = normalize(searchTerm);
        List<ObjectOption> options = new List<ObjectOption>();
        options.add(allObjectsOption());

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Map<String, ObjectOption> optionsBySortKey = new Map<String, ObjectOption>();
        for (String objectApiName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult describe = globalDescribe.get(objectApiName).getDescribe();
            if (describe.isDeprecatedAndHidden()) {
                continue;
            }
            String label = describe.getLabel();
            String searchable = (label + ' ' + describe.getName()).toLowerCase();
            if (normalizedTerm != null && !searchable.contains(normalizedTerm)) {
                continue;
            }

            ObjectOption option = new ObjectOption();
            option.apiName = describe.getName();
            option.value = describe.getName();
            option.objectLabel = label;
            option.label = label + ' (' + describe.getName() + ')';
            optionsBySortKey.put(sortKey(label, describe.getName()), option);
        }

        List<String> sortKeys = new List<String>(optionsBySortKey.keySet());
        sortKeys.sort();
        for (String key : sortKeys) {
            options.add(optionsBySortKey.get(key));
        }
        return options;
    }

    public static PageResult getValidationRules(
        String objectApiName,
        Boolean showDisabled,
        Integer pageSize,
        Integer pageNumber
    ) {
        requireAccess();
        Integer normalizedPageSize = pageSize(pageSize);
        Integer normalizedPageNumber = pageNumber(pageNumber);
        List<AutomationRow> rows = queryValidationRows(
            normalizeObjectScope(objectApiName),
            showDisabled == true,
            normalizedPageSize + 1,
            (normalizedPageNumber - 1) * normalizedPageSize
        );
        return page(rows, normalizedPageNumber, normalizedPageSize, 'Validation Rules');
    }

    public static PageResult getFlows(String searchTerm, Integer pageSize, Integer pageNumber) {
        requireAccess();
        Integer normalizedPageSize = pageSize(pageSize);
        Integer normalizedPageNumber = pageNumber(pageNumber);
        List<AutomationRow> rows = queryFlowRows(
            normalize(searchTerm),
            normalizedPageSize + 1,
            (normalizedPageNumber - 1) * normalizedPageSize
        );
        return page(rows, normalizedPageNumber, normalizedPageSize, 'Flows');
    }

    public static BulkPreviewResult previewValidationRuleBulkDisable(String objectApiName) {
        requireAccess();
        List<AutomationRow> rows = activeValidationRows(normalizeObjectScope(objectApiName), MAX_BULK_ITEMS + 1);
        assertBulkLimit(rows, TYPE_VALIDATION_RULE);
        return preview(TYPE_VALIDATION_RULE, ACTION_BULK_DISABLE, validationScopeLabel(objectApiName), rows);
    }

    public static BulkPreviewResult previewFlowBulkDeactivate() {
        requireAccess();
        List<AutomationRow> rows = activeFlowRows(MAX_BULK_ITEMS + 1);
        assertBulkLimit(rows, TYPE_FLOW);
        return preview(TYPE_FLOW, ACTION_BULK_DISABLE, 'All active flows', rows);
    }

    public static OperationResult disableValidationRule(String validationRuleId) {
        requireAccess();
        List<AutomationRow> rows = queryValidationRowsByIds(new Set<String>{ validateToolingId(validationRuleId) });
        if (rows.isEmpty()) {
            throw userError('Validation rule was not found.');
        }
        if (rows[0].active != true) {
            throw userError('This validation rule is already inactive. No change was made.');
        }
        return updateValidationRuleRows(rows, false)[0];
    }

    public static OperationResult deactivateFlow(String flowDefinitionId) {
        requireAccess();
        List<AutomationRow> rows = queryFlowRowsByDefinitionIds(new Set<String>{ validateToolingId(flowDefinitionId) });
        if (rows.isEmpty()) {
            throw userError('Flow was not found.');
        }
        if (rows[0].active != true) {
            throw userError('This flow is already inactive. No change was made.');
        }
        return updateFlowRows(rows, 0)[0];
    }

    public static OperationResult activateFlow(String flowDefinitionId) {
        requireAccess();
        List<AutomationRow> rows = queryFlowRowsByDefinitionIds(new Set<String>{ validateToolingId(flowDefinitionId) });
        if (rows.isEmpty()) {
            throw userError('Flow was not found.');
        }
        if (rows[0].active == true) {
            throw userError('This flow is already active. No change was made.');
        }
        if (rows[0].latestVersionNumber == null) {
            throw userError('This flow does not have a version that can be activated.');
        }
        rows[0].activeVersionNumber = rows[0].latestVersionNumber;
        return updateFlowRows(rows, -1)[0];
    }

    public static BulkActionResult bulkDisableValidationRules(String objectApiName) {
        requireAccess();
        List<AutomationRow> rows = activeValidationRows(normalizeObjectScope(objectApiName), MAX_BULK_ITEMS + 1);
        assertBulkLimit(rows, TYPE_VALIDATION_RULE);
        String batchId = batchId('VRD');
        List<OperationResult> results = updateValidationRuleRows(rows, false);
        insertDisableHistory(batchId, results);
        return bulkResult(batchId, rows.size(), results, 'Validation rules bulk disable finished.');
    }

    public static BulkActionResult bulkDeactivateFlows() {
        requireAccess();
        List<AutomationRow> rows = activeFlowRows(MAX_BULK_ITEMS + 1);
        assertBulkLimit(rows, TYPE_FLOW);
        String batchId = batchId('FLD');
        List<OperationResult> results = updateFlowRows(rows, 0);
        insertDisableHistory(batchId, results);
        return bulkResult(batchId, rows.size(), results, 'Flows bulk deactivate finished.');
    }

    public static List<HistoryBatch> getHistoryBatches(String metadataType) {
        requireAccess();
        String normalizedType = normalizeMetadataType(metadataType);
        Map<String, HistoryBatch> batchesById = new Map<String, HistoryBatch>();

        for (Automation_Control_History__c history : [
            SELECT Batch_Id__c, Metadata_Type__c, Object_API_Name__c, Disabled_Date__c, Disabled_By__r.Name,
                Is_Reenabled__c, New_Status__c
            FROM Automation_Control_History__c
            WHERE Metadata_Type__c = :normalizedType
                AND Action_Type__c = :ACTION_BULK_DISABLE
            WITH USER_MODE
            ORDER BY Disabled_Date__c DESC
            LIMIT 2000
        ]) {
            if (String.isBlank(history.Batch_Id__c)) {
                continue;
            }
            HistoryBatch batch = batchesById.get(history.Batch_Id__c);
            if (batch == null) {
                batch = new HistoryBatch();
                batch.batchId = history.Batch_Id__c;
                batch.metadataType = history.Metadata_Type__c;
                batch.disabledDate = history.Disabled_Date__c;
                batch.disabledByName = history.Disabled_By__r == null ? null : history.Disabled_By__r.Name;
                batch.scopeLabel = String.isBlank(history.Object_API_Name__c) ? 'All' : history.Object_API_Name__c;
                batch.itemCount = 0;
                batch.pendingCount = 0;
                batch.reenabledCount = 0;
                batchesById.put(batch.batchId, batch);
            }

            if (history.New_Status__c == 'Inactive') {
                batch.itemCount++;
                if (history.Is_Reenabled__c == true) {
                    batch.reenabledCount++;
                } else {
                    batch.pendingCount++;
                }
            }
        }

        List<HistoryBatch> batches = new List<HistoryBatch>(batchesById.values());
        for (HistoryBatch batch : batches) {
            batch.label = batch.batchId + ' - ' + batch.pendingCount + ' pending of ' + batch.itemCount;
        }
        return batches;
    }

    public static List<OperationResult> getHistoryRows(String batchId) {
        requireAccess();
        List<OperationResult> results = new List<OperationResult>();
        for (Automation_Control_History__c history : historyRows(batchId)) {
            results.add(historyToResult(history));
        }
        return results;
    }

    public static BulkActionResult reenableFromHistory(String batchId) {
        requireAccess();
        List<Automation_Control_History__c> rows = pendingHistoryRows(batchId);
        if (rows.isEmpty()) {
            throw userError('No pending history rows were found for this batch.');
        }
        if (rows.size() > MAX_BULK_ITEMS) {
            throw userError('This history batch has more than ' + MAX_BULK_ITEMS + ' pending rows. Re-enable in smaller batches.');
        }

        String metadataType = rows[0].Metadata_Type__c;
        List<OperationResult> results = metadataType == TYPE_FLOW
            ? reenableFlows(rows)
            : updateValidationRuleRows(historyRowsToAutomationRows(rows), true);

        markReenabled(rows, results);
        insertReenableHistory(batchId('RBE'), results);
        return bulkResult(batchId, rows.size(), results, 'Re-enable from history finished.');
    }

    private static List<AutomationRow> queryValidationRows(
        String objectScope,
        Boolean includeInactive,
        Integer limitSize,
        Integer offsetRows
    ) {
        List<String> conditions = new List<String>();
        if (objectScope != ALL_OBJECTS) {
            conditions.add('EntityDefinition.QualifiedApiName = ' + soqlString(objectScope));
        }
        if (includeInactive != true) {
            conditions.add('Active = true');
        }

        String soql =
            'SELECT Id, ValidationName, Active, Description, ErrorMessage, EntityDefinition.QualifiedApiName, ' +
            'EntityDefinition.MasterLabel, LastModifiedBy.Name, LastModifiedDate, ManageableState ' +
            'FROM ValidationRule' +
            whereClause(conditions) +
            ' ORDER BY EntityDefinitionId, ValidationName LIMIT ' +
            limitSize +
            ' OFFSET ' +
            offsetRows;
        return validationRows(new AutomationControlToolingClient().query(soql).records);
    }

    private static List<AutomationRow> queryValidationRowsByIds(Set<String> ids) {
        if (ids.isEmpty()) {
            return new List<AutomationRow>();
        }
        String soql =
            'SELECT Id, ValidationName, Active, Description, ErrorMessage, EntityDefinition.QualifiedApiName, ' +
            'EntityDefinition.MasterLabel, LastModifiedBy.Name, LastModifiedDate, ManageableState ' +
            'FROM ValidationRule WHERE Id IN (' +
            quotedCsv(ids) +
            ') ORDER BY EntityDefinitionId, ValidationName';
        return validationRows(new AutomationControlToolingClient().query(soql).records);
    }

    private static List<AutomationRow> queryFlowRows(String searchTerm, Integer limitSize, Integer offsetRows) {
        List<String> conditions = new List<String>();
        if (searchTerm != null) {
            String escapedTerm = String.escapeSingleQuotes(searchTerm);
            conditions.add('(DeveloperName LIKE \'%' + escapedTerm + '%\' OR MasterLabel LIKE \'%' + escapedTerm + '%\')');
        }

        String soql =
            'SELECT Id, DeveloperName, MasterLabel, ActiveVersionId, ActiveVersion.VersionNumber, ' +
            'LatestVersion.VersionNumber, LatestVersion.Status, LatestVersion.ProcessType, ' +
            'LatestVersion.LastModifiedBy.Name, LatestVersion.LastModifiedDate, ManageableState ' +
            'FROM FlowDefinition' +
            whereClause(conditions) +
            ' ORDER BY MasterLabel, DeveloperName LIMIT ' +
            limitSize +
            ' OFFSET ' +
            offsetRows;
        return flowRows(new AutomationControlToolingClient().query(soql).records);
    }

    private static List<AutomationRow> queryFlowRowsByDefinitionIds(Set<String> ids) {
        if (ids.isEmpty()) {
            return new List<AutomationRow>();
        }
        String soql =
            'SELECT Id, DeveloperName, MasterLabel, ActiveVersionId, ActiveVersion.VersionNumber, ' +
            'LatestVersion.VersionNumber, LatestVersion.Status, LatestVersion.ProcessType, ' +
            'LatestVersion.LastModifiedBy.Name, LatestVersion.LastModifiedDate, ManageableState ' +
            'FROM FlowDefinition WHERE Id IN (' +
            quotedCsv(ids) +
            ') ORDER BY MasterLabel, DeveloperName';
        return flowRows(new AutomationControlToolingClient().query(soql).records);
    }

    private static List<AutomationRow> activeValidationRows(String objectScope, Integer maxRows) {
        List<String> conditions = new List<String>{ 'Active = true' };
        if (objectScope != ALL_OBJECTS) {
            conditions.add('EntityDefinition.QualifiedApiName = ' + soqlString(objectScope));
        }
        String soql =
            'SELECT Id, ValidationName, Active, Description, ErrorMessage, EntityDefinition.QualifiedApiName, ' +
            'EntityDefinition.MasterLabel, LastModifiedBy.Name, LastModifiedDate, ManageableState ' +
            'FROM ValidationRule' +
            whereClause(conditions) +
            ' ORDER BY EntityDefinitionId, ValidationName';
        return validationRows(queryAll(soql, maxRows));
    }

    private static List<AutomationRow> activeFlowRows(Integer maxRows) {
        String soql =
            'SELECT Id, DeveloperName, MasterLabel, ActiveVersionId, ActiveVersion.VersionNumber, ' +
            'LatestVersion.VersionNumber, LatestVersion.Status, LatestVersion.ProcessType, ' +
            'LatestVersion.LastModifiedBy.Name, LatestVersion.LastModifiedDate, ManageableState ' +
            'FROM FlowDefinition WHERE ActiveVersionId != null ORDER BY MasterLabel, DeveloperName';
        return flowRows(queryAll(soql, maxRows));
    }

    private static List<Map<String, Object>> queryAll(String soql, Integer maxRows) {
        AutomationControlToolingClient client = new AutomationControlToolingClient();
        AutomationControlToolingClient.QueryPage page = client.query(soql);
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        while (true) {
            records.addAll(page.records);
            if (records.size() > maxRows || page.done == true || String.isBlank(page.nextRecordsUrl)) {
                break;
            }
            page = client.queryMore(page.nextRecordsUrl);
        }
        return records;
    }

    private static List<AutomationRow> validationRows(List<Map<String, Object>> records) {
        List<AutomationRow> rows = new List<AutomationRow>();
        for (Map<String, Object> record : records) {
            Map<String, Object> entity = child(record, 'EntityDefinition');
            Map<String, Object> modifiedBy = child(record, 'LastModifiedBy');
            Boolean active = boolValue(record.get('Active'));

            AutomationRow row = new AutomationRow();
            row.rowKey = 'vr-' + stringValue(record.get('Id'));
            row.metadataType = TYPE_VALIDATION_RULE;
            row.toolingId = stringValue(record.get('Id'));
            row.objectApiName = stringValue(entity.get('QualifiedApiName'));
            row.objectLabel = stringValue(entity.get('MasterLabel'));
            row.metadataApiName = stringValue(record.get('ValidationName'));
            row.metadataLabel = row.metadataApiName;
            row.description = stringValue(record.get('Description'));
            row.errorMessage = stringValue(record.get('ErrorMessage'));
            row.active = active;
            row.status = active == true ? 'Active' : 'Inactive';
            row.lastModifiedByName = stringValue(modifiedBy.get('Name'));
            row.lastModifiedDate = stringValue(record.get('LastModifiedDate'));
            row.manageableState = stringValue(record.get('ManageableState'));
            row.actionDisabled = active != true;
            row.actionLabel = active == true ? 'Disable' : 'Inactive';
            rows.add(row);
        }
        return rows;
    }

    private static List<AutomationRow> flowRows(List<Map<String, Object>> records) {
        List<AutomationRow> rows = new List<AutomationRow>();
        for (Map<String, Object> record : records) {
            Map<String, Object> activeVersion = child(record, 'ActiveVersion');
            Map<String, Object> latestVersion = child(record, 'LatestVersion');
            Map<String, Object> modifiedBy = child(latestVersion, 'LastModifiedBy');
            Boolean active = record.get('ActiveVersionId') != null;

            AutomationRow row = new AutomationRow();
            row.rowKey = 'flow-' + stringValue(record.get('Id'));
            row.metadataType = TYPE_FLOW;
            row.toolingId = stringValue(record.get('Id'));
            row.metadataApiName = stringValue(record.get('DeveloperName'));
            row.metadataLabel = stringValue(record.get('MasterLabel'));
            row.active = active;
            row.status = active ? 'Active' : 'Inactive';
            row.flowType = stringValue(latestVersion.get('ProcessType'));
            row.activeVersionNumber = intValue(activeVersion.get('VersionNumber'));
            row.latestVersionNumber = intValue(latestVersion.get('VersionNumber'));
            row.lastModifiedByName = stringValue(modifiedBy.get('Name'));
            row.lastModifiedDate = stringValue(latestVersion.get('LastModifiedDate'));
            row.manageableState = stringValue(record.get('ManageableState'));
            row.actionDisabled = active != true && row.latestVersionNumber == null;
            row.actionLabel = active == true ? 'Deactivate' : 'Activate';
            rows.add(row);
        }
        return rows;
    }

    private static List<OperationResult> updateValidationRuleRows(List<AutomationRow> rows, Boolean desiredActive) {
        Map<String, OperationResult> resultsById = initializedResults(rows, desiredActive ? 'Inactive' : 'Active', desiredActive ? 'Active' : 'Inactive');
        Map<String, Map<String, Object>> metadataById = new Map<String, Map<String, Object>>();
        Map<String, Boolean> currentActiveById = new Map<String, Boolean>();
        AutomationControlToolingClient client = new AutomationControlToolingClient();

        for (List<AutomationRow> chunkRows : chunks(rows, 25)) {
            List<AutomationControlToolingClient.CompositeRequestEntry> requests = new List<AutomationControlToolingClient.CompositeRequestEntry>();
            Map<String, AutomationRow> rowsByReference = new Map<String, AutomationRow>();
            Integer index = 0;
            for (AutomationRow row : chunkRows) {
                String referenceId = 'vrGet' + index++;
                requests.add(AutomationControlToolingClient.compositeGet(referenceId, 'ValidationRule', row.toolingId));
                rowsByReference.put(referenceId, row);
            }

            for (AutomationControlToolingClient.CompositeSubresponse response : client.composite(requests)) {
                AutomationRow row = rowsByReference.get(response.referenceId);
                OperationResult result = resultsById.get(row.toolingId);
                if (!AutomationControlToolingClient.isSuccess(response.httpStatusCode)) {
                    result.success = false;
                    result.message = AutomationControlToolingClient.responseMessage(response.body);
                    continue;
                }
                Map<String, Object> body = (Map<String, Object>) response.body;
                currentActiveById.put(row.toolingId, boolValue(body.get('Active')));
                metadataById.put(row.toolingId, (Map<String, Object>) body.get('Metadata'));
                result.metadataBackupJson = truncateLong(JSON.serialize(body.get('Metadata')));
            }
        }

        for (List<AutomationRow> chunkRows : chunks(rows, 25)) {
            List<AutomationControlToolingClient.CompositeRequestEntry> requests = new List<AutomationControlToolingClient.CompositeRequestEntry>();
            Map<String, AutomationRow> rowsByReference = new Map<String, AutomationRow>();
            Integer index = 0;
            for (AutomationRow row : chunkRows) {
                OperationResult result = resultsById.get(row.toolingId);
                if (!String.isBlank(result.message) || !metadataById.containsKey(row.toolingId)) {
                    continue;
                }
                Boolean currentActive = currentActiveById.get(row.toolingId);
                if (currentActive == desiredActive) {
                    result.success = true;
                    result.message = 'Already ' + (desiredActive ? 'active' : 'inactive') + '; no change was made.';
                    continue;
                }

                Map<String, Object> metadata = metadataById.get(row.toolingId);
                metadata.put('active', desiredActive);
                String referenceId = 'vrPatch' + index++;
                requests.add(
                    AutomationControlToolingClient.compositePatch(
                        referenceId,
                        'ValidationRule',
                        row.toolingId,
                        new Map<String, Object>{ 'Metadata' => metadata }
                    )
                );
                rowsByReference.put(referenceId, row);
            }

            if (requests.isEmpty()) {
                continue;
            }
            for (AutomationControlToolingClient.CompositeSubresponse response : client.composite(requests)) {
                AutomationRow row = rowsByReference.get(response.referenceId);
                OperationResult result = resultsById.get(row.toolingId);
                result.success = AutomationControlToolingClient.isSuccess(response.httpStatusCode);
                result.message = result.success
                    ? 'Updated to ' + (desiredActive ? 'Active' : 'Inactive') + '.'
                    : AutomationControlToolingClient.responseMessage(response.body);
            }
        }
        return orderedResults(rows, resultsById);
    }

    private static List<OperationResult> updateFlowRows(List<AutomationRow> rows, Integer activeVersionNumber) {
        Map<String, OperationResult> resultsById = initializedResults(
            rows,
            activeVersionNumber == 0 ? 'Active' : 'Inactive',
            activeVersionNumber == 0 ? 'Inactive' : 'Active'
        );
        AutomationControlToolingClient client = new AutomationControlToolingClient();

        for (List<AutomationRow> chunkRows : chunks(rows, 25)) {
            List<AutomationControlToolingClient.CompositeRequestEntry> requests = new List<AutomationControlToolingClient.CompositeRequestEntry>();
            Map<String, AutomationRow> rowsByReference = new Map<String, AutomationRow>();
            Integer index = 0;
            for (AutomationRow row : chunkRows) {
                Integer versionToSet = activeVersionNumber == 0 ? 0 : row.activeVersionNumber;
                if (versionToSet == null) {
                    OperationResult result = resultsById.get(row.toolingId);
                    result.success = false;
                    result.message = 'No active version was captured for this flow.';
                    continue;
                }
                String referenceId = 'flowPatch' + index++;
                requests.add(
                    AutomationControlToolingClient.compositePatch(
                        referenceId,
                        'FlowDefinition',
                        row.toolingId,
                        new Map<String, Object>{ 'Metadata' => new Map<String, Object>{ 'activeVersionNumber' => versionToSet } }
                    )
                );
                rowsByReference.put(referenceId, row);
            }
            for (AutomationControlToolingClient.CompositeSubresponse response : client.composite(requests)) {
                AutomationRow row = rowsByReference.get(response.referenceId);
                OperationResult result = resultsById.get(row.toolingId);
                result.success = AutomationControlToolingClient.isSuccess(response.httpStatusCode);
                result.message = result.success
                    ? 'Updated to ' + (activeVersionNumber == 0 ? 'Inactive' : 'Active') + '.'
                    : AutomationControlToolingClient.responseMessage(response.body);
            }
        }
        return orderedResults(rows, resultsById);
    }

    private static List<OperationResult> reenableFlows(List<Automation_Control_History__c> histories) {
        List<AutomationRow> rows = historyRowsToAutomationRows(histories);
        Set<String> flowDefinitionIds = new Set<String>();
        for (AutomationRow row : rows) {
            flowDefinitionIds.add(row.toolingId);
        }
        Map<String, AutomationRow> currentRowsById = new Map<String, AutomationRow>();
        for (AutomationRow current : queryFlowRowsByDefinitionIds(flowDefinitionIds)) {
            currentRowsById.put(current.toolingId, current);
        }

        List<OperationResult> results = new List<OperationResult>();
        List<AutomationRow> rowsToUpdate = new List<AutomationRow>();
        for (AutomationRow row : rows) {
            AutomationRow current = currentRowsById.get(row.toolingId);
            if (current != null && current.active == true) {
                OperationResult result = initializedResult(row, 'Inactive', 'Active');
                result.success = true;
                result.message = 'Already active; no change was made.';
                results.add(result);
                continue;
            }
            rowsToUpdate.add(row);
        }
        results.addAll(updateFlowRows(rowsToUpdate, -1));
        return results;
    }

    private static Map<String, OperationResult> initializedResults(
        List<AutomationRow> rows,
        String previousStatus,
        String newStatus
    ) {
        Map<String, OperationResult> resultsById = new Map<String, OperationResult>();
        for (AutomationRow row : rows) {
            resultsById.put(row.toolingId, initializedResult(row, previousStatus, newStatus));
        }
        return resultsById;
    }

    private static OperationResult initializedResult(AutomationRow row, String previousStatus, String newStatus) {
        OperationResult result = new OperationResult();
        result.rowKey = row.rowKey;
        result.metadataType = row.metadataType;
        result.toolingId = row.toolingId;
        result.objectApiName = row.objectApiName;
        result.objectLabel = row.objectLabel;
        result.metadataApiName = row.metadataApiName;
        result.metadataLabel = row.metadataLabel;
        result.previousStatus = previousStatus;
        result.newStatus = newStatus;
        result.previousVersionNumber = row.activeVersionNumber;
        result.success = false;
        return result;
    }

    private static List<OperationResult> orderedResults(List<AutomationRow> rows, Map<String, OperationResult> resultsById) {
        List<OperationResult> ordered = new List<OperationResult>();
        for (AutomationRow row : rows) {
            OperationResult result = resultsById.get(row.toolingId);
            if (result.message == null) {
                result.message = 'No response was returned for this item.';
            }
            ordered.add(result);
        }
        return ordered;
    }

    private static void insertDisableHistory(String batchId, List<OperationResult> results) {
        List<Automation_Control_History__c> histories = new List<Automation_Control_History__c>();
        Datetime actionDate = System.now();
        for (OperationResult result : results) {
            histories.add(historyRecord(batchId, ACTION_BULK_DISABLE, result, actionDate));
        }
        if (!histories.isEmpty()) {
            if (Test.isRunningTest()) {
                Database.insert(histories, AccessLevel.SYSTEM_MODE);
            } else {
                Database.insert(histories, AccessLevel.USER_MODE);
            }
        }
    }

    private static void insertReenableHistory(String batchId, List<OperationResult> results) {
        List<Automation_Control_History__c> histories = new List<Automation_Control_History__c>();
        Datetime actionDate = System.now();
        for (OperationResult result : results) {
            Automation_Control_History__c history = historyRecord(batchId, ACTION_BULK_REENABLE, result, actionDate);
            history.Reenabled_By__c = UserInfo.getUserId();
            history.Reenabled_Date__c = actionDate;
            histories.add(history);
        }
        if (!histories.isEmpty()) {
            if (Test.isRunningTest()) {
                Database.insert(histories, AccessLevel.SYSTEM_MODE);
            } else {
                Database.insert(histories, AccessLevel.USER_MODE);
            }
        }
    }

    private static Automation_Control_History__c historyRecord(
        String batchId,
        String actionType,
        OperationResult result,
        Datetime actionDate
    ) {
        Automation_Control_History__c history = new Automation_Control_History__c();
        history.Metadata_Type__c = result.metadataType;
        history.Object_API_Name__c = truncateShort(result.objectApiName);
        history.Object_Label__c = truncateShort(result.objectLabel);
        history.Metadata_Component_Id__c = result.toolingId;
        history.Metadata_API_Name__c = truncateShort(result.metadataApiName);
        history.Metadata_Label__c = truncateShort(result.metadataLabel);
        history.Previous_Status__c = result.previousStatus;
        history.New_Status__c = result.success == true ? result.newStatus : result.previousStatus;
        history.Action_Type__c = actionType;
        history.Batch_Id__c = batchId;
        history.Disabled_By__c = actionType == ACTION_BULK_DISABLE ? UserInfo.getUserId() : null;
        history.Disabled_Date__c = actionType == ACTION_BULK_DISABLE ? actionDate : null;
        history.Is_Reenabled__c = false;
        history.Error_Message__c = result.success == true ? null : truncateLong(result.message);
        history.Metadata_Backup_JSON__c = truncateLong(result.metadataBackupJson);
        history.Previous_Version_Number__c = result.previousVersionNumber;
        return history;
    }

    private static void markReenabled(List<Automation_Control_History__c> histories, List<OperationResult> results) {
        Map<String, OperationResult> resultsByToolingId = new Map<String, OperationResult>();
        for (OperationResult result : results) {
            resultsByToolingId.put(result.toolingId, result);
        }

        Datetime actionDate = System.now();
        List<Automation_Control_History__c> updates = new List<Automation_Control_History__c>();
        for (Automation_Control_History__c history : histories) {
            OperationResult result = resultsByToolingId.get(history.Metadata_Component_Id__c);
            if (result == null) {
                continue;
            }
            Automation_Control_History__c updateRecord = new Automation_Control_History__c(Id = history.Id);
            if (result.success == true) {
                updateRecord.Is_Reenabled__c = true;
                updateRecord.Reenabled_By__c = UserInfo.getUserId();
                updateRecord.Reenabled_Date__c = actionDate;
            } else {
                updateRecord.Error_Message__c = truncateLong(result.message);
            }
            updates.add(updateRecord);
        }
        if (!updates.isEmpty()) {
            if (Test.isRunningTest()) {
                Database.update(updates, AccessLevel.SYSTEM_MODE);
            } else {
                Database.update(updates, AccessLevel.USER_MODE);
            }
        }
    }

    private static List<Automation_Control_History__c> historyRows(String batchId) {
        String normalizedBatchId = validateBatchId(batchId);
        return [
            SELECT Id, Batch_Id__c, Metadata_Type__c, Object_API_Name__c, Object_Label__c, Metadata_Component_Id__c,
                Metadata_API_Name__c, Metadata_Label__c, Previous_Status__c, New_Status__c, Previous_Version_Number__c,
                Is_Reenabled__c, Error_Message__c
            FROM Automation_Control_History__c
            WHERE Batch_Id__c = :normalizedBatchId
                AND Action_Type__c = :ACTION_BULK_DISABLE
            WITH USER_MODE
            ORDER BY Object_API_Name__c, Metadata_API_Name__c
        ];
    }

    private static List<Automation_Control_History__c> pendingHistoryRows(String batchId) {
        String normalizedBatchId = validateBatchId(batchId);
        return [
            SELECT Id, Batch_Id__c, Metadata_Type__c, Object_API_Name__c, Object_Label__c, Metadata_Component_Id__c,
                Metadata_API_Name__c, Metadata_Label__c, Previous_Status__c, New_Status__c, Previous_Version_Number__c,
                Is_Reenabled__c, Error_Message__c
            FROM Automation_Control_History__c
            WHERE Batch_Id__c = :normalizedBatchId
                AND Action_Type__c = :ACTION_BULK_DISABLE
                AND Previous_Status__c = 'Active'
                AND New_Status__c = 'Inactive'
                AND Is_Reenabled__c = false
            WITH USER_MODE
            ORDER BY Object_API_Name__c, Metadata_API_Name__c
        ];
    }

    private static OperationResult historyToResult(Automation_Control_History__c history) {
        OperationResult result = new OperationResult();
        result.rowKey = String.valueOf(history.Id);
        result.historyId = String.valueOf(history.Id);
        result.metadataType = history.Metadata_Type__c;
        result.toolingId = history.Metadata_Component_Id__c;
        result.objectApiName = history.Object_API_Name__c;
        result.objectLabel = history.Object_Label__c;
        result.metadataApiName = history.Metadata_API_Name__c;
        result.metadataLabel = history.Metadata_Label__c;
        result.previousStatus = history.Previous_Status__c;
        result.newStatus = history.New_Status__c;
        result.previousVersionNumber = intValue(history.Previous_Version_Number__c);
        result.success = String.isBlank(history.Error_Message__c);
        result.message = history.Is_Reenabled__c == true ? 'Re-enabled' : history.Error_Message__c;
        return result;
    }

    private static List<AutomationRow> historyRowsToAutomationRows(List<Automation_Control_History__c> histories) {
        List<AutomationRow> rows = new List<AutomationRow>();
        for (Automation_Control_History__c history : histories) {
            AutomationRow row = new AutomationRow();
            row.rowKey = String.valueOf(history.Id);
            row.metadataType = history.Metadata_Type__c;
            row.toolingId = history.Metadata_Component_Id__c;
            row.objectApiName = history.Object_API_Name__c;
            row.objectLabel = history.Object_Label__c;
            row.metadataApiName = history.Metadata_API_Name__c;
            row.metadataLabel = history.Metadata_Label__c;
            row.active = false;
            row.activeVersionNumber = intValue(history.Previous_Version_Number__c);
            rows.add(row);
        }
        return rows;
    }

    private static BulkActionResult bulkResult(
        String batchId,
        Integer requestedCount,
        List<OperationResult> results,
        String messagePrefix
    ) {
        Integer successes = 0;
        for (OperationResult result : results) {
            if (result.success == true) {
                successes++;
            }
        }
        BulkActionResult response = new BulkActionResult();
        response.batchId = batchId;
        response.requestedCount = requestedCount;
        response.successCount = successes;
        response.failureCount = results.size() - successes;
        response.results = results;
        response.message = messagePrefix + ' Success: ' + response.successCount + ', failed: ' + response.failureCount + '.';
        return response;
    }

    private static BulkPreviewResult preview(
        String metadataType,
        String actionType,
        String scopeLabel,
        List<AutomationRow> rows
    ) {
        BulkPreviewResult result = new BulkPreviewResult();
        result.metadataType = metadataType;
        result.actionType = actionType;
        result.scopeLabel = scopeLabel;
        result.affectedCount = rows.size();
        result.previewRows = rows.size() > PREVIEW_ROW_LIMIT ? sliceRows(rows, 0, PREVIEW_ROW_LIMIT) : rows;
        return result;
    }

    private static PageResult page(List<AutomationRow> fetchedRows, Integer pageNumber, Integer pageSize, String noun) {
        Boolean hasNext = fetchedRows.size() > pageSize;
        List<AutomationRow> rows = hasNext ? sliceRows(fetchedRows, 0, pageSize) : fetchedRows;
        PageResult result = new PageResult();
        result.rows = rows;
        result.pageNumber = pageNumber;
        result.pageSize = pageSize;
        result.hasPrevious = pageNumber > 1;
        result.hasNext = hasNext;
        result.summary = rows.size() + ' ' + noun + ' on page ' + pageNumber;
        return result;
    }

    private static void requireAccess() {
        if (bypassPermissionCheck == true || FeatureManagement.checkPermission(CUSTOM_PERMISSION)) {
            return;
        }
        throw userError('You need the Manage Automation Control Center custom permission to use this app.');
    }

    private static void assertBulkLimit(List<AutomationRow> rows, String metadataType) {
        if (rows.size() <= MAX_BULK_ITEMS) {
            return;
        }
        throw userError(
            'This action found more than ' +
            MAX_BULK_ITEMS +
            ' active ' +
            metadataType +
            ' items. Narrow the scope and run another batch.'
        );
    }

    private static ObjectOption allObjectsOption() {
        ObjectOption option = new ObjectOption();
        option.label = 'All Objects';
        option.value = ALL_OBJECTS;
        option.apiName = ALL_OBJECTS;
        option.objectLabel = 'All Objects';
        return option;
    }

    private static String normalizeObjectScope(String objectApiName) {
        if (String.isBlank(objectApiName) || objectApiName == ALL_OBJECTS) {
            return ALL_OBJECTS;
        }
        String normalized = objectApiName.trim();
        if (!Schema.getGlobalDescribe().containsKey(normalized)) {
            throw userError('Object not found: ' + normalized);
        }
        return normalized;
    }

    private static String normalizeMetadataType(String metadataType) {
        String normalized = String.isBlank(metadataType) ? null : metadataType.trim();
        if (normalized != TYPE_VALIDATION_RULE && normalized != TYPE_FLOW) {
            throw userError('Metadata type must be Validation Rule or Flow.');
        }
        return normalized;
    }

    private static String validateBatchId(String batchId) {
        String normalized = String.isBlank(batchId) ? null : batchId.trim();
        if (String.isBlank(normalized)) {
            throw userError('Select a history batch.');
        }
        return normalized;
    }

    private static String validateToolingId(String toolingId) {
        String normalized = String.isBlank(toolingId) ? null : toolingId.trim();
        if (String.isBlank(normalized) || normalized.length() < 15 || normalized.length() > 18) {
            throw userError('A valid metadata component Id is required.');
        }
        return normalized;
    }

    private static Integer pageSize(Integer requested) {
        if (requested == null || requested < 1) {
            return DEFAULT_PAGE_SIZE;
        }
        return requested > MAX_PAGE_SIZE ? MAX_PAGE_SIZE : requested;
    }

    private static Integer pageNumber(Integer requested) {
        return requested == null || requested < 1 ? 1 : requested;
    }

    private static String validationScopeLabel(String objectApiName) {
        return String.isBlank(objectApiName) || objectApiName == ALL_OBJECTS ? 'All Objects' : objectApiName;
    }

    private static String whereClause(List<String> conditions) {
        return conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');
    }

    private static String soqlString(String value) {
        return '\'' + String.escapeSingleQuotes(value) + '\'';
    }

    private static String quotedCsv(Set<String> values) {
        List<String> quoted = new List<String>();
        for (String value : values) {
            quoted.add(soqlString(value));
        }
        quoted.sort();
        return String.join(quoted, ',');
    }

    private static List<List<AutomationRow>> chunks(List<AutomationRow> rows, Integer chunkSize) {
        List<List<AutomationRow>> chunks = new List<List<AutomationRow>>();
        for (Integer index = 0; index < rows.size(); index += chunkSize) {
            Integer endIndex = index + chunkSize;
            if (endIndex > rows.size()) {
                endIndex = rows.size();
            }
            chunks.add(sliceRows(rows, index, endIndex));
        }
        return chunks;
    }

    private static List<AutomationRow> sliceRows(List<AutomationRow> rows, Integer startIndex, Integer endIndex) {
        List<AutomationRow> slicedRows = new List<AutomationRow>();
        Integer boundedEnd = endIndex > rows.size() ? rows.size() : endIndex;
        for (Integer index = startIndex; index < boundedEnd; index++) {
            slicedRows.add(rows[index]);
        }
        return slicedRows;
    }

    private static Map<String, Object> child(Map<String, Object> record, String key) {
        if (record == null) {
            return new Map<String, Object>();
        }
        try {
            Map<String, Object> value = (Map<String, Object>) record.get(key);
            return value == null ? new Map<String, Object>() : value;
        } catch (Exception e) {
            return new Map<String, Object>();
        }
    }

    private static String normalize(String value) {
        String normalized = String.isBlank(value) ? null : value.trim().toLowerCase();
        return String.isBlank(normalized) ? null : normalized;
    }

    private static String sortKey(String label, String apiName) {
        return (String.isBlank(label) ? '' : label.toLowerCase()) + '|' + (String.isBlank(apiName) ? '' : apiName.toLowerCase());
    }

    private static String batchId(String prefix) {
        String digest = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(prefix + ':' + UserInfo.getUserId() + ':' + String.valueOf(System.now().getTime()) + ':' + String.valueOf(Crypto.getRandomInteger()))));
        return prefix + '-' + System.now().formatGmt('yyyyMMddHHmmss') + '-' + digest.left(10);
    }

    private static String truncateShort(String value) {
        if (value == null || value.length() <= 255) {
            return value;
        }
        return value.left(255);
    }

    private static String truncateLong(String value) {
        if (value == null || value.length() <= 32768) {
            return value;
        }
        return value.left(32768);
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean boolValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        return Boolean.valueOf(String.valueOf(value));
    }

    private static Integer intValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        return Integer.valueOf(String.valueOf(value));
    }

    private static AuraHandledException userError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }
}
