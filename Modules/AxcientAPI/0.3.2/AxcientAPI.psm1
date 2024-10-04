﻿#Region '.\Private\Find-ObjectIdByReference.ps1' -1

<#
.SYNOPSIS
Validates an object and returns an ID

.DESCRIPTION
This function handles two needs: Validating a given object is likely valid, and returning a logical ID for the object.
It is used by functions that accept custom object input as a simple and consistent method to handle these needs.

.PARAMETER Reference
The reference to be evaluated. Valid inputs are integers, strings, objects containing an id property
and possibly an objectschema property, and $null. All other inputs raise a warning to the console and
return $null.

.PARAMETER Schema
The schema name to compare against the provided Reference object. If the object has an objectschema property
the function will return the object ID if the schema matches the provided schema. If the schema does not match
the function will return $null and write a warning to the console. [int] and [string] values are not evaluated
and process as if the parameter is not specified.

.PARAMETER Validation
If set, the function completes as normal but returns only $true if the Reference is valid and $false otherwise.
This is used in parameter definition blocks as part of a ValidateScript attribute.
#>
function Find-ObjectIdByReference {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [AllowNull()]
        [object]$Reference,

        [Parameter()]
        [string]$Schema,

        [Parameter()]
        [switch]$Validation # Added because 0 is falsy but a valid id
    )
    process {
        Write-Debug "Find-ObjectIdByReference: $Reference"
        switch ($Reference) {
            { $null -eq $_ } { $null }
            { $Schema -and $_.objectschema } {
                if ($_.objectschema -ieq $Schema) {
                    $Validation ? $true : $_.id
                }
                else {
                    Write-Warning "Find-ObjectIdByReference: Schema mismatch: Expected '$Schema' but got '$($_.objectschema)'"
                    $null
                }
            }
            { $_.objectschema -and -not $Schema } { $Validation ? $true : $_.id }
            { $_ -is [int64] -or $_ -is [int] } { $Validation ? $true : $_ }
            { $_ -is [string] } {
                $_result = -1
                if ([int]::TryParse($_, [ref]$_result)) {
                    $Validation ? $true : $_result
                }
                else {
                    Write-Warning "Find-ObjectIdByReference: Unable to parse string to Int: $_"
                    $null
                }
            }
            default {
                Write-Warning "Find-ObjectIdByReference: Could not parse object reference: $_"
                $null
            }
        }
    }
}
#EndRegion '.\Private\Find-ObjectIdByReference.ps1' 69
#Region '.\Private\Invoke-AxcientAPI.ps1' -1

