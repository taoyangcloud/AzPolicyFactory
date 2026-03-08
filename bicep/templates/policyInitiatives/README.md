# Policy Initiatives Template

Deploys policy initiatives in CONTOSO.

This template deploys the policy initiatives in CONTOSO.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
managementGroupId | No       | Policy Definition Source Management Group ID

### managementGroupId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Policy Definition Source Management Group ID

- Default value: `[managementGroup().id]`

## Outputs

Name | Type | Description
---- | ---- | -----------
policySetDefinitions | array | The list of policy initiatives deployed by this template.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/templates/policyInitiatives/main.json"
    },
    "parameters": {
        "managementGroupId": {
            "value": "[managementGroup().id]"
        }
    }
}
```

