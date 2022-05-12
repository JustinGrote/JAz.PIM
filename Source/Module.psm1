$publicFunctions = @()
$PublicFunctions = foreach ($ScriptPathItem in 'Private','Public','Classes','Helpers') {
    $ScriptSearchFilter = [io.path]::Combine($PSScriptRoot, $ScriptPathItem, '*.ps1')
    Get-ChildItem -Recurse -Path $ScriptSearchFilter -Exclude '*.Tests.ps1' -ErrorAction SilentlyContinue |
        Foreach-Object {
            . $PSItem
            if ($ScriptPathItem -eq 'Public') {
                $PSItem.BaseName
            }
        }
}
Export-ModuleMember $PublicFunctions

Get-ChildItem "$PSScriptRoot\Formats\*.Format.PS1XML" | Foreach-Object {
    Update-FormatData -PrependPath $PSItem
}
