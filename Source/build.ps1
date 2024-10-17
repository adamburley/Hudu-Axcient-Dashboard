function Join-SourceItems {
    param (
        $Items,
        $Wraparound
    )
    if ($Wraparound) {
        if (Test-Path -Path $Wraparound) {
            $start, $end = (Get-Content -Path $Wraparound -Raw) -split '#--split'
        }
        else {
            $start, $end = $Wraparound -split '#--split'
        }
    }
    $result = @()
    $result += $start
    foreach ($item in $Items) {
        if (Test-Path $item){
            $result += Get-Content -Path $item -Raw
        }
        else { $result += $item}
    }
    $result += $end
    ($result -join "`n`n").Trim()
}

# Templated data at the top of the file
$scriptHeader = @'
<# 
    Hudu-Axcient Dashboard
    https://github.com/adamburley/Hudu-Axcient-Dashboard
    Copywrite: Adam Burley 2024
    Version: 1.1
#>
#requires -Version 7.2
'@

$modules = @'
$requiredModules = @(
    @{ Name = 'AxcientAPI'; Version = '0.3.2' }
    @{ Name = 'HuduAPI'   ; Version = '2.50'  }
)
'@

$endRegion = '#endregion ----------- MAIN EXECUTION -----------'

$functionsAndTemplates = [System.Text.StringBuilder]::new()
$functionsAndTemplates.AppendLine('#region ----------- FUNCTIONS -----------') | Out-Null
foreach ($file in Get-ChildItem -Path .\Source\Functions\*.ps1) {
    $functionsAndTemplates.AppendLine((Get-Content -Path $file.FullName -Raw)) | Out-Null
}
$functionsAndTemplates.AppendLine('#endregion ----------- FUNCTIONS -----------') | Out-Null
$functionsAndTemplates.AppendLine('#region ----------- TEMPLATES -----------') | Out-Null

foreach ($file in Get-ChildItem -Path .\Source\HTMLTemplates\*.html) {
    $functionsAndTemplates.AppendLine("Set-Variable -Name $($file.BaseName) -Value @'") | Out-Null
    $functionsAndTemplates.AppendLine((Get-Content -Path $file.FullName -Raw)) | Out-Null
    $functionsAndTemplates.AppendLine("'@") | Out-Null
}

$functionsAndTemplates.AppendLine('#endregion ----------- TEMPLATES -----------') | Out-Null
$functionsAndTemplates.AppendLine('#region ----------- MAIN EXECUTION -----------') | Out-Null
$functionsAndTemplates = $functionsAndTemplates.ToString()

# Setup file (both stand-alone and function app)

$setupContent = Join-SourceItems $scriptHeader, $modules, $functionsAndTemplates, '.\Source\ScriptTemplates\Setup-Template.ps1', $endRegion
$setupContent | Out-File -FilePath .\Deploy-StandAlone\setup.ps1
$setupContent | Out-File -FilePath .\Deploy-FunctionApp\setup.ps1

# Stand-alone file

Join-SourceItems $scriptHeader, $modules, $functionsAndTemplates, '.\Source\ScriptTemplates\StandAlone-Template.ps1', $endRegion | Out-File -FilePath .\Deploy-StandAlone\run.ps1

# Function app files

Join-SourceItems -Items $scriptHeader -Wraparound '.\Source\ScriptTemplates\FunctionApp-Starter.ps1' | Out-File -FilePath .\Deploy-FunctionApp\HuduAxcientDashboard-Starter\run.ps1
Join-SourceItems -Items $scriptHeader -Wraparound '.\Source\ScriptTemplates\FunctionApp-Orchestrator.ps1' | Out-File -FilePath .\Deploy-FunctionApp\HuduAxcientDashboard-Orchestrator\run.ps1
Join-SourceItems -Items $scriptHeader, $functionsAndTemplates, $endRegion -Wraparound '.\Source\ScriptTemplates\FunctionApp-GetInitialData.ps1' | Out-File -FilePath .\Deploy-FunctionApp\HuduAxcientDashboard-GetInitialData\run.ps1
Join-SourceItems -Items $scriptHeader, $functionsAndTemplates, $endRegion -Wraparound '.\Source\ScriptTemplates\FunctionApp-ProcessCompany.ps1' | Out-File -FilePath .\Deploy-FunctionApp\HuduAxcientDashboard-ProcessCompany\run.ps1