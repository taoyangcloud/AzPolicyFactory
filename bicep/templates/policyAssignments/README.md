# Policy Assignment Template

Deploys policy assignments to management group scopes.

This template creates policy assignments on various Management Group level scopes.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
location       | No       | Optional. Location for all resources.

### location

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. Location for all resources.

- Default value: `[deployment().location]`

## Outputs

Name | Type | Description
---- | ---- | -----------
policyAssignments | array | Policy Assignment resource ID

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/templates/policyAssignments/main.json"
    },
    "parameters": {
        "location": {
            "value": "[deployment().location]"
        }
    }
}
```

