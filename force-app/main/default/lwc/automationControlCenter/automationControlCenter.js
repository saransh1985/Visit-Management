import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

import getObjectOptions from '@salesforce/apex/AutomationControlCenterController.getObjectOptions';
import getValidationRules from '@salesforce/apex/AutomationControlCenterController.getValidationRules';
import getFlows from '@salesforce/apex/AutomationControlCenterController.getFlows';
import previewValidationRuleBulkDisable from '@salesforce/apex/AutomationControlCenterController.previewValidationRuleBulkDisable';
import previewFlowBulkDeactivate from '@salesforce/apex/AutomationControlCenterController.previewFlowBulkDeactivate';
import disableValidationRule from '@salesforce/apex/AutomationControlCenterController.disableValidationRule';
import deactivateFlow from '@salesforce/apex/AutomationControlCenterController.deactivateFlow';
import activateFlow from '@salesforce/apex/AutomationControlCenterController.activateFlow';
import bulkDisableValidationRules from '@salesforce/apex/AutomationControlCenterController.bulkDisableValidationRules';
import bulkDeactivateFlows from '@salesforce/apex/AutomationControlCenterController.bulkDeactivateFlows';
import getHistoryBatches from '@salesforce/apex/AutomationControlCenterController.getHistoryBatches';
import getHistoryRows from '@salesforce/apex/AutomationControlCenterController.getHistoryRows';
import reenableFromHistory from '@salesforce/apex/AutomationControlCenterController.reenableFromHistory';

const ALL_OBJECTS = '__ALL_OBJECTS__';
const PAGE_SIZE = 50;
const TYPE_VALIDATION_RULE = 'Validation Rule';
const TYPE_FLOW = 'Flow';
const MODE_VALIDATION_DISABLE = 'validationDisable';
const MODE_FLOW_DEACTIVATE = 'flowDeactivate';
const MODE_REENABLE = 'reenable';

export default class AutomationControlCenter extends LightningElement {
    @track objectOptions = [];
    @track validationRows = [];
    @track flowRows = [];
    @track validationHistoryBatches = [];
    @track flowHistoryBatches = [];
    @track previewRows = [];

    objectSearchTerm = '';
    selectedObjectApiName = ALL_OBJECTS;
    showDisabledValidationRules = false;
    validationPageNumber = 1;
    validationHasPrevious = false;
    validationHasNext = false;
    validationSummary = '';
    selectedValidationBatchId;

    flowSearchTerm = '';
    flowPageNumber = 1;
    flowHasPrevious = false;
    flowHasNext = false;
    flowSummary = '';
    selectedFlowBatchId;

    loadingObjects = false;
    loadingValidation = false;
    loadingFlows = false;
    working = false;
    errorMessage;

    showPreviewModal = false;
    previewMode;
    previewTitle;
    previewCount = 0;
    previewScopeLabel;
    previewBatchId;

    connectedCallback() {
        this.loadInitialData();
    }

    get filteredObjectOptions() {
        const term = this.objectSearchTerm.trim().toLowerCase();
        return this.objectOptions
            .filter((option) => {
                if (!term || option.value === ALL_OBJECTS) {
                    return true;
                }
                return (option.label || '').toLowerCase().includes(term) || (option.apiName || '').toLowerCase().includes(term);
            })
            .slice(0, 200)
            .map((option) => ({
                label: option.label,
                value: option.value
            }));
    }

    get validationHistoryOptions() {
        return this.validationHistoryBatches.map((batch) => ({
            label: batch.label,
            value: batch.batchId
        }));
    }

    get flowHistoryOptions() {
        return this.flowHistoryBatches.map((batch) => ({
            label: batch.label,
            value: batch.batchId
        }));
    }

    get isBusy() {
        return this.loadingObjects || this.loadingValidation || this.loadingFlows || this.working;
    }

    get validationPreviousDisabled() {
        return this.isBusy || !this.validationHasPrevious;
    }

    get validationNextDisabled() {
        return this.isBusy || !this.validationHasNext;
    }

    get flowPreviousDisabled() {
        return this.isBusy || !this.flowHasPrevious;
    }

    get flowNextDisabled() {
        return this.isBusy || !this.flowHasNext;
    }

    get validationBulkDisabled() {
        return this.isBusy || !this.validationRows.some((row) => row.active);
    }

    get flowBulkDisabled() {
        return this.isBusy || !this.flowRows.some((row) => row.active);
    }

    get validationReenableDisabled() {
        return this.isBusy || !this.selectedValidationBatchId;
    }

    get flowReenableDisabled() {
        return this.isBusy || !this.selectedFlowBatchId;
    }

    async loadInitialData() {
        await Promise.all([this.loadObjectOptions(), this.loadValidationRules(1), this.loadFlows(1), this.loadHistoryBatches()]);
    }

