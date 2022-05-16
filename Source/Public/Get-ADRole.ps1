#requires -module Microsoft.Graph.DeviceManagement.Enrolment
using namespace Microsoft.Graph.PowerShell.Models

function Get-ADRole {
    [CmdletBinding()]
    param(
        #TODO: Fetch roles for everyone, not just yourself. This usually requires additional permissions.
        # [Switch]$All,
        #Only fetch activated eligible roles.
        [Parameter(ParameterSetName = 'Enabled')][Switch]$Activated
    )

    process {
        #HACK: Cannot do this query with the existing cmdlets
        $requestUri = if ($Activated) {
            "beta/roleManagement/directory/roleAssignmentScheduleInstances/filterByCurrentUser(on='principal')?expand=principal,roledefinition,directoryscope"
        } else {
            "beta/roleManagement/directory/roleEligibilitySchedules/filterByCurrentUser(on='principal')?expand=principal,roledefinition,directoryscope"
        }
        $response = (Invoke-MgGraphRequest -Uri $requestUri -ErrorAction stop).value *>&1

        if ($? -eq 'False') {
            return
        }

        if ($Activated) {
            [MicrosoftGraphUnifiedRoleAssignmentScheduleInstance[]]$response | Where-Object AssignmentType -EQ 'Activated'
        } else {
            [MicrosoftGraphUnifiedRoleEligibilitySchedule[]]$response
        }
    }
}

