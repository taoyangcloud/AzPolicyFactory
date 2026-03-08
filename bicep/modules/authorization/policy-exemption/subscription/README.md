# Policy Exemptions (Subscription scope)

Deploy Policy Exemptions at a Subscription scope.

This module deploys a Policy Exemption at a Subscription scope.

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

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/policy-exemption/subscription/main.json"
    },
    "parameters": {
        "policyExemption": {
            "value": null
        }
    }
}
```

