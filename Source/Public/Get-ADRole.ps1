#requires -module Microsoft.Graph.DeviceManagement.Enrolment
using namespace Microsoft.Graph.PowerShell.Models

function Get-ADRole {
    [CmdletBinding()]
    param(
        #Fetch roles for everyone, not just yourself. This usually requires additional permissions.
        [Switch]$All,
        #Only fetch activated eligible roles.
        [Parameter(ParameterSetName = 'Enabled')][Switch]$Activated
    )

    process {
        #HACK: Cannot do this query with the existing cmdlets

        [string]$filter = if (-not $All) {
            "/filterByCurrentUser(on='principal')"
        } else {
            ''
        }
        $requestUri = if ($Activated) {
            "v1.0/roleManagement/directory/roleAssignmentScheduleInstances${filter}?expand=principal,roledefinition"
        } else {
            "v1.0/roleManagement/directory/roleEligibilitySchedules${filter}?expand=principal,roledefinition"
        }

        #HACK: For some reason in a cmdlet context Invoke-MgGraphRequest errors dont terminate without a try/catch
        try {
            $response = Invoke-MgGraphRequest -Uri $requestUri -ErrorAction stop |
                Select-Object -ExpandProperty Value
        } catch { throw }

        $typedResponse = if ($Activated) {
            [MicrosoftGraphUnifiedRoleAssignmentScheduleInstance[]]$response | Where-Object AssignmentType -EQ 'Activated'
        } else {
            [MicrosoftGraphUnifiedRoleEligibilitySchedule[]]$response
        }

        #HACK: Rehydrate directoryscopeId until Expand is available
        #Ref: https://github.com/microsoftgraph/microsoft-graph-docs/issues/16936#issuecomment-1129386441
        foreach ($scheduleItem in $typedResponse) {
            if ($scheduleItem.DirectoryScopeId -eq '/') {
                $scheduleItem.DirectoryScope.Id = '/'
            } else {
                $scheduleItem.DirectoryScope = Invoke-MgGraphRequest -Method 'get' "v1.0/directory/$($scheduleItem.DirectoryScopeId)"
            }
        }

        $typedResponse
    }
}

