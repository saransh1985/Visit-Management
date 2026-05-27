import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getVisitRecordTypes from '@salesforce/apex/VisitWizardController.getVisitRecordTypesV4';
import getVisitFieldMetadata from '@salesforce/apex/VisitWizardController.getVisitFieldMetadata';
import getAccountInfo from '@salesforce/apex/VisitWizardController.getAccountInfo';
import getInitialVisitorCandidates from '@salesforce/apex/VisitWizardController.getInitialVisitorCandidates';
import searchUsers from '@salesforce/apex/VisitWizardController.searchUsers';
import searchContacts from '@salesforce/apex/VisitWizardController.searchContacts';
import saveVisitV3 from '@salesforce/apex/VisitWizardController.saveVisitV3';
import getActionPlanStartInfo from '@salesforce/apex/VisitWizardController.getActionPlanStartInfo';
import saveActionPlan from '@salesforce/apex/VisitWizardController.saveActionPlan';

const STEP_RECORD_TYPE = 1;
const STEP_VISIT_DETAIL = 2;
const STEP_VISITORS = 3;
const STEP_VISITED_PARTIES = 4;
const STEP_ACTION_PLAN = 5;
const ROW_ACTION_ADD = 'add';
const ROW_ACTION_REMOVE = 'remove';
const ROW_ACTION_SELECT_TEMPLATE = 'select_template';
const ACCOUNT_CAN_FIELD = 'Customer_Account_Number_CAN__c';

export default class VisitWizard extends NavigationMixin(LightningElement) {
    @track recordTypes = [];
    @track visitFields = [];
    @track visitorCandidates = [];
    @track selectedVisitors = [];
    @track selectedContacts = [];
    @track userSearchResults = [];
    @track contactSearchResults = [];
    @track recentActionPlanTemplates = [];
    @track actionPlanStatusOptions = [];

