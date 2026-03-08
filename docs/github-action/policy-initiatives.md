# GitHub Actions Workflow for Azure Policy Initiatives

## 1. Overview

The [Policy Initiatives GitHub Actions Workflow](../../.github/workflows/policy-initiatives.yml) deploys all required custom policy initiatives to the target Azure environments.

![Policy Initiatives Workflow](../images/github-workflow-policy-initiatives.png)

The workflow consists of the following jobs:

- Initiation
- Policy Tests
- Build Dev
- Build Prod
- Test Dev
- Test Prod
- Deploy Dev
- Deploy Prod

1. After the `Initiation` job, the `Policy Tests` job performs a number of predefined Pester tests for each policy initiative file that are to be deployed.
2. The `Build Dev` and `Build Prod` jobs are kicked off concurrently upon the successful completion of the `Policy Tests` job. These jobs are responsible for building the policy definition Bicep template for the development and production environments respectively.
3. The `Test Dev` and `Test Prod` jobs are responsible for performing additional tests in their respective environments. They are kicked off after the `Build Dev` and `Build Prod` jobs respectively.
4. The `Deploy Dev` job is kicked off upon successful completion of the `Test Dev` job. It is responsible for deploying the policy definitions to the development environment.
5. The `Deploy Prod` job will only be kicked off when all the following conditions are met:
    - The `Deploy Dev` job has completed successfully.
    - The `Test Prod` job has completed successfully.
    - The workflow is triggered from the `main` branch or a git tag.

## 2. Workflow Trigger

The Policy Initiatives workflow is designed to be triggered by the following methods:

- Manually
- Upon the successful completion of the [Policy Definitions workflow](../../.github/workflows/policy-definitions.yml) when the `Deploy Prod` job is completed and the workflow is triggered from the `main` branch.

## 3. Jobs

### 3.1 Initiation

This job is the entry point of the workflow. It uses the custom action [initiation](../../.github/actions/templates/initiation/action.yml). It simply displays the current UTC time and environment variables on the agent for debugging purposes.

### 3.2 Policy Tests

This job uses the custom action [test-policy-def](../../.github/actions/templates/test-policy-def/action.yml) to perform Pester tests defined in the open-source PowerShell module [AzPolicyTest](https://www.powershellgallery.com/packages/AzPolicyTest).

The test results are summarized and written to the job summary using the custom action [parse-pester-results](../../.github/actions/templates/parse-pester-results/action.yml).

### 3.3 Build Dev and Build Prod

These jobs use the custom action [build-policy-def](../../.github/actions/templates/build-policy-def/action.yml) to populate the paths of each policy initiative JSON file and add them to the Policy Initiative Bicep template file.

These JSON files will then get loaded at compile time by the Policy Initiative bicep module using the `LoadJsonContent()` Bicep function.

The updated Bicep template file is then stored as build artifacts.

### 3.4 Test Dev and Test Prod

These jobs use the custom action [test-validate](../../.github/actions/templates/test-validate/action.yml) to perform a set of tests on the Bicep templates generated in the `Build Dev` and `Build Prod` jobs respectively.

The tests include:

- Bicep Support File tests ([BicepRequiredSupportFilesTests.ps1](../../tests/bicep/BicepRequiredSupportFilesTests.ps1))
- Bicep Linter tests by calling the `bicep build` command.
- PSRule tests
- Template deployment validation tests

The test results are summarized and written to the job summary using the custom action [parse-pester-results](../../.github/actions/templates/parse-pester-results/action.yml).

>**NOTE:** At the time of writing this document, the PSRule for Azure module does not provide any tests for policy resources. Also the ARM What-If validation does not work with policy resources (This issue has been reported on What-If's issue tracker on [GitHub](https://github.com/Azure/arm-template-whatif/issues/355)).

### 3.5 Deploy Dev

This job uses the custom action [bicep-deployment](../../.github/actions/templates/bicep-deployment/action.yml) to deploy the policy initiatives Bicep template generated from the `Build Dev` job upon successful completion of the `Test Dev` job.

The policy initiatives Bicep template does not require any parameter files.

Although only a single deployment job is created to deploy all the policy initiatives, the bicep templates are designed to create them concurrently (with up to 15 concurrent resource deployment defined in Bicep).

### 3.6 Deploy Prod

Same as the `Deploy Dev` job, this job uses the custom action [bicep-deployment](../../.github/actions/templates/bicep-deployment/action.yml).

It deploys the policy initiatives Bicep template generated from the `Build Prod` job upon successful completion of the `Test Prod` and `Deploy Dev` jobs.

The condition for this job also dictates that the workflow must be triggered from the `main` branch for this job to start.
