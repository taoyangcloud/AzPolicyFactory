function Get-GitRoot {
  $gitRootDir = Invoke-expression 'git rev-parse --show-toplevel 2>&1' -ErrorAction SilentlyContinue
  if (Test-Path $gitRootDir) {
    Convert-Path $gitRootDir
  }
}

#function detect if the script is running in an Azure DevOps pipeline or GitHub Actions
Function getPipelineType {
  if ($env:ADOORGNAME) {
    "Azure DevOps"
  } elseif ($env:GITHUB_ACTIONS) {
    "GitHub Actions"
  } else {
    "Local"
  }
}
Function Get-GitRelativeFilePath {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [String]$path
  )
  #Try to get git root directory
  if ((Get-Item $path -Force).PSIsContainer) {
    $gitRoot = Get-GitRoot -path $path
  } else {
    $gitRoot = Get-GitRoot -path (Get-Item $path -Force).Directory
  }
  if ($gitRoot) {
    $relativePath = Resolve-Path -Path $path -RelativeBasePath $gitRoot -Relative
  } else {
    $relativePath = $path
  }
  $relativePath
}
function convertBicepToArm {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the Bicep file path.')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })][string]$BicepFilePath
  )
  $armTemplate = invoke-expression "bicep build $bicepFilePath --stdout | ConvertFrom-Json -depth 99" -ErrorVariable bicepBuildError -ErrorAction SilentlyContinue

  if ($bicepBuildError) {
    Throw "Failed to convert the bicep file to ARM template. Error: $($bicepBuildError.Exception.Message)"
    exit -1
  }

  $armTemplate
}

#this function validates the bicep file for the Bicep templates used by Policy Integration tests
function validateBicep {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the Bicep file path.')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })][string]$BicepFilePath
  )
  $bIsValid = $true
  $armTemplate = convertBicepToArm -BicepFilePath $BicepFilePath


  # template must not have parameters
  if ($armTemplate.psobject.properties.name -contains 'parameters') {
    foreach ($p in $(Get-member -InputObject $armTemplate.parameters -MemberType NoteProperty).name) {
      If ($(get-member -inputobject $armTemplate.parameters.$p -MemberType NoteProperty).name -inotcontains 'defaultvalue') {
        Write-Error "The template should have default value for the parameter '$(($p | get-member -membertype NoteProperty)[0].name)'"
        $bIsValid = $false
      }
    }
  } else {
    Write-Verbose "The template does not have parameters" -Verbose
  }

  #template must have name and resourceId output

  if ($armTemplate.psobject.properties.name -notcontains 'outputs') {
    Write-Error "The template should have outputs"
    $bIsValid = $false
  } else {
    Write-Verbose "The template contains outputs" -Verbose
  }

  if ($armTemplate.outputs.psobject.properties.name -notcontains 'name') {
    Write-Error "The template should have name output"
    $bIsValid = $false
  } else {
    Write-Verbose "The template contains name output" -Verbose
  }

  if ($armTemplate.outputs.psobject.properties.name -notcontains 'resourceId') {
    Write-Error "The template should have resourceId output"
    $bIsValid = $false
  } else {
    Write-Verbose "The template contains resourceId output" -Verbose
  }

  if ($bIsValid) {
    Write-Verbose "The template is valid." -Verbose
  } else {
    Write-Error "The template is invalid."
  }
  $bIsValid

}

Function getTestConfig {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the test config file path.')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })][string]$TestConfigFilePath
  )

  $testConfig = Get-Content $TestConfigFilePath | ConvertFrom-Json
  $testConfig
}

Function getTemplateScope {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the Bicep file path.')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })][string]$BicepFilePath
  )

  $armTemplate = convertBicepToArm -BicepFilePath $BicepFilePath
  $schema = $armTemplate.'$schema'
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

function getCurrentUTCString {
  "$([DateTime]::UtcNow.ToString('u')) UTC"
}

