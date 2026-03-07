#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.3.1"}
#Requires -Version 7.0

<#
=======================================================================================================
AUTHOR: Tao Yang
DATE: 08/08/2025
NAME: assignmentConfigurationsSyntaxTest.ps1
VERSION: 1.0.0
COMMENT: Initiates the Pester tests for syntax validation of the Policy Assignment configuration files
=======================================================================================================
#>
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true, HelpMessage = 'Specify the Assignment Configurations file folder path.')]
  [validateScript({ Test-Path $_ -PathType Container })]
  [string]$configurationFilesPath,

  [Parameter(Mandatory = $true)]
  [validateScript({ Test-Path $_ -PathType leaf })]
  [string]$configurationSchemaFilePath,

  [Parameter(Mandatory = $false, HelpMessage = 'Specify the Pester test tags to exclude (comma separated).')]
  [string]$ExcludeTags,

  [Parameter(Mandatory = $true, HelpMessage = 'Specify the Pester test output folder path.')]
  [ValidateNotNullOrEmpty()]
  [string]$OutputFileDir,

  [Parameter(Mandatory = $false, HelpMessage = 'Specify the Pester test output file prefix.')]
  [ValidateNotNullOrEmpty()]
  [string]$OutputFilePrefix = "TEST-AssignmentConfigurationSyntax",

  [Parameter(Mandatory = $false, HelpMessage = 'Specify the Pester test output format.')]
  [ValidateSet('NUnitXml', 'LegacyNUnitXML')]
  [string]$OutputFormat = 'NUnitXml'
)

$testFilePath = join-path $PSScriptRoot "assignment.configurations.syntax.tests.ps1"
Write-Verbose "Assignment Configuration Files Path: '$configurationFilesPath'"

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
Write-Output $testConfig.filter.ExcludeTag
$testResultFile = join-path $OutputFileDir "$OutputFilePrefix`.XML"
Write-Output "Result file for Assignment Configuration File Syntax test: $testResultFile"
$testConfig.TestResult.Enabled = $true
$testConfig.TestResult.TestSuiteName = 'AssignmentConfigurationSyntaxTests'
$testConfig.TestResult.OutputFormat = $OutputFormat
$testConfig.TestResult.OutputPath = $testResultFile
$testResult = Invoke-Pester -Configuration $testConfig
if ($testResult.TestResult.Result -ieq 'failed') {
  Write-Error "Assignment Configuration File Syntax tests failed."
}

Write-Output "Current files in OutputFileDir '$OutputFileDir':"
Get-ChildItem -Path $OutputFileDir
Write-Output "Done"
