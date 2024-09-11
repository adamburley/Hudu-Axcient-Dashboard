
#requires -Version 7.2
$requiredModules = @(
    @{ Name = 'AxcientAPI'; Version = '0.3.2' }
    @{ Name = 'HuduAPI'   ; Version = '2.50'  }
)

clear
Write-Host "Hudu - Axcient Dashboard Interactive Setup" -ForegroundColor Cyan
Write-Host "------------------------------------------" -ForegroundColor Cyan

# Handle updating the match list
if (Test-Path -Path .\config.json) {
    Find-RequiredModuleVersion -requiredModules $requiredModules -localModulePath $PSScriptRoot\Modules -Interactive | Import-Module
    Write-Host "A configuration file was found. Initiating updating match list." -ForegroundColor Magenta
    Write-Host "If you want to restart setup, rename config.json and rerun this script." -ForegroundColor Yellow
    $config = Get-Content -Path .\config.json | ConvertFrom-Json
    Write-Host "Calling for Axcient clients..." -ForegroundColor Yellow
    Initialize-AxcientAPI -ApiKey $config.axcientAPIKey
    $axcientClients = Get-Client -ErrorAction Stop | Sort-Object name
    Write-Host "Calling for Hudu companies...`n" -ForegroundColor Yellow
    New-HuduBaseURL -BaseURL $config.huduBaseUrl -ErrorAction Stop
    New-HuduAPIKey -ApiKey $config.huduAPIKey -ErrorAction Stop
    $huduCompanies = Get-HuduCompanies | sort name

    Write-Host "Retrieved " -ForegroundColor Yellow -NoNewline
    Write-Host $huduCompanies.Count -ForegroundColor Green -NoNewline
    Write-Host " companies from Hudu and " -ForegroundColor Yellow -NoNewline
    Write-Host $axcientClients.Count -ForegroundColor Green -NoNewline
    Write-Host " clients from Axcient.`n" -ForegroundColor Yellow

    $config = Update-CompanyMatches -Config $config -AxcientClients $axcientClients -HuduCompanies $huduCompanies -Update
    Write-Host "Match list updated, now $($config.matches.Count) matched companies." -ForegroundColor Green
    $config | ConvertTo-Json | Out-File -FilePath .\config.json
    continue
}

# New config file setup
Write-Host "
This interactive setup will guide you through configuration options for the main
Hudu - Axcient Dashboard sync script, including hard-matching your current
companies in Axcient and Hudu.

A JSON file stores configuration data by default, however you may override this
by modifying run.ps1 (Under HuduAxcientDashboard-Starter for Azure Function
deployment) to use environment variables or other methods.
" -ForegroundColor Yellow
Write-Host "`nTIP: " -ForegroundColor Red -NoNewline
Write-Host "Use CTRL + SHIFT + V to paste into console prompts." -ForegroundColor Yellow

Write-host "`n------- Required Modules -------`n" -ForegroundColor Magenta
Write-Host "Both setup and execution scripts require PowerShell Modules.`nThey can be installed to the system or saved to a Modules path.`n" -ForegroundColor Yellow

Find-RequiredModuleVersion -requiredModules $requiredModules -localModulePath $PSScriptRoot\Modules -Interactive | Import-Module

Write-Host "`n------- Hudu Setup -------`n" -ForegroundColor Magenta

$config = [PSCustomObject][Ordered]@{
    createMagicDash          = $true
    updateDeviceAssets       = $true
    serverAssetLayoutId      = $null
    workstationAssetLayoutId = $null
    huduBaseUrl              = $null
    huduAPIKey               = $null
    axcientAPIKey            = $null
    autoMatch                = $true
    matches                  = @()
}

$config.huduBaseUrl = Read-Host -Prompt "Enter your Hudu URL (e.g. https://hudu.example.com)"
Write-Host "`nEnter your Hudu API key below. If you have not yet created one, click this link to add a key: " -ForegroundColor Yellow
Write-Host "`n$($config.huduBaseUrl)/admin/api_keys/new`n" -ForegroundColor Blue

$config.huduAPIKey = Read-Host -Prompt "Enter your Hudu API Key"

New-HuduBaseURL -BaseURL $config.huduBaseUrl -ErrorAction Stop
New-HuduAPIKey -ApiKey $config.huduAPIKey -ErrorAction Stop

if (-not (Get-HuduAppInfo)) { Write-Host "Something went wrong with the Hudu connection. Check your information and rerun setup." -ForegroundColor Red; continue }

Write-Host "`n------- Hudu Sync Destinations -------" -ForegroundColor Magenta

Write-Host "
Two sync options are available:
    - A Magic Dash with an overview of backup status, list of
      protected devices and links to those devices.
    - Data added to each server or workstation asset with a summary status as
      well as additional device-specific data.

You may choose one or both options. If you choose to sync into assets, a custom
asset layout field will be added at the top of both server and workstation asset
layouts.
" -ForegroundColor Yellow