function updateAzResourceTags {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the resource Id.')]
    [ValidateNotNullOrEmpty()][string]$resourceId,

    [Parameter(Mandatory = $true, HelpMessage = 'Specify the new resource tags.')]
    [hashtable]$tags,

    [Parameter(Mandatory = $false, HelpMessage = 'Set to true to revert the tags back to what it was after the update.')]
    [bool]$revertBack = $false
  )
  $uri = 'https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/tags/default?api-version=2021-04-01' -f $testSubscriptionId
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
  }
  $body = @{
    properties = @{
      tags = $tags
    }
  } | ConvertTo-Json -Depth 10
  if ($revertBack) {
    Write-Verbose "Get Existing tags before setting new tags for resource '$resourceId'."
    try {
      $existingTagsResponse = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers
      $existingTags = ($existingTagsResponse.content | ConvertFrom-Json -depth 5 -AsHashtable).properties.tags
      Write-Verbose "Existing Tags are:" -Verbose
      Write-Verbose $($existingTags | ConvertTo-Json) -verbose
    } Catch {
      Throw $_.Exception
    }
  }
  Write-Verbose "Updating tags for resource '$resourceId'. New Tags:" -Verbose
  Write-Verbose $tags -Verbose
  try {
    $response = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body $body -SkipHttpErrorCheck
  } catch {
    Throw $_.Exception
  }
  if ($revertBack) {
    Write-Verbose "Revert tags back for resource '$resourceId'. Old Tags." -Verbose
    $revertBackBody = @{
      properties = @{
        tags = $existingTags
      }
    } | ConvertTo-Json -Depth 10
    try {
      $revertBackResponse = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body $revertBackBody
    } Catch {
      Throw $_.Exception
    }
  }
  Write-Verbose "Tag Update response status code: $($response.StatusCode)" -Verbose
  Write-Verbose "Tag Update response content: '$($response.content)" -verbose
  $response
}

function getResourceViaARMAPI {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)][string]$resourceId,
    [Parameter(Mandatory = $true)][string]$apiVersion
  )
  $uri = "https://management.azure.com{0}?api-version={1}" -f $resourceId, $apiVersion
  Write-Verbose "[$(getCurrentUTCString)]: Trying getting resource via the Resource provider API endpoint '$uri'" -Verbose
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
  }
  try {
    $request = Invoke-WebRequest -Uri $uri -Method "GET" -Headers $headers
    if ($request.StatusCode -ge 200 -and $request.StatusCode -lt 300) {
      $resourceExists = $true
    }
  } catch {
    $resourceExists = $false
  }
  if ($resourceExists) {
    $resource = ($request.Content | ConvertFrom-Json -Depth 99)
  }
  $resource
}

function newResourceGroupViaARMAPI {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)][string]$subscriptionId,
    [Parameter(Mandatory = $true)][string]$resourceGroupName,
    [Parameter(Mandatory = $true)][string]$location,
    [Parameter(Mandatory = $false)][hashtable]$tags,
    [Parameter(Mandatory = $false)][string]$apiVersion = '2021-04-01'
  )
  $uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}?api-version={2}" -f $subscriptionId, $resourceGroupName, $apiVersion
  Write-Verbose "[$(getCurrentUTCString)]: Trying creating resource group via the Resource provider API endpoint '$uri'" -Verbose
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
  }
  $body = @{
    location = $location
  }
  if ($PSBoundParameters.ContainsKey('tags')) {
    $body.tags = $tags
  }
  $body = $body | ConvertTo-Json -Depth 10
  try {
    $request = Invoke-WebRequest -Uri $uri -Method "PUT" -Headers $headers -Body $body
    if ($request.StatusCode -ge 200 -and $request.StatusCode -lt 300) {
      $resourceGroupCreated = $true
    }
  } catch {
    Write-Error $_.Exception.Message
    $resourceGroupCreated = $false
  }
  if ($resourceGroupCreated) {
    Write-Verbose "Resource group '$resourceGroupName' created successfully." -Verbose
    $resourceGroupId = ($request.Content | ConvertFrom-Json -Depth 99).id
    $resourceGroupId
  } else {
    Write-Error "Failed to create resource group '$resourceGroupName'."
  }
}


#function to generate AES key and IV
function newAesKey {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param (
    [Parameter(Mandatory = $false)]
    [ValidateSet(128, 192, 256)]
    [int]$KeySize = 256,

    [Parameter(Mandatory = $false)]
    [string]$OutputFilePath
  )

  try {
    Write-Verbose "[$(getCurrentUTCString)]: Generating AES-$KeySize key and IV"

    # Create AES instance
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.KeySize = $KeySize
    $aes.GenerateKey()
    $aes.GenerateIV()

    # Create key object
    $keyObject = [PSCustomObject]@{
      Key     = [Convert]::ToBase64String($aes.Key)
      IV      = [Convert]::ToBase64String($aes.IV)
      KeySize = $KeySize
      Created = (Get-Date).ToUniversalTime().ToString('o')
    }

    # Save to file if path specified
    if ($OutputFilePath) {
      $keyJson = $keyObject | ConvertTo-Json
      [System.IO.File]::WriteAllText($OutputFilePath, $keyJson, [System.Text.Encoding]::UTF8)
      Write-Verbose "[$(getCurrentUTCString)]: AES key saved to: $OutputFilePath"
    }

    # Dispose of AES instance
    $aes.Dispose()

    return $keyObject
  } catch {
    Write-Error "[$(getCurrentUTCString)]: Failed to generate AES key: $_"
    throw
  }
}