function Invoke-AxcientAPI {
    [CmdletBinding()]
    param (
        [string]$Endpoint,
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,

        [bool]$ReturnErrors = $Script:AxcientReturnErrors
    )
    $_uri = "$Script:AxcientBaseUrl/$Endpoint"
    Write-Debug -Message "Axcient API: $Method $_uri"
    $response = Invoke-WebRequest -Uri $_uri -Method $Method  -Headers @{ 'X-API-Key' = $AxcientApiKey; 'Accept' = 'application/json' } -SkipHttpErrorCheck
    Write-Debug -Message "API Returned: $($response.StatusCode) $($response.StatusDescription) $($response.Content.Length) bytes of $($response.Headers.'Content-Type')"
    if ($response.StatusCode -ne 200) {
        # Attempt to parse the body
        $parsedContent = switch ($response.Headers.'Content-Type') {
            'application/problem+json' { [System.Text.Encoding]::UTF8.GetString($response.Content) | ConvertFrom-Json }
            'application/json' { $response.Content | ConvertFrom-Json }
            default {
                if ($response.Content | Test-Json -ErrorAction SilentlyContinue) { $response.Content | ConvertFrom-Json } # some responses arrive as JSON but with a text/html content type
                else {
                Write-Debug "The API did not return an expected body. Body: $($response.Content)"
                $null
                }
            }
        }
        # Bad API Key
        if ($response.StatusCode -eq 401 -and $parsedContent.PSObject.Properties.Count -eq 1 -and $parsedContent.message -eq 'Unauthorized') {
            $_keyLength = $AxcientApiKey.Length
            $_keySample = $_keyLength -gt 5 ? "[$($AxcientAPIKey.Substring(0,5))...] Verify key is active and the user account that generated the API key is active." : "Key is too short. Verify input to Initialize-AxcientAPI and retry."
            $_errorMessage = "API returned 401 Unauthorized. It's likely a problem with your API Key. Key: $_keySample"
        }
        # Bad endpoint
        elseif ($response.StatusCode -eq 401 -and $parsedContent.code -eq 401 -and $parsedContent.msg -eq 'Unauthorized' ) {
            $_errorMessage = "API returned 401 Unauthorized. There may be an issue with the specified endpoint or requested object. Endpoint: $Endpoint"
        }
        # Returned a full error object
        elseif ($parsedContent.detail -and $parsedContent.title) {
            $_errorMessage = "API returned {0} {1}: {2}" -f $response.StatusCode, $parsedContent.title, $parsedContent.detail
        }
        # Unknown response
        else {
                $httpCodeMessage = switch ($response.StatusCode) { # This is from the OpenAPI schema
                    400 { 'One or more specified IDs are invalid' }
                    401 { 'Access token is missing or invalid' }
                    404 { 'Resource not found or delegated to authenticating user' }
                    default { "$($response.StatusCode) $($response.StatusDescription)" }
                }

                $parsedContent = [pscustomobject][ordered]@{
                    detail = $httpCodeMessage
                    status = $response.StatusCode
                    title = $response.StatusDescription
                    type = 'UndefiniedHTTPErrorResponse'
                }
                $_errorMessage = "API returned an unexpected result: {0} {1}. Possible reason per API documentation is: {2}" -f $response.StatusCode, $response.StatusDescription, $httpCodeMessage
        }

        Write-Error $_errorMessage
        Write-Debug -Message "Failed to invoke Axcient API. StatusCode: $($response.StatusCode). Content: $($parsedContent | Convertto-json -Depth 5 -Compress)"

        if ($ReturnErrors) { $parsedContent }
    }
    else {
        $response.Content | ConvertFrom-Json
    }
}
#EndRegion '.\Private\Invoke-AxcientAPI.ps1' 67
#Region '.\Public\Get-Appliance.ps1' -1

<#
.SYNOPSIS
Get information about an Appliance.

.DESCRIPTION
Gets information about appliances. Can accept Appliance or Client objects from the pipeline or from parameters.
You can also specify an appliance by its service ID.

.PARAMETER Appliance
Appliance object or ID to retrieve information on.

.PARAMETER Client
Specifies the client object or reference to retrieve information for all appliances associated with a specific client.

.PARAMETER InputObject
Specifies the appliance or client object received through the pipeline to retrieve information.

.PARAMETER ServiceID
Specifies the service ID of the appliance. Must be a 4-character alphanumeric string.

.PARAMETER IncludeDevices
Indicates whether to include device information along with the appliance information. By default, it is set to $true.

.INPUTS
Appliance or Client object

.OUTPUTS
An Appliance object or array or Appliance objects

.EXAMPLE
Get-Appliance
# Returns all appliances avaialble to the user account at this organization

.EXAMPLE
Get-Appliance -Appliance 12345

