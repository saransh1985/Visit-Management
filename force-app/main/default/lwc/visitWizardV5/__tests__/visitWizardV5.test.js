import { createElement } from 'lwc';
import VisitWizard from 'c/visitWizardV5';

import getVisitRecordTypes from '@salesforce/apex/VisitWizardController.getVisitRecordTypesV4';
import getVisitFieldMetadata from '@salesforce/apex/VisitWizardController.getVisitFieldMetadata';
import getInitialVisitorCandidates from '@salesforce/apex/VisitWizardController.getInitialVisitorCandidates';
import searchUsers from '@salesforce/apex/VisitWizardController.searchUsers';
import searchContacts from '@salesforce/apex/VisitWizardController.searchContacts';
import saveVisitV3 from '@salesforce/apex/VisitWizardController.saveVisitV3';
import getActionPlanStartInfo from '@salesforce/apex/VisitWizardController.getActionPlanStartInfo';
import saveActionPlan from '@salesforce/apex/VisitWizardController.saveActionPlan';

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
                return Promise.resolve('https://www.example.com');
            }
        };

    NavigationMixin.Navigate = Navigate;
    NavigationMixin.GenerateUrl = GenerateUrl;

    return {
        CurrentPageReference: createTestWireAdapter(jest.fn()),
        NavigationMixin
    };
});
jest.mock(
    '@salesforce/apex/VisitWizardController.getVisitRecordTypesV4',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/VisitWizardController.getVisitFieldMetadata',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/VisitWizardController.getInitialVisitorCandidates',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock('@salesforce/apex/VisitWizardController.searchUsers', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/VisitWizardController.searchContacts', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/VisitWizardController.saveVisitV3', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock(
    '@salesforce/apex/VisitWizardController.getActionPlanStartInfo',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock('@salesforce/apex/VisitWizardController.saveActionPlan', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock(
    'lightning/actions',
    () => ({
        CloseActionScreenEvent: class CloseActionScreenEvent extends CustomEvent {
            constructor() {
                super('lightning__actionsclosescreen');
            }
        }
    }),
    { virtual: true }
);

const ACCOUNT_ID = '001000000000001AAA';
const CONTACT_ID = '003000000000001AAA';
const RECORD_TYPE_ID = '012000000000001AAA';
const USER_ID = '005000000000001AAA';
const VISIT_ID = '0Z5000000000001AAA';
const TEMPLATE_VERSION_ID = '0PT000000000001AAA';

async function flushPromises() {
    await Promise.resolve();
    await Promise.resolve();
}

function defaultMocks() {
    getVisitRecordTypes.mockResolvedValue([
        {
            label: 'Dealer Visit',
            value: RECORD_TYPE_ID,
            developerName: 'Dealer_Visit',
            defaultRecordTypeMapping: true,
            master: false
        }
    ]);
    getVisitFieldMetadata.mockResolvedValue([]);
    getInitialVisitorCandidates.mockResolvedValue([
        {
            userId: USER_ID,
            name: 'Visit Owner',
            email: 'owner@example.com',
            title: 'Owner',
            source: 'Account Owner',
            selected: true,
            locked: true
        }
    ]);
    searchUsers.mockResolvedValue([]);
    searchContacts.mockResolvedValue([
        {
            contactId: CONTACT_ID,
            accountId: ACCOUNT_ID,
            name: 'Visited Contact'
        }
    ]);
    saveVisitV3.mockResolvedValue({ visitId: VISIT_ID, message: 'Visit submitted.' });
    getActionPlanStartInfo.mockResolvedValue({
        targetRecordId: VISIT_ID,
        defaultStatus: 'NotStarted',
        statusOptions: [{ label: 'Not Started', value: 'NotStarted' }],
        recentTemplates: [
            {
                templateVersionId: TEMPLATE_VERSION_ID,
                name: 'Published Visit Template',
                actionPlanType: 'Visit',
                versionNumber: 1
            }
        ]
    });
    saveActionPlan.mockResolvedValue({
        actionPlanId: '07r000000000001AAA',
        message: 'Action Plan created.'
    });
}

function createComponent() {
    const element = createElement('c-visit-wizard-v5', {
        is: VisitWizard
    });
    element.recordId = ACCOUNT_ID;
    document.body.appendChild(element);
    return element;
}

function buttonByLabel(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find(
        (button) => button.label === label
    );
}

function selectRecordType(element) {
    const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
    radioGroup.dispatchEvent(
        new CustomEvent('change', {
            detail: { value: RECORD_TYPE_ID }
        })
    );
}

describe('c-visit-wizard-v5', () => {
    beforeEach(() => {
        defaultMocks();
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        mockNavigate.mockClear();
    });

    it('moves from record type to Visit details and lets the user go back', async () => {
        const element = createComponent();
        await flushPromises();

        selectRecordType(element);
        await flushPromises();

        expect(getVisitFieldMetadata).toHaveBeenCalledWith({ recordTypeId: RECORD_TYPE_ID });
        expect(element.shadowRoot.querySelector('lightning-record-edit-form')).not.toBeNull();

        buttonByLabel(element, 'Previous').click();
        await flushPromises();

        const radioGroup = element.shadowRoot.querySelector('lightning-radio-group');
        expect(radioGroup).not.toBeNull();
        expect(radioGroup.value).toBe(RECORD_TYPE_ID);
    });

    it('does not leave Visit details when a required Visit field is empty', async () => {
        getVisitFieldMetadata.mockResolvedValue([
            {
                apiName: 'PlannedVisitStartTime',
                label: 'Planned Start Time',
                required: true
            }
        ]);
        const element = createComponent();
        await flushPromises();

        selectRecordType(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-record-edit-form').dispatchEvent(new CustomEvent('load'));
        await flushPromises();
        buttonByLabel(element, 'Next').click();
        await flushPromises();

        expect(element.shadowRoot.querySelector('lightning-record-edit-form')).not.toBeNull();
        expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
    });

    it('creates an Action Plan and lands on the Visit record', async () => {
        const element = createComponent();
        await flushPromises();

        selectRecordType(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-record-edit-form').dispatchEvent(new CustomEvent('load'));
        await flushPromises();
        buttonByLabel(element, 'Next').click();
        await flushPromises();
        buttonByLabel(element, 'Next').click();
        await flushPromises();

        buttonByLabel(element, 'Add').click();
        await flushPromises();
        const contactResultsTable = Array.from(
            element.shadowRoot.querySelectorAll('lightning-datatable')
        ).find((datatable) => datatable.keyField === 'contactId' && datatable.data.length);
        contactResultsTable.dispatchEvent(
            new CustomEvent('rowaction', {
                detail: {
                    action: { name: 'add' },
                    row: {
                        contactId: CONTACT_ID,
                        accountId: ACCOUNT_ID,
                        name: 'Visited Contact'
                    }
                }
            })
        );
        await flushPromises();

        buttonByLabel(element, 'Add Action Plan').click();
        await flushPromises();
        await flushPromises();

        element.shadowRoot.querySelector('[data-field="actionPlanName"]').value = 'Follow Up';
        element.shadowRoot
            .querySelector('[data-field="actionPlanName"]')
            .dispatchEvent(new CustomEvent('change'));
        element.shadowRoot.querySelector('[data-field="actionPlanStartDate"]').value = '2026-06-01';
        element.shadowRoot
            .querySelector('[data-field="actionPlanStartDate"]')
            .dispatchEvent(new CustomEvent('change'));
        element.shadowRoot.querySelector('[data-field="actionPlanStatus"]').value = 'NotStarted';
        element.shadowRoot
            .querySelector('[data-field="actionPlanStatus"]')
            .dispatchEvent(new CustomEvent('change'));
        element.shadowRoot.querySelector('lightning-record-picker').dispatchEvent(
            new CustomEvent('change', {
                detail: { recordId: TEMPLATE_VERSION_ID }
            })
        );
        element.shadowRoot.querySelectorAll('[data-action-plan-field]').forEach((field) => {
            field.reportValidity = jest.fn(() => true);
        });

        buttonByLabel(element, 'Submit').click();
        await flushPromises();

        const savePayload = JSON.parse(saveActionPlan.mock.calls[0][0].requestJson);
        expect(savePayload.visitId).toBe(VISIT_ID);
        expect(savePayload.actionPlanTemplateVersionId).toBe(TEMPLATE_VERSION_ID);
        expect(mockNavigate).toHaveBeenCalledWith({
            type: 'standard__recordPage',
            attributes: {
                recordId: VISIT_ID,
                objectApiName: 'Visit',
                actionName: 'view'
            }
        });
    });
});