#function to encrypt file or text using AES
function encryptStuff {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyFile')]
    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyDirect')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$InputFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyFile')]
    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyDirect')]
    [ValidateNotNullOrEmpty()]
    [string]$InputText,

    [Parameter(Mandatory = $false)]
    [string]$OutputFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyFile')]
    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyFile')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$KeyFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyDirect')]
    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyDirect')]
    [string]$AESKey,

    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyDirect')]
    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyDirect')]
    [string]$AESIV,

    [Parameter(Mandatory = $false)]
    [switch]$UseCompression
  )

  try {
    Write-Verbose "[$(getCurrentUTCString)]: Starting AES encryption"
    $startTime = [datetime]::UtcNow

    # Load key and IV
    if ($PSCmdlet.ParameterSetName -eq 'FileInKeyFile' -or $PSCmdlet.ParameterSetName -eq 'TextInKeyFile') {
      $KeyFullPath = (Resolve-Path -Path $KeyFilePath).path
      Write-Verbose "[$(getCurrentUTCString)]: Loading key from file: $KeyFullPath"
      $keyJson = [System.IO.File]::ReadAllText($KeyFullPath)
      $keyObject = $keyJson | ConvertFrom-Json
      $keyBytes = [Convert]::FromBase64String($keyObject.Key)
      $ivBytes = [Convert]::FromBase64String($keyObject.IV)
    } else {
      $keyBytes = [Convert]::FromBase64String($AESKey)
      $ivBytes = [Convert]::FromBase64String($AESIV)
    }

    # Read input data
    if ($InputFilePath) {
      $inputFileFullPath = (Resolve-Path -Path $InputFilePath).path
      Write-Verbose "[$(getCurrentUTCString)]: Reading input file: $inputFileFullPath"
      $inputBytes = [System.IO.File]::ReadAllBytes($inputFileFullPath)
    } else {
      $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
    }

    Write-Verbose "[$(getCurrentUTCString)]: Input size: $($inputBytes.Length) bytes"

    # Compress if requested
    if ($UseCompression) {
      Write-Verbose "[$(getCurrentUTCString)]: Compressing data"
      $memoryStream = New-Object System.IO.MemoryStream
      $gzipStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
      $gzipStream.Write($inputBytes, 0, $inputBytes.Length)
      $gzipStream.Close()
      $inputBytes = $memoryStream.ToArray()
      $memoryStream.Dispose()
      Write-Verbose "[$(getCurrentUTCString)]: Compressed size: $($inputBytes.Length) bytes"
    }

    # Create AES instance
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $keyBytes
    $aes.IV = $ivBytes
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    # Create encryptor
    $encryptor = $aes.CreateEncryptor()

    # Encrypt data
    Write-Verbose "[$(getCurrentUTCString)]: Encrypting data"
    $encryptedBytes = $encryptor.TransformFinalBlock($inputBytes, 0, $inputBytes.Length)

    # Create output object with metadata
    $outputObject = [PSCustomObject]@{
      Algorithm     = "AES-$($aes.KeySize)"
      Compressed    = $UseCompression.IsPresent
      OriginalSize  = if ($InputFilePath) { (Get-Item $InputFilePath).Length } else { $InputText.Length }
      EncryptedData = [Convert]::ToBase64String($encryptedBytes)
      EncryptedAt   = (Get-Date).ToUniversalTime().ToString('o')
    }
    $outputJson = $outputObject | ConvertTo-Json
    # Cleanup
    $encryptor.Dispose()
    $aes.Dispose()

    $endTime = [datetime]::UtcNow
    $timeTaken = New-TimeSpan -Start $startTime -End $endTime
    Write-Verbose "[$(getCurrentUTCString)]: AES encryption completed in $($timeTaken.TotalSeconds) seconds"

    if ($OutputFilePath) {
      # Save to file
      [System.IO.File]::WriteAllText($OutputFilePath, $outputJson, [System.Text.Encoding]::UTF8)
      Write-Verbose "[$(getCurrentUTCString)]: Encrypted file saved to: $OutputFilePath"
      return $OutputFilePath
    } else {
      # Return JSON string
      return $outputJson
    }
  } catch {
    Write-Error "[$(getCurrentUTCString)]: AES encryption failed: $_"
    throw
  } finally {
    if ($aes) { $aes.Dispose() }
    if ($encryptor) { $encryptor.Dispose() }
  }
}


