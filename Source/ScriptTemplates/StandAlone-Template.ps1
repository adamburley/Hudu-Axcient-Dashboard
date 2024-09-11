Find-RequiredModuleVersion -requiredModules $requiredModules -localModulePath '.\Modules' | Import-Module

$config = Get-Content -Path '.\config.json' | ConvertFrom-Json

Write-Host "Connecting to Hudu at $($config.huduBaseUrl)" -ForegroundColor Cyan

New-HuduBaseURL $config.huduBaseUrl
New-HuduAPIKey $config.huduAPIKey
Initialize-AxcientAPI -ApiKey $config.axcientAPIKey

$axcientClients, $huduCompanies, $config = Get-InitialSyncData -config $config

$start = Get-date
$unMatchedClients = @()
foreach ($client in $axcientClients) {
    if ($match = $config.matches | where { $_.axcientId -eq $client.id }) {
        Write-Host "Match found for $($client.name) with $($match.name)" -ForegroundColor Cyan
        Invoke-ProcessCompany -client $client -match $match -huduCompanies $huduCompanies -config $config
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