<#
=================================================================
AUTHOR: Tao Yang
DATE: 27/02/2025
NAME: pipeline-template-validation.ps1
VERSION: 1.1.0
COMMENT: Bicep template validation script used in Azure Pipeline
=================================================================
#>

[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [string]$templateFileDirectory,

  [parameter(Mandatory = $true)]
  [string]$templateFileName,

  [parameter(Mandatory = $false)]
  [string]$parameterFileArtifactName,

  [parameter(Mandatory = $false)]
  [string]$parameterFileDirectory = $templateFileDirectory,

  [parameter(Mandatory = $false)]
  [string]$parameterFileName,

  [parameter(Mandatory = $true)]
  [validateSet('resourceGroup', 'subscription', 'managementGroup', 'tenant')]
  [string]$templateScope,

  [parameter(Mandatory = $false)]
  [string]$azureLocation,

  [parameter(Mandatory = $false)]
  [string]$targetName,

  [parameter(Mandatory = $false)]
  [string]$subscriptionName,

  [parameter(Mandatory = $false)]
  [validateset('true', 'false')]
  [string]$runWhatIfValidation = 'true', #can't be boolean because pipeline can only pass string

  [parameter(Mandatory = $false)]
  [ValidateRange(3, 10)]
  [int]$whatIfMaxRetry = 3,

  [parameter(Mandatory = $false)]
  [string]$whatIfResultArtifactName = '',

  [parameter(Mandatory = $false)]
  [string]$bicepModuleSubscriptionId = ''
)

#Display bicep version
Write-Output "$(bicep --version)"

#load external helper functions
$WhatIfvalidationHelperScriptPath = join-path $PSScriptRoot 'helper' 'invoke-arm-whatif-validation.ps1'
. $WhatIfvalidationHelperScriptPath

$WarningPreference = 'SilentlyContinue'
$templateFile = Join-Path $templateFileDirectory $templateFileName

If (!(Test-Path $templateFile)) {
  Write-Output "Template File '$templateFile' not found"
  Exit 1
} else {
  Write-Output "Template File: $templateFile"
}

if ($bicepModuleSubscriptionId -ne '') {
  Write-Output "Set Az Context to the bicep module subscription '$bicepModuleSubscriptionId'."
  set-AzContext -subscriptionId $bicepModuleSubscriptionId
}

#construct PS command parameters
$testDeploymentParams = @{
  TemplateFile = $templateFile
}
if ($runWhatIfValidation -ieq 'true') {
  $whatIfParams = @{
    templateFilePath          = $templateFile
    azureLocation             = $azureLocation
    resultFormat              = $whatIfResultArtifactName -eq '' ? 'ResourceIdOnly': 'FullResourcePayloads'
    bicepModuleSubscriptionId = $bicepModuleSubscriptionId
    maxRetry                  = $whatIfMaxRetry
  }
}
#Check if parameter file exists
if ($parameterFileName -ne '') {
  #parameter file specified, figure out the location of the parameter file
  If ( $parameterFileArtifactName -ne "") {
    $parameterFile = join-path -path $parameterFileDirectory -Childpath $parameterFileArtifactName -AdditionalChildPath $parameterFileName
    Write-Output "Deploying with Parameter File '$parameterFile' from Build Artifact..."
  } else {
    $parameterFile = join-path -path $parameterFileDirectory -Childpath $parameterFileName
    Write-Output "Deploying with Parameter File '$parameterFile' from Git repository..."
  }

  Write-Output "Checking if the Parameter file '$parameterFile' exists"
  if (Test-Path $parameterFile) {
    Write-Output "Validating with Parameter File '$parameterFile'..."
    $testDeploymentParams.Add('TemplateParameterFile', $parameterFile)
    if ($runWhatIfValidation -ieq 'true') {
      $whatIfParams.Add('parameterFilePath', $parameterFile)
    }
  } else {
    Write-Error "The specified parameter file '$parameterFile' does not exist. Unable to continue."
    Exit 1
  }
} else {
  Write-Output "No Parameter File specified. Template will be validated without a parameter file"
}