    async loadObjectOptions() {
        this.loadingObjects = true;
        this.errorMessage = null;
        try {
            this.objectOptions = await getObjectOptions({ searchTerm: null });
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loadingObjects = false;
        }
    }

    async loadValidationRules(pageNumber = this.validationPageNumber) {
        this.loadingValidation = true;
        this.errorMessage = null;
        try {
            const response = await getValidationRules({
                objectApiName: this.selectedObjectApiName,
                showDisabled: this.showDisabledValidationRules,
                pageSize: PAGE_SIZE,
                pageNumber
            });
            this.validationRows = this.decorateValidationRows(response.rows || []);
            this.validationPageNumber = response.pageNumber;
            this.validationHasPrevious = response.hasPrevious;
            this.validationHasNext = response.hasNext;
            this.validationSummary = response.summary;
        } catch (error) {
            this.validationRows = [];
            this.handleError(error);
        } finally {
            this.loadingValidation = false;
        }
    }

    async loadFlows(pageNumber = this.flowPageNumber) {
        this.loadingFlows = true;
        this.errorMessage = null;
        try {
            const response = await getFlows({
                searchTerm: this.flowSearchTerm,
                pageSize: PAGE_SIZE,
                pageNumber
            });
            this.flowRows = response.rows || [];
            this.flowPageNumber = response.pageNumber;
            this.flowHasPrevious = response.hasPrevious;
            this.flowHasNext = response.hasNext;
            this.flowSummary = response.summary;
        } catch (error) {
            this.flowRows = [];
            this.handleError(error);
        } finally {
            this.loadingFlows = false;
        }
    }

    async loadHistoryBatches() {
        try {
            const [validationBatches, flowBatches] = await Promise.all([
                getHistoryBatches({ metadataType: TYPE_VALIDATION_RULE }),
                getHistoryBatches({ metadataType: TYPE_FLOW })
            ]);
            this.validationHistoryBatches = validationBatches || [];
            this.flowHistoryBatches = flowBatches || [];
        } catch (error) {
            this.handleError(error);
        }
    }

    handleObjectSearchChange(event) {
        this.objectSearchTerm = event.target.value || '';
    }

    handleObjectSearchKeyup(event) {
        if (event.key !== 'Enter') {
            return;
        }
        const firstOption = this.filteredObjectOptions[0];
        if (firstOption) {
            this.selectedObjectApiName = firstOption.value;
            this.loadValidationRules(1);
        }
    }

    handleObjectChange(event) {
        this.selectedObjectApiName = event.detail.value;
        this.loadValidationRules(1);
    }

    handleShowDisabledChange(event) {
        this.showDisabledValidationRules = event.target.checked;
        this.loadValidationRules(1);
    }

    handleFlowSearchChange(event) {
        this.flowSearchTerm = event.target.value || '';
    }

    handleFlowSearchKeyup(event) {
        if (event.key === 'Enter') {
            this.loadFlows(1);
        }
    }

    handleValidationPrevious() {
        this.loadValidationRules(this.validationPageNumber - 1);
    }

    handleValidationNext() {
        this.loadValidationRules(this.validationPageNumber + 1);
    }

    handleValidationRefresh() {
        this.loadValidationRules();
    }

    handleFlowPrevious() {
        this.loadFlows(this.flowPageNumber - 1);
    }

    handleFlowNext() {
        this.loadFlows(this.flowPageNumber + 1);
    }

    handleFlowSearch() {
        this.loadFlows(1);
    }

    handleValidationBatchChange(event) {
        this.selectedValidationBatchId = event.detail.value;
    }

    handleFlowBatchChange(event) {
        this.selectedFlowBatchId = event.detail.value;
    }

    async handleValidationToggle(event) {
        const validationRuleId = event.target.dataset.id;
        if (event.target.checked) {
            return;
        }

        const confirmed = await LightningConfirm.open({
            label: 'Disable Validation Rule',
            message: 'Disable this active validation rule?',
            theme: 'warning'
        });
        if (!confirmed) {
            event.target.checked = true;
            return;
        }

        this.working = true;
        try {
            const result = await disableValidationRule({ validationRuleId });
            this.showToast('Validation Rule Disabled', result.message, 'success');
            await Promise.all([this.loadValidationRules(), this.loadHistoryBatches()]);
        } catch (error) {
            event.target.checked = true;
            this.handleError(error);
        } finally {
            this.working = false;
        }
    }

    async handleFlowToggle(event) {
        const flowDefinitionId = event.target.dataset.id;
        const activate = event.target.checked;

        const confirmed = await LightningConfirm.open({
            label: activate ? 'Activate Flow' : 'Deactivate Flow',
            message: activate ? 'Activate the latest version of this flow?' : 'Deactivate this active flow?',
            theme: 'warning'
        });
        if (!confirmed) {
            event.target.checked = !activate;
            return;
        }

        this.working = true;
        try {
            const result = activate ? await activateFlow({ flowDefinitionId }) : await deactivateFlow({ flowDefinitionId });
            this.showToast(activate ? 'Flow Activated' : 'Flow Deactivated', result.message, 'success');
            await Promise.all([this.loadFlows(), this.loadHistoryBatches()]);
        } catch (error) {
            event.target.checked = !activate;
            this.handleError(error);
        } finally {
            this.working = false;
        }
    }

