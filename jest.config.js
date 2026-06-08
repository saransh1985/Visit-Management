const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        ...jestConfig.moduleNameMapper,
        '^c/visitWizardV6$': '<rootDir>/visit-management-v6-package/main/default/lwc/visitWizardV6/visitWizardV6'
    }
};
