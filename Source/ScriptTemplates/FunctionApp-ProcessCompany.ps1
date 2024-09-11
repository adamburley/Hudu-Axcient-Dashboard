param($companyData)

#--split

Write-Host "Starting processing for $($companyData.client.name)" -ForegroundColor Yellow
New-HuduBaseURL $companyData.config.huduBaseUrl
New-HuduAPIKey $companyData.config.huduAPIKey
Initialize-AxcientAPI -ApiKey $companyData.config.axcientAPIKey

$match = $companyData.config.matches | where { $_.axcientId -eq $companyData.client.id }

try {
    if ($match) {
        Write-Host "Match found for $($companyData.client.name) with $($match.name)" -ForegroundColor Cyan
        Invoke-ProcessCompany -client $companyData.client -match $match -huduCompanies $companyData.huduCompanies -config $companyData.config
        Return "Updated $($companyData.client.name)"
    }
    else {
        Return "No match found: $($companyData.client.name)"
    }
}
catch {
    Write-Host "Error processing $($companyData.client.name): $_" -ForegroundColor Red
    Return "Error processing $($companyData.client.name)"
}