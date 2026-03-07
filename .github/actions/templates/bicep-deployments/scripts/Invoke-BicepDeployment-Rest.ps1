<#
===============================================================================================
AUTHOR: Tao Yang
DATE: 17/02/2026
NAME: Invoke-BicepDeployment-Rest.ps1
VERSION: 1.0.0
COMMENT: Bicep template deployment (via ARM deployment REST API) script used in Azure Pipeline
===============================================================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [string]$templateFileDirectory,

  [parameter(Mandatory = $true)]
  [string]$templateFileName,

  [parameter(Mandatory = $false)]
  [string]$parameterFileArtifactName,

  [parameter(Mandatory = $false)]
  [string]$parameterFileName,

  [parameter(Mandatory = $true)]
  [string]$templateName,

  [parameter(Mandatory = $false)]
  [string]$uniqueBuildIdPrefix = '',

  [parameter(Mandatory = $false)]
  [string]$parameterFileDirectory = $templateFileDirectory,

  [parameter(Mandatory = $true)]
  [string]$workspaceDirectory,

  [parameter(Mandatory = $false)]
  [int]$BuildNumber = $(Get-Random -Minimum 100000 -Maximum 999999),

  [parameter(Mandatory = $true)]
  [validateSet('resourceGroup', 'subscription', 'managementGroup', 'tenant')]
  [string]$templateScope,

  [parameter(Mandatory = $false)]
  [string]$azureLocation = 'australiaeast',

  [parameter(Mandatory = $false)]
  [string]$targetName,

  [parameter(Mandatory = $false)]
  [string]$subscriptionName,

  [parameter(Mandatory = $false)]
  [ValidateSet('true', 'false')]
  [string]$retryFailedDeployment = 'true', #can't be boolean because pipeline can only pass string

  [parameter(Mandatory = $false)]
  [ValidateRange(100, 1000)]
  [int]$httpTimeoutSeconds = 300,

  [Parameter(Mandatory = $false)]
  [ValidateRange(1, 360)]
  [int]$maxWaitMinutes = 60,

  [parameter(Mandatory = $false)]
  [int]$retryDelayInSeconds = 60,

  [ValidateSet('true', 'false')]
  [string]$publishDeploymentOutputs = 'true',

  [parameter(Mandatory = $false)]
  [string]$deploymentOutputVariablePrefix = '',

  [parameter(Mandatory = $false)]
  [string]$bicepModuleSubscriptionId = ''
)
$WarningPreference = 'SilentlyContinue'

#region function
function GetCurrentUTCString {
  "$([DateTime]::UtcNow.ToString('u')) UTC"
}

function ConvertBicepToJsonContent {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$bicepFilePath
  )
  $json = bicep build $bicepFilePath --stdout
  $json
}

