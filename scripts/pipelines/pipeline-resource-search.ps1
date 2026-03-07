#Requires -Modules Az.Accounts
#Requires -Module @{ModuleName="Az.ResourceGraph"; ModuleVersion="0.10.0"}
<#
=================================================================
AUTHOR: Tao Yang
DATE: 29/07/2022
NAME: pipeline-resource-search.ps1
VERSION: 1.0.0
COMMENT: Searching existing resources using Azure Resource Graph
=================================================================
#>

[CmdletBinding()]
param (
  [parameter(Mandatory = $false, ParameterSetName = 'PredefinedQuery', HelpMessage = "the scope for the ARG search query. This can be a subscription id, subscription name, or a management group name")]
  [parameter(Mandatory = $false, ParameterSetName = 'CustomQuery', HelpMessage = "the scope for the ARG search query. This can be a subscription id, subscription name, or a management group name")]
  [string]$Scope,

  [parameter(Mandatory = $true, ParameterSetName = 'PredefinedQuery', HelpMessage = "the scope type for the ARG search query. Possible values are 'subscription' and 'managementGroup'")]
  [parameter(Mandatory = $true, ParameterSetName = 'CustomQuery', HelpMessage = "the scope type for the ARG search query. Possible values are 'subscription' and 'managementGroup'")]
  [ValidateSet("subscription", "managementGroup", "tenant")]
  [string]$ScopeType,

  [parameter(Mandatory = $true, ParameterSetName = 'PredefinedQuery', HelpMessage = "the name of pre-defined ARG search query.")]
  [string]$queryName,

  [parameter(Mandatory = $true, ParameterSetName = 'CustomQuery', HelpMessage = "the custom ARG search query.")]
  [string]$customQuery
)

#region functions
function ValidateScope {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)][string]$scope,
    [parameter(Mandatory = $true)][string]$scopeType
  )
  $bValid = $false
  if ($scopeType -ieq "subscription") {
    if ($scope -match $script:guidRegex) {
      Write-Verbose "the scope is a valid GUID, will try to look up the subscription by subscription Id (GUID)"
      $params = @{
        SubscriptionId = $scope
      }
    } else {
      Write-Verbose "the scope is a not valid GUID, will try to look up the subscription by subscription name"
      $params = @{
        SubscriptionName = $scope
      }
    }
    $subscription = Get-AzSubscription @params -ErrorAction SilentlyContinue
    if ($subscription) {
      Write-Verbose "the subscription is found"
      $script:validatedScope = $subscription.SubscriptionId
      $bValid = $true
    }
  } else {
    Write-Verbose "Validating the management group name"
    $mg = Get-AzManagementGroup -GroupId $scope -ErrorAction SilentlyContinue
    if ($mg) {
      Write-Verbose "the management group is found"
      $script:validatedScope = $mg.Name
      $bValid = $true
    }
  }
  $bValid
}

function InvokeARGQuery {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $false)][string]$scope,
    [parameter(Mandatory = $true)][string]$scopeType,
    [parameter(Mandatory = $true)][string]$query
  )
  $params = @{
    Query = $query
    First = 1000
  }
  if ($scopeType -ieq "subscription") {
    $params.add('Subscription', $scope)
  } elseif ($scopeType -ieq "managementGroup") {
    $params.add('ManagementGroup', $scope)
  } else {
    $params.add('UseTenantScope', $true)
  }

  $asgs = Search-AzGraph @params
  $asgs
}

#endregion

#region main
#Suppress the Az PS module warning messages
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#variables
$script:guidRegex = '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$'

#ARG queries
$Script:ARGQuery_StorageAccount = @"
resources
| where type =~ 'microsoft.storage/storageAccounts'
"@

$Script:ARGQuery_NetworkSecurityGroup = @"
resources
| where type =~ 'microsoft.network/networksecuritygroups'
"@

$Script:ARGQuery_VirtualNetwork = @"
resources
| where type =~ 'microsoft.network/virtualNetworks'
"@

$Script:ARGQuery_Subscription = @"
ResourceContainers
| where type =~ 'microsoft.resources/subscriptions'
| extend  mgParent = properties.managementGroupAncestorsChain
"@

$Script:ARGQuery_PrivateEndpoint = @"
resources
| where type =~ 'Microsoft.Network/privateEndpoints'
| extend privateLinkServiceId = properties.privateLinkServiceConnections[0].properties.privateLinkServiceId
| extend groupId = properties.privateLinkServiceConnections[0].properties.groupIds[0]
| extend subnetId = properties.subnet.id
| extend networkInterfaceId = properties.networkInterfaces[0].id
| project id, name, tenantId, location, resourceGroup, subscriptionId, properties, zones, extendedLocation, privateLinkServiceId, groupId, subnetId, networkInterfaceId
"@

$Script:ARGQuery_LogAnalyticsWorkspace = @"
resources
| where type == "microsoft.operationalinsights/workspaces"
"@

$Script:ARGQuery_KeyVault = @"
resources
| where type == "microsoft.keyvault/vaults"
"@

$Script:ARGQuery_Databricks = @"
resources
| where type == "microsoft.databricks/workspaces"
"@

$argQueryVariables = Get-Variable -Scope script -Include ARGQuery_*
$htArgQueries = @{}
foreach ($v in $argQueryVariables) {
  $key = ($v.Name -split '_')[1]
  $htArgQueries.Add($key, $v.Value)
}
$strValidQueryNames = $htArgQueries.Keys -join ', '
#input validation
if ($ScopeType -ine 'tenant') {
  Write-Verbose "Validating the scope"
  $bValid = ValidateScope -Scope $Scope -ScopeType $ScopeType
  if (!$bValid) {
    Write-Error "the scope is not valid. '$scope' is not a valid '$scopeType'"
    exit 1
  } else {
    Write-Verbose "The scope is valid. $script:validatedScope is the validated scope of '$scopeType'."
  }
}

if ($PSCmdlet.ParameterSetName -ieq 'PredefinedQuery') {
  Write-Verbose "Validating the query name"
  if (!$htArgQueries.ContainsKey($queryName)) {
    Write-Error "the query name is not valid. '$queryName' is not a valid query name. The valid query names are '$strValidQueryNames'"
    exit 1
  } else {
    Write-Verbose "The query name is valid. '$queryName' is the validated query name."
  }
  $query = $htArgQueries[$queryName]
} else {
  $query = $customQuery
}


#Invoke ARG query
if ($ScopeType -ine 'tenant') {
  $QueryResult = InvokeARGQuery -Scope $script:validatedScope -ScopeType $ScopeType -Query $query
} else {
  $QueryResult = InvokeARGQuery -Query $query -ScopeType $ScopeType
}
if ($PSCmdlet.ParameterSetName -ieq 'PredefinedQuery') {
  Write-Verbose "$($QueryResult.count) resources are found for the query '$queryName'."
} else {
  Write-Verbose "$($QueryResult.count) resources are found for the custom query."
}
$QueryResult | ConvertTo-Json -Depth 99
#endreigon
