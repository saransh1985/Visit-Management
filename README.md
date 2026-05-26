# Visit Management

Salesforce DX project and unlocked package for the Account quick action wizard that creates Automotive Cloud Visits with Visitors, Visited Parties, and an optional Action Plan.

## Package

The released package below is the current promoted unlocked package. The V5 source and quick action are in this repo and have been deployed to the development org; create a new package version before using package install for V5 in another org.

- Package: `Visit Management`
- Released version: `1.0.0.5`
- Subscriber package version id: `04tg7000000AfY9AAK`
- Install URL: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000AfY9AAK

Install with Salesforce CLI:

```powershell
sf package install --package 04tg7000000AfY9AAK --target-org <target-org-alias> --wait 20 --publish-wait 20 --security-type AdminsOnly --no-prompt
```

## Components

- `force-app/main/default/lwc/visitWizardV4`
- `force-app/main/default/lwc/visitWizardV5`
- `force-app/main/default/classes/VisitWizardController.cls`
- `force-app/main/default/classes/VisitWizardControllerTest.cls`
- `force-app/main/default/quickActions/Account.New_Visit_V4.quickAction-meta.xml`
- `force-app/main/default/quickActions/Account.New_Visit_V5.quickAction-meta.xml`

## Requirements

- Automotive Cloud Visit Management objects are required in the target org: `Visit`, `Visitor`, and `VisitedParty`.
- Action Plans are required only when using the optional Add Action Plan flow.
- V4 is retained as the stable working wizard.
- V5 adds more standard Lightning datatables and a Visit details loading spinner.
- Add the desired packaged Account quick action to the Account Lightning page or page layout after install if it is not already visible.

## Validate Source

```powershell
sf project deploy start --source-dir force-app --target-org DTNA_Demo --test-level RunSpecifiedTests --tests VisitWizardControllerTest --dry-run
```