.EXAMPLE
$client | Get-Appliance
#>
function Get-Appliance {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(ParameterSetName = 'Appliance')]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'appliance' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Appliance,

        [Parameter(ParameterSetName = 'Client')]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'client' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Client,

        [Parameter(ValueFromPipeline, ParameterSetName = 'Pipeline', DontShow)]
        [ValidateScript({ $_.objectschema -iin 'appliance', 'client' }, ErrorMessage = 'Only Appliance and Client objects are accepted via the pipeline.' )]
        [object]$InputObject,

        [Parameter(ParameterSetName = 'All')]
        [Alias('service_id')]
        [ValidatePattern('^[a-zA-Z0-9]{4}$', ErrorMessage = 'Service ID must be a 4-character alphanumeric string')]
        [string]$ServiceID,

        [Parameter()]
        [Alias('include_devices')]
        [bool]$IncludeDevices = $true
    )
    process {
        $_queryParameters = @()
        switch ($PSCmdlet.ParameterSetName) {
            'Appliance' {
                $_applianceId = Find-ObjectIdByReference $Appliance
                $_endpoint = "appliance/$_applianceId"
            }
            'Client' {
                $_clientId = Find-ObjectIdByReference $Client
                $_endpoint = "client/$_clientId/appliance"
            }
            'Pipeline' {
                if ($InputObject.objectschema -eq 'appliance') {
                    $_applianceId = $InputObject.id
                    $_endpoint = "appliance/$_applianceId"
                }
                elseif ($InputObject.objectschema -eq 'client') {
                    $_clientId = $InputObject.id
                    $_endpoint = "client/$_clientId/appliance"
                }
            }
            default {
                $_endpoint = "appliance"
                if ($ServiceID) {
                    $_queryParameters += "service_id=$ServiceID"
                }
            }
        }
        if ($PSBoundParameters.ContainsKey('IncludeDevices')) {
            $_queryParameters += "include_devices=$IncludeDevices"
        }

        if ($_queryParameters) {
            $_endpoint += '?' + ($_queryParameters -join '&')
        }
        Invoke-AxcientAPI -Endpoint $_endpoint -Method Get | Foreach-Object {
            $_ | Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'appliance' -PassThru
        }
    }
}
#EndRegion '.\Public\Get-Appliance.ps1' 104
#Region '.\Public\Get-BackupJob.ps1' -1

<#
.SYNOPSIS
Get backup job information for a device.

.DESCRIPTION
Retrieves the Job configuration for a device. May return more than one Job.

.PARAMETER Device
Device to retrieve information for. Accepts device ID or Device Object. If specifying a device
object, function will also use Client ID if available. Not required if present on Job object

.PARAMETER Client
Relevant Client ID or Object. Not required if Client ID is avilable on Device or Job object

.PARAMETER Job
A specific Job to retrieve information for.

.INPUTS
Accepts Device or Job objects. If Client ID or Device ID is not present on passed object it must
be specified as a separate parameter.

.OUTPUTS
A Job object or array of Job objects

.EXAMPLE
Get-BackupJob -Device 12345 -Client 67890 -Job 54321

.EXAMPLE
# Get all Jobs for all devices for a client.
PS > Get-Client -Client 49282 | Get-Device | Get-BackupJob
#>
function Get-BackupJob {
    [CmdletBinding()]
    [OutputType([PSCustomObject],[PScustomObject[]])]
    param (
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'device' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Device,

        [Parameter()]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'client' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Client,

        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'job' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Job,

        [Parameter(ValueFromPipeline, DontShow)]
        [ValidateScript({ $_.objectschema -iin 'device', 'job' }, ErrorMessage = 'Only Device or Job objects are accepted via the pipeline.' )]
        [object]$InputObject
    )
    begin {
        $deviceParamID = Find-ObjectIdByReference $Device
        $clientParamID = Find-ObjectIdByReference $Client
    }
    process {
        if ($InputObject.objectschema -eq 'job' -xor $PSBoundParameters.ContainsKey('Job')) {
            $_io = $InputObject ?? $Job
            $_jobId = $_io | Find-ObjectIdByReference
            $_clientId = $_io.client_id ?? $clientParamID
            $_deviceId = $_io.device_id ?? $deviceParamID
            Write-Debug "Get-BackupJob: Per-Job flow: Client: $_clientId, Device: $_deviceId, Job: $_jobId"
            $_endpoint = "client/$_clientId/device/$_deviceId/job/$_jobId"
            if (-not ($_clientId -and $_deviceId)) {
                Write-Error "Missing client ID or device ID on job object. Specify with -Client and -Device parameters."
                return
            }
        }
        elseif ($InputObject.objectschema -eq 'device' -xor $PSBoundParameters.ContainsKey('Device')) {
            $_io = $InputObject ?? $Device
            $_clientId = $_io.client_id ?? $clientParamID
            $_deviceId = $_io.id ?? $deviceParamID
            Write-Debug "Get-BackupJob: Device flow: Client: $_clientId, Device: $_deviceId, Job: $_jobId"
            $_endpoint = "client/$_clientId/device/$_deviceId/job"
            if (-not $_clientId) {
                Write-Error "Missing client ID on device object. Specify with -Client parameter."
                return
            }
        }
        else {
            if ($InputObject.objectschema -eq 'Device' -and $PSBoundParameters.ContainsKey('Device')) {
                Write-Error 'Device specified via pipeline and -Device parameter. Use one or the other.'
            }
            elseif ($InputObject.objectschema -eq 'Job' -and $PSBoundParameters.ContainsKey('Job')) {
                Write-Error 'Job specified via pipeline and -Job parameter. Use one or the other.'
            }
            else {
                Write-Error "At least Device and Client ID must be specified as an object member or via parameters."
            }
            return
        }
        Invoke-AxcientAPI -Endpoint $_endpoint -Method Get | Foreach-Object {
            $_ | Add-Member -MemberType NoteProperty -Name 'client_id' -Value $_clientId -Force -PassThru |
            Add-Member -MemberType NoteProperty -Name 'device_id' -Value $_deviceId -PassThru |
            Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'job' -PassThru
        }
    }
}
#EndRegion '.\Public\Get-BackupJob.ps1' 97
#Region '.\Public\Get-BackupJobHistory.ps1' -1

