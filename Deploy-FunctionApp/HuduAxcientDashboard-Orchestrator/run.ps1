param($Context)


<# 
    Script Name: Hudu-Axcient Backup Dashboard
    URL: 
    Copywrite: Adam Burley 2024
    Version: 1.0
#>
#requires -Version 7.2


$config = $Context.Input | ConvertFrom-Json

$initialData = Invoke-DurableActivity -FunctionName 'HuduAxcientDashboard-GetInitialData' -Input $config
Write-Host "Initial data loaded."
if (-not $initialData) {
    Write-Host "No initial data found. Exiting."
}
else {
    $config = $initialData.config
    $axcientClients = $initialData.axcientClients
    $huduCompanies = $initialData.huduCompanies

    Write-Host "Processing data for $($axcientClients.Count) clients against $($huduCompanies.Count) companies, using $($config.matches.count) matches."

    $results = foreach ($client in $axcientClients) {
        $companyData = [PSCustomObject]@{ 
            config        = $config
            client        = $client
            huduCompanies = $huduCompanies
        } | ConvertTo-Json -Depth 10 -Compress
        Invoke-DurableActivity -FunctionName 'HuduAxcientDashboard-ProcessCompany' -Input $companyData #-NoWait
    }

    #Wait-ActivityFunction -Task $ParallelTasks
    Write-Host "FINAL RESULTS`n $($results | Out-string)"
}
