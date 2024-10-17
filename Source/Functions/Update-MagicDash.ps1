function Update-MagicDash {
    param(
        $client,
        $huduCompany,
        $huduServers,
        $huduWorkstations,
        $devices
    )
    $d2c       = $client.devices_counters.d2c             | Select-Object -ExpandProperty Count | measure-object -Sum | Select-Object -ExpandProperty Sum
    $appliance = $client.devices_counters.appliance_based | Select-Object -ExpandProperty Count | measure-object -Sum | Select-Object -ExpandProperty Sum
    $templateData = @{
        name                = $client.name
        health_status       = $client.health_status
        ab_server           = $client.devices_counters.appliance_based | Where-Object type -eq 'SERVER'      | Select-Object -ExpandProperty Count
        ab_workstation      = $client.devices_counters.appliance_based | Where-Object type -eq 'WORKSTATION' | Select-Object -ExpandProperty Count
        d2c_server          = $client.devices_counters.d2c             | Where-Object type -eq 'SERVER'      | Select-Object -ExpandProperty Count
        d2c_workstation     = $client.devices_counters.d2c             | Where-Object type -eq 'WORKSTATION' | Select-Object -ExpandProperty Count
        ar_server           = $client.devices_counters.cloud_archive   | Where-Object type -eq 'SERVER'      | Select-Object -ExpandProperty Count
        ar_workstation      = $client.devices_counters.cloud_archive   | Where-Object type -eq 'WORKSTATION' | Select-Object -ExpandProperty Count
        client_link         = "https://my.axcient.net/home/client/$($client.id)"
        warning_devices     = $devices | Where-Object { $_.current_health_status.status -ne 'NORMAL' } | Sort-Object type, name | New-DeviceDashStatusTable -huduServers $huduServers -huduWorkstations $huduWorkstations
        server_devices      = $devices | Where-Object { $_.type -eq 'SERVER' }                         | Sort-Object name       | New-DeviceDashStatusTable -huduServers $huduServers -huduWorkstations $huduWorkstations
        workstation_devices = $devices | Where-Object { $_.type -eq 'WORKSTATION' }                    | Sort-Object name       | New-DeviceDashStatusTable -huduServers $huduServers -huduWorkstations $huduWorkstations
        appliances          = New-ApplianceDashBlock -client $client
        last_update         = (Get-Date).ToString("dd MMM yyyy h:mm tt")
        time_zone           = (Get-TimeZone).DisplayName
    }
    $magicDashContent = Merge-Template -Template $magicDashTemplate -Parameters $templateData
    # Create the magic dash
    $mdSplash = @{
        CompanyName = $huduCompany.name
        Title       = 'Axcient X360Recover'
        Message     = "<strong>{0}</strong><br />Appliance: {1}<br />D2C: {2}" -f $client.health_status, $appliance, $d2c
        Shade       = $client.health_status -eq 'NORMAL' ? $config.styling.dashHealthy : $config.styling.dashWarning # Requires access to $config variable from script-scope
        Content     = $magicDashContent
        ImageUrl    = "https://dwpxs7qy0kohm.cloudfront.net/favicon.ico"
    }
    Set-HuduMagicDash @mdSplash | Out-Null
}