<#
.SYNOPSIS
Get history of runs for a backup job.

.DESCRIPTION
Retrieves run history for a backup job

.PARAMETER Device
Device to retrieve information for. Accepts device ID or Device Object. If specifying a device
object, function will also use Client ID if available. Not required if present on Job object

.PARAMETER Client
Relevant Client ID or Object. Not required if Client ID is avilable on Device or Job object

.PARAMETER Job
A specific Job to retrieve information for.

.EXAMPLE
Get-BackupJobHistory -Device 12345 -Client 67890 -Job 54321

.EXAMPLE
$job | Get-BackupJobHistory

.NOTES
This endpoint currently has a bug. Function logic is cohesive but untested. It may be attempted, a warning will display. Once bug is resolved this warning will be removed. #GH-3 -2024-07-11
#>
function Get-BackupJobHistory {
    [CmdletBinding()]
    param (
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'device' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Device,

        [Parameter()]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'client' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Client,

        [Parameter(ValueFromPipeline, Mandatory)]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'job' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Job
    )
    begin {
        $deviceParamID = Find-ObjectIdByReference $Device
        $clientParamID = Find-ObjectIdByReference $Client
    }
    process {
        $_jobId = Find-ObjectIdByReference $Job
        $_clientId = $Job.client_id ?? $clientParamID
        $_deviceId = $Job.device_id ?? $deviceParamID
        Write-Debug "Get-BackupJobHistory: Client: $_clientId, Device: $_deviceId, Job: $_jobId"
        if ($null -eq $_jobId -or $null -eq $_clientId -or $null -eq $_deviceId) {
            Write-Error "Missing client ID, device ID, or job ID. All three are required and may be included in the Job object or specified as parameters."
            continue
        }
        $_endpoint = "client/$_clientId/device/$_deviceId/job/$_jobId/history"
        Invoke-AxcientAPI -Endpoint $_endpoint -Method Get | Foreach-Object {
            $_ | Add-Member -MemberType NoteProperty -Name 'client_id' -Value $_clientId -Force -PassThru |
            Add-Member -MemberType NoteProperty -Name 'device_id' -Value $_deviceId -PassThru |
            Add-Member -MemberType NoteProperty -Name 'job_id' -Value $_jobId -PassThru |
            Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'job.history' -PassThru
        }
    }
}
#EndRegion '.\Public\Get-BackupJobHistory.ps1' 63
#Region '.\Public\Get-Client.ps1' -1

<#
.SYNOPSIS
Retrieves information on a client or clients

.DESCRIPTION
Retrieves information for for one or multiple clients, including client ID, name, health status,
and device counters. Optionally basic information about the client's appliances can be included.