function getAzDeploymentREST {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$uri
  )
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
  }
  Try {
    $deployment = Invoke-WebRequest -Uri $uri -Headers $headers -method 'get'
    If ($deployment.statuscode -ge 200 -and $deployment.statuscode -le 299) {
      $return = ConvertFrom-Json $deployment.content -Depth 99
    } else {
      Write-Error $deployment.rawContent
    }
  } Catch {
    $ExceptionDetails = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($ExceptionDetails)
    $ExceptionResponse = $reader.ReadToEnd();
    Write-Error $ExceptionResponse
    Write-Error $_.ErrorDetails
    throw $_.Exception
    $return = $null
  }
  $return
}
function newAzDeploymentREST {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$uri,

    [parameter(Mandatory = $true)]
    [int]$httpTimeoutSeconds,

    [Parameter(Mandatory = $true)]
    [int]$maxWaitMinutes,

    [Parameter(Mandatory = $true)]
    [validatescript({ test-path $_ -PathType Leaf })]
    [String]$templateFilePath,

    [Parameter(Mandatory = $false)]
    [validatescript({ test-path $_ -PathType Leaf })]
    [string]$ParameterFilePath,

    [parameter(Mandatory = $false)]
    [string]$location
  )
  #determine deployment scope
  $resourceGroupRegex = '\/subscriptions\/[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\/resourcegroups\/'
  $subscriptionRegex = '\/subscriptions\/[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\/providers\/microsoft\.resources\/deployments'
  $managementGroupRegex = '\/providers\/microsoft\.management\/managementgroups\/'
  $tenantRegex = 'https:\/\/management\.azure\.com\/providers\/microsoft\.resources\/deployments\/'
  switch ($uri) {
    { $_ -imatch $resourceGroupRegex } { $deploymentScope = 'resourceGroup' }
    { $_ -imatch $subscriptionRegex } { $deploymentScope = 'subscription' }
    { $_ -imatch $managementGroupRegex } { $deploymentScope = 'managementGroup' }
    { $_ -imatch $tenantRegex } { $deploymentScope = 'tenant' }
  }

  #Process template file
  $templateFile = Get-Item $TemplateFilePath
  if ($templateFile.Extension -ieq '.bicep') {
    Write-Verbose "[$(GetCurrentUTCString)]: '$templateFilePath' is a bicep file. Convert to Json" -verbose
    $templateFileContent = invoke-expression "bicep build '$templateFilePath' --stdout" | convertFrom-Json -depth 99
  } elseif ($templateFile.Extension -ieq '.json') {
    Write-Verbose "[$(GetCurrentUTCString)]: '$templateFilePath' is a json file. Get the content" -Verbose
    $templateFileContent = Get-Content -Path $TemplateFilePath -Raw | convertFrom-Json -depth 99
  } else {
    Throw "[$(GetCurrentUTCString)]: Template File '$templateFilePath' must be either a .json or .bicep file."
  }
  $body = @{
    properties = @{
      mode     = 'Incremental'
      template = $templateFileContent
    }
  }
  #Add location to the request body if the deployment scope is not resource group
  if ($deploymentScope -ine 'resourcegroup') {
    if ($null -eq $location) {
      Throw "[$(GetCurrentUTCString)]: Location cannot not be null when the deployment scope is '$deploymentScope'."
    }
    $body.add('location', $location)
  }

  #Process parameter file
  If ($PSBoundParameters.ContainsKey('ParameterFilePath')) {
    $parameterFile = Get-Item $ParameterFilePath
    if ($parameterFile.Extension -ieq '.bicepparam') {
      Write-Verbose "[$(GetCurrentUTCString)]: '$parameterFilePath' is a bicep parameter file. Convert to Json" -Verbose
      $parameterFileContent = Invoke-Expression "bicep build-params '$parameterFilePath' --stdout"
      #Read parameters from parameter file
      $parametersJson = (ConvertFrom-Json $parameterFileContent -Depth 99).parametersJson
      $parameters = (ConvertFrom-Json $parametersJson -Depth 99).parameters
    } elseif ($parameterFile.Extension -ieq '.json') {
      $parameterFileContent = Get-Content -Path $ParameterFilePath -Raw
      #Read parameters from parameter file
      $parameters = (ConvertFrom-Json $parameterFileContent -Depth 99).parameters
    }
    #Write-Verbose "parameters: $(ConvertTo-Json $parameters -Depth 99 -EscapeHandling 'EscapeNonAscii')" -Verbose
    $body.properties.Add('parameters', $parameters)
  } else {
    Write-Verbose "[$(GetCurrentUTCString)]: No parameter file provided. Deploying template without parameters." -Verbose
  }
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
  }
  $bodyJson = $body | ConvertTo-Json -Depth 99 -EscapeHandling 'EscapeNonAscii'
  #Create deployment
  $request = Invoke-WebRequest -Uri $uri -Headers $headers -method 'put' -body $bodyJson -ConnectionTimeoutSeconds $httpTimeoutSeconds -ContentType 'application/json'

  #Wait for deployment to complete
  $bWait = $true
  $waitUtil = (Get-Date).AddMinutes($maxWaitMinutes)
  do {
    Start-Sleep -Seconds 15
    $deployment = getAzDeploymentREST -Uri $uri
    $provisioningState = $deployment.properties.provisioningState.tolower()
    if ($provisioningState -ine 'running' -and $provisioningState -ine 'accepted') {
      $bWait = $false
      Write-Verbose "[$(GetCurrentUTCString)]:  Current provisioning state: '$provisioningState'. The wait is over." -verbose
    } else {
      if ($now -ge $waitUtil) {
        $bWait = $false
        Write-Verbose "[$(GetCurrentUTCString)]:  Current provisioning state: '$provisioningState'. The wait is over." -verbose
      } else {
        Write-Verbose "[$(GetCurrentUTCString)]:  Current provisioning state: '$provisioningState'. Sleep 15 seconds..." -verbose
      }
    }
  } While ($bWait -eq $true)
  #Output provisioning state
  Switch ($provisioningState) {
    'running' { Write-Warining "[$(GetCurrentUTCString)]: The deployment '$DeploymentName' is still running. please manually monitor the state since it has passed the maximum wait time of $MaximumWaitMinutes minutes." }
    'succeeded' { Write-Verbose "[$(GetCurrentUTCString)]: The deployment '$DeploymentName' has finished successfully." -verbose }
    'failed' {
      Write-verbose "[$(GetCurrentUTCString)]: The deployment '$DeploymentName' has failed. Error Code: $($deployment.properties.error.code), Error Message: $($deployment.properties.error.message)" -verbose
      Foreach ($Detail in $deployment.properties.error.details) {
        Write-Warning "$Detail.message"
      }
    }
    Default { Write-verbose "[$(GetCurrentUTCString)]: The deployment '$DeploymentName' provisioning state: '$provisioningState'" -verbose }
  }
  $deployment
}
function buildDeploymentUri {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true, ParameterSetName = 'tenant')]
    [parameter(Mandatory = $true, ParameterSetName = 'managementGroup')]
    [parameter(Mandatory = $true, ParameterSetName = 'subscription')]
    [parameter(Mandatory = $true, ParameterSetName = 'resourceGroup')]
    [ValidateScript({ $_ -imatch '^[-\w\._\(\)]+$' })]
    [string]$deploymentName,

    [parameter(Mandatory = $false, ParameterSetName = 'tenant')]
    [parameter(Mandatory = $false, ParameterSetName = 'managementGroup')]
    [parameter(Mandatory = $false, ParameterSetName = 'subscription')]
    [parameter(Mandatory = $false, ParameterSetName = 'resourceGroup')]
    [ValidateScript({ $_ -imatch '^\d{4}-\d{2}-\d{2}(-preview)?$' })]
    [string]$apiVersion = '2024-03-01',

    [parameter(Mandatory = $true, ParameterSetName = 'managementGroup')]
    [ValidateNotNull()]
    [string]$managementGroupName,

    [parameter(Mandatory = $true, ParameterSetName = 'subscription')]
    [parameter(Mandatory = $true, ParameterSetName = 'resourceGroup')]
    [ValidateScript({
        try {
          [System.Guid]::Parse($_) | Out-Null
          $true
        } catch {
          $false
        }
      })]
    [string]$subscriptionId,

    [parameter(Mandatory = $true, ParameterSetName = 'resourceGroup')]
    [ValidateNotNull()]
    [string]$resourceGroupName
  )
  $deploymentUriPrefix = 'https://management.azure.com/'
  if ($PSCmdlet.ParameterSetName -eq 'tenant') {
    Write-Verbose "[$(GetCurrentUTCString)]: Tenant scope deployment" -verbose
    $deploymentUri = "{0}providers/Microsoft.Resources/deployments/{1}?api-version={2}" -f $deploymentUriPrefix, $deploymentName, $apiVersion
  }
  if ($PSCmdlet.ParameterSetName -eq 'managementGroup') {
    Write-Verbose "[$(GetCurrentUTCString)]: Management Group scope deployment" -verbose
    $deploymentUri = "{0}providers/Microsoft.Management/managementGroups/{1}/providers/Microsoft.Resources/deployments/{2}?api-version={3}" -f $deploymentUriPrefix, $managementGroupName, $deploymentName, $apiVersion
  }
  if ($PSCmdlet.ParameterSetName -eq 'subscription') {
    Write-Verbose "[$(GetCurrentUTCString)]: Subscription scope deployment" -Verbose
    $deploymentUri = "{0}subscriptions/{1}/providers/Microsoft.Resources/deployments/{2}?api-version={3}" -f $deploymentUriPrefix, $subscriptionId, $deploymentName, $apiVersion
  }
  if ($PSCmdlet.ParameterSetName -eq 'resourceGroup') {
    Write-Verbose "[$(GetCurrentUTCString)]: Resource Group scope deployment" -Verbose
    $deploymentUri = "{0}subscriptions/{1}/resourcegroups/{2}/providers/Microsoft.Resources/deployments/{3}?api-version={4}" -f $deploymentUriPrefix, $subscriptionId, $resourceGroupName, $deploymentName, $apiVersion
  }
  Write-Verbose "[$(GetCurrentUTCString)]: Deployment Uri: '$deploymentUri" -verbose
  $deploymentUri
}
function CreateAzDeployment {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [validateSet('resourceGroup', 'subscription', 'managementGroup', 'tenant')]
    [string]$templateScope,

    [parameter(Mandatory = $true)]
    [string]$deploymentName,

    [parameter(Mandatory = $false)]
    [string]$managementGroupName = '',

    [parameter(Mandatory = $false)]
    [string]$subscriptionId = '',

    [parameter(Mandatory = $false)]
    [string]$resourceGroupName = '',

    [parameter(Mandatory = $true)]
    [string]$azureLocation,

    [parameter(Mandatory = $true)]
    [string]$retryFailedDeployment,

    [parameter(Mandatory = $true)]
    [int]$httpTimeoutSeconds,

    [Parameter(Mandatory = $true)]
    [int]$maxWaitMinutes,

    [parameter(Mandatory = $false)]
    [int]$retryDelayInSeconds = 60,

    [parameter(Mandatory = $true)]
    [string]$templateFilePath,

    [parameter(Mandatory = $false)]
    [string]$parameterFilePath
  )
  #create deployment
  $deploymentAttempt = 1
  $initialDeploymentName = "$deploymentName`-$deploymentAttempt"
  $deployParams = @{
    templateFilePath   = $templateFilePath
    maxWaitMinutes     = $maxWaitMinutes
    httpTimeoutSeconds = $httpTimeoutSeconds
  }
  if ($parameterFilePath.length -gt 0) {
    $deployParams.Add('parameterFilePath', $parameterFilePath)
  }
  Write-Verbose "Creating $templateScope level Deployment." -verbose

  try {
    switch ($templateScope) {
      'tenant' {
        $uri = buildDeploymentUri -deploymentName $initialDeploymentName
        $deployParams.Add('location', $azureLocation)
      }
      'managementGroup' {
        $uri = buildDeploymentUri -deploymentName $initialDeploymentName -managementGroupName $managementGroupName
        $deployParams.Add('location', $azureLocation)
      }
      'subscription' {
        $uri = buildDeploymentUri -deploymentName $initialDeploymentName -subscriptionId $subscriptionId
        $deployParams.Add('location', $azureLocation)
      }
      'resourceGroup' {
        $uri = buildDeploymentUri -deploymentName $initialDeploymentName -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName
      }
    }
    Write-Verbose "Deployment REST URI: '$uri'" -Verbose
    $deployParams.Add('uri', $uri)
    $initialDeployment = newAzDeploymentREST @deployParams
    Write-Verbose "Initial Deployment provisioning state: $($initialDeployment.properties.provisioningState)" -Verbose
  } catch {
    Write-Verbose "$templateScope level Deployment failed. Error:" -Verbose
    Write-Verbose $Error[0] -Verbose
  }
  if ($retryFailedDeployment -ieq 'true') {
    If ($initialDeployment.properties.provisioningState -ieq 'failed') {
      Write-Verbose "Wait $retryDelayInSeconds seconds before retrying failed deployment..." -verbose
      $DeploymentAttempt++
      $retryDeploymentName = "$deploymentName`-$deploymentAttempt"
      switch ($templateScope) {
        'tenant' {
          $retryUri = buildDeploymentUri -deploymentName $retryDeploymentName
        }
        'managementGroup' {
          $retryUri = buildDeploymentUri -deploymentName $retryDeploymentName -managementGroupName $managementGroupName
        }
        'subscription' {
          $retryUri = buildDeploymentUri -deploymentName $retryDeploymentName -subscriptionId $subscriptionId
        }
        'resourceGroup' {
          $retryUri = buildDeploymentUri -deploymentName $retryDeploymentName -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName
        }
      }
      #update URI in deployment parameters
      $deployParams.uri = $retryUri
      Start-Sleep -Seconds $retryDelayInSeconds
      $deploy = newAzDeploymentREST @deployParams

    } else {
      Write-Verbose "Retry skipped. The initial deployment status is '$($InitialDeployment.properties.provisioningState)'. Retry will only be initiated when the initial deployment has failed." -verbose
      If ($initialDeployment.properties.provisioningState -ine 'Succeeded') {
        throw "The initial deployment did not succeed. It's status is '$($InitialDeployment.properties.provisioningState)'. Please check detailed $templateScope level deployment status on the Azure portal. Deployment name: '$($deploymentParameters.name)'"
      } else {
        # Set $deploy variable to $InitialDeployment so the deployment output can be exported
        $deploy = $initialDeployment
      }
    }
  } else {
    Write-verbose "Retry failed deployment is disabled. The initial deployment status is '$($InitialDeployment.properties.provisioningState)'." -verbose
    throw $_
  }

  $deploy
}
#endregion
#region main
$outputFile = $env:GITHUB_OUTPUT
Write-Output "[$(GetCurrentUTCString)]: Deploying Bicep Template using ARM Deployment REST API."
if ($bicepModuleSubscriptionId -ne '') {
  Write-Output "[$(GetCurrentUTCString)]: Set Az Context to the bicep module subscription '$bicepModuleSubscriptionId'."
  set-AzContext -subscriptionId $bicepModuleSubscriptionId
}
$randomString = -join ((65..90) + (97..122) | Get-Random -Count 5 | % { [char]$_ })
$deploymentName = "$($templateName)-$($randomString)-$($uniqueBuildIdPrefix)$($BuildNumber)"
$deploymentAttempt = 1
$templateFile = join-path -path $workspaceDirectory -Childpath $templateFileDirectory -AdditionalChildPath $templateFileName
If (!(Test-Path $templateFile)) {
  Write-Output "[$(GetCurrentUTCString)]: Template File '$templateFile' not found"
  Exit 1
} else {
  Write-Output "[$(GetCurrentUTCString)]: Template File: $templateFile"
}

