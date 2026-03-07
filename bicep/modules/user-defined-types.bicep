type PolicyDefinitionReferenceType = {
  @sys.description('Optional. The name of the groups that this policy definition reference belongs to.')
  groupNames: array?

  @sys.description('Optional. The parameter values for the referenced policy rule. The keys are the parameter names.')
  parameters: object?

  @sys.description('Required. The ID of the policy definition or policy set definition.')
  policyDefinitionId: string

  @sys.description('Optional. A unique id (within the policy set definition) for this policy definition reference.')
  policyDefinitionReferenceId: string?

  @sys.description('Optional. The version of the policy definition to use.')
  definitionVersion: string?
}[]

type policyDefinitionGroupsType = {
  @sys.description('Required. The name of the group.')
  name: string

  @sys.description('Optional. The display name of the group.')
  displayName: string?

  @sys.description('Optional. The description of the group.')
  description: string?

  @sys.description('Optional. the category of the group.')
  category: string?

  @sys.description('Optional. A resource ID of a resource that contains additional metadata about the group.')
  additionalMetadataId: string?
}[]?

type policyDefinitionPropertiesType = {
  @sys.description('Optional. The display name of the policy definition. Maximum length is 128 characters.')
  @maxLength(128)
  displayName: string?

  @sys.description('Optional. The policy definition description.')
  description: string?

  @sys.description('Required. The policy definition mode. Default is All, Some examples are All, Indexed, Microsoft.KeyVault.Data.')
  mode: (
    | 'All'
    | 'Indexed'
    | 'Microsoft.KeyVault.Data'
    | 'Microsoft.ContainerService.Data'
    | 'Microsoft.Kubernetes.Data'
    | 'Microsoft.Network.Data')

  @sys.description('Optional. The policy Definition metadata. Metadata is an open ended object and is typically a collection of key-value pairs.')
  metadata: object?

  @sys.description('Optional. The details of the source of external evaluation results required by the policy during enforcement evaluation.')
  externalEvaluationEnforcementSettings: object?

  @sys.description('Optional. The policy definition parameters that can be used in policy definition references.')
  parameters: object?

  @sys.description('Required. The Policy Rule details for the Policy Definition.')
  policyRule: object

  @sys.description('Optional. The policy definition version in semantic versioning format.')
  version: string?
}

type policySetDefinitionPropertiesType = {
  @sys.description('Optional. The display name of the Set Definition (Initiative). Maximum length is 128 characters.')
  displayName: string?

  @sys.description('Optional. The description of the Set Definition (Initiative).')
  description: string?

  @sys.description('Optional. The Set Definition (Initiative) metadata. Metadata is an open ended object and is typically a collection of key-value pairs.')
  metadata: object?

  @sys.description('Optional. The Set Definition (Initiative) parameters that can be used in policy definition references.')
  parameters: object?

  @sys.description('Optional. The metadata describing groups of policy definition references within the Policy Set Definition (Initiative).')
  policyDefinitionGroups: policyDefinitionGroupsType?

  @sys.description('Required. The array of Policy definitions object to include for this policy set. Each object must include the Policy definition ID, and optionally other properties like parameters.')
  policyDefinitions: PolicyDefinitionReferenceType

  @sys.description('Optional. The policy set definition version in semantic versioning format.')
  version: string?
}

@export()
type policyDefinitionType = {
  @sys.description('Required. Specifies the name of the policy definition. Maximum length is 64 characters.')
  @maxLength(64)
  name: string

  @sys.description('Required. The policy definition properties.')
  properties: policyDefinitionPropertiesType
}[]

@export()
type policySetDefinitionType = {
  @sys.description('Required. The name of the policy Set Definition (Initiative).')
  name: string

  @sys.description('Required. The policy set definition properties.')
  properties: policySetDefinitionPropertiesType
}[]

