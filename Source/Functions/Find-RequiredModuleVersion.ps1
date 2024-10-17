function Find-RequiredModuleVersion {
    param(
        $requiredModules,
        $localModulePath,
        [switch]$Interactive
    )
    foreach ($m in $requiredModules) {
        $found = $false
        $testPath = "$localModulePath\$($M.Name)"
        if (Test-Path -Path $testPath) { 
            $foundVer = Get-ChildItem $testPath | Select-Object -ExpandProperty Name | Sort-Object -Descending | Select-Object -First 1
            if ($foundVer -ge $m.Version) {
                Write-Host "$($m.Name) $($m.Version) found in Modules folder" -ForegroundColor Green
                $found = $true
                "$localModulePath\$($m.Name)"
            }
        } 
        elseif (($installedModules = Get-Module $m.Name -ListAvailable) -and ($topVer = $installedModules | Sort-Object Version -Descending | Select-Object -first 1).Version -ge $m.Version) {
            Write-Host "$($m.Name) $($m.Version) found in installed modules" -ForegroundColor Green
            $found = $true
            $topVer.Path
        }
        if (-not $found) {
            Write-Host "$($m.Name) $($m.Version) not found" -ForegroundColor Red
            if ($Interactive) {
                Write-Host "Would you like to download to $localModulePath`? (Y/n): " -ForegroundColor Yellow -NoNewline
                if ((Read-Host) -in 'y', '') {
                    if (-not (Test-Path -Path $localModulePath)) {
                        New-Item -Path $localModulePath -ItemType Directory | Out-Null
                    }   
                    Save-Module -Name $m.Name -Path $localModulePath -MinimumVersion $m.Version
                    "$localModulePath\$($m.Name)"
                }
                else {
                    Write-Host "Please ensure module is installed or available before continuing." -ForegroundColor Red
                    pause
                }
            }
            else {
                Write-Error "Unable to locate module $($m.Name) $($m.Version). It is required to continue." -ErrorAction Stop
            }
        }
    }
}