#function to decrypt file using AES
function decryptStuff {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyFile')]
    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyDirect')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$InputFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyFile')]
    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyDirect')]
    [ValidateNotNullOrEmpty()]
    [string]$InputText,

    [Parameter(Mandatory = $false)]
    [string]$OutputFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyFile')]
    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyFile')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$KeyFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyDirect')]
    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyDirect')]
    [string]$AESKey,

    [Parameter(Mandatory = $true, ParameterSetName = 'FileInKeyDirect')]
    [Parameter(Mandatory = $true, ParameterSetName = 'TextInKeyDirect')]
    [string]$AESIV
  )

  try {
    Write-Verbose "[$(getCurrentUTCString)]: Starting AES decryption" -verbose
    $startTime = [datetime]::UtcNow

    # Load key and IV
    if ($PSCmdlet.ParameterSetName -eq 'FileInKeyFile' -or $PSCmdlet.ParameterSetName -eq 'TextInKeyFile') {
      $KeyFullPath = (Resolve-Path -Path $KeyFilePath).path
      Write-Verbose "[$(getCurrentUTCString)]: Loading key from file: $KeyFullPath"
      $keyJson = [System.IO.File]::ReadAllText($KeyFullPath)
      $keyObject = $keyJson | ConvertFrom-Json
      $keyBytes = [Convert]::FromBase64String($keyObject.Key)
      $ivBytes = [Convert]::FromBase64String($keyObject.IV)
    } else {
      $keyBytes = [Convert]::FromBase64String($AESKey)
      $ivBytes = [Convert]::FromBase64String($AESIV)
    }
    if ($InputFilePath) {
      # Read encrypted file
      Write-Verbose "[$(getCurrentUTCString)]: Reading encrypted file: $InputFilePath"
      $InputText = [System.IO.File]::ReadAllText($InputFilePath)
    }
    $encryptedObject = $InputText | ConvertFrom-Json

    # Extract encrypted data
    $encryptedBytes = [Convert]::FromBase64String($encryptedObject.EncryptedData)
    Write-Verbose "[$(getCurrentUTCString)]: Encrypted size: $($encryptedBytes.Length) bytes"
    Write-Verbose "[$(getCurrentUTCString)]: Algorithm: $($encryptedObject.Algorithm)"
    Write-Verbose "[$(getCurrentUTCString)]: Compressed: $($encryptedObject.Compressed)"

    # Create AES instance
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $keyBytes
    $aes.IV = $ivBytes
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    # Create decryptor
    $decryptor = $aes.CreateDecryptor()

    # Decrypt data
    Write-Verbose "[$(getCurrentUTCString)]: Decrypting data"
    $decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)

    # Decompress if needed
    if ($encryptedObject.Compressed) {
      Write-Verbose "[$(getCurrentUTCString)]: Decompressing data"
      $memoryStream = [System.IO.MemoryStream]::new($decryptedBytes)
      $gzipStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Decompress)
      $outputStream = New-Object System.IO.MemoryStream
      $gzipStream.CopyTo($outputStream)
      $decryptedBytes = $outputStream.ToArray()

      # Cleanup compression streams
      $gzipStream.Dispose()
      $memoryStream.Dispose()
      $outputStream.Dispose()
    }

    Write-Verbose "[$(getCurrentUTCString)]: Decrypted size: $($decryptedBytes.Length) bytes"

    # Output result
    if ($OutputFilePath) {
      [System.IO.File]::WriteAllBytes($OutputFilePath, $decryptedBytes)
      Write-Verbose "[$(getCurrentUTCString)]: Decrypted file saved to: $OutputFilePath"
      $result = $OutputFilePath

    } else {
      $result = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
    }

    # Cleanup
    $decryptor.Dispose()
    $aes.Dispose()

    $endTime = [datetime]::UtcNow
    $timeTaken = New-TimeSpan -Start $startTime -End $endTime
    Write-Verbose "[$(getCurrentUTCString)]: AES decryption completed in $($timeTaken.TotalSeconds) seconds"

    return $result
  } catch {
    Write-Error "[$(getCurrentUTCString)]: AES decryption failed: $_"
    throw
  } finally {
    if ($aes) { $aes.Dispose() }
    if ($decryptor) { $decryptor.Dispose() }
  }
}
