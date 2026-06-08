import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getAccountTeamUsers from '@salesforce/apex/VisitFlowUserSelectorController.getAccountTeamUsers';
import getUsersByIds from '@salesforce/apex/VisitFlowUserSelectorController.getUsersByIds';
import searchActiveUsers from '@salesforce/apex/VisitFlowUserSelectorController.searchActiveUsers';

export default class VisitFlowVisitorSelector extends LightningElement {
    @api accountId;
    @api accountOwnerId;
    @api accountOwnerName;

    teamUsers = [];
    additionalUsers = [];
    selectedTeamIds = [];
    searchResults = [];
    searchTerm = '';
    errorMessage = '';
    isLoading = false;
    isSearching = false;
    _selectedAccountTeamVisitorIds = '';
    _selectedAdditionalVisitorIds = '';
    _selectedVisitorUserIds = [];

    @api
    get selectedAccountTeamVisitorIds() {
        return this._selectedAccountTeamVisitorIds;
    }

    set selectedAccountTeamVisitorIds(value) {
        this._selectedAccountTeamVisitorIds = value || '';
    }

    @api
    get selectedAdditionalVisitorIds() {
        return this._selectedAdditionalVisitorIds;
    }

    set selectedAdditionalVisitorIds(value) {
        this._selectedAdditionalVisitorIds = value || '';
    }

    @api
    get selectedVisitorUserIds() {
        return this._selectedVisitorUserIds;
    }

    set selectedVisitorUserIds(value) {
        this._selectedVisitorUserIds = Array.isArray(value) ? value : this.parseIds(value);
    }

    connectedCallback() {
        this.selectedTeamIds = this.parseIds(this.selectedAccountTeamVisitorIds);
        this.loadAccountTeam();
        this.hydrateAdditionalUsers();
        this.emitVisitorUserIds();
    }

    get hasTeamUsers() {
        return this.teamRows.length > 0;
    }

    get hasAdditionalUsers() {
        return this.additionalUsers.length > 0;
    }

    get hasSearchResults() {
        return this.searchResultRows.length > 0;
    }

    get teamRows() {
        return this.teamUsers.map((user) => {
            const isOwner = user.owner === true || user.userId === this.accountOwnerId;
            return {
                ...user,
                selected: isOwner || this.selectedTeamIds.includes(user.userId),
                disabled: isOwner,
                rowClass: isOwner ? 'owner-row' : ''
            };
        });
    }

    get searchResultRows() {
            const selectedIds = new Set([
                this.accountOwnerId,
                ...this.selectedTeamIds,
            ...this.additionalUsers.map((user) => user.userId)
        ].filter(Boolean));

        return this.searchResults.map((user) => {
            const disabled = selectedIds.has(user.userId);
            return {
                ...user,
                disabled,
                buttonLabel: disabled ? 'Added' : 'Add'
            };
        });
    }

    async loadAccountTeam() {
        if (!this.accountId) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        try {
            this.teamUsers = await getAccountTeamUsers({ accountId: this.accountId });
        } catch (error) {
            this.errorMessage = this.errorText(error);
        } finally {
            this.isLoading = false;
        }
    }

    async hydrateAdditionalUsers() {
        const userIds = this.parseIds(this.selectedAdditionalVisitorIds);
        if (!userIds.length) {
            this.additionalUsers = [];
            return;
        }

        try {
            this.additionalUsers = await getUsersByIds({ userIds });
            this.emitVisitorUserIds();
        } catch (error) {
            this.errorMessage = this.errorText(error);
        }
    }

    handleTeamSelection(event) {
        const userId = event.target.dataset.id;
        if (!userId || userId === this.accountOwnerId) {
            return;
        }

        if (event.target.checked) {
            this.selectedTeamIds = this.uniqueIds([...this.selectedTeamIds, userId]);
        } else {
            this.selectedTeamIds = this.selectedTeamIds.filter((id) => id !== userId);
        }
        this.emitSelectedTeamIds();
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSearchKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSearch();
        }
    }

    async handleSearch() {
        this.errorMessage = '';
        const trimmedTerm = (this.searchTerm || '').trim();
        if (trimmedTerm.length < 2) {
            this.searchResults = [];
            this.errorMessage = 'Enter at least two characters to search active users.';
            return;
        }

        this.isSearching = true;
        try {
            this.searchResults = await searchActiveUsers({
                searchTerm: trimmedTerm,
                excludeUserIds: this.currentVisitorIds
            });
        } catch (error) {
            this.errorMessage = this.errorText(error);
        } finally {
            this.isSearching = false;
        }
    }

    handleAddUser(event) {
        const userId = event.target.dataset.id;
        const user = this.searchResults.find((candidate) => candidate.userId === userId);
        if (!user || this.additionalUsers.some((selected) => selected.userId === userId)) {
            return;
        }

        this.additionalUsers = [...this.additionalUsers, user];
        this.emitAdditionalUserIds();
    }

    handleRemoveUser(event) {
        const userId = event.currentTarget.dataset.id;
        this.additionalUsers = this.additionalUsers.filter((user) => user.userId !== userId);
        this.emitAdditionalUserIds();
    }

    emitSelectedTeamIds() {
        const value = this.selectedTeamIds.join(';');
        this._selectedAccountTeamVisitorIds = value;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedAccountTeamVisitorIds', value));
        this.emitVisitorUserIds();
    }

    emitAdditionalUserIds() {
        const value = this.additionalUsers.map((user) => user.userId).join(';');
        this._selectedAdditionalVisitorIds = value;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedAdditionalVisitorIds', value));
        this.emitVisitorUserIds();
    }

    emitVisitorUserIds() {
        const value = this.currentVisitorIds;
        this._selectedVisitorUserIds = value;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedVisitorUserIds', value));
    }

    get currentVisitorIds() {
        return this.uniqueIds([
            this.accountOwnerId,
            ...this.selectedTeamIds,
            ...this.additionalUsers.map((user) => user.userId)
        ]);
    }

    parseIds(value) {
        const matches = String(value || '').match(/005[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?/g) || [];
        return this.uniqueIds(matches);
    }

    uniqueIds(ids) {
        return [...new Set(ids.filter(Boolean))];
    }

    errorText(error) {
        return error?.body?.message || error?.message || 'Something went wrong while loading visitors.';
    }

    @api
    validate() {
        return { isValid: true };
    }
}
