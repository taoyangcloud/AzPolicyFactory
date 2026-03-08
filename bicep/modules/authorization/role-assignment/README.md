# Role Assignments (All scopes)

Deploy Role Assignments at a Management Group, Subscription or Resource Group scope.

Role Assignments module. Originally forked from the AVM project with modifications.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
roleDefinitionIdOrName | Yes      | Required. You can provide either the display name of the role definition (must be configured in the variable `builtInRoleNames`), or its fully qualified ID in the following format: '/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11'.
principalId    | Yes      | Required. The Principal or Object ID of the Security Principal (User, Group, Service Principal, Managed Identity).
resourceGroupName | No       | Optional. Name of the Resource Group to assign the RBAC role to. If Resource Group name is provided, and Subscription ID is provided, the module deploys at resource group level, therefore assigns the provided RBAC role to the resource group.
subscriptionId | No       | Optional. Subscription ID of the subscription to assign the RBAC role to. If no Resource Group name is provided, the module deploys at subscription level, therefore assigns the provided RBAC role to the subscription.
managementGroupId | No       | Optional. Group ID of the Management Group to assign the RBAC role to. If not provided, will use the current scope for deployment.
location       | No       | Optional. Location deployment metadata.
description    | No       | Optional. The description of the role assignment.
delegatedManagedIdentityResourceId | No       | Optional. ID of the delegated managed identity resource.
condition      | No       | Optional. The conditions on the role assignment. This limits the resources it can be assigned to.
conditionVersion | No       | Optional. Version of the condition. Currently accepted value is "2.0".
principalType  | No       | Optional. The principal type of the assigned principal ID.

### roleDefinitionIdOrName

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. You can provide either the display name of the role definition (must be configured in the variable `builtInRoleNames`), or its fully qualified ID in the following format: '/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11'.

### principalId

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. The Principal or Object ID of the Security Principal (User, Group, Service Principal, Managed Identity).

### resourceGroupName

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Name of the Resource Group to assign the RBAC role to. If Resource Group name is provided, and Subscription ID is provided, the module deploys at resource group level, therefore assigns the provided RBAC role to the resource group.

### subscriptionId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Subscription ID of the subscription to assign the RBAC role to. If no Resource Group name is provided, the module deploys at subscription level, therefore assigns the provided RBAC role to the subscription.

### managementGroupId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Group ID of the Management Group to assign the RBAC role to. If not provided, will use the current scope for deployment.

- Default value: `[managementGroup().name]`

### location

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Location deployment metadata.

- Default value: `[deployment().location]`

### description

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The description of the role assignment.

### delegatedManagedIdentityResourceId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. ID of the delegated managed identity resource.

### condition

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The conditions on the role assignment. This limits the resources it can be assigned to.

### conditionVersion

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Version of the condition. Currently accepted value is "2.0".

- Default value: `2.0`

- Allowed values: `2.0`

### principalType

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The principal type of the assigned principal ID.

- Allowed values: `ServicePrincipal`, `Group`, `User`, `ForeignGroup`, `Device`, ``

## Outputs

Name | Type | Description
---- | ---- | -----------
name | string | The GUID of the Role Assignment.
resourceId | string | The resource ID of the Role Assignment.
scope | string | The scope this Role Assignment applies to.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/role-assignment/main.json"
    },
    "parameters": {
        "roleDefinitionIdOrName": {
            "value": ""
        },
        "principalId": {
            "value": ""
        },
        "resourceGroupName": {
            "value": ""
        },
        "subscriptionId": {
            "value": ""
        },
        "managementGroupId": {
            "value": "[managementGroup().name]"
        },
        "location": {
            "value": "[deployment().location]"
        },
        "description": {
            "value": ""
        },
        "delegatedManagedIdentityResourceId": {
            "value": ""
        },
        "condition": {
            "value": ""
        },
        "conditionVersion": {
            "value": "2.0"
        },
        "principalType": {
            "value": ""
        }
    }
}
```

