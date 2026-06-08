import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord, getRecordCreateDefaults } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import ACTION_PLAN_NAME_FIELD from '@salesforce/schema/ActionPlan.Name';
import ACTION_PLAN_STATE_FIELD from '@salesforce/schema/ActionPlan.ActionPlanState';
import ACTION_PLAN_START_DATE_FIELD from '@salesforce/schema/ActionPlan.StartDate';
import ACTION_PLAN_TARGET_FIELD from '@salesforce/schema/ActionPlan.TargetId';
import ACTION_PLAN_TEMPLATE_VERSION_FIELD from '@salesforce/schema/ActionPlan.ActionPlanTemplateVersionId';
import VISIT_ACCOUNT_FIELD from '@salesforce/schema/Visit.AccountId';
import VISIT_NAME_FIELD from '@salesforce/schema/Visit.Name';
import VISIT_RECORD_TYPE_FIELD from '@salesforce/schema/Visit.RecordTypeId';
import VISIT_STATUS_FIELD from '@salesforce/schema/Visit.Status';

import getLaunchContext from '@salesforce/apex/VisitWizardV6Controller.getLaunchContext';
import getVisitFieldMetadata from '@salesforce/apex/VisitWizardV6Controller.getVisitFieldMetadata';
import getAccountInfo from '@salesforce/apex/VisitWizardV6Controller.getAccountInfo';
import searchAccounts from '@salesforce/apex/VisitWizardV6Controller.searchAccounts';
import searchAccountAddresses from '@salesforce/apex/VisitWizardV6Controller.searchAccountAddresses';
import getDefaultAccountAddress from '@salesforce/apex/VisitWizardV6Controller.getDefaultAccountAddress';
import getAddressInfo from '@salesforce/apex/VisitWizardV6Controller.getAddressInfo';
import getInitialVisitorCandidates from '@salesforce/apex/VisitWizardV6Controller.getInitialVisitorCandidates';
import searchUsers from '@salesforce/apex/VisitWizardV6Controller.searchUsers';
import getContactRecordTypeDescriptions from '@salesforce/apex/VisitWizardV6Controller.getContactRecordTypeDescriptions';
import searchContacts from '@salesforce/apex/VisitWizardV6Controller.searchContacts';
import saveForLater from '@salesforce/apex/VisitWizardV6Controller.saveForLater';
import saveVisitProgress from '@salesforce/apex/VisitWizardV6Controller.saveVisitProgress';
import getActionPlanStartInfo from '@salesforce/apex/VisitWizardV6Controller.getActionPlanStartInfo';
import getActionPlanTemplateOption from '@salesforce/apex/VisitWizardV6Controller.getActionPlanTemplateOption';
import saveActionPlanAndLoadTasks from '@salesforce/apex/VisitWizardV6Controller.saveActionPlanAndLoadTasks';
import getTaskList from '@salesforce/apex/VisitWizardV6Controller.getTaskList';
import startTask from '@salesforce/apex/VisitWizardV6Controller.startTask';
import saveTask from '@salesforce/apex/VisitWizardV6Controller.saveTask';
import getTaskNotes from '@salesforce/apex/VisitWizardV6Controller.getTaskNotes';
import saveTaskNote from '@salesforce/apex/VisitWizardV6Controller.saveTaskNote';
import getOpportunityDefaults from '@salesforce/apex/VisitWizardV6Controller.getOpportunityDefaults';
import getReview from '@salesforce/apex/VisitWizardV6Controller.getReview';
import completeVisit from '@salesforce/apex/VisitWizardV6Controller.completeVisit';

const STEP_RECORD_TYPE = 1;
const STEP_VISIT_DETAIL = 2;
const STEP_VISITORS = 3;
const STEP_VISITED_PARTIES = 4;
const STEP_ACTION_PLAN = 5;
const STEP_TASK_LIST = 6;
const STEP_TASK_DETAIL = 7;
const STEP_REVIEW = 8;
const ROW_ACTION_ADD = 'add';
const ROW_ACTION_REMOVE = 'remove';
const ROW_ACTION_SELECT_TEMPLATE = 'select_template';
const ROW_ACTION_START_TASK = 'start_task';
const ROW_ACTION_SELECT_ACCOUNT = 'select_account';
const ROW_ACTION_SELECT_ADDRESS = 'select_address';
const ACCOUNT_CUSTOMER_NUMBER_FIELD = 'Customer_Account_Number__c';
const CONTACT_OBJECT_API_NAME = 'Contact';
const VISIT_STATUS_IN_PROGRESS = 'InProgress';
const ACTION_PLAN_STATUS_IN_PROGRESS = 'In Progress';
const ACTION_PLAN_NAME_PREFIX = 'Template - ';
const ACTION_PLAN_NAME_MAX_LENGTH = 255;

export default class VisitWizardV6 extends NavigationMixin(LightningElement) {
    @track recordTypes = [];
    @track visitFields = [];
    @track visitorCandidates = [];
    @track selectedVisitors = [];
    @track selectedContacts = [];
    @track accountSearchResults = [];
    @track addressSearchResults = [];
    @track userSearchResults = [];
    @track contactSearchResults = [];
    @track recentActionPlanTemplates = [];
    @track actionPlanStatusOptions = [];
    @track tasks = [];
    @track taskNotes = [];
    @track opportunities = [];
    @track contactLayoutSections = [];
    @track contactRecordTypeDescriptions = {};

    step = STEP_RECORD_TYPE;
    selectedRecordTypeId;
    visitFormValues = {};
    createdVisitId;
    createdVisitName;
    launchMode = 'NEW';
    visitStatus;
    resumePage = 'RecordType';
    actionPlanId;
    actionPlanName = '';
    actionPlanStartDate;
    actionPlanTemplateVersionId;
    actionPlanStatus;
    actionPlanTargetRecordId;
    createActionPlan = true;
    requiredTasksComplete = false;
    activeTask;
    taskNoteTitle = '';
    taskNoteBody = '';
    opportunityDefaults;
    opportunityForm = {};
    loading = false;
    visitDetailLoading = false;
    errorMessage;
    showUserModal = false;
    showAccountModal = false;
    showAddressModal = false;
    showContactModal = false;
    showContactRecordTypeModal = false;
    showCreateContactModal = false;
    showTopicModal = false;
    showOpportunityModal = false;
    accountSearchTerm = '';
    addressSearchTerm = '';
    userSearchTerm = '';
    contactSearchTerm = '';
    newTopicForm = {};
    initialized = false;
    canEdit = true;
    completed = false;
    accountId;
    accountName;
    placeDisplayValue = '';
    newContactRecordTypeId;
    newContactDraft = {};
    contactLayoutLoading = false;
    sourceAccountLocked = false;
    hostActionClosing = false;
    userSearchStarted = false;
    userSearchTimer;
    newTopicSaveMode = 'close';
    _recordId;

