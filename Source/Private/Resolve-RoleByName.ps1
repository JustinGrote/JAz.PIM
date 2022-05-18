function Resolve-RoleByName ($RoleName, [Switch]$AD, [Switch]$Activated) {
    <#
.SYNOPSIS
Finds a role based on its tab complete information in RoleName parameter
#>
    if (-not $RoleName) { throw 'RoleName was null. this is a bug' }
    #This finds a guid inside parentheses.
    $guidExtractRegex = '.+\(([\w-]+)\)', '$1'
    $roleGuid = $RoleName -replace $guidExtractRegex
    if (-not $roleGuid) { throw "RoleName $roleName was in an incorrect format. It should have (RoleNameGuid) somewhere in the body. The -RoleName parameter is generally not meant to be entered manually, try <tab> or pipe in objects per the help examples." }
    $Role = if ($AD) {
        #For Graph, we need the original role schedule to do the disablement either way, so activated doesn't matter
        Get-ADRole -Activated:$Activated -Identity $roleGuid
    } else {
        #Get-Role doesn't support identity filtering serverside.
        Get-Role -Activated:$Activated | Where-Object { $_.Name -eq $RoleGuid }
    }

    # if ($AD) {
    #     Get-ADRole -Activated:$Activated | Where-Object RoleAssignmentScheduleId -EQ $roleGuid
    # } else {
    #     Get-Role -Activated:$Activated | Where-Object Name -EQ $roleGuid
    # }
    if (-not $Role) { throw "RoleGuid $roleGuid from $RoleName was not found as an eligible role for this user. NOTE: If you used autocomplete to get this result and didn't manually type it or use past history, please report this as a bug." }
    if ($Role.count -ne 1) { throw "Multiple roles found for role guid $roleGuid. This is a bug, please report it" }

    return $Role
}