.PARAMETER Client
Client or clients to retrieve information for. Accepts one or more integer client IDs or objects.
Parameter accepts from the pipeline.

.PARAMETER IncludeAppliances
Return basic information about appliances for this client.

.INPUTS
Accepts a Client object.

.OUTPUTS
Returns a Client object or array of Client objects.

.EXAMPLE
$clients = Get-Client
PS > $clients.Count
42

.EXAMPLE
$oneClientFreshData = Get-Client -Client $clients[0]
# Returns updated client information

.EXAMPLE
$oneClientFreshData = $clients[0] | Get-Client -IncludeAppliances
# Returns updated client information, now with basic appliance information

.EXAMPLE
$oneClient = Get-Client -Client 12345
PS > $oneClient.id
12345
#>
function Get-Client {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param (
        [Parameter(ValueFromPipeline, ParameterSetName = 'Client')]
        [Alias('Id')]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'client' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object[]]$Client,

        [Parameter()]
        [switch]$IncludeAppliances
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Client') {
            foreach ($thisClient in $Client) {
                $_id = Find-ObjectIdByReference $thisClient
                $_endpoint = "client/$_id"
                if ($IncludeAppliances) {
                    $_endpoint += '?include_appliances=true'
                }
                Invoke-AxcientAPI -Endpoint $_endpoint -Method Get | Foreach-Object { $_ | Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'client' -PassThru }
            }
        }
        else {
            $_endpoint = "client"
            if ($IncludeAppliances) {
                $_endpoint += '?include_appliances=true'
            }
            Invoke-AxcientAPI -Endpoint $_endpoint -Method Get | Foreach-Object { $_ | Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'client' -PassThru }
        }
    }
}
#EndRegion '.\Public\Get-Client.ps1' 72
#Region '.\Public\Get-Device.ps1' -1

<#
.SYNOPSIS
Retrieves information about devices.

.DESCRIPTION
Retrieves information about protected devices, including agent status, version, IP Address,
host OS, and more. You can specify by Client or Device. If no parameters are provided, the
function returns all devices available under the authenticated account.

.PARAMETER Client
Client to retrieve a list of devices for. Accepts one or more integer client IDs or objects.
You may pipe Client objects to this function.

.PARAMETER Device
A specific device or devices to retrieve information for. Accepts one or more integer device
IDs or objects.

.INPUTS
Client objects

.OUTPUTS
A Device object or array of Device objects

.EXAMPLE
Get-Device
# Returns a list of all devices available under the authenticated account.

.EXAMPLE
$client | Get-Device
# Returns a list of devices for the given client

.EXAMPLE
Get-Device -Client $client,$client2
# Returns a list of devices for two clients

.EXAMPLE
Get-Device -Device 12345

.EXAMPLE
Get-Device -Device $myDevice
#>
function Get-Device {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param (
        [Parameter(ValueFromPipeline, ParameterSetName = 'Client')]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'client' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object[]]$Client,

        [Parameter(ParameterSetName = 'Device')]
        [Alias('Id')]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'device' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object[]]$Device
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Device') {
            foreach ($thisDevice in $Device) {
                $_deviceId = Find-ObjectIdByReference $thisDevice
                $_endpoint = "device/$_deviceId"
                Invoke-AxcientAPI -Endpoint $_endpoint -Method Get | Foreach-Object {
                    $_ | Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'device' -PassThru
                }
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Client') {
            foreach ($thisClient in $Client) {
                $_clientId = Find-ObjectIdByReference $thisClient
                $_endpoint = "client/$_clientId/device"
                Invoke-AxcientAPI -Endpoint $_endpoint -Method Get | Foreach-Object {
                    $_ | Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'device' -PassThru
                }
            }
        }
        else {
            Invoke-AxcientAPI -Endpoint 'device' -Method Get | Foreach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'device' -PassThru
            }
        }
    }
}
#EndRegion '.\Public\Get-Device.ps1' 81
#Region '.\Public\Get-DeviceAutoVerify.ps1' -1

<#
.SYNOPSIS
Retrieves auto-verify information for one or more devices.

.DESCRIPTION
Returns information about auto-verify tests. Each device returns an auto-verify object with one or
more runs detailed.

