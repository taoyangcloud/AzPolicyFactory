metadata name = 'Policy Definitions (All scopes)'
metadata description = 'Policy Definition module. Originally forked from the CARML project with modifications.'
metadata summary = 'Deploy Policy Definitions at a Management Group or Subscription scope.'

targetScope = 'managementGroup'

import {
  policyDefinitionType
} from '../../user-defined-types.bicep'

@sys.description('Required. The Policy Definitions to be created.')
param policyDefinitions policyDefinitionType

@sys.description('Optional. The group ID of the Management Group (Scope). If not provided, will use the current scope for deployment.')
param managementGroupId string = managementGroup().name

@sys.description('Optional. The subscription ID of the subscription (Scope). Cannot be used with managementGroupId.')
param subscriptionId string = ''

module policyDefinition_mg 'management-group/main.bicep' = if (empty(subscriptionId)) {
  name: '${uniqueString(deployment().name)}-PolicyDefinition-MG-Module'
  scope: managementGroup(managementGroupId)
  params: {
    policyDefinitions: policyDefinitions
  }
}

module policyDefinition_sub 'subscription/main.bicep' = if (!empty(subscriptionId)) {
  name: '${uniqueString(deployment().name)}-PolicyDefinition-Sub-Module'
  scope: subscription(subscriptionId)
  params: {
    policyDefinitions: policyDefinitions
  }
}

@sys.description('Deployed policy definitions.')
output policyDefinitions array = empty(subscriptionId)
  ? policyDefinition_mg.?outputs.policyDefinitions ?? []
  : policyDefinition_sub.?outputs.policyDefinitions ?? []