Switch ($templateScope) {
  'tenant' {
    $testDeploymentParams.add('Location', $azureLocation)
    Write-Output "Tenant Level Validation. Template file: '$templateFile'"
    Write-Output "Test Tenant Level Deployment..."
    Test-AzTenantDeployment @testDeploymentParams -ErrorVariable validationError
  }
  'managementGroup' {
    $testDeploymentParams.add('Location', $azureLocation)
    $testDeploymentParams.add('ManagementGroupId', $targetName)
    if ($runWhatIfValidation -ieq 'true') {
      $whatIfParams.Add('deploymentTargetResourceId', "/providers/Microsoft.Management/managementGroups/$targetName")
    }
    Write-Output "Management Group Level Validation. Template file: '$templateFile'"
    Write-Output "Management Group: $targetName"
    Write-Output "Test Management Group Level Deployment..."
    Test-AzManagementGroupDeployment @testDeploymentParams -ErrorVariable validationError
  }
  'subscription' {
    $testDeploymentParams.add('Location', $azureLocation)

    Write-Output "Subscription Level Validation. Template file: '$templateFile'"
    Write-Output "Subscription: $subscriptionName"
    Write-Output "Set the Az Context to subscription '$subscriptionName'"
    Set-AzContext -Subscription $subscriptionName
    if ($runWhatIfValidation -ieq 'true') {
      $subscriptionId = (Get-AzContext).Subscription.Id
      $whatIfParams.Add('deploymentTargetResourceId', "/subscriptions/$subscriptionId")
    }
    Write-Output "Test Subscription Level Deployment..."
    Test-AzDeployment @testDeploymentParams -ErrorVariable validationError
  }
  'resourceGroup' {
    $testDeploymentParams.add('ResourceGroupName', $targetName)
    # enforce incremental deployment, never use 'Complete' (in case default value changes in the future)
    $testDeploymentParams.add('Mode', "Incremental")
    Write-Output "Resource Group Level Validation. Template file: '$templateFile'"
    Write-Output "Subscription: $subscriptionName, Resource Group: $targetName"
    Write-Output "Set the Az Context to subscription '$subscriptionName'"
    Set-AzContext -Subscription $subscriptionName
    if ($runWhatIfValidation -ieq 'true') {
      $subscriptionId = (Get-AzContext).Subscription.Id
      $whatIfParams.Add('deploymentTargetResourceId', "/subscriptions/$subscriptionId/resourceGroups/$targetName")
    }
    Write-Output "Test Resource Group Level Deployment..."
    Test-AzResourceGroupDeployment @testDeploymentParams -ErrorVariable validationError
  }
}
If ($runWhatIfValidation -eq 'true') {
  Write-Output "Get $templateScope Level Deployment What-If Results..."
  $whatIfResult = getArmDeploymentWhatIfResult @whatIfParams
  if (!$whatIfResult) {
    Write-Error "Failed to perform What-If validation."
    Exit 1
  }
  $whatIfResultJson = $whatIfResult | convertto-json
} else {
  Write-Output "What-If validation is skipped."
}
If ($runWhatIfValidation -eq 'true') {
  if ($whatIfResultArtifactName.length -ge 1) {
    #display what if results
    Write-Output "What-if results: "
    $whatIfResultJson

    #store what-if results in artifact
    $whatIfResultDir = Join-Path -path $templateFileDirectory -childPath $whatIfResultArtifactName
    $whatIfResultFilePath = join-path $whatIfResultDir "$whatIfResultArtifactName.json"
    Write-Output "Save What-If result to '$whatIfResultFilePath'"

    New-Item -Path $whatIfResultDir -ItemType Directory | Out-Null
    $whatIfResultJson | Out-File -FilePath $whatIfResultFilePath -Force | Out-Null
    Write-Output "What-If validation completed. Status: $($whatIfResult.Status)"
    if ($whatIfResult.Status -ine 'succeeded') {
      Write-Error "What-If validation status: $($whatIfResult.Status)"
      Exit 1
    } else {
      Write-Output "What-If Validation succeeded."
    }
  } else {
    Write-Output "What-If result will not be saved to artifact"
  }
}

if ($validationError) {
  Write-Error "Test Deployment Validation failed. Error: $validationError"
  Exit 1
} else {
  Write-Output "Template Validation succeeded."
}

