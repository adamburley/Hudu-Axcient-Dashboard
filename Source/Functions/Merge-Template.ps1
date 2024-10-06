function Merge-Template {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Template,

        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]$Parameters

    )
    begin {
        $resultAL = [System.Collections.ArrayList]::new()
    }
    process {
        $thisResult = $Template.Clone()
        $Parameters.GetEnumerator() | ForEach-Object {
            $thisResult = $thisResult.Replace("{{$($_.Key)}}", $_.Value, [System.StringComparison]::OrdinalIgnoreCase)
        }
        $resultAL.Add($thisResult) | Out-Null
    }
    end {
        $resultAL | Out-String
    }
}