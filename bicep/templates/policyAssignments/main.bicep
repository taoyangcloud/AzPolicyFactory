metadata name = 'Policy Assignment Template'
metadata description = 'This template creates policy assignments on various Management Group level scopes.'
metadata summary = 'Deploys policy assignments to management group scopes.'

targetScope = 'managementGroup'

import {
  policyAssignmentType
  roleAssignmentForPolicyAssignmentType
} from '../../modules/user-defined-types.bicep'

@sys.description('Optional. Location for all resources.')
param location string = deployment().location

//--------- variables ---------

//DO NOT MODIFY policyAssignments variable. The value will be populated by the pipeline
var policyAssignments = []

var createdByMetadata = {
  createdBy: 'CONTOSO Policy Assignment ADO Pipeline'
}

var deploymentNameSuffix = last(split(deployment().name, '-'))

var formattedPolicyAssignments = [
  for (assignment, i) in policyAssignments: {
    policyAssignment: {
      name: assignment.policyAssignment.name
      assignmentType: 'Custom'
      description: assignment.policyAssignment.?description
      displayName: assignment.policyAssignment.?displayName
      policyDefinitionId: replace(
        assignment.policyAssignment.policyDefinitionId,
        '{policyLocationResourceId}',
        assignment.definitionSourceManagementGroupId ?? managementGroup().id
      )
      parameters: assignment.policyAssignment.?parameters
      identity: assignment.policyAssignment.?identity
      #disable-next-line BCP053
      userAssignedIdentityId: assignment.policyAssignment.?userAssignedIdentityId
      #disable-next-line BCP053
      roleDefinitionIds: assignment.policyAssignment.?roleDefinitionIds
      #disable-next-line BCP053
      enforcementMode: assignment.policyAssignment.?enforcementMode
      metadata: union(assignment.policyAssignment.?metadata ?? {}, createdByMetadata)
      #disable-next-line BCP053
      notScopes: assignment.policyAssignment.?notScopes
      #disable-next-line BCP053
      nonComplianceMessages: assignment.policyAssignment.?nonComplianceMessages
    }
    #disable-next-line BCP053
    additionalRoleAssignments: assignment.?additionalRoleAssignments ?? []
    #disable-next-line BCP053
    managementGroupId: assignment.?managementGroupId
    #disable-next-line BCP053
    subscriptionId: assignment.?subscriptionId
    #disable-next-line BCP053
    resourceGroupName: assignment.?resourceGroupName
  }
]
//--------- policy assignments ---------
module assignments '../../modules/authorization/policy-assignment/main.bicep' = [
  for (assignment, i) in formattedPolicyAssignments: {
    name: take('${assignment.policyAssignment.name}-${deploymentNameSuffix}', 64)
    params: {
      policyAssignment: assignment.policyAssignment
      location: location
      managementGroupId: assignment.?managementGroupId
      subscriptionId: assignment.?subscriptionId
      resourceGroupName: assignment.?resourceGroupName
    }
  }
]

//--------- outputs ---------
@sys.description('Policy Assignment resource ID')
output policyAssignments array = [
  for (policyAssignment, i) in policyAssignments: {
    name: assignments[i].outputs.?name
    principalId: assignments[i].outputs.?principalId
    resourceId: assignments[i].outputs.?resourceId
  }
]

//--------- Definitions ---------

type policyAssignmentConfigurationType = {
  #disable-next-line BC318
  @sys.description('Required. Policy Assignment.')
  policyAssignment: policyAssignmentType

  #disable-next-line BC318
  @sys.description('Optional. Additional role assignments for the policy assignment managed identity that are required outside of the policy assignment scope.')
  additionalRoleAssignments: roleAssignmentForPolicyAssignmentType[]?

  #disable-next-line BC318
  @sys.description('Optional. The Target Scope for the Policy Assignment. The name of the management group for the policy assignment. If not provided, will use the current scope for deployment.')
  managementGroupId: string?

  #disable-next-line BC318
  @sys.description('Optional. The Target Scope for the Policy Assignment. The subscription ID of the subscription for the policy assignment.')
  subscriptionId: string?

  #disable-next-line BC318
  @sys.description('Optional. The Target Scope for the Policy Assignment. The name of the resource group for the policy assignment.')
  resourceGroupName: string?

  #disable-next-line BC318
  @description('Optional. Policy Definition Source Management Group Id. Default to the target management group')
  definitionSourceManagementGroupId: string?
}
