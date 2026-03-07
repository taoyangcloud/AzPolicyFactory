#Function to get the corresponding target scope from the other environment
function getTargetScopeMapping {
  [CmdletBinding()]
  [OutputType([String])]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('subscription', 'managementGroup', 'resourceGroup', IgnoreCase = $true)]
    [String]$type,

    [Parameter(Mandatory = $true)]
    [ValidateSet('development', 'production', IgnoreCase = $true)]
    [String]$from,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$name,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [Hashtable]$config
  )
  switch ($from) {
    'development' {
      $to = 'production'
    }
    'production' {
      $to = 'development'
    }
  }
  switch ($type) {
    'subscription' {
      $mapping = $config.targetScopeMapping.subscription
    }
    'managementGroup' {
      $mapping = $config.targetScopeMapping.managementGroup
    }
    'resourceGroup' {
      $mapping = $config.targetScopeMapping.resourceGroup
    }
  }
  foreach ($key in $mapping.keys) {
    $pair = $mapping.$key
    if ($pair.$from -ieq $name) {
      $mappedScope = $pair.$to
      break
    }
  }
  if (-not $mappedScope) {
    throw "No mapping found for $type $name from $from to $to"
    exit 1
  }
  $mappedScope
}

#function to get the deployment target scope from assignment configuration file's metadata
function getDeploymentTargetScopeFromConfigurationFile {
  [CmdletBinding()]
  [OutputType([String])]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [Hashtable]$fileContent
  )
  $deploymentTarget = $fileContent.managementGroupId
  if (-not $deploymentTarget) {
    throw "Unable to read deployment target scope from the configuration file"
    exit 1
  }
  $deploymentTarget
}

#function to validate if the policy definition id is a valid policy definition or initiative id using Regex
function isValidPolicyDefinitionId {
  [CmdletBinding()]
  [OutputType([Boolean])]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$policyDefinitionId
  )
  $validPolicyDefIdRegex = '^\/providers(\/Microsoft.Management\/managementGroups\/\S+\/providers)?\/Microsoft.Authorization\/(policySetDefinitions|policyDefinitions)\/\S+'
  $isValidPolicyDefinitionId = $policyDefinitionId -imatch $validPolicyDefIdRegex
  $isValidPolicyDefinitionId
}

#Function to read details of the policy definition from the assignment configuration file
function getDefinitionDetailsFromConfigurationFile {
  [CmdletBinding()]
  [OutputType([Hashtable])]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [Hashtable]$fileContent
  )
  $policyDefinitionId = $fileContent.policyAssignment.policyDefinitionId
  if ($fileContent.keys -contains 'definitionSourceManagementGroupId') {
    $definitionSourceManagementGroupId = $fileContent.definitionSourceManagementGroupId
  }
  if ($definitionSourceManagementGroupId.length -gt 0) {
    #extract definition source management group name from the id
    #$mgNameMatch = $definitionSourceManagementGroupId -imatch '^\/providers\/Microsoft.Management\/managementGroups\/(\S+)'
    $definitionSourceManagementGroupId -imatch '^\/providers\/Microsoft.Management\/managementGroups\/(\S+)' | out-null
    $definitionSourceManagementGroupName = $matches[1]
    #replace '{policyLocationResourceId}' from $policyDefinitionId
    $policyDefinitionId = $policyDefinitionId.replace('{policyLocationResourceId}', $definitionSourceManagementGroupId)
  }
  #validate $policyDefinitionId using Regex

  $isValidPolicyDefinitionId = isValidPolicyDefinitionId -policyDefinitionId $policyDefinitionId -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
  if (-not $isValidPolicyDefinitionId) {
    Throw "'$policyDefinitionId' is not a valid policy definition or initiative Id."
    exit 1
  }
  if ($policyDefinitionId -imatch '^\/providers\/Microsoft.Management\/managementGroups\/\S+\/providers') {
    #is custom definition
    $isCustom = $true
  } else {
    $isCustom = $false
  }
  #return a hashtable
  @{
    policyDefinitionId                  = $policyDefinitionId
    definitionSourceManagementGroupId   = $definitionSourceManagementGroupId
    definitionSourceManagementGroupName = $definitionSourceManagementGroupName
    isCustom                            = $isCustom
  }
}

