# Policy Exemptions (All scopes)

Deploy Policy Exemptions at a Management Group, Subscription or Resource Group scope.

Policy Exemption module. Originally forked from the CARML project with modifications.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policyExemption | Yes      | Required. Policy Exemption.
managementGroupId | No       | Optional. The Target Scope for the Policy Exemption. The name of the management group for the policy exemption. If not provided, will use the current scope for deployment.
subscriptionId | Yes      | Optional. The Target Scope for the Policy Exemption. The subscription ID of the subscription for the policy exemption.
resourceGroupName | Yes      | Optional. The Target Scope for the Policy Exemption. The name of the resource group for the policy exemption.
location       | No       | Optional. Location for all resources.

### policyExemption

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. Policy Exemption.

### managementGroupId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The Target Scope for the Policy Exemption. The name of the management group for the policy exemption. If not provided, will use the current scope for deployment.

- Default value: `[managementGroup().name]`

### subscriptionId

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Optional. The Target Scope for the Policy Exemption. The subscription ID of the subscription for the policy exemption.

### resourceGroupName

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Optional. The Target Scope for the Policy Exemption. The name of the resource group for the policy exemption.

### location

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Location for all resources.

- Default value: `[deployment().location]`

## Outputs

Name | Type | Description
---- | ---- | -----------
name | string | Policy Exemption Name.
resourceId | string | Policy Exemption resource ID.
scope | string | Policy Exemption Scope.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/policy-exemption/main.json"
    },
    "parameters": {
        "policyExemption": {
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
        }
    }
}
```

