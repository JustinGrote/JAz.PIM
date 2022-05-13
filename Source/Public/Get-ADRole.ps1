#requires -module Microsoft.Graph.DeviceManagement.Enrolment
using namespace Microsoft.Graph.PowerShell.Models

function Get-ADRole {
    [CmdletBinding()]
    param(
        # #Fetch roles for everyone, not just yourself. This usually requires additional permissions.
        # [Switch]$All,
        # #Only fetch activated eligible roles.
        # [Parameter(ParameterSetName = 'Enabled')][Switch]$EligibleActivated
    )

    process {
        # if ((Get-MgProfile).Name -ne 'beta') {
        #     throw "This command requires the beta Graph API. Please run {Select-MgProfile 'beta'} and retry"
        # }
        #HACK: Cannot do this query with the existing cmdlets
        $requestUri = "beta/roleManagement/directory/roleEligibilitySchedules/filterByCurrentUser(on='principal')?expand=principal,roledefinition"
        [MicrosoftGraphUnifiedRoleEligibilitySchedule[]]$eligibleRoles = (Invoke-MgGraphRequest -Uri $requestUri -ErrorAction Stop).value

        $eligibleRoles
        # $filter = if (-not $All) {
        #     'asTarget()'
        # }
        # try {
        #     if ($EligibleActivated) {
        #         Get-AzRoleAssignmentScheduleInstance -Scope $scope -Filter $filter -ErrorAction stop |
        #             Where-Object AssignmentType -EQ 'Activated'
        #     } else {
        #         Get-AzRoleEligibilitySchedule -Scope $scope -Filter $filter -ErrorAction stop
        #     }
        # } catch {
        #     if (-not ($PSItem.FullyQualifiedErrorId.Split(',')[0] -eq 'InsufficientPermissions')) {
        #         $PSCmdlet.WriteError($PSItem)
        #         return
        #     }

        #     $PSItem.ErrorDetails = "You specified -All but do not have sufficient rights to view all available roles at this scope, this usually requires Owner rights at the specified scope ($Scope)."

        #     $PSCmdlet.WriteError($PSItem)
        #     return
        # }
    }
}

#Formatting for
# Update-TypeData -TypeName 'Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Models.Api20201001Preview.RoleEligibilityScheduleRequest' -DefaultDisplayPropertySet 'PrincipalEmail', 'ScopeDisplayName', 'RoleDefinitionDisplayName', 'ExpirationEndDateTime'

#Get active roles. Ones with Activated State
