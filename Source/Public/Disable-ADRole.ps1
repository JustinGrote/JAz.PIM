using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace Microsoft.Graph.Powershell.Models

class ActivatedRoleCompleter : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        $errorActionPreference = 'Stop'
        try {
            Write-Progress -Id 51806 -Activity 'Get Activated Roles' -Status 'Fetching from Azure' -PercentComplete 1
            [List[CompletionResult]]$result = Get-ADRole -Activated | ForEach-Object {
                $scope = if ($PSItem.DirectoryScopeId -ne '/') {
                    " -> $($PSItem.Scope) "
                }
                "'{0} $scope({1})'" -f $PSItem.RoleName, $PSItem.Id
            } | Where-Object {
                if (-not $wordToComplete) { return $true }
                $PSItem.replace("'", '') -like "$($wordToComplete.replace("'",''))*"
            }
            Write-Progress -Id 51806 -Activity 'Get Activated Roles' -Completed
            return $result
        } catch {
            Write-Host ''
            Write-Host -Fore Red "Completer Error: $PSItem"
            return $null
        }
    }
}
function Disable-ADRole {
    <#
    .SYNOPSIS
    Deactivates an Azure AD PIM role in use.
    .DESCRIPTION
    Use this command to deactivate an existing eligible activated role for use.
    The Rolename parameter supports autocomplete so you can tab complete your current active roles
    .EXAMPLE
    Get-JAzADRole -Activated | Disable-JAzADRole
    Deactivate all eligible activated roles.
    .EXAMPLE
    Disable-JAzADRole <tab>
    Tab complete all eligible activated roles. You can also specify the first few letters of the role name (Owner, etc.) to filter to just that role for various contexts.
    .EXAMPLE
    Get-JAzADRole
    | Select -First 1
    | Disable-JAzADRole
    Deactivate the first role in the list
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'RoleName')]
    param(
        #The role object provided from Get-JAzRole
        [Parameter(ParameterSetName = 'Role', Mandatory, ValueFromPipeline)][MicrosoftGraphUnifiedRoleAssignmentScheduleInstance]$Role,
        #The role name to disable. This parameter supports tab completion
        [ArgumentCompleter([ActivatedRoleCompleter])]
        [Parameter(ParameterSetName = 'RoleName', Mandatory, Position = 0)][String]$RoleName
    )
    process {
        if ($RoleName) { $Role = Resolve-RoleByName -AD -Activated $RoleName }
        # You would think only targetScheduleId and Action would be required, but the rest are as well.
        [MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]$request = @{
            Action           = 'SelfDeactivate'
            RoleDefinitionId = $Role.RoleDefinitionId
            DirectoryScopeId = $Role.DirectoryScopeId
            PrincipalId      = $Role.PrincipalId
            TargetScheduleId = $Role.RoleAssignmentScheduleId
        }

        if ($PSCmdlet.ShouldProcess(
                $('{0} ({1})' -f $Role.RoleName, $Role.Scope),
                'Deactivate Role'
            )) {
            try {
                [MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]$response = Invoke-MgGraphRequest -Method POST -Uri 'v1.0/roleManagement/directory/roleAssignmentScheduleRequests' -Body $request.ToJsonString()
                # $response = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $request -ErrorAction Stop
            } catch {
                $err = Convert-GraphHttpException $PSItem
                if (-not ($err.FullyQualifiedErrorId -like 'ActiveDurationTooShort*')) {
                    $PSCmdlet.WriteError($err)
                    return
                }

                $err.ErrorDetails = 'You must wait at least 5 minutes after activating a role before you can disable it.'
                $PSCmdlet.WriteError($err)
                return
            }

            # Only partial information is returned from the response. We can intelligently re-hydrate this from our request.
            'RoleDefinition', 'Principal', 'DirectoryScope' | Restore-GraphProperty $request $response $Role

            # Sets the expiration time to the createdDateTime for visibility purposes
            $response.ScheduleInfo.Expiration.Type = 'afterDateTime'
            $response.ScheduleInfo.Expiration.EndDateTime = $response.CreatedDateTime

            return $response
        }
    }
}
