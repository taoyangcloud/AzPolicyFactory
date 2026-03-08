# Policy Definitions (All scopes)

Deploy Policy Definitions at a Management Group or Subscription scope.

Policy Definition module. Originally forked from the CARML project with modifications.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policyDefinitions | Yes      | Required. The Policy Definitions to be created.
managementGroupId | No       | Optional. The group ID of the Management Group (Scope). If not provided, will use the current scope for deployment.
subscriptionId | No       | Optional. The subscription ID of the subscription (Scope). Cannot be used with managementGroupId.

### policyDefinitions

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. The Policy Definitions to be created.

### managementGroupId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The group ID of the Management Group (Scope). If not provided, will use the current scope for deployment.

- Default value: `[managementGroup().name]`

### subscriptionId

![Parameter Setting](https://img.shields.io/badge/parameter-optional-green?style=flat-square)

Optional. The subscription ID of the subscription (Scope). Cannot be used with managementGroupId.

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
        "template": "./bicep/modules/authorization/policy-definition/main.json"
    },
    "parameters": {
        "policyDefinitions": {
            "value": null
        },
        "managementGroupId": {
            "value": "[managementGroup().name]"
        },
        "subscriptionId": {
            "value": ""
        }
    }
}
```

