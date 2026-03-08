# Policy Definitions Template

Deploys policy definitions in Contoso.

This template deploys the policy definitions in Contoso.

## Outputs

Name | Type | Description
---- | ---- | -----------
policyDefinitions | array | The list of policy definitions deployed by this template.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/templates/policyDefinitions/main.json"
    },
    "parameters": {}
}
```

