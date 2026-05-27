@IsTest
@SuppressWarnings('PMD.AvoidHardcodingId,PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexDoc')
private class AutomationControlServiceTest {
    private static List<String> mockResponses = new List<String>();
    private static List<Integer> mockStatusCodes = new List<Integer>();
    private static List<String> mockEndpoints = new List<String>();
    private static Integer mockIndex = 0;

    @IsTest
    static void objectOptionsIncludeAllObjects() {
        AutomationControlService.bypassPermissionCheck = true;

        List<AutomationControlService.ObjectOption> options = AutomationControlCenterController.getObjectOptions('Account');
        List<AutomationControlService.ObjectOption> narrowOptions = AutomationControlCenterController.getObjectOptions('DefinitelyNoObject');

        System.assert(!options.isEmpty(), 'Expected object options.');
        System.assertEquals('__ALL_OBJECTS__', options[0].value, 'All Objects should stay first.');
        System.assertEquals(1, narrowOptions.size(), 'Expected only All Objects when no object matches.');
    }

    @IsTest
    static void validationRuleRowsParseToolingResponse() {
        AutomationControlService.bypassPermissionCheck = true;
        resetMock();
        mockResponses.add(queryResponse(validationRuleRecord(true)));
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlService.PageResult page = AutomationControlCenterController.getValidationRules('Account', false, 10, 1);

        System.assertEquals(1, page.rows.size(), 'Expected one validation rule row.');
        System.assertEquals('Account', page.rows[0].objectApiName);
        System.assertEquals('Require_Field', page.rows[0].metadataApiName);
        System.assertEquals(true, page.rows[0].active);
    }

