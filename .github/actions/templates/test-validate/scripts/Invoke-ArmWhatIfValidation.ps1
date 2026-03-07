<#
==================================================================================
AUTHOR: Tao Yang
DATE: 27/02/2025
NAME: Invoke-ArmWhatIfValidation.ps1
VERSION: 1.1.0
COMMENT: Function to invoke the ARM deployment what-if REST API (GitHub Actions version)
==================================================================================
#>

#function to invoke the deployment what-if REST API
function getArmDeploymentWhatIfResult {
  [CmdletBinding(positionalbinding = $false)]
  [OutputType([object])]
  param (
    [parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$templateFilePath,

    [parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$parameterFilePath,

    [parameter(Mandatory = $false, HelpMessage = 'The deployment target resource Id. Leave it blank if the deployment scope is at the tenant level.')]
    [string]$deploymentTargetResourceId = '',

    [parameter(Mandatory = $false)]
    [ValidateSet('FullResourcePayloads', 'ResourceIdOnly')]
    [string]$resultFormat = 'FullResourcePayloads',

    [parameter(Mandatory = $false, helpMessage = 'The subscription Id for the private Bicep Registry or Template Specs. This is required if the template file is consuming modules from a private registry or template specs.')]
    [string]$bicepModuleSubscriptionId = '',

    [parameter(Mandatory = $false)]
    [ValidateRange(100, 1000)]
    [int]$httpTimeoutSeconds = 300,

    [parameter(Mandatory = $false)]
    [ValidateRange(300, 1000)]
    [int]$longRunningJobTimeoutSeconds = 300,

    [parameter(Mandatory = $false)]
    [ValidateRange(3, 10)]
    [int]$maxRetry = 3,

    [parameter(Mandatory = $false)]
    [string]$azureLocation = 'australiaeast'
  )
  $WarningPreference = 'SilentlyContinue'
  Write-Verbose "[$(getCurrentUTCString)]: What-If validation for Bicep Template using ARM Deployment What-If REST API." -Verbose
  if ($bicepModuleSubscriptionId -ne '') {
    Write-Verbose "[$(getCurrentUTCString)]: Set Az Context to the bicep module subscription '$bicepModuleSubscriptionId'."
    Set-AzContext -SubscriptionId $bicepModuleSubscriptionId | Out-Null
  }
  #Process template file
  Write-Verbose "[$(getCurrentUTCString)]: Process template file '$templateFilePath'" -Verbose
  $templateFileItem = Get-Item $templateFilePath
  Write-Verbose "[$(getCurrentUTCString)]: TemplateFilePath: '$($templateFileItem.FullName)'" -Verbose
  if ($templateFileItem.Extension -ieq '.bicep') {
    Write-Verbose "[$(getCurrentUTCString)]: '$templateFilePath' is a bicep file. Convert to Json" -Verbose
    $templateFileContent = Invoke-Expression "bicep build $templateFilePath --stdout | ConvertFrom-Json -Depth 99"
  } elseif ($templateFileItem.Extension -ieq '.json') {
    Write-Verbose "[$(getCurrentUTCString)]: '$templateFilePath' is a json file. Get the content" -Verbose
    $templateFileContent = Get-Content -Path $templateFilePath -Raw | ConvertFrom-Json -Depth 99
  } else {
    Throw "Template File '$templateFilePath' must be either a .json or .bicep file."
  }
  $deploymentScope = getTemplateScope -templateFileContent $templateFileContent
  $defaultRetryAfterSeconds = 15
  Write-Verbose "[$(getCurrentUTCString)]: $deploymentScope Level Deployment. Template file: '$templateFilePath'" -Verbose

  $body = @{
    properties = @{
      mode           = 'Incremental'
      whatIfSettings = @{
        resultFormat = $resultFormat
      }
      template       = $templateFileContent
    }
  }
  #Add location to the request body if the deployment scope is not resource group
  if ($deploymentScope -ine 'resourcegroup') {
    $body.add('location', $azureLocation)
  }

  #Process parameter file
  If ($parameterFilePath) {
    Write-Verbose "[$(getCurrentUTCString)]: ParameterFilePath: '$parameterFilePath'" -Verbose
    $parameterFile = Get-Item $parameterFilePath
    if ($parameterFile.Extension -ieq '.bicepparam') {
      Write-Verbose "'$parameterFilePath' is a bicep parameter file. Convert to Json" -Verbose
      $parameterFileContent = Invoke-Expression "bicep build-params '$parameterFilePath' --stdout"
    } elseif ($parameterFile.Extension -ieq '.json') {
      Write-Verbose "[$(getCurrentUTCString)]: '$parameterFilePath' is a json parameter file." -Verbose
      $parameterFileContent = Get-Content -Path $parameterFilePath -Raw
    }
    #Read parameters from parameter file
    $parameters = (ConvertFrom-Json $parameterFileContent -Depth 99).parameters
    $body.properties.Add('parameters', $parameters)
  }

  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
  }
  $bodyJson = $body | ConvertTo-Json -Depth 99 -EscapeHandling 'EscapeNonAscii'
  #Create what-if deployment and retry if failed
  $retryCount = 0
  $whatIfSuccessful = $false
  Do {
    try {
      $retryCount++
      Write-Verbose "[$(getCurrentUTCString)]: Attempt $retryCount/$maxRetry`: What-If Template validation." -Verbose
      $whatIfDeploymentUri = buildWhatIfDeploymentUri -deploymentTargetResourceId $deploymentTargetResourceId
      Write-Verbose "[$(getCurrentUTCString)]: What-If Deployment URI: '$whatIfDeploymentUri'" -Verbose
      Write-Verbose "[$(getCurrentUTCString)]: Create What-If deployment via URL '$whatIfDeploymentUri'..." -Verbose
      #What-If API reference: https://learn.microsoft.com/en-us/rest/api/resources/deployments/what-if?view=rest-resources-2021-04-01&tabs=HTTP

      $request = Invoke-WebRequest -Uri $whatIfDeploymentUri -Headers $headers -Method 'POST' -Body $bodyJson -ConnectionTimeoutSeconds $httpTimeoutSeconds -ContentType 'application/json'
      if ($request.StatusCode -eq 200) {
        $whatIfSuccessful = $true
        Write-Verbose "[$(getCurrentUTCString)]: What-If deployment completed successfully. No need to wait for long-running operations." -Verbose
        $result = $request.Content | ConvertFrom-Json -Depth 99
      } elseif ($request.StatusCode -eq 202) {
        Write-Verbose "[$(getCurrentUTCString)]: What-If deployment accepted. Will retrieve results by polling the long-running job..." -Verbose
        $responseHeaders = $request.Headers | ConvertTo-Json -Depth 99 -Compress
        Write-Verbose "[$(getCurrentUTCString)]: Initial response headers: $responseHeaders" -Verbose
        $longRunningOperationUrl = $request.Headers.Location[0]
        $retryAfterSeconds = [int]$request.Headers.'Retry-After'[0]
        $shouldWait = $true
        $waitStartTime = Get-Date
        Do {
          Write-Verbose "[$(getCurrentUTCString)]: What-If long running job URL: $longRunningOperationUrl" -Verbose
          if ($retryAfterSeconds) {
            Write-Verbose "[$(getCurrentUTCString)]: Retry-After header found from initial HTTP response. Will retry after $retryAfterSeconds seconds." -Verbose
            Start-Sleep -Seconds $retryAfterSeconds
          } else {
            Write-Verbose "[$(getCurrentUTCString)]: Retry-After header not found from initial HTTP response. Will retry after $defaultRetryAfterSeconds seconds." -Verbose
            Start-Sleep -Seconds $defaultRetryAfterSeconds
          }
          $longRunningJobResult = Invoke-WebRequest -Uri $longRunningOperationUrl -Headers $headers -Method Get -ConnectionTimeoutSeconds $httpTimeoutSeconds -ErrorVariable longRunningJobError
          if (!$longRunningJobError) {
            Write-Verbose "[$(getCurrentUTCString)]: Long running job status: $($longRunningJobResult.StatusCode)" -Verbose
            $now = Get-Date
            if ($longRunningJobResult.StatusCode -eq 200 -or ($now - $waitStartTime).TotalSeconds -gt $longRunningJobTimeoutSeconds) {
              $shouldWait = $false
              if ($longRunningJobResult.StatusCode -eq 200) {
                Write-Verbose "[$(getCurrentUTCString)]: Long running job completed." -Verbose
                $result = $longRunningJobResult.Content | ConvertFrom-Json -Depth 99
                $whatIfSuccessful = $true
              } else {
                Throw "[$(getCurrentUTCString)]: Long Running Job did not complete within the timeout period. Status Code: $($result.StatusCode)"
              }
            }
          }
        } until (!$shouldWait)
      } else {
        Write-Verbose "[$(getCurrentUTCString)]: Failed to create what-if deployment. HTTP response status code: $($request.StatusCode)" -Verbose
      }
    } Catch {
      $statusCodeDescription = $_.Exception.Response.StatusCode
      $statusCode = [int]$statusCodeDescription
      Write-Verbose "[$(getCurrentUTCString)]: Error occurred while creating the what-if deployment."
      Write-Verbose "[$(getCurrentUTCString)]: HTTP response status code: $statusCode - $statusCodeDescription " -Verbose
      Write-Verbose "[$(getCurrentUTCString)]: Error: $_" -Verbose
      if ($retryCount -le $maxRetry) {
        Write-Verbose "[$(getCurrentUTCString)]: Will retry in $defaultRetryAfterSeconds seconds." -Verbose
        Start-Sleep -Seconds $defaultRetryAfterSeconds
      } else {
        Write-Verbose "[$(getCurrentUTCString)]: Max retry count reached. Will not retry." -Verbose
      }
    }

  } until ($retryCount -ge $maxRetry -or $whatIfSuccessful -eq $true)
  if ($result) {
    $result
  } else {
    Write-Error "[$(getCurrentUTCString)]: Failed to create the what-if deployment after $maxRetry retries."
    exit -1
  }
}

#function to build the what-if deployment uri
function buildWhatIfDeploymentUri {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [parameter(Mandatory = $false)]
    [ValidateScript({ $_ -imatch '^\d{4}-\d{2}-\d{2}(-preview)?$' })]
    [string]$apiVersion = '2024-11-01',

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string]$deploymentTargetResourceId
  )
  $deploymentName = "{0}{1}" -f $( -join ((97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })), $(Get-Random -Minimum 100 -Maximum 999)
  $deploymentUri = 'https://management.azure.com{0}/providers/Microsoft.Resources/deployments/{1}/whatIf?api-version={2}' -f $deploymentTargetResourceId, $deploymentName, $apiVersion
  $deploymentUri
}

#function to detect the template scope based on the schema defined in the ARM template
Function getTemplateScope {
  [CmdletBinding()]
  [OutputType([string])]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the template File content.')]
    [object]$templateFileContent
  )

  $schema = $templateFileContent.'$schema'
  Write-Verbose "Arm template Schema: $schema" -Verbose
  switch ($($schema -split ('/'))[-1].tolower()) {
    $('subscriptiondeploymenttemplate.json#') {
      $scope = 'subscription'
    }
    $('managementgroupdeploymenttemplate.json#') {
      $scope = 'managementGroup'
    }
    $('deploymenttemplate.json#') {
      $scope = 'resourceGroup'
    }
    $('tenantdeploymenttemplate.json#') {
      $scope = 'tenant'
    }
    default {
      Write-Error "Invalid template scope"
      exit -1
    }
  }
  $scope
}

#function to get the current UTC time
function getCurrentUTCString {
  "$([DateTime]::UtcNow.ToString('u')) UTC"
}
