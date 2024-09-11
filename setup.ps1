. .\Source\Functions\Update-CompanyMatches.ps1
. .\Source\Functions\Add-HuduAssetLayoutField.ps1

Write-Host "Hudu - Axcient Dashboard Interactive Setup" -ForegroundColor Cyan
Write-Host "------------------------------------------" -ForegroundColor Cyan
if (Test-Path -Path .\config.json) {
    Write-Host "A configuration file was found. Defaulting to updating match list." -ForegroundColor Magenta
    Write-Host "To restart setup, rename config.json and rerun this script." -ForegroundColor Yellow
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
Write-Host "`nThis script will guide you through configuring options." -ForegroundColor Yellow
Write-Host "Press Ctrl + C at any time to exit." -ForegroundColor Yellow
Write-Host "`nTIP: " -ForegroundColor Red -NoNewline
Write-Host "Use CTRL + SHIFT + V to paste into console prompts." -ForegroundColor Yellow

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
Write-Host "If you have not yet created an API Key, click this link to add a key: " -NoNewline -ForegroundColor Yellow
Write-Host "$($config.huduBaseUrl)/admin/api_keys/new " -ForegroundColor Blue -NoNewline
Write-Host "No extra permissions are required." -ForegroundColor Yellow
Write-Host "Enter your API Key: " -ForegroundColor Yellow -NoNewline
$config.huduAPIKey = Read-Host

New-HuduBaseURL -BaseURL $config.huduBaseUrl -ErrorAction Stop
New-HuduAPIKey -ApiKey $config.huduAPIKey -ErrorAction Stop

Write-Host "Do you want to create and update a Magic Dash for each client with a status summary? (Y/n): " -ForegroundColor Yellow -NoNewline
$config.createMagicDash = (Read-Host) -in 'y', ''

Write-Host "Do you want to create and update a summary status in each server and workstation asset? This will add a custom field at the top of the asset layout(s). (Y/n): " -ForegroundColor Yellow -NoNewline
$config.updateDeviceAssets = (Read-Host) -in 'y', ''

$assetLayouts = Get-HuduAssetLayouts

Write-Host "Server and Workstation asset layout IDs are required for link creation and updating asset data (if selected)." -ForegroundColor Cyan

do {
    $assetLayouts | sort name | ft id, name
    Write-Host "Enter the ID of the Server Asset Layout" -ForegroundColor Yellow
    $config.serverAssetLayoutId = Read-Host
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
    Write-Host "Enter the ID of the Workstation Asset Layout" -ForegroundColor Yellow
    $config.workstationAssetLayoutId = Read-Host
    Write-Host "You selected " -ForegroundColor Yellow -NoNewline
    Write-host ($assetLayouts | ? id -eq $config.serverAssetLayoutId).name -ForegroundColor Green -NoNewline
    Write-Host ". Is this correct? Y/n: " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host
    if ($confirm -ne 'y') {
        $config.workstationAssetLayoutId = $null
    }
} while ($null -eq $config.workstationAssetLayoutId)

if ($config.updateDeviceAssets) {
    Write-Host "Creating custom fields for asset layouts..." -ForegroundColor Yellow
    Add-HuduAssetLayoutField -AssetLayoutId $config.serverAssetLayoutId | Out-Null
    Add-HuduAssetLayoutField -AssetLayoutId $config.workstationAssetLayoutId | Out-Null
}

Write-Host "`n------- Axcient Setup -------`n" -ForegroundColor Magenta
Write-Host "If you have not yet created an API Key, click this link to add a key: " -NoNewline -ForegroundColor Yellow
Write-Host "https://partner.axcient.com/settings/api-keys" -ForegroundColor Blue
Write-Host "Enter your Axcient API Key: " -ForegroundColor Yellow -NoNewline
$config.axcientAPIKey = Read-Host

Initialize-AxcientAPI -ApiKey $config.axcientAPIKey
$axcientClients = Get-Client -ErrorAction Stop | Sort-Object name
Write-Host "Calling for Hudu companies...`n" -ForegroundColor Yellow
$huduCompanies = Get-HuduCompanies | sort name

Write-Host "Retrieved " -ForegroundColor Yellow -NoNewline
Write-Host $huduCompanies.Count -ForegroundColor Green -NoNewline
Write-Host " companies from Hudu and " -ForegroundColor Yellow -NoNewline
Write-Host $axcientClients.Count -ForegroundColor Green -NoNewline
Write-Host " clients from Axcient.`n" -ForegroundColor Yellow

Write-Host "`n------ Client Matching ------`n" -ForegroundColor Magenta

Write-Host "Enable Automatch? Automatch will execute on each run and attempt to match by exact name unmatched Clients in Axcient. This will not override or update your hard matches. (Y/n): " -ForegroundColor Yellow -NoNewline
$config.autoMatch = (Read-Host) -in 'y', ''


$config = Update-CompanyMatches -Config $config -AxcientClients $axcientClients -HuduCompanies $huduCompanies

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
Write-Host "Matched Companies".PadRight(20) -ForegroundColor Yellow -NoNewline
Write-Host $config.matches.Count -ForegroundColor Green

$config | ConvertTo-Json | Out-File -FilePath .\config.json