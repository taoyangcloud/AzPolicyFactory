<#
.SYNOPSIS
  Generate policy non-compliant messages for each policy definition
.DESCRIPTION
  Generate policy non-compliant messages for each policy definition
.PARAMETER configFilePath
  Specify the path to the policy assignment configuration files
.PARAMETER outputDir
  Output directory for the updated configuration files
.PARAMETER policyLocationResourceId
  Policy location resource Id (for the token replacement for the {policyLocationResourceId} in policyDefinitionId parameter value)
.PARAMETER updatedConfigurationFileArtifactName
  the name of the updated configuration file artifact (for the pipeline build artifact)
.EXAMPLE
  .\pipeline-set-policy-non-compliance-messages.ps1 -configFilePath 'configFileFolder\assignment1.json' -outputDir $pwd -policyLocationResourceId '/providers/Microsoft.Management/managementGroups/contoso' -updatedConfigurationFileArtifactName 'updatedConfigFiles'
  Update a single policy assignment configuration file
.EXAMPLE
  .\pipeline-set-policy-non-compliance-messages.ps1 -configFilePath 'configFileFolder' -outputDir $pwd -policyLocationResourceId '/providers/Microsoft.Management/managementGroups/contoso' -updatedConfigurationFileArtifactName 'updatedConfigFiles'
  Update all policy assignment configuration file in a folder
#>
#Requires -Modules Az.Accounts
#Requires -Module @{ModuleName="Az.ResourceGraph"; ModuleVersion="0.10.0"}
<#
=================================================================================================
AUTHOR: Tao Yang
DATE: 19/05/2025
NAME: pipeline-set-policy-non-compliance-messages.ps1
VERSION: 1.2.0
COMMENT: Generate policy non-compliant messages for each policy definition
VERSION HISTORY:
1.0.0 - 04/05/2024 - Initial version
1.0.1 - 02/02/2024 - Fix the Azure Resource Graph query to make resource Id case insensitive
1.1.0 - 19/05/2025 - Add support to allow existing non-compliance messages in the parameter file
1.2.0 - 05/08/2025 - Updated to support the new assignment configuration file structure
=================================================================================================
#>
[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ })]
  [string]$configFilePath,

  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$outputDir,

  [parameter(Mandatory = $true)]
  [string]$policyLocationResourceId,

  [parameter(Mandatory = $true)]
  [string]$updatedConfigurationFileArtifactName
)
#region functions
function getDefinitions {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$resourceId,

    [Parameter(Mandatory = $false)]
    [ValidateSet('all', 'policy', 'initiative')]
    [string] $queryType = 'all'

  )
  #convert multiple resourceIds to string
  $arrResourceId = @()
  foreach ($item in $resourceId) {
    $arrResourceId += "'$item'"
  }
  $strResourceId = $arrResourceId -join ','
  $strResourceId = $strResourceId.ToLower()

  # Have separate queries for policy and initiative definitions to improve query performance by filtering out unnecessary data
  Switch ($queryType) {
    'all' {
      $argQuery = @"
policyresources
| where tolower(id) in ($strResourceId)
"@
    }
    'policy' {
      $argQuery = @"
policyresources
| where type =~ 'microsoft.authorization/policydefinitions'
| where tolower(id) in ($strResourceId)
| project kind, id, displayName = properties.displayName, policyType = properties.policyType, mode = properties.mode
"@
    }
    'initiative' {
      $argQuery = @"
policyresources
| where type =~ 'microsoft.authorization/policysetdefinitions'
| where tolower(id) in ($strResourceId)
| extend memberPolicies=properties.policyDefinitions
| project kind, id, displayName = properties.displayName, memberPolicies
"@
    }
  }
  Write-Verbose "Searching policy and initiative definitions using ARG query:" -verbose
  Write-Verbose $argQuery -Verbose
  $definitions = & $script:resourceSearchScriptPath -ScopeType 'tenant' -customQuery $argQuery | ConvertFrom-Json

  if ($definitions.Count -eq 0) {
    throw "No definitions found for in the tenant."
  } else {
    Write-Verbose "Total number of definitions found: $($definitions.count)." -verbose
  }
  $definitions
}

