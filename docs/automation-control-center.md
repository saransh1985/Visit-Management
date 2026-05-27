# Automation Control Center

## Recommended Architecture

Automation Control Center is a Lightning admin app for governed, reversible automation shutdowns. The app uses LWC for the console, Apex for authorization, orchestration, history writes, and partial-success handling, and Salesforce Tooling API callouts for metadata reads and activation changes.

The app is intentionally history-first:

- Row-level actions can disable one active validation rule or deactivate one active flow.
- Bulk actions create `Automation_Control_History__c` rows with a shared `Batch_Id__c`.
- Re-enable is only available from a tracked bulk-disable batch.
- Re-enable skips anything outside the selected batch and does not use an unscoped "turn everything back on" operation.

The source currently includes a synchronous implementation with a guardrail of 250 active items per bulk action. For very large production orgs, keep the same service contract and move execution to chained Queueable Apex or a Batch Apex coordinator that processes Tooling API pages in chunks and publishes progress.

## Data Model

`Automation_Control_History__c` stores one audit row per attempted bulk item.

Core fields:

- `Metadata_Type__c`: `Validation Rule` or `Flow`
- `Object_API_Name__c`, `Object_Label__c`: populated for validation rules
- `Metadata_Component_Id__c`: Tooling API component Id
- `Metadata_API_Name__c`, `Metadata_Label__c`
- `Previous_Status__c`, `New_Status__c`
- `Previous_Version_Number__c`: prior active Flow version
- `Action_Type__c`: `Bulk Disable` or `Bulk Re-enable`
- `Batch_Id__c`
- `Disabled_By__c`, `Disabled_Date__c`
- `Reenabled_By__c`, `Reenabled_Date__c`, `Is_Reenabled__c`
- `Error_Message__c`
- `Metadata_Backup_JSON__c`

## LWC Structure

`automationControlCenter` is exposed as a Lightning tab and contains:

- Validation Rules Manager
- Flows Manager
- Bulk preview modal
- History batch picker
- Re-enable preview and confirmation flow

Each manager supports pagination, lazy reload, row-level active toggles, bulk preview, and explicit confirmation before writes.

## Apex Class Design

- `AutomationControlCenterController`: `@AuraEnabled` facade for LWC.
- `AutomationControlService`: authorization checks, DTOs, SOQL construction, Tooling API orchestration, history DML, re-enable guardrails.
- `AutomationControlToolingClient`: small REST client for Tooling API query, queryMore, retrieve, PATCH, and Composite API partial-success calls.

## Metadata and Tooling API Approach

Validation rules:

- Query `ValidationRule` using Tooling API.
- Read top-level fields for list views.
- Retrieve the single rule metadata before update because the `Metadata` field is only safe to query/retrieve one component at a time.
- Patch `ValidationRule.Metadata.active`.

Flows:

- Query `FlowDefinition` and its `ActiveVersion` and `LatestVersion` relationships.
- Deactivate by patching `FlowDefinition.Metadata.activeVersionNumber` to `0`.
- Re-enable by restoring the captured `Previous_Version_Number__c`.

## UI Wireframe

Validation Rules Manager:

- Object search
- Object picker with `All Objects`
- `Show Disabled Validation Rules`
- Refresh
- Preview Bulk Disable
- Re-enable from History
- Paginated table with object, rule, description, error message, status, last modified, and action toggle

Flows Manager:

- Flow search
- Search
- Preview Bulk Deactivate
- Re-enable from History
- Paginated table with label, API name, type, active version, latest version, status, last modified, and action toggle

Bulk flow:

1. Click preview.
2. Review affected items.
3. Confirm in modal.
4. Confirm again in the platform confirmation dialog.
5. Results are written to history and summarized by toast.

## Implementation Plan

1. Deploy the custom object, fields, custom permission, app, tab, LWC, Apex, Visualforce session bridge, and Named Credential.
2. Confirm the `Automation_Control_Center` Named Credential points to the org My Domain URL.
3. Assign the `Automation Control Center` permission set only to approved admins.
4. Open the app and validate read-only lists first.
5. Test row-level disable in a sandbox.
6. Test bulk disable on one object.
7. Test re-enable from the generated batch.
8. Expand use to all objects only after sandbox validation.

## Security Model

Access is gated by the `Manage_Automation_Control_Center` custom permission. The permission set grants:

- App visibility
- Tab visibility
- Apex class access
- History object read/create/edit
- Custom permission assignment
- API Enabled and View Setup and Configuration

The deployed org setup uses the Named Credential for the My Domain endpoint and the `AutomationControlSession` Visualforce page to obtain an API-capable session for the current authorized admin. This avoids storing OAuth client secrets in source and preserves user-level auditability, but it is only appropriate for synchronous admin UI actions. If the org allows Connected App creation, a Salesforce Auth Provider plus OAuth Named Credential remains the preferred long-term configuration.

## Testing Strategy

Unit tests should cover:

- Permission denial.
- Object option filtering.
- Validation rule list parsing from mocked Tooling API responses.
- Flow list parsing from mocked Tooling API responses.
- Row-level disable/deactivate success and failure.
- Bulk partial success.
- History records inserted only for bulk actions.
- Re-enable only from matching batch rows.
- Flow re-enable skips a flow that is already active.
- Managed package metadata failure messages.

Manual sandbox tests should cover:

- All Objects with active-only default.
- Show disabled behavior.
- A validation rule that was inactive before a bulk action.
- Flow with no active version.
- Flow with a newer draft latest version.
- Managed package validation rules and flows.

## Known Limitations and Risks

- The current synchronous implementation caps bulk actions at 250 active items to stay inside callout, CPU, and response limits.
- Validation rules do not have a separate label field in Tooling API; the UI displays the rule name as label.
- Flow versioning is nuanced. Deactivation clears the active version number; re-enable restores the captured version number.
- If a flow has been manually activated after the bulk deactivate, the app skips re-enable rather than overwriting that later admin action.
- Managed package components can be visible but not editable.
- Flow activation in production can be affected by org settings and flow test coverage requirements for some flow/process types.
- OAuth Named Credential setup is org-specific. In orgs where Connected App creation is blocked, use the deployed endpoint-only Named Credential plus the Visualforce session bridge.

## Deployment Considerations

- Deploy to sandbox first.
- Confirm the `Automation_Control_Center` Named Credential endpoint matches the target org My Domain before opening the app.
- Assign access by permission set, not profile.
- Keep Setup Audit Trail and Field History Tracking enabled for audit review.
- Consider extending the service to async Queueable processing before enabling whole-org bulk actions in very large orgs.
