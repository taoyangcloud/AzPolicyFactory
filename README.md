
# AzPolicyFactory

**AzPolicyFactory** — Infrastructure as Code (IaC) solutions for Azure Policy resources.

## Introduction

It can be challenging to manage Azure Policy resources at scale, especially in large organizations with complex governance requirements.

AzPolicyFactory provides a comprehensive set of IaC solutions for testing, deploying and managing Azure Policy resources at scale.

By leveraging these IaC templates and pipelines, organizations can automate the deployment and management of Azure Policy resources, ensuring consistent governance across their Azure environments while reducing manual effort and the risk of misconfigurations.

This repository contains the complete set of IaC solutions for deploying Azure Policy resources, including:

- Bicep Modules for Azure Policy and supporting resources
- Bicep templates for deploying the following Azure Policy resources:
  - Policy Definitions
  - Policy Initiatives
  - Policy Assignments
  - Policy Exemptions
- Azure DevOps pipelines and GitHub Action workflows for:
  - Deploying Azure Policy Definitions, Initiatives, Assignments, and Exemptions
  - PR Validation Code Scan using GitHub Super-Linter
  - PR Validation for Azure Policy Assignment configurations between production and development environments

The solution automates the entire lifecycle of Azure Policy resources — from code commit through testing and validation to production deployment — ensuring quality and correctness at every stage.

![high-level-process](./docs/images/high-level-process.png)

## Feature Highlights

The Azure Policy IaC solution in this repository includes the following key features:

- Supports both Azure DevOps pipelines and GitHub Actions workflows for maximum flexibility and compatibility with different CI/CD platforms.
- Comprehensive set of Bicep modules and templates for deploying Azure Policy resources, following best practices for modularity, reusability, and maintainability.
- Comprehensive set of tests and validation at different stages of the CI/CD pipelines to ensure the quality and correctness of the Azure Policy resources being deployed.
- Follows industry best practices for Azure Policy management, safe deployment, code scan, and PR validation to ensure that the Azure Policy resources are deployed in a secure and compliant manner.
- Unit tests for every policy resource being deployed.
- Policy Integration Test (coming soon) to validate the functionality and effectiveness of the deployed Azure Policy resources in enforcing the desired governance and compliance requirements.

## Recommended Architectural Approach for Azure Policy IaC

A key element for any successful IaC implementation is to have a dedicated dev/test environment that mimics the production environment as closely as possible. This is especially important for Azure Policy resources because they have a direct impact on the governance and compliance of the Azure environment.

We recommend the following architectural approach for implementing Azure Policy IaC:

### Single Tenant

Many organizations have a single Microsoft Entra ID tenant, and they manage multiple Azure subscriptions under that tenant. In this case, we recommend separate Management Group hierarchies for production and development environments.

![Recommended Architectural Approach for Azure Policy IaC - Single Tenant](./docs/images/single-tenant.png)

### Multiple Tenants

Some organizations have multiple Microsoft Entra ID tenants for different environments (e.g., production, development, testing). In this case, we recommend identical Management Group hierarchies for production and development tenants for the Azure Policy IaC implementation.

![Recommended Architectural Approach for Azure Policy IaC - Multiple Tenants](./docs/images/multi-tenants.png)

## Repository Structure

The repository is organized into the following folders:

| Folder | Description |
| --- | --- |
| [`.azuredevops/`](.azuredevops/) | Azure DevOps pipeline definitions and reusable pipeline templates |
| &nbsp;&nbsp;&nbsp;&nbsp;[`pipelines/`](.azuredevops/pipelines/) | Azure DevOps pipeline YAML definitions for policy deployments and validations |
| &nbsp;&nbsp;&nbsp;&nbsp;[`templates/`](.azuredevops/templates/) | Reusable Azure DevOps pipeline stage, job, and task templates |
| [`.github/`](.github/) | GitHub-specific configurations including Actions, workflows, and linter settings |
| &nbsp;&nbsp;&nbsp;&nbsp;[`actions/`](.github/actions/) | Custom composite GitHub Actions |
| &nbsp;&nbsp;&nbsp;&nbsp;[`linters/`](.github/linters/) | Linter configuration files used by GitHub Super-Linter (e.g., codespell, textlint, PSScriptAnalyzer) |
| &nbsp;&nbsp;&nbsp;&nbsp;[`workflows/`](.github/workflows/) | GitHub Actions workflow definitions for policy deployments, PR code scans, and environment consistency checks |
| [`.ps-rule/`](.ps-rule/) | PSRule configuration and rule suppression files |
| [`.vscode/`](.vscode/) | VS Code workspace settings, recommended extensions, and script analyzer configuration |
| [`bicep/`](bicep/) | Bicep modules and deployment templates for Azure Policy resources |
| &nbsp;&nbsp;&nbsp;&nbsp;[`modules/`](bicep/modules/) | Reusable Bicep modules including authorization role assignments and user-defined types |
| &nbsp;&nbsp;&nbsp;&nbsp;[`templates/`](bicep/templates/) | Bicep deployment templates for policy definitions, initiatives, assignments, and exemptions |
| [`docs/`](docs/) | Project documentation |
| [`policyAssignments/`](policyAssignments/) | Azure Policy assignment configuration files (JSON), organized by environment |
| &nbsp;&nbsp;&nbsp;&nbsp;[`dev/`](policyAssignments/dev/) | Development environment policy assignment configuration files |
| &nbsp;&nbsp;&nbsp;&nbsp;[`prod/`](policyAssignments/prod/) | Production environment policy assignment configuration files |
| [`policyDefinitions/`](policyDefinitions/) | Custom Azure Policy definition files, organized by resource type |
| [`policyExemptions/`](policyExemptions/) | Azure Policy exemption configuration files (JSON), organized by environment |
| &nbsp;&nbsp;&nbsp;&nbsp;[`dev/`](policyExemptions/dev/) | Development environment policy exemption configuration files |
| &nbsp;&nbsp;&nbsp;&nbsp;[`prod/`](policyExemptions/prod/) | Production environment policy exemption configuration files |
| [`policyInitiatives/`](policyInitiatives/) | Azure Policy initiative (policy set) definition files |
| [`scripts/`](scripts/) | PowerShell scripts used in CI/CD pipelines and supporting utilities |
| &nbsp;&nbsp;&nbsp;&nbsp;[`pipelines/`](scripts/pipelines/) | PowerShell scripts invoked by CI/CD pipelines for deployment, validation, remediation, and resource management |
| &nbsp;&nbsp;&nbsp;&nbsp;[`support/`](scripts/support/) | Supporting utilities including PSDocs-based documentation generators |
| [`tests/`](tests/) | Pester and PSRule test files for validating Bicep templates and policy configurations |
| &nbsp;&nbsp;&nbsp;&nbsp;[`bicep/`](tests/bicep/) | Pester tests for validating Bicep templates, modules, and bicepconfig settings |
| &nbsp;&nbsp;&nbsp;&nbsp;[`policyAssignment/`](tests/policyAssignment/) | Tests for policy assignment configuration syntax validation and cross-environment consistency checks |
| &nbsp;&nbsp;&nbsp;&nbsp;[`policyExemption/`](tests/policyExemption/) | Tests for policy exemption configuration syntax validation |

