function Get-MyId ($user) {
    <#
    Retrieves the GUID of the current user in a cached manner
    #>

    #module scoped cache of the user's GUID
    if (-not $SCRIPT:_MyIDCache) { $SCRIPT:_MyIDCache = [Collections.Generic.Dictionary[String, Guid]]@{} }

    if (-not $user) {
        $context = Get-MgContext
        if (-not $context) { throw 'You are not connected to Microsoft Graph. Please run connect-mggraph first.' }
        $user = $context.Account
    }

    #Cache Hit
    $result = $SCRIPT:_MyIDCache[$user]
    if ($null -ne $result) {
        return $result
    }

    #Cache Miss
    $response = Invoke-MgGraphRequest -Uri 'v1.0/me' -Body @{select = 'userPrincipalName,id' }
    if ($response.userprincipalname -notmatch $context.account) { throw 'The userPrincipalName in the response does not match your Mg context. This is probably a bug, please report it.' }
    $SCRIPT:_MYIDCache[$response.userPrincipalName] = $response.id
    return [guid]($response.id)
}
