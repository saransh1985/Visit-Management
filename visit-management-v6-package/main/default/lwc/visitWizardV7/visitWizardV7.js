import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getFieldValue, getRecord, getRecordCreateDefaults, updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import USER_ID from '@salesforce/user/Id';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import ACTION_PLAN_NAME_FIELD from '@salesforce/schema/ActionPlan.Name';
import ACTION_PLAN_STATE_FIELD from '@salesforce/schema/ActionPlan.ActionPlanState';
import ACTION_PLAN_START_DATE_FIELD from '@salesforce/schema/ActionPlan.StartDate';
import ACTION_PLAN_TARGET_FIELD from '@salesforce/schema/ActionPlan.TargetId';
import ACTION_PLAN_TEMPLATE_VERSION_FIELD from '@salesforce/schema/ActionPlan.ActionPlanTemplateVersionId';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import USER_EMAIL_FIELD from '@salesforce/schema/User.Email';
import USER_TITLE_FIELD from '@salesforce/schema/User.Title';
import USER_ROLE_NAME_FIELD from '@salesforce/schema/User.UserRole.Name';
import VISIT_ACCOUNT_FIELD from '@salesforce/schema/Visit.AccountId';
import VISIT_NAME_FIELD from '@salesforce/schema/Visit.Name';
import VISIT_RECORD_TYPE_FIELD from '@salesforce/schema/Visit.RecordTypeId';
import VISIT_STATUS_FIELD from '@salesforce/schema/Visit.Status';

import getLaunchContext from '@salesforce/apex/VisitWizardV6Controller.getLaunchContext';
import getVisitFieldMetadata from '@salesforce/apex/VisitWizardV6Controller.getVisitFieldMetadata';
import getAccountInfo from '@salesforce/apex/VisitWizardV6Controller.getAccountInfo';
import searchAccounts from '@salesforce/apex/VisitWizardV7Controller.searchAccounts';
import searchAccountAddresses from '@salesforce/apex/VisitWizardV6Controller.searchAccountAddresses';
import getDefaultAccountAddress from '@salesforce/apex/VisitWizardV6Controller.getDefaultAccountAddress';
import getAddressInfo from '@salesforce/apex/VisitWizardV6Controller.getAddressInfo';
import getInitialVisitorCandidates from '@salesforce/apex/VisitWizardV6Controller.getInitialVisitorCandidates';
import searchUsers from '@salesforce/apex/VisitWizardV6Controller.searchUsers';
import getContactRecordTypeDescriptions from '@salesforce/apex/VisitWizardV6Controller.getContactRecordTypeDescriptions';
import searchContacts from '@salesforce/apex/VisitWizardV6Controller.searchContacts';
import saveForLater from '@salesforce/apex/VisitWizardV7Controller.saveForLater';
import saveVisitProgress from '@salesforce/apex/VisitWizardV7Controller.saveVisitProgress';
import saveTopicContext from '@salesforce/apex/VisitWizardV7Controller.saveTopicContext';
import getActionPlanStartInfo from '@salesforce/apex/VisitWizardV6Controller.getActionPlanStartInfo';
import getActionPlanTemplateOption from '@salesforce/apex/VisitWizardV6Controller.getActionPlanTemplateOption';
import searchActionPlanTemplates from '@salesforce/apex/VisitWizardV6Controller.searchActionPlanTemplates';
import saveActionPlanAndLoadTasks from '@salesforce/apex/VisitWizardV6Controller.saveActionPlanAndLoadTasks';
import getTaskList from '@salesforce/apex/VisitWizardV6Controller.getTaskList';
import startTask from '@salesforce/apex/VisitWizardV6Controller.startTask';
import saveTask from '@salesforce/apex/VisitWizardV6Controller.saveTask';
import getTaskDetail from '@salesforce/apex/VisitWizardV6Controller.getTaskDetail';
import getTaskNotes from '@salesforce/apex/VisitWizardV6Controller.getTaskNotes';
import saveTaskNote from '@salesforce/apex/VisitWizardV6Controller.saveTaskNote';
import linkUploadedTopicFiles from '@salesforce/apex/VisitWizardV6Controller.linkUploadedTopicFiles';
import deleteTopicUploadFile from '@salesforce/apex/VisitWizardV6Controller.deleteTopicUploadFile';
import deleteTopicFiles from '@salesforce/apex/VisitWizardV6Controller.deleteTopicFiles';
import getOpportunityDefaults from '@salesforce/apex/VisitWizardV6Controller.getOpportunityDefaults';
import addOpportunityProductsFromTopicContexts from '@salesforce/apex/VisitWizardV6Controller.addOpportunityProductsFromTopicContexts';
import createFollowUp from '@salesforce/apex/VisitWizardV6Controller.createFollowUp';
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
const ROW_ACTION_CREATE_OPPORTUNITY = 'create_opportunity';
const ROW_ACTION_SELECT_ACCOUNT = 'select_account';
const ROW_ACTION_SELECT_ADDRESS = 'select_address';
const ACCOUNT_CUSTOMER_NUMBER_FIELD = 'Customer_Account_Number__c';
const CONTACT_OBJECT_API_NAME = 'Contact';
const OPPORTUNITY_OBJECT_API_NAME = 'Opportunity';
const TASK_OBJECT_API_NAME = 'Task';
const VISIT_STATUS_DRAFT = 'Draft';
const VISIT_STATUS_DRAFT_PERSISTED = 'Planned';
const VISIT_STATUS_COMPLETED = 'Completed';
const ACTION_PLAN_STATUS_IN_PROGRESS = 'In Progress';
const TOPIC_STATUS_IN_PROGRESS = 'In Progress';
const TOPIC_STATUS_COMPLETED = 'Completed';
const OPPORTUNITY_VISIT_FIELD = 'Related_Visit__c';
const OPPORTUNITY_STAGE_INITIAL_NOTIFICATION = 'Initial Notification';
const ACTION_PLAN_NAME_PREFIX = 'Template - ';
const ACTION_PLAN_NAME_MAX_LENGTH = 255;
const VISIT_DETAIL_LOADING_MIN_MS = 700;
const HIDDEN_V7_VISIT_FIELDS = new Set(['VisitPriority', 'ContextId', 'Status']);

export default class VisitWizardV7 extends NavigationMixin(LightningElement) {
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
    @track actionPlanTemplateSearchResults = [];
    @track actionPlanStatusOptions = [];
    @track tasks = [];
    @track taskNotes = [];
    @track taskFiles = [];
    @track opportunities = [];
    @track contactLayoutSections = [];
    @track opportunityLayoutSections = [];
    @track contactRecordTypeDescriptions = {};
    @track newTopicFiles = [];
    @track followUpContacts = [];
    @track followUpContactSearchResults = [];

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
    actionPlanTemplateName = '';
    actionPlanTemplateSearchTerm = '';
    actionPlanTemplateSearchStarted = false;
    actionPlanTemplateSearching = false;
    actionPlanStatus;
    actionPlanTargetRecordId;
    createActionPlan = false;
    requiredTasksComplete = false;
    activeTask;
    taskNoteTitle = '';
    taskNoteBody = '';
    opportunityDefaults;
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
    showFollowUpModal = false;
    showFollowUpContactSearch = false;
    opportunityDefaultsLoading = false;
    opportunityLayoutLoading = false;
    accountSearchTerm = '';
    addressSearchTerm = '';
    userSearchTerm = '';
    contactSearchTerm = '';
    followUpContactSearchTerm = '';
    followUpOwnerId = USER_ID;
    followUpSubject = 'Follow up';
    followUpDueDate;
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
    actionPlanTemplateSearchTimer;
    newTopicSaveMode = 'close';
    visitDetailLoadingStartedAt = 0;
    visitDetailLoadingTimer;
    taskFileIdsPendingDelete = [];
    currentUserCandidate = {
        userId: USER_ID,
        name: 'Current User',
        email: '',
        title: '',
        source: 'Current User',
        selected: true,
        locked: true
    };
    _recordId;

