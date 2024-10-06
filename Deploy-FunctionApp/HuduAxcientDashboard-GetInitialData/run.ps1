param($config)


<# 
    Hudu-Axcient Dashboard
    https://github.com/adamburley/Hudu-Axcient-Dashboard
    Copywrite: Adam Burley 2024
    Version: 1.0
#>
#requires -Version 7.2

#region ----------- FUNCTIONS -----------
# Thanks, @JohnDuprey! https://github.com/KelvinTegelaar/CIPP-API/blob/master/Modules/CippExtensions/Public/Extension%20Functions/Add-HuduAssetLayoutM365Field.ps1
function Add-HuduAssetLayoutField {
    Param(
        $AssetLayoutId
    )

    $M365Field = @{
        position     = 0
        label        = 'Axcient x360Recover'
        field_type   = 'RichText'
        show_in_list = $false
        required     = $false
        expiration   = $false
        hint         = '** DO NOT MODIFY **  This field is automatically updated.'
    }

    $AssetLayout = Get-HuduAssetLayouts -LayoutId $AssetLayoutId

    if ($AssetLayout.fields.label -contains 'Axcient x360Recover') {
        Write-Host "Layout $($AssetLayout.name) already has the Axcient x360Recover field" -ForegroundColor Magenta
        return $AssetLayout
    }

    $AssetLayoutFields = [System.Collections.Generic.List[object]]::new()
    $AssetLayoutFields.Add($M365Field)
    foreach ($Field in $AssetLayout.fields) {
        $Field.position++
        $AssetLayoutFields.Add($Field)
    }
    Set-HuduAssetLayout -Id $AssetLayoutId -Fields $AssetLayoutFields
    Write-Host "Added Axcient x360Recover field to $($AssetLayout.name)" -ForegroundColor Green
}
function Find-RequiredModuleVersion {
    param($requiredModules,
    $localModulePath,
    [switch]$Interactive)
    foreach ($m in $requiredModules) {
        $found = $false
        $testPath = "$localModulePath\$($M.Name)"
        if (Test-Path -Path $testPath) { 
            $foundVer = gci $testPath | select -ExpandProperty Name | sort -Descending | select -First 1
            if ($foundVer -ge $m.Version) {
                Write-Host "$($m.Name) $($m.Version) found in Modules folder" -ForegroundColor Green
                $found = $true
                "$localModulePath\$($m.Name)"
            }
        } 
        elseif (($installedModules = Get-Module $m.Name -ListAvailable) -and ($topVer = $installedModules | sort Version -Descending | select -first 1).Version -ge $m.Version) {
                Write-Host "$($m.Name) $($m.Version) found in installed modules" -ForegroundColor Green
                $found = $true
                $topVer.Path
        }
        if (-not $found) {
            Write-Host "$($m.Name) $($m.Version) not found" -ForegroundColor Red
            if ($Interactive){
                Write-Host "Would you like to download to $localModulePath`? (Y/n): " -ForegroundColor Yellow -NoNewline
                if ((Read-Host) -in 'y', '') {
                    if (-not (Test-Path -Path $localModulePath)) {
                        New-Item -Path $localModulePath -ItemType Directory | Out-Null
                    }   
                    Save-Module -Name $m.Name -Path $localModulePath -MinimumVersion $m.Version
                    "$localModulePath\$($m.Name)"
                } else {
                    Write-Host "Please ensure module is installed or available before continuing." -ForegroundColor Red
                    pause
                }
            } else {
                Write-Error "Unable to locate module $($m.Name) $($m.Version). It is required to continue." -ErrorAction Stop
            }
        }
    }
}
function Get-InitialSyncData {
    param($config)

    $axcientClients = Get-Client | Sort-Object name
    $huduCompanies = Get-HuduCompanies

    if ($config.autoMatch) {
        Write-Host "Automatch running..." -ForegroundColor Magenta
        $softMatches = 0
        foreach ($c in $axcientClients | where { $_.id -inotin $Config.matches.axcientId }) {
            $match = $huduCompanies | ? { $_.name -eq $c.name }
            if ($match) {
                $config.matches += [PSCustomObject]@{
                    name      = $c.name
                    axcientId = $c.id
                    huduID    = $match.id
                }
                $softMatches++
                Write-Host "`t$($c.name)" -ForegroundColor Green
            }
        }
        Write-Host "`nSuccessfully soft-matched " -ForegroundColor Yellow -NoNewline
        Write-Host $softMatches -ForegroundColor Green -NoNewline
        Write-Host " clients.`n" -ForegroundColor Yellow
    }
    return $axcientClients, $huduCompanies, $config
}
function Invoke-ProcessCompany {
    param(
        $client,   
        $match,
        $huduCompanies,
        $config
    )   
    $huduCompany = $huduCompanies | where { $_.id -eq $match.huduID }

    $devices = $client | Get-Device
    $huduServers = Get-HuduAssets -AssetLayoutId $config.serverAssetLayoutId -CompanyID $huduCompany.id
    
    if ($devices.type.Contains('WORKSTATION')) {
        $huduWorkstations = Get-HuduAssets -AssetLayoutId $config.workstationAssetLayoutId -CompanyID $huduCompany.id
        Write-Host "Retrieved $($huduServers.Count) servers and $($huduWorkstations.count) workstations for $($huduCompany.name)" -ForegroundColor Yellow

    }
    else {
        Write-Host "Retrieved $($huduServers.Count) servers for $($huduCompany.name)" -ForegroundColor Yellow
    }

    if ($config.createMagicDash) {
        Write-Host "Updating Magic dash..."
        Update-MagicDash -client $client -huduCompany $huduCompany -huduServers $huduServers -huduWorkstations $huduWorkstations -devices $devices
    }
    else {
        Write-Host "Magic Dash creation is disabled"
    }

    if ($config.updateDeviceAssets) {
        $devices | % {
            Write-Host "Updating asset for $($_.name)"
            Update-DeviceAsset -device $_ -huduServers $huduServers -huduWorkstations $huduWorkstations 
        }
    }
    else {
        Write-Host "Device asset update is disabled"
    }
}