#Construct the corresponding custom policy Definition Id for custom definitions for the other environment
function getMappedCustomPolicyDefinitionId {
  [CmdletBinding()]
  [OutputType([String])]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$customPolicyDefinitionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$mappedManagementGroup
  )

  $replaceMgInPolicyDefIdRegexPattern = '^\/providers\/Microsoft.Management\/managementGroups\/(\S+)\/providers\/'
  $mappedCustomPolicyDefinitionId = $customPolicyDefinitionId -replace $replaceMgInPolicyDefIdRegexPattern, "/providers/Microsoft.Management/managementGroups/$mappedManagementGroup/providers/"
  #Make sure the mapped custom policy definition id is valid
  $isValidPolicyDefinitionId = isValidPolicyDefinitionId -policyDefinitionId $mappedCustomPolicyDefinitionId -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
  if (-not $isValidPolicyDefinitionId) {
    Throw "'$mappedCustomPolicyDefinitionId' is not a valid policy definition or initiative Id."
    exit 1
  }
  $mappedCustomPolicyDefinitionId
}

#Function to read assignment configuration file
function readConfigurationFile {
  [CmdletBinding()]
  [OutputType([Hashtable])]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$filePath
  )
  #check file extension
  if ($filePath -match '\.json$') {
    $fileRawContent = Get-Content -Path $filePath -Raw
  } else {
    throw "Invalid file extension. Only .json files are supported."
    exit 1
  }
  $tempHashTable = $fileRawContent | ConvertFrom-Json -Depth 99 -AsHashtable
  #convert hashtable keys to case-insensitive (workaround from this github issue: https://github.com/PowerShell/PowerShell/issues/19928)
  $fileContent = [HashTable]::New($tempHashTable, [StringComparer]::OrdinalIgnoreCase)
  $fileContent
}

#function to search policy assignment configuration files in a folder based on the policy definition Id and assignment scope
function getPolicyAssignment {
  [CmdletBinding()]
  [OutputType([array])]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$policyDefinitionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$assignmentScope,

    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [array]$assignmentNotScopes = @(),

    [Parameter(Mandatory = $true)]
    [ValidateScript({ test-path -PathType Container $_ })]
    [string]$directory
  )
  Write-Verbose "    - Expected Assignment Scope: '$assignmentScope'"
  Write-Verbose "    - Expected Policy Definition Id: '$policyDefinitionId'"
  $assignments = @()
  #get all configuration files in the directory
  #only json files are supported.
  $files = Get-ChildItem -Path $directory -Recurse -Filter "*.json"
  Write-Verbose "    - Policy assignment configuration file count in the directory '$directory': $($files.count)" -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
  foreach ($file in $files) {
    Write-Verbose "    - Checking assignment configuration file $($file.name)" -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    $content = readConfigurationFile -filePath $file.FullName -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    $policyDefinitionDetails = getDefinitionDetailsFromConfigurationFile -fileContent $content -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    $targetMgName = $content.managementGroupId
    $notScopesFromAssignmentConfigurationFile = $content.policyAssignment.containsKey('notScopes') ? $content.policyAssignment.notScopes : @()
    #Compare notScopes
    if ($null -eq $(compare-object -ReferenceObject $assignmentNotScopes -DifferenceObject $notScopesFromAssignmentConfigurationFile)) {
      #Matching notScopes
      $matchNotScopes = $true
    } else {
      #notScopes don't match
      $matchNotScopes = $false
    }
    $targetMg = '/providers/Microsoft.Management/managementGroups/{0}' -f $content.metadata.targetManagementGroupName
    Write-Verbose "      - Target Management Group Name: '$targetMgName'" -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    Write-Verbose "      - Target Management Group ID: '$targetMg'" -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    $policyDefIdFromAssignmentConfigurationFile = $policyDefinitionDetails.policyDefinitionId
    Write-Verbose "      - Policy Definition Id from the assignment configuration file: '$policyDefIdFromAssignmentConfigurationFile'"
    if ($targetMgName -ieq $assignmentScope -and $policyDefIdFromAssignmentConfigurationFile -ieq $policyDefinitionId -and $matchNotScopes -eq $true) {
      Write-Verbose "  - Policy assignment found for policy definition Id '$policyDefinitionId' and target management group '$assignmentScope' in the parameter file '$($file.FullName)'" -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
      $assignments += [ordered]@{
        filePath                = $file.FullName
        fileName                = $file.Name
        fileContent             = $content
        policyDefinitionDetails = $policyDefinitionDetails
        targetManagementGroup   = $targetMg
      }
    }
  }
  Write-Verbose "      - Number of policy assignments found: $($assignments.count)" -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
  If ($assignments.Count -eq 0) {
    Write-Warning "No policy assignment found for policy definition Id '$policyDefinitionId' and target management group '$assignmentScope' in the directory '$directory'"
  }
  if ($assignments.Count -gt 1) {
    Write-Warning "Multiple policy assignments found for policy definition Id '$policyDefinitionId' and target management group '$assignmentScope' in the directory '$directory'"
  }
  , $assignments
}

