
foreach ($file in Get-ChildItem -Path .\Source\Functions\*.ps1) {
    . $file.FullName
}
foreach ($file in Get-ChildItem -Path .\Source\Templates\*.html) {
    Set-Variable -Name $file.BaseName -Value (Get-Content -Path $file.FullName -Raw)
}

$config = Get-ConfigData -Path .\config.json
New-HuduBaseURL $config.huduBaseUrl
New-HuduAPIKey $config.huduAPIKey
Initialize-AxcientAPI -ApiKey $config.axcientAPIKey

$axcientClients, $huduCompanies, $config = Get-InitialSyncData -config $config

$start = Get-date
$unMatchedClients = @()
foreach ($client in $axcientClients | where { $_.name -ilike "*duramax*"}) {
    if ($match = $config.matches | where { $_.axcientId -eq $client.id }) {
        Write-Host "Match found for $($client.name) with $($match.name)" -ForegroundColor Cyan
        $huduCompany = $huduCompanies | where { $_.id -eq $match.huduID }
        $huduServers, $huduWorkstations, $devices = Get-DashSyncAssets -companyId $huduCompany.id -axcientClient $client
        #$huduServers = Get-HuduAssets -AssetLayoutId $config.serverAssetLayoutId -CompanyID $huduCompany.id
        Write-Host "Retrieved $($huduServers.Count) servers for $($huduCompany.name)" -ForegroundColor Yellow
        #$huduWorkstations = Get-HuduAssets -AssetLayoutId $config.workstationAssetLayoutId -CompanyID $huduCompany.id
        Write-Host "Retrieved $($huduWorkstations.Count) workstations for $($huduCompany.name)" -ForegroundColor Yellow
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
    else {
        Write-Host "No match found for $($client.name)"
        $unMatchedClients += $client.name
    }
}
$end = get-date
New-TimeSpan -Start $start -End $end

Write-Host "These clients in Axcient were not matched to a company in Hudu:"
$unMatchedClients | ForEach-Object { Write-Host $_ }