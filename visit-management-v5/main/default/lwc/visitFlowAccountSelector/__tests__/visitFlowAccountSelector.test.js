import { createElement } from 'lwc';
import VisitFlowAccountSelector from 'c/visitFlowAccountSelector';
import getAccountInfo from '@salesforce/apex/VisitWizardController.getAccountInfo';

jest.mock('@salesforce/apex/VisitWizardController.getAccountInfo', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock(
    'lightning/flowSupport',
    () => ({
        FlowAttributeChangeEvent: class FlowAttributeChangeEvent extends CustomEvent {
            constructor(attributeName, value) {
                super('flowattributechange', {
                    detail: {
                        attributeName,
                        value
                    }
                });
            }
        }
    }),
    { virtual: true }
);

const ACCOUNT_ID = '001000000000001AAA';
const FLEET_RECORD_TYPE_ID = '012000000000002AAA';

async function flushPromises() {
    await Promise.resolve();
    await Promise.resolve();
}

function createComponent(props = {}) {
    const element = createElement('c-visit-flow-account-selector', {
        is: VisitFlowAccountSelector
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
}

describe('c-visit-flow-account-selector', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('shows source Account and CAN as read-only for Fleet visits', async () => {
        const element = createComponent({
            accountId: ACCOUNT_ID,
            accountName: 'Fleet Account',
            customerAccountNumber: 'CAN-001',
            selectedRecordTypeId: FLEET_RECORD_TYPE_ID,
            fleetRecordTypeIds: [FLEET_RECORD_TYPE_ID],
            sourceAccountLocked: true
        });
        await flushPromises();

        const inputs = element.shadowRoot.querySelectorAll('lightning-input');
        expect(inputs).toHaveLength(2);
        expect(inputs[0].value).toBe('Fleet Account');
        expect(inputs[0].disabled).toBe(true);
        expect(inputs[1].value).toBe('CAN-001');
        expect(inputs[1].disabled).toBe(true);
    });

    it('requires Account selection before Flow can continue', async () => {
        const element = createComponent({
            selectedRecordTypeId: FLEET_RECORD_TYPE_ID,
            fleetRecordTypeIds: [FLEET_RECORD_TYPE_ID]
        });
        await flushPromises();

        expect(element.validate().isValid).toBe(false);
    });

    it('emits selected Account details from record picker changes', async () => {
        getAccountInfo.mockResolvedValue({
            accountId: ACCOUNT_ID,
            name: 'Selected Account',
            customerAccountNumber: 'CAN-002'
        });
        const element = createComponent();
        const changes = [];
        element.addEventListener('flowattributechange', (event) => {
            changes.push({ name: event.detail.attributeName, value: event.detail.value });
        });
        await flushPromises();

        element.shadowRoot.querySelector('lightning-record-picker').dispatchEvent(
            new CustomEvent('change', {
                detail: { recordId: ACCOUNT_ID }
            })
        );
        await flushPromises();

        expect(getAccountInfo).toHaveBeenCalledWith({ accountId: ACCOUNT_ID });
        expect(changes).toEqual(
            expect.arrayContaining([
                { name: 'accountId', value: ACCOUNT_ID },
                { name: 'accountName', value: 'Selected Account' },
                { name: 'customerAccountNumber', value: 'CAN-002' }
            ])
        );
    });
});
