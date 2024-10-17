function Update-CompanyMatches {
    param(
        $Config,
        $AxcientClients,
        $HuduCompanies,
        [switch]$Update
    )

    if ($Update) {
        Write-Host "Updating existing list. $($Config.matches.Count) matches already exist." -ForegroundColor Green
        $AxcientClients = $AxcientClients | Where-Object { $_.id -inotin $Config.matches.axcientId }
        Write-Host "$($AxcientClients.Count) Axcient clients are unmatched." -ForegroundColor Magenta
    }

    Write-Host "Attempting to soft-match based on company name...`n" -ForegroundColor Yellow
    Write-Host "Soft matches:" -ForegroundColor Magenta

    $huduMatches = @()
    $axcientMatches = @()
    $softMatches = 0
    foreach ($c in $axcientClients) {
        $match = $huduCompanies | Where-Object { $_.name -eq $c.name }
        if ($match) {
            $config.matches += [PSCustomObject]@{
                name      = $c.name
                axcientId = $c.id
                huduID    = $match.id
            }
            $huduMatches += $match
            $axcientMatches += $c
            $softMatches++
            Write-Host "`t$($c.name)" -ForegroundColor Green
        }
    }
    Write-Host "`nSuccessfully soft-matched " -ForegroundColor Yellow -NoNewline
    Write-Host $softMatches -ForegroundColor Green -NoNewline
    Write-Host " clients.`n" -ForegroundColor Yellow

    $axcientNonMatches = $axcientClients | Where-Object { $_ -notin $axcientMatches }
    $huduNonMatches = $huduCompanies | Where-Object { $_ -notin $huduMatches }

    Write-host $axcientNonMatches.Count -ForegroundColor Red -NoNewline
    Write-Host " Axcient clients did not match." -ForegroundColor Yellow

    Write-Host "`nYou may use this script to match remaining clients, or you may manually match them via configurations." -ForegroundColor Yellow
    if ((Read-Host -Prompt "Use script to match remaining clients? (Y/n)") -in 'y', '') {
        Write-Host "To match remaining clients, a gridview will repeatedly invoke, showing remaining clients. Select two matching companies and click OK." -ForegroundColor Yellow
        Write-Host "To skip a client, select it alone and click OK." -ForegroundColor Yellow
        Write-Host "When finished, click Cancel to exit the matching subroutine." -ForegroundColor Yellow

        Write-Host "Axcient".PadRight(50) "Hudu" -ForegroundColor Magenta
        Write-Host "------".PadRight(50) "----" -ForegroundColor Magenta
        do {
            $gvOutput = @($axcientNonMatches | Select-Object @{ n = 'Source'; e = { 'Axcient' } }, name, id)
            $gvOutput += $huduNonMatches | Select-Object @{ n = 'Source'; e = { 'Hudu' } }, name, id
            $selection = $gvOutput | Sort-Object name | Out-GridView -OutputMode Multiple
            if ($selection.Count -eq 2) {
                $axcientMatch = $selection | Where-Object Source -eq 'Axcient'
                $huduMatch = $selection | Where-Object Source -eq 'Hudu'
                $config.matches += [PSCustomObject]@{
                    name      = $axcientMatch.name
                    axcientId = $axcientMatch.id
                    huduID    = $huduMatch.id
                }
                $axcientNonMatches = $axcientNonMatches | Where-Object id -ne $axcientMatch.id
                $huduNonMatches = $huduNonMatches | Where-Object id -ne $huduMatch.id
                Write-Host $axcientMatch.name.PadRight(70) $huduMatch.name -ForegroundColor Green
            }
            elseif ($selection.Count -eq 1) {
                $axcientMatch = $selection | Where-Object Source -eq 'Axcient'
                $axcientNonMatches = $axcientNonMatches | Where-Object { $_.id -ne $axcientMatch.id }
                Write-Host $axcientMatch.name.PadRight(50) X -ForegroundColor Red
            }
            else {
                break
            }
        } while ($axcientNonMatches.Count -gt 0)

        Write-Host "`nSuccessfully matched " -ForegroundColor Yellow -NoNewline
        Write-Host $($config.matches.Count) -ForegroundColor Green -NoNewline
        Write-Host " clients.`n" -ForegroundColor Yellow
    }
    $Config
}