    accountNameFields = [ACCOUNT_NAME_FIELD];
    accountCanFields = [ACCOUNT_CUSTOMER_NUMBER_FIELD];
    visitStatusOptions = [
        { label: VISIT_STATUS_DRAFT, value: VISIT_STATUS_DRAFT },
        { label: VISIT_STATUS_COMPLETED, value: VISIT_STATUS_COMPLETED }
    ];
    actionPlanReviewFields = [
        ACTION_PLAN_NAME_FIELD,
        ACTION_PLAN_STATE_FIELD,
        ACTION_PLAN_START_DATE_FIELD,
        ACTION_PLAN_TARGET_FIELD,
        ACTION_PLAN_TEMPLATE_VERSION_FIELD
    ];
    visitNameFields = [VISIT_NAME_FIELD];
    visitReviewFields = [VISIT_NAME_FIELD, VISIT_ACCOUNT_FIELD, VISIT_STATUS_FIELD, VISIT_RECORD_TYPE_FIELD];
    opportunityObjectApiName = OPPORTUNITY_OBJECT_API_NAME;
    taskObjectApiName = TASK_OBJECT_API_NAME;
    topicContextFilter = {
        criteria: [
            {
                fieldPath: 'IsActive',
                operator: 'eq',
                value: true
            }
        ]
    };
    topicContextDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['ProductCode']
    };
    topicContextMatchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: 'ProductCode' }]
    };

    visitorCandidateColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Title', fieldName: 'title' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Source', fieldName: 'source' }
    ];
    selectedVisitorColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Role', fieldName: 'role' },
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
        { label: 'Dealer Code', fieldName: 'dealerCode' },
        { label: 'Primary CAN', fieldName: 'primaryCanChecked', type: 'boolean', fixedWidth: 132 },
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
    followUpContactColumns = [
        { label: 'Name', fieldName: 'name', wrapText: true },
        { label: 'Title', fieldName: 'title', wrapText: true },
        { label: 'Email', fieldName: 'email', type: 'email', wrapText: true },
        { label: 'Phone', fieldName: 'phone', type: 'phone', wrapText: true },
        { type: 'button-icon', fixedWidth: 56, typeAttributes: { iconName: 'utility:delete', name: ROW_ACTION_REMOVE, title: 'Remove' } }
    ];
    recentActionPlanTemplateColumns = [
        { label: 'Name', fieldName: 'name' },
        { label: 'Type', fieldName: 'actionPlanType' },
        { label: 'Version', fieldName: 'versionNumber', type: 'number' },
        { label: 'Last Modified', fieldName: 'lastModifiedDate', type: 'date' },
        { type: 'button', fixedWidth: 96, typeAttributes: { label: 'Select', name: ROW_ACTION_SELECT_TEMPLATE, variant: 'base' } }
    ];
    topicTreeColumns = [
        { label: 'Topic / Context', fieldName: 'name', type: 'text', wrapText: true },
        { label: 'Status', fieldName: 'displayStatus' },
        { label: 'Required', fieldName: 'requiredLabel' },
        { label: 'Completed', fieldName: 'completedLabel' },
        {
            label: 'Actions',
            type: 'button',
            fixedWidth: 120,
            typeAttributes: {
                label: { fieldName: 'topicActionLabel' },
                name: ROW_ACTION_START_TASK,
                variant: 'neutral',
                disabled: { fieldName: 'topicActionDisabled' }
            }
        }
    ];
    reviewTaskColumns = [
        { label: 'Topic', fieldName: 'name', wrapText: true },
        { label: 'Status', fieldName: 'displayStatus' },
        { label: 'Required', fieldName: 'requiredLabel' },
        { label: 'Completed', fieldName: 'completedLabel' }
    ];
    reviewTopicTreeColumns = [
        { label: 'Topic / Product Context', fieldName: 'name', type: 'text', wrapText: true },
        { label: 'Status', fieldName: 'displayStatus' },
        { label: 'Required', fieldName: 'requiredLabel' },
        { label: 'Completed', fieldName: 'completedLabel' }
    ];
    reviewVisitorColumns = [
        { label: 'Name', fieldName: 'name', wrapText: true },
        { label: 'Email', fieldName: 'email', type: 'email', wrapText: true },
        { label: 'Role', fieldName: 'role', wrapText: true }
    ];
    reviewContactColumns = [
        { label: 'Name', fieldName: 'name', wrapText: true },
        { label: 'Title', fieldName: 'title', wrapText: true },
        { label: 'Email', fieldName: 'email', type: 'email', wrapText: true },
        { label: 'Phone', fieldName: 'phone', type: 'phone', wrapText: true }
    ];
    opportunityColumns = [
        { label: 'Name', fieldName: 'name', wrapText: true },
        { label: 'Stage', fieldName: 'stageName' },
        { label: 'Close Date', fieldName: 'closeDate', type: 'date' },
        { label: 'Amount', fieldName: 'amount', type: 'currency' },
        { label: 'Products', fieldName: 'productNames', wrapText: true }
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

    @wire(getObjectInfo, { objectApiName: OPPORTUNITY_OBJECT_API_NAME })
    opportunityObjectInfo;

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

    @wire(getRecordCreateDefaults, {
        objectApiName: OPPORTUNITY_OBJECT_API_NAME,
        recordTypeId: '$opportunityCreateDefaultsRecordTypeId'
    })
    setOpportunityCreateDefaults({ data, error }) {
        if (!this.showOpportunityModal) {
            return;
        }
        this.opportunityLayoutLoading = false;
        if (data) {
            this.opportunityLayoutSections = this.buildOpportunityLayoutSections(data);
        } else if (error) {
            this.opportunityLayoutSections = this.fallbackOpportunityLayoutSections();
            this.handleError(error);
        }
    }

    @wire(getContactRecordTypeDescriptions)
    setContactRecordTypeDescriptions({ data }) {
        this.contactRecordTypeDescriptions = data || {};
    }

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD, USER_EMAIL_FIELD, USER_TITLE_FIELD, USER_ROLE_NAME_FIELD] })
    setCurrentUserRecord({ data }) {
        if (!data) {
            this.ensureCurrentUserAttendee();
            return;
        }
        this.currentUserCandidate = {
            userId: USER_ID,
            name: data.fields.Name?.value || 'Current User',
            email: data.fields.Email?.value || '',
            title: data.fields.Title?.value || '',
            role: getFieldValue(data, USER_ROLE_NAME_FIELD) || '',
            source: 'Current User',
            selected: true,
            locked: true
        };
        this.ensureCurrentUserAttendee();
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
        window.clearTimeout(this.actionPlanTemplateSearchTimer);
        window.clearTimeout(this.visitDetailLoadingTimer);
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
        if (!modalContainer) {
            return;
        }

        modalContainer.dataset.visitWizardV7Sized = 'compact';
        modalContainer.style.width = 'min(92vw, 84rem)';
        modalContainer.style.maxWidth = 'min(92vw, 84rem)';
        modalContainer.style.minWidth = 'min(58rem, 92vw)';
    }

    get panelHeader() {
        return this.launchMode === 'EDIT' ? 'Edit Visit' : 'New Visit';
    }

    get isBusy() {
        return this.loading || this.visitDetailLoading;
    }

    get showGlobalSpinner() {
        return this.loading;
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
        return [STEP_VISIT_DETAIL, STEP_VISITORS].includes(this.step) && this.canEdit;
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

    get visitStatusValue() {
        return this.visitFormValues.Status || this.visitStatus || VISIT_STATUS_DRAFT;
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

    get recordTypeButtonOptions() {
        return this.recordTypeOptions.map((recordType) => ({
            ...recordType,
            className: recordType.value === this.selectedRecordTypeId
                ? 'visit-record-type-button selected'
                : 'visit-record-type-button'
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

    get selectedVisitRecordType() {
        return this.recordTypes.find((type) => type.value === this.selectedRecordTypeId);
    }

    get opportunityRecordTypeId() {
        const selectedRecordType = this.selectedVisitRecordType;
        const recordTypeInfos = this.opportunityObjectInfo?.data?.recordTypeInfos || {};
        if (!selectedRecordType || !Object.keys(recordTypeInfos).length) {
            return null;
        }
        const selectedDeveloperName = selectedRecordType.developerName;
        const selectedLabel = selectedRecordType.label;
        const matchingRecordType = Object.values(recordTypeInfos).find(
            (recordTypeInfo) =>
                recordTypeInfo.available &&
                !recordTypeInfo.master &&
                (recordTypeInfo.developerName === selectedDeveloperName || recordTypeInfo.name === selectedLabel)
        );
        return matchingRecordType?.recordTypeId || null;
    }

    get opportunityRecordTypeLoading() {
        return (
            this.showOpportunityModal &&
            (
                this.opportunityDefaultsLoading ||
                (this.opportunityLayoutLoading && !!this.opportunityRecordTypeId) ||
                (!this.opportunityObjectInfo?.data && !this.opportunityObjectInfo?.error)
            )
        );
    }

    get showOpportunityRecordForm() {
        return (
            this.showOpportunityModal &&
            !this.opportunityDefaultsLoading &&
            !this.opportunityLayoutLoading &&
            !!this.opportunityRecordTypeId &&
            this.hasOpportunityLayoutSections &&
            !this.opportunityObjectInfo?.error
        );
    }

    get opportunityRecordTypeError() {
        if (this.opportunityObjectInfo?.error) {
            return 'Opportunity metadata could not be loaded. Ask your Salesforce admin to check Opportunity access.';
        }
        if (this.opportunityObjectInfo?.data && !this.opportunityRecordTypeId) {
            const visitRecordTypeName = this.selectedVisitRecordType?.label || 'the selected Visit record type';
            return `No available Opportunity record type matches ${visitRecordTypeName}.`;
        }
        return null;
    }

    get opportunityCreateDefaultsRecordTypeId() {
        return this.showOpportunityModal && this.opportunityRecordTypeId ? this.opportunityRecordTypeId : undefined;
    }

    get hasOpportunityLayoutSections() {
        return this.opportunityLayoutSections.some((section) => section.rows.some((row) => row.fields.length > 0));
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

    get hasActionPlanTemplateSearchResults() {
        return this.actionPlanTemplateSearchResults.length > 0;
    }

    get showActionPlanTemplateNoResults() {
        return this.actionPlanTemplateSearchStarted &&
            !this.actionPlanTemplateSearching &&
            !this.hasActionPlanTemplateSearchResults;
    }

    get actionPlanTemplateSearchHelpText() {
        return this.actionPlanTemplateVersionId
            ? 'Selected Meeting Template'
            : 'Search published Visit Meeting Templates by name.';
    }

    get hasTasks() {
        return this.tasks.length > 0;
    }

    get topicTreeRows() {
        return (this.tasks || []).map((task) => {
            const children = (task.topicContexts || []).map((context, index) => ({
                treeRowKey: `${task.taskRowKey || task.genericTaskId}-context-${context.contextId || index}`,
                rowType: 'context',
                name: context.productName || context.contextName || 'Context',
                displayStatus: '',
                requiredLabel: '',
                completedLabel: '',
                topicActionLabel: '',
                topicActionDisabled: true
            }));
            const row = {
                ...task,
                treeRowKey: task.taskRowKey,
                rowType: 'topic',
                topicActionLabel: task.taskActionLabel,
                topicActionDisabled: false
            };
            if (children.length) {
                row._children = children;
            }
            return row;
        });
    }

    get reviewTopicTreeRows() {
        return (this.tasks || []).map((task) => {
            const children = (task.topicContexts || []).map((context, index) => ({
                treeRowKey: `${task.taskRowKey || task.genericTaskId}-review-context-${context.contextId || index}`,
                rowType: 'context',
                name: context.productName || context.contextName || 'Product Context',
                displayStatus: '',
                requiredLabel: '',
                completedLabel: ''
            }));
            const row = {
                treeRowKey: `${task.taskRowKey || task.genericTaskId}-review`,
                rowType: 'topic',
                name: task.name,
                displayStatus: task.displayStatus,
                requiredLabel: task.requiredLabel,
                completedLabel: task.completedLabel
            };
            if (children.length) {
                row._children = children;
            }
            return row;
        });
    }

    get createOpportunityFromTopicsDisabled() {
        return this.isBusy || !this.createdVisitId || !this.hasTasks;
    }

    get createFollowUpDisabled() {
        return this.isBusy || !this.createdVisitId;
    }

    get createdVisitLabel() {
        return this.createdVisitName || this.createdVisitId || '';
    }

    get followUpContactIds() {
        return this.uniqueContactIds(this.followUpContacts);
    }

    get hasFollowUpContacts() {
        return this.followUpContacts.length > 0;
    }

    get hasFollowUpContactSearchResults() {
        return this.followUpContactSearchResults.length > 0;
    }

    get hasOpportunities() {
        return this.opportunities.length > 0;
    }

    get hasTaskNotes() {
        return this.taskNotes.length > 0;
    }

    get hasTaskFiles() {
        return this.taskFiles.length > 0;
    }

    get activeTaskIsSales() {
        return this.activeTask?.salesTask;
    }

    get activeTaskIsManual() {
        return this.isManualTopic(this.activeTask);
    }

    get activeTaskNameDisabled() {
        return this.isBusy || !this.activeTaskIsManual;
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

    get taskFileUploadDisabled() {
        return this.isBusy || !this.activeTask?.genericTaskId;
    }

    get hasNewTopicFiles() {
        return this.newTopicFiles.length > 0;
    }

    get topicUploadDisabled() {
        return this.isBusy || !this.createdVisitId;
    }

    get selectedVisitorIds() {
        return this.selectedVisitors.map((visitor) => visitor.userId).filter(Boolean);
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
            { value: STEP_VISITORS, label: 'Attendees' },
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
        this.visitStatus = context?.visitStatus || VISIT_STATUS_DRAFT;
        this.recordTypes = context?.recordTypes || [];
        this.createdVisitId = context?.visitId;
        this.createdVisitName = context?.visitName;
        this.accountId = context?.accountId;
        this.accountName = context?.accountName;
        this.selectedRecordTypeId = context?.recordTypeId;
        this.visitFormValues = { ...(context?.visitValues || {}) };
        if (!this.completed) {
            this.applyDraftVisitStatus();
        }
        this.visitorCandidates = [];
        this.selectedVisitors = this.uniqueVisitors(this.launchMode === 'NEW' ? [] : (context?.selectedVisitors || []));
        this.ensureCurrentUserAttendee();
        this.selectedContacts = this.uniqueContacts(context?.selectedContacts || []);
        this.actionPlanId = null;
        this.actionPlanName = '';
        this.actionPlanStartDate = this.todayValue();
        this.actionPlanTemplateVersionId = null;
        this.actionPlanTemplateName = '';
        this.actionPlanTemplateSearchTerm = '';
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
        if (!this.actionPlanTemplateSearchTerm && this.actionPlanTemplateName) {
            this.actionPlanTemplateSearchTerm = this.actionPlanTemplateName;
        }

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
        if (this.step === STEP_VISITED_PARTIES) {
            this.step = STEP_VISITORS;
        }
        if (this.step === STEP_ACTION_PLAN) {
            this.step = STEP_TASK_LIST;
            if (this.createdVisitId) {
                await this.loadTaskList(null);
            }
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
        this.startVisitDetailLoading();
        this.errorMessage = null;
        try {
            const fields = await getVisitFieldMetadata({ recordTypeId });
            this.rememberHiddenVisitFieldDefaults(fields || []);
            this.visitFields = this.mergeVisitFieldValues((fields || []).filter((field) => !HIDDEN_V7_VISIT_FIELDS.has(field.apiName)));
            if (!this.visitFields.length) {
                this.finishVisitDetailLoading();
            }
        } catch (error) {
            this.clearVisitDetailLoading();
            this.handleError(error);
        }
    }

    handleVisitFormLoad() {
        this.finishVisitDetailLoading();
        Promise.resolve().then(() => this.applyStoredVisitValues());
    }

    startVisitDetailLoading() {
        window.clearTimeout(this.visitDetailLoadingTimer);
        this.visitDetailLoadingStartedAt = Date.now();
        this.visitDetailLoading = true;
    }

    finishVisitDetailLoading() {
        const elapsed = Date.now() - (this.visitDetailLoadingStartedAt || Date.now());
        const remaining = Math.max(0, VISIT_DETAIL_LOADING_MIN_MS - elapsed);
        window.clearTimeout(this.visitDetailLoadingTimer);
        if (remaining === 0) {
            this.visitDetailLoading = false;
            this.visitDetailLoadingTimer = undefined;
            return;
        }
        this.visitDetailLoadingTimer = window.setTimeout(() => {
            this.visitDetailLoading = false;
            this.visitDetailLoadingTimer = undefined;
        }, remaining);
    }

    clearVisitDetailLoading() {
        window.clearTimeout(this.visitDetailLoadingTimer);
        this.visitDetailLoading = false;
        this.visitDetailLoadingTimer = undefined;
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
            const results = await searchAccounts({ searchTerm: this.accountSearchTerm });
            this.accountSearchResults = (results || []).map((account) => ({
                ...account,
                primaryCanChecked: this.toBoolean(account.primaryCan)
            }));
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

    async handleVisitorNext() {
        this.ensureCurrentUserAttendee();
        if (!this.selectedVisitors.length) {
            this.showToast('Attendees Required', 'Select at least one attendee before continuing.', 'error');
            return;
        }
        if (!this.selectedContacts.length) {
            this.showToast('Dealer / Customer Contacts Required', 'Add at least one dealer or customer contact before continuing.', 'error');
            return;
        }
        const response = await this.persistProgress('Tasks', false, true);
        if (response?.visitId) {
            await this.loadTaskList(null);
        }
    }

    async handleVisitedPartyNext() {
        await this.handleVisitorNext();
    }

    handlePrevious() {
        this.captureVisitFormValues(false);
        if (this.step === STEP_VISIT_DETAIL && this.showRecordTypePage) {
            this.step = STEP_RECORD_TYPE;
            return;
        }
        if (this.step === STEP_ACTION_PLAN) {
            this.step = STEP_VISITORS;
            return;
        }
        if (this.step === STEP_TASK_LIST) {
            this.step = STEP_VISITORS;
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
            this.showToast('Saved as Draft', 'Visit saved as Draft.', 'success');
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
                Status: VISIT_STATUS_DRAFT_PERSISTED
            },
            visitorUserIds: this.selectedVisitorIds,
            visitedContactIds: this.selectedContactIds,
            resumePage,
            stateJson: this.serializedState(),
            actionPlanId: null,
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

    handleActionPlanTemplateSearchInput(event) {
        const searchTerm = this.getInputValue(event.target);
        this.actionPlanTemplateSearchTerm = searchTerm;
        if (this.actionPlanTemplateName && searchTerm !== this.actionPlanTemplateName) {
            this.clearActionPlanTemplateSelection(true);
        }
        this.validateActionPlanTemplateSelection(false);
        window.clearTimeout(this.actionPlanTemplateSearchTimer);

        const normalizedTerm = (searchTerm || '').trim();
        if (normalizedTerm.length < 2) {
            this.actionPlanTemplateSearchResults = [];
            this.actionPlanTemplateSearchStarted = normalizedTerm.length > 0;
            this.actionPlanTemplateSearching = false;
            return;
        }

        this.actionPlanTemplateSearching = true;
        this.actionPlanTemplateSearchTimer = window.setTimeout(() => {
            this.runActionPlanTemplateSearch(normalizedTerm);
        }, 300);
    }

    async runActionPlanTemplateSearch(searchTerm) {
        const normalizedTerm = (searchTerm || '').trim();
        if (normalizedTerm.length < 2) {
            this.actionPlanTemplateSearching = false;
            return;
        }
        try {
            const results = await searchActionPlanTemplates({ searchTerm: normalizedTerm });
            if ((this.actionPlanTemplateSearchTerm || '').trim() === normalizedTerm) {
                this.actionPlanTemplateSearchResults = results || [];
                this.actionPlanTemplateSearchStarted = true;
            }
        } catch (error) {
            this.actionPlanTemplateSearchResults = [];
            this.handleError(error);
        } finally {
            if ((this.actionPlanTemplateSearchTerm || '').trim() === normalizedTerm) {
                this.actionPlanTemplateSearching = false;
            }
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

    async handleActionPlanTemplateSearchRowAction(event) {
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
        this.actionPlanTemplateName = template.templateName || template.name || '';
        this.actionPlanTemplateSearchTerm = this.actionPlanTemplateName;
        this.actionPlanName = this.actionPlanNameForTemplate(this.actionPlanTemplateName);
        this.actionPlanTemplateSearchResults = [];
        this.actionPlanTemplateSearchStarted = false;
        this.actionPlanTemplateSearching = false;
        this.validateActionPlanTemplateSelection(false);
    }

    clearActionPlanTemplateSelection(preserveSearchTerm) {
        this.actionPlanTemplateVersionId = null;
        this.actionPlanTemplateName = '';
        this.actionPlanName = '';
        if (!preserveSearchTerm) {
            this.actionPlanTemplateSearchTerm = '';
        }
    }

    actionPlanNameForTemplate(templateName) {
        const name = `${ACTION_PLAN_NAME_PREFIX}${templateName || ''}`;
        if (name.length <= ACTION_PLAN_NAME_MAX_LENGTH) {
            return name;
        }
        return `${name.slice(0, ACTION_PLAN_NAME_MAX_LENGTH - 2)}..`;
    }

    templateNameFromActionPlanName(actionPlanName) {
        if (!actionPlanName || !actionPlanName.startsWith(ACTION_PLAN_NAME_PREFIX)) {
            return '';
        }
        return actionPlanName.slice(ACTION_PLAN_NAME_PREFIX.length);
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
        this.actionPlanId = null;
        this.loading = true;
        try {
            const response = this.createdVisitId
                ? await getTaskList({ visitId: this.createdVisitId, actionPlanId })
                : { tasks: [], requiredTasksComplete: true };
            this.tasks = this.decorateTasks(response?.tasks || []);
            this.requiredTasksComplete = response?.requiredTasksComplete !== false;
            this.step = STEP_TASK_LIST;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
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
            status: TOPIC_STATUS_IN_PROGRESS,
            description: '',
            required: false,
            startDateTime: this.nowDateTimeValue(),
            endDateTime: null,
            definitionReferenceId: null,
            topicContextProductId: null,
            sequence: this.nextTopicSequenceValue(),
            noteTitle: '',
            noteBody: ''
        };
        this.newTopicFiles = [];
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

    handleNewTopicContextChange(event) {
        this.newTopicForm = {
            ...this.newTopicForm,
            topicContextProductId: event.detail?.recordId || event.detail?.value || null
        };
    }

    setNewTopicSaveMode(event) {
        this.newTopicSaveMode = event.target?.dataset?.saveMode || 'close';
    }

    handleNewTopicSave(event) {
        this.setNewTopicSaveMode(event);
        if (!this.createdVisitId) {
            this.showToast('Visit Required', 'Create or save the Visit before adding a Topic.', 'error');
            return;
        }

        const form = this.template.querySelector('[data-new-topic-form]');
        const { fields, isValid } = this.collectNewTopicFormFields(true);
        if (!form || !isValid) {
            return;
        }

        fields.VisitId = this.createdVisitId;
        fields.Status = TOPIC_STATUS_COMPLETED;
        if (!this.hasValue(fields.Sequence) && this.hasValue(this.newTopicForm.sequence)) {
            fields.Sequence = Number(this.newTopicForm.sequence);
        }
        if (!this.hasValue(fields.IsRequired)) {
            fields.IsRequired = Boolean(this.newTopicForm.required);
        }

        this.loading = true;
        form.submit(fields);
    }

    collectNewTopicFormFields(validate) {
        const fields = {};
        const draft = { ...this.newTopicForm };
        let isValid = true;
        const inputs = this.template.querySelectorAll('[data-new-topic-form] lightning-input-field[data-field]');
        const apiNameByDraftName = {
            name: 'Name',
            status: 'Status',
            startDateTime: 'StartDateTime',
            endDateTime: 'EndDateTime',
            definitionReferenceId: 'DefinitionReferenceId',
            required: 'IsRequired',
            description: 'Description'
        };
        inputs.forEach((input) => {
            const draftName = input.dataset.field;
            const apiName = input.fieldName || input.getAttribute('field-name') || apiNameByDraftName[draftName];
            const fieldValue = this.getInputValue(input);
            if (apiName) {
                fields[apiName] = fieldValue;
            }
            if (draftName) {
                draft[draftName] = fieldValue;
            }
            if (validate && typeof input.reportValidity === 'function') {
                isValid = input.reportValidity() && isValid;
            }
        });
        this.newTopicForm = draft;
        return { fields, isValid };
    }

    handleNewTopicUploadFinished(event) {
        const uploadedFiles = (event.detail?.files || []).map((file) => ({
            key: file.documentId,
            contentDocumentId: file.documentId,
            fileName: file.name
        }));
        this.newTopicFiles = this.uniqueTopicFiles([...this.newTopicFiles, ...uploadedFiles]);
    }

    async handleRemoveNewTopicFile(event) {
        const fileKey = event.currentTarget?.dataset?.fileKey;
        const fileToRemove = this.newTopicFiles.find((file) => file.key === fileKey);
        if (!fileToRemove) {
            return;
        }
        const previousFiles = [...this.newTopicFiles];
        this.newTopicFiles = this.newTopicFiles.filter((file) => file.key !== fileKey);
        if (!fileToRemove.contentDocumentId) {
            return;
        }
        try {
            await deleteTopicUploadFile({
                requestJson: JSON.stringify({
                    contentDocumentId: fileToRemove.contentDocumentId,
                    temporaryLinkedEntityId: this.createdVisitId
                })
            });
        } catch (error) {
            this.newTopicFiles = previousFiles;
            this.handleError(error);
        }
    }

    handleNewTopicSubmit(event) {
        event.preventDefault();
        if (!this.createdVisitId) {
            this.showToast('Visit Required', 'Create or save the Visit before adding a Topic.', 'error');
            return;
        }

        const fields = { ...(event.detail?.fields || {}) };
        fields.VisitId = this.createdVisitId;
        fields.Status = TOPIC_STATUS_COMPLETED;
        if (!this.hasValue(fields.Sequence) && this.hasValue(this.newTopicForm.sequence)) {
            fields.Sequence = Number(this.newTopicForm.sequence);
        }
        if (!this.hasValue(fields.IsRequired)) {
            fields.IsRequired = Boolean(this.newTopicForm.required);
        }

        this.loading = true;
        event.target.submit(fields);
    }

    async handleNewTopicSuccess(event) {
        try {
            const topicId = event.detail?.id;
            const contextSaved = await this.saveNewTopicContext(topicId);
            const noteSaved = await this.saveNewTopicNote(topicId);
            const fileResult = await this.saveNewTopicFiles(topicId);
            const response = await getTaskList({
                visitId: this.createdVisitId,
                actionPlanId: this.actionPlanId
            });
            this.actionPlanId = response?.actionPlanId || this.actionPlanId;
            this.tasks = this.decorateTasks(response?.tasks || []);
            this.requiredTasksComplete = Boolean(response?.requiredTasksComplete);
            this.showToast('Topic Created', this.newTopicSuccessMessage(noteSaved, fileResult, contextSaved), fileResult.failed ? 'warning' : 'success');
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

    async saveNewTopicContext(genericTaskId) {
        if (!genericTaskId || !this.newTopicForm.topicContextProductId) {
            return false;
        }
        await saveTopicContext({
            requestJson: JSON.stringify({
                genericTaskId,
                productId: this.newTopicForm.topicContextProductId
            })
        });
        return true;
    }

    async saveNewTopicNote(genericTaskId) {
        if (!genericTaskId || !this.hasRichTextContent(this.newTopicForm.noteBody)) {
            return false;
        }
        try {
            await saveTaskNote({
                requestJson: JSON.stringify({
                    genericTaskId,
                    title: this.newTopicForm.noteTitle || `${this.newTopicForm.name || 'Visit Topic'} Note`,
                    body: this.newTopicForm.noteBody
                })
            });
            return true;
        } catch (error) {
            this.handleError(error);
            return false;
        }
    }

    async saveNewTopicFiles(genericTaskId) {
        if (!genericTaskId || !this.newTopicFiles.length) {
            return { count: 0, failed: false };
        }
        try {
            const count = await linkUploadedTopicFiles({
                requestJson: JSON.stringify({
                    genericTaskId,
                    temporaryLinkedEntityId: this.createdVisitId,
                    visitorUserIds: this.selectedVisitorIds,
                    contentDocumentIds: this.newTopicFiles.map((file) => file.contentDocumentId).filter(Boolean)
                })
            });
            return { count: Number(count) || 0, failed: false };
        } catch (error) {
            this.handleError(error);
            return { count: 0, failed: true };
        }
    }

    newTopicSuccessMessage(noteSaved, fileResult = { count: 0, failed: false }, contextSaved = false) {
        if (fileResult.failed) {
            return 'Topic added, but one or more files could not be uploaded.';
        }
        const details = [];
        if (contextSaved) {
            details.push('context');
        }
        if (noteSaved) {
            details.push('note');
        }
        if (fileResult.count) {
            details.push(`${fileResult.count} file${fileResult.count === 1 ? '' : 's'}`);
        }
        return details.length ? `Topic and ${details.join(' and ')} added to this Visit.` : 'Topic added to this Visit.';
    }

    handleTaskRowAction(event) {
        if (event.detail?.action?.name === ROW_ACTION_START_TASK) {
            const row = event.detail.row;
            if (row?.rowType !== 'context') {
                this.openTask(row);
            }
        }
    }

    handleTaskButtonClick(event) {
        this.openTask(this.findTaskByRowKey(event.currentTarget.dataset.taskKey));
    }

    handleCreateOpportunityFromTask(event) {
        this.openOpportunityForTask(this.findTaskByRowKey(event.currentTarget.dataset.taskKey));
    }

    handleCreateOpportunityFromTopicHeader() {
        if (!this.createdVisitId) {
            this.showToast('Visit Required', 'Create or save the Visit before creating an Opportunity.', 'error');
            return;
        }
        if (!this.hasTasks) {
            this.showToast('Topic Required', 'Create at least one Topic before creating an Opportunity.', 'error');
            return;
        }
        this.openOpportunityModal();
    }

    openFollowUpModal() {
        if (!this.createdVisitId) {
            this.showToast('Visit Required', 'Create or save the Visit before creating a follow up.', 'error');
            return;
        }
        this.followUpOwnerId = USER_ID;
        this.followUpSubject = 'Follow up';
        this.followUpDueDate = null;
        this.followUpContacts = this.uniqueContacts(this.selectedContacts);
        this.followUpContactSearchTerm = '';
        this.followUpContactSearchResults = [];
        this.showFollowUpContactSearch = false;
        this.showFollowUpModal = true;
    }

    closeFollowUpModal() {
        this.showFollowUpModal = false;
        this.showFollowUpContactSearch = false;
        this.followUpContactSearchResults = [];
    }

    toggleFollowUpContactSearch() {
        this.showFollowUpContactSearch = !this.showFollowUpContactSearch;
        if (!this.showFollowUpContactSearch) {
            this.followUpContactSearchResults = [];
        }
    }

    handleFollowUpContactSearchTermChange(event) {
        this.followUpContactSearchTerm = event.target.value;
    }

    handleFollowUpContactSearchKeyup(event) {
        if (event.key === 'Enter') {
            this.runFollowUpContactSearch();
        }
    }

    async runFollowUpContactSearch() {
        const accountId = this.resolveAccountId();
        if (!accountId) {
            this.showToast('Account Required', 'Select an Account before adding contacts to the follow up.', 'error');
            return;
        }
        this.loading = true;
        try {
            this.followUpContactSearchResults = await searchContacts({
                accountId,
                searchTerm: this.followUpContactSearchTerm,
                excludedContactIds: this.followUpContactIds
            });
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleFollowUpContactSearchRowAction(event) {
        if (event.detail?.action?.name !== ROW_ACTION_ADD) {
            return;
        }
        const contact = event.detail.row;
        const contactId = this.normalizeContactId(contact?.contactId);
        if (!contactId) {
            return;
        }
        this.followUpContacts = this.uniqueContacts([...this.followUpContacts, { ...contact, contactId }]);
        this.followUpContactSearchResults = this.followUpContactSearchResults.filter(
            (candidate) => this.recordIdentityKey(candidate.contactId) !== this.recordIdentityKey(contactId)
        );
    }

    handleFollowUpContactRowAction(event) {
        if (event.detail?.action?.name !== ROW_ACTION_REMOVE) {
            return;
        }
        const removedKey = this.recordIdentityKey(this.normalizeContactId(event.detail.row?.contactId));
        this.followUpContacts = this.uniqueContacts(
            this.followUpContacts.filter((contact) => this.recordIdentityKey(contact.contactId) !== removedKey)
        );
    }

    async handleFollowUpFormSubmit(event) {
        event.preventDefault();
        const fields = { ...event.detail.fields };
        const ownerId = fields.OwnerId || this.followUpOwnerId || USER_ID;
        const subject = (fields.Subject || this.followUpSubject || 'Follow up').trim();
        const dueDate = fields.ActivityDate || this.followUpDueDate;
        if (!this.createdVisitId) {
            this.showToast('Visit Required', 'Create or save the Visit before creating a follow up.', 'error');
            return;
        }
        if (!dueDate) {
            this.showToast('Due Date Required', 'Enter a due date before creating the follow up.', 'error');
            return;
        }
        if (!this.followUpContactIds.length) {
            this.showToast('Contact Required', 'Add at least one dealer or customer contact to the follow up.', 'error');
            return;
        }
        this.loading = true;
        try {
            const result = await createFollowUp({
                requestJson: JSON.stringify({
                    visitId: this.createdVisitId,
                    ownerId,
                    subject,
                    dueDate,
                    contactIds: this.followUpContactIds
                })
            });
            this.showToast('Follow up Created', result?.message || 'Task and calendar activity were created.', 'success');
            this.closeFollowUpModal();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    openOpportunityForTask() {
        this.handleCreateOpportunityFromTopicHeader();
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
            const refreshedTask = this.tasks.find((task) => task.genericTaskId === taskRow.genericTaskId) || taskRow;
            const taskDetail = refreshedTask?.genericTaskId
                ? await getTaskDetail({ genericTaskId: refreshedTask.genericTaskId })
                : {};
            const hydratedTask = this.decorateTasks([
                {
                    ...refreshedTask,
                    ...(taskDetail?.task || {}),
                    actionPlanItemId: refreshedTask.actionPlanItemId,
                    itemState: refreshedTask.itemState,
                    required: Object.prototype.hasOwnProperty.call(taskDetail?.task || {}, 'required')
                        ? taskDetail.task.required
                        : refreshedTask.required
                }
            ])[0];
            this.activeTask = this.applyTaskDefaults(hydratedTask || refreshedTask);
            this.taskNoteTitle = `${this.activeTask?.name || 'Visit Topic'} Note`;
            this.taskNoteBody = '';
            this.taskNotes = taskDetail?.notes || [];
            this.taskFiles = this.decorateTopicFiles(taskDetail?.files || []);
            this.taskFileIdsPendingDelete = [];
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

    handleTaskContextChange(event) {
        if (!this.activeTask) {
            return;
        }
        this.activeTask = {
            ...this.activeTask,
            topicContextProductId: event.detail?.recordId || event.detail?.value || null
        };
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

    async refreshActiveTaskFiles() {
        if (!this.activeTask?.genericTaskId) {
            this.taskFiles = [];
            return;
        }
        const detail = await getTaskDetail({ genericTaskId: this.activeTask.genericTaskId });
        this.taskFiles = this.decorateTopicFiles(detail?.files || []);
    }

    async handleTaskNoteSave() {
        await this.savePendingTaskNote();
    }

    async handleTaskUploadFinished(event) {
        if (!this.activeTask?.genericTaskId) {
            return;
        }
        const uploadedDocumentIds = (event.detail?.files || []).map((file) => file.documentId).filter(Boolean);
        if (!uploadedDocumentIds.length) {
            return;
        }
        this.loading = true;
        try {
            await linkUploadedTopicFiles({
                requestJson: JSON.stringify({
                    genericTaskId: this.activeTask.genericTaskId,
                    temporaryLinkedEntityId: null,
                    visitorUserIds: this.selectedVisitorIds,
                    contentDocumentIds: uploadedDocumentIds
                })
            });
            await this.refreshActiveTaskFiles();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleRemoveTaskFile(event) {
        const documentId = event.currentTarget?.dataset?.documentId;
        if (!documentId) {
            return;
        }
        this.taskFileIdsPendingDelete = Array.from(new Set([...this.taskFileIdsPendingDelete, documentId]));
        this.taskFiles = this.taskFiles.filter((file) => file.contentDocumentId !== documentId);
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

    async savePendingTaskFileRemovals() {
        if (!this.activeTask?.genericTaskId || !this.taskFileIdsPendingDelete.length) {
            return;
        }
        const files = await deleteTopicFiles({
            requestJson: JSON.stringify({
                genericTaskId: this.activeTask.genericTaskId,
                contentDocumentIds: this.taskFileIdsPendingDelete
            })
        });
        this.taskFiles = this.decorateTopicFiles(files || []);
        this.taskFileIdsPendingDelete = [];
    }

    handleTaskBack() {
        this.activeTask = null;
        this.taskNoteTitle = '';
        this.taskNoteBody = '';
        this.taskNotes = [];
        this.taskFiles = [];
        this.taskFileIdsPendingDelete = [];
        this.step = STEP_TASK_LIST;
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
            await this.saveActiveTaskContext();
            const response = await saveTask({
                requestJson: JSON.stringify({
                    visitId: this.createdVisitId,
                    actionPlanItemId: this.activeTask.actionPlanItemId,
                    genericTaskId: this.activeTask.genericTaskId,
                    actionPlanId: this.actionPlanId,
                    name: this.activeTask.name,
                    description: this.activeTask.description,
                    startDateTime: this.activeTask.startDateTime,
                    endDateTime: this.activeTask.endDateTime,
                    required: this.activeTask.required,
                    status: this.activeTask.status,
                    complete
                })
            });
            await this.savePendingTaskFileRemovals();
            this.tasks = this.decorateTasks(response.tasks || []);
            this.requiredTasksComplete = response.requiredTasksComplete;
            this.activeTask = null;
            this.taskFiles = [];
            this.taskFileIdsPendingDelete = [];
            this.step = STEP_TASK_LIST;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async saveActiveTaskContext() {
        if (!this.activeTask?.genericTaskId || !this.activeTask.topicContextProductId) {
            return;
        }
        await saveTopicContext({
            requestJson: JSON.stringify({
                genericTaskId: this.activeTask.genericTaskId,
                productId: this.activeTask.topicContextProductId
            })
        });
    }

    async openOpportunityModal() {
        this.opportunityDefaults = {
            closeDate: this.defaultOpportunityCloseDate(),
            stageName: OPPORTUNITY_STAGE_INITIAL_NOTIFICATION
        };
        this.opportunityDefaultsLoading = true;
        this.opportunityLayoutLoading = true;
        this.opportunityLayoutSections = [];
        this.showOpportunityModal = true;
        try {
            const defaults = await getOpportunityDefaults({ visitId: this.createdVisitId });
            this.opportunityDefaults = {
                ...defaults,
                closeDate: defaults?.closeDate || this.defaultOpportunityCloseDate(),
                stageName: defaults?.stageName || OPPORTUNITY_STAGE_INITIAL_NOTIFICATION
            };
        } catch (error) {
            this.handleError(error);
        } finally {
            this.opportunityDefaultsLoading = false;
        }
    }

    closeOpportunityModal() {
        this.showOpportunityModal = false;
        this.opportunityDefaultsLoading = false;
        this.opportunityLayoutLoading = false;
        this.opportunityLayoutSections = [];
    }

    handleOpportunityFormSubmit(event) {
        event.preventDefault();
        const fields = { ...event.detail.fields };
        fields.RecordTypeId = this.opportunityRecordTypeId;
        const accountId = this.resolveAccountId();
        if (accountId) {
            fields.AccountId = accountId;
        }
        if (this.createdVisitId) {
            fields[OPPORTUNITY_VISIT_FIELD] = this.createdVisitId;
        }
        if (!fields.StageName && this.opportunityDefaults?.stageName) {
            fields.StageName = this.opportunityDefaults.stageName;
        }
        if (!fields.CloseDate) {
            fields.CloseDate = this.opportunityDefaults?.closeDate || this.defaultOpportunityCloseDate();
        }
        this.template.querySelector('[data-opportunity-form]')?.submit(fields);
    }

    async handleOpportunityFormSuccess(event) {
        const createdRecordId = event.detail.id;
        this.loading = true;
        try {
            const updateFields = {
                Id: createdRecordId,
                RecordTypeId: this.opportunityRecordTypeId
            };
            const accountId = this.resolveAccountId();
            if (accountId) {
                updateFields.AccountId = accountId;
            }
            if (this.createdVisitId) {
                updateFields[OPPORTUNITY_VISIT_FIELD] = this.createdVisitId;
            }
            await updateRecord({ fields: updateFields });
            const productResult = await addOpportunityProductsFromTopicContexts({
                opportunityId: createdRecordId,
                visitId: this.createdVisitId
            });
            const opportunity = {
                opportunityId: createdRecordId,
                name: event.detail.fields?.Name?.value || createdRecordId,
                stageName: event.detail.fields?.StageName?.value,
                closeDate: event.detail.fields?.CloseDate?.value,
                amount: event.detail.fields?.Amount?.value
            };
            this.opportunities = [opportunity, ...this.opportunities];
            this.showOpportunityModal = false;
            this.opportunityLayoutSections = [];
            const message = productResult?.message || 'Opportunity created.';
            this.showToast('Success', message, productResult?.skippedProductCount ? 'warning' : 'success');
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleOpportunityFormError(event) {
        this.handleError(event.detail);
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

    buildOpportunityLayoutSections(defaults) {
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
                                if (!apiName || seenFields.has(apiName) || componentType !== 'Field' || apiName === 'RecordTypeId') {
                                    return;
                                }
                                seenFields.add(apiName);
                                fields.push({
                                    id: `opp-${sectionIndex}-${rowIndex}-${itemIndex}-${componentIndex}-${apiName}`,
                                    apiName,
                                    required: item.required === true,
                                    value: this.opportunityFieldDefaultValue(apiName, recordFields),
                                    disabled: this.opportunityFieldDisabled(apiName, item)
                                });
                            });
                        });
                        return {
                            id: `opp-${sectionIndex}-${rowIndex}`,
                            fields
                        };
                    })
                    .filter((row) => row.fields.length > 0);

                return {
                    id: `opp-section-${sectionIndex}`,
                    heading: section.heading || section.label || 'Opportunity Information',
                    rows
                };
            })
            .filter((section) => section.rows.length > 0);

        return layoutSections.length ? layoutSections : this.fallbackOpportunityLayoutSections();
    }

    opportunityFieldDefaultValue(apiName, recordFields) {
        if (apiName === 'AccountId') {
            return this.resolveAccountId() || this.opportunityDefaults?.accountId;
        }
        if (apiName === OPPORTUNITY_VISIT_FIELD) {
            return this.createdVisitId;
        }
        if (apiName === 'StageName') {
            return this.opportunityDefaults?.stageName || OPPORTUNITY_STAGE_INITIAL_NOTIFICATION;
        }
        if (apiName === 'CloseDate') {
            return this.opportunityDefaults?.closeDate || this.defaultOpportunityCloseDate();
        }
        return recordFields?.[apiName]?.value;
    }

    opportunityFieldDisabled(apiName, item) {
        if (apiName === 'AccountId' || apiName === OPPORTUNITY_VISIT_FIELD) {
            return true;
        }
        return item?.editableForNew === false;
    }

    fallbackOpportunityLayoutSections() {
        return [
            {
                id: 'fallback-opportunity-information',
                heading: 'Opportunity Information',
                rows: [
                    {
                        id: 'fallback-opportunity-row-1',
                        fields: [
                            { id: 'fallback-opportunity-name', apiName: 'Name', required: true },
                            { id: 'fallback-opportunity-stage', apiName: 'StageName', required: true, value: this.opportunityDefaults?.stageName || OPPORTUNITY_STAGE_INITIAL_NOTIFICATION }
                        ]
                    },
                    {
                        id: 'fallback-opportunity-row-2',
                        fields: [
                            { id: 'fallback-opportunity-account', apiName: 'AccountId', value: this.resolveAccountId(), disabled: true },
                            { id: 'fallback-opportunity-close', apiName: 'CloseDate', required: true, value: this.opportunityDefaults?.closeDate || this.defaultOpportunityCloseDate() }
                        ]
                    },
                    {
                        id: 'fallback-opportunity-row-3',
                        fields: [
                            { id: 'fallback-opportunity-visit', apiName: OPPORTUNITY_VISIT_FIELD, value: this.createdVisitId, disabled: true }
                        ]
                    }
                ]
            }
        ];
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
            this.newContactRecordTypeId = null;
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
            this.showToast('Account Required', 'Select an Account before adding dealer or customer contacts.', 'error');
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
        const fieldValidity = fields.reduce((isValid, field) => {
            const valid = typeof field.reportValidity === 'function' ? field.reportValidity() : true;
            return isValid && valid && this.hasValue(this.getInputValue(field));
        }, true);
        return fieldValidity && this.validateActionPlanTemplateSelection(true);
    }

    validateActionPlanTemplateSelection(reportValidity) {
        const input = this.template.querySelector('[data-action-plan-template-search]');
        const hasSelection = this.hasValue(this.actionPlanTemplateVersionId);
        if (input && typeof input.setCustomValidity === 'function') {
            input.setCustomValidity(hasSelection ? '' : 'Select a Meeting Template.');
            if (reportValidity && typeof input.reportValidity === 'function') {
                input.reportValidity();
            }
        }
        return hasSelection;
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
            const [accountInfo, defaultAddress] = await Promise.all([
                getAccountInfo({ accountId: this.accountId }),
                getDefaultAccountAddress({ accountId: this.accountId })
            ]);
            this.accountName = accountInfo?.name;
            this.visitorCandidates = [];
            this.ensureCurrentUserAttendee();
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
                    this.ensureCurrentUserAttendee();
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
            this.ensureCurrentUserAttendee();
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
            createActionPlan: false
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
            this.ensureCurrentUserAttendee();
            this.selectedContacts = state.selectedContacts?.length ? this.uniqueContacts(state.selectedContacts) : this.uniqueContacts(this.selectedContacts);
            this.placeDisplayValue = state.placeDisplayValue || this.placeDisplayValue;
            this.actionPlanId = null;
            this.actionPlanName = '';
            this.actionPlanTemplateVersionId = null;
            this.actionPlanTemplateName = '';
            this.actionPlanTemplateSearchTerm = '';
            this.createActionPlan = false;
        } catch {
            // Saved state is best-effort; persisted records still hydrate the wizard.
        }
    }

    decorateTasks(tasks) {
        return (tasks || []).map((task) => {
            const manualTopic = this.isManualTopic(task);
            const completed = manualTopic || task.completed;
            return {
                ...task,
                completed,
                taskRowKey: this.taskRowKey(task),
                salesTask: Boolean(task.salesTask),
                topicContexts: task.topicContexts || [],
                displayStatus: manualTopic ? 'Complete' : this.formatTaskStatus(task.itemState || task.status || 'Not Started'),
                requiredLabel: task.required ? 'Yes' : 'No',
                completedLabel: completed ? 'True' : 'No',
                taskActionLabel: manualTopic ? 'Edit' : completed || task.itemState === 'InProgress' ? 'View' : 'Start'
            };
        });
    }

    findTaskByRowKey(rowKey) {
        return (this.tasks || []).find((task) => task.taskRowKey === rowKey);
    }

    taskRowKey(task) {
        return task?.genericTaskId || task?.actionPlanItemId || task?.name || '';
    }

    isSalesTopicName(name) {
        return String(name || '').toLowerCase().includes('sales');
    }

    isManualTopic(task) {
        return !!task?.genericTaskId && !task?.actionPlanItemId;
    }

    uniqueTopicFiles(files = []) {
        const seen = new Set();
        return (files || []).filter((file) => {
            const fileKey = file?.contentDocumentId || file?.key;
            if (!fileKey || seen.has(fileKey)) {
                return false;
            }
            seen.add(fileKey);
            return true;
        });
    }

    decorateTopicFiles(files = []) {
        return (files || []).map((file) => ({
            ...file,
            key: file.contentDocumentId,
            fileName: file.fileName || file.title || 'File'
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
            VisitedParties: STEP_VISITORS,
            ActionPlan: STEP_TASK_LIST,
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

    ensureCurrentUserAttendee() {
        if (!this.currentUserCandidate?.userId) {
            return;
        }
        const otherVisitors = (this.selectedVisitors || []).filter((visitor) => visitor.userId !== this.currentUserCandidate.userId);
        this.selectedVisitors = this.uniqueVisitors([{ ...this.currentUserCandidate }, ...otherVisitors]);
    }

    rememberHiddenVisitFieldDefaults(fields) {
        const values = { ...this.visitFormValues };
        (fields || []).forEach((field) => {
            if (
                HIDDEN_V7_VISIT_FIELDS.has(field.apiName) &&
                this.hasValue(field.value) &&
                !Object.prototype.hasOwnProperty.call(values, field.apiName)
            ) {
                values[field.apiName] = field.value;
            }
        });
        this.visitFormValues = values;
        this.applyDraftVisitStatus();
    }

    applyDraftVisitStatus() {
        if (this.completed) {
            this.visitStatus = VISIT_STATUS_COMPLETED;
            this.visitFormValues = { ...this.visitFormValues, Status: VISIT_STATUS_COMPLETED };
            return;
        }
        this.visitStatus = VISIT_STATUS_DRAFT;
        this.visitFormValues = { ...this.visitFormValues, Status: VISIT_STATUS_DRAFT };
    }

    todayValue() {
        const now = new Date();
        const localDate = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
        return localDate.toISOString().slice(0, 10);
    }

    nowDateTimeValue() {
        return new Date().toISOString();
    }

    defaultOpportunityCloseDate() {
        const closeDate = new Date();
        closeDate.setDate(closeDate.getDate() + 30);
        const localDate = new Date(closeDate.getTime() - closeDate.getTimezoneOffset() * 60000);
        return localDate.toISOString().slice(0, 10);
    }

    hasValue(value) {
        return value !== null && value !== undefined && value !== '' && (!Array.isArray(value) || value.length > 0);
    }

    toBoolean(value) {
        if (typeof value === 'boolean') {
            return value;
        }
        if (typeof value === 'string') {
            return value.toLowerCase() === 'true';
        }
        return Boolean(value);
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
