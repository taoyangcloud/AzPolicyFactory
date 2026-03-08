# Policy Assignments (All scopes)

Deploy Policy Assignments at a Management Group, Subscription or Resource Group scope.

Policy Assignment module. Originally forked from the CARML project with modifications.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policyAssignment | Yes      | Required. Policy Assignment.
managementGroupId | No       | Optional. The Target Scope for the Policy Assignment. The name of the management group for the policy assignment. If not provided, will use the current scope for deployment.
subscriptionId | Yes      | Optional. The Target Scope for the Policy Assignment. The subscription ID of the subscription for the policy assignment.
resourceGroupName | Yes      | Optional. The Target Scope for the Policy Assignment. The name of the resource group for the policy assignment.
location       | No       | Optional. Location for all resources.
additionalRoleAssignments | No       | Optional. Additional role assignments for the policy assignment managed identity that are required outside of the policy assignment scope.

### policyAssignment

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. Policy Assignment.

### managementGroupId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The Target Scope for the Policy Assignment. The name of the management group for the policy assignment. If not provided, will use the current scope for deployment.

- Default value: `[managementGroup().name]`

### subscriptionId

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Optional. The Target Scope for the Policy Assignment. The subscription ID of the subscription for the policy assignment.

### resourceGroupName

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Optional. The Target Scope for the Policy Assignment. The name of the resource group for the policy assignment.

### location

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Location for all resources.

- Default value: `[deployment().location]`

### additionalRoleAssignments

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Additional role assignments for the policy assignment managed identity that are required outside of the policy assignment scope.

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
        "template": "./bicep/modules/authorization/policy-assignment/main.json"
    },
    "parameters": {
        "policyAssignment": {
            "value": null
        },
        "managementGroupId": {
            "value": "[managementGroup().name]"
        },
        "subscriptionId": {
            "value": ""
        },
        "resourceGroupName": {
            "value": ""
        },
        "location": {
            "value": "[deployment().location]"
        },
        "additionalRoleAssignments": {
            "value": []
        }
    }
}
```

