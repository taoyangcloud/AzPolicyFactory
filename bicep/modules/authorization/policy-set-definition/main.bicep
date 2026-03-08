metadata name = 'Policy Set Definitions (Initiatives) (All scopes)'
metadata description = 'Policy Set Definitions (Initiatives) module. Originally forked from the CARML project with modifications.'
metadata summary = 'Deploy Policy Set Definitions (Initiatives) at a Management Group or Subscription scope.'
targetScope = 'managementGroup'

import {
  policySetDefinitionType
} from '../../user-defined-types.bicep'

@sys.description('Required. Policy Set Definitions to be created.')
param policySetDefinitions policySetDefinitionType

@sys.description('Optional. The group ID of the Management Group (Scope). If not provided, will use the current scope for deployment.')
param managementGroupId string = managementGroup().name

@sys.description('Optional. The subscription ID of the subscription (Scope). Cannot be used with managementGroupId.')
param subscriptionId string = ''

module policySetDefinition_mg 'management-group/main.bicep' = if (empty(subscriptionId)) {
  name: '${uniqueString(deployment().name)}-PolicySetDefinition-MG-Module'
  scope: managementGroup(managementGroupId)
  params: {
    policySetDefinitions: policySetDefinitions
  }
}

module policySetDefinition_sub 'subscription/main.bicep' = if (!empty(subscriptionId)) {
  name: '${uniqueString(deployment().name)}-PolicySetDefinition-Sub-Module'
  scope: subscription(subscriptionId)
  params: {
    policySetDefinitions: policySetDefinitions
  }
}

@sys.description('Deployed policy set definitions.')
output policySetDefinitions array = empty(subscriptionId)
  ? policySetDefinition_mg.?outputs.policySetDefinitions ?? []
  : policySetDefinition_sub.?outputs.policySetDefinitions ?? []
