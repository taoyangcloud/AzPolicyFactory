<#
=================================================================
AUTHOR: Tao Yang
DATE: 08/05/2024
NAME: pipeline-get-parameter-files.ps1
VERSION: 1.0.0
COMMENT: Get all parameter files that matches the name pattern
=================================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [AllowEmptyString()]
  [string]$parameterFileDir,

  [parameter( Mandatory = $true)]
  [AllowEmptyString()]
  [string]$parameterFileArtifactName,

  [parameter( Mandatory = $true)]
  [AllowEmptyString()]
  [string]$parameterFileNamePattern
)

Write-Verbose "parameterFileDir: $parameterFileDir" -Verbose
Write-Verbose "parameterFileArtifactName: $parameterFileArtifactName" -Verbose
Write-Verbose "parameterFileNamePattern: $parameterFileNamePattern" -Verbose

$fileTable = [Ordered]@{}
$i = 1
if ($parameterFileArtifactName.length -gt 0 -and $parameterFileDir.Length -gt 0) {
  $parameterFileDir = join-path $parameterFileDir $parameterFileArtifactName -Resolve
}
if ($parameterFileNamePattern.length -gt 0 -and $parameterFileDir.Length -gt 0) {
  Write-Verbose "Files in $parameterFileDir`: $(Get-ChildItem -Path $parameterFileDir -File)" -Verbose
  Write-Verbose "Looking for parameter files that matches the pattern '$parameterFileNamePattern' in the directory '$parameterFileDir'." -Verbose
  $parameterFiles = Get-ChildItem -Path $parameterFileDir -Filter $parameterFileNamePattern -File
  if ($parameterFiles) {
    Foreach ($file in $parameterFiles) {
      $fileTable["Parameter File $i - $($file.Name)"] += @{
        matrixParameterFileName     = $file.Name
        matrixParameterFileBaseName = $file.BaseName
        matrixParameterFileFullPath = $file.FullName
      }
      $i++
    }
    Write-Output "Found $($fileTable.Count) parameter files that matches the pattern '$parameterFileNamePattern'"
    $fileTable.GetEnumerator() | ForEach-Object {
      Write-Output "File Name: $($_.Key), Full Path: $($_.Value)"
    }
  } else {
    Write-Error "No parameter files found that matches the pattern '$parameterFileNamePattern'"
    Exit 1
  }
} else {
  Write-Verbose "no parameter file name pattern provided." -Verbose
  $fileTable["Parameter File 0 - null"] += @{
    matrixParameterFileName     = ""
    matrixParameterFileBaseName = ""
    matrixParameterFileFullPath = ""
  }
}

#Output Hashtable to ADO Pipeline as a Variable.
Write-Output ('##vso[task.setVariable variable=ParameterFiles;isOutput=true]{0}' -f ($fileTable | ConvertTo-Json -Compress))