function Merge-Template {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Template,

        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$Parameters

    )
    begin {
        $resultAL = [System.Collections.ArrayList]::new()
    }
    process {
        $thisResult = $Template.Clone()
        $Parameters.GetEnumerator() | ForEach-Object {
            $thisResult = $thisResult.Replace("{{$($_.Key)}}", $_.Value, [System.StringComparison]::OrdinalIgnoreCase)
        }
        $resultAL.Add($thisResult) | Out-Null
    }
    end {
        $resultAL | Out-String
    }
}
function New-ApplianceDashBlock {
    param ($client)
    $appliances = $client | Get-Appliance
    $result = "<table><thead><tr><th></th><th>Status</th><th>Storage</th></tr></thead><tbody>"
    foreach ($a in $appliances) {
        $result += @"
<tr><th>
            <button class="button" style="background-color: var(--primary)" role="button"><a style="color: white;"
				role="button" href="https://my.axcient.net/home/appliance/$($a.id)" title="View $($a.alias) in Axcient" target="_blank"><i
					class="fas fa-server me-2"></i>$($a.alias)</a></button></th>
<td> $($a.health_status) $($a.health_status_reason)</td>
<td> $([math]::round($a.storage_details.used_size/1tb, 1)) / $([math]::round($a.storage_details.drive_size/1tb, 1)) TB ($([math]::round($a.storage_details.used_size/$a.storage_details.drive_size*100, 1))%)</td>
</tr>
"@
    }
    $result + "</tbody></table>"
}
function New-DeviceDashStatusTable {
    param (
        [Parameter(ValueFromPipeline)]
        $device,
        $huduServers,
        $huduWorkstations
    )
    begin {
        $result = [System.Collections.ArrayList]@(
            @"
        <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Links</th>
                <th>Type</th>
                <th>Status</th>
                <th>Last Backup</th>
                <th>Vault Usage</th>
            </tr>
        </thead>
        <tbody>
"@
        )
    }
    process {
        # Find the Hudu asset, if we can
        $hAss = $device.Type -eq 'SERVER' ? ($huduServers | ? name -eq $device.name) : $huduWorkstations | ? name -eq $device.name
        if (-not $hAss) {
            $nShort = $device.name -split '\.' | select -first 1
            $hAss =  $device.Type -eq 'SERVER' ? ($huduServers | ? name -eq $nShort) : $huduWorkstations | ? name -eq $nShort
        }
        if ($hAss) {
            $hUrl = $hAss | select -expandproperty url
            $hAssName = $hAss | select -expandproperty name
            $disabled = ''
        }
        else {
            $hUrl = ''
            $hAssName = ''
            $disabled = 'disabled'
        }
        $errStyle = $device.current_health_status.status -eq 'NORMAL' ? '' : 'background-color: #fcd1d3'
        $result.Add(@"
<tr title=$($device.name) style="$errStyle">
    <td style="$errStyle">
        $($device.name)
    </td>
    <td style="$errStyle">
        <a class="button" style="display: inline; color: white;background-color: var(--primary);width: 4em;height: 2em;" role="button" href="$hUrl" title="View $hAssName in Hudu" $disabled>
            <i class="fa-solid fa-file-lines" style="margin: 2px;"></i>
        </a>
        &nbsp;
        <a class="button" style="display: inline; color: white;background-color: var(--primary);width: 4em;height: 2em;" role="button" href="$($device.device_details_page_url)" target="_blank" title="View $($device.name) in Axcient">
            <i class="fa-solid fa-cloud-arrow-up" style="margin: 2px;"></i>
        </a>
    </td>
    <td style="$errStyle">
        $($device.type)
    </td>
    <td style="$errStyle">
        $($device.current_health_status.status) $($device.current_health_status.reason)
    </td>
    <td style="$errStyle">
        $(if ($device.latest_cloud_rp) { $device.latest_cloud_rp.ToLocalTime()} else { 'Unknown'})
    </td>
    <td style="$errStyle">
        $([math]::round($device.vaults[0].device_usage/1gb,1)) GB
    </td>
</tr>
"@) | Out-Null
    }
    end {
        if ($result.count -eq 1) { 
            "No devices found"
        }
        else {
            $result.Add("</tbody></table>") | Out-Null
            $result | Out-String
        }
    }
}
function Update-CompanyMatches {
    param(
        $Config,
        $AxcientClients,
        $HuduCompanies,
        [switch]$Update
    )

    if ($Update) {
        Write-Host "Updating existing list. $($Config.matches.Count) matches already exist." -ForegroundColor Green
        $AxcientClients = $AxcientClients | where { $_.id -inotin $Config.matches.axcientId }
        Write-Host "$($AxcientClients.Count) Axcient clients are unmatched." -ForegroundColor Magenta
    }

    Write-Host "Attempting to soft-match based on company name...`n" -ForegroundColor Yellow
    Write-Host "Soft matches:" -ForegroundColor Magenta

    $huduMatches = @()
    $axcientMatches = @()
    $softMatches = 0
    foreach ($c in $axcientClients) {
        $match = $huduCompanies | ? { $_.name -eq $c.name }
        if ($match) {
            $config.matches += [PSCustomObject]@{
                name      = $c.name
                axcientId = $c.id
                huduID    = $match.id
            }
            $huduMatches += $match
            $axcientMatches += $c
            $softMatches++
            Write-Host "`t$($c.name)" -ForegroundColor Green
        }
    }
    Write-Host "`nSuccessfully soft-matched " -ForegroundColor Yellow -NoNewline
    Write-Host $softMatches -ForegroundColor Green -NoNewline
    Write-Host " clients.`n" -ForegroundColor Yellow

    $axcientNonMatches = $axcientClients | where { $_ -notin $axcientMatches }
    $huduNonMatches = $huduCompanies | where { $_ -notin $huduMatches }

    Write-host $axcientNonMatches.Count -ForegroundColor Red -NoNewline
    Write-Host " Axcient clients did not match." -ForegroundColor Yellow

    Write-Host "`nYou may use this script to match remaining clients, or you may manually match them via configurations." -ForegroundColor Yellow
    if ((Read-Host -Prompt "Use script to match remaining clients? (Y/n)") -in 'y', '') {
        Write-Host "To match remaining clients, a gridview will repeatedly invoke, showing remaining clients. Select two matching companies and click OK." -ForegroundColor Yellow
        Write-Host "To skip a client, select it alone and click OK." -ForegroundColor Yellow
        Write-Host "When finished, click Cancel to exit the matching subroutine." -ForegroundColor Yellow

        Write-Host "Axcient".PadRight(50) "Hudu" -ForegroundColor Magenta
        Write-Host "------".PadRight(50) "----" -ForegroundColor Magenta
        do {
            $gvOutput = @($axcientNonMatches | Select @{ n = 'Source'; e = { 'Axcient' } }, name, id)
            $gvOutput += $huduNonMatches | Select @{ n = 'Source'; e = { 'Hudu' } }, name, id
            $selection = $gvOutput | sort name | out-gridview -OutputMode Multiple
            if ($selection.Count -eq 2) {
                $axcientMatch = $selection | ? Source -eq 'Axcient'
                $huduMatch = $selection | ? Source -eq 'Hudu'
                $config.matches += [PSCustomObject]@{
                    name      = $axcientMatch.name
                    axcientId = $axcientMatch.id
                    huduID    = $huduMatch.id
                }
                $axcientNonMatches = $axcientNonMatches | where { $_.id -ne $axcientMatch.id }
                $huduNonMatches = $huduNonMatches | where { $_.id -ne $huduMatch.id }
                Write-Host $axcientMatch.name.PadRight(50) $huduMatch.name -ForegroundColor Green
            }
            elseif ($selection.Count -eq 1) {
                $axcientMatch = $selection | ? Source -eq 'Axcient'
                $axcientNonMatches = $axcientNonMatches | where { $_.id -ne $axcientMatch.id }
                Write-Host $axcientMatch.name.PadRight(50) X -ForegroundColor Red
            }
            else {
                break
            }
        } while ($axcientNonMatches.Count -gt 0)

        Write-Host "`nSuccessfully matched " -ForegroundColor Yellow -NoNewline
        Write-Host $($config.matches.Count) -ForegroundColor Green -NoNewline
        Write-Host " clients.`n" -ForegroundColor Yellow
    }
    $Config
}
function Update-DeviceAsset {
    param($device, $huduServers, $huduWorkstations)
    $hAss = $device.Type -eq 'SERVER' ? ($huduServers | ? name -eq $device.name) : $huduWorkstations | ? name -eq $device.name
    if (-not $hAss) {
        $nShort = $device.name -split '\.' | select -first 1
        $hAss = $device.Type -eq 'SERVER' ? ($huduServers | ? name -eq $nShort) : $huduWorkstations | ? name -eq $nShort
    }
    if (-not $hAss) {
        Write-Host "Unable to find a match for $($device.name)" -ForegroundColor Red
        return
    }
    elseif ($hAss.Count -gt 1) {
        Write-Host "Multiple matches found for $($device.name). Defaulting to first result, with slug $($hass[0].slug)" -ForegroundColor Magenta
        $hAss = $hAss[0]
    }
    Write-Host "Matched Axcient device $($device.name) to Hudu asset $($hAss.name)" -ForegroundColor Cyan
    $jobs = Get-BackupJob -Device $device
    $jobOpen = $jobs.count -eq 1 ? 'open' : ''
    $dav = Get-DeviceAutoVerify -Device $device | select -first 1 | select -expandproperty autoverify_details | sort timestamp -Descending | select -first 3
    $templateData = @{
        axcient_url       = $device.device_details_page_url
        name              = $device.name
        status            = $device.current_health_status.status
        errStyle = $device.current_health_status.status -eq 'NORMAL' ? '' : "background-color: #fcd1d3"
        replication_type  = $device.d2c ? 'D2C' : 'Appliance'
        last_local_backup = $device.latest_local_rp ? $device.latest_local_rp : ''
        local_usage       = $device.local_usage ? "$([math]::round($device.local_usage/1gb,1)) GB" : ''
        last_cloud_backup = $device.latest_cloud_rp ? $device.latest_cloud_rp : ''
        cloud_usage       = $device.cloud_usage ? "$([math]::round($device.cloud_usage/1gb,1)) GB" : ''
        volumes = $device.volumes -join "<br />"
        last_update       = (Get-Date).ToString()
        jobs              = $jobs | % {
            # some jobs have different schedules - possibly offsite = true
            $schedule = $_.schedule | ConvertFrom-Json -Depth 10
            $scheduleStatus = $schedule.isEnabled ? 'Enabled' : 'Disabled'
            $scheduleStatus += $schedule.isDefault ? ', Default' : ''
            $busAllowFull = $schedule.backup.businessHours.allowFull ? 'Full / Incremental' : 'Incremental only'
            $nbAllowFull = $schedule.backup.nonBusinessHours.allowFull ? 'Full / Incremental' : 'Incremental only'
            @{
                jobOpen               = $jobOpen
                name                   = $_.name
                id                     = $_.id
                description            = $_.description
                enabled                = $_.enabled ? 'Enabled' : 'Disabled'
                health_status          = $_.health_status
                type                   = $_.offsite -eq $true ? 'Offsite' : 'Local'
                destination            = $_.vaultIp
                last_run               = $_.latest_rp
                schedule_name          = $schedule.name
                schedule_description   = $schedule.description
                schedule_type          = $schedule.type
                schedule_status       = $scheduleStatus
                schedule_offset        = $schedule.offsetBackup
                schedule_businessHours = "Every $($schedule.backup.businessHours.repeat.hour) hour(s), $busAllowFull"
                schedule_nbHours       = "Every $($schedule.backup.nonBusinessHours.repeat.hour) hour(s), $nbAllowFull"
                throttling             = $schedule.throttling.isEnabled ? 'Enabled' : 'Disabled'
                throttling_business    = "Disk: $($schedule.throttling.businessHours.disk), Network: $($schedule.throttling.businessHours.network)"
                throttling_nb          = "Disk: $($schedule.throttling.nonbusinessHours.disk), Network: $($schedule.throttling.nonbusinessHours.network)"
                replication_info       = "Batch size: $($schedule.batchSize), Replication wait days: $($schedule.replicationwaitdays)"
                replication_schedule   = $schedule.schedules | ConvertTo-Json
            }
        } | Merge-Template -Template $assetJobTemplate
        
        dav               = $dav | % {
            @{
                timestamp                = $_.timestamp
                status                   = $_.status
                start                    = $_.start_timestamp
                end                      = $_.end_timestamp
                screenshot_url           = $_.screenshot_url
                screenshot_thumbnail_url = $_.screenshot_thumbnail_url
            }
        } | Merge-Template -Template $assetAutoVerifyTemplate
    }
    $result = $templateData | Merge-Template $assetTemplate
    Set-HuduAsset -id $hAss.id -CompanyId $hAss.company_id -Fields @{ 'axcient_x360recover' = $result } | Out-Null
}
# Config must be passed to activity
function Update-MagicDash {
    param(
        $client,
        $huduCompany,
        $huduServers,
        $huduWorkstations,
        $devices
    )
    $d2c = $client.devices_counters.d2c | select -ExpandProperty Count | measure-object -Sum | select -expandproperty Sum
    $appliance = $client.devices_counters.appliance_based | select -ExpandProperty Count | measure-object -Sum | select -expandproperty Sum
   $templateData = @{
        name = $client.name
        health_status = $client.health_status
        ab_server = $client.devices_counters.appliance_based | ? type -eq 'SERVER' | select -ExpandProperty Count
        ab_workstation = $client.devices_counters.appliance_based | ? type -eq 'WORKSTATION' | select -ExpandProperty Count
        d2c_server = $client.devices_counters.d2c | ? type -eq 'SERVER' | select -ExpandProperty Count
        d2c_workstation = $client.devices_counters.d2c | ? type -eq 'WORKSTATION' | select -ExpandProperty Count
        ar_server = $client.devices_counters.cloud_archive | ? type -eq 'SERVER' | select -ExpandProperty Count
        ar_workstation = $client.devices_counters.cloud_archive | ? type -eq 'WORKSTATION' | select -ExpandProperty Count
        client_link = "https://my.axcient.net/home/client/$($client.id)"
        warning_devices = $devices | where { $_.current_health_status.status -ne 'NORMAL' } | sort type,name | New-DeviceDashStatusTable -huduServers $huduServers -huduWorkstations $huduWorkstations
        server_devices = $devices | where { $_.type -eq 'SERVER' } | sort name | New-DeviceDashStatusTable -huduServers $huduServers -huduWorkstations $huduWorkstations
        workstation_devices = $devices | where { $_.type -eq 'WORKSTATION' }  | sort name | New-DeviceDashStatusTable -huduServers $huduServers -huduWorkstations $huduWorkstations
        appliances = New-ApplianceDashBlock -client $client
        last_update = (Get-Date).ToString("dd MMM yyyy h:mm tt")
        time_zone = (Get-TimeZone).DisplayName
    }
    $magicDashContent = Merge-Template -Template $magicDashTemplate -Parameters $templateData
    # Create the magic dash
    $mdSplash = @{
        CompanyName = $huduCompany.name
        Title       = 'Axcient X360Recover'
        Message     = "<strong>{0}</strong><br />Appliance: {1}<br />D2C: {2}" -f $client.health_status, $appliance, $d2c
        Shade       = $client.health_status -eq 'NORMAL' ? $config.styling.dashHealthy : $config.styling.dashWarning
        Content     = $magicDashContent
        ImageUrl    = "https://dwpxs7qy0kohm.cloudfront.net/favicon.ico"
        #Icon        = 'fa-solid fa-floppy-disk'
    }
    Set-HuduMagicDash @mdSplash | Out-Null
}
#endregion ----------- FUNCTIONS -----------
#region ----------- TEMPLATES -----------
Set-Variable -Name assetAutoVerifyTemplate -Value @'
<details class="mce-accordion">
    <summary>{{timestamp}}</summary>
    <div classs="card__item">
        <div class="card__item-slot">Status</div>
        <div class="card__item-slot">{{status}}</div>
    </div>
    <div classs="card__item">
        <div class="card__item-slot">Start</div>
        <div class="card__item-slot">{{start}}</div>
    </div>
    <div classs="card__item">
        <div class="card__item-slot">End</div>
        <div class="card__item-slot">{{end}}</div>
    </div>
    <div classs="card__item">
        <div class="card__item-slot">Screenshot</div>
        <a href="{{screenshot_url}}" target=_blank>
            <img src="{{screenshot_thumbnail_url}}" />
        </a>
    </div>
</details>
'@
Set-Variable -Name assetJobTemplate -Value @'
<details class="mce-accordion" {{jobOpen}}>
    <summary>{{name}}</summary>
    <button class="button" style="background-color: var(--primary)" role="button">
        <a style="color: white;" role="button" href="https://my.axcient.net/home/job/{{id}}" target="_blank" title="Open job {{name}} in Axcient x360Recover portal">
            Open job in x360Recover
            &nbsp;<i class="fa-solid fa-up-right-from-square">&nbsp;</i>
        </a>
    </button>
    <div class="nasa__content">
        <div class="nasa__block">
            <div class="card__item">
                <div class="card__item-slot">Type</div>
                <div class="card__item-slot">{{type}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Destination</div>
                <div class="card__item-slot">{{destination}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Description</div>
                <div class="card__item-slot">{{description}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Status</div>
                <div class="card__item-slot">{{enabled}} - {{health_status}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Last run</div>
                <div class="card__item-slot">{{last_run}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Schedule Name</div>
                <div class="card__item-slot">{{schedule_name}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Schedule Description</div>
                <div class="card__item-slot">{{schedule_description}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Schedule Type</div>
                <div class="card__item-slot">{{schedule_type}}</div>
            </div>
        </div>
        <div class="nasa__block">
            <div class="card__item">
                <div class="card__item-slot">Schedule Status</div>
                <div class="card__item-slot">{{schedule_status}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Schedule Offset</div>
                <div class="card__item-slot">{{schedule_offset}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Schedule - Business Hours</div>
                <div class="card__item-slot">{{schedule_businessHours}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Schedule - After Hours</div>
                <div class="card__item-slot">{{schedule_nbHours}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Throttling</div>
                <div class="card__item-slot">{{throttling}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Throttling - Business Hours</div>
                <div class="card__item-slot">{{throttling_business}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot"> Throttling - After Hours</div>
                <div class="card__item-slot">{{throttling_nb}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Replication Info</div>
                <div class="card__item-slot">{{replication_info}}</div>
            </div>        
        </div>
    </div>
    <h2>Replication Schedule</h2>
    <pre>{{replication_schedule}}</pre>
</details>
'@
Set-Variable -Name assetTemplate -Value @'
<div class="nasa__content">
    <div class="nasa__block" style="margin-bottom:20px;height:auto">
        <header class="nasa__block-header">
            <h1>
                <img src="https://dwpxs7qy0kohm.cloudfront.net/favicon.ico" style="vertical-align: middle;" />
                Axcient x360Recover
            </h1>
        </header>
        <div style="padding-left: 15px; padding-right: 15px; padding-bottom: 15px;">
            <div class="card__item">
                <button class="button" style="background-color: var(--primary)" role="button">
                    <a style="color: white;" role="button" href="{{axcient_url}}" target="_blank" title="Open {name} in x360Recover portal">
                        Open in x360Recover
                        &nbsp;<i class="fa-solid fa-up-right-from-square">&nbsp;</i>
                    </a>
                </button>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Name</div>
                <div class="card__item-slot">{{name}}</div>
            </div>
            <div class="card__item" style="{{errStyle}}">
                <div class="card__item-slot">Status</div>
                <div class="card__item-slot">{{status}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Replication Type</div>
                <div class="card__item-slot">{{replication_type}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Last local backup</div>
                <div class="card__item-slot">{{last_local_backup}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Local usage</div>
                <div class="card__item-slot">{{local_usage}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Last cloud backup</div>
                <div class="card__item-slot">{{last_cloud_backup}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Cloud usage</div>
                <div class="card__item-slot">{{cloud_usage}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Protected volumes</div>
                <div class="card__item-slot">{{volumes}}</div>
            </div>
            <div class="card__item">
                <div class="card__item-slot">Last Hudu sync</div>
                <div class="card__item-slot">{{last_update}}</div>

            </div>
        </div>
    </div>
    <div class="nasa__block" style="margin-bottom:20px;height:auto">
        <header class="nasa__block-header">
            <h1><i class="fa-solid fa-person-digging">&nbsp;</i>Backup Jobs</h1>
        </header>
        {{jobs}}
    </div>
    <div class="nasa__block" style="margin-bottom:20px;height:auto">
        <header class="nasa__block-header">
            <h1><i class="fa-solid fa-check">&nbsp;</i>Autoverify</h1>
            <h2>(Latest 3)</h2>
        </header>
        {{dav}}
    </div>
</div>
'@
Set-Variable -Name magicdashTemplate -Value @'
<div class="nasa__content">
    <div class="nasa__block">
        <header class="nasa__block-header">
            <h1><i class='fas fa-info-circle icon'></i>Basic Info</h1>
        </header>
        <main>
            <button class="button" style="background-color: var(--primary)" role="button"><a style="color: white;"
                    role="button" href="{{client_link}}" target="_blank"><i class="fas fa-server me-2"></i>Axcient
                    Portal</a>
            </button><br />
            <article>
                <div class='basic_info__section'>
                    <h2>Client Name</h2>
                    <p>
                        {{name}}
                    </p>
                </div>
                <div class='basic_info__section'>
                    <h2>Health Status</h2>
                    <p>
                        {{health_status}}
                    </p>
                </div>
                <div class="basic_info__section">
                    <h2>Hudu sync date</h2>
                    <p>
                        {{last_update}}
                    </p>
                </div>
                <div class="basic_info__section">
                    <h2>Time Zone</h2>
                    <p>
                        {{time_zone}}<br />(All timestamps)
                    </p>
                </div>
            </article>
        </main>
    </div>
    <div class="nasa__block">
        <header class="nasa__block-header">
            <h1><i class='fas fa-server icon'></i>Protected Devices</h1>
        </header>
        <table>
            <thead>
                <tr>
                    <th></th>
                    <th>Server</th>
                    <th>Workstation</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <th>Appliance-Based</th>
                    <td>{{ab_server}}</td>
                    <td>{{ab_workstation}}</td>
                </tr>
                <tr>
                    <th>D2C</th>
                    <td>{{d2c_server}}</td>
                    <td>{{d2c_workstation}}</td>
                </tr>
                <tr>
                    <th>Cloud Archive</th>
                    <td>{{ar_server}}</td>
                    <td>{{ar_workstation}}</td>
                </tr>
            </tbody>
        </table>
        <br />
        <header class="nasa__block-header">
            <h1><i class='fas fa-server icon'></i>Appliances</h1>
        </header>
        {{appliances}}
    </div>
</div>
<div class="nasa__block">
    <header class='nasa__block-header'>
        <h1><i class="fa-solid fa-triangle-exclamation"></i></i>Warnings</h1>
    </header>
    {{warning_devices}}
</div>
<div class="nasa__block">
    <header class='nasa__block-header'>
        <h1><i class="fa-solid fa-server"></i>Servers</h1>
    </header>

    {{server_devices}}

</div>
<div class="nasa__block">
    <header class='nasa__block-header'>
        <h1><i class="fa-solid fa-server"></i>Workstations</h1>
    </header>
    {{workstation_devices}}
</div>
'@
#endregion ----------- TEMPLATES -----------
#region ----------- MAIN EXECUTION -----------


#endregion ----------- MAIN EXECUTION -----------


New-HuduBaseURL $config.huduBaseUrl
New-HuduAPIKey $config.huduAPIKey
Initialize-AxcientAPI -ApiKey $config.axcientAPIKey

$axcientClients, $huduCompanies, $config = Get-InitialSyncData -config $config

return @{
    axcientClients = $axcientClients
    huduCompanies = $huduCompanies
    config = $config
}
