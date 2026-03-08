metadata name = 'Policy Definitions (Subscription scope)'
metadata description = 'This module deploys Policy Definitions at a Subscription scope.'
metadata summary = 'Deploy Policy Definitions at a Subscription scope.'

targetScope = 'subscription'

import {
  policyDefinitionType
} from '../../../user-defined-types.bicep'

@sys.description('Required. The Policy Definitions to be created.')
param policyDefinitions policyDefinitionType

var additionalMetadata = {
  hidden_vml_name: 'authorization/policy-definition'
  hidden_vml_version: loadJsonContent('../version.json').version
}

@batchSize(15)
resource policies 'Microsoft.Authorization/policyDefinitions@2025-03-01' = [
  for policyDefinition in policyDefinitions: {
    name: policyDefinition.name
    properties: {
      policyType: 'Custom'
      mode: policyDefinition.properties.mode
      displayName: policyDefinition.properties.?displayName
      description: policyDefinition.properties.?description
      metadata: union(policyDefinition.properties.?metadata ?? {}, additionalMetadata)
      externalEvaluationEnforcementSettings: policyDefinition.properties.?externalEvaluationEnforcementSettings
      parameters: policyDefinition.properties.?parameters
      policyRule: policyDefinition.properties.policyRule
      version: policyDefinition.properties.?version
    }
  }
]

@sys.description('Deployed policy definitions.')
output policyDefinitions array = [
  for (definition, i) in policyDefinitions: {
    name: policies[i].name
    resourceId: policies[i].id
    roleDefinitionIds: (contains(policies[i].properties.policyRule.then, 'details')
      ? ((policies[i].properties.policyRule.then.details.?roleDefinitionIds ?? []))
      : [])
  }
]
