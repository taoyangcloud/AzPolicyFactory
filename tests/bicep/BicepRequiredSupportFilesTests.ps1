#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.3.1"}
#Requires -Version 6.0

<#
===================================================================================
AUTHOR: Tao Yang
DATE: 08/03/2022
NAME: BicepRequiredSupportFilesTests.ps1
VERSION: 1.0.0
COMMENT: Pester tests for required supporting files for bicep templates and modules
===================================================================================
#>

[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true, HelpMessage = 'Specify the Bicep file folder path.')][validateScript({ Test-Path $_ -PathType Container })][string]$BicepDir,
  [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$OutputFileDir,
  [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()][string]$OutputFilePrefix = "TEST-Bicep",
  [Parameter(Mandatory = $false)][ValidateSet('NUnitXml', 'LegacyNUnitXML')][string]$OutputFormat = 'NUnitXml'
)

$ReadmeTestFilePath = join-path $PSScriptRoot 'bicep.readme.tests.ps1'
$bicepconfigTestFilePath = join-path $PSScriptRoot "bicep.bicepconfig.tests.ps1"

#region readme file tests
Write-Output "Testing '$ReadmeTestFilePath'..."
$readmeContainer = New-PesterContainer -Path $ReadmeTestFilePath -Data @{BicepDir = $BicepDir }
$readmeConfig = New-PesterConfiguration
$readmeConfig.Run.Container = $readmeContainer
$readmeConfig.Run.PassThru = $true
$readmeConfig.Output.verbosity = 'Detailed'

$ReadmeTestResultFile = join-path $OutputFileDir "$OutputFilePrefix`.Readme.XML"
Write-Output "Result file for readme test: $ReadmeTestResultFile"
$readmeConfig.TestResult.Enabled = $true
$readmeConfig.TestResult.TestSuiteName = 'BicepReadmeFileTests'
$readmeConfig.TestResult.OutputFormat = $OutputFormat
$readmeConfig.TestResult.OutputPath = $ReadmeTestResultFile
$ReadmeTestResult = Invoke-Pester -Configuration $readmeConfig
if ($ReadmeTestResult.TestResult.Result -ieq 'failed') {
  Write-Error "Readme test failed."
}
#endregion

#region bicepconfig file tests
Write-Verbose "Testing '$bicepconfigTestFilePath'..."
$bicepconfigContainer = New-PesterContainer -Path $bicepconfigTestFilePath -Data @{BicepDir = $BicepDir }
$bicepconfigConfig = New-PesterConfiguration
$bicepconfigConfig.Run.Container = $bicepconfigContainer
$bicepconfigConfig.Run.PassThru = $true
$bicepconfigConfig.Output.verbosity = 'Detailed'

$bicepconfigTestResultFile = join-path $OutputFileDir "$OutputFilePrefix`.Bicepconfig.XML"
Write-Output "Result file for bicepconfig test: $bicepconfigTestResultFile"
$bicepconfigConfig.TestResult.Enabled = $true
$bicepconfigConfig.TestResult.TestSuiteName = 'BicepConfigFileTests'
$bicepconfigConfig.TestResult.OutputFormat = $OutputFormat
$bicepconfigConfig.TestResult.OutputPath = $bicepconfigTestResultFile
$BicepconfigTestResult = Invoke-Pester -Configuration $bicepconfigConfig
if ($BicepconfigTestResult.TestResult.Result -ieq 'failed') {
  Write-Error "Bicepconfig test failed."
}
#endregion

Write-Output "Current files in OutputFileDir '$OutputFileDir':"
Get-ChildItem -Path $OutputFileDir
Write-Output "Done"
