metadata name = 'Policy Initiatives Template'
metadata description = 'This template deploys the policy initiatives in CONTOSO.'
metadata summary = 'Deploys policy initiatives in CONTOSO.'

targetScope = 'managementGroup'

@description('Policy Definition Source Management Group ID')
param managementGroupId string = managementGroup().id

var deploymentNameSuffix = last(split(deployment().name, '-'))
// ------Read policy initiative definitions from json files------
//DO NOT MODIFY policySetDefinitions variable. The value will be populated by the pipeline
var policySetDefinitions = []

var mappedPolicySetDefinitions = map(range(0, length(policySetDefinitions)), i => {
  name: policySetDefinitions[i].name
  properties: {
    displayName: policySetDefinitions[i].properties.?displayName
    description: policySetDefinitions[i].properties.?description
    metadata: policySetDefinitions[i].properties.?metadata
    parameters: policySetDefinitions[i].properties.?parameters
    policyDefinitionGroups: policySetDefinitions[i].properties.?policyDefinitionGroups
    policyDefinitions: map(range(0, length(policySetDefinitions[i].properties.policyDefinitions)), c => {
      policyDefinitionReferenceId: policySetDefinitions[i].properties.policyDefinitions[c].?policyDefinitionReferenceId
      policyDefinitionId: replace(
        policySetDefinitions[i].properties.policyDefinitions[c].policyDefinitionId,
        '{policyLocationResourceId}',
        managementGroupId
      )
      parameters: policySetDefinitions[i].properties.policyDefinitions[c].?parameters
      groupNames: policySetDefinitions[i].properties.policyDefinitions[c].?groupNames
    })
  }
})

//------Deploy Policy Initiatives------
module policyInitiatives '../../modules/authorization/policy-set-definition/main.bicep' = {
  name: take('policySetDef-${deploymentNameSuffix}', 64)
  params: {
    policySetDefinitions: mappedPolicySetDefinitions
  }
}

//------ Outputs ------
@description('The list of policy initiatives deployed by this template.')
output policySetDefinitions array = policyInitiatives.outputs.policySetDefinitions
