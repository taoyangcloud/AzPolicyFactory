# Azure Policy Factory — Documentation

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

## Setup Guides

- [Setup Guide for Azure DevOps Pipelines](ado-pipelines/setup-guide.md)
- [Setup Guide for GitHub Actions Workflows](github-action/setup-guide.md)
- [Add Policy Resources to the Repository](add-policy-resources.md)
- [Policy Assignment Environment Consistency Tests](assignment-environment-consistency-tests.md)

## FAQs

- [Frequently Asked Questions](FAQ.md)

