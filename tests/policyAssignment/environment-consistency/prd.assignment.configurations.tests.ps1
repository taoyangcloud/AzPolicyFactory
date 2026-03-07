#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.3.1"}
#Requires -Version 7.0

<#
=================================================================================================================
AUTHOR: Tao Yang
DATE: 08/08/2025
NAME: prd.assignment.configurations.tests.ps1
VERSION: 1.0.0
COMMENT: Pester tests for environment consistency between environments for Policy Assignment configuration files
=================================================================================================================
#>

[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true)]
  [validateScript({ Test-Path $_ -PathType Container })]
  [string]$prodConfigurationFilesPath,

  [Parameter(Mandatory = $true)]
  [validateScript({ Test-Path $_ -PathType Container })]
  [string]$devConfigurationFilesPath
)
#variables

$script:helperModulePath = join-path $PSScriptRoot 'helper.psm1'
$script:configFilePath = (resolve-path -relativeBasePath $PSScriptRoot -path './assignment_configuration_consistency_test_config.jsonc').path
# load helper functions

import-module $script:helperModulePath

# load the configuration file
Write-Verbose "Loading test configuration file from '$configFilePath'..."
$config = Get-content -Path $script:configFilePath -Raw | convertFrom-Json -Depth 99 -AsHashtable
#convert hashtable keys to case-insensitive (workaround from this github issue: https://github.com/PowerShell/PowerShell/issues/19928)
$Script:config = [HashTable]::New($config, [StringComparer]::OrdinalIgnoreCase)

#Get all the policy assignment configuration files in the production environment
Write-Verbose "Getting all the policy assignment configuration files in the Production environment from '$prodConfigurationFilesPath'..."
$prodConfigurationFiles = Get-ChildItem -Path $prodConfigurationFilesPath -Recurse -Filter "*.json"

Write-Verbose "Production Policy Assignment configuration files:"
$prodConfigurationFiles | ForEach-Object { Write-Verbose "  - $($_.name)" }

