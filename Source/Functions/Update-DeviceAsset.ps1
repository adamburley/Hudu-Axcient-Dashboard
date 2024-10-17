function Update-DeviceAsset {
    param($device, $huduServers, $huduWorkstations)
    $hAss = $device.Type -eq 'SERVER' ? ($huduServers | Where-Object name -eq $device.name) : $huduWorkstations | Where-Object name -eq $device.name
    if (-not $hAss) {
        $nShort = $device.name -split '\.' | Select-Object -First 1
        $hAss = $device.Type -eq 'SERVER' ? ($huduServers | Where-Object name -eq $nShort) : $huduWorkstations | Where-Object name -eq $nShort
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
    $dav = Get-DeviceAutoVerify -Device $device | Select-Object -first 1 | Select-Object -expandproperty autoverify_details | Sort-Object timestamp -Descending | Select-Object -first 3
    $templateData = @{
        axcient_url       = $device.device_details_page_url
        name              = $device.name
        status            = $device.current_health_status.status
        errStyle          = $device.current_health_status.status -eq 'NORMAL' ? '' : "background-color: #fcd1d3"
        replication_type  = $device.d2c ? 'D2C' : 'Appliance'
        last_local_backup = $device.latest_local_rp ? $device.latest_local_rp : ''
        local_usage       = $device.local_usage ? "$([math]::round($device.local_usage/1gb,1)) GB" : ''
        last_cloud_backup = $device.latest_cloud_rp ? $device.latest_cloud_rp : ''
        cloud_usage       = $device.cloud_usage ? "$([math]::round($device.cloud_usage/1gb,1)) GB" : ''
        volumes           = $device.volumes -join "<br />"
        last_update       = (Get-Date).ToString()
        jobs              = $jobs | ForEach-Object {
            # some jobs have different schedules - possibly offsite = true
            $schedule = $_.schedule | ConvertFrom-Json -Depth 10
            $scheduleStatus = $schedule.isEnabled ? 'Enabled' : 'Disabled'
            $scheduleStatus += $schedule.isDefault ? ', Default' : ''
            $busAllowFull = $schedule.backup.businessHours.allowFull ? 'Full / Incremental' : 'Incremental only'
            $nbAllowFull = $schedule.backup.nonBusinessHours.allowFull ? 'Full / Incremental' : 'Incremental only'
            @{
                jobOpen                = $jobOpen
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
                schedule_status        = $scheduleStatus
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
        
        dav               = $dav | ForEach-Object {
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