$config.createMagicDash = (Read-Host -Prompt 'Magic Dash summary? (Y/n)' ) -in 'y', ''
$config.updateDeviceAssets = (Read-Host -Prompt 'Update asset data? (Y/n)') -in 'y', ''

$assetLayouts = Get-HuduAssetLayouts

Write-Host "`nSpecify asset layout for Server and Workstation assets below.`nThis is needed even if only creating a Magic Dash at this time." -ForegroundColor Yellow

do {
    $assetLayouts | sort name | ft id, name
    $config.serverAssetLayoutId = Read-Host -Prompt 'Enter the ID of the Server Asset Layout'
    Write-Host "You selected " -ForegroundColor Yellow -NoNewline
    Write-host ($assetLayouts | ? id -eq $config.serverAssetLayoutId).name -ForegroundColor Green -NoNewline
    Write-Host ". Is this correct? Y/n: " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host
    if ($confirm -ne 'y') {
        $config.serverAssetLayoutId = $null
    }
} while ($null -eq $config.serverAssetLayoutId)

do {
    $assetLayouts | sort name | ft id, name
    $config.workstationAssetLayoutId = Read-Host -Prompt 'Enter the ID of the Workstation Asset Layout. It may be the same as the Server layout'
    Write-Host "You selected " -ForegroundColor Yellow -NoNewline
    Write-host ($assetLayouts | ? id -eq $config.workstationAssetLayoutId).name -ForegroundColor Green -NoNewline
    Write-Host ". Is this correct? Y/n: " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host
    if ($confirm -ne 'y') {
        $config.workstationAssetLayoutId = $null
    }
} while ($null -eq $config.workstationAssetLayoutId)

if ($config.updateDeviceAssets) {
    Write-Host "`nCreating custom fields for asset layouts..." -ForegroundColor Cyan
    Add-HuduAssetLayoutField -AssetLayoutId $config.serverAssetLayoutId | Out-Null
    Add-HuduAssetLayoutField -AssetLayoutId $config.workstationAssetLayoutId | Out-Null
}

Write-Host "`n------- Axcient Setup -------`n" -ForegroundColor Magenta
Write-Host "If you have not yet created an API Key, click this link to add a key:`n" -ForegroundColor Yellow
Write-Host "https://partner.axcient.com/settings/api-keys" -ForegroundColor Blue
$config.axcientAPIKey = Read-Host -Prompt "`nEnter your Axcient API Key"

Initialize-AxcientAPI -ApiKey $config.axcientAPIKey
$axcientClients = Get-Client -ErrorAction Stop | Sort-Object name

Write-Host "`n------ Client Matching ------`n" -ForegroundColor Magenta

Write-Host "Calling for Hudu companies...`n" -ForegroundColor Yellow
$huduCompanies = Get-HuduCompanies | sort name

Write-Host "Retrieved " -ForegroundColor Yellow -NoNewline
Write-Host $huduCompanies.Count -ForegroundColor Green -NoNewline
Write-Host " companies from Hudu and " -ForegroundColor Yellow -NoNewline
Write-Host $axcientClients.Count -ForegroundColor Green -NoNewline
Write-Host " clients from Axcient.`n" -ForegroundColor Yellow

$config = Update-CompanyMatches -Config $config -AxcientClients $axcientClients -HuduCompanies $huduCompanies

Write-Host "Enable Automatch? Automatch will execute on each run and attempt to match by exact name unmatched Clients in Axcient. This will not override or update your hard matches. (Y/n): " -ForegroundColor Yellow -NoNewline
$config.autoMatch = (Read-Host) -in 'y', ''

Write-Host "`n------- Summary -------`n" -ForegroundColor Magenta
Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host "Hudu Base URL:".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.huduBaseUrl -ForegroundColor Green
Write-Host "Hudu API Key:".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.huduAPIKey -ForegroundColor Green
Write-Host "Axcient API Key:".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.axcientAPIKey -ForegroundColor Green
Write-Host "Create Magic Dash:".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.createMagicDash -ForegroundColor Green
Write-Host "Update Server Assets:".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.updateDeviceAssets -ForegroundColor Green
Write-Host "Server Asset Layout ID:".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.serverAssetLayoutId -ForegroundColor Green
Write-Host "Workstation Asset Layout ID:".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.workstationAssetLayoutId -ForegroundColor Green
Write-Host "Automatch:".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.autoMatch -ForegroundColor Green
Write-Host "Matched Companies".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.matches.Count -ForegroundColor Green

$config | ConvertTo-Json | Out-File -FilePath $PSScriptRoot\config.json

Write-Host "Config file saved to $($PSScriptRoot)\config.json" -ForegroundColor Green
Write-Host "For stand-alone execution, place config.json in the same path as run.ps1. For function app, place next to run.ps1 under HuduAxcientDashboard-Starter." -ForegroundColor Yellow

Write-Host "`nSetup complete. Press any key to exit." -ForegroundColor Cyan
pause