function updateConfigFile {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$configFilePath,

    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$outputDir,

    [parameter(Mandatory = $true)]
    [string]$policyLocationResourceId,

    [parameter(Mandatory = $true)]
    [string]$updatedConfigurationFileArtifactName
  )

  $script:resourceSearchScriptPath = join-path $PSScriptRoot 'pipeline-resource-search.ps1'
  $arrNonCompliantMessages = @()

  #parse policy assignment config file
  $assignmentConfigFileJson = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json

  #get existing non-compliance messages
  $existingNonComplianceMessages = $assignmentConfigFileJson.policyAssignment.nonComplianceMessages

  #Get definition resource Id
  $AssignmentDefinitionResourceId = $assignmentConfigFileJson.policyAssignment.policyDefinitionId.replace('{policyLocationResourceId}', $policyLocationResourceId)

  $definitionSourceManagementGroupId = $assignmentConfigFileJson.definitionSourceManagementGroupId

  $AssignmentDefinitionResourceId = $AssignmentDefinitionResourceId -replace '{policyLocationResourceId}', $definitionSourceManagementGroupId
  #Get policy definition
  $AssignmentDefinition = getDefinitions -resourceId $AssignmentDefinitionResourceId -queryType 'all'

  if (!$AssignmentDefinition) {
    throw "No policy definition found for the given policy definition resource Id [$AssignmentDefinitionResourceId]."
    exit 1
  }
  #Default message
  $defaultMessage = "You have not met all standards set by '{0}'. Refer to the policy for requirements." -f $AssignmentDefinition[0].name

  # Add default message to the array
  $arrNonCompliantMessages += [PSCustomObject]@{
    message = $defaultMessage
  }
  Write-Verbose "Type of the assigned policy is  $($AssignmentDefinition[0].kind)" -verbose
  Write-Verbose "Display name of the assigned policy is $($AssignmentDefinition[0].properties.displayName)" -verbose

  #If assigned policy is an initiative, get all policy definitions in the initiative
  if ($AssignmentDefinition[0].kind -ieq 'policysetdefinitions') {
    $memberPolicies = $AssignmentDefinition[0].properties.policyDefinitions
    $memberPolicyDefinitionsResourceId = @()
    #firstly get all member policy definition resource Ids via a single ARG search query
    foreach ($memberPolicy in $memberPolicies) {
      $memberPolicyDefinitionsResourceId += $memberPolicy.policyDefinitionId
    }
    $memberPolicyDefinitions = getDefinitions -resourceId $memberPolicyDefinitionsResourceId -queryType 'policy'
    #then map the reference id and displayName for all member policy definitions
    foreach ($memberPolicy in $memberPolicies) {
      # Populate non-compliance messages for each member policy definition if it is not already defined in the config file
      if ($existingNonComplianceMessages.policyDefinitionReferenceId -notcontains $memberPolicy.policyDefinitionReferenceId) {
        Write-Verbose "Processing member policy definition with reference id $($memberPolicy.policyDefinitionReferenceId)" -verbose

        $memberPolicyDefinition = $memberPolicyDefinitions | Where-Object { $_.id -eq $memberPolicy.policyDefinitionId }
        Write-Verbose "  - $($memberPolicy.policyDefinitionReferenceId) Resource Id is $($memberPolicyDefinition.id)" -verbose
        Write-Verbose "  - $($memberPolicy.policyDefinitionReferenceId) DisplayName is $($memberPolicyDefinition.displayName)" -verbose
        Write-Verbose "  - $($memberPolicy.policyDefinitionReferenceId) Mode is $($memberPolicyDefinition.mode)" -verbose
        if ($memberPolicyDefinition.mode -ine 'all' -and $memberPolicyDefinition.mode -ine 'indexed') {
          Write-Verbose "  - The mode for [$($memberPolicy.policyDefinitionReferenceId)] - [$($memberPolicyDefinition.displayName)] is [$($memberPolicyDefinition.mode)]. Only policy mode 'all' and 'indexed' are supported for custom non-compliance messages. This policy will be skipped." -verbose
        } else {
          $arrNonCompliantMessages += [PSCustomObject]@{
            policyDefinitionReferenceId = $memberPolicy.policyDefinitionReferenceId
            message                     = "PolicyID: {0} Violation in {1} Initiative - '{2}'" -f $memberPolicy.policyDefinitionReferenceId, $AssignmentDefinition[0].name, $memberPolicyDefinition.displayName
          }
        }
      } else {
        Write-Verbose "Non-compliance message for policy definition reference id [$($memberPolicy.policyDefinitionReferenceId)] already exists in the configuration file." -verbose
      }
    }
  }

  #Convert the array to JSON
  #add existing non-compliance messages to the array
  if ($existingNonComplianceMessages) {
    foreach ($item in $existingNonComplianceMessages) {
      $arrNonCompliantMessages += [PSCustomObject]@{
        policyDefinitionReferenceId = $item.policyDefinitionReferenceId
        message                     = $item.message
      }
    }
  }
  $arrNonCompliantMessages = $arrNonCompliantMessages | Sort-Object policyDefinitionReferenceId

  #make sure the non-compliance messages are valid
  $validateNonComplianceMessagesResult = validateNonComplianceMessages -nonComplianceMessages $arrNonCompliantMessages
  if ($validateNonComplianceMessagesResult.isValid -eq $true) {
    Write-verbose $validateNonComplianceMessagesResult.messages[0] -Verbose
  } else {
    Foreach ($m in $validateNonComplianceMessagesResult.messages) {
      Write-Error $m
    }
    Exit 1
  }
  $nonCompliantMessagesJson = $arrNonCompliantMessages | ConvertTo-Json -Depth 10 -AsArray

  Write-Verbose "Non-Compliant Messages:" -verbose
  Write-Verbose $nonCompliantMessagesJson -verbose

  #update the config file and output to a separate file

  # Save Updated config File
  $UpdatedConfigFileDirPath = Join-Path $outputDir $updatedConfigurationFileArtifactName
  Write-Verbose "Save the updated config file to '$UpdatedConfigFileDirPath'" -Verbose
  if (!(Test-Path $UpdatedConfigFileDirPath)) {
    New-Item -Path $UpdatedConfigFileDirPath -ItemType Directory | out-null
  }
  $outputFilePath = join-path $UpdatedConfigFileDirPath $(Get-Item $configFilePath).Name
  #$assignmentConfigFileJson.policyAssignment.nonComplianceMessages = $nonCompliantMessagesJson | convertFrom-Json -Depth 10
  if ($arrNonCompliantMessages.count -gt 1) {
    $assignmentConfigFileJson.policyAssignment.nonComplianceMessages = $arrNonCompliantMessages
  } else {
    $assignmentConfigFileJson.policyAssignment.nonComplianceMessages = , $arrNonCompliantMessages
  }

  if (Test-Path $outputFilePath) {
    Write-Warning "Output file [$outputFilePath] already exists. It will be overwritten."
  }
  ConvertTo-Json -InputObject $assignmentConfigFileJson -Depth 100 | Out-File -FilePath $outputFilePath -Force
  $outputFilePath
}