@export()
type policyAssignmentType = {
  @sys.description('Required. Specifies the name of the policy assignment. Maximum length is 24 characters for management group scope.')
  @maxLength(24)
  name: string

  @sys.description('Optional. This description of the policy assignment.')
  description: string?

  @sys.description('Optional. The display name of the policy assignment. Maximum length is 128 characters.')
  @maxLength(128)
  displayName: string?

  @sys.description('Optional. The type of policy assignment. Possible values are NotSpecified, System, SystemHidden, and Custom. Immutable.')
  assignmentType: ('NotSpecified' | 'System' | 'SystemHidden' | 'Custom')

  @sys.description('Required. Specifies the ID of the policy definition or policy set definition being assigned.')
  policyDefinitionId: string

  @sys.description('Optional. The version of the policy definition to use..')
  definitionVersion: string?

  @sys.description('Optional. Parameters for the policy assignment if needed.')
  parameters: object?

  @sys.description('Optional. The managed identity associated with the policy assignment. Policy assignments must include a resource identity when assigning \'Modify\' policy definitions.')
  identity: ('SystemAssigned' | 'UserAssigned' | 'None' | null)

  @sys.description('Optional. The Resource ID for the user assigned identity to assign to the policy assignment.')
  userAssignedIdentityId: string?

  @sys.description('Optional. The IDs Of the Azure Role Definition list that is used to assign permissions to the identity. You need to provide either the fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles for the list IDs for built-in Roles. They must match on what is on the policy definition.')
  roleDefinitionIds: array?

  @sys.description('Optional. The policy assignment metadata. Metadata is an open ended object and is typically a collection of key-value pairs.')
  metadata: object?

  @sys.description('Optional. The messages that describe why a resource is non-compliant with the policy.')
  nonComplianceMessages: array?

  @sys.description('Optional. The policy assignment enforcement mode. Possible values are Default, DoNotEnforce and Enroll.')
  enforcementMode: ('Default' | 'DoNotEnforce' | 'Enroll' | null)

  @sys.description('Optional. The policy excluded scopes.')
  notScopes: array?

  @sys.description('Optional. The policy property value override. Allows changing the effect of a policy definition without modifying the underlying policy definition or using a parameterized effect in the policy definition.')
  overrides: array?

  @sys.description('Optional. The resource selector list to filter policies by resource properties. Facilitates safe deployment practices (SDP) by enabling gradual roll out policy assignments based on factors like resource location, resource type, or whether a resource has a location.')
  resourceSelectors: array?
}

type policyExemptionResourceSelectorSelector = {
  @sys.description('Optional. The list of values to filter in.')
  in: string[]?

  @sys.description('Required. The selector kind.')
  kind: (
    | 'GroupPrincipalId'
    | 'policyDefinitionReferenceId'
    | 'resourceLocation'
    | 'resourceType'
    | 'resourceWithoutLocation'
    | 'UserPrincipalId')

  @sys.description('Optional. The list of values to filter out.')
  notIn: string[]?
}

type policyExemptionResourceSelector = {
  @sys.description('Required. The name of the resource selector.')
  name: string

  @sys.description('Required. The list of the selector expressions.')
  selectors: policyExemptionResourceSelectorSelector[]
}

@export()
type policyExemptionType = {
  @sys.description('Required. Specifies the name of the policy exemption. Maximum length is 64 characters.')
  @maxLength(64)
  name: string

  @sys.description('Optional. The description of the policy exemption.')
  description: string?

  @sys.description('Optional. The display name of the policy exemption. Maximum length is 128 characters.')
  @maxLength(128)
  displayName: string?

  @sys.description('Optional. The policy exemption metadata. Metadata is an open ended object and is typically a collection of key-value pairs.')
  metadata: object?

  @sys.description('Required. The ID of the policy assignment that is being exempted.')
  policyAssignmentId: string

  @sys.description('Required. The policy exemption category. Possible values are Waiver and Mitigated.')
  exemptionCategory: ('Mitigated' | 'Waiver')

  @sys.description('Required. The option whether validate the exemption is at or under the assignment scope..')
  assignmentScopeValidation: ('Default' | 'DoNotValidate')

  @sys.description('Optional. The expiration date and time (in UTC ISO 8601 format yyyy-MM-ddTHH:mm:ssZ) of the policy exemption.')
  expiresOn: string?

  @sys.description('Optional. The policy definition reference ID list when the associated policy assignment is an assignment of a policy set definition.')
  policyDefinitionReferenceIds: string[]?

  @sys.description('Optional. The resource selector list to filter policies by resource properties.')
  resourceSelectors: policyExemptionResourceSelector[]?
}

@export()
type roleAssignmentForPolicyAssignmentType = {
  @sys.description('Required. You can provide either the display name of the role definition, or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
  roleDefinitionIdOrName: string

  @sys.description('Optional. Name of the Resource Group to assign the RBAC role to. If Resource Group name is provided, and Subscription ID is provided, the module deploys at resource group level, therefore assigns the provided RBAC role to the resource group.')
  resourceGroupName: string?

  @sys.description('Optional. Subscription ID of the subscription to assign the RBAC role to. If no Resource Group name is provided, the module deploys at subscription level, therefore assigns the provided RBAC role to the subscription.')
  subscriptionId: string?

  @sys.description('Optional. Group ID of the Management Group to assign the RBAC role to. If not provided, will use the current scope for deployment.')
  managementGroupId: string?

  @sys.description('Optional. The description of the role assignment.')
  description: string?

  @sys.description('Optional. The conditions on the role assignment. This limits the resources it can be assigned to.')
  condition: string?
}
