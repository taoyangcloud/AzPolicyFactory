<#
=================================================================
AUTHOR: Tao Yang
DATE: 08/05/2024
NAME: Get-ParameterFiles.ps1
VERSION: 1.1.0
COMMENT: Get all parameter files that matches the name pattern (GitHub Actions version)
=================================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [AllowEmptyString()]
  [string]$parameterFileDir,

  [parameter(Mandatory = $false)]
  [AllowEmptyString()]
  [string]$parameterFileArtifactName = '',

  [parameter(Mandatory = $true)]
  [AllowEmptyString()]
  [string]$parameterFileNamePattern
)

Write-Verbose "parameterFileDir: $parameterFileDir" -Verbose
Write-Verbose "parameterFileArtifactName: $parameterFileArtifactName" -Verbose
Write-Verbose "parameterFileNamePattern: $parameterFileNamePattern" -Verbose

$fileTable = [Ordered]@{}
$i = 1

if ($parameterFileArtifactName.length -gt 0 -and $parameterFileDir.Length -gt 0) {
  $parameterFileDir = Join-Path $parameterFileDir $parameterFileArtifactName -Resolve -ErrorAction SilentlyContinue
}

if ($parameterFileNamePattern.length -gt 0 -and $parameterFileDir.Length -gt 0) {
  if (Test-Path $parameterFileDir) {
    Write-Verbose "Files in $parameterFileDir`: $(Get-ChildItem -Path $parameterFileDir -File)" -Verbose
    Write-Verbose "Looking for parameter files that matches the pattern '$parameterFileNamePattern' in the directory '$parameterFileDir'." -Verbose
    $parameterFiles = Get-ChildItem -Path $parameterFileDir -Filter $parameterFileNamePattern -File
    if ($parameterFiles) {
      Foreach ($file in $parameterFiles) {
        $fileTable["ParameterFile$i"] = @{
          ParameterFileName     = $file.Name
          ParameterFileBaseName = $file.BaseName
          ParameterFileFullPath = $file.FullName
        }
        $i++
      }
      Write-Output "Found $($fileTable.Count) parameter files that matches the pattern '$parameterFileNamePattern'"
      $fileTable.GetEnumerator() | ForEach-Object {
        Write-Output "File Name: $($_.Key), Full Path: $($_.Value.ParameterFileFullPath)"
      }
    } else {
      Write-Warning "No parameter files found that matches the pattern '$parameterFileNamePattern'"
    }
  } else {
    Write-Warning "Parameter file directory '$parameterFileDir' does not exist."
  }
} else {
  Write-Verbose "No parameter file name pattern provided." -Verbose
  $fileTable["ParameterFile0"] = @{
    ParameterFileName     = ""
    ParameterFileBaseName = ""
    ParameterFileFullPath = ""
  }
}

# Output to GitHub Actions using GITHUB_OUTPUT
$outputFile = $env:GITHUB_OUTPUT
if ($outputFile) {
  $jsonOutput = $fileTable | ConvertTo-Json -Compress
  Write-Output "parameter-files=$jsonOutput" >> $outputFile
  Write-Output "parameter-file-count=$($fileTable.Count)" >> $outputFile
}

# Return the hashtable for use within the same step
return $fileTable
