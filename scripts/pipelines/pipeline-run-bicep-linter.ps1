<#
.SYNOPSIS
  Runs the Bicep linter and builds the template and parameter files.

.DESCRIPTION
  Builds the Bicep template to JSON for PSRule validation. Optionally sets the Azure context
  to a specified subscription for Bicep module resolution. Also builds any .bicepparam files
  found in the PSRule test directory.

.PARAMETER TemplateFileDirectory
  The directory containing the Bicep template file.

.PARAMETER TemplateFileName
  The name of the Bicep template file (default: main.bicep).
#>
[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [string]$TemplateFileDirectory,

  [Parameter(Mandatory = $false)]
  [string]$TemplateFileName = 'main.bicep'
)

bicep --version

if ($env:bicepModuleSubscriptionId -ne '') {
  Write-Output "Set Az Context to the bicep module subscription '$env:bicepModuleSubscriptionId'."
  Set-AzContext -SubscriptionId $env:bicepModuleSubscriptionId
}

$psruleTestDir = "$TemplateFileDirectory/psrule-test"
if (!(Test-Path $psruleTestDir)) {
  New-Item -Path $psruleTestDir -ItemType 'Directory' -Force
}

bicep build "$TemplateFileDirectory/$TemplateFileName" --outfile "$psruleTestDir/main.json"

# Update 'using' path and build bicepparam files if they exist
$bicepParamFiles = Get-ChildItem -Path $psruleTestDir -Filter *.bicepparam -ErrorAction SilentlyContinue
foreach ($paramFile in $bicepParamFiles) {
  # Replace the first line 'using' path to point to the template in the parent directory
  $content = Get-Content -Path $paramFile.FullName
  if ($content[0] -match "^using\s+'.*'") {
    $content[0] = "using '../$TemplateFileName'"
    Set-Content -Path $paramFile.FullName -Value $content
    Write-Output "Updated 'using' path in $($paramFile.Name) to '../$TemplateFileName'"
  }
  Write-Output "Building bicepparam file $($paramFile.FullName)"
  bicep build-params $paramFile.FullName --outfile "$psruleTestDir/$($paramFile.BaseName).json"
}

Write-Output "Files in ${psruleTestDir}:"
Get-ChildItem -Path $psruleTestDir


