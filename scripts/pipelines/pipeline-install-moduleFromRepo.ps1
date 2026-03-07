<#
=========================================================================
AUTHOR: Tao Yang
DATE: 24/04/2025
NAME: pipeline-install-moduleFromRepo.ps1
VERSION: 1.2.0
COMMENT: Register PowerShell module repository if not already registered
=========================================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $false)]
  [string]$repoName = 'PSGallery',

  [parameter( Mandatory = $false)]
  [string[]]$modules = 'Az.ResourceGraph',

  [parameter(Mandatory = $false)]
  [ValidateRange(3, 10)]
  [int]$maxRetry = 3,

  [parameter(Mandatory = $false)]
  [ValidateSet('true', 'false')]
  [string]$allowPrerelease = $false
)

#region functions
Function getModuleFromRepo {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$name,

    [parameter(Mandatory = $false)]
    [string]$requiredVersion,

    [parameter(Mandatory = $true)]
    [boolean]$allowPrerelease,

    [parameter(Mandatory = $true)]
    [string]$repository,

    [parameter(Mandatory = $true)]
    [ValidateRange(3, 10)]
    [int]$maxRetry
  )
  $moduleParams = @{
    Name            = $name
    repository      = $repository
    AllowPrerelease = $allowPrerelease
  }
  if ($PSBoundParameters.ContainsKey('requiredVersion')) {
    Write-Verbose "Searching module '$name' version '$requiredVersion' from repo '$repository'..." -Verbose
    $moduleParams.Add('RequiredVersion', $requiredVersion)
  } else {
    Write-Verbose "Searching latest version of module '$name' from repo '$repository'..." -Verbose
  }
  $retryCount = 0
  $findCommandSuccessful = $false
  $defaultRetryAfterSeconds = 10
  Do {
    try {
      $retryCount++
      $moduleFromRepo = Find-Module @moduleParams
      if ($null -ne $moduleFromRepo) {
        $findCommandSuccessful = $true
      }

    } catch {
      Write-Verbose "Error occurred while searching module '$name' from repo '$repository'. Error: $($_.Exception.Message)" -Verbose
      if ($retryCount -le $maxRetry) {
        Write-Verbose "Will retry in $defaultRetryAfterSeconds seconds." -verbose
        Start-Sleep -Seconds $defaultRetryAfterSeconds
      } else {
        Write-Verbose "Max retry count reached. Will not retry." -verbose
      }
    }
  } until ($retryCount -ge $maxRetry -or $findCommandSuccessful -eq $true)

  If (!$moduleFromRepo) {
    Write-Error "Module '$($moduleParams.name)' not found from repo '$repository'."
    Exit -1
  } else {
    Write-Verbose "Module '$($moduleParams.name)' found from repo '$repository'. Version: '$($moduleFromrepo.version)'."
    $moduleFromRepo
  }
}
#endregion

#find out agent details
Write-Verbose "Environment Variable 'AGENT_ISSELFHOSTED': $($env:AGENT_ISSELFHOSTED)" -verbose
$isSelfHostedAgent = [boolean]$([int]$env:AGENT_ISSELFHOSTED)
$agentOS = $env:AGENT_OS
Write-Output "Agent OS: $agentOS"
Write-Output "Is Self Hosted Agent: $isSelfHostedAgent"

