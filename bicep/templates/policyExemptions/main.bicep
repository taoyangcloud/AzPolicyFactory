metadata name = 'Policy Exemption Template'
metadata description = 'This template creates policy exemptions on various scopes.'
metadata summary = 'Deploys policy exemptions to various scopes.'

targetScope = 'managementGroup'

import {
  policyExemptionType
} from '../../modules/user-defined-types.bicep'

//--------- variables ---------

//DO NOT MODIFY policyExemptions variable. The value will be populated by the pipeline
var policyExemptions = []

var createdByMetadata = {
  createdBy: 'CONTOSO Policy Exemption ADO Pipeline'
}

var deploymentNameSuffix = last(split(deployment().name, '-'))

var formattedPolicyExemptions = [
  for (exemption, i) in policyExemptions: {
    policyExemption: {
      name: exemption.policyExemption.name
      description: exemption.policyExemption.?description
      displayName: exemption.policyExemption.?displayName
      metadata: union(exemption.policyExemption.?metadata ?? {}, createdByMetadata)
      policyAssignmentId: exemption.policyExemption.policyAssignmentId
      exemptionCategory: exemption.policyExemption.exemptionCategory
      expiresOn: exemption.policyExemption.?expiresOn
      assignmentScopeValidation: exemption.policyExemption.?assignmentScopeValidation
      policyDefinitionReferenceIds: exemption.policyExemption.?policyDefinitionReferenceIds
      resourceSelectors: exemption.policyExemption.?resourceSelectors
    }
    #disable-next-line BCP053
    managementGroupId: exemption.?managementGroupId
    #disable-next-line BCP053
    subscriptionId: exemption.?subscriptionId
    #disable-next-line BCP053
    resourceGroupName: exemption.?resourceGroupName
  }
]
//--------- policy exemptions ---------
module exemptions '../../modules/authorization/policy-exemption/main.bicep' = [
  for (exemption, i) in formattedPolicyExemptions: {
    name: take('${exemption.policyExemption.name}-${deploymentNameSuffix}', 64)
    params: {
      policyExemption: exemption.policyExemption
      managementGroupId: exemption.managementGroupId
      subscriptionId: exemption.subscriptionId
      resourceGroupName: exemption.resourceGroupName
    }
  }
]

//--------- outputs ---------
@sys.description('Policy Exemption resource ID')
output policyExemptions array = [
  for (policyExemption, i) in policyExemptions: {
    name: exemptions[i].outputs.?name
    resourceId: exemptions[i].outputs.?resourceId
    scope: exemptions[i].outputs.?scope
  }
]

//--------- Definitions ---------

type policyExemptionConfigurationType = {
  @sys.description('Required. Policy Exemption.')
  policyExemption: policyExemptionType

  @sys.description('Optional. The Target Scope for the Policy Exemption nb. The name of the management group for the policy assignment. If not provided, will use the current scope for deployment.')
  managementGroupId: string?

  @sys.description('Optional. The Target Scope for the Policy. The subscription ID of the subscription for the policy assignment.')
  subscriptionId: string?

  @sys.description('Optional. The Target Scope for the Policy. The name of the resource group for the policy assignment.')
  resourceGroupName: string?
}
