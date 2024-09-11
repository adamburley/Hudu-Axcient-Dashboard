function Get-InitialSyncData {
    param($config)

    $axcientClients = Get-Client | Sort-Object name
    $huduCompanies = Get-HuduCompanies

    if ($config.autoMatch) {
        Write-Host "Automatch running..." -ForegroundColor Magenta
        $softMatches = 0
        foreach ($c in $axcientClients | where { $_.id -inotin $Config.matches.axcientId }) {
            $match = $huduCompanies | ? { $_.name -eq $c.name }
            if ($match) {
                $config.matches += [PSCustomObject]@{
                    name      = $c.name
                    axcientId = $c.id
                    huduID    = $match.id
                }
                $softMatches++
                Write-Host "`t$($c.name)" -ForegroundColor Green
            }
        }
        Write-Host "`nSuccessfully soft-matched " -ForegroundColor Yellow -NoNewline
        Write-Host $softMatches -ForegroundColor Green -NoNewline
        Write-Host " clients.`n" -ForegroundColor Yellow
    }
    return $axcientClients, $huduCompanies, $config
}