#convert string true/false to boolean
$bAllowPrerelease = [System.Convert]::ToBoolean($allowPrerelease)
Write-Verbose "Allow Prerelease module versions: $bAllowPrerelease" -verbose
switch ($agentOS) {
  'Windows_NT' { $psModulePath = $env:SystemDrive + "\Modules" }
  default { $psModulePath = "/usr/share" }
}
#install module if required
Foreach ($module in $modules) {
  Write-Output "Processing module '$module' from repo '$repoName'..."
  #split module name and version
  $moduleDetails = $module.Split('@')
  $moduleParams = @{
    name            = $moduleDetails[0].trim()
    repository      = $repoName
    AllowPrerelease = $bAllowPrerelease
  }

  if ($moduleDetails.Count -eq 2) {
    $bVersionSpecified = $true
    $moduleParams.RequiredVersion = $moduleDetails[1].trim()
  } else {
    $bVersionSpecified = $false
  }

  $moduleFromRepo = getModuleFromRepo @moduleParams -maxRetry $maxRetry
  If (!$moduleFromRepo) {
    Write-Error "Unable to find module '$($moduleParams.name)' from repo '$repoName'. Unable to continue."
    Exit -1
  } else {
    Write-output "  - Module '$($moduleParams.name)' found from repo '$repoName'. Version: '$($moduleFromrepo.version)'."
  }

  If ( $($moduleParams.name) -ieq 'az') {
    if ($isSelfHostedAgent) {
      Write-Output "  - Skip installing Az module on self-hosted agent. Az module must be installed manually on self-hosted agents."
      Continue
    } else {
      if ($bVersionSpecified) {
        $modulePath = Join-Path -Path $psModulePath -ChildPath "$($moduleParams.name.tolower())_$($moduleParams.RequiredVersion)"
      } else {
        Write-Output "  - Processing module '$($moduleParams.name)' from repo '$repoName'"
        $moduleFromRepo = getModuleFromRepo @moduleParams
        $modulePath = Join-Path -Path $psModulePath -ChildPath "$($moduleParams.name.tolower())_$($moduleFromRepo.version)"
      }
      if (Test-Path $modulePath) {
        Write-Output "  - Module Path '$modulePath' already exists. No need to download again."

      } else {
        Write-Output "  - Module Path '$modulePath' does not exists. Creating now"
        New-Item -Path $modulePath -ItemType Directory | out-null
        Write-Output "  - Downloading module '$($moduleParams.name)' from repo '$repoName' to '$modulePath'"
        do {
          $retryCount = 0
          $defaultRetryAfterSeconds = 10
          $installSuccessful = $false
          try {
            $moduleFromRepo | Save-Module -LiteralPath $modulePath -verbose -ErrorVariable installError
            if (!$installError) {
              $installSuccessful = $true
              Write-Verbose "Module '$($moduleFromRepo.name)' saved successfully to '$modulePath'." -verbose
            } else {
              Write-Error $installError
            }
          } catch {
            Write-Verbose "Error occurred while saving the az module."
            Write-Verbose "Error: $_" -verbose
            if ($retryCount -le $maxRetry) {
              Write-Verbose "Will retry in $defaultRetryAfterSeconds seconds." -verbose
              Start-Sleep -Seconds $defaultRetryAfterSeconds
            } else {
              Write-Verbose "Max retry count reached. Will not retry." -verbose
            }
          }
        } until ($retryCount -ge $maxRetry -or $installSuccessful -eq $true)
      }
    }
  } else {
    if (!$bVersionSpecified) {
      Write-Output "  - Check if the latest version of module '$($moduleParams.name)' is already installed"
      $installedModule = Get-InstalledModule -Name $($moduleParams.name) -ErrorAction SilentlyContinue
    } else {
      Write-Output "  - Check if the required version '$($moduleParams.RequiredVersion)' of module '$($moduleParams.name)' is already installed"
      $installedModule = Get-InstalledModule -Name $($moduleParams.name) -RequiredVersion $($moduleParams.RequiredVersion) -ErrorAction SilentlyContinue
    }

    $bInstall = $false

    If (!$installedModule) {
      Write-Output "  - Module '$($moduleParams.name)' currently not installed."
      $bInstall = $true
    } else {
      Write-Output "  - Module '$($moduleParams.name)' already installed. Installed version: '$($installedModule.version)'"
      #Module already installed, compare the version
      If ($($moduleFromRepo.version) -gt $($installedModule.version) -and !$bVersionSpecified) {
        Write-Output "  - The version for module '$($moduleParams.name)' from repo '$repoName' is $($moduleFromRepo.version), which is greater than the existing version $($installedModule.version). Newer version will be installed."
        $bInstall = $true
      }
    }
    #install module if required
    if ($bInstall) {
      Write-output "  - Installing module '$($moduleParams.name)' from repo '$repoName'..."
      $retryCount = 0
      $defaultRetryAfterSeconds = 10
      $installSuccessful = $false
      Do {
        try {
          $retryCount++
          Install-Module @moduleParams -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber -ErrorVariable installError
          if (!$installError) {
            $installSuccessful = $true
          }
        } Catch {
          Write-Verbose "Error occurred while installing the module."
          Write-Verbose "Error: $_" -verbose
          if ($retryCount -le $maxRetry) {
            Write-Verbose "Will retry in $defaultRetryAfterSeconds seconds." -verbose
            Start-Sleep -Seconds $defaultRetryAfterSeconds
          } else {
            Write-Verbose "Max retry count reached. Will not retry." -verbose
          }
        }
      } until ($retryCount -ge $maxRetry -or $installSuccessful -eq $true)
    }
  }
  if ($bInstall) {
    if ($installSuccessful) {
      Write-Output "  - Module '$($moduleParams.name)' installed successfully."
    } else {
      Write-Error "  - Failed to install module '$($moduleParams.name)'."
      Exit -1
    }
  } else {
    Write-Output "  - Module '$($moduleParams.name)' is already installed and up to date."
  }

}

Write-Output "Done"
