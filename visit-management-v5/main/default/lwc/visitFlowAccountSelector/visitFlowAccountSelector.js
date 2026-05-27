import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getAccountInfo from '@salesforce/apex/VisitWizardController.getAccountInfo';

const ACCOUNT_CAN_FIELD = 'Customer_Account_Number_CAN__c';

export default class VisitFlowAccountSelector extends LightningElement {
    @api selectedRecordTypeId;
    @api sourceAccountLocked = false;
    accountPickerDisplayInfo = {
        primaryField: 'Name',
        additionalFields: [ACCOUNT_CAN_FIELD]
    };
    accountPickerMatchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: ACCOUNT_CAN_FIELD }]
    };

    _accountId;
    _accountName;
    _customerAccountNumber;
    _fleetRecordTypeIds = [];

    @api
    get accountId() {
        return this._accountId;
    }

    set accountId(value) {
        this._accountId = value;
    }

    @api
    get accountName() {
        return this._accountName;
    }

    set accountName(value) {
        this._accountName = value;
    }

    @api
    get customerAccountNumber() {
        return this._customerAccountNumber;
    }

    set customerAccountNumber(value) {
        this._customerAccountNumber = value;
    }

    @api
    get fleetRecordTypeIds() {
        return this._fleetRecordTypeIds;
    }

    set fleetRecordTypeIds(value) {
        this._fleetRecordTypeIds = Array.isArray(value)
            ? value
            : String(value || '')
                  .split(',')
                  .map((item) => item.trim())
                  .filter((item) => item);
    }

    connectedCallback() {
        if (this.accountId && (!this.accountName || this.customerAccountNumber === undefined)) {
            this.hydrateAccount(this.accountId);
        }
    }

    get accountDisplayValue() {
        return this.accountName || this.accountId;
    }

    get showCustomerAccountNumber() {
        return this._fleetRecordTypeIds.includes(this.selectedRecordTypeId);
    }

    async handleAccountChange(event) {
        const accountId = event.detail?.recordId || event.detail?.value;
        await this.hydrateAccount(accountId);
    }

    async hydrateAccount(accountId) {
        this._accountId = accountId;
        this.emitChange('accountId', this._accountId);
        if (!accountId) {
            this._accountName = null;
            this._customerAccountNumber = null;
            this.emitChange('accountName', this._accountName);
            this.emitChange('customerAccountNumber', this._customerAccountNumber);
            return;
        }

        const accountInfo = await getAccountInfo({ accountId });
        this._accountName = accountInfo?.name;
        this._customerAccountNumber = accountInfo?.customerAccountNumber;
        this.emitChange('accountName', this._accountName);
        this.emitChange('customerAccountNumber', this._customerAccountNumber);
    }

    emitChange(name, value) {
        this.dispatchEvent(new FlowAttributeChangeEvent(name, value));
    }

    @api
    validate() {
        if (this.accountId) {
            return { isValid: true };
        }

        const picker = this.template.querySelector('lightning-record-picker');
        if (picker && typeof picker.reportValidity === 'function') {
            picker.reportValidity();
        }
        return {
            isValid: false,
            errorMessage: 'Select an Account before continuing.'
        };
    }
}
