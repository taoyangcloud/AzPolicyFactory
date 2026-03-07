<#
=================================================================
AUTHOR: Tao Yang
DATE: 10/02/2026
NAME: Invoke-AllTemplateValidations.ps1
VERSION: 1.0.0
COMMENT: Wrapper script to run template validation for all parameter files (GitHub Actions version)
=================================================================
#>

[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [string]$templateFileDirectory,

  [parameter(Mandatory = $true)]
  [string]$templateFileName,

  [parameter(Mandatory = $false)]
  [string]$parameterFileDirectory = '',

  [parameter(Mandatory = $false)]
  [string]$parameterFileNamePattern = '',

  [parameter(Mandatory = $true)]
  [ValidateSet('resourceGroup', 'subscription', 'managementGroup', 'tenant')]
  [string]$templateScope,

  [parameter(Mandatory = $false)]
  [string]$azureLocation = '',

  [parameter(Mandatory = $false)]
  [string]$targetName = '',

  [parameter(Mandatory = $false)]
  [string]$subscriptionName = '',

  [parameter(Mandatory = $false)]
  [ValidateSet('true', 'false')]
  [string]$runWhatIfValidation = 'true',

  [parameter(Mandatory = $false)]
  [ValidateRange(3, 10)]
  [int]$whatIfMaxRetry = 3,

  [parameter(Mandatory = $false)]
  [string]$whatIfResultArtifactName = '',

  [parameter(Mandatory = $false)]
  [string]$bicepModuleSubscriptionId = '',

  [parameter(Mandatory = $true)]
  [string]$scriptsDirectory
)

# Determine parameter file directory
if ($parameterFileDirectory -eq '') {
  $parameterFileDirectory = $templateFileDirectory
}

Write-Output "Template File Directory: $templateFileDirectory"
Write-Output "Template File Name: $templateFileName"
Write-Output "Parameter File Directory: $parameterFileDirectory"
Write-Output "Parameter File Pattern: $parameterFileNamePattern"
Write-Output "Template Scope: $templateScope"

# Get parameter files
$parameterFiles = @()
if ($parameterFileNamePattern -ne '' -and $parameterFileDirectory -ne '') {
  if (Test-Path $parameterFileDirectory) {
    $parameterFiles = Get-ChildItem -Path $parameterFileDirectory -Filter $parameterFileNamePattern -File -ErrorAction SilentlyContinue
  }
}

if ($parameterFiles.Count -eq 0) {
  Write-Output "No parameter files found matching pattern '$parameterFileNamePattern'. Running validation without parameter file."
  $parameterFiles = @($null)
} else {
  Write-Output "Found $($parameterFiles.Count) parameter file(s) matching pattern '$parameterFileNamePattern'"
}

$validationResults = @()
$validationScript = Join-Path $scriptsDirectory 'Invoke-TemplateValidation.ps1'

foreach ($paramFile in $parameterFiles) {
  $paramFileName = if ($paramFile) { $paramFile.Name } else { '' }
  Write-Output "=========================================="
  Write-Output "Validating with parameter file: $paramFileName"
  Write-Output "=========================================="

  # Get deployment target
  $currentTargetName = $targetName
  $currentSubscriptionName = $subscriptionName

  Write-Output "Target Name: $currentTargetName"
  Write-Output "Subscription Name: $currentSubscriptionName"

  # Run validation
  try {
    & $validationScript `
      -templateFileDirectory $templateFileDirectory `
      -templateFileName $templateFileName `
      -parameterFileName $paramFileName `
      -parameterFileDirectory $parameterFileDirectory `
      -templateScope $templateScope `
      -azureLocation $azureLocation `
      -targetName $currentTargetName `
      -subscriptionName $currentSubscriptionName `
      -runWhatIfValidation $runWhatIfValidation `
      -whatIfMaxRetry $whatIfMaxRetry `
      -whatIfResultArtifactName $whatIfResultArtifactName `
      -bicepModuleSubscriptionId $bicepModuleSubscriptionId

    $validationResults += @{
      ParameterFile = $paramFileName
      Result        = 0
    }
  } catch {
    Write-Error "Validation failed for parameter file '$paramFileName': $_"
    $validationResults += @{
      ParameterFile = $paramFileName
      Result        = 1
    }
  }
}

# Output results summary
Write-Output "=========================================="
Write-Output "Validation Results Summary"
Write-Output "=========================================="

$passedCount = ($validationResults | Where-Object { $_.Result -eq 0 }).Count
$failedCount = ($validationResults | Where-Object { $_.Result -ne 0 }).Count

Write-Output "Total: $($validationResults.Count), Passed: $passedCount, Failed: $failedCount"

# Set GitHub output
$outputFile = $env:GITHUB_OUTPUT
if ($outputFile) {
  if ($failedCount -gt 0) {
    Write-Output "validation-failed=true" >> $outputFile
  } else {
    Write-Output "validation-failed=false" >> $outputFile
  }
  Write-Output "passed-count=$passedCount" >> $outputFile
  Write-Output "failed-count=$failedCount" >> $outputFile
}

if ($failedCount -gt 0) {
  Write-Error "Template validation failed for $failedCount parameter file(s)."
  exit 1
} else {
  Write-Output "All template validations passed."
  exit 0
}