    actionPlanTemplatePickerFilter = {
        criteria: [
            { fieldPath: 'Status', operator: 'eq', value: 'Final' },
            { fieldPath: 'ActionPlanTemplate.Status', operator: 'eq', value: 'Final' },
            { fieldPath: 'ActionPlanTemplate.TargetEntityType', operator: 'eq', value: 'Visit' }
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
    accountNameFields = [ACCOUNT_NAME_FIELD];
    accountCanFields = [ACCOUNT_CUSTOMER_NUMBER_FIELD];
    actionPlanReviewFields = [
        ACTION_PLAN_NAME_FIELD,
        ACTION_PLAN_STATE_FIELD,
        ACTION_PLAN_START_DATE_FIELD,
        ACTION_PLAN_TARGET_FIELD,
        ACTION_PLAN_TEMPLATE_VERSION_FIELD
    ];
    visitNameFields = [VISIT_NAME_FIELD];
    visitReviewFields = [VISIT_NAME_FIELD, VISIT_ACCOUNT_FIELD, VISIT_STATUS_FIELD, VISIT_RECORD_TYPE_FIELD];

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
    accountSearchColumns = [
        { label: 'Account Name', fieldName: 'name', wrapText: true },
        { label: 'Customer Account Number', fieldName: 'customerAccountNumber' },
        { label: 'Old Dealer Code', fieldName: 'dealerCode' },
        { type: 'button', fixedWidth: 92, typeAttributes: { label: 'Select', name: ROW_ACTION_SELECT_ACCOUNT, variant: 'brand-outline' } }
    ];
    addressSearchColumns = [
        { label: 'Address', fieldName: 'displayAddress', wrapText: true },
        { label: 'City', fieldName: 'city' },
        { label: 'State', fieldName: 'state' },
        { label: 'Postal Code', fieldName: 'postalCode' },
        { label: 'Country', fieldName: 'country' },
        { label: 'Address Name', fieldName: 'name' },
        { type: 'button', fixedWidth: 92, typeAttributes: { label: 'Select', name: ROW_ACTION_SELECT_ADDRESS, variant: 'brand-outline' } }
    ];
    userSearchColumns = [
        { label: 'Name', fieldName: 'name', wrapText: true },
        { label: 'Role', fieldName: 'role', wrapText: true },
        { label: 'Email', fieldName: 'email', type: 'email', wrapText: true },
        { type: 'button-icon', fixedWidth: 56, typeAttributes: { iconName: 'utility:add', name: ROW_ACTION_ADD, title: 'Add' } }
    ];
    selectedContactColumns = [
        { label: 'Name', fieldName: 'name', wrapText: true },
        { label: 'Title', fieldName: 'title', wrapText: true },
        { label: 'Email', fieldName: 'email', type: 'email', wrapText: true },
        { label: 'Phone', fieldName: 'phone', type: 'phone', wrapText: true },
        { type: 'button-icon', fixedWidth: 56, typeAttributes: { iconName: 'utility:delete', name: ROW_ACTION_REMOVE, title: 'Remove' } }
    ];
    contactSearchColumns = [
        { label: 'Name', fieldName: 'name', wrapText: true },
        { label: 'Title', fieldName: 'title', wrapText: true },
        { label: 'Email', fieldName: 'email', type: 'email', wrapText: true },
        { label: 'Phone', fieldName: 'phone', type: 'phone', wrapText: true },
        { type: 'button-icon', fixedWidth: 56, typeAttributes: { iconName: 'utility:add', name: ROW_ACTION_ADD, title: 'Add' } }
    ];
    recentActionPlanTemplateColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Type', fieldName: 'actionPlanType' },
        { label: 'Version', fieldName: 'versionNumber', type: 'number' },
        { label: 'Last Modified', fieldName: 'lastModifiedDate', type: 'date' },
        { type: 'button', fixedWidth: 96, typeAttributes: { label: 'Select', name: ROW_ACTION_SELECT_TEMPLATE, variant: 'base' } }
    ];
    taskColumns = [
        { label: 'Topic', fieldName: 'name', wrapText: true },
        { label: 'Status', fieldName: 'displayStatus' },
        { label: 'Required', fieldName: 'requiredLabel' },
        { label: 'Completed', fieldName: 'completedLabel' },
        { type: 'button', fixedWidth: 110, typeAttributes: { label: { fieldName: 'taskActionLabel' }, name: ROW_ACTION_START_TASK, variant: 'brand-outline' } }
    ];
    reviewTaskColumns = [
        { label: 'Topic', fieldName: 'name', wrapText: true },
        { label: 'Status', fieldName: 'displayStatus' },
        { label: 'Required', fieldName: 'requiredLabel' },
        { label: 'Completed', fieldName: 'completedLabel' }
    ];
    opportunityColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Stage', fieldName: 'stageName' },
        { label: 'Close Date', fieldName: 'closeDate', type: 'date' },
        { label: 'Amount', fieldName: 'amount', type: 'currency' }
    ];

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
    }

    @wire(getObjectInfo, { objectApiName: CONTACT_OBJECT_API_NAME })
    contactObjectInfo;

    @wire(getRecordCreateDefaults, {
        objectApiName: CONTACT_OBJECT_API_NAME,
        recordTypeId: '$contactCreateDefaultsRecordTypeId'
    })
    setContactCreateDefaults({ data, error }) {
        if (!this.showCreateContactModal) {
            return;
        }
        this.contactLayoutLoading = false;
        if (data) {
            this.contactLayoutSections = this.buildContactLayoutSections(data);
        } else if (error) {
            this.contactLayoutSections = this.fallbackContactLayoutSections();
            this.handleError(error);
        }
    }

    @wire(getContactRecordTypeDescriptions)
    setContactRecordTypeDescriptions({ data }) {
        this.contactRecordTypeDescriptions = data || {};
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageReference) {
        const recordId = this.findRecordId([
            pageReference?.state?.recordId,
            pageReference?.state?.c__recordId,
            pageReference?.attributes?.recordId,
            pageReference?.state?.backgroundContext,
            pageReference?.state?.inContextOfRef
        ]);
        if (recordId && !this._recordId) {
            this._recordId = recordId;
        }
    }

    connectedCallback() {
        this.initialize();
    }

    disconnectedCallback() {
        window.clearTimeout(this.userSearchTimer);
        if (!this.shouldSaveOnHostClose()) {
            return;
        }
        try {
            this.captureVisitFormValues(false);
            const payload = this.buildSavePayload(this.resumePageForStep(this.step), false);
            saveForLater({ requestJson: JSON.stringify(payload) }).catch(() => {
                // The host modal is already closing, so this best-effort save cannot show UI feedback.
            });
        } catch {
            // Closing should never be blocked by best-effort save for later.
        }
    }

    renderedCallback() {
        this.sizeHostModal();
    }

    sizeHostModal() {
        const host = this.template?.host;
        const modalContainer = host?.closest?.('.slds-modal__container');
        if (!modalContainer || modalContainer.dataset.visitWizardV6Sized === 'true') {
            return;
        }

        modalContainer.dataset.visitWizardV6Sized = 'true';
        modalContainer.style.width = 'min(96vw, 112rem)';
        modalContainer.style.maxWidth = 'min(96vw, 112rem)';
        modalContainer.style.minWidth = 'min(72rem, 96vw)';
    }

    get panelHeader() {
        return this.launchMode === 'EDIT' ? 'Edit Visit' : 'New Visit';
    }

    get isBusy() {
        return this.loading || this.visitDetailLoading;
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

    get isTaskListStep() {
        return this.step === STEP_TASK_LIST;
    }

    get isTaskDetailStep() {
        return this.step === STEP_TASK_DETAIL;
    }

    get isReviewStep() {
        return this.step === STEP_REVIEW;
    }

    get showRecordTypePage() {
        return this.recordTypes.length > 1;
    }

    get showPrevious() {
        return this.step > STEP_RECORD_TYPE && !this.isReviewStep && !this.isTaskDetailStep;
    }

    get showSaveForLater() {
        return [STEP_VISIT_DETAIL, STEP_VISITORS, STEP_VISITED_PARTIES, STEP_ACTION_PLAN].includes(this.step) && this.canEdit;
    }

    get visitDetailSectionClass() {
        return this.isVisitDetailStep ? '' : 'slds-hide';
    }

    get visitFormClass() {
        return this.visitDetailLoading ? 'visit-form visit-form_loading' : 'visit-form';
    }

    get visitRecordIdForForm() {
        return this.createdVisitId || null;
    }

    get hasCreatedVisitId() {
        return !!this.createdVisitId;
    }

    get hasAccountId() {
        return !!this.accountId;
    }

    get placeSearchDisabled() {
        return !this.hasAccountId || this.isBusy;
    }

    get placeId() {
        return this.visitFormValues.PlaceId || null;
    }

    get accountDisplayValue() {
        return this.accountName || this.accountId || '';
    }

    get placeLookupDisplayValue() {
        return this.placeDisplayValue || this.placeId || '';
    }

    get hasActionPlanId() {
        return !!this.actionPlanId;
    }

    get actionPlanCreationLocked() {
        return this.hasActionPlanId;
    }

    get showEditableAccountCanOutput() {
        return this.showCustomerAccountNumber && this.hasAccountId;
    }

    get visitDisplayValue() {
        return this.createdVisitName || this.visitFormValues.Name || this.createdVisitId;
    }

    get actionPlanTargetDisplayValue() {
        return this.visitDisplayValue || this.actionPlanTargetRecordId;
    }

    get recordTypeOptions() {
        return this.recordTypes.map((recordType) => ({
            label: recordType.defaultRecordTypeMapping ? `${recordType.label} (Default)` : recordType.label,
            value: recordType.value
        }));
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

    get userSearchDisabled() {
        return this.isBusy || String(this.userSearchTerm || '').trim().length < 3;
    }

    get userSearchEmptyMessage() {
        if (!this.userSearchStarted || String(this.userSearchTerm || '').trim().length < 3) {
            return 'No user found! Search for a user and press Search button.';
        }
        return 'No user found.';
    }

    get hasContactSearchResults() {
        return this.contactSearchResults.length > 0;
    }

    get hasAccountSearchResults() {
        return this.accountSearchResults.length > 0;
    }

    get hasAddressSearchResults() {
        return this.addressSearchResults.length > 0;
    }

    get contactRecordTypeOptions() {
        const infos = this.contactObjectInfo?.data?.recordTypeInfos || {};
        return Object.keys(infos)
            .map((recordTypeId) => infos[recordTypeId])
            .filter((info) => info?.available && !info.master)
            .map((info) => ({
                label: info.name,
                value: info.recordTypeId,
                description: this.contactRecordTypeDescriptions?.[info.recordTypeId] || ''
            }));
    }

    get hasMultipleContactRecordTypes() {
        return this.contactRecordTypeOptions.length > 1;
    }

    get contactRecordTypeChoices() {
        return this.contactRecordTypeOptions.map((option) => ({
            ...option,
            className: option.value === this.newContactRecordTypeId ? 'record-type-choice selected' : 'record-type-choice',
            buttonClass:
                option.value === this.newContactRecordTypeId
                    ? 'slds-button slds-button_brand record-type-action'
                    : 'slds-button slds-button_neutral record-type-action',
            description: option.description || 'No description provided.'
        }));
    }

    get selectedContactRecordTypeLabel() {
        return this.contactRecordTypeOptions.find((option) => option.value === this.newContactRecordTypeId)?.label || '';
    }

    get createContactModalTitle() {
        return this.selectedContactRecordTypeLabel ? `New Contact: ${this.selectedContactRecordTypeLabel}` : 'Create Contact';
    }

    get contactCreateDefaultsRecordTypeId() {
        return this.showCreateContactModal && this.newContactRecordTypeId ? this.newContactRecordTypeId : undefined;
    }

    get hasContactLayoutSections() {
        return this.contactLayoutSections.some((section) => section.rows.some((row) => row.fields.length > 0));
    }

    get createContactSaveDisabled() {
        return this.isBusy || this.contactLayoutLoading || !this.hasContactLayoutSections;
    }

    get hasRecentActionPlanTemplates() {
        return this.recentActionPlanTemplates.length > 0;
    }

    get hasTasks() {
        return this.tasks.length > 0;
    }

    get hasOpportunities() {
        return this.opportunities.length > 0;
    }

    get hasTaskNotes() {
        return this.taskNotes.length > 0;
    }

    get activeTaskIsSales() {
        return this.activeTask?.salesTask;
    }

    get activeTaskStartDateTime() {
        return this.activeTask?.startDateTime || null;
    }

    get taskEndDateTimeMin() {
        return this.activeTaskStartDateTime;
    }

    get taskHasRequiredNote() {
        return this.hasTaskNotes || this.hasRichTextContent(this.taskNoteBody);
    }

    get taskDateRangeValid() {
        if (!this.activeTask?.startDateTime || !this.activeTask?.endDateTime) {
            return false;
        }
        return new Date(this.activeTask.endDateTime).getTime() >= new Date(this.activeTask.startDateTime).getTime();
    }

    get taskCompleteReady() {
        return !!this.activeTask?.startDateTime && !!this.activeTask?.endDateTime && this.taskDateRangeValid && this.taskHasRequiredNote;
    }

    get taskCompleteDisabled() {
        return this.isBusy || !this.taskCompleteReady;
    }

    get taskNoteSaveDisabled() {
        return this.isBusy || !this.hasRichTextContent(this.taskNoteBody);
    }

    get selectedVisitorIds() {
        return this.selectedVisitors.map((visitor) => visitor.userId);
    }

    get lockedVisitorIds() {
        return this.visitorCandidates.filter((visitor) => visitor.locked).map((visitor) => visitor.userId);
    }

    get selectedContactIds() {
        return this.uniqueContactIds(this.selectedContacts);
    }

    get steps() {
        const rawSteps = [
            ...(this.showRecordTypePage ? [{ value: STEP_RECORD_TYPE, label: 'Record Type' }] : []),
            { value: STEP_VISIT_DETAIL, label: 'Visit Details' },
            { value: STEP_VISITORS, label: 'Visitors' },
            { value: STEP_VISITED_PARTIES, label: 'Visited Parties' },
            { value: STEP_ACTION_PLAN, label: 'Meeting Template' },
            { value: STEP_TASK_LIST, label: 'Topics' },
            { value: STEP_REVIEW, label: 'Review' }
        ];
        return rawSteps.map((stepItem, index) => ({
            ...stepItem,
            number: index + 1,
            className: stepItem.value === this.step ? 'step active' : stepItem.value < this.step ? 'step complete' : 'step'
        }));
    }

    get stepbarStyle() {
        return `--step-count: ${this.steps.length}`;
    }

    async initialize() {
        if (this.initialized) {
            return;
        }
        this.initialized = true;
        this.loading = true;
        this.errorMessage = null;

        try {
            const context = await getLaunchContext({ recordIdText: this.resolveLaunchRecordId() });
            await this.applyLaunchContext(context);
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async applyLaunchContext(context) {
        this.launchMode = context?.mode || 'NEW';
        this.canEdit = context?.canEdit !== false;
        this.completed = context?.completed === true;
        this.visitStatus = context?.visitStatus || VISIT_STATUS_IN_PROGRESS;
        this.recordTypes = context?.recordTypes || [];
        this.createdVisitId = context?.visitId;
        this.createdVisitName = context?.visitName;
        this.accountId = context?.accountId;
        this.accountName = context?.accountName;
        this.selectedRecordTypeId = context?.recordTypeId;
        this.visitFormValues = { ...(context?.visitValues || {}) };
        if (!this.completed) {
            this.visitStatus = VISIT_STATUS_IN_PROGRESS;
            this.visitFormValues = { ...this.visitFormValues, Status: VISIT_STATUS_IN_PROGRESS };
        }
        this.visitorCandidates = context?.visitorCandidates || [];
        this.selectedVisitors = context?.selectedVisitors?.length ? context.selectedVisitors : this.visitorCandidates.filter((visitor) => visitor.selected);
        this.selectedContacts = this.uniqueContacts(context?.selectedContacts || []);
        this.actionPlanId = context?.actionPlanId;
        this.actionPlanName = context?.actionPlanName || '';
        this.actionPlanStartDate = context?.actionPlanStartDate || this.todayValue();
        this.actionPlanTemplateVersionId = context?.actionPlanTemplateVersionId;
        this.actionPlanStatus = context?.actionPlanStatus || ACTION_PLAN_STATUS_IN_PROGRESS;
        this.actionPlanTargetRecordId = this.createdVisitId;
        this.tasks = this.decorateTasks(context?.tasks || []);
        this.opportunities = context?.opportunities || [];
        this.sourceAccountLocked = false;
        this.resumePage = context?.resumePage || (this.recordTypes.length === 1 ? 'VisitDetails' : 'RecordType');

        if (this.completed) {
            this.errorMessage = 'This Visit is completed and cannot be edited through the V6 flow.';
            this.step = STEP_REVIEW;
            return;
        }

        this.applySerializedState(context?.stateJson);

        if (this.visitFormValues.PlaceId) {
            await this.hydratePlace(this.visitFormValues.PlaceId);
        } else {
            await this.applyDefaultAccountPlace();
        }

        if (!this.selectedRecordTypeId && this.recordTypes.length === 1) {
            this.selectedRecordTypeId = this.recordTypes[0].value;
        }

        if (this.selectedRecordTypeId) {
            await this.loadVisitFields(this.selectedRecordTypeId);
        }

        this.step = this.stepFromResumePage(this.resumePage);
        if (!this.showRecordTypePage && this.step === STEP_RECORD_TYPE) {
            this.step = STEP_VISIT_DETAIL;
        }
        if (this.step === STEP_ACTION_PLAN && this.createdVisitId) {
            await this.openActionPlanStep(this.createdVisitId, false);
        }
    }

    async handleRecordTypeSelect(event) {
        const recordTypeId = event.detail?.value || event.currentTarget?.dataset?.id;
        if (!recordTypeId) {
            return;
        }
        this.selectedRecordTypeId = recordTypeId;
        this.step = STEP_VISIT_DETAIL;
        await this.loadVisitFields(recordTypeId);
    }

    async loadVisitFields(recordTypeId) {
        this.visitDetailLoading = true;
        this.errorMessage = null;
        try {
            const fields = await getVisitFieldMetadata({ recordTypeId });
            this.visitFields = this.mergeVisitFieldValues(fields || []);
        } catch (error) {
            this.handleError(error);
        } finally {
            this.visitDetailLoading = false;
        }
    }

    handleVisitFormLoad() {
        this.visitDetailLoading = false;
        Promise.resolve().then(() => this.applyStoredVisitValues());
    }

    async handleVisitDetailNext() {
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
        this.visitFormValues = { ...this.visitFormValues, [fieldName]: this.getInputValue(event.target) };
        this.visitFields = this.mergeVisitFieldValues(this.visitFields);
    }

    openAccountModal() {
        this.showAccountModal = true;
        this.accountSearchTerm = this.accountName || '';
        this.runAccountSearch();
    }

    closeAccountModal() {
        this.showAccountModal = false;
    }

    handleAccountSearchTermChange(event) {
        this.accountSearchTerm = this.getInputValue(event.target);
    }

    handleAccountSearchKeyup(event) {
        if (event.key === 'Enter') {
            this.runAccountSearch();
        }
    }

    async runAccountSearch() {
        this.loading = true;
        try {
            this.accountSearchResults = await searchAccounts({ searchTerm: this.accountSearchTerm });
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async handleAccountSearchRowAction(event) {
        if (event.detail?.action?.name !== ROW_ACTION_SELECT_ACCOUNT) {
            return;
        }
        const row = event.detail.row;
        this.setAccountId(row.accountId, { resetRelated: true });
        this.accountName = row.name;
        this.showAccountModal = false;
        await this.refreshAccountContext();
    }

    openAddressModal() {
        if (!this.resolveAccountId()) {
            this.showToast('Account Required', 'Select an Account before searching for a Place.', 'error');
            return;
        }
        this.showAddressModal = true;
        this.addressSearchTerm = '';
        this.runAddressSearch();
    }

    closeAddressModal() {
        this.showAddressModal = false;
    }

    handleAddressSearchTermChange(event) {
        this.addressSearchTerm = this.getInputValue(event.target);
    }

    handleAddressSearchKeyup(event) {
        if (event.key === 'Enter') {
            this.runAddressSearch();
        }
    }

    async runAddressSearch() {
        const accountId = this.resolveAccountId();
        if (!accountId) {
            this.showToast('Account Required', 'Select an Account before searching for a Place.', 'error');
            return;
        }
        this.loading = true;
        try {
            this.addressSearchResults = await searchAccountAddresses({ accountId, searchTerm: this.addressSearchTerm });
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleAddressSearchRowAction(event) {
        if (event.detail?.action?.name !== ROW_ACTION_SELECT_ADDRESS) {
            return;
        }
        this.setPlace(event.detail.row);
        this.showAddressModal = false;
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
        this.selectedVisitors = this.uniqueVisitors([...this.visitorCandidates.filter((visitor) => visitor.selected), ...manuallyAddedVisitors]);
    }

    handleVisitorNext() {
        if (!this.selectedVisitors.length) {
            this.showToast('Visitors Required', 'Select at least one visitor before continuing.', 'error');
            return;
        }
        this.step = STEP_VISITED_PARTIES;
    }

    async handleVisitedPartyNext() {
        if (!this.selectedContacts.length) {
            this.showToast('Visited Parties Required', 'Select at least one visited party before continuing.', 'error');
            return;
        }
        const response = await this.persistProgress('ActionPlan', false, true);
        if (response?.visitId) {
            await this.openActionPlanStep(response.visitId, true);
        }
    }

    handlePrevious() {
        this.captureVisitFormValues(false);
        if (this.step === STEP_VISIT_DETAIL && this.showRecordTypePage) {
            this.step = STEP_RECORD_TYPE;
            return;
        }
        if (this.step === STEP_ACTION_PLAN) {
            this.step = STEP_VISITED_PARTIES;
            return;
        }
        if (this.step === STEP_TASK_LIST) {
            this.step = STEP_ACTION_PLAN;
            return;
        }
        if (this.step > STEP_VISIT_DETAIL) {
            this.step -= 1;
            if (this.step === STEP_VISIT_DETAIL) {
                Promise.resolve().then(() => this.applyStoredVisitValues());
            }
        }
    }

    async handleSaveForLater() {
        const resumePage = this.resumePageForStep(this.step);
        const response = await this.persistProgress(resumePage, true, this.step === STEP_VISIT_DETAIL);
        if (response?.visitId) {
            this.showToast('Saved', 'Visit saved for later.', 'success');
            this.hostActionClosing = true;
            this.navigateToVisit(response.visitId);
            this.closeHostAction();
        }
    }

    async persistProgress(resumePage, saveLater, validateRequired) {
        if (this.step === STEP_VISIT_DETAIL && !this.captureVisitFormValues(validateRequired)) {
            this.showToast('Missing Required Fields', 'Complete the required Visit fields before saving.', 'error');
            return null;
        }
        this.captureVisitFormValues(false);
        this.loading = true;
        this.errorMessage = null;

        try {
            const payload = this.buildSavePayload(resumePage, validateRequired);
            const method = saveLater ? saveForLater : saveVisitProgress;
            const response = await method({ requestJson: JSON.stringify(payload) });
            this.createdVisitId = response.visitId;
            this.createdVisitName = response.visitName || this.createdVisitName;
            this.actionPlanTargetRecordId = response.visitId;
            this.resumePage = response.resumePage;
            return response;
        } catch (error) {
            this.handleError(error);
            return null;
        } finally {
            this.loading = false;
        }
    }

    buildSavePayload(resumePage, validateRequired) {
        return {
            visitId: this.createdVisitId,
            accountId: this.resolveAccountId(),
            recordTypeId: this.selectedRecordTypeId,
            visitFields: {
                ...this.visitFormValues,
                AccountId: this.resolveAccountId(),
                Status: VISIT_STATUS_IN_PROGRESS
            },
            visitorUserIds: this.selectedVisitorIds,
            visitedContactIds: this.selectedContactIds,
            resumePage,
            stateJson: this.serializedState(),
            actionPlanId: this.actionPlanId,
            validateRequired
        };
    }

    async openActionPlanStep(visitId, moveToStep) {
        this.createdVisitId = visitId;
        this.actionPlanTargetRecordId = visitId;
        this.actionPlanStartDate = this.actionPlanStartDate || this.todayValue();
        this.loading = true;
        try {
            const startInfo = await getActionPlanStartInfo({ visitId });
            this.recentActionPlanTemplates = startInfo?.recentTemplates || [];
            this.actionPlanStatusOptions = startInfo?.statusOptions || [];
            this.actionPlanStatus = this.actionPlanStatus || this.preferredActionPlanStatus(startInfo?.defaultStatus);
            if (moveToStep) {
                this.step = STEP_ACTION_PLAN;
            }
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleCreateActionPlanChange(event) {
        if (this.actionPlanCreationLocked) {
            this.createActionPlan = true;
            return;
        }
        this.createActionPlan = event.target.checked;
    }

    handleActionPlanFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (fieldName) {
            this[fieldName] = this.getInputValue(event.target);
        }
    }

    async handleActionPlanTemplateLookupChange(event) {
        const hasRecordId = Object.prototype.hasOwnProperty.call(event.detail || {}, 'recordId');
        const templateVersionId = hasRecordId ? event.detail.recordId : event.detail?.value || null;
        this.actionPlanTemplateVersionId = templateVersionId;

        if (!templateVersionId) {
            this.actionPlanName = '';
            return;
        }

        const recentTemplate = this.recentActionPlanTemplates.find(
            (template) => template.templateVersionId === templateVersionId
        );
        if (recentTemplate) {
            this.actionPlanName = this.actionPlanNameForTemplate(recentTemplate.templateName || recentTemplate.name);
            return;
        }

        try {
            const option = await getActionPlanTemplateOption({ templateVersionId });
            if (this.actionPlanTemplateVersionId === templateVersionId) {
                this.actionPlanName = this.actionPlanNameForTemplate(option?.templateName || option?.name);
            }
        } catch (error) {
            this.handleError(error);
        }
    }

    async handleRecentTemplateRowAction(event) {
        if (event.detail?.action?.name === ROW_ACTION_SELECT_TEMPLATE) {
            await this.selectActionPlanTemplate(event.detail.row);
        }
    }

    async selectActionPlanTemplate(template) {
        const templateVersionId = template?.templateVersionId;
        if (!templateVersionId) {
            return;
        }
        this.actionPlanTemplateVersionId = null;
        await Promise.resolve();
        this.actionPlanTemplateVersionId = templateVersionId;
        this.actionPlanName = this.actionPlanNameForTemplate(template.templateName || template.name);
        const picker = this.template.querySelector('[data-action-plan-template-picker]');
        if (picker) {
            picker.value = templateVersionId;
        }
    }

    actionPlanNameForTemplate(templateName) {
        const name = `${ACTION_PLAN_NAME_PREFIX}${templateName || ''}`;
        if (name.length <= ACTION_PLAN_NAME_MAX_LENGTH) {
            return name;
        }
        return `${name.slice(0, ACTION_PLAN_NAME_MAX_LENGTH - 2)}..`;
    }

    async handleActionPlanNext() {
        if (this.actionPlanCreationLocked) {
            this.createActionPlan = true;
        }
        if (!this.createActionPlan) {
            await this.loadTaskList(null);
            return;
        }
        if (!this.validateActionPlanForm()) {
            this.showToast('Missing Required Fields', 'Complete the Meeting Template fields before continuing.', 'error');
            return;
        }
        this.loading = true;
        this.errorMessage = null;
        try {
            const response = await saveActionPlanAndLoadTasks({
                requestJson: JSON.stringify({
                    visitId: this.createdVisitId,
                    actionPlanId: this.actionPlanId,
                    targetRecordId: this.actionPlanTargetRecordId,
                    name: this.actionPlanName,
                    startDate: this.actionPlanStartDate,
                    actionPlanTemplateVersionId: this.actionPlanTemplateVersionId,
                    status: this.actionPlanStatus || this.preferredActionPlanStatus(),
                    stateJson: this.serializedState()
                })
            });
            this.actionPlanId = response.actionPlanId;
            this.tasks = this.decorateTasks(response.tasks || []);
            this.requiredTasksComplete = response.requiredTasksComplete;
            this.step = STEP_TASK_LIST;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async loadTaskList(actionPlanId) {
        this.actionPlanId = actionPlanId || this.actionPlanId;
        this.tasks = this.decorateTasks([]);
        this.requiredTasksComplete = true;
        this.step = STEP_TASK_LIST;
    }

    openTopicModal() {
        this.resetNewTopicForm();
        this.showTopicModal = true;
    }

    closeTopicModal() {
        this.showTopicModal = false;
    }

    resetNewTopicForm() {
        this.newTopicForm = {
            name: '',
            status: 'Is Defined',
            description: '',
            required: false,
            startDateTime: null,
            endDateTime: null,
            definitionReferenceId: null,
            sequence: this.nextTopicSequenceValue()
        };
        this.newTopicSaveMode = 'close';
    }

    nextTopicSequenceValue() {
        const sequences = (this.tasks || [])
            .map((task) => Number(task.sequence))
            .filter((sequence) => Number.isFinite(sequence));
        return sequences.length ? Math.max(...sequences) + 1 : 1;
    }

    handleNewTopicFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (!fieldName) {
            return;
        }
        this.newTopicForm = {
            ...this.newTopicForm,
            [fieldName]: Object.prototype.hasOwnProperty.call(event.detail || {}, 'value')
                ? event.detail.value
                : this.getInputValue(event.target)
        };
    }

    setNewTopicSaveMode(event) {
        this.newTopicSaveMode = event.target?.dataset?.saveMode || 'close';
    }

    handleNewTopicSubmit(event) {
        event.preventDefault();
        if (!this.createdVisitId) {
            this.showToast('Visit Required', 'Create or save the Visit before adding a Topic.', 'error');
            return;
        }

        const fields = { ...(event.detail?.fields || {}) };
        fields.VisitId = this.createdVisitId;
        fields.Status = fields.Status || this.newTopicForm.status || 'Is Defined';
        if (!this.hasValue(fields.Sequence) && this.hasValue(this.newTopicForm.sequence)) {
            fields.Sequence = Number(this.newTopicForm.sequence);
        }
        if (!this.hasValue(fields.IsRequired)) {
            fields.IsRequired = Boolean(this.newTopicForm.required);
        }

        this.loading = true;
        event.target.submit(fields);
    }

    async handleNewTopicSuccess() {
        try {
            const response = await getTaskList({
                visitId: this.createdVisitId,
                actionPlanId: this.actionPlanId
            });
            this.actionPlanId = response?.actionPlanId || this.actionPlanId;
            this.tasks = this.decorateTasks(response?.tasks || []);
            this.requiredTasksComplete = Boolean(response?.requiredTasksComplete);
            this.showToast('Topic Created', 'Topic added to this Visit.', 'success');
            if (this.newTopicSaveMode === 'new') {
                this.showTopicModal = false;
                await Promise.resolve();
                this.resetNewTopicForm();
                this.showTopicModal = true;
            } else {
                this.showTopicModal = false;
            }
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleNewTopicError(event) {
        this.loading = false;
        this.handleError(event.detail);
    }

    handleTaskRowAction(event) {
        if (event.detail?.action?.name !== ROW_ACTION_START_TASK) {
            return;
        }
        this.openTask(event.detail.row);
    }

    async openTask(taskRow) {
        this.loading = true;
        try {
            if (!taskRow.completed && taskRow.itemState !== 'InProgress') {
                const response = await startTask({
                    visitId: this.createdVisitId,
                    actionPlanItemId: taskRow.actionPlanItemId,
                    genericTaskId: taskRow.genericTaskId
                });
                this.tasks = this.decorateTasks(response.tasks || []);
                this.requiredTasksComplete = response.requiredTasksComplete;
            }
            this.activeTask = this.applyTaskDefaults(this.tasks.find((task) => task.genericTaskId === taskRow.genericTaskId) || taskRow);
            this.taskNoteTitle = `${this.activeTask?.name || 'Visit Topic'} Note`;
            this.taskNoteBody = '';
            await this.loadTaskNotes(this.activeTask?.genericTaskId);
            this.step = STEP_TASK_DETAIL;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleTaskFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (fieldName && this.activeTask) {
            this.activeTask = { ...this.activeTask, [fieldName]: this.getInputValue(event.target) };
            Promise.resolve().then(() => this.validateTaskDateRange(false));
        }
    }

    handleTaskNoteTitleChange(event) {
        this.taskNoteTitle = this.getInputValue(event.target);
    }

    handleTaskNoteBodyChange(event) {
        this.taskNoteBody = event.detail?.value || event.target.value || '';
    }

    async loadTaskNotes(genericTaskId) {
        if (!genericTaskId) {
            this.taskNotes = [];
            return;
        }
        this.taskNotes = await getTaskNotes({ genericTaskId });
    }

    async handleTaskNoteSave() {
        await this.savePendingTaskNote();
    }

    async savePendingTaskNote() {
        if (!this.activeTask?.genericTaskId || !this.hasRichTextContent(this.taskNoteBody)) {
            return;
        }
        const notes = await saveTaskNote({
            requestJson: JSON.stringify({
                genericTaskId: this.activeTask.genericTaskId,
                title: this.taskNoteTitle || `${this.activeTask.name || 'Visit Topic'} Note`,
                body: this.taskNoteBody
            })
        });
        this.taskNotes = notes || [];
        this.taskNoteTitle = `${this.activeTask.name || 'Visit Topic'} Note`;
        this.taskNoteBody = '';
        this.showToast('Saved', 'Note saved.', 'success');
    }

    async handleTaskSave() {
        await this.persistTask(false);
    }

    async handleTaskComplete() {
        if (!this.validateTaskCompletion(true)) {
            return;
        }
        await this.persistTask(true);
    }

    async persistTask(complete) {
        if (!this.activeTask) {
            return;
        }
        const shouldShowDateErrors = complete || !!(this.activeTask.startDateTime && this.activeTask.endDateTime);
        if (!this.validateTaskDateRange(shouldShowDateErrors)) {
            return;
        }
        this.loading = true;
        try {
            await this.savePendingTaskNote();
            const response = await saveTask({
                requestJson: JSON.stringify({
                    visitId: this.createdVisitId,
                    actionPlanItemId: this.activeTask.actionPlanItemId,
                    genericTaskId: this.activeTask.genericTaskId,
                    actionPlanId: this.actionPlanId,
                    description: this.activeTask.description,
                    startDateTime: this.activeTask.startDateTime,
                    endDateTime: this.activeTask.endDateTime,
                    status: this.activeTask.status,
                    complete
                })
            });
            this.tasks = this.decorateTasks(response.tasks || []);
            this.requiredTasksComplete = response.requiredTasksComplete;
            this.activeTask = null;
            this.step = STEP_TASK_LIST;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async openOpportunityModal() {
        this.loading = true;
        try {
            const defaults = await getOpportunityDefaults({ visitId: this.createdVisitId });
            this.opportunityDefaults = defaults;
            this.opportunityForm = {
                name: `${this.accountName || 'Visit'} Opportunity`,
                closeDate: defaults.closeDate,
                stageName: defaults.stageName,
                amount: null,
                type: null,
                description: null
            };
            this.showOpportunityModal = true;
            if (defaults.warning) {
                this.showToast('Opportunity Stage', defaults.warning, 'warning');
            }
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    closeOpportunityModal() {
        this.showOpportunityModal = false;
    }

    handleOpportunityFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (fieldName) {
            this.opportunityForm = { ...this.opportunityForm, [fieldName]: this.getInputValue(event.target) };
        }
    }

    async handleOpportunitySubmit() {
        const inputs = Array.from(this.template.querySelectorAll('[data-opportunity-field]'));
        const valid = inputs.reduce((isValid, input) => {
            const fieldValid = typeof input.reportValidity === 'function' ? input.reportValidity() : true;
            return isValid && fieldValid;
        }, true);
        if (!valid) {
            return;
        }
        this.loading = true;
        try {
            const fields = {
                Name: this.opportunityForm.name,
                AccountId: this.accountId,
                Visit__c: this.createdVisitId,
                StageName: this.opportunityForm.stageName,
                CloseDate: this.opportunityForm.closeDate
            };
            if (this.hasValue(this.opportunityForm.amount)) {
                fields.Amount = Number(this.opportunityForm.amount);
            }
            if (this.hasValue(this.opportunityForm.type)) {
                fields.Type = this.opportunityForm.type;
            }
            if (this.hasValue(this.opportunityForm.description)) {
                fields.Description = this.opportunityForm.description;
            }
            const createdRecord = await createRecord({ apiName: 'Opportunity', fields });
            const opportunity = {
                opportunityId: createdRecord.id,
                name: fields.Name,
                stageName: fields.StageName,
                closeDate: fields.CloseDate,
                amount: fields.Amount
            };
            this.opportunities = [opportunity, ...this.opportunities];
            this.showOpportunityModal = false;
            this.showToast('Success', 'Opportunity created.', 'success');
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async handleTasksNext() {
        if (!this.requiredTasksComplete) {
            return;
        }
        this.loading = true;
        try {
            const context = await getReview({ visitId: this.createdVisitId, actionPlanId: this.actionPlanId });
            this.createdVisitName = context?.visitName || this.createdVisitName;
            this.actionPlanName = context?.actionPlanName || this.actionPlanName;
            this.tasks = this.decorateTasks(context?.tasks || []);
            this.opportunities = context?.opportunities || [];
            this.step = STEP_REVIEW;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async handleCompleteVisit() {
        this.loading = true;
        try {
            const response = await completeVisit({ visitId: this.createdVisitId, actionPlanId: this.actionPlanId });
            this.showToast('Completed', response.message, 'success');
            this.hostActionClosing = true;
            this.navigateToVisit(response.visitId);
            this.closeHostAction();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    openUserModal() {
        this.showUserModal = true;
        this.userSearchTerm = '';
        this.userSearchResults = [];
        this.userSearchStarted = false;
    }

    closeUserModal() {
        this.showUserModal = false;
        window.clearTimeout(this.userSearchTimer);
    }

    handleUserSearchTermChange(event) {
        this.userSearchTerm = event.target.value || '';
        window.clearTimeout(this.userSearchTimer);
        if (this.userSearchTerm.trim().length < 3) {
            this.userSearchResults = [];
            this.userSearchStarted = false;
            return;
        }
        this.userSearchTimer = window.setTimeout(() => {
            this.runUserSearch();
        }, 300);
    }

    handleUserSearchKeyup(event) {
        if (event.key === 'Enter') {
            this.runUserSearch();
        }
    }

    async runUserSearch() {
        if (this.userSearchTerm.trim().length < 3) {
            this.userSearchResults = [];
            this.userSearchStarted = false;
            return;
        }
        this.loading = true;
        this.userSearchStarted = true;
        try {
            this.userSearchResults = await searchUsers({ searchTerm: this.userSearchTerm, excludedUserIds: this.selectedVisitorIds });
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

    handleUserSearchAddClick(event) {
        const userId = event.currentTarget?.dataset?.userId;
        const visitor = this.userSearchResults.find((candidate) => candidate.userId === userId);
        this.addVisitor(visitor);
        this.userSearchResults = this.userSearchResults.filter((candidate) => candidate.userId !== userId);
    }

    addVisitor(visitor) {
        if (!visitor || this.selectedVisitors.some((selected) => selected.userId === visitor.userId)) {
            return;
        }
        this.selectedVisitors = this.uniqueVisitors([...this.selectedVisitors, { ...visitor, selected: true }]);
        this.visitorCandidates = this.visitorCandidates.map((candidate) => candidate.userId === visitor.userId ? { ...candidate, selected: true } : candidate);
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
        this.visitorCandidates = this.visitorCandidates.map((candidate) => candidate.userId === userId && !candidate.locked ? { ...candidate, selected: false } : candidate);
    }

    openContactModal() {
        this.showContactModal = true;
        this.runContactSearch();
    }

    closeContactModal() {
        this.showContactModal = false;
    }

    buildContactLayoutSections(defaults) {
        const sections = defaults?.layout?.sections || [];
        const recordFields = defaults?.record?.fields || {};
        const seenFields = new Set();
        const layoutSections = sections
            .map((section, sectionIndex) => {
                const rows = (section.layoutRows || [])
                    .map((row, rowIndex) => {
                        const fields = [];
                        (row.layoutItems || []).forEach((item, itemIndex) => {
                            (item.layoutComponents || []).forEach((component, componentIndex) => {
                                const apiName = component.apiName || component.fieldApiName || component.value;
                                const componentType = component.componentType || component.type;
                                if (!apiName || seenFields.has(apiName) || componentType !== 'Field') {
                                    return;
                                }
                                if (apiName === 'RecordTypeId') {
                                    return;
                                }
                                if (item.editableForNew === false && apiName !== 'AccountId') {
                                    return;
                                }

                                seenFields.add(apiName);
                                fields.push({
                                    id: `${sectionIndex}-${rowIndex}-${itemIndex}-${componentIndex}-${apiName}`,
                                    apiName,
                                    required: item.required === true,
                                    value: this.contactFieldDefaultValue(apiName, recordFields),
                                    disabled: apiName === 'AccountId'
                                });
                            });
                        });
                        return {
                            id: `${sectionIndex}-${rowIndex}`,
                            fields
                        };
                    })
                    .filter((row) => row.fields.length > 0);

                return {
                    id: `section-${sectionIndex}`,
                    heading: section.heading || section.label || 'Contact Information',
                    rows
                };
            })
            .filter((section) => section.rows.length > 0);

        return layoutSections.length ? layoutSections : this.fallbackContactLayoutSections();
    }

    contactFieldDefaultValue(apiName, recordFields) {
        if (apiName === 'AccountId') {
            return this.resolveAccountId();
        }
        return recordFields?.[apiName]?.value;
    }

    fallbackContactLayoutSections() {
        return [
            {
                id: 'fallback-contact-information',
                heading: 'Contact Information',
                rows: [
                    {
                        id: 'fallback-row-1',
                        fields: [
                            { id: 'fallback-FirstName', apiName: 'FirstName' },
                            { id: 'fallback-LastName', apiName: 'LastName', required: true }
                        ]
                    },
                    {
                        id: 'fallback-row-2',
                        fields: [
                            { id: 'fallback-Title', apiName: 'Title' },
                            { id: 'fallback-Email', apiName: 'Email' }
                        ]
                    },
                    {
                        id: 'fallback-row-3',
                        fields: [
                            { id: 'fallback-Phone', apiName: 'Phone' },
                            { id: 'fallback-AccountId', apiName: 'AccountId', value: this.resolveAccountId(), disabled: true }
                        ]
                    }
                ]
            }
        ];
    }

    openCreateContact() {
        const accountId = this.resolveAccountId();
        if (!accountId) {
            this.showToast('Account Required', 'Select an Account before creating a Contact.', 'error');
            return;
        }
        this.newContactDraft = {};
        this.contactLayoutSections = [];
        this.contactLayoutLoading = false;
        const options = this.contactRecordTypeOptions;
        if (options.length > 1) {
            this.newContactRecordTypeId = this.contactObjectInfo?.data?.defaultRecordTypeId || options[0].value;
            this.showContactRecordTypeModal = true;
            return;
        }
        this.newContactRecordTypeId = options[0]?.value || this.contactObjectInfo?.data?.defaultRecordTypeId || null;
        this.openCreateContactForm();
    }

    closeContactRecordTypeModal() {
        this.showContactRecordTypeModal = false;
    }

    handleContactRecordTypeChange(event) {
        this.newContactRecordTypeId = event.currentTarget?.dataset?.id || event.detail?.value || event.target.value;
        this.continueCreateContact();
    }

    continueCreateContact() {
        if (!this.newContactRecordTypeId) {
            this.showToast('Record Type Required', 'Select a Contact record type before continuing.', 'error');
            return;
        }
        this.showContactRecordTypeModal = false;
        this.openCreateContactForm();
    }

    openCreateContactForm() {
        this.contactLayoutSections = [];
        this.contactLayoutLoading = true;
        this.showCreateContactModal = true;
    }

    closeCreateContactModal() {
        this.showCreateContactModal = false;
        this.newContactDraft = {};
        this.contactLayoutSections = [];
        this.contactLayoutLoading = false;
    }

    handleCreateContactSubmit(event) {
        event.preventDefault();
        const accountId = this.resolveAccountId();
        if (!accountId) {
            this.showToast('Account Required', 'Select an Account before creating a Contact.', 'error');
            return;
        }
        const fields = { ...event.detail.fields, AccountId: accountId };
        if (this.newContactRecordTypeId) {
            fields.RecordTypeId = this.newContactRecordTypeId;
        }
        this.newContactDraft = { ...fields };
        this.template.querySelector('[data-create-contact-form]').submit(fields);
    }

    handleCreateContactSuccess(event) {
        const fields = event.detail?.fields || {};
        const firstName = this.recordFormFieldValue(fields, 'FirstName') || this.newContactDraft.FirstName || '';
        const lastName = this.recordFormFieldValue(fields, 'LastName') || this.newContactDraft.LastName || '';
        const contactId = this.normalizeContactId(event.detail.id);
        const contact = {
            contactId,
            accountId: this.resolveAccountId(),
            name: `${firstName} ${lastName}`.trim() || this.recordFormFieldValue(fields, 'Name') || 'New Contact',
            email: this.recordFormFieldValue(fields, 'Email') || this.newContactDraft.Email,
            phone: this.recordFormFieldValue(fields, 'Phone') || this.newContactDraft.Phone,
            title: this.recordFormFieldValue(fields, 'Title') || this.newContactDraft.Title
        };
        this.addContact(contact);
        this.contactSearchResults = this.contactSearchResults.filter((candidate) => this.recordIdentityKey(candidate.contactId) !== this.recordIdentityKey(contactId));
        this.showCreateContactModal = false;
        this.showToast('Contact Created', 'Contact added to Visited Parties.', 'success');
    }

    handleCreateContactError(event) {
        const message = event.detail?.message || 'Contact could not be created.';
        this.showToast('Contact Error', message, 'error');
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
        const accountId = this.resolveAccountId();
        if (!accountId) {
            this.showToast('Account Required', 'Select an Account before adding visited parties.', 'error');
            return;
        }
        this.loading = true;
        try {
            this.contactSearchResults = await searchContacts({ accountId, searchTerm: this.contactSearchTerm, excludedContactIds: this.selectedContactIds });
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
        const addedId = this.normalizeContactId(event.detail.row?.contactId);
        this.contactSearchResults = this.contactSearchResults.filter((candidate) => this.recordIdentityKey(candidate.contactId) !== this.recordIdentityKey(addedId));
    }

    addContact(contact) {
        const contactId = this.normalizeContactId(contact?.contactId);
        if (!contactId) {
            return;
        }
        this.selectedContacts = this.uniqueContacts([...this.selectedContacts, { ...contact, contactId }]);
    }

    handleSelectedContactRowAction(event) {
        if (event.detail?.action?.name === ROW_ACTION_REMOVE) {
            const removedId = this.normalizeContactId(event.detail.row?.contactId);
            const removedKey = this.recordIdentityKey(removedId);
            this.selectedContacts = this.uniqueContacts(this.selectedContacts.filter((contact) => this.recordIdentityKey(contact.contactId) !== removedKey));
        }
    }

    validateActionPlanForm() {
        if (!this.createActionPlan) {
            return true;
        }
        const fields = Array.from(this.template.querySelectorAll('[data-action-plan-field]'));
        return fields.reduce((isValid, field) => {
            const valid = typeof field.reportValidity === 'function' ? field.reportValidity() : true;
            return isValid && valid && this.hasValue(this.getInputValue(field));
        }, true) && this.hasValue(this.actionPlanTemplateVersionId);
    }

    captureVisitFormValues(validate) {
        const fields = Array.from(this.template.querySelectorAll('[data-visit-field]'));
        const values = { ...this.visitFormValues };
        const accountId = this.resolveAccountId();
        if (accountId) {
            values.AccountId = accountId;
        }
        const placeId = this.normalizeRecordId(this.visitFormValues.PlaceId, '130');
        if (placeId) {
            values.PlaceId = placeId;
        } else {
            delete values.PlaceId;
        }
        let isValid = true;
        const requiredFields = new Set(this.visitFields.filter((field) => field.required).map((field) => field.apiName));
        if (validate && !placeId) {
            isValid = false;
        }
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
        Array.from(this.template.querySelectorAll('[data-visit-field]')).forEach((field) => {
            const fieldName = field.dataset.field;
            if (Object.prototype.hasOwnProperty.call(this.visitFormValues, fieldName)) {
                field.value = this.visitFormValues[fieldName];
            }
        });
    }

    async refreshAccountContext() {
        if (!this.accountId) {
            return;
        }
        this.loading = true;
        try {
            const [accountInfo, visitorCandidates, defaultAddress] = await Promise.all([
                getAccountInfo({ accountId: this.accountId }),
                getInitialVisitorCandidates({ accountId: this.accountId }),
                getDefaultAccountAddress({ accountId: this.accountId })
            ]);
            this.accountName = accountInfo?.name;
            this.visitorCandidates = visitorCandidates || [];
            this.selectedVisitors = this.visitorCandidates.filter((visitor) => visitor.selected);
            if (!this.placeId && defaultAddress) {
                this.setPlace(defaultAddress);
            }
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async applyDefaultAccountPlace() {
        const accountId = this.resolveAccountId();
        if (!accountId || this.placeId) {
            return;
        }
        try {
            const defaultAddress = await getDefaultAccountAddress({ accountId });
            if (defaultAddress) {
                this.setPlace(defaultAddress);
            }
        } catch {
            // Place can still be selected manually if the default address is not readable.
        }
    }

    async hydratePlace(placeId) {
        const addressId = this.normalizeRecordId(placeId, '130');
        if (!addressId) {
            return;
        }
        try {
            const address = await getAddressInfo({ addressId });
            this.setPlace(address || { addressId, displayAddress: addressId, name: addressId });
        } catch {
            this.setPlace({ addressId, displayAddress: addressId, name: addressId });
        }
    }

    setPlace(address) {
        const addressId = this.normalizeRecordId(address?.addressId, '130');
        if (!addressId) {
            return;
        }
        this.visitFormValues = {
            ...this.visitFormValues,
            PlaceId: addressId
        };
        this.placeDisplayValue = address.displayAddress || address.name || addressId;
    }

    clearPlace() {
        const values = { ...this.visitFormValues };
        delete values.PlaceId;
        this.visitFormValues = values;
        this.placeDisplayValue = '';
        this.addressSearchResults = [];
        this.addressSearchTerm = '';
    }

    setAccountId(value, options = {}) {
        const accountId = this.normalizeAccountId(value);
        if (!accountId) {
            if (options.allowClear) {
                this.accountId = null;
                const values = { ...this.visitFormValues };
                delete values.AccountId;
                delete values.PlaceId;
                this.visitFormValues = values;
                this.placeDisplayValue = '';
                this.addressSearchResults = [];
                if (options.resetRelated) {
                    this.visitorCandidates = [];
                    this.selectedVisitors = [];
                    this.selectedContacts = [];
                    this.contactSearchResults = [];
                    this.userSearchResults = [];
                }
            }
            return;
        }
        const accountChanged = this.accountId && this.accountId !== accountId;
        this.accountId = accountId;
        this.visitFormValues = { ...this.visitFormValues, AccountId: accountId };
        if (options.resetRelated || accountChanged) {
            this.clearPlace();
            this.visitorCandidates = [];
            this.selectedVisitors = [];
            this.selectedContacts = [];
            this.contactSearchResults = [];
            this.userSearchResults = [];
        }
    }

    shouldSaveOnHostClose() {
        if (
            this.hostActionClosing ||
            !this.initialized ||
            !this.canEdit ||
            this.completed ||
            !this.showSaveForLater
        ) {
            return false;
        }
        return !!this.resolveAccountId() && !!this.selectedRecordTypeId;
    }

    resolveAccountId() {
        const accountId = this.normalizeAccountId(this.accountId || this.visitFormValues.AccountId);
        if (accountId) {
            this.setAccountId(accountId);
        }
        return accountId;
    }

    serializedState() {
        return JSON.stringify({
            selectedRecordTypeId: this.selectedRecordTypeId,
            visitFormValues: this.visitFormValues,
            selectedVisitors: this.selectedVisitors,
            selectedContacts: this.uniqueContacts(this.selectedContacts),
            placeDisplayValue: this.placeDisplayValue,
            actionPlanId: this.actionPlanId,
            actionPlanName: this.actionPlanName,
            actionPlanStartDate: this.actionPlanStartDate,
            actionPlanTemplateVersionId: this.actionPlanTemplateVersionId,
            actionPlanStatus: this.actionPlanStatus,
            createActionPlan: this.createActionPlan
        });
    }

    applySerializedState(stateJson) {
        if (!stateJson) {
            return;
        }
        try {
            const state = JSON.parse(stateJson);
            this.selectedRecordTypeId = this.selectedRecordTypeId || state.selectedRecordTypeId;
            this.visitFormValues = { ...this.visitFormValues, ...(state.visitFormValues || {}) };
            this.selectedVisitors = state.selectedVisitors?.length ? state.selectedVisitors : this.selectedVisitors;
            this.selectedContacts = state.selectedContacts?.length ? this.uniqueContacts(state.selectedContacts) : this.uniqueContacts(this.selectedContacts);
            this.placeDisplayValue = state.placeDisplayValue || this.placeDisplayValue;
            this.actionPlanId = this.actionPlanId || state.actionPlanId;
            this.actionPlanName = this.actionPlanName || state.actionPlanName || '';
            this.actionPlanStartDate = this.actionPlanStartDate || state.actionPlanStartDate;
            this.actionPlanTemplateVersionId = this.actionPlanTemplateVersionId || state.actionPlanTemplateVersionId;
            this.actionPlanStatus = this.actionPlanStatus || state.actionPlanStatus;
            this.createActionPlan = state.createActionPlan !== false;
            if (this.actionPlanId) {
                this.createActionPlan = true;
            }
        } catch {
            // Saved state is best-effort; persisted records still hydrate the wizard.
        }
    }

    decorateTasks(tasks) {
        return (tasks || []).map((task) => ({
            ...task,
            displayStatus: this.formatTaskStatus(task.itemState || task.status || 'Not Started'),
            requiredLabel: task.required ? 'Yes' : 'No',
            completedLabel: task.completed ? 'Yes' : 'No',
            taskActionLabel: task.completed || task.itemState === 'InProgress' ? 'View' : 'Start'
        }));
    }

    applyTaskDefaults(task) {
        return {
            ...task,
            startDateTime: task?.startDateTime || this.nowDateTimeValue()
        };
    }

    formatTaskStatus(status) {
        if (status === 'InProgress') {
            return 'In Progress';
        }
        return status;
    }

    preferredActionPlanStatus(fallbackValue) {
        const hasInProgress = (this.actionPlanStatusOptions || []).some(
            (option) => option.value === ACTION_PLAN_STATUS_IN_PROGRESS
        );
        if (hasInProgress) {
            return ACTION_PLAN_STATUS_IN_PROGRESS;
        }
        return fallbackValue || this.actionPlanStatusOptions[0]?.value;
    }

    validateTaskCompletion(showErrors) {
        const fieldsValid = this.validateTaskDateRange(showErrors);
        if (!this.taskHasRequiredNote) {
            if (showErrors) {
                this.showToast('Notes Required', 'Add a note before completing the topic.', 'error');
            }
            return false;
        }
        if (!this.taskCompleteReady) {
            if (showErrors) {
                this.showToast('Required Fields', 'Complete Start Date Time, End Date Time, and Notes before completing the topic.', 'error');
            }
            return false;
        }
        return fieldsValid;
    }

    validateTaskDateRange(showErrors) {
        const startInput = this.template.querySelector('[data-task-start]');
        const endInput = this.template.querySelector('[data-task-end]');
        const startValue = this.activeTask?.startDateTime;
        const endValue = this.activeTask?.endDateTime;
        let valid = true;

        if (startInput && typeof startInput.setCustomValidity === 'function') {
            startInput.setCustomValidity(startValue ? '' : 'Start Date Time is required.');
            valid = valid && (!showErrors || startInput.reportValidity());
        }

        if (endInput && typeof endInput.setCustomValidity === 'function') {
            let endMessage = '';
            if (!endValue) {
                endMessage = 'End Date Time is required.';
            } else if (startValue && new Date(endValue).getTime() < new Date(startValue).getTime()) {
                endMessage = 'End Date Time must be after Start Date Time.';
            }
            endInput.setCustomValidity(endMessage);
            valid = valid && (!showErrors || endInput.reportValidity());
        }

        return valid && (!startValue || !endValue || new Date(endValue).getTime() >= new Date(startValue).getTime());
    }

    hasRichTextContent(value) {
        return !!String(value || '').replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').trim();
    }

    stepFromResumePage(resumePage) {
        const pageMap = {
            RecordType: STEP_RECORD_TYPE,
            VisitDetails: STEP_VISIT_DETAIL,
            Visitors: STEP_VISITORS,
            VisitedParties: STEP_VISITED_PARTIES,
            ActionPlan: STEP_ACTION_PLAN,
            Tasks: STEP_TASK_LIST,
            Review: STEP_REVIEW
        };
        return pageMap[resumePage] || STEP_VISIT_DETAIL;
    }

    resumePageForStep(step) {
        const pageMap = {
            [STEP_RECORD_TYPE]: 'RecordType',
            [STEP_VISIT_DETAIL]: 'VisitDetails',
            [STEP_VISITORS]: 'Visitors',
            [STEP_VISITED_PARTIES]: 'VisitedParties',
            [STEP_ACTION_PLAN]: 'ActionPlan',
            [STEP_TASK_LIST]: 'Tasks',
            [STEP_REVIEW]: 'Review'
        };
        return pageMap[step] || 'VisitDetails';
    }

    mergeVisitFieldValues(fields) {
        return fields.map((field) => ({
            ...field,
            value: Object.prototype.hasOwnProperty.call(this.visitFormValues, field.apiName)
                ? this.visitFormValues[field.apiName]
                : field.value
        }));
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

    todayValue() {
        const now = new Date();
        const localDate = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
        return localDate.toISOString().slice(0, 10);
    }

    nowDateTimeValue() {
        return new Date().toISOString();
    }

    hasValue(value) {
        return value !== null && value !== undefined && value !== '' && (!Array.isArray(value) || value.length > 0);
    }

    getInputValue(input) {
        if (!input) {
            return null;
        }
        if (input.type === 'checkbox') {
            return input.checked;
        }
        return input.value;
    }

    recordFormFieldValue(fields, fieldName) {
        const field = fields?.[fieldName];
        if (field && Object.prototype.hasOwnProperty.call(field, 'value')) {
            return field.value;
        }
        return field;
    }

    resolveLaunchRecordId() {
        return this.findRecordId([this._recordId, this.recordId, window?.location?.href, document?.referrer]);
    }

    findRecordId(values) {
        const candidates = [];
        (values || []).forEach((value) => {
            if (!value) {
                return;
            }
            const stringValue = String(value);
            candidates.push(stringValue);
            try {
                candidates.push(decodeURIComponent(stringValue));
            } catch {
                // Some values are already decoded.
            }
        });
        return candidates.map((candidate) => {
            const match = candidate.match(/(?:001|0Z5)[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?/);
            return match ? match[0] : null;
        }).find((candidate) => !!candidate);
    }

    normalizeAccountId(value) {
        return this.normalizeRecordId(value, '001');
    }

    normalizeContactId(value) {
        return this.normalizeRecordId(value, '003');
    }

    recordIdentityKey(value) {
        const recordId = value ? String(value) : '';
        return recordId.length >= 15 ? recordId.substring(0, 15) : recordId;
    }

    uniqueContactIds(contacts = []) {
        const seen = new Set();
        const contactIds = [];
        (contacts || []).forEach((contact) => {
            const contactId = this.normalizeContactId(contact?.contactId);
            const key = this.recordIdentityKey(contactId);
            if (contactId && !seen.has(key)) {
                seen.add(key);
                contactIds.push(contactId);
            }
        });
        return contactIds;
    }

    uniqueContacts(contacts = []) {
        const seen = new Set();
        const unique = [];
        (contacts || []).forEach((contact) => {
            const contactId = this.normalizeContactId(contact?.contactId);
            const key = this.recordIdentityKey(contactId);
            if (contactId && !seen.has(key)) {
                seen.add(key);
                unique.push({ ...contact, contactId });
            }
        });
        return unique;
    }

    normalizeRecordId(value, prefix) {
        if (!value) {
            return null;
        }
        const match = String(value).match(new RegExp(`${prefix}[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?`));
        return match ? match[0] : null;
    }

    navigateToVisit(visitId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: visitId, objectApiName: 'Visit', actionName: 'view' }
        });
    }

    closeHostAction() {
        this.hostActionClosing = true;
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new CustomEvent('visitwizardclose', { bubbles: true, composed: true }));
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
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
