#requires -module Microsoft.Graph.DeviceManagement.Enrolment
using namespace Microsoft.Graph.PowerShell.Models

function Get-ADRole {
    [CmdletBinding()]
    param(
        #TODO: Fetch roles for everyone, not just yourself. This usually requires additional permissions.
        # [Switch]$All,
        #Only fetch activated eligible roles.
        [Parameter(ParameterSetName = 'Enabled')][Switch]$EligibleActivated
    )

    process {
        #HACK: Cannot do this query with the existing cmdlets
        $requestUri = if ($EligibleActivated) {
            "beta/roleManagement/directory/roleAssignmentScheduleInstances/filterByCurrentUser(on='principal')?expand=principal,roledefinition"
        } else {
            "beta/roleManagement/directory/roleEligibilitySchedules/filterByCurrentUser(on='principal')?expand=principal,roledefinition"
        }
        $response = (Invoke-MgGraphRequest -Uri $requestUri).value

        if ($eligibleActivated) {
            [MicrosoftGraphUnifiedRoleAssignmentScheduleInstance[]]$response | Where-Object AssignmentType -EQ 'Activated'
        } else {
            [MicrosoftGraphUnifiedRoleEligibilitySchedule[]]$response
        }
    }
}

