#requires -Module PSDocs.Azure

[CmdletBinding()]
Param
(
  [Parameter(Mandatory = $true, ParameterSetName = 'FilePath', HelpMessage = "Template Path.")]
  [ValidateScript({ test-path $_ -PathType leaf })][String]$templatePath,

  [Parameter(Mandatory = $true, ParameterSetName = 'DirPath', HelpMessage = "Template Directory.")]
  [ValidateScript({ test-path $_ -PathType Container })][String]$templateDirectory,

  [Parameter(Mandatory = $false, ParameterSetName = 'DirPath', HelpMessage = "Culture.")]
  [Parameter(Mandatory = $false, ParameterSetName = 'FilePath', HelpMessage = "Culture.")]
  [String]$culture = 'en-us'
)

#region functions
Function ValidateMetadata {
  [CmdletBinding()]
  [outputType([boolean])]
  Param
  (
    [Parameter(Mandatory = $true)][String]$metadataPath
  )
  $bValidMetadata = $true
  $requiredAttributes = 'itemDisplayName', 'description', 'summary'
  If (Test-Path $metadataPath) {
    try {
      $metadata = Get-Content $metadataPath -Raw | convertFrom-Json
      Foreach ($attribute in $requiredAttributes) {
        if (!$($metadata.$attribute) -or $($($metadata.$attribute).length) -eq 0) {
          Write-Error "Metadata is missing attribute: $attribute or $attribute is empty"
          $bValidMetadata = $false
          break
        }
      }
    } catch {
      $bValidMetadata = $false
    }
  } else {
    $bValidMetadata = $false
  }
  $bValidMetadata
}

Function BicepBuild {
  [CmdletBinding()]
  Param
  (
    [Parameter(Mandatory = $true)][String]$bicepPath
  )
  $bicepDir = (Get-Item -Path $bicepPath).DirectoryName;
  $bicepFileBaseName = (Get-Item -Path $bicepPath).BaseName
  $outputFile = Join-Path $bicepDir "$bicepFileBaseName`.json"
  Write-Verbose "Building ARM template $outputFile from Bicep file $bicepPath"
  $buildOutput = bicep Build $bicepPath --outfile $outputFile 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep build failed for '$bicepPath': $buildOutput"
    return $null
  }
  if (-not (Test-Path $outputFile)) {
    Write-Error "Bicep build did not produce output file '$outputFile'"
    return $null
  }
  $outputFile
}
#endregion
#region main
$docName = "README"
$currentDir = $PWD
$arrTemplatePaths = @()
Write-Output "Current working directory '$currentDir'"
if ($PSCmdlet.ParameterSetName -eq 'FilePath') {
  $arrTemplatePaths += $templatePath
  Write-Output "Template Path '$templatePath'"
} else {
  Write-Output "Template Directory '$templateDirectory'"
  $arrTemplatePaths += (Get-ChildItem $templateDirectory -filter main.bicep -recurse -force).fullName
  Write-Output "Total Bicep templates found in directory '$templateDirectory': $($arrTemplatePaths.count)"
}

$i = 0
foreach ($item in $arrTemplatePaths) {
  $i++
  Write-Output "($i/$($arrTemplatePaths.count)) Generating document for template '$item'"
  $templateDir = (Get-Item -Path $item).DirectoryName;
  Write-Output "  - Template Directory '$templateDir'"
  set-location $templateDir
  Write-Output "  - Detecting git root directory"
  $gitRootDir = invoke-expression 'git rev-parse --show-toplevel' -ErrorAction SilentlyContinue
  if ($gitRootDir.length -gt 0) {
    #In case the script is running on Windows, convert the path to Windows format
    $gitRootDir = convert-Path -Path $gitRootDir
    Write-Output "  - Git root directory '$gitRootDir'"
  } else {
    Write-Output "  - Not a git repository"
  }
  set-location $currentDir
  Import-Module PSDocs.Azure;

  $metadataPath = Join-Path $templateDir 'metadata.json';
  if (Test-Path $metadataPath) {
    Write-Output "  - metadata.json file path: '$metadataPath'"
    #Validate metadata'
    $ValidMetaData = ValidateMetadata -metadataPath $metadataPath
  } else {
    $ValidMetaData = $true

  }

  #Convert Bicep to ARM template if input file is bicep
  $removeARM = $false
  if ((get-item $item).Extension -ieq '.bicep') {
    Write-Output "    - Compiling bicep file $item to ARM template"
    $tempPath = BicepBuild -bicepPath $item
    if ($null -eq $tempPath) {
      Write-Error "Skipping '$item' due to bicep compilation failure"
      continue
    }
    $removeARM = $true
  } else {
    $tempPath = $item
  }
  Write-Output "    - Generating Document for $tempPath"
  if ($ValidMetaData) {
    Get-AzDocTemplateFile -Path $tempPath | ForEach-Object {
      # Generate a standard name of the markdown file. i.e. <name>_<version>.md
      $template = Get-Item -Path $_.TemplateFile;

      # Generate markdown
      Write-Output "      - Generating document for template '$template'"
      Invoke-PSDocument -Module PSDocs.Azure -OutputPath $templateDir -InputObject $template.FullName -InstanceName $docName -Culture $culture -ErrorAction Continue

    }
  } else {
    Write-Error "Invalid metadata in $metadataPath"
  }
  $outputFilePath = join-path $templateDir "$docName`.md"
  If (Test-Path $outputFilePath) {
    if ($gitRootDir.length -gt 0) {
      # replace the git root dir with a relative path in generated markdown file
      Write-Output "      - replacing git root dir '$gitRootDir' with '.' in generated markdown file '$outputFilePath'"
      #In case on Windows the git root directory has backslashes, escape them
      $gitRootDirToReplace = $gitRootDir -replace '\\', '\\\\'
      (Get-Content $outputFilePath -Raw) -replace $gitRootDirToReplace, '.' | Set-Content $outputFilePath
    }

    Write-Output "    - Generated document '$outputFilePath'"
  } else {
    Write-Error "'$outputFilePath' not found"
  }
  #Remove temp ARM template if required
  if ($removeARM) {
    Write-Output "  - Remove temp ARM template $tempPath"
    Remove-Item -Path $tempPath -Force
  }
  Write-Output ""
}

Write-Output "Done."
#endregion