#function to check if the string is a environment-specific Azure resource ID
Function isEnvironmentSpecificResourceId {
  [CmdletBinding()]
  [OutputType([Boolean])]
  Param (
    [Parameter(Mandatory = $false, Position = 0)]
    [AllowEmptyString()]
    [object[]]$value = ''
  )
  $mgResourceRegex = '(?i)^\/providers\/microsoft.management\/managementgroups\/(\S+)\/providers\/\S+'
  $subResourceRegex = '(?i)^\/subscriptions\/([0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12})\/resourcegroups\/(\S+)'
  $result = $true
  if ($value -eq $null -or $value.count -eq 0 -or $value -is [Hashtable]) {
    $result = $false
  } else {
    foreach ($v in $value) {
      Write-verbose "Checking if '$v' is an environment specific resource id." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
      if ($v -inotmatch $mgResourceRegex -and $v -inotmatch $subResourceRegex) {
        Write-Verbose "'$v' is not an environment specific resource Id" -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $result = $false
        break
      }
    }
  }
  $result
}

#function to get the corresponding environment specific value
Function getCorrespondingEnvironmentSpecificValues {
  [CmdletBinding()]
  [OutputType([array])]
  Param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [object]$config,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [object[]]$sourceValue,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$sourceEnvironment,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$correspondingEnvironment


  )
  $environmentSpecificValues = $config.environmentSpecificValues
  $strSourceValue = $sourceValue | convertTo-Json -Depth 100 -Compress
  $valueTypes = $environmentSpecificValues.keys
  $allFound = $true
  foreach ($valueType in $valueTypes) {
    $allFound = $true
    foreach ($s in $sourceValue) {
      if ($environmentSpecificValues.$valueType.$sourceEnvironment -inotcontains $s) {
        $allFound = $false
        break
      }
    }
    if ($allFound) {
      Write-Verbose "Found value '$strSourceValue' in 'environmentSpecificValues.$valueType.$sourceEnvironment'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
      #look for corresponding value in the corresponding environment
      $correspondingEnvironmentSpecificValues = $environmentSpecificValues.$valueType.$correspondingEnvironment
      break
    }
  }
  , $correspondingEnvironmentSpecificValues
}

