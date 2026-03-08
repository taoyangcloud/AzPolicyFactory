# Add Policy Resources to AzPolicyFactory

## Step 1: Add Policy Definitions to the repository

Add your custom Azure Policy definitions to the `./policyDefinitions` folder in this repository.

Each policy definition should be in its own JSON file. The JSON file should have the following property structure:

```json
{
  "name": "<policy-definition-name>",
  "properties": {
    "<policy-definition-properties>"
  }
}
```

You can organize them into sub-folders as needed.

## Step 2: Add Policy Initiatives to the repository

Add your custom Azure Policy initiatives to the `./policyInitiatives` folder in this repository.

Each policy initiative should be in its own JSON file. The JSON file should have the following property structure:

```json
{
  "name": "<policy-initiative-name>",
  "properties": {
    "<policy-initiative-properties>"
  }
}
```

> :memo: NOTE: Since the deployment places all custom policy definitions and initiatives at the top-level management group for the Enterprise Scale Landing Zone, you do not have to hardcode the resource ID of each member policy definition in the initiative definition.
> You can use `{policyLocationResourceId}` as a placeholder for the Management Group resource ID.
> The Bicep template will replace this string with the actual resource ID of the management group where the policies deploy during deployment.

For example:

i.e. `"policyDefinitionId": "{policyLocationResourceId}/providers/Microsoft.Authorization/policyDefinitions/pol-audit-postgresql-ssl"`

```json
{
  "policyDefinitionReferenceId": "PGS-003",
  "policyDefinitionId": "{policyLocationResourceId}/providers/Microsoft.Authorization/policyDefinitions/pol-audit-postgresql-geo-redundant-backup",
  "parameters": {
    "effect": {
      "value": "[parameters('PGS-003_Effect')]"
    }
  },
  "groupNames": [
    "ISO27001-2013_A.12.3.1"
  ]
}
```

## Step 3: Add Policy Assignments to the repository

The policy assignments are separated into different folders under `./policyAssignments` based on the environment (development or production):

- Development environment: `./policyAssignments/dev`
- Production environment: `./policyAssignments/prod`


The configuration files must be aligned with the JSON schema file [policyAssignment.schema.json](../policyAssignments/policyAssignment.schema.json).

Example:

```json
{
  "$schema": "../policyAssignment.schema.json",
  "policyAssignment": {
    "name": "pa-p-acr",
    "displayName": "Azure Container Registry Policies Prod",
    "description": "Policy Assignment for Azure Container Registry - Prod",
    "metadata": {
      "category": "Azure Container Registry"
    },
    "policyDefinitionId": "{policyLocationResourceId}/providers/Microsoft.Authorization/policySetDefinitions/polset-acr",
    "identity": "None",
    "parameters": {
      "ACR-001_Effect": {
        "value": "Audit"
      },
      "ACR-002_Effect": {
        "value": "Audit"
      },
      "ACR-003_Effect": {
        "value": "Audit"
      }
    },
    "nonComplianceMessages": [],
    "roleDefinitionIds": []
  },
  "definitionSourceManagementGroupId": "/providers/Microsoft.Management/managementGroups/CONTOSO",
  "managementGroupId": "CONTOSO"
}
```

Since the policy assignment bicep template deployment is targeting the same management group where the policy definitions and initiatives are deployed to, you can follow the same pattern as the Policy Initiative definitions and use `{policyLocationResourceId}` as a placeholder for the policy definition ID in the `policyAssignment` block.

The Bicep template will replace this string with the actual resource ID of the policy definition during deployment.

The Bicep template uses nested deployments to deploy policy assignments to any child management groups, subscriptions or resource groups under the top-level management group.

In the above example, the policy assignment is scoped to the `CONTOSO` management group (defined in the `managementGroupId` property).

If the assignment is targeting a subscription, replace the `managementGroupId` property with `subscriptionId`(GUID) property and provide the target subscription ID.

If the assignment is targeting a resource group, remove the `managementGroupId` property and add `subscriptionId` and `resourceGroupName` properties and provide the target resource group name.

> :memo: NOTE: the Policy Assignment ADO pipeline and GitHub actions workflow will automatically populate the `nonComplianeceMessages` property based on assigned policies during the build stage / job. You do not need to provide any value for this property when creating the policy assignment configuration file.

## Step 4: Add Policy Exemptions to the repository

The policy exemptions are separated into different folders under `./policyExemptions` based on the environment (development or production):

- Development environment: `./policyExemptions/dev`
- Production environment: `./policyExemptions/prod`

The configuration files must be aligned with the JSON schema file [policyExemption.schema.json](../policyExemptions/policyExemption.schema.json).

Example:

```json
  "$schema": "../policyExemption.schema.json",
  "policyExemption": {
    "name": "pex-lz-corp-sub-eh-001",
    "displayName": "Exempt LZ-Corp Subscription from Event Hub disable local auth restriction",
    "description": "This is a test exemption for the sub-d-lz-corp-01 subscription.",
    "metadata": {
      "requestedBy": "Eric Cartman",
      "approvedBy": "Bart Simpson",
      "approvedOn": "2025-10-16",
      "ticketRef": "INC123124"
    },
    "policyAssignmentId": "/providers/Microsoft.Management/managementGroups/CONTOSO/providers/microsoft.authorization/policyassignments/pa-p-eh",
    "exemptionCategory": "Waiver",
    "assignmentScopeValidation": "Default",
    "policyDefinitionReferenceIds": [
      "EH-001"
    ],
    "expiresOn": "2026-05-31T23:59:59Z",
    "resourceSelectors": [
      {
        "name": "AustraliaEast_Region",
        "selectors": [
          {
            "in": [
              "AustraliaEast"
            ],
            "kind": "resourceLocation"
          }
        ]
      }
    ]
  },
  "subscriptionId": "0f1b7d98-c832-4d46-8a29-a0c63d54a2fa"
```

In the above example, the policy exemption is scoped to the subscription `0f1b7d98-c832-4d46-8a29-a0c63d54a2fa`.

If the assignment is targeting a management group, replace the `subscriptionId` property with `managementGroupId` property and provide the target management group ID (i.e. `CONTOSO`).

If the assignment is targeting a resource group, add `resourceGroupName` properties and provide the target resource group name.

You can specify required metadata in the exemption configuration file based on your organization's standards. You can also update the [policy exemption configuration validation Pester script](../tests/policyExemption/configuration-syntax/exemptionConfigurationsSyntaxTest.ps1) to include additional validation rules for the metadata if needed.

This script has included the following tests based on the metadata property values in the example above:

- Requester and Approver should be different people (`requestedBy` and `approvedBy` properties should have different value)
- Exemption approved date should be a validate date in the past (`approvedOn` property value should be a valid date and should be less than the current date)

These tests are excluded by the Policy Exmemption ADO pipeline and GitHub actions workflow by default. You can enable them by removing the `ExcludeTag` filter in the Pester test task in the Test stages / jobs in the ADO pipeline and GitHub actions workflow.

> :memo: NOTE: The Policy Exemption ADO pipeline and GitHub actions workflow evaluates the expiry date of each exemption based on the value from `expiresOn` property during the build stage / job. If the exemption is expired, the pipeline / workflow will automatically exclude the expired exemption from the deployment. However, this does not automatically remove the expired exemption from Azure.

