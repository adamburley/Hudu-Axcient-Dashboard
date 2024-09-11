param($Timer)
#--split
# Option 1: File Path
# This handles for both hard-coded config file parameters and environment variables + Data Table
$config = Get-Content -Path $PSScriptRoot\config.json -Raw

# Option 2: Environment & Hard coded values
# NOTE: You can double-encode JSON to store client matches in an environment variable.
# Environment variables are good for up to around 800 clients. There is a
# 50,000 character limit for environment variables which you may hit eventually.

# matches is an array of objects. with name, axcientId, and huduID properties.
# see sample-config.json if needed.
<#
$config = [PSCustomObject][Ordered]@{
    createMagicDash          = $env:HuduAxcientCreateMagicDash
    updateDeviceAssets       = $env:HuduAxcientUpdateDeviceAssets
    serverAssetLayoutId      = $env:HuduAxcientServerAssetLayoutId
    workstationAssetLayoutId = $env:HuduAxcientWorkstationAssetLayoutId
    huduBaseUrl              = $env:HUDU_BASE_URL
    huduAPIKey               = $env:HUDU_API_KEY
    axcientAPIKey            = $env:AXCIENT_API_KEY
    autoMatch                = $true
    matches                  = @()
} | ConvertTo-Json -Compress
#>

#requires -Version 7.2
#requires -Modules @{ ModuleName = 'AxcientAPI'; ModuleVersion = '0.3.2' }
#requires -Modules @{ ModuleName = 'HuduAPI'   ; ModuleVersion = '2.50'  }

if (-not $config) {
    Write-Host "No configuration found. Exiting."
    exit 1
}
else {
    $configObject = $config | ConvertFrom-Json

    Write-Host "Configuration loaded."
    Write-Host ($config | convertfrom-json | select -ExcludeProperty *key | fl | out-string)

    $InstanceId = Start-DurableOrchestration -FunctionName 'HuduAxcientDashboard-Orchestrator' -InputObject $config
    Write-Host "Started orchestration with ID = '$InstanceId'"
}