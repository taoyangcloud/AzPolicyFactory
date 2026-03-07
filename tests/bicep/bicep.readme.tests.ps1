[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true)][validateScript({ Test-Path $_ -PathType Container })][string]$BicepDir
)
Write-Verbose "Bicep Folder Path: '$BicepDir'"
#variables
$TestName = "README File Test"
$readmeFileName = "README.md"
$MarkdownLevel1Regex = '^#\s\S+'
$requiredHeadings = @()
#$requiredHeadings += "## Parameters"
#$requiredHeadings += "## Outputs"
$requiredHeadings += "## Snippets"
$requiredHeadings += "### Parameter file"

$readmeFile = Get-ChildItem -Path $bicepDir -Filter $readmeFileName -ErrorAction SilentlyContinue
$env:readmeFilePath = $readmeFile.FullName

Describe $TestName {
  BeforeAll {
    $script:readmeContent = Get-Content -Path $env:readmeFilePath -ErrorAction SilentlyContinue
    Write-Verbose "Readme File line count: $($script:readmeContent.count)"
  }
  Context "File" {
    It 'Should exist' {
      Test-Path $(join-path $BicepDir $readmeFileName) -ErrorAction SilentlyContinue | should -Be $true
    }

    It "Name should have correct case" {
      $readmeFile.Name -ceq $readmeFileName | should -be $true
    }
  }

  Context "Content" {
    it "Should begin with level 1 heading" {
      $script:readmeContent[0] -match $MarkdownLevel1Regex | should -Be $true
    }
    it "Should only container one level 1 heading" {
      $count = [regex]::match($script:readmeContent, $MarkdownLevel1Regex).count
      $count | should -Be 1
    }
    it "Should contain heading <_>" -ForEach $requiredHeadings {
      Write-Verbose "Checking for $_"
      $script:readmeContent | should -Contain $_
    }

  }
}
