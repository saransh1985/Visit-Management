import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getAccountContacts from '@salesforce/apex/VisitFlowVisitedPartySelectorController.getAccountContacts';

export default class VisitFlowVisitedPartySelector extends LightningElement {
    @api accountId;

    contacts = [];
    selectedIds = [];
    isLoading = false;
    errorMessage = '';

    @api
    get selectedVisitedContactIds() {
        return this.selectedIds;
    }

    set selectedVisitedContactIds(value) {
        this.selectedIds = Array.isArray(value) ? value : this.parseIds(value);
    }

    connectedCallback() {
        this.loadContacts();
    }

    get hasContacts() {
        return this.contacts.length > 0;
    }

    get contactRows() {
        return this.contacts.map((contact) => ({
            ...contact,
            selected: this.selectedIds.includes(contact.contactId)
        }));
    }

    async loadContacts() {
        if (!this.accountId) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        try {
            this.contacts = await getAccountContacts({ accountId: this.accountId });
        } catch (error) {
            this.errorMessage = this.errorText(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSelection(event) {
        const contactId = event.target.dataset.id;
        if (!contactId) {
            return;
        }

        if (event.target.checked) {
            this.selectedIds = this.uniqueIds([...this.selectedIds, contactId]);
        } else {
            this.selectedIds = this.selectedIds.filter((id) => id !== contactId);
        }
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedVisitedContactIds', this.selectedIds));
    }

    parseIds(value) {
        const matches = String(value || '').match(/003[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?/g) || [];
        return this.uniqueIds(matches);
    }

    uniqueIds(ids) {
        return [...new Set(ids.filter(Boolean))];
    }

    errorText(error) {
        return error?.body?.message || error?.message || 'Something went wrong while loading contacts.';
    }

    @api
    validate() {
        const isValid = this.selectedIds.length > 0;
        return {
            isValid,
            errorMessage: isValid ? null : 'Select at least one visited party before finishing.'
        };
    }
}
