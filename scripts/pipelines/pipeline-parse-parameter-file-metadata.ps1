<#
====================================================
AUTHOR: Tao Yang
DATE: 04/08/2022
NAME: pipeline-parse-parameter-file-metadata.ps1
VERSION: 1.0.0
COMMENT: Parsing metadata in a Bicep parameter file
====================================================
#>

[CmdletBinding()]
param (
  [parameter(Mandatory = $true, ParameterSetName = 'AbsolutePath', HelpMessage = "The parameter file path")]
  [string]$ParameterFilePath,

  [parameter(Mandatory = $true, ParameterSetName = 'CalculatedPath', HelpMessage = "The value of Azure Devops predefined variable 'System.DefaultWorkingDirectory'")]
  [string]$SystemDefaultWorkingDirectory,

  [parameter(Mandatory = $true, ParameterSetName = 'CalculatedPath', HelpMessage = "The Template file directory")]
  [string]$templateFileDirectory,

  [parameter(Mandatory = $false, ParameterSetName = 'CalculatedPath', HelpMessage = "Optional. The build artifact name for the parameter file")]
  [string]$parameterFileArtifactName,

  [parameter(Mandatory = $true, ParameterSetName = 'CalculatedPath', HelpMessage = "The parameter file name")]
  [string]$parameterFileName
)

#parse Json file
if ($PSCmdlet.ParameterSetName -eq 'CalculatedPath') {
  # Identify the Parameter File Path
  if ($parameterFileArtifactName.length -gt 0) {
    #parameter file is from a downloaded build artifact
    $parameterFileDir = join-path $SystemDefaultWorkingDirectory $parameterFileArtifactName
  } else {
    #parameter file is from the git repo, same folder as the template file.
    $parameterFileDir = Join-Path $SystemDefaultWorkingDirectory $templateFileDirectory
  }
  $ParameterFilePath = Join-Path $parameterFileDir $parameterFileName
}
Write-Output "Parameter File Path: '$ParameterFilePath'"
$content = Get-Content -Path $ParameterFilePath -Raw
$json = ConvertFrom-Json -InputObject $content -ErrorVariable parseError
if ($parseError) {
  Throw $parseError
  exit -1
}

if ($json.psobject.properties.name -contains 'metadata') {
  $metadata = $json.metadata
  foreach ($item in $metadata.psobject.properties.name) {
    $variableName = "metadata_$item"
    $variableValue = $metadata.$item
    if ($variableValue -is [system.array]) {
      #join array to string using 2 pipe characters '||'
      $variableValue = $variableValue -join '||'
    }
    Write-Output "Setting Azure Pipeline variable: $variableName = $variableValue"
    Write-Output "##vso[task.setvariable variable=$variableName]$variableValue"
    Write-Output "##vso[task.setvariable variable=$variableName;isOutput=true]$variableValue"
  }

}
