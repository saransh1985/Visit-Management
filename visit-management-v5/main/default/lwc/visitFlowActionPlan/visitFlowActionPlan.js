import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getActionPlanStartInfo from '@salesforce/apex/VisitWizardController.getActionPlanStartInfo';

export default class VisitFlowActionPlan extends LightningElement {
    @api visitId;

    isLoading = false;
    errorMessage = '';
    statusOptions = [];
    recentTemplateOptions = [];
    _actionPlanName = '';
    _actionPlanStartDate = '';
    _actionPlanTemplateVersionId = '';
    _actionPlanTargetRecordId = '';
    _actionPlanStatus = '';

    @api
    get actionPlanName() {
        return this._actionPlanName;
    }

    set actionPlanName(value) {
        this._actionPlanName = value || '';
    }

    @api
    get actionPlanStartDate() {
        return this._actionPlanStartDate;
    }

    set actionPlanStartDate(value) {
        this._actionPlanStartDate = value || '';
    }

    @api
    get actionPlanTemplateVersionId() {
        return this._actionPlanTemplateVersionId;
    }

    set actionPlanTemplateVersionId(value) {
        this._actionPlanTemplateVersionId = value || '';
    }

    @api
    get actionPlanTargetRecordId() {
        return this._actionPlanTargetRecordId;
    }

    set actionPlanTargetRecordId(value) {
        this._actionPlanTargetRecordId = value || '';
    }

    @api
    get actionPlanStatus() {
        return this._actionPlanStatus;
    }

    set actionPlanStatus(value) {
        this._actionPlanStatus = value || '';
    }

    templateFilter = {
        criteria: [
            {
                fieldPath: 'Status',
                operator: 'eq',
                value: 'Final'
            },
            {
                fieldPath: 'ActionPlanTemplate.Status',
                operator: 'eq',
                value: 'Final'
            },
            {
                fieldPath: 'ActionPlanTemplate.TargetEntityType',
                operator: 'eq',
                value: 'Visit'
            }
        ],
        filterLogic: '1 AND 2 AND 3'
    };
    templateDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['ActionPlanTemplate.Name']
    };
    templateMatchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: 'ActionPlanTemplate.Name' }]
    };

    connectedCallback() {
        this._actionPlanTargetRecordId = this.actionPlanTargetRecordId || this.visitId;
        this._actionPlanStartDate = this.actionPlanStartDate || this.todayValue();
        this.emitValue('actionPlanTargetRecordId', this.actionPlanTargetRecordId);
        this.emitValue('actionPlanStartDate', this.actionPlanStartDate);
        this.loadStartInfo();
    }

    get targetRecordDisplay() {
        return this.actionPlanTargetRecordId || this.visitId;
    }

    get hasRecentTemplates() {
        return this.recentTemplates.length > 0;
    }

    get recentTemplates() {
        return this.recentTemplateOptions.map((template) => ({
            ...template,
            buttonClass:
                template.templateVersionId === this.actionPlanTemplateVersionId
                    ? 'recent-template selected'
                    : 'recent-template'
        }));
    }

    async loadStartInfo() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const startInfo = await getActionPlanStartInfo({ visitId: this.visitId });
            this.statusOptions = startInfo?.statusOptions || [];
            this.recentTemplateOptions = startInfo?.recentTemplates || [];
            this._actionPlanTargetRecordId = startInfo?.targetRecordId || this.actionPlanTargetRecordId || this.visitId;
            this._actionPlanStatus =
                this.actionPlanStatus ||
                startInfo?.defaultStatus ||
                this.statusOptions[0]?.value ||
                '';
            this.emitValue('actionPlanTargetRecordId', this.actionPlanTargetRecordId);
            this.emitValue('actionPlanStatus', this.actionPlanStatus);
        } catch (error) {
            this.errorMessage = this.errorText(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleInputChange(event) {
        this.emitValue(event.target.dataset.field, event.target.value);
    }

    handleTemplateChange(event) {
        const value = event.detail?.recordId || event.detail?.value || event.target.value;
        this.emitValue('actionPlanTemplateVersionId', value);
    }

    handleRecentTemplateSelect(event) {
        this.emitValue('actionPlanTemplateVersionId', event.currentTarget.dataset.id);
    }

    emitValue(name, value) {
        if (!name) {
            return;
        }
        this[`_${name}`] = value || '';
        this.dispatchEvent(new FlowAttributeChangeEvent(name, this[`_${name}`]));
    }

    todayValue() {
        const now = new Date();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        return `${now.getFullYear()}-${month}-${day}`;
    }

    errorText(error) {
        return error?.body?.message || error?.message || 'Something went wrong while loading Action Plan details.';
    }

    @api
    validate() {
        let isValid = true;
        this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-record-picker').forEach((field) => {
            if (typeof field.reportValidity === 'function') {
                isValid = field.reportValidity() && isValid;
            }
        });

        if (!this.actionPlanTemplateVersionId) {
            isValid = false;
        }

        return {
            isValid,
            errorMessage: isValid ? null : 'Complete the required Action Plan fields before finishing.'
        };
    }
}
