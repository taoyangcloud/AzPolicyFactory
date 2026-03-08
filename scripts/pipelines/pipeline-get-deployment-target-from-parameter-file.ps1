<#
==================================================================================
AUTHOR: Tao Yang
DATE: 05/06/2024
NAME: pipeline-get-deployment-target-from-parameter-file.ps1
VERSION: 1.0.0
COMMENT: determine deployment target by parsing metadata in a Bicep parameter file
==================================================================================
#>

[CmdletBinding()]
param (
  [parameter(Mandatory = $false, HelpMessage = "The parameter file path")]
  [string]$parameterFileDirectory,

  [parameter(Mandatory = $false, HelpMessage = "Optional. The build artifact name for the parameter file")]
  [string]$parameterFileArtifactName,

  [parameter(Mandatory = $false, HelpMessage = "The parameter file name")]
  [string]$parameterFileName,

  [parameter(Mandatory = $false, HelpMessage = "The target Name passed in from the pipeline template.")]
  [string]$targetName = '',

  [parameter(Mandatory = $false, HelpMessage = "The subscription Name passed in from the pipeline template.")]
  [string]$subscriptionName = ''
)

if ($targetName -eq '' -and $subscriptionName -eq '') {
  Write-Output "Target Name and Subscription Name are not passed in from the pipeline template. Trying to determine the target from the parameter file metadata."
  if ($parameterFileName -ne '') {
    #parameter file specified, figure out the location of the parameter file
    If ( $parameterFileArtifactName -ne "") {
      $parameterFile = join-path -path $parameterFileDirectory -Childpath $parameterFileArtifactName -AdditionalChildPath $parameterFileName
      Write-Output "Use Parameter File '$parameterFile' from Build Artifact..."
    } else {
      $parameterFile = join-path -path $parameterFileDirectory -Childpath $parameterFileName
      Write-Output "Use Parameter File '$parameterFile' from Git repository..."
    }

    Write-Output "Checking if the Parameter file '$parameterFile' exists"
    if (Test-Path $parameterFile) {
      $content = Get-Content -Path $parameterFile -Raw
      $json = ConvertFrom-Json -InputObject $content -ErrorVariable parseError
      if ($json.psobject.properties.name -contains 'metadata') {
        $metadata = $json.metadata
        if ($metadata.psobject.properties.name -contains 'targetSubscriptionName') {
          $subscriptionName = $metadata.subscriptionName
          #If subscription name is specified, check for resource group name
          if ($metadata.psobject.properties.name -contains 'targetResourceGroupName') {
            $targetName = $metadata.targetResourceGroupName
          }
        } elseif ($metadata.psobject.properties.name -contains 'targetManagementGroupName') {
          $targetName = $metadata.targetManagementGroupName
        }
      }
    } else {
      Write-Output "Target Name and /or Subscription Name are passed in from the pipeline template. No need to read from the parameter file."
    }
  } else {
    Write-Error "The specified parameter file '$parameterFile' does not exist. Unable to continue."
    Exit 1
  }
} else {
  Write-Output "No Parameter File specified."
}

#Create pipeline variables
Write-Verbose "Target Name: '$targetName'" -Verbose
Write-Verbose "Subscription Name: '$subscriptionName'" -Verbose
Write-Output "##vso[task.setvariable variable=targetName]$targetName"
Write-Output "##vso[task.setvariable variable=targetName;isOutput=true]$targetName"
Write-Output "##vso[task.setvariable variable=subscriptionName]$subscriptionName"
Write-Output "##vso[task.setvariable variable=subscriptionName;isOutput=true]$subscriptionName"
