#requires -module Microsoft.Graph.DeviceManagement.Enrolment
using namespace Microsoft.Graph.PowerShell.Models

function Get-ADRole {
    [CmdletBinding()]
    param(
        #Fetch roles for everyone, not just yourself. This usually requires additional permissions.
        [Switch]$All,
        #Only fetch activated eligible roles.
        [Parameter(ParameterSetName = 'Enabled')][Switch]$Activated,
        #The ID of the role to fetch
        $Identity,
        #An OAuth Filter to limit what is retrieved. This is ignored if Id is used
        [String]$Filter
    )

    process {
        #HACK: Cannot do this query with the existing cmdlets

        [string]$userFilter = if (-not $All) {
            "/filterByCurrentUser(on='principal')"
        } else {
            [String]::Empty
        }
        [string]$type = if ($Activated) {
            'roleAssignmentScheduleInstances'
        } else {
            'roleEligibilitySchedules'
        }
        if ($Identity) {
            $Filter = "id eq '$Identity'"
        }
        [string]$objectFilter = if ($Filter) {
            "&`$filter=$filter"
        } else {
            [String]::Empty
        }

        $requestUri = "v1.0/roleManagement/directory/${type}${userFilter}?`$expand=principal,roledefinition${objectFilter}"

        #HACK: For some reason in a cmdlet context Invoke-MgGraphRequest errors dont terminate without a try/catch
        try {
            $response = Invoke-MgGraphRequest -Uri $requestUri -ErrorAction stop |
                Select-Object -ExpandProperty Value
        } catch {
            throw (Convert-GraphHttpException $PSItem)
        }

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

