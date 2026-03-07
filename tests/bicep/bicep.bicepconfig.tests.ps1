[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true)][validateScript({ Test-Path $_ -PathType Container })][string]$BicepDir
)
#region functions
function GetGitRootDir {
  $gitRootDir = Invoke-expression 'git rev-parse --show-toplevel 2>&1' -ErrorAction SilentlyContinue
  if (Test-Path $gitRootDir) {
    Convert-Path $gitRootDir
  }
}
Function FindNearestBicepConfigFile {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)][string]$BicepDir,
    [Parameter(Mandatory = $false)][string]$RootDir = ''
  )
  $bicepConfigFileName = 'bicepconfig.json'
  if ($RootDir -ne '' -and -not (Test-Path $RootDir)) {
    throw "[bicepconfig File Test] - RootDir '$RootDir' does not exist"
  } else {
    Write-Verbose "[bicepconfig File Test] - Root Directory for the search is set to '$RootDir'" -Verbose
  }
  Write-Verbose "[bicepconfig File Test] - Finding nearest $bicepConfigFileName file in '$BicepDir'" -Verbose
  $searchDir = $BicepDir
  $found = $false
  Do {
    Write-Verbose "[bicepconfig File Test] - Searching $bicepConfigFileName in '$searchDir'" -Verbose
    $bicepconfigFile = Get-ChildItem -Path $searchDir -Filter $bicepConfigFileName -ErrorAction SilentlyContinue
    if ($bicepconfigFile) {
      $found = $true
    }
    $searchDir = Split-Path -Path $searchDir -Parent
  } until ($found -or $(Convert-Path $BicepDir) -ieq $(Convert-Path $RootDir) -or $searchDir -eq $null)

  if ($bicepconfigFile) {
    Write-Verbose "[bicepconfig File Test] - Found $bicepConfigFileName file: '$($bicepconfigFile.FullName)'" -Verbose
    return $bicepconfigFile
  } else {
    throw "[bicepconfig File Test] - $bicepConfigFileName file not found in the directory '$BicepDir' or any of its parent directories."
  }
}
#
$bicepDirFullPath = (Get-item $BicepDir).FullName
$params = @{
  BicepDir = $bicepDirFullPath
}
$gitRootDir = GetGitRootDir
Write-Verbose "[bicepconfig File Test] - Bicep Folder Path: '$BicepDir'" -Verbose
if ($gitRootDir) {
  Write-Verbose "[bicepconfig File Test] - Git Root Folder Path: '$gitRootDir'" -Verbose
  $params.Add("RootDir", $gitRootDir)
}
#variables
$TestName = "Bicepconfig File Test"
$env:bicepconfigFileName = "bicepconfig.json"
$env:bicepconfigSchemaFile = join-path $PSScriptRoot "bicepconfig.schema.json"

#$bicepconfigFile = Get-ChildItem -Path $bicepDir -Filter $env:bicepconfigFileName -ErrorAction SilentlyContinue
$bicepconfigFile = FindNearestBicepConfigFile @params
$env:bicepconfigFilePath = $bicepconfigFile.FullName
$env:bicepconfigFileActualName = $bicepconfigFile.name
Describe $TestName {
  BeforeAll {
    $script:bicepconfigContent = Get-Content -Path $env:bicepconfigFilePath -Raw
    $script:bicepconfigFileName = $env:bicepconfigFileName
    $script:bicepconfigFilePath = $env:bicepconfigFilePath
    $script:bicepconfigFileActualName = $env:bicepconfigFileActualName
    $script:bicepconfigSchemaFile = $env:bicepconfigSchemaFile
  }
  Context "File" {
    It 'Should exist' {
      Test-Path $bicepconfigFilePath -ErrorAction SilentlyContinue | should -Be $true
    }

    It "Name should have correct case" {
      $script:bicepconfigFileActualName -ceq $script:bicepconfigFileName | should -be $true
    }
  }

  Context "Content" {
    it "Should be a valid Json file" {
      ConvertFrom-Json -InputObject $script:bicepconfigContent -ErrorVariable parseError
      $parseError | Should -Be $Null
    }
    It 'Should be a valid JSON file against Schema' {

      $Schema = Get-Content -Path $script:bicepconfigSchemaFile -Raw
      Test-Json -Json $script:bicepconfigContent -schema $Schema | Should -Be $true
    }
  }
}
