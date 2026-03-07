<#
================================================
AUTHOR: Tao Yang
DATE: 28/03/2025
NAME: pipeline-install-bicep.ps1
VERSION: 1.0.0
COMMENT: Install Bicep on ADO pipeline agents
================================================
#>
[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [string] $DesiredVersion
)

#region functions
function InstallBicepLinux {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $DesiredVersion
  )

  begin {
    Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
  }

  process {
    # Check the current Bicep CLI version
    try {
      $CurrentVersion = [regex]::Match($(bicep --version), '[\d\.]+').Value
    } catch {
      Write-Warning $PSItem.Exception.Message
      $CurrentVersion = 'Not Available'
    }
    # Compare the current and desired versions
    if ($CurrentVersion -ne $DesiredVersion) {
      # Install the desired version
      Write-Verbose -Message "The current Bicep CLI version is '$CurrentVersion'. Installing desired version '$DesiredVersion'..." -Verbose
      try {
        # Attempt to remove the existing Bicep CLI binary
        Write-Verbose "Attempt to remove the existing Bicep CLI binary..." -Verbose
        sudo rm /usr/local/bin/bicep
        # Fetch the latest Bicep CLI binary
        Write-Verbose "Fetch the latest Bicep CLI binary..." -Verbose
        curl -Lo bicep-linux-x64 "https://github.com/Azure/bicep/releases/download/v$DesiredVersion/bicep-linux-x64"
        #https://github.com/Azure/bicep/releases/download/v0.37.4/bicep-linux-x64
        #https://github.com/Azure/bicep/releases/download/v0.37.4/bicep-linux-x64
        # Mark it as executable
        Write-Verbose "Mark the Bicep CLI binary as executable..." -Verbose
        chmod +x ./bicep-linux-x64
        # Add bicep to your PATH (requires admin)
        Write-Verbose "Move the Bicep CLI binary to /usr/local/bin..." -Verbose
        sudo mv ./bicep-linux-x64 /usr/local/bin/bicep
        # Verify installation
        Write-Verbose "Verify the Bicep CLI installation..." -Verbose
        bicep --version
      } catch {
        Write-Error $PSItem.Exception.Message
      }
    } else {
      Write-Verbose -Message "The desired Bicep CLI version is already installed. No action needed." -Verbose
    }
  }

  end {
    Write-Debug ('{0} exiting' -f $MyInvocation.MyCommand)
  }
}

Function InstallBicepWindows {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $DesiredVersion
  )

  begin {
    Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
  }

  process {
    # Check the current Bicep CLI version
    try {
      $CurrentVersion = [regex]::Match($(bicep --version), '[\d\.]+').Value
    } catch {
      Write-Warning $PSItem.Exception.Message
      $CurrentVersion = 'Not Available'
    }
    # Compare the current and desired versions
    if ($CurrentVersion -ne $DesiredVersion) {
      # Install the desired version
      Write-Verbose -Message "The current Bicep CLI version is '$CurrentVersion'.. Installing desired version '$DesiredVersion'..." -Verbose
      try {
        $installPath = "$env:USERPROFILE\.bicep"
        $installDir = New-Item -ItemType Directory -Path $installPath -Force
        $installDir.Attributes += 'Hidden'
        # Fetch the latest Bicep CLI binary
        (New-Object Net.WebClient).DownloadFile("https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe", "$installPath\bicep.exe")
        # Add bicep to your PATH
        $currentPath = (Get-Item -path "HKCU:\Environment" ).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        if (-not $currentPath.Contains("%USERPROFILE%\.bicep")) { setx PATH ($currentPath + ";%USERPROFILE%\.bicep") }
        if (-not $env:path.Contains($installPath)) { $env:path += ";$installPath" }
        # Verify you can now access the 'bicep' command.
        bicep --help
      } catch {
        Write-Error $PSItem.Exception.Message
      }
    } else {
      Write-Verbose -Message "The desired Bicep CLI version is already installed. No action needed." -Verbose
    }
  }

  end {
    Write-Debug ('{0} exiting' -f $MyInvocation.MyCommand)
  }
}
#endregion

#region main
$os = $env:AGENT_OS
$isSelfHostedAgent = [boolean]$([int]$env:AGENT_ISSELFHOSTED)
if ($isSelfHostedAgent) {
  Write-Output "Self-hosted agent detected. Skip Bicep installation and make sure desired version is installed manually on the agent Computer."
  exit 0
}
if ($os -eq 'Linux') {
  InstallBicepLinux -DesiredVersion $DesiredVersion
} elseif ($os -eq 'Windows_NT') {
  InstallBicepWindows -DesiredVersion $DesiredVersion
} else {
  Write-Error "Unsupported OS: $os"
}
#endregion
