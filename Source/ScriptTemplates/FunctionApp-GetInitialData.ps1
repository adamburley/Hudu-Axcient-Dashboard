param($config)
#--split
New-HuduBaseURL $config.huduBaseUrl
New-HuduAPIKey $config.huduAPIKey
Initialize-AxcientAPI -ApiKey $config.axcientAPIKey

$axcientClients, $huduCompanies, $config = Get-InitialSyncData -config $config

return @{
    axcientClients = $axcientClients
    huduCompanies = $huduCompanies
    config = $config
}