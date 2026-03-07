#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.3.1"}
#Requires -Version 7.0

<#
==========================================================================================
AUTHOR: Tao Yang
DATE: 08/08/2025
NAME: exemption.configurations.syntax.tests.ps1
VERSION: 1.0.0
COMMENT: Pester tests for syntax validation of the Policy Exemption configuration files
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

#Get all the policy exemption configuration files
Write-Verbose "Getting all the policy exemption configuration files from '$configurationFilesPath'..."
$configurationFiles = Get-ChildItem -Path $configurationFilesPath -Recurse -Filter "*.json"
$schema = Get-Content -Path $configurationSchemaFilePath -raw
Write-Verbose "Policy Exemption configuration files:"
$configurationFiles | ForEach-Object { Write-Verbose "  - $($_.name)" }

foreach ($configurationFile in $configurationFiles) {
  Write-Verbose "- Processing Exemption Configuration file '$($configurationFile.Name)..."
  $configurationFileContentJson = $(Get-Content -Path $configurationFile.FullName -Raw | ConvertFrom-Json -Depth 99)
  try {
    $approvedDate = [datetime]::ParseExact($configurationFileContentJson.policyExemption.metadata.approvedOn, 'yyyy-MM-dd', $null)
  } catch {
    $approvedDate = $null
  }
  $testParameters = @{
    configurationFileName        = $configurationFile.Name
    schema                       = $schema
    configurationFilePath        = $configurationFile.FullName
    configurationFileContentJson = $configurationFileContentJson
    approvedDate                 = $approvedDate
  }
  Describe "[$($configurationFile.Name)]:Exemption Configuration File Test" -Tag 'ConfigurationFileSyntax' {
    BeforeAll {
    }
    Context 'Policy Exemption Configuration File JSON Schema Validation' -Tag 'JSONSchemaValidation' {
      It "Should align with the JSON schema" -testCases $testParameters -tag 'AlignJsonSchema' {
        param (
          [string]$configurationFilePath,
          [string]$schema
        )
        Test-Json -Path $configurationFilePath -Schema $schema | Should -Be $true -Because "The configuration file '$configurationFilePath' should align with the JSON schema."
      }

      It "Should have JSON Schema specified" -testCases $testParameters -tag 'JsonSchemaSpecified' {
        param (
          [object]$configurationFileContentJson
        )
        $configurationFileContentJson.'$schema' | Should -Not -BeNullOrEmpty -Because "'$schema' property should be specified in the policy exemption configuration file"
      }
    }

    Context 'Policy Exemption property validation' -Tag 'PropertyValidation' {
      It "Exemption approved date should be a validate date in the past" -testCases $testParameters -tag "ApprovedDate" {
        param (
          [object]$approvedDate,
          [object]$configurationFileContentJson
        )

        $approvedDate | Should -BeOfType [datetime] -Because "Approved date '$($configurationFileContentJson.policyExemption.metadata.approvedOn)' should be a valid date"
        $approvedDate | Should -BeLessThan $($(Get-Date).ToUniversalTime()) -Because "Approved date '$($approvedDate)' should be in the past"
      }

      It "Exemption Requester and Approver should be different people" -testCases $testParameters -tag "DifferentRequesterApprover" {
        param (
          [object]$configurationFileContentJson
        )
        $requester = $configurationFileContentJson.policyExemption.metadata.requestedBy.trim()
        $approver = $configurationFileContentJson.policyExemption.metadata.approvedBy.trim()
        $requester -ieq $approver | Should -Be $false -Because "Exemption requester '$($requester)' and approver '$($approver)' should not be the same person"
      }
    }
  }
}
