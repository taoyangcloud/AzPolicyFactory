metadata name = 'Policy Assignments (Subscription scope)'
metadata description = 'This module deploys a Policy Assignment at a Subscription scope.'
metadata summary = 'Deploy Policy Assignments at a Subscription scope.'

targetScope = 'subscription'

import { policyAssignmentType } from '../../../user-defined-types.bicep'
@sys.description('Required. Policy Assignment.')
param policyAssignment policyAssignmentType

@sys.description('Optional. Location for all resources.')
param location string = deployment().location

@sys.description('Optional. The Target Scope for the Policy Assignment. The subscription ID of the subscription for the policy assignment. If not provided, will use the current scope for deployment.')
param subscriptionId string = subscription().subscriptionId

var additionalMetadata = union(policyAssignment.?metadata ?? {}, {
  hidden_vml_name: 'authorization/policy-assignment'
  hidden_vml_version: loadJsonContent('./version.json').version
})
var identityVar = policyAssignment.?identity == 'SystemAssigned'
  ? {
      type: policyAssignment.?identity
    }
  : policyAssignment.?identity == 'UserAssigned'
      ? {
          type: policyAssignment.?identity
          userAssignedIdentities: {
            '${policyAssignment.?userAssignedIdentityId}': {}
          }
        }
      : null

resource assignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: policyAssignment.name
  location: location
  properties: {
    assignmentType: policyAssignment.assignmentType
    definitionVersion: policyAssignment.?definitionVersion
    displayName: policyAssignment.?displayName
    metadata: additionalMetadata
    description: policyAssignment.?description
    policyDefinitionId: policyAssignment.policyDefinitionId
    parameters: policyAssignment.?parameters
    nonComplianceMessages: policyAssignment.?nonComplianceMessages
    enforcementMode: policyAssignment.?enforcementMode
    notScopes: policyAssignment.?notScopes
    overrides: policyAssignment.?overrides
    resourceSelectors: policyAssignment.?resourceSelectors
  }
  identity: identityVar
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in policyAssignment.?roleDefinitionIds ?? []: if (!empty(policyAssignment.?roleDefinitionIds) && policyAssignment.?identity == 'SystemAssigned') {
    name: guid(subscriptionId, roleDefinitionId, location, policyAssignment.name)
    properties: {
      roleDefinitionId: roleDefinitionId
      principalId: assignment.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

@sys.description('Policy Assignment Name.')
output name string = assignment.name

@sys.description('Policy Assignment principal ID.')
output principalId string = policyAssignment.?identity == 'SystemAssigned' ? assignment.identity.principalId : ''

@sys.description('Policy Assignment resource ID.')
output resourceId string = assignment.id

@sys.description('The location the resource was deployed into.')
output location string = assignment.location
