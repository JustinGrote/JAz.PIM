function Resolve-RoleByName ($RoleName, [Switch]$AD) {
    <#
.SYNOPSIS
Finds a role based on its tab complete information in RoleName parameter
#>
    if (-not $RoleName) { throw 'RoleName was null. this is a bug' }
    #This finds a guid inside parentheses.
    $guidExtractRegex = '.+\(([{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?)\)', '$1'
    $roleGuid = $RoleName -replace $guidExtractRegex -as [Guid]
    if (-not $roleGuid) { throw "RoleName $roleName was in an incorrect format. It should have (RoleNameGuid) somewhere in the body. The -RoleName parameter is generally not meant to be entered manually, try <tab> or pipe in objects per the help examples." }
    $Role = if ($AD) {
        Get-ADRole -Activated | Where-Object RoleAssignmentScheduleId -EQ $roleGuid
    } else {
        Get-Role | Where-Object Name -EQ $roleGuid
    }
    if (-not $Role) { throw "RoleGuid $roleGuid from $RoleName was not found as an eligible role for this user. NOTE: If you used autocomplete to get this result and didn't manually type it or use past history, please report this as a bug." }
    return $Role
}