## Pipeline and Workflow Overview

The repository includes the following CI/CD pipelines and GitHub Actions workflows:

| Name | :link: ADO Pipeline | :link: GitHub Action | Description |
| :--- | :----------: | :--------------------: | :---------- |
| Policy Definitions | [Link](.azuredevops/pipelines/policies/azure-pipelines-policy-definitions.yml) | [Link](.github/workflows/alz-policy-definitions.yml) | Deploys custom Azure Policy definitions to the target Azure environment |
| Policy Initiatives | [Link](.azuredevops/pipelines/policies/azure-pipelines-policy-initiatives.yml) | [Link](.github/workflows/alz-policy-initiatives.yml) | Deploys Azure Policy initiatives (policy sets) to the target Azure environment |
| Policy Assignments | [Link](.azuredevops/pipelines/policies/azure-pipelines-policy-assignments.yml) | [Link](.github/workflows/alz-policy-assignments.yml) | Deploys Azure Policy assignments based on environment-specific configuration files |
| Policy Exemptions | [Link](.azuredevops/pipelines/policies/azure-pipelines-policy-exemptions.yml) | [Link](.github/workflows/alz-policy-exemptions.yml) | Deploys Azure Policy exemptions based on environment-specific configuration files |
| PR Validation Code Scan | [Link](.azuredevops/pipelines/validation/azure-pipelines-pr-validation.yml) | [Link](.github/workflows/pr-code-scan.yml) | Runs GitHub Super-Linter to validate code quality and syntax in pull requests |
| PR Validation for Policy Assignment Consistency | [Link](.azuredevops/pipelines/validation/azure-pipelines-pr-policy-assignment-env-consistency-tests.yml) | [Link](.github/workflows/pr-policy-assignment-env-consistency.yml) | Validates that policy assignment configurations in development and production environments are consistent and do not contain unintended differences |

## Configurations

The repository includes the following configuration files:

| Name | Description |
| :--- | :---------- |
| [settings.yml](./settings.yml) | Centralized configuration file for pipeline variables and configurations |
| [ps-rule.yml](./.ps-rule/ps-rule.yml) | PSRule configuration file |
| [bicepconfig.json](./bicepconfig.json) | Bicep configuration file |
| [markdownlint.json](./.github/linters/markdownlint.json) | Markdownlint configuration file |
| [.gitignore](./.gitignore) | Git ignore file specifying untracked files and folders |
| [.ps-rule/](./.ps-rule/) | PSRule rule suppression files |
| [.vscode/](./.vscode/) | VS Code workspace settings, recommended extensions, and script analyzer configuration |
| [.github/linters/](./.github/linters/) | Linter configuration files used by GitHub Super-Linter (e.g., codespell, textlint, PSScriptAnalyzer) |

## Policy Resources

This repository includes a comprehensive set of Azure Policy resources that can be used as samples, including:

| Resource Type | Location | Description |
| :------------ | :------- | :---------- |
| Policy Definitions | [policyDefinitions/](./policyDefinitions/) | Custom Azure Policy definition files |
| Policy Initiatives | [policyInitiatives/](./policyInitiatives/) | Azure Policy initiative (policy set) definition files |
| Policy Assignments | [policyAssignments/](./policyAssignments/) | Azure Policy assignment configuration files (JSON), organized by environment |
| Policy Exemptions | [policyExemptions/](./policyExemptions/) | Azure Policy exemption configuration files (JSON), organized by environment |