#function to check if a list of strings exists in an array. Return true if all strings exist in the array
Function isStringsInArray {
  [CmdletBinding()]
  [OutputType([Boolean])]
  Param (
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [String[]]$valueToCheck = '',

    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [array]$sourceArray = @()
  )
  $result = $true
  foreach ($v in $valueToCheck) {
    if ($sourceArray -inotcontains $v) {
      $result = $false
      break
    }
  }
  $result
}
#Function to check if the generic (anything but a resource id) parameter value from the corresponding environment is valid
function isValidGenericParameterValue {
  [CmdletBinding()]
  [OutputType([Boolean])]
  Param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [object]$config,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$sourceAssignmentName,

    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [string]$sourceAssignmentScopeName,

    [Parameter(Mandatory = $true, Position = 3)]
    [ValidateNotNullOrEmpty()]
    [string]$parameterName,

    [Parameter(Mandatory = $false, Position = 4)]
    [AllowEmptyString()]
    [object[]]$sourceValue = '',

    [Parameter(Mandatory = $false, Position = 5)]
    [AllowEmptyString()]
    [object[]]$correspondingValue = ''
  )
  $isValid = $false
  $bViolateAllowedParameterValueDeviations = $false
  $strSourceValue = $sourceValue | ConvertTo-Json -Depth 99 -Compress
  $srtCorrespondingValue = $correspondingValue | ConvertTo-Json -Depth 99 -Compress
  #firstly check the allowed Parameter Value Deviations defined in the config file
  $allowedParameterValueDeviations = $config.allowedParameterValueDeviations
  Write-Verbose "Looking for allowed parameter value deviations for source assignment name '$sourceAssignmentName', source assignment scope name '$sourceAssignmentScopeName', parameter name '$parameterName'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
  foreach ($apd in $allowedParameterValueDeviations) {
    if ($apd.sourceAssignmentName -ieq $sourceAssignmentName -and $apd.sourceAssignmentScopeName -ieq $sourceAssignmentScopeName -and $apd.parameterName -icontains $parameterName) {
      Write-Verbose "Found allowed parameter value deviation for source assignment name '$sourceAssignmentName', source assignment scope name '$sourceAssignmentScopeName', parameter name '$parameterName'."
      $allowedSourceDeviationValues = $apd.sourceParameterValue
      $strAllowedSourceDeviationValues = $allowedSourceDeviationValues | ConvertTo-Json -Depth 99 -Compress
      $allowedCorrespondingDeviationValues = $apd.correspondingParameterValue
      $strAllowedCorrespondingDeviationValues = $allowedCorrespondingDeviationValues | ConvertTo-Json -Depth 99 -Compress

      if ($null -eq $($sourceValue | Compare-Object $allowedSourceDeviationValues)) {
        Write-Verbose "Source Value '$strSourceValue' is matching allowed parameter value deviations '$strAllowedSourceDeviationValues'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $bMatchedSourceDeviation = $true
      } else {
        Write-Verbose "Source Value '$strSourceValue' is not matching allowed parameter value deviations '$strAllowedSourceDeviationValues'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $bMatchedSourceDeviation = $false
      }
      if ($null -eq $($correspondingValue | Compare-Object $allowedCorrespondingDeviationValues)) {
        Write-Verbose "Corresponding Value '$srtCorrespondingValue' is matching allowed parameter value deviations '$strAllowedCorrespondingDeviationValues'."
        $bMatchedCorrespondingDeviation = $true
      } else {
        Write-Verbose "Corresponding Value '$srtCorrespondingValue' is not matching allowed parameter value deviations '$strAllowedCorrespondingDeviationValues'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $bMatchedCorrespondingDeviation = $false
      }
      if ($bMatchedSourceDeviation -and $bMatchedCorrespondingDeviation) {
        Write-Verbose "Both Source Value '$sourceValue' and Corresponding Value $correspondingValue are matching allowed parameter value deviations." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $isValid = $true
      } else {
        Write-Verbose "Source Value '$sourceValue' and Corresponding Value $correspondingValue are not matching allowed parameter value deviations." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $bViolateAllowedParameterValueDeviations = $true
      }
      break
    }
  }
  #Continue to check if the source and corresponding values are the same if the specific parameter value is not defined in the allowedParameterValueDeviations section of the config file.
  if (!$isValid -and !$bViolateAllowedParameterValueDeviations) {
    Write-Verbose "the parameter value is not defined in the allowedParameterValueDeviations section of the config file. Checking if the source and corresponding values are the same."
    #if the source and corresponding values are the same, then it's valid

    if ($null -eq $($sourceValue | compare-object $correspondingValue) ) {
      Write-Verbose "Source Value '$strSourceValue' and Corresponding Value $srtCorrespondingValue are the same." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
      $isValid = $true
    } else {
      Write-Verbose "Source Value '$strSourceValue' and Corresponding Value $srtCorrespondingValue are not the same. Checking interchangeable values." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    }

    if (!$isValid) {
      #check interchangeable values if the source and corresponding values are not the same
      $interchangeableParameterValues = $config.interchangeableParameterValues
      $valueTypes = $interchangeableParameterValues.keys
      foreach ($valueType in $valueTypes) {
        Write-Verbose "Checking 'interchangeableParameterValues.$valueType' for source value '$strSourceValue' and corresponding value '$srtCorrespondingValue'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        if ($(isStringsInArray -valueToCheck $sourceValue -sourceArray $interchangeableParameterValues.$valueType) -and $(isStringsInArray -valueToCheck $correspondingValue -sourceArray $interchangeableParameterValues.$valueType)) {
          Write-Verbose "Found value both source value '$strSourceValue' and corresponding value '$srtCorrespondingValue' in 'interchangeableParameterValues.$valueType'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
          $isValid = $true
          break
        }
      }
    }
  }

  $isValid
}

