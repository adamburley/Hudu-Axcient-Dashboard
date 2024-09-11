function New-DeviceDashStatusTable {
    param (
        [Parameter(ValueFromPipeline)]
        $device,
        $huduServers,
        $huduWorkstations
    )
    begin {
        $result = [System.Collections.ArrayList]@(
            @"
        <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>Links</th>
                <th>Type</th>
                <th>Status</th>
                <th>Last Backup</th>
                <th>Vault Usage</th>
            </tr>
        </thead>
        <tbody>
"@
        )
    }
    process {
        # Find the Hudu asset, if we can
        $hAss = $device.Type -eq 'SERVER' ? ($huduServers | ? name -eq $device.name) : $huduWorkstations | ? name -eq $device.name
        if (-not $hAss) {
            $nShort = $device.name -split '\.' | select -first 1
            $hAss =  $device.Type -eq 'SERVER' ? ($huduServers | ? name -eq $nShort) : $huduWorkstations | ? name -eq $nShort
        }
        if ($hAss) {
            $hUrl = $hAss | select -expandproperty url
            $hAssName = $hAss | select -expandproperty name
            $disabled = ''
        }
        else {
            $hUrl = ''
            $hAssName = ''
            $disabled = 'disabled'
        }
        $errStyle = $device.current_health_status.status -eq 'NORMAL' ? '' : 'background-color: #fcd1d3'
        $result.Add(@"
<tr title=$($device.name) style="$errStyle">
    <td style="$errStyle">
        $($device.name)
    </td>
    <td style="$errStyle">
        <a class="button" style="display: inline; color: white;background-color: var(--primary);width: 4em;height: 2em;" role="button" href="$hUrl" title="View $hAssName in Hudu" $disabled>
            <i class="fa-solid fa-file-lines" style="margin: 2px;"></i>
        </a>
        &nbsp;
        <a class="button" style="display: inline; color: white;background-color: var(--primary);width: 4em;height: 2em;" role="button" href="$($device.device_details_page_url)" target="_blank" title="View $($device.name) in Axcient">
            <i class="fa-solid fa-cloud-arrow-up" style="margin: 2px;"></i>
        </a>
    </td>
    <td style="$errStyle">
        $($device.type)
    </td>
    <td style="$errStyle">
        $($device.current_health_status.status) $($device.current_health_status.reason)
    </td>
    <td style="$errStyle">
        $(if ($device.latest_cloud_rp) { $device.latest_cloud_rp.ToLocalTime()} else { 'Unknown'})
    </td>
    <td style="$errStyle">
        $([math]::round($device.vaults[0].device_usage/1gb,1)) GB
    </td>
</tr>
"@) | Out-Null
    }
    end {
        if ($result.count -eq 1) { 
            "No devices found"
        }
        else {
            $result.Add("</tbody></table>") | Out-Null
            $result | Out-String
        }
    }
}