<#
.SYNOPSIS
Parse NUnit XML test result files from Pester and output a formatted markdown summary to GitHub job summaries.

.DESCRIPTION
Parses one or more NUnit XML test result files (produced by Pester), generates a formatted markdown summary table,
and appends it to the GitHub Step Summary ($env:GITHUB_STEP_SUMMARY).

.PARAMETER InputFilePattern
Mandatory. Glob pattern to match NUnit XML test result files (e.g. '**/TEST-*.XML').

.PARAMETER TestTitle
Optional. Title displayed in the job summary markdown.

.PARAMETER SkipPassedTestsReport
Optional. When set, only failed and inconclusive tests are included in the detailed breakdown.

.EXAMPLE
./parse-pester-results.ps1 -InputFilePattern './TEST-POLICY*.XML' -TestTitle 'Policy Tests'

.EXAMPLE
./parse-pester-results.ps1 -InputFilePattern './TEST-*.XML' -TestTitle 'All Pester Tests' -SkipPassedTestsReport

#>

[CmdletBinding()]
param (
  [Parameter(Mandatory)]
  [String] $InputFilePattern,

  [Parameter(Mandatory = $false)]
  [string] $TestTitle = 'Pester Test Results',

  [Parameter(Mandatory = $false)]
  [switch] $SkipPassedTestsReport
)

#region functions
function Get-NUnitTestSummary {
  <#
  .SYNOPSIS
  Parse a single NUnit XML file and return a summary object.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [String] $FilePath
  )

  if (-not (Test-Path $FilePath)) {
    throw ('Test result file [{0}] not found' -f $FilePath)
  }

  try {
    [xml]$xml = Get-Content $FilePath -ErrorAction Stop
    $testResult = $xml.'test-results'
    if (-not $testResult) {
      Write-Warning ('File [{0}] does not contain NUnit test-results element' -f $FilePath)
      return $null
    }

    $total = [int]$testResult.total
    $failures = [int]$testResult.failures
    $errors = if ($testResult.errors) { [int]$testResult.errors } else { 0 }
    $inconclusive = if ($testResult.inconclusive) { [int]$testResult.inconclusive } else { 0 }
    $notRun = if ($testResult.'not-run') { [int]$testResult.'not-run' } else { 0 }
    $passed = $total - $failures - $inconclusive - $errors

    [PSCustomObject]@{
      FileName     = [System.IO.Path]::GetFileName($FilePath)
      FilePath     = $FilePath
      Total        = $total
      Passed       = $passed
      Failed       = $failures
      Errors       = $errors
      Inconclusive = $inconclusive
      NotRun       = $notRun
      XmlDoc       = $xml
    }
  } catch {
    Write-Warning "Failed to parse test result file: $FilePath. Error: $_"
    return $null
  }
}

function Get-NUnitFailedTests {
  <#
  .SYNOPSIS
  Extract failed test case details from NUnit XML.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [xml] $XmlDoc
  )

  $failedTests = @()
  $testCases = $XmlDoc.SelectNodes("//test-case[@success='False' or @result='Failure' or @result='Error']")
  foreach ($tc in $testCases) {
    $failedTests += [PSCustomObject]@{
      Name    = $tc.name
      Result  = $tc.result
      Message = if ($tc.failure) { $tc.failure.message } elseif ($tc.'stack-trace') { $tc.'stack-trace' } else { '' }
    }
  }
  $failedTests
}

function Get-NUnitPassedTests {
  <#
  .SYNOPSIS
  Extract passed test case details from NUnit XML.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [xml] $XmlDoc
  )

  $passedTests = @()
  $testCases = $XmlDoc.SelectNodes("//test-case[@success='True' or @result='Success']")
  foreach ($tc in $testCases) {
    $passedTests += [PSCustomObject]@{
      Name   = $tc.name
      Result = $tc.result
    }
  }
  $passedTests
}
#endregion

#region main
# Resolve test result files
$testFiles = @(Resolve-Path -Path $InputFilePattern -ErrorAction SilentlyContinue | ForEach-Object { Get-Item $_.Path } | Where-Object { $_.Extension -eq '.XML' -or $_.Extension -eq '.xml' })

if ($testFiles.Count -eq 0) {
  throw "No NUnit XML test result files found matching pattern: $InputFilePattern"
}

# Parse all files
$summaries = @()
foreach ($file in $testFiles) {
  $summary = Get-NUnitTestSummary -FilePath $file.FullName
  if ($null -ne $summary) {
    $summaries += $summary
  }
}

if ($summaries.Count -eq 0) {
  throw "No valid NUnit test results could be parsed."
}