    @IsTest
    static void bulkDisableValidationRulesWritesHistory() {
        AutomationControlService.bypassPermissionCheck = true;
        resetMock();
        mockResponses.add(queryResponse(validationRuleRecord(true)));
        mockResponses.add(
            compositeResponse(
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'referenceId' => 'vrGet0',
                        'httpStatusCode' => 200,
                        'body' => new Map<String, Object>{
                            'Id' => '03d000000000001AAA',
                            'Active' => true,
                            'Metadata' => new Map<String, Object>{
                                'active' => true,
                                'description' => 'Description',
                                'errorConditionFormula' => 'true',
                                'errorMessage' => 'Required'
                            }
                        }
                    }
                }
            )
        );
        mockResponses.add(
            compositeResponse(
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'referenceId' => 'vrPatch0',
                        'httpStatusCode' => 204,
                        'body' => null
                    }
                }
            )
        );
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlService.BulkActionResult result = AutomationControlCenterController.bulkDisableValidationRules('Account');

        System.assertEquals(1, result.successCount, 'Expected a successful bulk disable.');
        List<Automation_Control_History__c> histories = [
            SELECT Metadata_Type__c, Object_API_Name__c, Metadata_API_Name__c, Previous_Status__c, New_Status__c,
                Action_Type__c, Is_Reenabled__c
            FROM Automation_Control_History__c
            WHERE Batch_Id__c = :result.batchId
        ];
        System.assertEquals(1, histories.size(), 'Expected one history row.');
        System.assertEquals('Validation Rule', histories[0].Metadata_Type__c);
        System.assertEquals('Active', histories[0].Previous_Status__c);
        System.assertEquals('Inactive', histories[0].New_Status__c);
        System.assertEquals(false, histories[0].Is_Reenabled__c);
    }

    @IsTest
    static void previewAndDisableValidationRuleThroughController() {
        AutomationControlService.bypassPermissionCheck = true;
        resetMock();
        mockResponses.add(queryResponse(validationRuleRecord(true)));
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlService.BulkPreviewResult preview = AutomationControlCenterController.previewValidationRuleBulkDisable('Account');
        System.assertEquals(1, preview.affectedCount, 'Expected one validation rule in preview.');

        resetMock();
        mockResponses.add(queryResponse(validationRuleRecord(true)));
        mockResponses.add(
            compositeResponse(
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'referenceId' => 'vrGet0',
                        'httpStatusCode' => 200,
                        'body' => new Map<String, Object>{
                            'Id' => '03d000000000001AAA',
                            'Active' => true,
                            'Metadata' => new Map<String, Object>{
                                'active' => true,
                                'description' => 'Description',
                                'errorConditionFormula' => 'true',
                                'errorMessage' => 'Required'
                            }
                        }
                    }
                }
            )
        );
        mockResponses.add(
            compositeResponse(
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'referenceId' => 'vrPatch0',
                        'httpStatusCode' => 204,
                        'body' => null
                    }
                }
            )
        );
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlService.OperationResult result = AutomationControlCenterController.disableValidationRule('03d000000000001AAA');

        System.assertEquals(true, result.success, 'Expected row-level validation rule disable to succeed.');
        System.assert(mockEndpoints[1].contains('/tooling/composite'), 'Validation rule retrieve must use Tooling composite.');
        System.assert(mockEndpoints[2].contains('/tooling/composite'), 'Validation rule update must use Tooling composite.');
    }

    @IsTest
    static void controllerFlowMethodsDeactivateActiveFlow() {
        AutomationControlService.bypassPermissionCheck = true;
        resetMock();
        mockResponses.add(queryResponse(flowDefinitionRecord(true)));
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlService.PageResult page = AutomationControlCenterController.getFlows(null, 10, 1);

        System.assertEquals(1, page.rows.size(), 'Expected one flow row.');
        System.assertEquals('Account_After_Save', page.rows[0].metadataApiName);
        System.assertEquals(3, page.rows[0].activeVersionNumber);

        mockResponses.add(queryResponse(flowDefinitionRecord(true)));
        mockResponses.add(
            compositeResponse(
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'referenceId' => 'flowPatch0',
                        'httpStatusCode' => 204,
                        'body' => null
                    }
                }
            )
        );

        AutomationControlService.OperationResult result = AutomationControlCenterController.deactivateFlow('300000000000001AAA');

        System.assertEquals(true, result.success, 'Expected row-level flow deactivation to succeed.');
        System.assertEquals('Inactive', result.newStatus);

        resetMock();
        mockResponses.add(queryResponse(flowDefinitionRecord(false)));
        mockResponses.add(
            compositeResponse(
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'referenceId' => 'flowPatch0',
                        'httpStatusCode' => 204,
                        'body' => null
                    }
                }
            )
        );
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlService.OperationResult activateResult = AutomationControlCenterController.activateFlow('300000000000001AAA');

        System.assertEquals(true, activateResult.success, 'Expected row-level flow activation to succeed.');
        System.assertEquals('Active', activateResult.newStatus);
    }

    @IsTest
    static void bulkDeactivateFlowsWritesHistory() {
        AutomationControlService.bypassPermissionCheck = true;
        resetMock();
        mockResponses.add(queryResponse(flowDefinitionRecord(true)));
        mockResponses.add(
            compositeResponse(
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'referenceId' => 'flowPatch0',
                        'httpStatusCode' => 204,
                        'body' => null
                    }
                }
            )
        );
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlService.BulkPreviewResult preview = AutomationControlCenterController.previewFlowBulkDeactivate();
        System.assertEquals(1, preview.affectedCount, 'Expected one active flow in preview.');

        resetMock();
        mockResponses.add(queryResponse(flowDefinitionRecord(true)));
        mockResponses.add(
            compositeResponse(
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'referenceId' => 'flowPatch0',
                        'httpStatusCode' => 204,
                        'body' => null
                    }
                }
            )
        );
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlService.BulkActionResult result = AutomationControlCenterController.bulkDeactivateFlows();

        System.assertEquals(1, result.successCount, 'Expected a successful flow bulk deactivate.');
        System.assertEquals(1, [SELECT COUNT() FROM Automation_Control_History__c WHERE Metadata_Type__c = 'Flow']);
    }

    @IsTest
    static void historyControllerMethodsHandleEmptyBatch() {
        User automationUser = createAutomationUser();
        System.runAs(automationUser) {
            AutomationControlService.bypassPermissionCheck = true;
            insert new Automation_Control_History__c(
                Metadata_Type__c = 'Validation Rule',
                Object_API_Name__c = 'Account',
                Object_Label__c = 'Account',
                Metadata_Component_Id__c = '03d000000000001AAA',
                Metadata_API_Name__c = 'Setup_Rule',
                Metadata_Label__c = 'Setup Rule',
                Previous_Status__c = 'Active',
                New_Status__c = 'Inactive',
                Action_Type__c = 'Bulk Disable',
                Batch_Id__c = 'B-REENABLE',
                Disabled_By__c = UserInfo.getUserId(),
                Disabled_Date__c = System.now(),
                Reenabled_By__c = UserInfo.getUserId(),
                Reenabled_Date__c = System.now(),
                Is_Reenabled__c = true
            );

            List<AutomationControlService.HistoryBatch> batches = AutomationControlCenterController.getHistoryBatches('Validation Rule');
            List<AutomationControlService.OperationResult> historyRows = AutomationControlCenterController.getHistoryRows('B-REENABLE');
            System.assertEquals(1, batches.size(), 'Expected one history batch.');
            System.assertEquals(1, historyRows.size(), 'Expected one history row.');

            try {
                AutomationControlCenterController.reenableFromHistory('B-REENABLE');
                System.assert(false, 'Expected an empty batch exception.');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('No pending history rows'));
            }
        }
    }

    @IsTest
    static void rowActionGuardrailsRejectMissingAndInactiveRows() {
        AutomationControlService.bypassPermissionCheck = true;
        resetMock();
        mockResponses.add(emptyQueryResponse());
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        try {
            AutomationControlCenterController.disableValidationRule('03d000000000001AAA');
            System.assert(false, 'Expected missing validation rule error.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Validation rule was not found'));
        }

        resetMock();
        mockResponses.add(queryResponse(validationRuleRecord(false)));
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        try {
            AutomationControlCenterController.disableValidationRule('03d000000000001AAA');
            System.assert(false, 'Expected inactive validation rule error.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already inactive'));
        }

        resetMock();
        mockResponses.add(emptyQueryResponse());
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        try {
            AutomationControlCenterController.deactivateFlow('300000000000001AAA');
            System.assert(false, 'Expected missing flow error.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Flow was not found'));
        }

        resetMock();
        mockResponses.add(queryResponse(flowDefinitionRecord(false)));
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        try {
            AutomationControlCenterController.deactivateFlow('300000000000001AAA');
            System.assert(false, 'Expected inactive flow error.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already inactive'));
        }
    }

    @IsTest
    static void toolingClientSupportsRetrievePatchAndQueryMore() {
        resetMock();
        mockResponses.add(JSON.serialize(new Map<String, Object>{ 'Id' => '03d000000000001AAA', 'Active' => true }));
        mockResponses.add('');
        mockResponses.add(queryResponse(validationRuleRecord(false)));
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        AutomationControlToolingClient client = new AutomationControlToolingClient();
        Map<String, Object> record = client.retrieve('ValidationRule', '03d000000000001AAA');
        client.patch('ValidationRule', '03d000000000001AAA', new Map<String, Object>{ 'Metadata' => new Map<String, Object>{ 'active' => false } });
        AutomationControlToolingClient.QueryPage page = client.queryMore('/services/data/v60.0/tooling/query/01g000000000001-2000');

        System.assertEquals(true, record.get('Active'));
        System.assertEquals(1, page.records.size(), 'Expected queryMore to parse records.');
    }

    @IsTest
    static void toolingClientHandlesErrorsAndGuardrails() {
        System.assertEquals(
            'First | Second',
            AutomationControlToolingClient.responseMessage(
                new List<Object>{
                    new Map<String, Object>{ 'message' => 'First' },
                    new Map<String, Object>{ 'message' => 'Second' }
                }
            )
        );
        System.assertEquals('Mapped', AutomationControlToolingClient.responseMessage(new Map<String, Object>{ 'message' => 'Mapped' }));
        System.assertEquals('plain', AutomationControlToolingClient.responseMessage('plain'));
        System.assertEquals(0, new AutomationControlToolingClient().composite(new List<AutomationControlToolingClient.CompositeRequestEntry>()).size());

        List<AutomationControlToolingClient.CompositeRequestEntry> tooMany = new List<AutomationControlToolingClient.CompositeRequestEntry>();
        for (Integer index = 0; index < 26; index++) {
            tooMany.add(AutomationControlToolingClient.compositeGet('r' + index, 'ValidationRule', '03d000000000001AAA'));
        }

        try {
            new AutomationControlToolingClient().composite(tooMany);
            System.assert(false, 'Expected a composite size exception.');
        } catch (AutomationControlToolingClient.ToolingClientException e) {
            System.assert(e.getMessage().contains('at most 25'));
        }

        try {
            new AutomationControlToolingClient().queryMore('bad');
            System.assert(false, 'Expected an invalid locator exception.');
        } catch (AutomationControlToolingClient.ToolingClientException e) {
            System.assert(e.getMessage().contains('Invalid Tooling API query locator'));
        }

        resetMock();
        mockStatusCodes.add(400);
        mockResponses.add(JSON.serialize(new List<Object>{ new Map<String, Object>{ 'message' => 'Bad request' } }));
        Test.setMock(HttpCalloutMock.class, new ToolingMock());

        try {
            new AutomationControlToolingClient().retrieve('ValidationRule', '03d000000000001AAA');
            System.assert(false, 'Expected a Tooling API exception.');
        } catch (AutomationControlToolingClient.ToolingClientException e) {
            System.assert(e.getMessage().contains('Bad request'));
        }
    }

    private static String queryResponse(Map<String, Object> record) {
        return JSON.serialize(
            new Map<String, Object>{
                'totalSize' => 1,
                'done' => true,
                'records' => new List<Object>{ record }
            }
        );
    }

    private static String emptyQueryResponse() {
        return JSON.serialize(
            new Map<String, Object>{
                'totalSize' => 0,
                'done' => true,
                'records' => new List<Object>()
            }
        );
    }

    private static String compositeResponse(List<Map<String, Object>> subresponses) {
        return JSON.serialize(new Map<String, Object>{ 'compositeResponse' => subresponses });
    }

    private static Map<String, Object> validationRuleRecord(Boolean active) {
        return new Map<String, Object>{
            'Id' => '03d000000000001AAA',
            'ValidationName' => 'Require_Field',
            'Active' => active,
            'Description' => 'Description',
            'ErrorMessage' => 'Required',
            'ManageableState' => 'unmanaged',
            'LastModifiedDate' => '2026-05-27T00:00:00.000+0000',
            'EntityDefinition' => new Map<String, Object>{
                'QualifiedApiName' => 'Account',
                'MasterLabel' => 'Account'
            },
            'LastModifiedBy' => new Map<String, Object>{ 'Name' => 'Test User' }
        };
    }

    private static Map<String, Object> flowDefinitionRecord(Boolean active) {
        return new Map<String, Object>{
            'Id' => '300000000000001AAA',
            'DeveloperName' => 'Account_After_Save',
            'MasterLabel' => 'Account After Save',
            'ActiveVersionId' => active ? '301000000000003AAA' : null,
            'ManageableState' => 'unmanaged',
            'ActiveVersion' => active
                ? new Map<String, Object>{
                      'VersionNumber' => 3
                  }
                : null,
            'LatestVersion' => new Map<String, Object>{
                'VersionNumber' => 4,
                'Status' => active ? 'Active' : 'Draft',
                'ProcessType' => 'AutoLaunchedFlow',
                'LastModifiedDate' => '2026-05-27T00:00:00.000+0000',
                'LastModifiedBy' => new Map<String, Object>{ 'Name' => 'Test User' }
            }
        };
    }

    private static User createAutomationUser() {
        Profile profile = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        User user = new User(
            Alias = 'autctl',
            Email = 'automation-control@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Automation',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'automation-control-' + System.now().getTime() + '@example.com'
        );
        insert user;

        PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Name = 'Automation_Control_Center' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = user.Id, PermissionSetId = permissionSet.Id);
        return user;
    }

    private static void resetMock() {
        mockResponses.clear();
        mockStatusCodes.clear();
        mockEndpoints.clear();
        mockIndex = 0;
    }

    private class ToolingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            mockEndpoints.add(request.getEndpoint());
            HttpResponse response = new HttpResponse();
            Integer statusCode = mockIndex < mockStatusCodes.size() && mockStatusCodes[mockIndex] != null
                ? mockStatusCodes[mockIndex]
                : 200;
            response.setStatusCode(statusCode);
            response.setHeader('Content-Type', 'application/json');
            response.setBody(mockResponses[mockIndex++]);
            return response;
        }
    }
}