#function to get the resource scope name and type (management group, subscription or resource group) by Id based on regex match
Function getResourceScopeTypeAndNameById {
  [CmdletBinding()]
  [OutputType([Hashtable])]
  Param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$resourceId
  )
  $rgRegex = '(?i)^\/subscriptions\/[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}\/resourcegroups\/([-\w\._\(\)]+)$'
  $mgRegex = '(?i)^\/providers\/microsoft.management\/managementgroups\/([-\w\._\(\)]+)$'
  $subRegex = '(?i)^\/subscriptions\/([0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12})$'
  if ($resourceId -match $mgRegex) {
    #is resource group
    $resourceName = $matches[1]
    $resourceType = 'managementGroup'
  } elseif ($resourceId -match $rgRegex) {
    $resourceName = $matches[1]
    $resourceType = 'resourceGroup'
  } elseif ($resourceId -match $subRegex) {
    $resourceName = $matches[1]
    $resourceType = 'subscription'
  } else {
    Throw "Unknown resource type for resource id '$resourceId'."
    Exit 1
  }
  $result = @{
    resourceType = $resourceType
    resourceName = $resourceName
  }
  $result
}


#Function to get corresponding resource Ids based on the target scope mapping defined in the configuration file
Function getCorrespondingResourceIds {
  [CmdletBinding()]
  [OutputType([Array])]
  Param (
    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [array]$sourceResourceId = @(),

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$sourceEnvironment,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$correspondingEnvironment,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [Hashtable]$config
  )
  $correspondingResourceIds = @()
  foreach ($s in $sourceResourceId) {
    Write-Verbose "Looking up corresponding resource for production resource '$s'" -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    $sourceDetails = getResourceScopeTypeAndNameById -resourceId $s
    Write-Verbose "Resource Type for '$s': '$($sourceDetails.resourceType)'." -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
    switch ($sourceDetails.resourceType) {
      'managementGroup' {
        $correspondingResource = getTargetScopeMapping -type 'managementGroup' -name $sourceDetails.resourceName -from $sourceEnvironment -config $config -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $correspondingResourceIds += '/providers/Microsoft.Management/managementGroups/{0}' -f $correspondingResource
      }
      'resourceGroup' {
        #For resource group, the resource Id is required (can't use resource Name because the resource Id also contains the subscription id)
        $correspondingResource = getTargetScopeMapping -type 'resourceGroup' -name $sourceResourceId -from $sourceEnvironment -config $config  -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $correspondingResourceIds += $correspondingResource
      }
      'subscription' {
        $correspondingResource = getTargetScopeMapping -type 'subscription' -name $sourceDetails.resourceName -from $sourceEnvironment -config $config  -Verbose:($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true)
        $correspondingResourceIds += '/subscriptions/{0}' -f $correspondingResource
      }
    }
  }
  , $correspondingResourceIds
}

Export-ModuleMember *