function validateNonComplianceMessages {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [array]$nonComplianceMessages
  )
  $messages = @()
  $isValid = $true
  #make sure there's exact ONE generic message without the policyDefinitionReferenceId property
  $genericMessage = $nonComplianceMessages | Where-Object { $null -eq $_.policyDefinitionReferenceId }
  if ($genericMessage.Count -ne 1) {
    $messages += "The Non-Compliance messages payload should contain exactly one generic message without the policyDefinitionReferenceId property."
    $isValid = $false
  }

  #make sure all policyDefinitionReferenceId are unique and find out duplicate ones
  $policyDefinitionReferenceIds = $nonComplianceMessages | Where-Object { $null -ne $_.policyDefinitionReferenceId } | Select-Object -ExpandProperty policyDefinitionReferenceId

  # Find duplicates
  $duplicateIds = $policyDefinitionReferenceIds | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name

  if ($duplicateIds.Count -gt 0) {
    $messages += "The following policyDefinitionReferenceId values are duplicated: $($duplicateIds -join ', ')"
    $isValid = $false
  }
  if ($isValid) {
    $messages += "The Non-Compliance messages payload is valid."
  }
  #return the validation result
  @{
    IsValid  = $isValid
    Messages = $messages
  }
}
#endregion

#region main
#determine if the config file path is a single file or a folder
if (Test-Path $configFilePath -PathType Leaf) {
  Write-Verbose "Config File Path is a single file." -verbose
  $outputFilePath = updateConfigFile -configFilePath $configFilePath -outputDir $outputDir -policyLocationResourceId $policyLocationResourceId -updatedConfigurationFileArtifactName $updatedConfigurationFileArtifactName
  Write-Output "Updated config file saved to $outputFilePath"
} else {
  Write-Verbose "Config File Path is a folder." -verbose
  $configFiles = Get-ChildItem -Path $configFilePath -Filter '*.json' -File
  $outputFilePaths = @()
  foreach ($configFile in $configFiles) {
    $outputFilePaths += updateConfigFile -configFilePath $configFile.FullName -outputDir $outputDir -policyLocationResourceId $policyLocationResourceId -updatedConfigurationFileArtifactName $updatedConfigurationFileArtifactName
  }
  Write-Output "Updated config files saved to:"
  foreach ($item in $outputFilePaths) {
    Write-Output "  - '$item'"
  }
}
#endregion