    async handlePreviewValidationBulkDisable() {
        this.working = true;
        try {
            const preview = await previewValidationRuleBulkDisable({ objectApiName: this.selectedObjectApiName });
            this.openBulkPreview(MODE_VALIDATION_DISABLE, 'Bulk Disable Validation Rules', preview);
        } catch (error) {
            this.handleError(error);
        } finally {
            this.working = false;
        }
    }

    async handlePreviewFlowBulkDeactivate() {
        this.working = true;
        try {
            const preview = await previewFlowBulkDeactivate();
            this.openBulkPreview(MODE_FLOW_DEACTIVATE, 'Bulk Deactivate Flows', preview);
        } catch (error) {
            this.handleError(error);
        } finally {
            this.working = false;
        }
    }

    async handlePreviewValidationReenable() {
        await this.openReenablePreview(this.selectedValidationBatchId, TYPE_VALIDATION_RULE);
    }

    async handlePreviewFlowReenable() {
        await this.openReenablePreview(this.selectedFlowBatchId, TYPE_FLOW);
    }

    async openReenablePreview(batchId, metadataType) {
        if (!batchId) {
            this.showToast('History Batch Required', 'Select a history batch.', 'error');
            return;
        }
        this.working = true;
        try {
            const rows = await getHistoryRows({ batchId });
            this.previewMode = MODE_REENABLE;
            this.previewBatchId = batchId;
            this.previewTitle = metadataType === TYPE_FLOW ? 'Re-enable Flows from History' : 'Re-enable Validation Rules from History';
            this.previewScopeLabel = batchId;
            this.previewRows = this.normalizePreviewRows(rows || []);
            this.previewCount = this.previewRows.filter((row) => row.newStatus === 'Inactive' && !row.message).length || this.previewRows.length;
            this.showPreviewModal = true;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.working = false;
        }
    }

    openBulkPreview(mode, title, preview) {
        this.previewMode = mode;
        this.previewBatchId = null;
        this.previewTitle = title;
        this.previewScopeLabel = preview.scopeLabel;
        this.previewCount = preview.affectedCount;
        this.previewRows = this.normalizePreviewRows(preview.previewRows || []);
        this.showPreviewModal = true;
    }

    closePreviewModal() {
        this.showPreviewModal = false;
        this.previewRows = [];
        this.previewMode = null;
        this.previewBatchId = null;
    }

    async handleConfirmPreview() {
        const confirmed = await LightningConfirm.open({
            label: this.previewTitle,
            message: `Execute this action for ${this.previewCount} item(s)?`,
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }

        this.working = true;
        try {
            let result;
            if (this.previewMode === MODE_VALIDATION_DISABLE) {
                result = await bulkDisableValidationRules({ objectApiName: this.selectedObjectApiName });
                await this.loadValidationRules(1);
            } else if (this.previewMode === MODE_FLOW_DEACTIVATE) {
                result = await bulkDeactivateFlows();
                await this.loadFlows(1);
            } else if (this.previewMode === MODE_REENABLE) {
                result = await reenableFromHistory({ batchId: this.previewBatchId });
                await Promise.all([this.loadValidationRules(1), this.loadFlows(1)]);
            }

            this.showToast('Bulk Action Complete', result.message, result.failureCount ? 'warning' : 'success');
            this.closePreviewModal();
            await this.loadHistoryBatches();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.working = false;
        }
    }

    normalizePreviewRows(rows) {
        return rows.map((row) => ({
            key: row.rowKey || row.historyId || row.toolingId,
            objectApiName: row.objectApiName || '',
            metadataApiName: row.metadataApiName,
            metadataLabel: row.metadataLabel,
            status: row.status || `${row.previousStatus || ''} -> ${row.newStatus || ''}`,
            message: row.message || '',
            newStatus: row.newStatus
        }));
    }

    decorateValidationRows(rows) {
        if (this.selectedObjectApiName !== ALL_OBJECTS) {
            return rows.map((row) => ({ ...row, groupLabel: null, groupKey: null }));
        }

        let previousObjectApiName;
        return rows.map((row) => {
            const startsGroup = row.objectApiName !== previousObjectApiName;
            previousObjectApiName = row.objectApiName;
            return {
                ...row,
                groupLabel: startsGroup ? `${row.objectLabel || row.objectApiName} (${row.objectApiName})` : null,
                groupKey: startsGroup ? `group-${row.objectApiName}` : null
            };
        });
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Something went wrong.';
    }

    handleError(error) {
        this.errorMessage = this.reduceError(error);
        this.showToast('Error', this.errorMessage, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}