.PARAMETER Device
The device or devices to retrieve auto-verify information. Accepts integer IDs or Device objects.
Accepts from the pipeline.

.INPUTS
Device objects

.OUTPUTS
An Autoverify object or array of Autoverify objects.

.EXAMPLE
Get-DeviceAutoVerify -Device $device1, $device2
Retrieves auto-verify information for $device1 and $device2.

.EXAMPLE
$clientDevices | Get-DeviceAutoVerify
Returns auto-verify information for all devices.
#>
function Get-DeviceAutoVerify {
    [CmdletBinding()]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'device' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object[]]$Device
    )
    process {
        foreach ($thisDevice in $Device) {
            $_deviceId = Find-ObjectIdByReference $thisDevice
            Invoke-AxcientAPI -Endpoint "device/$_deviceId/autoverify" -Method Get | Foreach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name 'client_id' -Value $thisDevice.client_id -Force -PassThru |
                Add-Member -MemberType NoteProperty -Name 'device_id' -Value $thisDevice.id -PassThru |
                Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'device.autoverify' -PassThru
            }
        }
    }
}
#EndRegion '.\Public\Get-DeviceAutoVerify.ps1' 46
#Region '.\Public\Get-DeviceRestorePoint.ps1' -1

<#
.SYNOPSIS
Retrieves restore points for a device.

.DESCRIPTION
For each specified device, returns an object with current status and a list of restore points.

.PARAMETER Device
One or more Device objects or integers to retrieve restore points for.

.INPUTS
Restore point object

.OUTPUTS
Restore point object or array of Restore point objects

.EXAMPLE
$devices = Get-Device
PS > $restorePoints = $devices | Get-DeviceRestorePoint
#>
function Get-DeviceRestorePoint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'device' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object[]]$Device
    )
    process {
        foreach ($thisDevice in $Device) {
            $_deviceId = Find-ObjectIdByReference $thisDevice
            Invoke-AxcientAPI -Endpoint "device/$_deviceId/restore_point" -Method Get | Foreach-Object {
                $_ | Add-Member -MemberType NoteProperty -Name 'client_id' -Value $thisDevice.client_id -Force -PassThru |
                Add-Member -MemberType NoteProperty -Name 'device_id' -Value $_deviceId -PassThru |
                Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'device.restorepoint' -PassThru
            }
        }
    }
}
#EndRegion '.\Public\Get-DeviceRestorePoint.ps1' 39
#Region '.\Public\Get-Organization.ps1' -1

<#
.SYNOPSIS
Retrieves information about the partner organization.

.DESCRIPTION
Retrieves basic information about the partner organization related to the authenticating
user API Key.

.EXAMPLE
Get-Organization

id           : 26
name          : Spacely Sprockets
active        : True
brand_id      : SPACELY
salesforce_id : reseller_salesforce_id
#>

function Get-Organization {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    Invoke-AxcientAPI -Endpoint 'organization' -Method Get | Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'organization' -PassThru
}
#EndRegion '.\Public\Get-Organization.ps1' 25
#Region '.\Public\Get-Vault.ps1' -1

<#
.SYNOPSIS
Get information about vaults

.DESCRIPTION
Get information about a vaults related to an organization or on a specific vault. If requesting
information for all vaults you can filter by type, state, and URL presence.

.PARAMETER Vault
Vault object or ID to retrieve information on.

.PARAMETER Type
Specifies the type of vaults to retrieve. Valid values are 'Private' and 'Cloud'. Returns both
types if not specified.

.PARAMETER Active
Specifies whether to retrieve active vaults only. If set to $true, only active vaults will be
retrieved. If set to $false, only inactive vaults will be retrieved. If not set, the result
is not filtered by active state.

.PARAMETER WithUrl
Filter on presence of URL. If true, only vaults with a URL will be retrieved. If false, only vaults
without a URL will be retrieved. If not set, the result is not filtered by URL presence.

.PARAMETER Limit
Specifies the maximum number of vaults to retrieve.

.PARAMETER IncludeDevices
Specifies whether to include devices associated with the vaults in the retrieved information. If set to $true, devices will be included.

