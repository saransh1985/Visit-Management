import { LightningElement, api, track } from 'lwc';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import ACTION_PLAN_NAME_FIELD from '@salesforce/schema/ActionPlan.Name';
import ACTION_PLAN_STATE_FIELD from '@salesforce/schema/ActionPlan.ActionPlanState';
import ACTION_PLAN_START_DATE_FIELD from '@salesforce/schema/ActionPlan.StartDate';
import ACTION_PLAN_TARGET_FIELD from '@salesforce/schema/ActionPlan.TargetId';
import ACTION_PLAN_TEMPLATE_VERSION_FIELD from '@salesforce/schema/ActionPlan.ActionPlanTemplateVersionId';
import VISIT_ACCOUNT_FIELD from '@salesforce/schema/Visit.AccountId';
import VISIT_NAME_FIELD from '@salesforce/schema/Visit.Name';
import VISIT_RECORD_TYPE_FIELD from '@salesforce/schema/Visit.RecordTypeId';
import VISIT_STATUS_FIELD from '@salesforce/schema/Visit.Status';
import getTaskList from '@salesforce/apex/VisitWizardV6Controller.getTaskList';
import createCustomTopic from '@salesforce/apex/VisitWizardV6Controller.createCustomTopic';
import startTask from '@salesforce/apex/VisitWizardV6Controller.startTask';
import saveTask from '@salesforce/apex/VisitWizardV6Controller.saveTask';
import getTaskNotes from '@salesforce/apex/VisitWizardV6Controller.getTaskNotes';
import saveTaskNote from '@salesforce/apex/VisitWizardV6Controller.saveTaskNote';
import getOpportunityDefaults from '@salesforce/apex/VisitWizardV6Controller.getOpportunityDefaults';
import createOpportunity from '@salesforce/apex/VisitWizardV6Controller.createOpportunity';
import getReview from '@salesforce/apex/VisitWizardV6Controller.getReview';
import completeVisit from '@salesforce/apex/VisitWizardV6Controller.completeVisit';

const ROW_ACTION_START_TASK = 'start_task';
const SCREEN_TASKS = 'tasks';
const SCREEN_TASK_DETAIL = 'task_detail';
const SCREEN_REVIEW = 'review';

export default class VisitFlowTaskRunner extends LightningElement {
    @api visitId;
    @api accountId;
    @api availableActions = [];

    @track tasks = [];
    @track taskNotes = [];
    @track opportunities = [];
    @track selectedVisitors = [];
    @track selectedContacts = [];

    screen = SCREEN_TASKS;
    activeTask;
    taskNoteTitle = '';
    taskNoteBody = '';
    loading = false;
    errorMessage = '';
    requiredTasksComplete = false;
    reviewContext;
    opportunityDefaults;
    opportunityForm = {};
    showOpportunityModal = false;
    showTopicModal = false;
    newTopicForm = {};
    _actionPlanId;
    _visitCompleted = false;
    _message = '';