    step = STEP_RECORD_TYPE;
    selectedRecordTypeId;
    visitFormValues = {};
    createdVisitId;
    actionPlanName = '';
    actionPlanStartDate;
    actionPlanTemplateVersionId;
    actionPlanStatus;
    actionPlanTargetRecordId;
    actionPlanTemplatePickerFilter = {
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
    actionPlanTemplateDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['ActionPlanTemplate.Name']
    };
    actionPlanTemplateMatchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: 'ActionPlanTemplate.Name' }]
    };
    accountPickerDisplayInfo = {
        primaryField: 'Name',
        additionalFields: [ACCOUNT_CAN_FIELD]
    };
    accountPickerMatchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: ACCOUNT_CAN_FIELD }]
    };
    visitorCandidateColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Title', fieldName: 'title' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Source', fieldName: 'source' }
    ];
    selectedVisitorColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Title', fieldName: 'title' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Source', fieldName: 'source' },
        {
            type: 'button-icon',
            fixedWidth: 56,
            typeAttributes: {
                iconName: 'utility:delete',
                name: ROW_ACTION_REMOVE,
                title: 'Remove',
                alternativeText: 'Remove',
                disabled: { fieldName: 'locked' }
            }
        }
    ];
    userSearchColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Title', fieldName: 'title' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        {
            type: 'button-icon',
            fixedWidth: 56,
            typeAttributes: {
                iconName: 'utility:add',
                name: ROW_ACTION_ADD,
                title: 'Add',
                alternativeText: 'Add'
            }
        }
    ];
    selectedContactColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Title', fieldName: 'title' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Phone', fieldName: 'phone', type: 'phone' },
        {
            type: 'button-icon',
            fixedWidth: 56,
            typeAttributes: {
                iconName: 'utility:delete',
                name: ROW_ACTION_REMOVE,
                title: 'Remove',
                alternativeText: 'Remove'
            }
        }
    ];
    contactSearchColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Title', fieldName: 'title' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Phone', fieldName: 'phone', type: 'phone' },
        {
            type: 'button-icon',
            fixedWidth: 56,
            typeAttributes: {
                iconName: 'utility:add',
                name: ROW_ACTION_ADD,
                title: 'Add',
                alternativeText: 'Add'
            }
        }
    ];
    recentActionPlanTemplateColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Type', fieldName: 'actionPlanType' },
        { label: 'Version', fieldName: 'versionNumber', type: 'number' },
        {
            label: 'Last Modified',
            fieldName: 'lastModifiedDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        },
        {
            type: 'button',
            fixedWidth: 96,
            typeAttributes: {
                label: 'Select',
                name: ROW_ACTION_SELECT_TEMPLATE,
                variant: 'base'
            }
        }
    ];
    visitFieldMetadataByRecordType = {};
    loading = false;
    visitDetailLoading = false;
    visitDetailLoadedRecordTypeId;
    errorMessage;
    showUserModal = false;
    showContactModal = false;
    userSearchTerm = '';
    contactSearchTerm = '';
    initialized = false;
    accountId;
    accountName;
    customerAccountNumber;
    sourceAccountLocked = false;
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        this.setAccountId(value, { lockAccount: true });
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageReference) {
        const pageRecordId =
            pageReference?.state?.recordId ||
            pageReference?.state?.c__recordId ||
            pageReference?.attributes?.recordId ||
            this.extractAccountIdFromPageReference(pageReference);
        this.setAccountId(pageRecordId, { lockAccount: true });
    }

    connectedCallback() {
        this.setAccountId(this.extractAccountIdFromUrl(), { lockAccount: true });
        this.initialize();
    }

    get panelHeader() {
        return this.isActionPlanStep ? 'New Action Plan' : 'New Visit';
    }

    get isBusy() {
        return this.loading || this.visitDetailLoading;
    }

    get loadingText() {
        return this.visitDetailLoading ? 'Loading Visit details' : 'Loading';
    }

    get isRecordTypeStep() {
        return this.step === STEP_RECORD_TYPE;
    }

    get isVisitDetailStep() {
        return this.step === STEP_VISIT_DETAIL;
    }

    get isVisitorStep() {
        return this.step === STEP_VISITORS;
    }

    get isVisitedPartyStep() {
        return this.step === STEP_VISITED_PARTIES;
    }

    get isActionPlanStep() {
        return this.step === STEP_ACTION_PLAN;
    }

    get showPrevious() {
        return this.step > STEP_RECORD_TYPE && !this.isActionPlanStep;
    }

    get visitDetailSectionClass() {
        return this.isVisitDetailStep ? '' : 'slds-hide';
    }

    get visitFormClass() {
        return this.visitDetailLoading ? 'visit-form visit-form_loading' : 'visit-form';
    }

    get stepbarClass() {
        return this.isActionPlanStep ? 'stepbar action-plan-stepbar slds-m-bottom_medium' : 'stepbar slds-m-bottom_medium';
    }

    get recordTypeOptions() {
        return this.recordTypes.map((recordType) => ({
            label: recordType.defaultRecordTypeMapping ? `${recordType.label} (Default)` : recordType.label,
            value: recordType.value
        }));
    }

    get hasRecentActionPlanTemplates() {
        return this.recentActionPlanTemplates.length > 0;
    }

    get accountDisplayValue() {
        return this.accountName || this.accountId;
    }

    get showCustomerAccountNumber() {
        return this.selectedRecordTypeIsFleet;
    }

    get selectedRecordTypeIsFleet() {
        const recordType = this.recordTypes.find((type) => type.value === this.selectedRecordTypeId);
        const label = (recordType?.label || '').toLowerCase();
        const developerName = (recordType?.developerName || '').toLowerCase();
        return label.includes('fleet') || developerName.includes('fleet');
    }

    get hasSelectedVisitors() {
        return this.selectedVisitors.length > 0;
    }

    get hasSelectedContacts() {
        return this.selectedContacts.length > 0;
    }

    get hasUserSearchResults() {
        return this.userSearchResults.length > 0;
    }

    get hasContactSearchResults() {
        return this.contactSearchResults.length > 0;
    }

    get selectedVisitorIds() {
        return this.selectedVisitors.map((visitor) => visitor.userId);
    }

    get lockedVisitorIds() {
        return this.visitorCandidates.filter((visitor) => visitor.locked).map((visitor) => visitor.userId);
    }

    get selectedContactIds() {
        return this.dedupeIds([
            ...this.selectedContacts.map((contact) => this.normalizeContactIdValue(contact.contactId || contact.Id || contact.id)),
            ...this.getRenderedContactIds()
        ]);
    }

    get steps() {
        if (this.isActionPlanStep) {
            return [
                {
                    value: 1,
                    label: 'Action Plan',
                    className: 'step active'
                }
            ];
        }

        return [
            { value: STEP_RECORD_TYPE, label: 'Record Type' },
            { value: STEP_VISIT_DETAIL, label: 'Details' },
            { value: STEP_VISITORS, label: 'Visitors' },
            { value: STEP_VISITED_PARTIES, label: 'Visited Parties' }
        ].map((stepItem) => ({
            ...stepItem,
            className: stepItem.value === this.step ? 'step active' : stepItem.value < this.step ? 'step complete' : 'step'
        }));
    }

    async initialize() {
        if (this.initialized) {
            return;
        }

        this.initialized = true;
        this.loading = true;
        this.errorMessage = null;

        try {
            const recordTypes = await getVisitRecordTypes();
            this.recordTypes = recordTypes;
            if (this.accountId) {
                await this.refreshAccountContext();
            }
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async handleRecordTypeSelect(event) {
        const recordTypeId = event.detail?.value || event.currentTarget?.dataset?.id;
        if (!recordTypeId) {
            return;
        }

        this.selectedRecordTypeId = recordTypeId;
        this.step = STEP_VISIT_DETAIL;
        this.visitDetailLoading = this.visitDetailLoadedRecordTypeId !== recordTypeId;
        this.loading = true;
        this.errorMessage = null;

        try {
            let fields = this.visitFieldMetadataByRecordType[recordTypeId];
            if (!fields) {
                fields = await getVisitFieldMetadata({ recordTypeId });
            }
            this.visitFieldMetadataByRecordType = {
                ...this.visitFieldMetadataByRecordType,
                [recordTypeId]: fields
            };
            this.visitFields = this.mergeVisitFieldValues(fields);
        } catch (error) {
            this.visitDetailLoading = false;
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleVisitFormLoad() {
        this.visitDetailLoadedRecordTypeId = this.selectedRecordTypeId;
        this.visitDetailLoading = false;
        Promise.resolve().then(() => this.applyStoredVisitValues());
    }

    handleVisitDetailNext() {
        if (this.visitDetailLoading) {
            this.showToast('Still Loading', 'Wait for the Visit details to finish loading.', 'info');
            return;
        }

        if (!this.resolveAccountId()) {
            this.showToast('Account Required', 'Select an Account before continuing.', 'error');
            return;
        }

        if (!this.captureVisitFormValues(true)) {
            this.showToast('Missing Required Fields', 'Complete the required Visit fields before continuing.', 'error');
            return;
        }

        this.step = STEP_VISITORS;
    }

    handleVisitFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (!fieldName) {
            return;
        }

        this.visitFormValues = {
            ...this.visitFormValues,
            [fieldName]: this.getInputValue(event.target)
        };
        this.visitFields = this.mergeVisitFieldValues(this.visitFields);
    }

    handleAccountFieldChange(event) {
        const fieldValue = this.getInputValue(event.target);
        if (fieldValue) {
            this.setAccountId(fieldValue);
            this.visitFormValues = {
                ...this.visitFormValues,
                AccountId: fieldValue
            };
        }
    }

    handleAccountLookupChange(event) {
        const fieldValue = event.detail?.recordId || event.detail?.value || this.getInputValue(event.target);
        this.setAccountId(fieldValue, { resetRelated: true });
    }

    handleVisitorCandidateSelection(event) {
        const selectedRows = event.detail?.selectedRows || [];
        const selectedIds = new Set(selectedRows.map((visitor) => visitor.userId));
        const candidateIds = new Set(this.visitorCandidates.map((visitor) => visitor.userId));
        const manuallyAddedVisitors = this.selectedVisitors.filter((visitor) => !candidateIds.has(visitor.userId));

        this.visitorCandidates = this.visitorCandidates.map((visitor) => {
            if (visitor.locked) {
                return { ...visitor, selected: true };
            }
            return { ...visitor, selected: selectedIds.has(visitor.userId) };
        });

        this.selectedVisitors = this.uniqueVisitors([
            ...this.visitorCandidates.filter((visitor) => visitor.selected),
            ...manuallyAddedVisitors
        ]);
    }

    handleVisitorNext() {
        if (!this.selectedVisitors.length) {
            this.showToast('Visitors Required', 'Select at least one visitor before continuing.', 'error');
            return;
        }
        this.step = STEP_VISITED_PARTIES;
    }

    handlePrevious() {
        if (this.step === STEP_VISIT_DETAIL) {
            this.captureVisitFormValues(false);
            this.visitDetailLoading = false;
            this.step = STEP_RECORD_TYPE;
            return;
        }

        if (this.step > STEP_VISIT_DETAIL) {
            this.captureVisitFormValues(false);
            this.step -= 1;
            if (this.step === STEP_VISIT_DETAIL) {
                Promise.resolve().then(() => this.applyStoredVisitValues());
            }
        }
    }

    openUserModal() {
        this.showUserModal = true;
        this.runUserSearch();
    }

    closeUserModal() {
        this.showUserModal = false;
    }

    handleUserSearchTermChange(event) {
        this.userSearchTerm = event.target.value;
    }

    handleUserSearchKeyup(event) {
        if (event.key === 'Enter') {
            this.runUserSearch();
        }
    }

    async runUserSearch() {
        this.loading = true;
        try {
            this.userSearchResults = await searchUsers({
                searchTerm: this.userSearchTerm,
                excludedUserIds: this.selectedVisitorIds
            });
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleUserSearchRowAction(event) {
        if (event.detail?.action?.name !== ROW_ACTION_ADD) {
            return;
        }
        this.addVisitor(event.detail.row);
        this.userSearchResults = this.userSearchResults.filter((candidate) => candidate.userId !== event.detail.row.userId);
    }

    addSearchedUser(event) {
        const userId = event.currentTarget.dataset.id;
        const user = this.userSearchResults.find((candidate) => candidate.userId === userId);
        this.addVisitor(user);
        this.userSearchResults = this.userSearchResults.filter((candidate) => candidate.userId !== userId);
    }

    addVisitor(visitor) {
        if (!visitor || this.selectedVisitors.some((selected) => selected.userId === visitor.userId)) {
            return;
        }

        this.selectedVisitors = this.uniqueVisitors([...this.selectedVisitors, { ...visitor, selected: true }]);
        this.visitorCandidates = this.visitorCandidates.map((candidate) => {
            if (candidate.userId === visitor.userId) {
                return { ...candidate, selected: true };
            }
            return candidate;
        });
    }

    removeVisitor(event) {
        const userId = event.currentTarget.dataset.id;
        this.removeVisitorById(userId);
    }

    handleSelectedVisitorRowAction(event) {
        if (event.detail?.action?.name === ROW_ACTION_REMOVE) {
            this.removeVisitorById(event.detail.row.userId);
        }
    }

    removeVisitorById(userId) {
        const visitor = this.selectedVisitors.find((selected) => selected.userId === userId);
        if (visitor?.locked) {
            return;
        }

        this.selectedVisitors = this.selectedVisitors.filter((selected) => selected.userId !== userId);
        this.visitorCandidates = this.visitorCandidates.map((candidate) => {
            if (candidate.userId === userId && !candidate.locked) {
                return { ...candidate, selected: false };
            }
            return candidate;
        });
    }

    uniqueVisitors(visitors) {
        const seen = new Set();
        return visitors.filter((visitor) => {
            if (!visitor?.userId || seen.has(visitor.userId)) {
                return false;
            }
            seen.add(visitor.userId);
            return true;
        });
    }

    openContactModal() {
        this.showContactModal = true;
        this.runContactSearch();
    }

    closeContactModal() {
        this.showContactModal = false;
    }

    handleContactSearchTermChange(event) {
        this.contactSearchTerm = event.target.value;
    }

    handleContactSearchKeyup(event) {
        if (event.key === 'Enter') {
            this.runContactSearch();
        }
    }

    async runContactSearch() {
        const sourceAccountId = this.resolveAccountId();
        if (!sourceAccountId) {
            this.showToast('Account Required', 'Close this action and start again from an Account record.', 'error');
            return;
        }

        this.loading = true;
        try {
            this.contactSearchResults = await searchContacts({
                accountId: sourceAccountId,
                searchTerm: this.contactSearchTerm,
                excludedContactIds: this.selectedContactIds
            });
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleContactSearchRowAction(event) {
        if (event.detail?.action?.name !== ROW_ACTION_ADD) {
            return;
        }
        this.addContact(event.detail.row);
    }

    addSearchedContact(event) {
        const contactId = event.currentTarget.dataset.id;
        const contact = this.contactSearchResults.find((candidate) => candidate.contactId === contactId);
        this.addContact(contact);
    }

    addContact(contact) {
        const contactId = contact?.contactId;
        if (!contact || this.selectedContacts.some((selected) => selected.contactId === contactId)) {
            return;
        }

        this.selectedContacts = [...this.selectedContacts, { ...contact, contactId }];
        this.contactSearchResults = this.contactSearchResults.filter((candidate) => candidate.contactId !== contactId);
    }

    removeContact(event) {
        const contactId = event.currentTarget.dataset.id;
        this.removeContactById(contactId);
    }

    handleSelectedContactRowAction(event) {
        if (event.detail?.action?.name === ROW_ACTION_REMOVE) {
            this.removeContactById(event.detail.row.contactId);
        }
    }

    removeContactById(contactId) {
        this.selectedContacts = this.selectedContacts.filter((contact) => contact.contactId !== contactId);
    }

    handleSaveDraft() {
        this.persistVisit('Draft');
    }

    handleSubmit() {
        if (!this.selectedContacts.length) {
            this.showToast('Visited Parties Required', 'Select at least one visited party before submitting.', 'error');
            return;
        }
        this.persistVisit('Submit');
    }

    handleAddActionPlan() {
        if (!this.selectedContacts.length) {
            this.showToast('Visited Parties Required', 'Select at least one visited party before adding an Action Plan.', 'error');
            return;
        }
        this.persistVisit('Submit', { openActionPlan: true });
    }

    async persistVisit(action, options = {}) {
        this.captureVisitFormValues(false);
        const sourceAccountId = this.resolveAccountId();
        const accountIdForSave = this.resolveAccountIdText(sourceAccountId);
        const accountContextText = this.collectAccountContextText(accountIdForSave);
        const visitedContactIds = this.selectedContactIds;
        const visitedContactIdText = visitedContactIds.join(',');
        if (!accountIdForSave && !accountContextText && (action !== 'Submit' || !visitedContactIds.length)) {
            this.showToast('Account Required', 'Close this action and start again from an Account record.', 'error');
            return;
        }

        this.loading = true;
        this.errorMessage = null;

        try {
            const response = await saveVisitV3({
                requestJson: JSON.stringify({
                    accountId: accountIdForSave,
                    accountIdText: accountContextText,
                    sourceAccountId: accountContextText,
                    recordTypeId: this.selectedRecordTypeId,
                    visitFields: {
                        ...this.visitFormValues,
                        ...(accountIdForSave ? { AccountId: accountIdForSave } : {})
                    },
                    visitorUserIds: this.selectedVisitorIds,
                    visitedContactIds,
                    visitedContactIdStrings: visitedContactIds,
                    visitedContactIdText,
                    action
                })
            });

            if (options.openActionPlan) {
                await this.openActionPlanStep(response.visitId);
                this.showToast('Success', 'Visit created. Add the Action Plan details.', 'success');
                return;
            }

            this.showToast('Success', response.message, 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: response.visitId,
                    objectApiName: 'Visit',
                    actionName: 'view'
                }
            });
            this.closeHostAction();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async openActionPlanStep(visitId) {
        this.createdVisitId = visitId;
        this.actionPlanTargetRecordId = visitId;
        this.actionPlanStartDate = this.actionPlanStartDate || this.todayValue();

        const startInfo = await getActionPlanStartInfo({ visitId });
        this.recentActionPlanTemplates = startInfo?.recentTemplates || [];
        this.actionPlanStatusOptions = startInfo?.statusOptions || [];
        this.actionPlanStatus =
            this.actionPlanStatus ||
            startInfo?.defaultStatus ||
            this.actionPlanStatusOptions[0]?.value;
        this.actionPlanTargetRecordId = startInfo?.targetRecordId || visitId;
        this.step = STEP_ACTION_PLAN;
    }

    handleActionPlanFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (!fieldName) {
            return;
        }

        this[fieldName] = this.getInputValue(event.target);
    }

    handleActionPlanTemplateLookupChange(event) {
        this.actionPlanTemplateVersionId =
            event.detail?.recordId ||
            event.detail?.value ||
            this.getInputValue(event.target);
    }

    selectRecentActionPlanTemplate(event) {
        this.actionPlanTemplateVersionId = event.currentTarget.dataset.id;
    }

    handleRecentTemplateRowAction(event) {
        if (event.detail?.action?.name === ROW_ACTION_SELECT_TEMPLATE) {
            this.actionPlanTemplateVersionId = event.detail.row.templateVersionId;
        }
    }

    async handleActionPlanSubmit() {
        if (!this.validateActionPlanForm()) {
            this.showToast('Missing Required Fields', 'Complete the required Action Plan fields before submitting.', 'error');
            return;
        }

        this.loading = true;
        this.errorMessage = null;

        try {
            const response = await saveActionPlan({
                requestJson: JSON.stringify({
                    visitId: this.createdVisitId,
                    targetRecordId: this.actionPlanTargetRecordId,
                    name: this.actionPlanName,
                    startDate: this.actionPlanStartDate,
                    actionPlanTemplateVersionId: this.actionPlanTemplateVersionId,
                    status: this.actionPlanStatus
                })
            });

            this.showToast('Success', response.message, 'success');
            const visitRecordId = this.createdVisitId || this.actionPlanTargetRecordId;
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: visitRecordId,
                    objectApiName: 'Visit',
                    actionName: 'view'
                }
            });
            this.closeHostAction();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    validateActionPlanForm() {
        const fields = Array.from(this.template.querySelectorAll('[data-action-plan-field]'));
        let isValid = true;
        fields.forEach((field) => {
            const fieldName = field.dataset.field;
            const reportedValid = typeof field.reportValidity === 'function' ? field.reportValidity() : true;
            const hasRequiredValue = fieldName ? this.hasValue(this.getInputValue(field)) : true;
            isValid = isValid && reportedValid && hasRequiredValue;
        });

        return isValid && this.hasValue(this.actionPlanTemplateVersionId);
    }

    todayValue() {
        const now = new Date();
        const localDate = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
        return localDate.toISOString().slice(0, 10);
    }

    hasValue(value) {
        return value !== null && value !== undefined && value !== '' && (!Array.isArray(value) || value.length > 0);
    }

    setAccountId(value, options = {}) {
        const normalizedValue = this.normalizeIdValue(value);
        if (!normalizedValue) {
            return;
        }

        if (options.lockAccount) {
            this.sourceAccountLocked = true;
        }

        this.visitFormValues = {
            ...this.visitFormValues,
            AccountId: normalizedValue
        };

        if (this.accountId === normalizedValue) {
            return;
        }

        this.accountId = normalizedValue;
        this._recordId = normalizedValue;
        if (options.resetRelated) {
            this.visitorCandidates = [];
            this.selectedVisitors = [];
            this.selectedContacts = [];
            this.contactSearchResults = [];
            this.userSearchResults = [];
        }
        if (this.initialized) {
            this.refreshAccountContext();
        } else {
            this.initialize();
        }
    }

    async refreshAccountContext() {
        if (!this.accountId) {
            return;
        }

        this.loading = true;
        try {
            const [accountInfo, visitorCandidates] = await Promise.all([
                getAccountInfo({ accountId: this.accountId }),
                getInitialVisitorCandidates({ accountId: this.accountId })
            ]);
            this.accountName = accountInfo?.name;
            this.customerAccountNumber = accountInfo?.customerAccountNumber;
            this.visitorCandidates = visitorCandidates;
            this.selectedVisitors = visitorCandidates.filter((visitor) => visitor.selected);
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    captureVisitFormValues(validate) {
        const fields = Array.from(this.template.querySelectorAll('[data-visit-field]'));
        const values = { ...this.visitFormValues };
        const sourceAccountId = this.resolveAccountId();
        if (sourceAccountId) {
            values.AccountId = sourceAccountId;
        }
        let isValid = true;
        const requiredFields = new Set(this.visitFields.filter((field) => field.required).map((field) => field.apiName));

        fields.forEach((field) => {
            const fieldName = field.dataset.field;
            const fieldValue = this.getInputValue(field);
            values[fieldName] = fieldValue;

            if (validate) {
                const reportedValid = typeof field.reportValidity === 'function' ? field.reportValidity() : true;
                const hasRequiredValue = !requiredFields.has(fieldName) || this.hasValue(fieldValue);
                isValid = isValid && reportedValid && hasRequiredValue;
            }
        });

        this.visitFormValues = values;
        this.visitFields = this.mergeVisitFieldValues(this.visitFields);
        return isValid;
    }

    applyStoredVisitValues() {
        const accountField = this.template.querySelector('[data-account-field]');
        const sourceAccountId = this.resolveAccountId();
        if (accountField && sourceAccountId) {
            accountField.value = sourceAccountId;
        }

        const fields = Array.from(this.template.querySelectorAll('[data-visit-field]'));
        fields.forEach((field) => {
            const fieldName = field.dataset.field;
            if (Object.prototype.hasOwnProperty.call(this.visitFormValues, fieldName)) {
                field.value = this.visitFormValues[fieldName];
            }
        });
    }

    resolveAccountId() {
        const candidates = [
            this.accountId,
            this._recordId,
            this.recordId,
            this.visitFormValues.AccountId,
            this.getAccountIdFromSelectedContacts(),
            this.getInputValue(this.template.querySelector('[data-account-field]')),
            this.extractAccountIdFromUrl()
        ];

        const accountId = candidates.map((candidate) => this.normalizeIdValue(candidate)).find((candidate) => !!candidate);
        if (accountId) {
            this.setAccountId(accountId);
        }
        return accountId;
    }

    resolveAccountIdText(preferredAccountId) {
        return this.findAccountIdInStrings(this.getAccountContextValues(preferredAccountId));
    }

    collectAccountContextText(preferredAccountId) {
        return this.getAccountContextValues(preferredAccountId)
            .map((value) => this.stringifyContextValue(value))
            .filter((value) => !!value)
            .join('|');
    }

    getAccountContextValues(preferredAccountId) {
        return [
            preferredAccountId,
            this.accountId,
            this._recordId,
            this.recordId,
            this.visitFormValues.AccountId,
            this.getAccountIdFromSelectedContacts(),
            this.getInputValue(this.template.querySelector('[data-account-field]')),
            this.extractAccountIdFromUrl(),
            window?.location?.href,
            document?.location?.href,
            document?.URL,
            document?.referrer,
            window?.history?.state,
            this.selectedContacts,
            this.getRenderedAccountIds()
        ];
    }

    getAccountIdFromSelectedContacts() {
        const contactWithAccount = this.selectedContacts.find((contact) => contact.accountId || contact.AccountId);
        const accountId = contactWithAccount ? contactWithAccount.accountId || contactWithAccount.AccountId : null;
        return accountId || this.getRenderedAccountId();
    }

    extractAccountIdFromPageReference(pageReference) {
        const state = pageReference?.state || {};
        const candidates = [state.recordId, state.c__recordId, state.backgroundContext, state.inContextOfRef];

        if (state.inContextOfRef) {
            const encodedContext = String(state.inContextOfRef).replace(/^1\./, '');
            try {
                candidates.push(window.atob(encodedContext));
            } catch {
                // Salesforce can omit or alter the encoded context depending on how the action was launched.
            }
        }

        return this.findAccountIdInStrings(candidates);
    }

    extractAccountIdFromUrl() {
        const candidates = [
            window.location.href,
            document?.location?.href,
            document?.URL,
            document?.referrer,
            window?.history?.state
        ];

        try {
            const url = new URL(window.location.href);
            candidates.push(url.searchParams.get('recordId'));
            candidates.push(url.searchParams.get('c__recordId'));
            candidates.push(url.searchParams.get('backgroundContext'));
            candidates.push(url.searchParams.get('inContextOfRef'));
        } catch {
            // Fall back to scanning the raw href below.
        }

        return this.findAccountIdInStrings(candidates);
    }

    normalizeIdValue(value) {
        if (Array.isArray(value)) {
            return value.length ? this.normalizeIdValue(value[0]) : null;
        }
        if (!value) {
            return null;
        }

        const stringValue = String(value);
        const match = stringValue.match(/001[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?/);
        return match ? match[0] : null;
    }

    normalizeContactIdValue(value) {
        if (Array.isArray(value)) {
            return value.length ? this.normalizeContactIdValue(value[0]) : null;
        }
        if (!value) {
            return null;
        }

        const stringValue = String(value);
        const match = stringValue.match(/003[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?/);
        return match ? match[0] : null;
    }

    getRenderedContactIds() {
        const ids = [];
        this.collectRenderedIds(this.template, ids, '[data-contact-id], lightning-button-icon[data-id], [data-id*="003"]', (element) =>
            this.normalizeContactIdValue(this.getDataValue(element, 'contactId') || this.getDataValue(element, 'id'))
        );
        return this.dedupeIds(ids);
    }

    getRenderedAccountId() {
        return this.getRenderedAccountIds()[0] || null;
    }

    getRenderedAccountIds() {
        const accountIds = [];
        this.collectRenderedIds(this.template, accountIds, '[data-account-id], [data-source-account-id], [data-record-id], [data-recordid]', (element) =>
            this.normalizeIdValue(
                this.getDataValue(element, 'accountId') ||
                this.getDataValue(element, 'sourceAccountId') ||
                this.getDataValue(element, 'recordId') ||
                this.getDataValue(element, 'recordid')
            )
        );
        return this.dedupeIds(accountIds);
    }

    collectRenderedIds(root, ids, selector, normalize) {
        if (!root || !selector) {
            return;
        }

        try {
            root.querySelectorAll(selector).forEach((element) => {
                const normalizedId = normalize(element);
                if (normalizedId) {
                    ids.push(normalizedId);
                }
            });
        } catch {
            // Some Lightning wrappers restrict template queries; state-based ids are still used above.
        }
    }

    getDataValue(element, name) {
        if (!element) {
            return null;
        }
        const attributeName = name.replace(/[A-Z]/g, (letter) => '-' + letter.toLowerCase());
        return element.dataset?.[name] || element.getAttribute?.('data-' + attributeName);
    }

    stringifyContextValue(value) {
        if (!value) {
            return null;
        }
        if (typeof value === 'string') {
            return value;
        }
        try {
            return JSON.stringify(value);
        } catch {
            return String(value);
        }
    }

    dedupeIds(ids) {
        const seen = new Set();
        return ids.filter((id) => {
            if (!id || seen.has(id)) {
                return false;
            }
            seen.add(id);
            return true;
        });
    }

    findAccountIdInStrings(values) {
        const candidates = [];
        values.forEach((value) => {
            if (!value) {
                return;
            }

            let stringValue;
            try {
                stringValue = typeof value === 'string' ? value : JSON.stringify(value);
            } catch {
                stringValue = String(value);
            }
            if (!stringValue) {
                return;
            }
            candidates.push(stringValue);
            try {
                const decodedValue = decodeURIComponent(stringValue);
                candidates.push(decodedValue);
                candidates.push(decodeURIComponent(decodedValue));
            } catch {
                // Some strings are not URL encoded.
            }
        });

        return candidates.map((candidate) => this.normalizeIdValue(candidate)).find((candidate) => !!candidate) || null;
    }

    getInputValue(input) {
        if (!input) {
            return null;
        }
        return input.value;
    }

    mergeVisitFieldValues(fields) {
        return fields.map((field) => ({
            ...field,
            value: Object.prototype.hasOwnProperty.call(this.visitFormValues, field.apiName)
                ? this.visitFormValues[field.apiName]
                : field.value
        }));
    }

    handleError(error) {
        this.errorMessage = this.reduceError(error);
        this.showToast('Error', this.errorMessage, 'error');
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Something went wrong.';
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

    closeHostAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new CustomEvent('visitwizardclose', { bubbles: true, composed: true }));
    }
}
