# Policy Assignments (Management Group scope)

Deploy Policy Assignments at a Management Group scope.

This module deploys a Policy Assignment at a Management Group scope.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policyAssignment | Yes      | Required. Policy Assignment.
managementGroupId | No       | Optional. The Target Scope for the Policy Assignment. The name of the management group for the policy assignment. If not provided, will use the current scope for deployment.
location       | No       | Optional. Location for all resources.

### policyAssignment

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. Policy Assignment.

### managementGroupId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The Target Scope for the Policy Assignment. The name of the management group for the policy assignment. If not provided, will use the current scope for deployment.

- Default value: `[managementGroup().name]`

### location

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Location for all resources.

- Default value: `[deployment().location]`

## Outputs

Name | Type | Description
---- | ---- | -----------
name | string | Policy Assignment Name.
principalId | string | Policy Assignment principal ID.
resourceId | string | Policy Assignment resource ID.
location | string | The location the resource was deployed into.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/policy-assignment/management-group/main.json"
    },
    "parameters": {
        "policyAssignment": {
            "value": null
        },
        "managementGroupId": {
            "value": "[managementGroup().name]"
        },
        "location": {
            "value": "[deployment().location]"
        }
    }
}
```

