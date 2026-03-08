# AzPolicyFactory — Documentation

## Supported Platforms

The following DevOps / CICD platforms are supported:

- [Azure DevOps](https://azure.microsoft.com/products/devops)
- [GitHub Actions](https://github.com/features/actions)

## Azure DevOps Pipelines and GitHub Actions Workflows

| Name | :memo: ADO Pipeline | :memo: GitHub Action | Description |
| :--- | :----------: | :--------------------: | :---------- |
| Policy Definitions | [Documentation](ado-pipelines/policy-definitions.md) | [Documentation](github-action/policy-definitions.md) | Deploys custom Azure Policy definitions to the target Azure environment |
| Policy Initiatives | [Documentation](ado-pipelines/policy-initiatives.md) | [Documentation](github-action/policy-initiatives.md) | Deploys Azure Policy initiatives (policy sets) to the target Azure environment |
| Policy Assignments | [Documentation](ado-pipelines/policy-assignments.md) | [Documentation](github-action/policy-assignments.md) | Deploys Azure Policy assignments based on environment-specific configuration files |
| Policy Exemptions | [Documentation](ado-pipelines/policy-exemptions.md) | [Documentation](github-action/policy-exemptions.md) | Deploys Azure Policy exemptions based on environment-specific configuration files |
| PR Validation Code Scan | [Documentation](ado-pipelines/pr-validation.md) | [Documentation](github-action/pr-code-scan.md) | Runs GitHub Super-Linter to validate code quality and syntax in pull requests |
| PR Validation for Policy Assignment Consistency | [Documentation](ado-pipelines/pr-policy-assignment-env-consistency.md) | [Documentation](github-action/pr-policy-assignment-env-consistency.md) | Validates that policy assignment configurations in development and production environments are consistent and do not contain unintended differences |

## Instructions

- [Setup Guide for Azure DevOps Pipelines](ado-pipelines/setup-guide.md)
- [Setup Guide for GitHub Actions Workflows](github-action/setup-guide.md)
- [Add Policy Resources to the Repository](add-policy-resources.md)
- [Policy Assignment Environment Consistency Tests](assignment-environment-consistency-tests.md)
- [How to generate documentations for Bicep templates and modules](generate-bicep-docs.md)

## FAQs

- [Frequently Asked Questions](FAQ.md)


## Repository Structure

The repository is organized into the following folders:

| Folder | Description |
| --- | --- |
| [`.azuredevops/`](../.azuredevops/) | Azure DevOps pipeline definitions and reusable pipeline templates |
| &nbsp;&nbsp;&nbsp;&nbsp;[`pipelines/`](../.azuredevops/pipelines/) | Azure DevOps pipeline YAML definitions for policy deployments and validations |
| &nbsp;&nbsp;&nbsp;&nbsp;[`templates/`](../.azuredevops/templates/) | Reusable Azure DevOps pipeline stage, job, and task templates |
| [`.github/`](../.github/) | GitHub-specific configurations including Actions, workflows, and linter settings |
| &nbsp;&nbsp;&nbsp;&nbsp;[`actions/`](../.github/actions/) | Custom composite GitHub Actions |
| &nbsp;&nbsp;&nbsp;&nbsp;[`linters/`](../.github/linters/) | Linter configuration files used by GitHub Super-Linter (e.g., codespell, textlint, PSScriptAnalyzer) |
| &nbsp;&nbsp;&nbsp;&nbsp;[`workflows/`](../.github/workflows/) | GitHub Actions workflow definitions for policy deployments, PR code scans, and environment consistency checks |
| [`.ps-rule/`](../.ps-rule/) | PSRule configuration and rule suppression files |
| [`.vscode/`](../.vscode/) | Visual Studio Code workspace settings, recommended extensions, and script analyzer configuration |
| [`bicep/`](../bicep/) | Bicep modules and deployment templates for Azure Policy resources |
| &nbsp;&nbsp;&nbsp;&nbsp;[`modules/`](../bicep/modules/) | Reusable Bicep modules including authorization role assignments and user-defined types |
| &nbsp;&nbsp;&nbsp;&nbsp;[`templates/`](../bicep/templates/) | Bicep deployment templates for policy definitions, initiatives, assignments, and exemptions |
| [`docs/`](../docs/) | Project documentation |
| [`policyAssignments/`](../policyAssignments/) | Azure Policy assignment configuration files (JSON), organized by environment |
| &nbsp;&nbsp;&nbsp;&nbsp;[`dev/`](../policyAssignments/dev/) | Development environment policy assignment configuration files |
| &nbsp;&nbsp;&nbsp;&nbsp;[`prod/`](../policyAssignments/prod/) | Production environment policy assignment configuration files |
| [`policyDefinitions/`](../policyDefinitions/) | Custom Azure Policy definition files, organized by resource type |
| [`policyExemptions/`](../policyExemptions/) | Azure Policy exemption configuration files (JSON), organized by environment |
| &nbsp;&nbsp;&nbsp;&nbsp;[`dev/`](../policyExemptions/dev/) | Development environment policy exemption configuration files |
| &nbsp;&nbsp;&nbsp;&nbsp;[`prod/`](../policyExemptions/prod/) | Production environment policy exemption configuration files |
| [`policyInitiatives/`](../policyInitiatives/) | Azure Policy initiative (policy set) definition files |
| [`scripts/`](../scripts/) | PowerShell scripts used in CI/CD pipelines and supporting utilities |
| &nbsp;&nbsp;&nbsp;&nbsp;[`pipelines/`](../scripts/pipelines/) | PowerShell scripts invoked by CI/CD pipelines for deployment, validation, remediation, and resource management |
| &nbsp;&nbsp;&nbsp;&nbsp;[`support/`](../scripts/support/) | Supporting utilities including PSDocs-based documentation generators |
| [`tests/`](../tests/) | Pester and PSRule test files for validating Bicep templates and policy configurations |
| &nbsp;&nbsp;&nbsp;&nbsp;[`bicep/`](../tests/bicep/) | Pester tests for validating Bicep templates, modules, and bicepconfig settings |
| &nbsp;&nbsp;&nbsp;&nbsp;[`policyAssignment/`](../tests/policyAssignment/) | Tests for policy assignment configuration syntax validation and cross-environment consistency checks |
| &nbsp;&nbsp;&nbsp;&nbsp;[`policyExemption/`](../tests/policyExemption/) | Tests for policy exemption configuration syntax validation |

## Pipeline and Workflow Overview

The repository includes the following CI/CD pipelines and GitHub Actions workflows:

| Name | :link: ADO Pipeline | :link: GitHub Action | Description |
| :--- | :----------: | :--------------------: | :---------- |
| Policy Definitions | [Link](../.azuredevops/pipelines/policies/azure-pipelines-policy-definitions.yml) | [Link](../.github/workflows/alz-policy-definitions.yml) | Deploys custom Azure Policy definitions to the target Azure environment |
| Policy Initiatives | [Link](../.azuredevops/pipelines/policies/azure-pipelines-policy-initiatives.yml) | [Link](../.github/workflows/alz-policy-initiatives.yml) | Deploys Azure Policy initiatives (policy sets) to the target Azure environment |
| Policy Assignments | [Link](../.azuredevops/pipelines/policies/azure-pipelines-policy-assignments.yml) | [Link](../.github/workflows/alz-policy-assignments.yml) | Deploys Azure Policy assignments based on environment-specific configuration files |
| Policy Exemptions | [Link](../.azuredevops/pipelines/policies/azure-pipelines-policy-exemptions.yml) | [Link](../.github/workflows/alz-policy-exemptions.yml) | Deploys Azure Policy exemptions based on environment-specific configuration files |
| PR Validation Code Scan | [Link](../.azuredevops/pipelines/validation/azure-pipelines-pr-validation.yml) | [Link](../.github/workflows/pr-code-scan.yml) | Runs GitHub Super-Linter to validate code quality and syntax in pull requests |
| PR Validation for Policy Assignment Consistency | [Link](../.azuredevops/pipelines/validation/azure-pipelines-pr-policy-assignment-env-consistency-tests.yml) | [Link](../.github/workflows/pr-policy-assignment-env-consistency.yml) | Validates that policy assignment configurations in development and production environments are consistent and do not contain unintended differences |

## Configurations

The repository includes the following configuration files:

| Name | Description |
| :--- | :---------- |
| [settings.yml](../settings.yml) | Centralized configuration file for pipeline variables and configurations |
| [ps-rule.yml](../.ps-rule/ps-rule.yml) | PSRule configuration file |
| [bicepconfig.json](../bicepconfig.json) | Bicep configuration file |
| [markdownlint.json](../.github/linters/markdownlint.json) | Markdownlint configuration file |
| [.gitignore](../.gitignore) | Git ignore file specifying untracked files and folders |
| [.ps-rule/](../.ps-rule/) | PSRule rule suppression files |
| [.vscode/](../.vscode/) | Visual Studio Code workspace settings, recommended extensions, and script analyzer configuration |
| [.github/linters/](../.github/linters/) | Linter configuration files used by GitHub Super-Linter (e.g., codespell, textlint, PSScriptAnalyzer) |

## Policy Resources

This repository includes a comprehensive set of Azure Policy resources that can be used as samples, including:

| Resource Type | Location | Description |
| :------------ | :------- | :---------- |
| Policy Definitions | [policyDefinitions/](../policyDefinitions/) | Custom Azure Policy definition files |
| Policy Initiatives | [policyInitiatives/](../policyInitiatives/) | Azure Policy initiative (policy set) definition files |
| Policy Assignments | [policyAssignments/](../policyAssignments/) | Azure Policy assignment configuration files (JSON), organized by environment |
| Policy Exemptions | [policyExemptions/](../policyExemptions/) | Azure Policy exemption configuration files (JSON), organized by environment |
