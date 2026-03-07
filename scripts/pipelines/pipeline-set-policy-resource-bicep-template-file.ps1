<#
=====================================================================================
AUTHOR: Tao Yang
DATE: 19/04/2024
NAME: pipeline-set-policy-resource-bicep-template-file.ps1
VERSION: 1.0.0
COMMENT: Update the Policy Definition, Initiative and Assignment Bicep Template file
=====================================================================================
#>

[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$bicepFilePath,

  [parameter(Mandatory = $true)]
  [string]$bicepVariableName,

  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$resourceFileFolder,

  [Parameter(Mandatory = $false)]
  [String[]]$excludePath,

  [Parameter(Mandatory = $false)]
  [ValidateSet('true', 'false')]
  [string]$isPolicyExemption = 'false',

  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$outputDir,

  [parameter(Mandatory = $true)]
  [string]$artifactName,

  [parameter(Mandatory = $false)]
  [string]$updateBicepFileName = 'updated-policy-resources.bicep'
)

#region functions

function isExemptionExpired {
  [OutputType([Boolean])]
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$filePath
  )
  Write-Verbose "Checking exemption configuration file: '$filePath'..." -verbose
  $isExpired += $false
  $json = Get-Content -Path $filePath -Raw | ConvertFrom-Json -depth 99
  if ($json.policyExemption.psobject.properties.name -contains 'expiresOn') {
    $expiryDate = $json.policyExemption.expiresOn
    if ($expiryDate) {
      Write-Verbose "  - Expiry date: $expiryDate" -verbose
      if ($expiryDate -lt $script:utcNow) {
        Write-Verbose "  - Expiry date has already passed. It will be excluded from the deployment." -verbose
        $isExpired += $true
      } else {
        Write-Verbose "  - Expiry date is in the future. It will be included in the deployment." -verbose
      }
    } else {
      Write-Verbose "  - No expiry date found. It will be included in the deployment." -verbose
    }
  }
  $isExpired
}

function BuildResourceVariable {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$bicepFileParentDir,

    [parameter(Mandatory = $true)]
    [string]$resourceFileFolder,

    [Parameter(Mandatory = $true)]
    [bool]$isPolicyExemption,

    [Parameter(Mandatory = $false)]
    [String[]]$excludePath
  )
  $bicepFilesToLoad = @()
  $policyFiles = Get-ChildItem -Path $resourceFileFolder -Filter '*.json' -File -Recurse
  # -Exclude parameter in Get-ChildItem only works on file name, not parent folder name hence it's not used in get-childitem
  if ($excludePath -ne '') {
    $excludePath = $excludePath -join "|"
    $policyFiles = $policyFiles | where-object { $_.FullName -notmatch $excludePath }
  }

  if ($isPolicyExemption) {
    $policyFiles = $policyFiles | where-object {
      !$(isExemptionExpired -filePath $_.FullName)
    }
  }
  foreach ($file in $policyFiles) {
    $relativePath = Resolve-Path -Path $file.FullName -RelativeBasePath $bicepFileParentDir -Relative
    Write-Verbose "Adding Policy Definition file: $relativePath" -verbose
    $bicepFilesToLoad += "loadJsonContent('$relativePath')"
  }

  $bicepFilesToLoad | out-string
}
#endregion
#region main
#Convert $isPolicyExemption to boolean
Write-Verbose "Processing Policy Exemption Bicep template: '$isPolicyExemption'." -verbose
$bIsPolicyExemption = [System.Convert]::ToBoolean($isPolicyExemption)
$script:utcNow = (get-date).ToUniversalTime()
#read the content of the Bicep file
$bicepFile = Get-Item -Path $bicepFilePath
$bicepFileContent = Get-Content -Path $bicepFilePath -Raw

#Build the loadJsonContent variable
$loadJsonContent = BuildResourceVariable -bicepFileParentDir $bicepFile.Directory -resourceFileFolder $resourceFileFolder -isPolicyExemption $bIsPolicyExemption -excludePath $excludePath

#replace the variable value in the Bicep file
$updatedBicepFileContent = $bicepFileContent -replace "var $bicepVariableName = \[\]", "var $bicepVariableName = [`r`n$loadJsonContent]"

#Save the updated Bicep file
#create the output directory if it does not exist
$outputArtifactsDir = Join-path $outputDir -ChildPath $artifactName
if (-not (Test-Path -Path $outputArtifactsDir)) {
  New-Item -Path $outputArtifactsDir -ItemType Directory
}
$updatedBicepFilePath = Join-Path -Path $outputArtifactsDir $updateBicepFileName
Write-Verbose "Saving updated Bicep file to $updatedBicepFilePath" -verbose
$updatedBicepFileContent | out-file $updatedBicepFilePath
#Set-Content -Path $updatedBicepFilePath -Value $updatedBicepFileContent
Write-Output "Done."
#endregion