foreach ($configurationFile in $prodConfigurationFiles) {
  Write-Verbose "- Processing Production Assignment Configuration file '$($configurationFile.Name)..."
  #Read configuration file content into a hashtable
  $configurationFileContent = readConfigurationFile -filePath $configurationFile.FullName
  $assignmentName = $configurationFileContent.policyAssignment.name
  Write-Verbose "  - Assignment Name: '$assignmentName'."
  $configurationFileNotScopes = $configurationFileContent.policyAssignment.containsKey('notScopes') ? $($configurationFileContent.policyAssignment.notScopes | where-object { $config.assignmentNotScopeExclusions -inotcontains $_ }) : @()
  #check if notScopes deviation is present for the assignment
  $notScopesDeviation = $config.assignmentNotScopeDeviations | where-object { $_.sourceAssignmentName -ieq $assignmentName }
  if ($notScopesDeviation) {
    Write-Verbose "  - NotScopes deviation found for the assignment '$assignmentName'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    $mappedNotScopes = $notScopesDeviation.correspondingNotScopeValue
  } else {
    Write-Verbose "  - No NotScopes deviation found for the assignment '$assignmentName'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    $mappedNotScopes = getCorrespondingResourceIds -config $config -sourceResourceId $configurationFileNotScopes -sourceEnvironment 'production' -correspondingEnvironment 'development' -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
  }

  #Get deployment target Management Group
  $deploymentTargetMG = getDeploymentTargetScopeFromConfigurationFile -fileContent $configurationFileContent
  #Get mapped corresponding deployment Target Management Group in Development environment
  $mappedDevDeploymentTargetMG = getTargetScopeMapping -type 'managementGroup' -from 'production' -name $deploymentTargetMG -config $Script:config -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
  $policyDefinitionDetails = getDefinitionDetailsFromConfigurationFile -fileContent $configurationFileContent -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
  Write-Verbose "  - Deployment target Management Group: '$deploymentTargetMG'."
  Write-Verbose "  - Mapped Development Environment deployment target Management Group: '$mappedDevDeploymentTargetMG'."
  Write-Verbose "  - Policy Definition Id: '$($policyDefinitionDetails.policyDefinitionId)'."
  Write-Verbose "  - Is custom definition: $($policyDefinitionDetails.isCustom)"
  if ($policyDefinitionDetails.definitionSourceManagementGroupName.length -gt 0) {
    Write-Verbose "  - Policy Definition Source Management Group: '$($policyDefinitionDetails.definitionSourceManagementGroupName)'."
    $mappedPolicyDefinitionSourceMG = getTargetScopeMapping -type 'managementGroup' -from 'production' -name $policyDefinitionDetails.definitionSourceManagementGroupName -config $Script:config -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    Write-Verbose "  - Mapped Development Environment Policy Definition Source Management Group: '$mappedPolicyDefinitionSourceMG'."
  }
  #for custom policies, replace the policy definition source management group with the mapped corresponding management group in development environment
  if ($policyDefinitionDetails.isCustom) {

    $policyDefinitionId = $policyDefinitionDetails.policyDefinitionId -replace '{policyLocationResourceId}', $policyDefinitionDetails.definitionSourceManagementGroupName
    $mappedPolicyDefinitionId = getMappedCustomPolicyDefinitionId -customPolicyDefinitionId $policyDefinitionId -mappedManagementGroup $mappedPolicyDefinitionSourceMG -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    Write-Verbose "  - Mapped Development Environment Custom Policy Definition Id: '$mappedPolicyDefinitionId'."
  }
  Write-Verbose "  - Searching for the corresponding policy assignment configuration file in Development environment..."
  $devAssignments = getPolicyAssignment -policyDefinitionId $mappedPolicyDefinitionId -assignmentScope $mappedDevDeploymentTargetMG -assignmentNotScopes $mappedNotScopes -directory $devConfigurationFilesPath -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)

  #Parameter File Count Test case
  $configurationFileCountTest = @{
    correspondingDevAssignmentsCount = $devAssignments.Count
  }

  #individual assignment parameter test cases
  $configurationTests = @()
  foreach ($devAssignment in $devAssignments) {
    $configurationTests += @{
      prdConfigurationFileName    = $configurationFile.Name
      prdAssignmentName           = $assignmentName
      prdConfigurationFilePath    = $configurationFile.FullName
      prdConfigurationFileContent = $configurationFileContent
      prodPolicyDefinitionDetails = $policyDefinitionDetails
      prdAssignmentTargetMG       = $deploymentTargetMG
      correspondingDevAssignment  = $devAssignment
    }
  }

  Write-Verbose "  - Corresponding policy assignment configuration file count in Development environment: $($configurationFileCountTest.correspondingDevAssignmentsCount)." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)

  Describe "[$($configurationFile.Name)]:Production Assignment Configuration File Content Test" -Tag 'ProdConfigurationContent' {
    BeforeAll {
      $script:helperModulePath = join-path $PSScriptRoot 'helper.psm1'
      import-module $script:helperModulePath -verbose:$false
      $script:configFilePath = (resolve-path -relativeBasePath $PSScriptRoot -path './assignment_configuration_consistency_test_config.jsonc').path
      $config = Get-content -Path $script:configFilePath -Raw | convertFrom-Json -Depth 99 -AsHashtable
      #convert hashtable keys to case-insensitive (workaround from this github issue: https://github.com/PowerShell/PowerShell/issues/19928)
      $Script:config = [HashTable]::New($config, [StringComparer]::OrdinalIgnoreCase)
    }
    Context 'Matching Policy Assignment Configuration File Count Test' -Tag 'MatchingAssignmentCountContext' {
      It "Should have exact ONE (1) corresponding policy assignment configuration file in Development environment" -testCases $configurationFileCountTest -tag 'MatchingDevAssignmentCount' {
        param (
          [array]$correspondingDevAssignmentsCount
        )
        $correspondingDevAssignmentsCount | Should -Be 1 -Because "There should be exactly one corresponding policy assignment configuration file in Development environment for the Production assignment configuration file '$($configurationFile.Name)'."
      }
    }
    Context 'Assignment Non-Compliance Messages Test' -Tag 'AssignmentNonComplianceMessagesContext' -foreach $configurationTests {
      It "[$($configurationFile.Name)] Should have the case-sensitive exact matching non-compliance messages in Development environment" -Tag 'AssignmentNonComplianceMessagesTest' {
        $prdNonComplianceMessages = $prdConfigurationFileContent.policyAssignment.nonComplianceMessages | convertTo-Json -Depth 100 -Compress
        $devNonComplianceMessages = $correspondingDevAssignment.fileContent.policyAssignment.nonComplianceMessages | convertTo-Json -Depth 100 -Compress
        Write-Verbose "  - Production Assignment Non-Compliance Messages: $prdNonComplianceMessages"
        Write-Verbose "  - Development Assignment Non-Compliance Messages: $devNonComplianceMessages"
        $prdNonComplianceMessages -ceq $devNonComplianceMessages | Should -Be $true -because "Non-Compliance Messages should match exactly between Production and Development environments."
      }
    }
    Context 'Assignment Parameters Test' -Tag 'AssignmentParametersContext' -foreach $configurationTests {
      It "[$($configurationFile.Name)] vs [$($correspondingDevAssignment.fileName)] Should have the same assignment parameters in Development environment" -Tag 'AssignmentParametersTest' {
        $prdAssignmentParameters = $prdConfigurationFileContent.policyAssignment.parameters.keys | sort-object
        $devAssignmentParameters = $correspondingDevAssignment.fileContent.policyAssignment.parameters.keys | sort-object
        Write-Verbose "  - Production Assignment Parameters: $($prdAssignmentParameters -join ', ')."
        Write-Verbose "  - Development Assignment Parameters: $($devAssignmentParameters -join ', ')."
        $prdAssignmentParameters | Should -Be $devAssignmentParameters -Because "Same parameters should be specified for Production and Development environments."
      }
      foreach ($p in $prdConfigurationFileContent.policyAssignment.parameters.keys) {
        $prdParameterConfig = $prdConfigurationFileContent.policyAssignment.parameters.$p
        $devParameterConfig = $correspondingDevAssignment.fileContent.policyAssignment.parameters.$p
        $devConfigurationFileName = $correspondingDevAssignment.fileName

        $isValueEnvironmentSpecificResourceId = isEnvironmentSpecificResourceId $prdParameterConfig.value -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $strPrdValue = $prdParameterConfig.value | ConvertTo-json -Depth 100 -Compress
        $strDevValue = $devParameterConfig.value | ConvertTo-json -Depth 100 -Compress
        $parameterValueTestCase = @{
          parameterName                        = $p
          prdAssignmentName                    = $prdAssignmentName
          prdAssignmentTargetMG                = $prdAssignmentTargetMG
          prdParameterConfig                   = $prdParameterConfig
          devParameterConfig                   = $devParameterConfig
          devConfigurationFileName             = $devConfigurationFileName
          strPrdValue                          = $strPrdValue
          strDevValue                          = $strDevValue
          isValueEnvironmentSpecificResourceId = $isValueEnvironmentSpecificResourceId
        }
        It "[$($configurationFile.Name)] vs [$devConfigurationFileName] Should have matching environment-specific resource Id for parameter '$p' in Development environment" -testCases ($parameterValueTestCase | where-object { $_.isValueEnvironmentSpecificResourceId -eq $true }) -Tag 'ResourceIdParameterValuesTest' {
          param (
            [hashtable]$prdParameterConfig,
            [hashtable]$devParameterConfig,
            [string]$devConfigurationFileName,
            [string]$strPrdValue,
            [string]$strDevValue,
            [boolean]$isValueEnvironmentSpecificResourceId
          )

          Write-Verbose "Development Assignment Configuration File Name: '$devConfigurationFileName'."
          Write-Verbose "Production Assignment Parameter '$parameterName' value: '$strPrdValue'."
          Write-Verbose "Development Assignment Parameter '$parameterName' value: '$strDevValue'."
          $correspondingDevValues = getCorrespondingEnvironmentSpecificValues -config $Script:config -sourceValue $($prdParameterConfig.value) -sourceEnvironment 'production' -correspondingEnvironment 'development' -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
          $containsAllDevValues = $true
          foreach ($dv in $devParameterConfig.value) {
            if ($correspondingDevValues -inotcontains $dv) {
              $containsAllDevValues = $false
            }
          }
          $containsAllDevValues | Should -Be $true -because "Production environment Specific resource IDs should match its corresponding values in Development environment defined in the configuration."
        }
        It "[$($configurationFile.Name)] vs [$devConfigurationFileName] Should have valid value for generic parameter '$p' in Development environment " -testCases ($parameterValueTestCase | where-object { $_.isValueEnvironmentSpecificResourceId -eq $false }) -Tag 'GenericParameterValuesTest' {
          param (
            [string]$parameterName,
            [hashtable]$prdParameterConfig,
            [hashtable]$devParameterConfig,
            [string]$devConfigurationFileName,
            [string]$strPrdValue,
            [string]$strDevValue,
            [string]$prdAssignmentName,
            [string]$prdAssignmentTargetMG,
            [boolean]$isValueEnvironmentSpecificResourceId
          )
          Write-Verbose "Production Assignment Name: '$prdAssignmentName'."
          Write-Verbose "Development Assignment Configuration File Name: '$devConfigurationFileName'."
          Write-Verbose "Production Assignment Parameter '$parameterName' value: '$strPrdValue'."
          Write-Verbose "Development Assignment Parameter '$parameterName' value: '$strDevValue'."
          $isValidGenericValue = isValidGenericParameterValue -config $Script:config -sourceAssignmentName $prdAssignmentName -sourceAssignmentScopeName $prdAssignmentTargetMG -parameterName $parameterName -sourceValue $prdParameterConfig.value -correspondingValue $devParameterConfig.value -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
          Write-Verbose "Is valid generic value: $isValidGenericValue"
          $isValidGenericValue | Should -Be $true -Because "Generic parameter '$parameterName' value should be valid and match the expected value in Development environment."
        }
      }
    }
  }
}
