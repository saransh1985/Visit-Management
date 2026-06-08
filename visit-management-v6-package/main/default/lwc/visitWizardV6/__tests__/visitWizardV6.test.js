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
import saveActionPlanAndLoadTasks from '@salesforce/apex/VisitWizardV6Controller.saveActionPlanAndLoadTasks';
import createCustomTopic from '@salesforce/apex/VisitWizardV6Controller.createCustomTopic';
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
jest.mock('@salesforce/apex/VisitWizardV6Controller.saveActionPlanAndLoadTasks', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/VisitWizardV6Controller.createCustomTopic', () => ({ default: jest.fn() }), { virtual: true });
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
const CONTACT_RECORD_TYPE_ID = '012000000000003AAA';
const SECOND_CONTACT_RECORD_TYPE_ID = '012000000000004AAA';
const USER_ID = '005000000000001AAA';
const CREATED_CONTACT_ID = '003000000000010AAA';
const EXISTING_CONTACT_ID = '003000000000011AAA';
const PLACE_ID = '130000000000001AAA';

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
    saveActionPlanAndLoadTasks.mockResolvedValue({ tasks: [], requiredTasksComplete: true });
    createCustomTopic.mockResolvedValue({ tasks: [], requiredTasksComplete: true });
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
});
