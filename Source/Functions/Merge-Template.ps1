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
            $thisResult = $thisResult -replace "{{$($_.Key)}}", $_.Value
        }
        $resultAL.Add($thisResult) | Out-Null
    }
    end {
        $resultAL | Out-String
    }
}