function Invoke-ProcessCompany {
    param(
        $client,
        $match,
        $huduCompanies,
        $config
    )   
    $huduCompany = $huduCompanies | Where-Object id -eq $match.huduID

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
        $devices | ForEach-Object {
            Write-Host "Updating asset for $($_.name)"
            Update-DeviceAsset -device $_ -huduServers $huduServers -huduWorkstations $huduWorkstations 
        }
    }
    else {
        Write-Host "Device asset update is disabled"
    }
}