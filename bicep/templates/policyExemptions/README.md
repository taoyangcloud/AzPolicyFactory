# Policy Exemption Template

Deploys policy exemptions to various scopes.

This template creates policy exemptions on various scopes.

## Outputs

Name | Type | Description
---- | ---- | -----------
policyExemptions | array | Policy Exemption resource ID

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/templates/policyExemptions/main.json"
    },
    "parameters": {}
}
```

