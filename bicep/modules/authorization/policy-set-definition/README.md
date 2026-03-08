# Policy Set Definitions (Initiatives) (All scopes)

Deploy Policy Set Definitions (Initiatives) at a Management Group or Subscription scope.

Policy Set Definitions (Initiatives) module. Originally forked from the CARML project with modifications.

## Parameters

Parameter name | Required | Description
-------------- | -------- | -----------
policySetDefinitions | Yes      | Required. Policy Set Definitions to be created.
managementGroupId | No       | Optional. The group ID of the Management Group (Scope). If not provided, will use the current scope for deployment.
subscriptionId | No       | Optional. The subscription ID of the subscription (Scope). Cannot be used with managementGroupId.

### policySetDefinitions

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

Required. Policy Set Definitions to be created.

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
policySetDefinitions | array | Deployed policy set definitions.

## Snippets

### Parameter file

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "template": "./bicep/modules/authorization/policy-set-definition/main.json"
    },
    "parameters": {
        "policySetDefinitions": {
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

