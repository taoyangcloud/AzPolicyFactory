# Policy Definitions (Management Group scope)

Deploy Policy Definitions at a Management Group scope.

This module deploys Policy Definitions at a Management Group scope.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policyDefinitions | Yes      | Required. The Policy Definitions to be created.

### policyDefinitions

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. The Policy Definitions to be created.

## Outputs

Name | Type | Description
---- | ---- | -----------
policyDefinitions | array | Deployed policy definitions.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/policy-definition/management-group/main.json"
    },
    "parameters": {
        "policyDefinitions": {
            "value": null
        }
    }
}
```

