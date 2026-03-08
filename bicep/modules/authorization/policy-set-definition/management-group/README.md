# Policy Set Definitions (Initiatives) (Management Group scope)

Deploy Policy Set Definitions (Initiatives) at a Management Group scope.

This module deploys Policy Set Definitions (Initiatives) at a Management Group scope.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policySetDefinitions | Yes      | Required. Policy Set Definitions to be created.

### policySetDefinitions

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. Policy Set Definitions to be created.

## Outputs

Name | Type | Description
---- | ---- | -----------
policySetDefinitions | array | Deployed policy definitions.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/policy-set-definition/management-group/main.json"
    },
    "parameters": {
        "policySetDefinitions": {
            "value": null
        }
    }
}
```

