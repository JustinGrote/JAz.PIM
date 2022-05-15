filter Restore-GraphProperty {
    <#
    .SYNOPSIS
    Graph responses often contain minimal info. If our request object had the info, we can fairly sanely restore the data if properties were not changed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Request,
        [Parameter(Mandatory)]$Response,
        $DataObject = $Request,
        [Parameter(Mandatory, ValueFromPipeline)]$Property
    )

    if ($Response[$("${property}Id")] -ne $Request[$("${property}Id")]) {
        throw "The returned ${property}Id does not match the request. This is a bug"
    }
    $Response.$property = $DataObject.$property
}
