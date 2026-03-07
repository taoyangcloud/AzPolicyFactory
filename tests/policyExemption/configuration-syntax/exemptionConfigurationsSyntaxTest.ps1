#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.3.1"}
#Requires -Version 7.0

<#
=======================================================================================================
AUTHOR: Tao Yang
DATE: 12/08/2025
NAME: exemptionConfigurationsSyntaxTest.ps1
VERSION: 1.0.0
COMMENT: Initiates the Pester tests for syntax validation of the Policy Exemption configuration files
=======================================================================================================
#>
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true, HelpMessage = 'Specify the Exemption Configurations file folder path.')]
  [validateScript({ Test-Path $_ -PathType Container })]
  [string]$configurationFilesPath,

  [Parameter(Mandatory = $true)]
  [validateScript({ Test-Path $_ -PathType leaf })]
  [string]$configurationSchemaFilePath,

  [Parameter(Mandatory = $false, HelpMessage = 'Specify the Pester test tags to exclude  (comma separated).')]
  [string]$ExcludeTags,

  [Parameter(Mandatory = $true, HelpMessage = 'Specify the Pester test output folder path.')]
  [ValidateNotNullOrEmpty()]
  [string]$OutputFileDir,

  [Parameter(Mandatory = $false, HelpMessage = 'Specify the Pester test output file prefix.')]
  [ValidateNotNullOrEmpty()]
  [string]$OutputFilePrefix = "TEST-ExemptionConfigurationSyntax",

  [Parameter(Mandatory = $false, HelpMessage = 'Specify the Pester test output format.')]
  [ValidateSet('NUnitXml', 'LegacyNUnitXML')]
  [string]$OutputFormat = 'NUnitXml'
)

$testFilePath = join-path $PSScriptRoot "exemption.configurations.syntax.tests.ps1"
Write-Verbose "Exemption Configuration Files Path: '$configurationFilesPath'"

Write-Verbose "Testing '$testFilePath'..."
$testData = @{
  configurationFilesPath      = $configurationFilesPath
  configurationSchemaFilePath = $configurationSchemaFilePath
}
$testContainer = New-PesterContainer -Path $testFilePath -Data $testData
$testConfig = New-PesterConfiguration
$testConfig.Run.Container = $testContainer
$testConfig.Run.PassThru = $true
$testConfig.Output.verbosity = 'Detailed'
if ($ExcludeTags.length -gt 0) {
  $arrExcludedTags = @()
  foreach ($item in $($ExcludeTags -split ',')) {
    $arrExcludedTags += $($item.trim())
  }
  $testConfig.filter.ExcludeTag = $arrExcludedTags
}

$testResultFile = join-path $OutputFileDir "$OutputFilePrefix`.XML"
Write-Output "Result file for Exemption Configuration File Syntax test: $testResultFile"
$testConfig.TestResult.Enabled = $true
$testConfig.TestResult.TestSuiteName = 'ExemptionConfigurationSyntaxTests'
$testConfig.TestResult.OutputFormat = $OutputFormat
$testConfig.TestResult.OutputPath = $testResultFile
$testResult = Invoke-Pester -Configuration $testConfig
if ($testResult.TestResult.Result -ieq 'failed') {
  Write-Error "Exemption Configuration File Syntax tests failed."
}

Write-Output "Current files in OutputFileDir '$OutputFileDir':"
Get-ChildItem -Path $OutputFileDir
Write-Output "Done"
