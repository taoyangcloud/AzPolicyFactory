metadata name = 'Policy Exemptions (All scopes)'
metadata description = 'Policy Exemption module. Originally forked from the CARML project with modifications.'
metadata summary = 'Deploy Policy Exemptions at a Management Group, Subscription or Resource Group scope.'

targetScope = 'managementGroup'

import {
  policyExemptionType
} from '../../user-defined-types.bicep'

@sys.description('Required. Policy Exemption.')
param policyExemption policyExemptionType

@sys.description('Optional. The Target Scope for the Policy Exemption. The name of the management group for the policy exemption. If not provided, will use the current scope for deployment.')
param managementGroupId string = managementGroup().name

@sys.description('Optional. The Target Scope for the Policy Exemption. The subscription ID of the subscription for the policy exemption.')
param subscriptionId string?

@sys.description('Optional. The Target Scope for the Policy Exemption. The name of the resource group for the policy exemption.')
param resourceGroupName string?

@sys.description('Optional. Location for all resources.')
param location string = deployment().location

module policyExemption_mg 'management-group/main.bicep' = if (empty(subscriptionId) && empty(resourceGroupName)) {
  name: '${uniqueString(deployment().name, location)}-PolicyExemption-MG'
  scope: managementGroup(managementGroupId)
  params: {
    policyExemption: policyExemption
  }
}

module policyExemption_sub 'subscription/main.bicep' = if (!empty(subscriptionId) && empty(resourceGroupName)) {
  name: '${uniqueString(deployment().name, location)}-PolicyExemption-Sub'
  scope: subscription(subscriptionId!)
  params: {
    policyExemption: policyExemption
  }
}

module policyExemption_rg 'resource-group/main.bicep' = if (!empty(resourceGroupName) && !empty(subscriptionId)) {
  name: '${uniqueString(deployment().name, location)}-PolicyExemption-RG'
  scope: resourceGroup(subscriptionId!, resourceGroupName!)
  params: {
    policyExemption: policyExemption
  }
}

@sys.description('Policy Exemption Name.')
output name string? = empty(subscriptionId) && empty(resourceGroupName)
  ? policyExemption_mg.?outputs.?name
  : (!empty(subscriptionId) && empty(resourceGroupName)
      ? policyExemption_sub.?outputs.?name
      : policyExemption_rg.?outputs.?name)

@sys.description('Policy Exemption resource ID.')
output resourceId string? = empty(subscriptionId) && empty(resourceGroupName)
  ? policyExemption_mg.?outputs.?resourceId
  : (!empty(subscriptionId) && empty(resourceGroupName)
      ? policyExemption_sub.?outputs.?resourceId
      : policyExemption_rg.?outputs.?resourceId)

@sys.description('Policy Exemption Scope.')
output scope string? = empty(subscriptionId) && empty(resourceGroupName)
  ? policyExemption_mg.?outputs.?scope
  : (!empty(subscriptionId) && empty(resourceGroupName)
      ? policyExemption_sub.?outputs.?scope
      : policyExemption_rg.?outputs.?scope)
