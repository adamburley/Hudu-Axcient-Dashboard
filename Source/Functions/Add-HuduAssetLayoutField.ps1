# Thanks, @JohnDuprey! https://github.com/KelvinTegelaar/CIPP-API/blob/master/Modules/CippExtensions/Public/Extension%20Functions/Add-HuduAssetLayoutM365Field.ps1
function Add-HuduAssetLayoutField {
    Param(
        $AssetLayoutId
    )

    $M365Field = @{
        position     = 0
        label        = 'Axcient x360Recover'
        field_type   = 'RichText'
        show_in_list = $false
        required     = $false
        expiration   = $false
        hint         = '** DO NOT MODIFY **  This field is automatically updated.'
    }

    $AssetLayout = Get-HuduAssetLayouts -LayoutId $AssetLayoutId

    if ($AssetLayout.fields.label -contains 'Axcient x360Recover') {
        Write-Host "Layout $($AssetLayout.name) already has the Axcient x360Recover field" -ForegroundColor Magenta
        return $AssetLayout
    }

    $AssetLayoutFields = [System.Collections.Generic.List[object]]::new()
    $AssetLayoutFields.Add($M365Field)
    foreach ($Field in $AssetLayout.fields) {
        $Field.position++
        $AssetLayoutFields.Add($Field)
    }
    Set-HuduAssetLayout -Id $AssetLayoutId -Fields $AssetLayoutFields
    Write-Host "Added Axcient x360Recover field to $($AssetLayout.name)" -ForegroundColor Green
}