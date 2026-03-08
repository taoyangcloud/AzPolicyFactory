metadata name = 'Policy Exemptions (Management Group scope)'
metadata description = 'This module deploys a Policy Exemption at a Management Group scope.'
metadata summary = 'Deploy Policy Exemptions at a Management Group scope.'

targetScope = 'managementGroup'
import { policyExemptionType } from '../../../user-defined-types.bicep'

@sys.description('Required. Policy Exemption.')
param policyExemption policyExemptionType

var additionalMetadata = union(policyExemption.?metadata ?? {}, {
  hidden_vml_name: 'authorization/policy-exemption'
  hidden_vml_version: loadJsonContent('./version.json').version
})

resource exemption 'Microsoft.Authorization/policyExemptions@2024-12-01-preview' = {
  name: policyExemption.name
  properties: {
    displayName: policyExemption.?displayName
    description: policyExemption.?description
    metadata: additionalMetadata
    exemptionCategory: policyExemption.exemptionCategory
    policyAssignmentId: policyExemption.policyAssignmentId
    policyDefinitionReferenceIds: policyExemption.?policyDefinitionReferenceIds
    expiresOn: policyExemption.?expiresOn
    assignmentScopeValidation: policyExemption.assignmentScopeValidation
    resourceSelectors: policyExemption.?resourceSelectors
  }
}

@sys.description('Policy Exemption Name.')
output name string = exemption.name

@sys.description('Policy Exemption resource ID.')
output resourceId string = exemption.id

@sys.description('Policy Exemption Scope.')
output scope string = managementGroup().id
