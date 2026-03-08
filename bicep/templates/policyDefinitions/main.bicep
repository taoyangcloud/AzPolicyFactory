metadata name = 'Policy Definitions Template'
metadata description = 'This template deploys the policy definitions in Contoso.'
metadata summary = 'Deploys policy definitions in Contoso.'

targetScope = 'managementGroup'

// ---------- Variables ----------
//DO NOT MODIFY policyDefinitions variable. The value will be populated by the pipeline
var policyDefinitions = []

var deploymentNameSuffix = last(split(deployment().name, '-'))

module policyDefs '../../modules/authorization/policy-definition/main.bicep' = {
  name: take('policyDef-${deploymentNameSuffix}', 64)
  params: {
    policyDefinitions: policyDefinitions
  }
}

@description('The list of policy definitions deployed by this template.')
output policyDefinitions array = policyDefs.outputs.policyDefinitions