# Build markdown output
$md = [System.Text.StringBuilder]::new()
$null = $md.AppendLine("# $TestTitle")
$null = $md.AppendLine('')

# Summary table
$totalTests = ($summaries | Measure-Object -Property Total -Sum).Sum
$totalPassed = ($summaries | Measure-Object -Property Passed -Sum).Sum
$totalFailed = ($summaries | Measure-Object -Property Failed -Sum).Sum
$totalInconclusive = ($summaries | Measure-Object -Property Inconclusive -Sum).Sum

if ($totalFailed -eq 0 -and $totalInconclusive -eq 0) {
  $null = $md.AppendLine((':rocket: All [{0}] tests passed :rocket:' -f $totalTests))
  $null = $md.AppendLine('')
}

$null = $md.AppendLine('| Test File | Total | :white_check_mark: Passed | :x: Failed | :warning: Inconclusive |')
$null = $md.AppendLine('| :-- | :-- | :-- | :-- | :-- |')

foreach ($s in $summaries) {
  $icon = if ($s.Failed -gt 0) { ':x:' } elseif ($s.Inconclusive -gt 0) { ':warning:' } else { ':white_check_mark:' }
  $null = $md.AppendLine(('| {0} {1} | {2} | {3} | {4} | {5} |' -f $icon, $s.FileName, $s.Total, $s.Passed, $s.Failed, $s.Inconclusive))
}
$null = $md.AppendLine('')

# Failed tests detail
$allFailed = @()
foreach ($s in $summaries) {
  if ($s.Failed -gt 0) {
    $failedTests = Get-NUnitFailedTests -XmlDoc $s.XmlDoc
    foreach ($ft in $failedTests) {
      $allFailed += [PSCustomObject]@{
        File    = $s.FileName
        Name    = $ft.Name
        Result  = $ft.Result
        Message = $ft.Message
      }
    }
  }
}

if ($allFailed.Count -gt 0) {
  $null = $md.AppendLine('<details>')
  $null = $md.AppendLine('<summary>List of Failed Tests</summary>')
  $null = $md.AppendLine('')
  $null = $md.AppendLine('## Failed Tests')
  $null = $md.AppendLine('')
  $null = $md.AppendLine('| Source File | Test Name | Result | Message |')
  $null = $md.AppendLine('| :-- | :-- | :-- | :-- |')
  foreach ($ft in $allFailed) {
    $msg = ($ft.Message -replace '\|', '\|' -replace "`n", ' ' -replace "`r", '').Substring(0, [Math]::Min(200, $ft.Message.Length))
    $null = $md.AppendLine(('| {0} | `{1}` | {2} | {3} |' -f $ft.File, $ft.Name, $ft.Result, $msg))
  }
  $null = $md.AppendLine('')
  $null = $md.AppendLine('</details>')
  $null = $md.AppendLine('')
}

# Passed tests detail (optional)
if (-not $SkipPassedTestsReport) {
  $allPassed = @()
  foreach ($s in $summaries) {
    if ($s.Passed -gt 0) {
      $passedTests = Get-NUnitPassedTests -XmlDoc $s.XmlDoc
      foreach ($pt in $passedTests) {
        $allPassed += [PSCustomObject]@{
          File = $s.FileName
          Name = $pt.Name
        }
      }
    }
  }

  if ($allPassed.Count -gt 0) {
    $null = $md.AppendLine('<details>')
    $null = $md.AppendLine('<summary>List of Passed Tests</summary>')
    $null = $md.AppendLine('')
    $null = $md.AppendLine('## Passed Tests')
    $null = $md.AppendLine('')
    $null = $md.AppendLine('| Source File | Test Name |')
    $null = $md.AppendLine('| :-- | :-- |')
    foreach ($pt in $allPassed) {
      $null = $md.AppendLine(('| {0} | `{1}` |' -f $pt.File, $pt.Name))
    }
    $null = $md.AppendLine('')
    $null = $md.AppendLine('</details>')
    $null = $md.AppendLine('')
  }
}

# Write to GitHub Step Summary
$markdownContent = $md.ToString()
if ($env:GITHUB_STEP_SUMMARY -and (Test-Path $env:GITHUB_STEP_SUMMARY)) {
  Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value $markdownContent
  Write-Verbose 'Successfully appended NUnit test results to GitHub Job Summary' -Verbose
} else {
  Write-Verbose 'GITHUB_STEP_SUMMARY not available, outputting to console:' -Verbose
  Write-Output $markdownContent
}

# Fail the pipeline if any tests failed
if ($totalFailed -gt 0) {
  throw "$totalFailed test(s) failed out of $totalTests total. See the job summary for details."
}
#endregion
