using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Management.Automation
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
        [double]$Interval = 1,
        #Keep checking until this specified number of seconds. Default to 10 minutes to allow for approval workflows.
        $Timeout = 600,
        #How many roles to check simultaneously. You shouldn't normally need to modify this.
        $ThrottleLimit = 5,
        #If specified, will return the activated role instances which can be later passed to Disable-AdRole
        [Switch]$PassThru
    )
    begin {
        [List[MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]]$RoleRequests = @{}
        #Used to track progress
        $parentId = Get-Random
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
        #This synchronized dictionary is used to keep the status of the requests.
        [ConcurrentDictionary[Int, hashtable]]$info = @{}

        $waitJobs = $RoleRequests | ForEach-Object -ThrottleLimit $ThrottleLimit -AsJob -Parallel {
            Import-Module 'Microsoft.Graph.Authentication' -Verbose:$false 4>$null
            $VerbosePreference = 'continue'
            [Microsoft.Graph.PowerShell.Models.MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]$requestItem = $PSItem
            $name = $requestItem.RoleDefinition.DisplayName
            $created = $requestItem.CreatedDateTime

            function Get-Timestamp ($created = $created) {
                $since = [datetime]::UtcNow - $created
                if ($since.TotalSeconds -gt $USING:Timeout) {
                    throw "$name`: Exceeded Timeout of $($USING:Timeout) seconds waiting for role request to be completed"
                }
                $since.toString('\[hh\:mm\:ss\]')
            }

            function Set-JobStatus ($Status, $PercentComplete, $jobInfo = $jobInfo) {
                if ($status) { $jobInfo.Status = $Status + " $(Get-TimeStamp)" }
                if ($percentComplete) { $jobInfo.PercentComplete = $PercentComplete }
            }

            #Register a job info tracker
            $jobInfo = @{
                Activity = "$Name".padRight(30)
                Status   = 'Provisioning'
            }
            do {
                $isUnique = ($USING:info).TryAdd((Get-Random), $jobInfo)
            } until ($isUnique)

            if ($status -ne 'Provisioned') {
                do {
                    #HACK: Command doesn't exist for this yet
                    $request = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleRequests/filterByCurrentUser(on='principal')?`$select=status&`$filter=id eq '$($requestItem.Id)'"
                    $status = (Invoke-MgGraphRequest -Verbose:$false -ErrorAction stop -Method Get -Uri $request).value.status
                    Set-JobStatus $status 30
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
            }

            #Now we need to wait until the instance actually appears in the directory, the role definition request updates don't provide status on this.
            #We have to match on the schedule id from the request, it's a 1:1 relationship so this is safe and should never return multiple results.
            $activatedRole = $null
            do {
                Set-JobStatus 'Activating' 60
                $uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances/filterByCurrentUser(on='principal')?`$select=startDateTime&`$filter=roleAssignmentScheduleId eq '$($requestItem.TargetScheduleId)'"
                $response = (Invoke-MgGraphRequest -Verbose:$false -Method Get -Uri $uri).Value

                Start-Sleep $USING:Interval
            } until ($response)

            $activatedStartDateTime = $response.startDateTime.ToLocalTime()
            Set-JobStatus "Activated at $activatedStartDateTime" 100
        }


        #Report progress
        Write-Progress -Id $parentId -Activity 'Azure AD PIM Role Activation'
        $runningStates = 'AtBreakpoint', 'Running', 'Stopping', 'Suspending'
        do {
            foreach ($infoItem in $info.GetEnumerator()) {
                $jobInfo = $infoItem.Value
                Write-Progress -ParentId $parentId -Id $infoItem.Key @jobInfo
            }
            #Get an average progress from child jobs
            $totalProgress = ($info.Values.PercentComplete | Measure-Object -Sum).Sum / $waitJobs.ChildJobs.Count
            Write-Host -fore magenta "Total Progress: $totalProgress"
            $completeJobCount = ($waitJobs.ChildJobs | Where-Object state -NotIn $runningStates).count
            Write-Progress -Id $parentId -Activity 'Azure AD PIM Role Activation' -Status "$completeJobCount of $($waitJobs.ChildJobs.count)" -PercentComplete $totalProgress
            Start-Sleep 0.5
        } while ($waitJobs.State -in $RunningStates)

        Write-Progress -Id $parentId -Activity 'Azure AD PIM Role Activation' -Completed -PercentComplete 100
        Start-Sleep 1
        Write-Progress -Id $parentId -Activity 'Azure AD PIM Role Activation' -Completed

        if ($PassThru) {
            Get-JAzADRole -Activated
            | Where-Object { $_.roleAssignmentScheduleId -in $RoleRequests.TargetScheduleId }
        }


    }
}
