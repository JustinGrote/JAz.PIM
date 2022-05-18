using namespace System.Collections.Generic
using namespace Microsoft.Graph.PowerShell.Models
function Wait-AdRole {
    [OutputType([Microsoft.Graph.PowerShell.Models.MicrosoftGraphUnifiedRoleAssignmentScheduleInstance])]
    <#
.SYNOPSIS
Waits for an AD role request to complete.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]$RoleRequest,
        #How often to check for an update. Defaults to 1 second
        $Interval = 1,
        #Keep checking until this specified number of seconds. Default to 10 minutes to allow for approval workflows.
        $Timeout = 600,
        #How many roles to check simultaneously. You shouldn't normally need to modify this.
        $ThrottleLimit = 5,
        #If specified, will return the activated role instances which can be later passed to Disable-AdRole
        [Switch]$PassThru
    )
    begin {
        [hashset[int]]$uniqueIds = @()
        [int]$parentId = Get-Random
        [void]$uniqueIds.Add($parentId)
        # Write-Progress -Id $parentId -Activity 'Waiting for PIM Role Activation'
        [List[MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]]$RoleRequests = @{}
    }
    process {
        if ($RoleRequest.EndDateTime) {
            $localEndTime = $RoleRequest.EndDateTime.ToLocalTime()
            if ($localEndTime -lt [DateTime]::Now) {
                Write-CmdletError "$($RoleRequest.RoleName) role end date already expired at $localEndTime. Skipping.."
                return
            }
        }

        $RoleRequests.Add($RoleRequest)
    }
    end {
        $RoleRequests | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            Import-Module 'Microsoft.Graph.Authentication' -Verbose:$false 4>$null
            $VerbosePreference = 'continue'
            [Microsoft.Graph.PowerShell.Models.MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]$requestItem = $PSItem
            #First make sure any approvals are cleared

            $name = $requestItem.RoleDefinition.DisplayName
            $created = $requestItem.CreatedDateTime

            # if ($status -ne 'Provisioned') {
            do {
                #HACK: Command doesn't exist for this yet
                $request = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests/filterByCurrentUser(on='principal')?`$select=status&`$filter=id eq '$($requestItem.Id)'"
                $status = (Invoke-MgGraphRequest -Verbose:$false -ErrorAction stop -Method Get -Uri $request).value.status
                [int]$secondsSinceCreation = ([datetime]::UtcNow - $created).TotalSeconds
                if ($secondsSinceCreation -gt $USING:Timeout) {
                    throw "$name`: Exceeded Timeout of $($USING:Timeout) seconds waiting for role request to be completed"
                }
                Write-Verbose "Waiting for $Name request to process. Status: $status - $secondsSinceCreation seconds since creation"
                Start-Sleep $USING:Interval
            } while (
                #This is a generic consent request type
                #https://docs.microsoft.com/en-us/graph/api/resources/request?view=graph-rest-1.0
                $status -like 'Pending*'
            )
            if ($status -ne 'Provisioned') {
                Write-Error "$name`: Request failed with status $status"
                return
            }
            # }

            #Now we need to wait until the instance actually appears in the directory, the role definition request updates don't provide status on this.
            #We have to match on the schedule id from the request, it's a 1:1 relationship so this is safe and should never return multiple results.
            $activatedRole = $null
            do {
                [int]$secondsSinceCreation = ([datetime]::utcnow - $created).TotalSeconds
                if ($secondsSinceCreation -gt $USING:Timeout) {
                    throw Write-Error "$name`: Exceeded Timeout of $($USING:Timeout) seconds waiting for role request to be completed"
                }
                Write-Verbose "$Name request processed. Waiting for role to activate  - $secondsSinceCreation seconds since creation"
                $uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances/filterByCurrentUser(on='principal')?`$select=startDateTime&`$filter=roleAssignmentScheduleId eq '$($requestItem.TargetScheduleId)'"
                $response = (Invoke-MgGraphRequest -Verbose:$false -Method Get -Uri $uri).Value

                Start-Sleep $USING:Interval
            } until ($response)

            $activatedStartDateTime = $response.startDateTime.ToLocalTime()
            Write-Verbose "$Name activated at $activatedStartDateTime"
        }

        if ($PassThru) {
            Get-JAzADRole -Activated | Where-Object { $_.roleAssignmentScheduleId -in $RoleRequests.TargetScheduleId }
        }
    }
}