Write-Output "[$(GetCurrentUTCString)]: $templateScope Level Deployment. Template file: '$templateFile'"
Write-Output "[$(GetCurrentUTCString)]: Deployment Name: '$deploymentName'"

$params = @{
  TemplateScope         = $templateScope
  deploymentName        = $deploymentName
  retryFailedDeployment = $retryFailedDeployment
  maxWaitMinutes        = $maxWaitMinutes
  retryDelayInSeconds   = $retryDelayInSeconds
  httpTimeoutSeconds    = $httpTimeoutSeconds
  azureLocation         = $azureLocation
  templateFilePath      = $templateFile
}
#Determine which parameter file to use
if ($parameterFileName -ine '') {
  If ( $parameterFileArtifactName -ne "") {
    $ParameterFileLocation = join-path -path $workspaceDirectory -Childpath $parameterFileDirectory -AdditionalChildPath $parameterFileArtifactName, $parameterFileName
    Write-Output "[$(GetCurrentUTCString)]: Deploying with Parameter File '$ParameterFileLocation' from Build Artifact..."
  } else {
    $ParameterFileLocation = join-path -path $workspaceDirectory -ChildPath $parameterFileDirectory -AdditionalChildPath $parameterFileName
    Write-Output "[$(GetCurrentUTCString)]: Deploying with Parameter File '$ParameterFileLocation' from Git repository..."
  }
  #Check if parameter file exists
  if (Test-Path $ParameterFileLocation) {
    Write-Output "[$(GetCurrentUTCString)]: Deploying with Parameter File '$ParameterFileLocation'..."
    $params.Add('parameterFilePath', $ParameterFileLocation)
  } else {
    $ParameterFileLocation = $null
    If ( $parameterFileArtifactName -ne "") {
      Throw "[$(GetCurrentUTCString)]: Parameter File Artifact '$parameterFileArtifactName' not found"
      Exit 1
    }
  }
} else {
  Write-Output "[$(GetCurrentUTCString)]: No Parameter File specified. Template will be deployed without a parameter file"
}

