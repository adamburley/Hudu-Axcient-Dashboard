function New-ApplianceDashBlock {
    param ($client)
    $appliances = $client | Get-Appliance
    $result = "<table><thead><tr><th></th><th>Status</th><th>Storage</th></tr></thead><tbody>"
    foreach ($a in $appliances) {
        $result += @"
<tr><th>
            <button class="button" style="background-color: var(--primary)" role="button"><a style="color: white;"
				role="button" href="https://my.axcient.net/home/appliance/$($a.id)" title="View $($a.alias) in Axcient" target="_blank"><i
					class="fas fa-server me-2"></i>$($a.alias)</a></button></th>
<td> $($a.health_status) $($a.health_status_reason)</td>
<td> $([math]::round($a.storage_details.used_size/1tb, 1)) / $([math]::round($a.storage_details.drive_size/1tb, 1)) TB ($([math]::round($a.storage_details.used_size/$a.storage_details.drive_size*100, 1))%)</td>
</tr>
"@
    }
    $result + "</tbody></table>"
}