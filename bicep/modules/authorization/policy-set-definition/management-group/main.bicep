metadata name = 'Policy Set Definitions (Initiatives) (Management Group scope)'
metadata description = 'This module deploys Policy Set Definitions (Initiatives) at a Management Group scope.'
metadata summary = 'Deploy Policy Set Definitions (Initiatives) at a Management Group scope.'

targetScope = 'managementGroup'

import {
  policySetDefinitionType
} from '../../../user-defined-types.bicep'
@sys.description('Required. Policy Set Definitions to be created.')
param policySetDefinitions policySetDefinitionType

var additionalMetadata = {
  hidden_vml_name: 'authorization/policy-set-definition'
  hidden_vml_version: loadJsonContent('../version.json').version
}

@batchSize(15)
resource policySets 'Microsoft.Authorization/policySetDefinitions@2025-03-01' = [
  for policySetDefinition in policySetDefinitions: {
    name: policySetDefinition.name
    properties: {
      policyType: 'Custom'
      displayName: policySetDefinition.properties.?displayName
      description: policySetDefinition.properties.?description
      metadata: union(policySetDefinition.properties.?metadata ?? {}, additionalMetadata)
      parameters: policySetDefinition.properties.?parameters
      policyDefinitions: policySetDefinition.properties.policyDefinitions
      policyDefinitionGroups: policySetDefinition.properties.?policyDefinitionGroups
      version: policySetDefinition.properties.?version
    }
  }
]

@sys.description('Deployed policy definitions.')
output policySetDefinitions array = [
  for (definition, i) in policySetDefinitions: {
    name: policySets[i].name
    resourceId: policySets[i].id
  }
]