if ($subscriptionName.length -gt 0) {
  #Get subscription Id
  $sub = Get-AzSubscription -SubscriptionName $subscriptionName | where-object { $_.state -ieq 'enabled' }
  $subscriptionId = $sub.Id
}
Switch ($templateScope) {
  'tenant' {
    #nothing to add
  }
  'managementGroup' {
    $params.add('managementGroupName', $targetName)
  }
  'subscription' {
    $params.add('subscriptionId', $subscriptionId)
  }
  'resourceGroup' {
    $params.add('subscriptionId', $subscriptionId)
    $params.add('ResourceGroupName', $targetName)
  }
}

$deploy = CreateAzDeployment @params

#Process deployment outputs
$deploymentOutputPublished = $false
$deploymentOutputs = $deploy.properties.outputs | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii'
if ($deploymentOutputs) {
  Write-Output "Deployment Outputs: $deploymentOutputs"
  if ($publishDeploymentOutputs -eq 'true') {
    Write-Output "[$(GetCurrentUTCString)]: Saving Deployment Outputs..."

    #Save deployment output to File
    $deploymentOutputDir = "$workspaceDirectory\$templateFileDirectory\Outputs"
    $deploymentOutputFileName = "$($templateName)-Outputs.json"
    $deploymentOutputFilePath = $(Join-path $deploymentOutputDir $deploymentOutputFileName)

    Write-Output "[$(GetCurrentUTCString)]: Creating Output Directory '$deploymentOutputDir'"
    New-Item -Path $deploymentOutputDir -ItemType Directory | Out-Null
    Write-Output "[$(GetCurrentUTCString)]: Saving Deployment Outputs to $deploymentOutputFilePath"
    $deploymentOutputs | Out-File -FilePath $deploymentOutputFilePath

    #Save deployed bicep template and parameter files to the output directory
    Write-Output "[$(GetCurrentUTCString)]: Saving deployed bicep template to the output directory '$deploymentOutputDir'."
    Copy-item -Path $templateFile -Destination $deploymentOutputDir
    if ($ParameterFileLocation) {
      Write-Output "[$(GetCurrentUTCString)]: Saving deployed parameter file to the output directory '$deploymentOutputDir'."
      Copy-item -Path $ParameterFileLocation -Destination $deploymentOutputDir
    }
    $deploymentOutputPublished = $true

    #create pipeline variables for deployment name (this will be used in the next stage to publish deployment output)
    Write-Output "deploymentName=$deploymentName" >> $outputFile
  } else {
    Write-Output "[$(GetCurrentUTCString)]: Deployment outputs are not required to be published"
  }

  if ($deploymentOutputVariablePrefix.Length -gt 0) {
    foreach ($key in $($deploy.outputs.keys)) {
      $pipelineVariableName = "$deploymentOutputVariablePrefix`_$key"
      $pipelineVariableValue = $deploy.outputs.$key.value
      Write-Output "[$(GetCurrentUTCString)]: Creating pipeline variable '$pipelineVariableName' with value '$pipelineVariableValue'."
      Write-Output "$pipelineVariableName=$pipelineVariableValue" >> $outputFile
    }
  } else {
    Write-Output "[$(GetCurrentUTCString)]: Pipeline variables are not required to be created for each deployment output."
  }
} else {
  Write-Output "[$(GetCurrentUTCString)]: No Deployment Outputs found."
}
Write-Output "deploymentOutputPublished=$deploymentOutputPublished" >> $outputFile

#process deployment result
if ($deploy.properties.provisioningState -ieq 'succeeded') {
  Write-Output "[$(GetCurrentUTCString)]: Deployment Succeeded."
  Exit 0
} else {
  throw "[$(GetCurrentUTCString)]: Deployment Failed. Provisioning State: $($deploy.properties.provisioningState)"
  Exit 1
}
#endregion

