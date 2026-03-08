# Policy Assignment Environment Consistency Tests

## Table of Contents

- [Policy Assignment Environment Consistency Tests](#policy-assignment-environment-consistency-tests)
  - [Table of Contents](#table-of-contents)
  - [Background](#background)
  - [How It Works](#how-it-works)
  - [PR Policy Assignment Environment Consistency Tests ADO Pipeline and GitHub Actions Workflow](#pr-policy-assignment-environment-consistency-tests-ado-pipeline-and-github-actions-workflow)
  - [Configurations](#configurations)
    - [targetScopeMapping](#targetscopemapping)
    - [interchangeableParameterValues](#interchangeableparametervalues)
    - [allowedParameterValueDeviations](#allowedparametervaluedeviations)
    - [environmentSpecificValues](#environmentspecificvalues)
    - [assignmentNotScopeExclusions](#assignmentnotscopeexclusions)
    - [assignmentNotScopeDeviations](#assignmentnotscopedeviations)

## Background

Unlike Policy Definitions and Initiatives which are identical across environments, policy assignment configurations differ per environment — they target different scopes and may have different parameter values. Consistency tests ensure that production assignment changes are intentional and properly reviewed before being merged into the main branch.

## How It Works

The test iterates over every production policy assignment configuration file (`policyAssignments/prod/`), finds its corresponding development counterpart (`policyAssignments/dev/`) by matching on the mapped policy definition ID, target scope, and NotScopes, and then compares parameters between the two.

Differences are only allowed when explicitly configured in the test configuration file (e.g., via interchangeable parameter values, allowed deviations, or environment-specific values). The tests are written in [Pester](https://pester.dev/) and can be run locally:

```powershell
Invoke-Pester -Path './tests/policyAssignment/environment-consistency/prd.assignment.configurations.tests.ps1' \
  -Data @{
    prodConfigurationFilesPath = './policyAssignments/prod'
    devConfigurationFilesPath  = './policyAssignments/dev'
  }
```

## PR Policy Assignment Environment Consistency Tests ADO Pipeline and GitHub Actions Workflow

The PR Policy Assignment Environment Consistency Tests is implemented as both an Azure DevOps Pipeline and a GitHub Actions Workflow to provide flexibility and options for different teams and organizations to choose the CI/CD platform that best fits their needs and preferences.

For details on the implementation and configuration of the PR Policy Assignment Environment Consistency Tests in both platforms, please refer to the following documentation:

- [Setup Guide for Azure DevOps Pipelines](./ado-pipelines/setup-guide.md)
- [Setup Guide for GitHub Actions Workflows](./github-action/setup-guide.md)

## Configurations

Before using the PR Policy Assignment Environment Consistency Tests, you need to customize the test configuration file [./tests/policyAssignment/environment-consistency/assignment_configuration_consistency_test_config.jsonc](../tests/policyAssignment/environment-consistency/assignment_configuration_consistency_test_config.jsonc).

> :bulb: **NOTE:** The configuration file uses **JSONC** format (JSON with Comments). Standard JSON parsers will reject it — PowerShell's `ConvertFrom-Json` handles it natively.

The configuration file contains the following properties:

| Property | Purpose |
|---|---|
| `targetScopeMapping` | Maps target scopes (management groups, subscriptions, resource groups) between environments |
| `interchangeableParameterValues` | Defines groups of parameter values treated as equivalent across environments |
| `allowedParameterValueDeviations` | Lists specific parameter value differences that are expected per assignment |
| `environmentSpecificValues` | Maps environment-specific resource IDs (e.g., Log Analytics workspace) |
| `assignmentNotScopeExclusions` | NotScope values to ignore globally during comparison |
| `assignmentNotScopeDeviations` | NotScope differences allowed for specific assignments |

### targetScopeMapping

The `targetScopeMapping` property defines the mapping of target scopes between environments. For example:

```json
"targetScopeMapping": {
  /*
  mapping for management groups. the key is just a description of the target scope.
  within the child object, each key is the name of the environment and the value is the management group name in that environment.
  */
  "managementGroup": {
    "landing-zone-root": {
      "development": "CONTOSO-DEV",
      "production": "CONTOSO"
    }
  },
  /*
  mapping for subscriptions. the key is just a description of the target scope.
  within the child object, each key is the name of the environment and the value is the subscription id in that environment.
  */
  "subscription": {
    "management": {
      "development": "f27ab1cb-9c1a-4bdb-9e18-bb11ec9205db",
      "production": "fca82a86-9abc-4ef3-8628-cd6e3e426325"
    }
  },
  /*
  mapping for resource groups. the key is just a description of the target scope.
  within the child object, each key is the name of the environment and the value is the resource id of the resource group in that environment.
  */
  "resourceGroup": {
    "connectivity-network-rg": {
      "development": "/subscriptions/3cea5943-a7f2-4991-ba22-19e240671e63/resourceGroups/rg-ae-d-net-hub",
      "production": "/subscriptions/b92da35a-73a9-4554-8711-f6af2342fb52/resourceGroups/rg-ae-p-net-hub"
    }
  }
}
```

As shown in the above example, when the landing zone root management group is specified as `CONTOSO-DEV` for the development environment, the test expects the corresponding target scope for the production environment to be `CONTOSO`.

When a subscription ID for the management subscription in the development environment is specified as `f27ab1cb-9c1a-4bdb-9e18-bb11ec9205db`, the test expects the corresponding target scope for the production environment to be `fca82a86-9abc-4ef3-8628-cd6e3e426325`, or the test will fail.

When a resource group with the resource ID of `/subscriptions/3cea5943-a7f2-4991-ba22-19e240671e63/resourceGroups/rg-ae-d-net-hub` is specified for the development environment, the test expects the corresponding target scope for the production environment to be `/subscriptions/b92da35a-73a9-4554-8711-f6af2342fb52/resourceGroups/rg-ae-p-net-hub`, or the test will fail.

You need to update the values in the mapping based on your specific landing zone management group naming convention and structure.

### interchangeableParameterValues

The `interchangeableParameterValues` property defines the parameter values that can be different between environments. This caters for scenarios where different policy effects are applied in different environments.

All values within the same group are treated as equivalent — if the production assignment uses any value from the group and the development assignment uses any other value from the same group, the test passes.

For example:

```json
"interchangeableParameterValues": {
  "dinePolicyEffects": [
    "Disabled",
    "DeployIfNotExists"
  ],
  "ainePolicyEffects": [
    "Disabled",
    "AuditIfNotExists"
  ],
  "auditDenyEffects": [
    "Disabled",
    "Audit",
    "Deny"
  ],
  "appendEffects": [
    "Disabled",
    "Append"
  ],
  "modifyEffects": [
    "Disabled",
    "Modify"
  ]
}
```

In the above example, the test will not fail if a development policy assignment has specified a policy effect of `DeployIfNotExists` while the corresponding production policy assignment has specified a policy effect of `Disabled` (or vice versa) as both values are included in the list of interchangeable values for the `dinePolicyEffects` parameter.

### allowedParameterValueDeviations

This section defines the allowed parameter value deviations between environments for specific policy assignments. This caters for scenarios where certain parameter values are expected to be different between environments due to differences in environment configurations and settings.

> :bulb: **NOTE:** The `sourceAssignmentName` refers to the **production** policy assignment name (the test iterates over production assignments and looks up their development counterparts).

For example, the tag values for the tagging policy assignment may be different between environments as the resources in the production environment may have different tag values compared to the development environment. In this case, you can specify the allowed tag value deviations for the tagging policy assignment as shown below:

```json
//Define allowed deviations for the parameter values used in the assignments
"allowedParameterValueDeviations": [
  {
    "sourceAssignmentName": "pa-p-ro-tags-prod",
    "sourceAssignmentScopeName": "CONTOSO",
    "parameterName": "platform-environment_TagValue",
    "sourceParameterValue": "Production",
    "correspondingParameterValue": "Development",
    "deviationReason": "tag value for the environment is different."
  }
]
```

Or, if the allowed service tags used in the NSG rules are different between environments because the production environment may allow more service tags compared to the development environment, you can specify the allowed service tag value deviations for the NSG rules in the network policy assignment as shown below:

```json
//Define allowed deviations for the parameter values used in the assignments
"allowedParameterValueDeviations": [
  {
    "sourceAssignmentName": "pa-p-nsg",
    "sourceAssignmentScopeName": "CONTOSO",
    "parameterName": "nsgAllowedInboundServiceTags",
    "sourceParameterValue": [
      "VirtualNetwork",
      "AzureLoadBalancer",
      "Internet",
      "GatewayManager",
      "ApplicationInsightsAvailability",
      "*"
    ],
    "correspondingParameterValue": [
      "VirtualNetwork",
      "AzureLoadBalancer",
      "Internet",
      "GatewayManager",
      "ApplicationInsightsAvailability",
      "*"
    ],
    "deviationReason": "The additional service tags are required for the Policy Integration test for ADF policies."
  }
]
```

### environmentSpecificValues

The `environmentSpecificValues` property defines environment-specific values for the parameters used in the assignments (i.e. Azure resource IDs specific to each environment).

For example, the Log Analytics Workspace Resource ID used for the Diagnostic Settings in the policy assignment may be different between environments as the production environment may have a different Log Analytics Workspace compared to the development environment. In this case, you can specify the environment specific values for the Log Analytics Workspace Resource ID as shown below:

```json
"environmentSpecificValues": {
  "logAnalyticsWorkspace": {
    "development": [
      "/subscriptions/f27ab1cb-9c1a-4bdb-9e18-bb11ec9205db/resourcegroups/rg-ae-d-monitor/providers/microsoft.operationalinsights/workspaces/law-ae-d-mgmt-01"
    ],
    "production": [
      "/subscriptions/fca82a86-9abc-4ef3-8628-cd6e3e426325/resourcegroups/rg-ae-p-monitor/providers/microsoft.operationalinsights/workspaces/law-ae-p-mgmt-01"
    ]
  }
}
```

>:memo: NOTE: the key name for each environment specific value does not need to match the parameter name. In the example above, the key name is `logAnalyticsWorkspace`. It is simply a descriptive name for the environment specific value.

### assignmentNotScopeExclusions

This section defines the exclusion list for the assignment's NotScopes property. Items in this list will be excluded when checking for corresponding values in the other environment.

For example, there is a management group called `CONTOSO-Quarantine` under the production root management group, and there is no corresponding management group in the development environment.

Some of the production policy assignments have configured to exclude this management group. In this case, you can specify the resource ID of the `CONTOSO-Quarantine` management group in the `assignmentNotScopeExclusions` list as shown below so the test will not fail due to the missing corresponding NotScope value in the development environment:

```json
"assignmentNotScopeExclusions": [
  "/providers/Microsoft.Management/managementGroups/CONTOSO-Quarantine"
]
```

### assignmentNotScopeDeviations

This section defines the exclusion deviation for a specific policy assignment. For example, a resource restriction policy assignment may need to exclude certain child scopes under the development landing zone management group to allow the creation of Public IP addresses for testing purposes, while the production policy assignment does not have such exclusions.

In this case, you can specify the allowed NotScope deviations for the resource restriction policy assignment as shown below:

```json
"assignmentNotScopeDeviations": [
  {
    "sourceAssignmentName": "pa-lz-res-restriction",
    "correspondingNotScopeValue": [
      "/providers/Microsoft.Management/managementGroups/CONTOSO-DEV-LandingZones-Corp"
    ],
    "deviationReason": "These child management groups need to be excluded so Public IP addresses can be created for tests for AKS, Bastion and VNet Gateway."
  }
]
```
