import { createElement } from 'lwc';
import { createApexTestWireAdapter as mockCreateApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import VisitWizardV6 from 'c/visitWizardV6';

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
import searchActionPlanTemplates from '@salesforce/apex/VisitWizardV6Controller.searchActionPlanTemplates';
import saveActionPlanAndLoadTasks from '@salesforce/apex/VisitWizardV6Controller.saveActionPlanAndLoadTasks';
import getTaskList from '@salesforce/apex/VisitWizardV6Controller.getTaskList';
import startTask from '@salesforce/apex/VisitWizardV6Controller.startTask';
import saveTask from '@salesforce/apex/VisitWizardV6Controller.saveTask';
import getTaskNotes from '@salesforce/apex/VisitWizardV6Controller.getTaskNotes';
import saveTaskNote from '@salesforce/apex/VisitWizardV6Controller.saveTaskNote';
import getOpportunityDefaults from '@salesforce/apex/VisitWizardV6Controller.getOpportunityDefaults';
import getReview from '@salesforce/apex/VisitWizardV6Controller.getReview';
import completeVisit from '@salesforce/apex/VisitWizardV6Controller.completeVisit';

const mockNavigate = jest.fn();

jest.mock('lightning/navigation', () => {
    const { createTestWireAdapter } = require('@salesforce/wire-service-jest-util');
    const Navigate = Symbol('Navigate');
    const GenerateUrl = Symbol('GenerateUrl');
    const NavigationMixin = (Base) =>
        class extends Base {
            [Navigate](pageReference) {
                mockNavigate(pageReference);
            }

            [GenerateUrl]() {
                return Promise.resolve('https://example.com');
            }
        };

    NavigationMixin.Navigate = Navigate;
    NavigationMixin.GenerateUrl = GenerateUrl;

    return {
        CurrentPageReference: createTestWireAdapter(jest.fn()),
        NavigationMixin
    };
});

jest.mock('lightning/actions', () => ({
    CloseActionScreenEvent: class CloseActionScreenEvent extends CustomEvent {
        constructor() {
            super('lightning__actionsclosescreen');
        }
    }
}), { virtual: true });

jest.mock('@salesforce/apex/VisitWizardV6Controller.getLaunchContext', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getVisitFieldMetadata', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getAccountInfo', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.searchAccounts', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.searchAccountAddresses', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getDefaultAccountAddress', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getAddressInfo', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getInitialVisitorCandidates', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.searchUsers', () => ({ default: jest.fn() }), { virtual: true });
jest.mock(
    '@salesforce/apex/VisitWizardV6Controller.getContactRecordTypeDescriptions',
    () => ({ default: mockCreateApexTestWireAdapter(jest.fn()) }),
    { virtual: true }
);
jest.mock('@salesforce/apex/VisitWizardV6Controller.searchContacts', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.saveForLater', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.saveVisitProgress', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getActionPlanStartInfo', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getActionPlanTemplateOption', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.searchActionPlanTemplates', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.saveActionPlanAndLoadTasks', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getTaskList', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.startTask', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.saveTask', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getTaskNotes', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.saveTaskNote', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getOpportunityDefaults', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.getReview', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.completeVisit', () => ({ default: jest.fn() }), { virtual: true });

const ACCOUNT_ID = '001000000000001AAA';
const RECORD_TYPE_ID = '012000000000001AAA';
const SECOND_RECORD_TYPE_ID = '012000000000002AAA';
const OPPORTUNITY_RECORD_TYPE_ID = '012000000000005AAA';
const CONTACT_RECORD_TYPE_ID = '012000000000003AAA';
const SECOND_CONTACT_RECORD_TYPE_ID = '012000000000004AAA';
const USER_ID = '005000000000001AAA';
const CREATED_CONTACT_ID = '003000000000010AAA';
const EXISTING_CONTACT_ID = '003000000000011AAA';
const PLACE_ID = '130000000000001AAA';
const TEMPLATE_VERSION_ID = '0PT000000000001AAA';

async function flushPromises() {
    for (let i = 0; i < 12; i += 1) {
        await Promise.resolve();
    }
}

function launchContext(overrides = {}) {
    return {
        mode: 'NEW',
        canEdit: true,
        completed: false,
        accountId: ACCOUNT_ID,
        accountName: 'Visit Account',
        recordTypes: [
            {
                label: 'Fleet Visit',
                value: RECORD_TYPE_ID,
                developerName: 'Fleet_Service',
                defaultRecordTypeMapping: true,
                master: false
            },
            {
                label: 'Dealer Visit',
                value: SECOND_RECORD_TYPE_ID,
                developerName: 'Dealer_Visit',
                defaultRecordTypeMapping: false,
                master: false
            }
        ],
        visitorCandidates: [
            {
                userId: USER_ID,
                name: 'Visit Owner',
                email: 'owner@example.com',
                title: 'Owner',
                role: 'Regional Manager',
                source: 'Account Owner',
                selected: true,
                locked: true
            }
        ],
        selectedVisitors: [],
        selectedContacts: [],
        visitValues: {},
        resumePage: 'RecordType',
        tasks: [],
        opportunities: [],
        ...overrides
    };
}

function defaultMocks(contextOverrides = {}) {
    getLaunchContext.mockResolvedValue(launchContext(contextOverrides));
    getVisitFieldMetadata.mockResolvedValue([]);
    getAccountInfo.mockResolvedValue({ accountId: ACCOUNT_ID, name: 'Visit Account' });
    searchAccounts.mockResolvedValue([]);
    searchAccountAddresses.mockResolvedValue([]);
    getDefaultAccountAddress.mockResolvedValue(null);
    getAddressInfo.mockResolvedValue(null);
    getInitialVisitorCandidates.mockResolvedValue([]);
    searchUsers.mockResolvedValue([]);
    searchContacts.mockResolvedValue([]);
    saveForLater.mockResolvedValue({ visitId: '0Z5000000000001AAA', resumePage: 'Visitors' });
    saveVisitProgress.mockResolvedValue({ visitId: '0Z5000000000001AAA', resumePage: 'Visitors' });
    getActionPlanStartInfo.mockResolvedValue({ statusOptions: [], recentTemplates: [], defaultStatus: 'In Progress' });
    getActionPlanTemplateOption.mockResolvedValue({ templateVersionId: TEMPLATE_VERSION_ID, name: 'Resolved Template' });
    searchActionPlanTemplates.mockResolvedValue([]);
    saveActionPlanAndLoadTasks.mockResolvedValue({ tasks: [], requiredTasksComplete: true });
    getTaskList.mockResolvedValue({ tasks: [], requiredTasksComplete: true });
    startTask.mockResolvedValue({ tasks: [], requiredTasksComplete: true });
    saveTask.mockResolvedValue({ tasks: [], requiredTasksComplete: true });
    getTaskNotes.mockResolvedValue([]);
    saveTaskNote.mockResolvedValue([]);
    getOpportunityDefaults.mockResolvedValue({});
    getReview.mockResolvedValue(launchContext({ resumePage: 'Review' }));
    completeVisit.mockResolvedValue({ visitId: '0Z5000000000001AAA', message: 'Visit completed.' });
}

function emitContactMetadata() {
    getObjectInfo.emit({
        defaultRecordTypeId: CONTACT_RECORD_TYPE_ID,
        recordTypeInfos: {
            [CONTACT_RECORD_TYPE_ID]: {
                available: true,
                master: false,
                name: 'Dealer Contact',
                recordTypeId: CONTACT_RECORD_TYPE_ID
            },
            [SECOND_CONTACT_RECORD_TYPE_ID]: {
                available: true,
                master: false,
                name: 'Supplier Contact',
                recordTypeId: SECOND_CONTACT_RECORD_TYPE_ID
            }
        }
    });
    getContactRecordTypeDescriptions.emit({
        [CONTACT_RECORD_TYPE_ID]: 'This should be used for dealership contacts and should remain readable.',
        [SECOND_CONTACT_RECORD_TYPE_ID]: 'This should be used to create Contacts for Supplier.'
    });
}

function emitOpportunityMetadata() {
    getObjectInfo.emit({
        defaultRecordTypeId: OPPORTUNITY_RECORD_TYPE_ID,
        recordTypeInfos: {
            [OPPORTUNITY_RECORD_TYPE_ID]: {
                available: true,
                master: false,
                name: 'Fleet Visit',
                developerName: 'Fleet_Service',
                recordTypeId: OPPORTUNITY_RECORD_TYPE_ID
            },
            [SECOND_RECORD_TYPE_ID]: {
                available: true,
                master: false,
                name: 'Dealer Visit',
                developerName: 'Dealer_Visit',
                recordTypeId: SECOND_RECORD_TYPE_ID
            }
        }
    });
}

function createComponent(contextOverrides = {}) {
    defaultMocks(contextOverrides);
    const element = createElement('c-visit-wizard-v6', {
        is: VisitWizardV6
    });
    element.recordId = ACCOUNT_ID;
    document.body.appendChild(element);
    return element;
}

function buttonByLabel(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find(
        (button) => (button.label || button.getAttribute('label') || button.textContent) === label
    );
}

function nativeButtonByText(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll('button')).find(
        (button) => button.textContent.trim() === label
    );
}

