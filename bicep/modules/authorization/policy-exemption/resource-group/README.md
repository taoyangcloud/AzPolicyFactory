# Policy Exemptions (Resource Group scope)

Deploy Policy Exemptions at a Resource Group scope.

This module deploys a Policy Exemption at a Resource Group scope.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policyExemption | Yes      | Required. Policy Exemption.

### policyExemption

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. Policy Exemption.

## Outputs

Name | Type | Description
---- | ---- | -----------
name | string | Policy Exemption Name.
resourceId | string | Policy Exemption resource ID.
scope | string | Policy Exemption Scope.
resourceGroupName | string | The name of the resource group the policy exemption was applied at.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/policy-exemption/resource-group/main.json"
    },
    "parameters": {
        "policyExemption": {
            "value": null
        }
    }
}
```

