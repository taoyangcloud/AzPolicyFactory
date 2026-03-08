# Policy Assignments (Resource Group scope)

Deploy Policy Assignments at a Resource Group scope.

This module deploys a Policy Assignment at a Resource Group scope.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policyAssignment | Yes      | Required. Policy Assignment.
location       | No       | Optional. Location for all resources.
subscriptionId | No       | Optional. The Target Scope for the Policy Assignment. The subscription ID of the subscription for the policy assignment. If not provided, will use the current scope for deployment.
resourceGroupName | No       | Optional. The Target Scope for the Policy Assignment. The name of the resource group for the policy assignment. If not provided, will use the current scope for deployment.

### policyAssignment

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. Policy Assignment.

### location

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Location for all resources.

- Default value: `[resourceGroup().location]`

### subscriptionId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The Target Scope for the Policy Assignment. The subscription ID of the subscription for the policy assignment. If not provided, will use the current scope for deployment.

- Default value: `[subscription().subscriptionId]`

### resourceGroupName

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The Target Scope for the Policy Assignment. The name of the resource group for the policy assignment. If not provided, will use the current scope for deployment.

- Default value: `[resourceGroup().name]`

## Outputs

Name | Type | Description
---- | ---- | -----------
name | string | Policy Assignment Name.
principalId | string | Policy Assignment principal ID.
resourceId | string | Policy Assignment resource ID.
resourceGroupName | string | The name of the resource group the policy was assigned to.
location | string | The location the resource was deployed into.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/policy-assignment/resource-group/main.json"
    },
    "parameters": {
        "policyAssignment": {
            "value": null
        },
        "location": {
            "value": "[resourceGroup().location]"
        },
        "subscriptionId": {
            "value": "[subscription().subscriptionId]"
        },
        "resourceGroupName": {
            "value": "[resourceGroup().name]"
        }
    }
}
```