.EXAMPLE
Get-Vault -Vault 12345

.EXAMPLE
Get-Vault -Type 'Private' -Active $true -WithUrl $true -IncludeDevices $false

.INPUTS
    Pipeline input is not accepted.

.OUTPUTS
Returns a Vault object or array of Vault objects
    [PSCustomObject],[PScustomObject[]]
#>
function Get-Vault {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [parameter(ValueFromPipeline, ParameterSetName = 'Vault')]
        [Alias('Id')]
        [ValidateScript({ Find-ObjectIdByReference -Reference $_ -Schema 'vault' -Validation }, ErrorMessage = 'Must be a positive integer or matching object' )]
        [object]$Vault,

        [Parameter(ParameterSetName = 'All')]
        [Alias('vault_type')]
        [ValidateSet('Private', 'Cloud')]
        [string]$Type,

        [Parameter(ParameterSetName = 'All')]
        [bool]$Active,

        [Parameter(ParameterSetName = 'All')]
        [Alias('with_url')]
        [bool]$WithUrl,

        [Parameter(ParameterSetName = 'All')]
        [int]$Limit,

        [Parameter(ParameterSetName = 'All')]
        [Alias('include_devices')]
        [bool]$IncludeDevices = $true
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Vault') {
            $_vaultId = Find-ObjectIdByReference $Vault
            $_endpoint = "vault/$_vaultId"
        }
        else {
            $_queryParameters = @()
            if ($Type) {
                $_queryParameters += "type=$Type"
            }
            if ($PSBoundParameters.ContainsKey('Active')) {
                $_queryParameters += "active=$Active"
            }
            if ($PSBoundParameters.ContainsKey('WithUrl')) {
                $_queryParameters += "with_url=$WithUrl"
            }
            if ($Limit) {
                $_queryParameters += "limit=$Limit"
            }
            if ($PSBoundParameters.ContainsKey('IncludeDevices')) {
                $_queryParameters += "include_devices=$IncludeDevices"
            }
            if ($_queryParameters) {
                $_endpoint = "vault?" + ($_queryParameters -join '&')
            }
            else {
                $_endpoint = "vault"
            }
        }
        Invoke-AxcientAPI -Endpoint $_endpoint -Method Get | Foreach-Object { $_ | Add-Member -MemberType NoteProperty -Name 'objectschema' -Value 'vault' -PassThru }
    }
}
#EndRegion '.\Public\Get-Vault.ps1' 103
#Region '.\Public\Initialize-AxcientAPI.ps1' -1

<#
.SYNOPSIS
Sets API key, server URL, and error handling for AxcientAPI module functions.

.DESCRIPTION
Initialize-AxcientAPI sets the API key and server URL for AxcientAPI module functions. The API key is
required for both production and mock environments. By default the production server URL is utilized.
Use the -MockServer switch to specify the mock environment.

.PARAMETER ApiKey
API key to authenticate the connection.

.PARAMETER MockServer
Specifies whether to use the mock server for testing purposes.

.PARAMETER ReturnErrors
When set, module functions will return the error object if an API call fails. By default nothing is returned
on failure.

.EXAMPLE
Initialize-AxcientAPI -ApiKey "imalumberjackandimokay" -MockServer -ReturnErrors

.NOTES
 As of module version 0.3.0 and the July 2024 API release the error schema is not well-defined. The module
 attempts to return a consistent object of its own design.
#>
function Initialize-AxcientAPI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ApiKey,

        [Parameter()]
        [switch]$MockServer,

        [Parameter()]
        [switch]$ReturnErrors
    )
    $baseUrl = $MockServer ? 'https://ax-pub-recover.wiremockapi.cloud' : 'https://axapi.axcient.com/x360recover'
    $Script:AxcientBaseUrl = $baseUrl
    $Script:AxcientApiKey = $ApiKey
    if ($ReturnErrors) { $Script:AxcientReturnErrors = $true } else { $Script:AxcientReturnErrors = $false }
}
#EndRegion '.\Public\Initialize-AxcientAPI.ps1' 44
