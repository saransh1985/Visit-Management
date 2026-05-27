@SuppressWarnings('PMD.CognitiveComplexity,PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters,PMD.ApexDoc')
public inherited sharing class AutomationControlCenterController {
    @AuraEnabled
    public static List<AutomationControlService.ObjectOption> getObjectOptions(String searchTerm) {
        return AutomationControlService.getObjectOptions(searchTerm);
    }

    @AuraEnabled
    public static AutomationControlService.PageResult getValidationRules(
        String objectApiName,
        Boolean showDisabled,
        Integer pageSize,
        Integer pageNumber
    ) {
        return AutomationControlService.getValidationRules(objectApiName, showDisabled, pageSize, pageNumber);
    }

    @AuraEnabled
    public static AutomationControlService.PageResult getFlows(String searchTerm, Integer pageSize, Integer pageNumber) {
        return AutomationControlService.getFlows(searchTerm, pageSize, pageNumber);
    }

    @AuraEnabled
    public static AutomationControlService.BulkPreviewResult previewValidationRuleBulkDisable(String objectApiName) {
        return AutomationControlService.previewValidationRuleBulkDisable(objectApiName);
    }

    @AuraEnabled
    public static AutomationControlService.BulkPreviewResult previewFlowBulkDeactivate() {
        return AutomationControlService.previewFlowBulkDeactivate();
    }

    @AuraEnabled
    public static AutomationControlService.OperationResult disableValidationRule(String validationRuleId) {
        return AutomationControlService.disableValidationRule(validationRuleId);
    }

    @AuraEnabled
    public static AutomationControlService.OperationResult deactivateFlow(String flowDefinitionId) {
        return AutomationControlService.deactivateFlow(flowDefinitionId);
    }

    @AuraEnabled
    public static AutomationControlService.OperationResult activateFlow(String flowDefinitionId) {
        return AutomationControlService.activateFlow(flowDefinitionId);
    }

    @AuraEnabled
    public static AutomationControlService.BulkActionResult bulkDisableValidationRules(String objectApiName) {
        return AutomationControlService.bulkDisableValidationRules(objectApiName);
    }

    @AuraEnabled
    public static AutomationControlService.BulkActionResult bulkDeactivateFlows() {
        return AutomationControlService.bulkDeactivateFlows();
    }

    @AuraEnabled
    public static List<AutomationControlService.HistoryBatch> getHistoryBatches(String metadataType) {
        return AutomationControlService.getHistoryBatches(metadataType);
    }

    @AuraEnabled
    public static List<AutomationControlService.OperationResult> getHistoryRows(String batchId) {
        return AutomationControlService.getHistoryRows(batchId);
    }

    @AuraEnabled
    public static AutomationControlService.BulkActionResult reenableFromHistory(String batchId) {
        return AutomationControlService.reenableFromHistory(batchId);
    }
}
