#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.3.1"}
#Requires -Version 7.0

<#
==========================================================================================
AUTHOR: Tao Yang
DATE: 08/08/2025
NAME: assignment.configurations.syntax.tests.ps1
VERSION: 1.0.0
COMMENT: Pester tests for syntax validation of the Policy Assignment configuration files
==========================================================================================
#>

[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true)]
  [validateScript({ Test-Path $_ -PathType Container })]
  [string]$configurationFilesPath,

  [Parameter(Mandatory = $true)]
  [validateScript({ Test-Path $_ -PathType leaf })]
  [string]$configurationSchemaFilePath
)

#Get all the policy assignment configuration files
Write-Verbose "Getting all the policy assignment configuration files from '$configurationFilesPath'..."
$configurationFiles = Get-ChildItem -Path $configurationFilesPath -Recurse -Filter "*.json"
$schema = Get-Content -Path $configurationSchemaFilePath -raw
Write-Verbose "Policy Assignment configuration files:"
$configurationFiles | ForEach-Object { Write-Verbose "  - $($_.name)" }

foreach ($configurationFile in $configurationFiles) {
  Write-Verbose "- Processing Assignment Configuration file '$($configurationFile.Name)..."
  $configurationFileContentJson = $(Get-Content -Path $configurationFile.FullName -Raw | ConvertFrom-Json -Depth 99)
  $testParameters = @{
    configurationFileName        = $configurationFile.Name
    schema                       = $schema
    configurationFilePath        = $configurationFile.FullName
    configurationFileContentJson = $configurationFileContentJson
  }
  Describe "[$($configurationFile.Name)]:Assignment Configuration File Test" -Tag 'ConfigurationFileSyntax' {
    BeforeAll {
    }
    Context 'Policy Assignment Configuration File JSON Schema Validation' -Tag 'JSONSchemaValidation' {
      It "Should align with the JSON schema" -testCases $testParameters -tag 'AlignJsonSchema' {
        param (
          [string]$configurationFilePath,
          [string]$schema
        )
        Test-Json -Path $configurationFilePath -Schema $schema | Should -Be $true -Because "The configuration file '$configurationFilePath' should align with the JSON schema"
      }

      It "Should have JSON Schema specified" -testCases $testParameters -tag 'JsonSchemaSpecified' {
        param (
          [object]$configurationFileContentJson
        )
        $configurationFileContentJson.'$schema' | Should -Not -BeNullOrEmpty -Because "'$schema' property should be specified in the policy assignment configuration file"
      }
    }

    Context 'Policy Assignment property validation' -Tag 'PropertyValidation' {
      It "Assignment Name should align with Azure naming restrictions" -testCases $testParameters -tag "AssignmentName" {
        param (
          [object]$configurationFileContentJson
        )
        $nameLength = $configurationFileContentJson.policyAssignment.name.length
        if ($configurationFileContentJson.subscriptionId.length -gt 0) {
          #It's not a management group scoped assignment, name must be between 1-64 characters
          $maxLength = 64
          $because = "It's not a management group scoped assignment, the name '$($configurationFileContentJson.policyAssignment.name)' must be between 1-64 characters"
        } else {
          #It's a management group scoped assignment, name must be between 1-24 characters
          $maxLength = 24
          $because = "It's a management group scoped assignment, the name '$($configurationFileContentJson.policyAssignment.name)' must be between 1-24 characters"
        }
        $nameLength | Should -BeLessOrEqual $maxLength -Because $because
      }
      It "Assignment Non-Compliance Messages should be present" -testCases $testParameters -tag "NonComplianceMessages" {
        param (
          [object]$configurationFileContentJson
        )
        $nonComplianceMessages = $configurationFileContentJson.policyAssignment.nonComplianceMessages
        $nonComplianceMessages.count | Should -BeGreaterOrEqual 2 -Because "Non-Compliance Messages should be present and contain at least 2 items"
      }
      It "Assignment Should have correct scope defined" -testCases $testParameters -tag "CorrectScopeDefined" {
        param (
          [object]$configurationFileContentJson
        )
        $mg = $configurationFileContentJson.managementGroupId ? $configurationFileContentJson.managementGroupId : $null
        $sub = $configurationFileContentJson.subscriptionId ? $configurationFileContentJson.subscriptionId : $null
        $rg = $configurationFileContentJson.resourceGroupName ? $configurationFileContentJson.resourceGroupName : $null
        if ($null -ne $mg -and $null -eq $sub -and $null -eq $rg) {
          #Management group scoped assignment
          $scopeType = "Management Group"
        } elseif ($null -ne $sub -and $null -eq $mg -and $null -eq $rg) {
          #Subscription scoped assignment
          $scopeType = "Subscription"
        } elseif ($null -ne $sub -and $null -ne $rg -and $null -eq $mg) {
          #Resource group scoped assignment
          $scopeType = "Resource Group"
        } else {
          $scopeType = "Unknown"
        }
        $scopeType | Should -BeIn ("Management Group", "Subscription", "Resource Group") -Because "The policy assignment should have a valid scope defined, either Management Group, Subscription, or Resource Group"
      }
      It "Should have parameters defined" -testCases $testParameters -tag "ParametersDefined" {
        param (
          [object]$configurationFileContentJson
        )
        $configurationFileContentJson.policyAssignment.parameters | Should -Not -BeNullOrEmpty -Because "The policy assignment should have parameters defined"
      }
      It "Should assign a policy initiative" -testCases $testParameters -tag "AssignPolicyInitiative" {
        param (
          [object]$configurationFileContentJson
        )
        $policyInitiativeIdRegex = '(?i)\/providers\/microsoft\.authorization\/policysetdefinitions\/'
        $configurationFileContentJson.policyAssignment.policyDefinitionId -match $policyInitiativeIdRegex | Should -BeTrue -Because "The only policy initiatives should be assigned"
      }
    }

    Context 'Policy Assignment Parameters Validation' -Tag 'ParametersValidation' {
      $parameterNames = Get-Member -InputObject $configurationFileContentJson.policyAssignment.parameters -MemberType NoteProperty | Select-Object -ExpandProperty Name
      foreach ($p in $parameterNames) {
        $parameterMembers = Get-Member -InputObject $configurationFileContentJson.policyAssignment.parameters.$p -MemberType NoteProperty
        $parameterConfigTestCase = @{
          parameterName    = $p
          parameterMembers = $parameterMembers
        }
        It "[$p]Parameters should only have the 'Value' property defined" -tag "ValidParameterNames" -testCases $parameterConfigTestCase {
          param (
            [string]$parameterName,
            [object[]]$parameterMembers
          )
          if ($parameterMembers.count -eq 1 -and $parameterMembers[0].Name -ieq 'value') {
            $isValidParameter = $true
          } else {
            $isValidParameter = $false
          }
          $isValidParameter | Should -Be $true -Because "Parameter '$parameterName' should only have the 'Value' property defined"

        }
      }
    }
  }
}