    visitReviewFields = [VISIT_NAME_FIELD, VISIT_ACCOUNT_FIELD, VISIT_STATUS_FIELD, VISIT_RECORD_TYPE_FIELD];
    actionPlanReviewFields = [
        ACTION_PLAN_NAME_FIELD,
        ACTION_PLAN_STATE_FIELD,
        ACTION_PLAN_START_DATE_FIELD,
        ACTION_PLAN_TARGET_FIELD,
        ACTION_PLAN_TEMPLATE_VERSION_FIELD
    ];
    taskColumns = [
        { label: 'Topic', fieldName: 'name', wrapText: true },
        { label: 'Status', fieldName: 'displayStatus' },
        { label: 'Required', fieldName: 'requiredLabel' },
        { label: 'Completed', fieldName: 'completedLabel' },
        {
            type: 'button',
            fixedWidth: 112,
            typeAttributes: {
                label: { fieldName: 'taskActionLabel' },
                name: ROW_ACTION_START_TASK,
                variant: 'brand-outline'
            }
        }
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
    get actionPlanId() {
        return this._actionPlanId;
    }

    set actionPlanId(value) {
        this._actionPlanId = value || null;
    }

    @api
    get visitCompleted() {
        return this._visitCompleted;
    }

    set visitCompleted(value) {
        this._visitCompleted = Boolean(value);
    }

    @api
    get message() {
        return this._message;
    }

    set message(value) {
        this._message = value || '';
    }

    connectedCallback() {
        this.loadTasks();
    }

    get isTaskListScreen() {
        return this.screen === SCREEN_TASKS;
    }

    get isTaskDetailScreen() {
        return this.screen === SCREEN_TASK_DETAIL;
    }

    get isReviewScreen() {
        return this.screen === SCREEN_REVIEW;
    }

    get hasTasks() {
        return this.tasks.length > 0;
    }

    get hasActionPlan() {
        return Boolean(this.actionPlanId);
    }

    get hasTaskNotes() {
        return this.taskNotes.length > 0;
    }

    get hasPendingNote() {
        return this.hasRichTextContent(this.taskNoteBody);
    }

    get hasOpportunities() {
        return this.opportunities.length > 0;
    }

    get hasSelectedVisitors() {
        return this.selectedVisitors.length > 0;
    }

    get hasSelectedContacts() {
        return this.selectedContacts.length > 0;
    }

    get activeTaskIsSales() {
        return Boolean(this.activeTask?.salesTask);
    }

    get taskEndDateTimeMin() {
        return this.activeTask?.startDateTime || this.defaultDateTimeValue();
    }

    get taskCompleteDisabled() {
        return this.loading || !this.hasTaskCompletionInputs;
    }

    get newTopicSaveDisabled() {
        return this.loading || !this.hasValue(this.newTopicForm?.name);
    }

    get hasTaskCompletionInputs() {
        return Boolean(
            this.activeTask?.startDateTime &&
            this.activeTask?.endDateTime &&
            this.endDateIsValid(false) &&
            (this.hasTaskNotes || this.hasPendingNote)
        );
    }

    get reviewIntro() {
        return this.requiredTasksComplete
            ? 'All required topics are complete. Review the final Visit snapshot, then complete the Visit.'
            : 'Review the current Visit snapshot.';
    }

    async loadTasks() {
        if (!this.visitId) {
            this.errorMessage = 'Visit Id is required before loading tasks.';
            return;
        }

        this.loading = true;
        this.errorMessage = '';
        try {
            const response = await getTaskList({
                visitId: this.visitId,
                actionPlanId: this.actionPlanId || null
            });
            this._actionPlanId = response?.actionPlanId || this.actionPlanId || null;
            this.tasks = this.decorateTasks(response?.tasks || []);
            this.requiredTasksComplete = Boolean(response?.requiredTasksComplete);
            if (!this.hasTasks) {
                await this.loadReview();
            }
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handleTaskRowAction(event) {
        if (event.detail?.action?.name === ROW_ACTION_START_TASK) {
            this.openTask(event.detail.row);
        }
    }

    async openTask(taskRow) {
        this.loading = true;
        this.errorMessage = '';
        try {
            if (!taskRow.completed && taskRow.itemState !== 'InProgress') {
                const response = await startTask({
                    visitId: this.visitId,
                    actionPlanItemId: taskRow.actionPlanItemId,
                    genericTaskId: taskRow.genericTaskId
                });
                this.tasks = this.decorateTasks(response?.tasks || []);
                this.requiredTasksComplete = Boolean(response?.requiredTasksComplete);
            }

            const refreshedTask = this.tasks.find((task) => task.genericTaskId === taskRow.genericTaskId) || taskRow;
            this.activeTask = this.applyTaskDefaults(refreshedTask);
            this.taskNoteTitle = `${this.activeTask?.name || 'Visit Topic'} Note`;
            this.taskNoteBody = '';
            await this.loadTaskNotes(this.activeTask?.genericTaskId);
            this.screen = SCREEN_TASK_DETAIL;
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
            this.endDateIsValid(false);
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
        this.loading = true;
        try {
            await this.savePendingTaskNote();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async handleTaskSave() {
        await this.persistTask(false);
    }

    async handleTaskComplete() {
        if (!this.validateTaskCompletion()) {
            return;
        }
        await this.persistTask(true);
    }

    async persistTask(complete) {
        if (!this.activeTask) {
            return;
        }
        if (!this.endDateIsValid(complete)) {
            return;
        }

        this.loading = true;
        this.errorMessage = '';
        try {
            await this.savePendingTaskNote();
            const response = await saveTask({
                requestJson: JSON.stringify({
                    visitId: this.visitId,
                    actionPlanId: this.actionPlanId,
                    actionPlanItemId: this.activeTask.actionPlanItemId,
                    genericTaskId: this.activeTask.genericTaskId,
                    description: this.activeTask.description,
                    startDateTime: this.activeTask.startDateTime,
                    endDateTime: this.activeTask.endDateTime,
                    status: this.activeTask.status,
                    complete
                })
            });
            this._actionPlanId = response?.actionPlanId || this.actionPlanId;
            this.tasks = this.decorateTasks(response?.tasks || []);
            this.requiredTasksComplete = Boolean(response?.requiredTasksComplete);
            this.activeTask = null;
            this.screen = SCREEN_TASKS;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async savePendingTaskNote() {
        if (!this.activeTask?.genericTaskId || !this.hasPendingNote) {
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

    openTopicModal() {
        this.newTopicForm = {
            name: '',
            description: '',
            required: false
        };
        this.showTopicModal = true;
    }

    closeTopicModal() {
        this.showTopicModal = false;
    }

    handleNewTopicFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (!fieldName) {
            return;
        }
        this.newTopicForm = {
            ...this.newTopicForm,
            [fieldName]: this.getInputValue(event.target)
        };
    }

    async handleNewTopicSubmit() {
        const fields = Array.from(this.template.querySelectorAll('[data-new-topic-field]'));
        const valid = fields.reduce((isValid, field) => {
            const fieldValid = typeof field.reportValidity === 'function' ? field.reportValidity() : true;
            return isValid && fieldValid;
        }, true);
        if (!valid || !this.hasValue(this.newTopicForm?.name)) {
            return;
        }

        this.loading = true;
        this.errorMessage = '';
        try {
            const response = await createCustomTopic({
                requestJson: JSON.stringify({
                    visitId: this.visitId,
                    actionPlanId: this.actionPlanId,
                    name: this.newTopicForm.name,
                    description: this.newTopicForm.description,
                    required: this.newTopicForm.required
                })
            });
            this._actionPlanId = response?.actionPlanId || this.actionPlanId;
            this.tasks = this.decorateTasks(response?.tasks || []);
            this.requiredTasksComplete = Boolean(response?.requiredTasksComplete);
            this.showTopicModal = false;
            this.showToast('Topic Created', 'Topic added to this Visit.', 'success');
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
        await this.loadReview();
    }

    async loadReview() {
        this.loading = true;
        this.errorMessage = '';
        try {
            const context = await getReview({ visitId: this.visitId, actionPlanId: this.actionPlanId || null });
            this.reviewContext = context;
            this._actionPlanId = context?.actionPlanId || this.actionPlanId;
            this.tasks = this.decorateTasks(context?.tasks || this.tasks || []);
            this.selectedVisitors = context?.selectedVisitors || [];
            this.selectedContacts = context?.selectedContacts || [];
            this.opportunities = context?.opportunities || [];
            this.requiredTasksComplete = this.tasks.every((task) => !task.required || task.completed);
            this.screen = SCREEN_REVIEW;
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async handleCompleteVisit() {
        this.loading = true;
        this.errorMessage = '';
        try {
            const response = await completeVisit({ visitId: this.visitId, actionPlanId: this.actionPlanId || null });
            this._visitCompleted = true;
            this._message = response?.message || 'Visit completed.';
            this.dispatchEvent(new FlowAttributeChangeEvent('visitCompleted', this.visitCompleted));
            this.dispatchEvent(new FlowAttributeChangeEvent('message', this.message));
            this.showToast('Completed', this.message, 'success');
            if (this.availableActions.includes('NEXT')) {
                this.dispatchEvent(new FlowNavigationNextEvent());
            }
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async openOpportunityModal() {
        this.loading = true;
        this.errorMessage = '';
        try {
            const defaults = await getOpportunityDefaults({ visitId: this.visitId });
            this.opportunityDefaults = defaults;
            this.opportunityForm = {
                name: `${defaults?.accountName || 'Visit'} Opportunity`,
                closeDate: defaults?.closeDate,
                stageName: defaults?.stageName,
                amount: null,
                type: null,
                description: null
            };
            this.showOpportunityModal = true;
            if (defaults?.warning) {
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
        this.errorMessage = '';
        try {
            const opportunity = await createOpportunity({
                requestJson: JSON.stringify({
                    visitId: this.visitId,
                    accountId: this.opportunityDefaults?.accountId || this.accountId,
                    name: this.opportunityForm.name,
                    closeDate: this.opportunityForm.closeDate,
                    amount: this.opportunityForm.amount,
                    type: this.opportunityForm.type,
                    description: this.opportunityForm.description
                })
            });
            this.opportunities = [opportunity, ...this.opportunities];
            this.showOpportunityModal = false;
            this.showToast('Success', 'Opportunity created.', 'success');
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    decorateTasks(tasks) {
        return (tasks || []).map((task) => ({
            ...task,
            rowKey: task.genericTaskId || task.actionPlanItemId || task.name,
            displayStatus: task.status || task.itemState || 'Not Started',
            requiredLabel: task.required ? 'Yes' : 'No',
            completedLabel: task.completed ? 'Completed' : '',
            taskActionLabel: task.completed ? 'View' : 'Start'
        }));
    }

    applyTaskDefaults(task) {
        const startDateTime = task.startDateTime || this.defaultDateTimeValue();
        return {
            ...task,
            startDateTime,
            endDateTime: task.endDateTime || ''
        };
    }

    validateTaskCompletion() {
        let isValid = true;
        this.template.querySelectorAll('[data-task-field]').forEach((field) => {
            if (typeof field.reportValidity === 'function') {
                isValid = field.reportValidity() && isValid;
            }
        });
        if (!this.endDateIsValid(true)) {
            isValid = false;
        }
        if (!this.hasTaskNotes && !this.hasPendingNote) {
            this.errorMessage = 'Add a note before completing the topic.';
            isValid = false;
        }
        return isValid;
    }

    endDateIsValid(reportError) {
        const endInput = this.template.querySelector('[data-task-end]');
        if (!this.activeTask?.endDateTime || !this.activeTask?.startDateTime) {
            if (reportError && endInput?.reportValidity) {
                endInput.reportValidity();
            }
            return false;
        }

        const valid = new Date(this.activeTask.endDateTime).getTime() >= new Date(this.activeTask.startDateTime).getTime();
        if (endInput?.setCustomValidity) {
            endInput.setCustomValidity(valid ? '' : 'End Date Time must be after Start Date Time.');
            if (reportError || !valid) {
                endInput.reportValidity();
            }
        }
        return valid;
    }

    defaultDateTimeValue() {
        return new Date().toISOString();
    }

    hasRichTextContent(value) {
        return Boolean((value || '').replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').trim());
    }

    hasValue(value) {
        return value !== null && value !== undefined && value !== '' && (!Array.isArray(value) || value.length > 0);
    }

    getInputValue(input) {
        if (input.type === 'checkbox') {
            return input.checked;
        }
        return input.value;
    }

    handleError(error) {
        this.errorMessage = error?.body?.message || error?.message || 'Something went wrong in the Visit task flow.';
        this.showToast('Visit Flow Error', this.errorMessage, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    @api
    validate() {
        const isValid = Boolean(this.visitCompleted);
        return {
            isValid,
            errorMessage: isValid ? null : 'Complete the Visit from this screen before finishing the flow.'
        };
    }
}
