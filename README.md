# Automotive Cloud Visit Wizard

Salesforce DX project for an Account quick action Lightning Web Component that creates Automotive Cloud Visits with Visitors, Visited Parties, and an optional Action Plan.

## Components

- `force-app/main/default/lwc/visitWizardV4`
- `force-app/main/default/classes/VisitWizardController.cls`
- `force-app/main/default/classes/VisitWizardControllerTest.cls`

## Deploy

```powershell
sf project deploy start --source-dir force-app --target-org DTNA_Demo --test-level RunSpecifiedTests --tests VisitWizardControllerTest
```
