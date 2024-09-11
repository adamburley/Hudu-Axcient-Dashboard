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