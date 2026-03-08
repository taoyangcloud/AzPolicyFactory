metadata name = 'Policy Assignments (All scopes)'
metadata description = 'Policy Assignment module. Originally forked from the CARML project with modifications.'
metadata summary = 'Deploy Policy Assignments at a Management Group, Subscription or Resource Group scope.'
targetScope = 'managementGroup'

import {
  policyAssignmentType
  roleAssignmentForPolicyAssignmentType
} from '../../user-defined-types.bicep'

@sys.description('Required. Policy Assignment.')
param policyAssignment policyAssignmentType

@sys.description('Optional. The Target Scope for the Policy Assignment. The name of the management group for the policy assignment. If not provided, will use the current scope for deployment.')
param managementGroupId string = managementGroup().name

@sys.description('Optional. The Target Scope for the Policy Assignment. The subscription ID of the subscription for the policy assignment.')
param subscriptionId string?

@sys.description('Optional. The Target Scope for the Policy Assignment. The name of the resource group for the policy assignment.')
param resourceGroupName string?

@sys.description('Optional. Location for all resources.')
param location string = deployment().location

@sys.description('Optional. Additional role assignments for the policy assignment managed identity that are required outside of the policy assignment scope.')
param additionalRoleAssignments roleAssignmentForPolicyAssignmentType[] = []

module policyAssignment_mg 'management-group/main.bicep' = if (empty(subscriptionId) && empty(resourceGroupName)) {
  name: '${uniqueString(deployment().name, location)}-PolicyAssignment-MG'
  scope: managementGroup(managementGroupId)
  params: {
    policyAssignment: policyAssignment
    managementGroupId: managementGroupId
    location: location
  }
}

module policyAssignment_sub 'subscription/main.bicep' = if (!empty(subscriptionId) && empty(resourceGroupName)) {
  name: '${uniqueString(deployment().name, location)}-PolicyAssignment-Sub'
  scope: subscription(subscriptionId!)
  params: {
    policyAssignment: policyAssignment
    subscriptionId: subscriptionId
    location: location
  }
}

module policyAssignment_rg 'resource-group/main.bicep' = if (!empty(resourceGroupName) && !empty(subscriptionId)) {
  name: '${uniqueString(deployment().name, location)}-PolicyAssignment-RG'
  scope: resourceGroup(subscriptionId!, resourceGroupName!)
  params: {
    policyAssignment: policyAssignment
    subscriptionId: subscriptionId
    location: location
  }
}

module additionalRA '../role-assignment/main.bicep' = [
  for (ra, i) in (additionalRoleAssignments): {
    name: '${uniqueString(deployment().name, location)}-additionalRA-${i}'
    params: {
      roleDefinitionIdOrName: ra.roleDefinitionIdOrName
      principalId: (empty(subscriptionId) && empty(resourceGroupName) ? policyAssignment_mg.?outputs.principalId : null) ?? (!empty(subscriptionId) && empty(resourceGroupName)
        ? policyAssignment_sub.?outputs.principalId
        : null) ?? policyAssignment_rg.?outputs.principalId ?? ''
      principalType: 'ServicePrincipal'
      resourceGroupName: ra.?resourceGroupName
      subscriptionId: ra.?subscriptionId
      managementGroupId: ra.?managementGroupId
      description: ra.?description
      condition: ra.?condition
    }
  }
]
@sys.description('Policy Assignment Name.')
output name string? = empty(subscriptionId) && empty(resourceGroupName)
  ? policyAssignment_mg.?outputs.?name
  : (!empty(subscriptionId) && empty(resourceGroupName)
      ? policyAssignment_sub.?outputs.?name
      : policyAssignment_rg.?outputs.?name)

@sys.description('Policy Assignment principal ID.')
output principalId string? = empty(subscriptionId) && empty(resourceGroupName)
  ? policyAssignment_mg.?outputs.?principalId
  : (!empty(subscriptionId) && empty(resourceGroupName)
      ? policyAssignment_sub.?outputs.?principalId
      : policyAssignment_rg.?outputs.?principalId)

@sys.description('Policy Assignment resource ID.')
output resourceId string? = empty(subscriptionId) && empty(resourceGroupName)
  ? policyAssignment_mg.?outputs.resourceId
  : (!empty(subscriptionId) && empty(resourceGroupName)
      ? policyAssignment_sub.?outputs.resourceId
      : policyAssignment_rg.?outputs.?resourceId)

@sys.description('The location the resource was deployed into.')
output location string? = empty(subscriptionId) && empty(resourceGroupName)
  ? policyAssignment_mg.?outputs.location
  : (!empty(subscriptionId) && empty(resourceGroupName)
      ? policyAssignment_sub.?outputs.location
      : policyAssignment_rg.?outputs.?location)
