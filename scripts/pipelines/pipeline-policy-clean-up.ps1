#Requires -Modules @{ModuleName = 'Az.Resources'; ModuleVersion = '8.0.0'}; @{ModuleName = 'Az.Accounts'; ModuleVersion = '5.0.1'}

<#
======================================================
AUTHOR: Tao Yang
DATE: 15/05/2024
NAME: pipeline-policy-clean-up.ps1
VERSION: 1.0.0
COMMENT: Delete policy resources from management group
======================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [string]$resourceListFilePath
)

#region functions
function DeleteRoleAssignment {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$roleAssignmentId
  )
  Write-Output "    - Deleting Role Assignment '$roleAssignmentId'"
  $uri = 'https://management.azure.com{0}?api-version=2022-04-01' -f $roleAssignmentId
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
  }
  $response = Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers
  If ($response.StatusCode -eq 200) {
    Write-Output "    - Role Assignment '$roleAssignmentId' deleted."
  } elseif ($response.StatusCode -eq 204) {
    Write-Output "    - Role Assignment '$roleAssignmentId' already deleted or does not exist."
  } else {
    Write-Error "    - Failed to delete Role Assignment '$roleAssignmentId'."
    Write-Error "    - Response: $($response.Content)"
  }
}

#endregion
#region main
#Load external functions
$getRoleAssignmentScriptPath = join-path $PSScriptRoot 'helper' 'getRoleAssignments.ps1'
Write-Verbose "Load external functions from: $getRoleAssignmentScriptPath" -verbose
. $getRoleAssignmentScriptPath
#process the resource list file
Write-Output "Processing resource list file: $resourceListFilePath"
$content = Get-Content -Path $resourceListFilePath -Raw
$resourceList = ConvertFrom-Json -InputObject $content -ErrorVariable parseError
if ($parseError) {
  Throw $parseError
  exit -1
}
$resourceType = $resourceList.resourceType
$managementGroup = $resourceList.managementGroup
$resources = $resourceList.resources
$TotalResources = $resources.count

Write-Output "Resource Type: '$resourceType'"
Write-Output "Management Group: '$managementGroup'"
Write-Output "Total Resources: $TotalResources"

Write-Output "Removing $TotalResources policy $resourceType resources."
$i = 1
switch ($resourceType) {
  'definition' {
    foreach ($r in $resources) {
      Write-Output "  - [$i/$TotalResources] Removing Policy $resourceType '$($r.ResourceId)'."
      Remove-AzPolicyDefinition -id $($r.ResourceId) -force
      $i++
    }
  }
  'initiative' {
    foreach ($r in $resources) {
      Write-Output "  - [$i/$TotalResources] Removing Policy $resourceType '$($r.ResourceId)'."
      Remove-AzPolicySetDefinition -id $($r.ResourceId) -force
      $i++
    }
  }
  'exemption' {
    foreach ($r in $resources) {
      Write-Output "  - [$i/$TotalResources] Removing Policy $resourceType '$($r.ResourceId)'."
      Remove-AzPolicyExemption -id $($r.ResourceId) -force
      $i++
    }
  }
  'assignment' {
    foreach ($r in $resources) {
      if ($r.principalId) {
        Write-Output "  - Removing Role Assignments for the Policy $resourceType '$($r.id)' principal Id: '$($r.principalId)'."
        $roleAssignments = getRoleAssignment -principalId $r.principalId
        Write-Verbose "    - $($roleAssignments.count) role assignments found for principalId '$($r.principalId)'." -verbose
        if ($roleAssignments) {
          foreach ($ra in $roleAssignments) {
            Write-Verbose "    - Delete Role Assignment: '$($ra.id)' on scope $($ra.scope)" -verbose
            DeleteRoleAssignment -roleAssignmentId $ra.id

          }
        } else {
          Write-Output "    - No role assignments found for principalId '$($r.principalId)'."
        }
      }
      Write-Output "  - [$i/$TotalResources] Removing Policy $resourceType '$($r.ResourceId)'."
      Remove-AzPolicyAssignment -id $($r.id)
      $i++
    }
  }
}

Write-Output "Done."
#endregion