describe('c-visit-wizard-v6', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.useRealTimers();
        jest.clearAllMocks();
        mockNavigate.mockClear();
    });

    it('fits all visible wizard steps into the header', async () => {
        const element = createComponent();
        await flushPromises();

        const stepbar = element.shadowRoot.querySelector('.stepbar_v6');
        const labels = Array.from(element.shadowRoot.querySelectorAll('.step-label')).map((label) => label.textContent);

        expect(stepbar.style.getPropertyValue('--step-count')).toBe('7');
        expect(labels).toEqual([
            'Record Type',
            'Visit Details',
            'Visitors',
            'Visited Parties',
            'Meeting Template',
            'Topics',
            'Review'
        ]);
    });

    it('shows readable Contact record type descriptions', async () => {
        const element = createComponent({
            recordTypeId: RECORD_TYPE_ID,
            resumePage: 'VisitedParties'
        });
        emitContactMetadata();
        await flushPromises();

        buttonByLabel(element, 'Create Contact').click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('.record-type-table')).toBeNull();
        const headerText = element.shadowRoot.querySelector('.record-type-grid-header').textContent;
        expect(headerText).toContain('Recordtype name');
        expect(headerText).toContain('Description');
        expect(headerText).not.toContain('Description of that recordtype');
        expect(element.shadowRoot.querySelector('.record-type-description-cell').textContent).toContain(
            'dealership contacts'
        );
    });

    it('shows visitor Role and full email in the Add Visitor modal', async () => {
        jest.useFakeTimers();
        const element = createComponent({
            recordTypeId: RECORD_TYPE_ID,
            resumePage: 'Visitors'
        });
        searchUsers.mockResolvedValue([
            {
                userId: '005000000000002AAA',
                name: 'Sandy Cade',
                role: 'Regional Fleet Sales Manager',
                email: 'sandy.cade@example-dtna.com',
                source: 'Manual',
                selected: false,
                locked: false
            }
        ]);
        await flushPromises();

        buttonByLabel(element, 'Add').click();
        await flushPromises();
        expect(element.shadowRoot.querySelector('.slds-text-heading_medium')?.textContent).not.toBe('Add Visitor');
        expect(element.shadowRoot.querySelector('.empty-state').textContent).toContain('No user found');

        const searchInput = Array.from(element.shadowRoot.querySelectorAll('lightning-input')).find(
            (input) => input.label === 'Search Active Users'
        );
        searchInput.value = 'san';
        searchInput.dispatchEvent(new CustomEvent('change'));
        jest.runOnlyPendingTimers();
        await flushPromises();

        const tableText = element.shadowRoot.querySelector('.user-search-table').textContent;
        expect(searchUsers).toHaveBeenCalledWith({ searchTerm: 'san', excludedUserIds: [USER_ID] });
        expect(tableText).toContain('Role');
        expect(tableText).toContain('Regional Fleet Sales Manager');
        expect(tableText).toContain('sandy.cade@example-dtna.com');
    });

    it('saves only the reselected account contact after removing a created visited party', async () => {
        const element = createComponent({
            recordTypeId: RECORD_TYPE_ID,
            resumePage: 'VisitedParties',
            selectedContacts: [
                {
                    contactId: CREATED_CONTACT_ID,
                    name: 'Created Contact',
                    email: 'created@example.com'
                },
                {
                    contactId: CREATED_CONTACT_ID.substring(0, 15),
                    name: 'Created Contact Duplicate',
                    email: 'created@example.com'
                }
            ],
            visitValues: {
                AccountId: ACCOUNT_ID,
                PlaceId: PLACE_ID,
                PlannedVisitStartTime: '2026-06-08T17:00:00.000Z',
                PlannedVisitEndTime: '2026-06-08T18:00:00.000Z',
                VisitPriority: 'Medium'
            }
        });
        searchContacts.mockResolvedValue([
            {
                contactId: EXISTING_CONTACT_ID,
                name: 'Existing Account Contact',
                email: 'existing@example.com'
            }
        ]);
        await flushPromises();

        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowaction', {
            detail: {
                action: { name: 'remove' },
                row: { contactId: CREATED_CONTACT_ID }
            }
        }));
        await flushPromises();

        buttonByLabel(element, 'Add').click();
        await flushPromises();
        const contactSearchTable = Array.from(element.shadowRoot.querySelectorAll('lightning-datatable')).pop();
        contactSearchTable.dispatchEvent(new CustomEvent('rowaction', {
            detail: {
                action: { name: 'add' },
                row: {
                    contactId: EXISTING_CONTACT_ID,
                    name: 'Existing Account Contact',
                    email: 'existing@example.com'
                }
            }
        }));
        await flushPromises();

        buttonByLabel(element, 'Next').click();
        await flushPromises();

        const payload = JSON.parse(saveVisitProgress.mock.calls.at(-1)[0].requestJson);
        const state = JSON.parse(payload.stateJson);
        expect(payload.visitedContactIds).toEqual([EXISTING_CONTACT_ID]);
        expect(state.selectedContacts).toEqual([
            expect.objectContaining({
                contactId: EXISTING_CONTACT_ID,
                name: 'Existing Account Contact'
            })
        ]);
    });

    it('locks Meeting Template name and derives it from the selected recent template', async () => {
        const templateName = `DTNA ${'Meeting Template '.repeat(18)}`;
        const expectedName = `Template - ${templateName}`.slice(0, 253) + '..';
        const element = createComponent({
            recordTypeId: RECORD_TYPE_ID,
            resumePage: 'ActionPlan',
            visitId: '0Z5000000000001AAA',
            visitName: '00000282',
            visitValues: {
                AccountId: ACCOUNT_ID,
                PlaceId: PLACE_ID,
                VisitPriority: 'Medium'
            }
        });
        getActionPlanStartInfo.mockResolvedValue({
            statusOptions: [{ label: 'In Progress', value: 'In Progress' }],
            defaultStatus: 'In Progress',
            recentTemplates: [
                {
                    templateVersionId: TEMPLATE_VERSION_ID,
                    name: templateName,
                    templateName,
                    actionPlanType: 'Retail',
                    versionNumber: 1
                }
            ]
        });
        await flushPromises();

        let nameInput = Array.from(element.shadowRoot.querySelectorAll('lightning-input')).find(
            (input) => input.label === 'Name'
        );
        expect(nameInput.disabled).toBe(true);

        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowaction', {
            detail: {
                action: { name: 'select_template' },
                row: {
                    templateVersionId: TEMPLATE_VERSION_ID,
                    name: templateName,
                    templateName
                }
            }
        }));
        await flushPromises();

        nameInput = Array.from(element.shadowRoot.querySelectorAll('lightning-input')).find(
            (input) => input.label === 'Name'
        );
        expect(nameInput.value).toBe(expectedName);
        expect(nameInput.value).toHaveLength(255);

        Array.from(element.shadowRoot.querySelectorAll('[data-action-plan-field]')).forEach((field) => {
            field.reportValidity = jest.fn(() => true);
        });
        buttonByLabel(element, 'Next').click();
        await flushPromises();

        const payload = JSON.parse(saveActionPlanAndLoadTasks.mock.calls.at(-1)[0].requestJson);
        expect(payload.name).toBe(expectedName);
        expect(payload.actionPlanTemplateVersionId).toBe(TEMPLATE_VERSION_ID);
    });

    it('searches and selects a published Meeting Template manually', async () => {
        jest.useFakeTimers();
        const templateName = 'DTNA Sales Meeting Template';
        const element = createComponent({
            recordTypeId: RECORD_TYPE_ID,
            resumePage: 'ActionPlan',
            visitId: '0Z5000000000001AAA',
            visitName: '00000312',
            visitValues: {
                AccountId: ACCOUNT_ID,
                PlaceId: PLACE_ID,
                VisitPriority: 'Medium'
            }
        });
        getActionPlanStartInfo.mockResolvedValue({
            statusOptions: [{ label: 'In Progress', value: 'In Progress' }],
            defaultStatus: 'In Progress',
            recentTemplates: []
        });
        searchActionPlanTemplates.mockResolvedValue([
            {
                templateVersionId: TEMPLATE_VERSION_ID,
                name: templateName,
                templateName,
                actionPlanType: 'Retail',
                versionNumber: 1
            }
        ]);
        await flushPromises();

        const templateSearch = element.shadowRoot.querySelector('[data-action-plan-template-search]');
        templateSearch.value = 'Sales';
        templateSearch.dispatchEvent(new CustomEvent('change'));
        jest.runOnlyPendingTimers();
        await flushPromises();

        expect(searchActionPlanTemplates).toHaveBeenCalledWith({ searchTerm: 'Sales' });
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(new CustomEvent('rowaction', {
            detail: {
                action: { name: 'select_template' },
                row: {
                    templateVersionId: TEMPLATE_VERSION_ID,
                    name: templateName,
                    templateName
                }
            }
        }));
        await flushPromises();

        expect(templateSearch.value).toBe(templateName);
        const nameInput = Array.from(element.shadowRoot.querySelectorAll('lightning-input')).find(
            (input) => input.label === 'Name'
        );
        expect(nameInput.value).toBe(`Template - ${templateName}`);

        Array.from(element.shadowRoot.querySelectorAll('[data-action-plan-field]')).forEach((field) => {
            field.reportValidity = jest.fn(() => true);
        });
        templateSearch.reportValidity = jest.fn(() => true);
        buttonByLabel(element, 'Next').click();
        await flushPromises();

        const payload = JSON.parse(saveActionPlanAndLoadTasks.mock.calls.at(-1)[0].requestJson);
        expect(payload.name).toBe(`Template - ${templateName}`);
        expect(payload.actionPlanTemplateVersionId).toBe(TEMPLATE_VERSION_ID);
    });

    it('shows Create Opportunity beside incomplete Sales topics and disables completed Sales topics', async () => {
        const visitId = '0Z5000000000001AAA';
        const actionPlanId = '0PR000000000001AAA';
        const element = createComponent({
            recordTypeId: RECORD_TYPE_ID,
            resumePage: 'Tasks',
            visitId,
            actionPlanId,
            tasks: [
                {
                    genericTaskId: '0py000000000001AAA',
                    name: 'Review dealer parts sales pipeline',
                    status: 'Pending',
                    required: true,
                    completed: false
                },
                {
                    genericTaskId: '0py000000000002AAA',
                    name: 'Confirm inventory gaps and critical SKUs',
                    status: 'Pending',
                    required: true,
                    completed: false
                },
                {
                    genericTaskId: '0py000000000003AAA',
                    name: 'Schedule monthly sales checkpoint',
                    status: 'Completed',
                    required: false,
                    completed: true
                }
            ]
        });
        getOpportunityDefaults.mockResolvedValue({
            closeDate: '2026-06-30',
            stageName: 'Draft'
        });
        await flushPromises();
        emitOpportunityMetadata();
        await flushPromises();

        const opportunityButtons = Array.from(element.shadowRoot.querySelectorAll('button, lightning-button')).filter(
            (button) => (button.label || button.textContent.trim()) === 'Create Opportunity'
        );
        expect(opportunityButtons).toHaveLength(2);
        expect(opportunityButtons[0].className).toContain('slds-button_brand');
        expect(opportunityButtons[0].disabled).toBeFalsy();
        expect(opportunityButtons[1].disabled).toBe(true);

        opportunityButtons[0].click();
        await flushPromises();

        expect(getOpportunityDefaults).toHaveBeenCalledWith({ visitId });
        expect(element.shadowRoot.querySelector('.slds-modal__header').textContent).toContain('Create Opportunity');
        const opportunityForm = Array.from(element.shadowRoot.querySelectorAll('lightning-record-form')).find(
            (form) => form.objectApiName === 'Opportunity' || form.getAttribute('object-api-name') === 'Opportunity'
        );
        expect(opportunityForm).toBeTruthy();
        expect(opportunityForm.layoutType || opportunityForm.getAttribute('layout-type')).toBe('Full');
        expect(opportunityForm.recordTypeId || opportunityForm.getAttribute('record-type-id')).toBe(OPPORTUNITY_RECORD_TYPE_ID);

        opportunityForm.submit = jest.fn();
        const submitFields = {
            Name: 'Visit Opportunity'
        };
        opportunityForm.dispatchEvent(
            new CustomEvent('submit', {
                detail: {
                    fields: submitFields
                },
                cancelable: true
            })
        );
        expect(opportunityForm.submit).toHaveBeenCalledWith(
            expect.objectContaining({
                AccountId: ACCOUNT_ID,
                Visit__c: visitId,
                RecordTypeId: OPPORTUNITY_RECORD_TYPE_ID,
                StageName: 'Draft',
                CloseDate: '2026-06-30'
            })
        );
    });

    it('lets users save topic details without completing and shows Notes as mandatory', async () => {
        const visitId = '0Z5000000000001AAA';
        const actionPlanId = '0PR000000000001AAA';
        const genericTaskId = '0py000000000001AAA';
        const element = createComponent({
            recordTypeId: RECORD_TYPE_ID,
            resumePage: 'Tasks',
            visitId,
            actionPlanId,
            tasks: [
                {
                    genericTaskId,
                    name: 'Review dealer parts sales pipeline',
                    status: 'In Progress',
                    itemState: 'InProgress',
                    required: true,
                    completed: false,
                    startDateTime: '2026-06-08T17:00:00.000Z'
                }
            ]
        });
        await flushPromises();

        nativeButtonByText(element, 'View').click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('.required-help').textContent).toContain('Notes are mandatory');
        expect(buttonByLabel(element, 'Back to Topics')).toBeTruthy();
        expect(buttonByLabel(element, 'Save')).toBeTruthy();
        expect(buttonByLabel(element, 'Complete Topic')).toBeTruthy();

        buttonByLabel(element, 'Back to Topics').click();
        await flushPromises();
        expect(saveTask).not.toHaveBeenCalled();
        expect(element.shadowRoot.querySelector('.topics-table')).toBeTruthy();

        nativeButtonByText(element, 'View').click();
        await flushPromises();
        const descriptionInput = Array.from(element.shadowRoot.querySelectorAll('lightning-input')).find(
            (input) => input.label === 'Topic Details'
        );
        descriptionInput.value = 'Saved but not completed';
        descriptionInput.dispatchEvent(new CustomEvent('change'));
        await flushPromises();

        buttonByLabel(element, 'Save').click();
        await flushPromises();

        const payload = JSON.parse(saveTask.mock.calls.at(-1)[0].requestJson);
        expect(payload.genericTaskId).toBe(genericTaskId);
        expect(payload.description).toBe('Saved but not completed');
        expect(payload.complete).toBe(false);
    });

    it('opens New Topic as a Generic Visit Task-style form tied to the Visit', async () => {
        const visitId = '0Z5000000000001AAA';
        const actionPlanId = '0PR000000000001AAA';
        const element = createComponent({
            recordTypeId: RECORD_TYPE_ID,
            resumePage: 'Tasks',
            visitId,
            actionPlanId,
            tasks: [
                {
                    genericTaskId: '0py000000000001AAA',
                    name: 'Existing Topic',
                    status: 'Pending',
                    sequence: 2,
                    required: false,
                    completed: false
                }
            ]
        });
        await flushPromises();

        buttonByLabel(element, 'New Topic').click();
        await flushPromises();

        const form = Array.from(element.shadowRoot.querySelectorAll('lightning-record-edit-form')).find(
            (candidate) => candidate.objectApiName === 'GenericVisitTask'
        );
        expect(form.objectApiName).toBe('GenericVisitTask');
        const fieldNames = Array.from(form.querySelectorAll('lightning-input-field')).map((field) =>
            field.fieldName || field.getAttribute('field-name')
        );
        expect(fieldNames).toEqual([
            'Name',
            'Status',
            'Description',
            'StartDateTime',
            'Sequence',
            'VisitId',
            'DefinitionReferenceId',
            'IsRequired',
            'EndDateTime'
        ]);

        const visitField = Array.from(form.querySelectorAll('lightning-input-field')).find(
            (field) => (field.fieldName || field.getAttribute('field-name')) === 'VisitId'
        );
        const sequenceField = Array.from(form.querySelectorAll('lightning-input-field')).find(
            (field) => (field.fieldName || field.getAttribute('field-name')) === 'Sequence'
        );
        const startDateTimeField = Array.from(form.querySelectorAll('lightning-input-field')).find(
            (field) => (field.fieldName || field.getAttribute('field-name')) === 'StartDateTime'
        );
        expect(visitField.value).toBe(visitId);
        expect(visitField.disabled).toBe(true);
        expect(sequenceField.value).toBe(3);
        expect(sequenceField.disabled).toBe(true);
        expect(startDateTimeField.value).toBeTruthy();

        form.submit = jest.fn();
        form.dispatchEvent(new CustomEvent('submit', {
            detail: {
                fields: {
                    Name: 'Walkaround Topic'
                }
            },
            cancelable: true
        }));
        expect(form.submit).toHaveBeenCalledWith(expect.objectContaining({
            Name: 'Walkaround Topic',
            VisitId: visitId,
            Status: 'In Progress',
            Sequence: 3,
            IsRequired: false
        }));

        form.dispatchEvent(new CustomEvent('success', { detail: { id: '0py000000000002AAA' } }));
        await flushPromises();

        expect(getTaskList).toHaveBeenCalledWith({ visitId, actionPlanId });
    });
});
