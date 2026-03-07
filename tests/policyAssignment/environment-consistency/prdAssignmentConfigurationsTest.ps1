#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.3.1"}
#Requires -Version 7.0

<#
===============================================================================================================================
AUTHOR: Tao Yang
DATE: 08/08/2025
NAME: prdAssignmentConfigurationsTest.ps1
VERSION: 1.0.0
COMMENT: Initiates the Pester tests for environment consistency between environments for Policy Assignment configuration files
===============================================================================================================================
#>
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true, HelpMessage = 'Specify the Production Assignment Configurations file folder path.')]
  [validateScript({ Test-Path $_ -PathType Container })]
  [string]$prodConfigurationFilesPath,

  [Parameter(Mandatory = $true, HelpMessage = 'Specify the Development Assignment Configurations file folder path.')]
  [validateScript({ Test-Path $_ -PathType Container })]
  [string]$devConfigurationFilesPath,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$OutputFileDir,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$OutputFilePrefix = "TEST-ProdAssignmentConfigurations",

  [Parameter(Mandatory = $false)]
  [ValidateSet('NUnitXml', 'LegacyNUnitXML')]
  [string]$OutputFormat = 'NUnitXml'
)

$testFilePath = join-path $PSScriptRoot "prd.assignment.configurations.tests.ps1"
Write-Verbose "Production Assignment Configuration Files Path: '$prodConfigurationFilesPath'"
Write-Verbose "Development Assignment Configuration Files Path: '$devConfigurationFilesPath'"
Write-Verbose "Testing '$testFilePath'..."
$testData = @{
  prodConfigurationFilesPath = $prodConfigurationFilesPath
  devConfigurationFilesPath  = $devConfigurationFilesPath
}
$testContainer = New-PesterContainer -Path $testFilePath -Data $testData
$testConfig = New-PesterConfiguration
$testConfig.Run.Container = $testContainer
$testConfig.Run.PassThru = $true
$testConfig.Output.verbosity = 'Detailed'

$testResultFile = join-path $OutputFileDir "$OutputFilePrefix`.XML"
Write-Output "Result file for Production Assignment Configurations test: $testResultFile"
$testConfig.TestResult.Enabled = $true
$testConfig.TestResult.TestSuiteName = 'ProductionAssignmentConfigurationsTests'
$testConfig.TestResult.OutputFormat = $OutputFormat
$testConfig.TestResult.OutputPath = $testResultFile
$testResult = Invoke-Pester -Configuration $testConfig
if ($testResult.TestResult.Result -ieq 'failed') {
  Write-Error "Production Assignment Configurations tests failed."
}

Write-Output "Current files in OutputFileDir '$OutputFileDir':"
Get-ChildItem -Path $OutputFileDir
Write-Output "Done"
