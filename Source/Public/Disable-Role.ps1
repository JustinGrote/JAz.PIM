using namespace Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Models.Api20201001Preview
using namespace Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Models
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class ActivatedRoleCompleter : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        Write-Progress -Id 51806 -Activity 'Get Activated Roles' -Status 'Fetching from Azure' -PercentComplete 1
        [List[CompletionResult]]$result = Get-Role -Activated | ForEach-Object {
            "'{0} -> {1} ({2})'" -f $PSItem.RoleDefinitionDisplayName, $PSItem.ScopeDisplayName, $PSItem.Name
        } | Where-Object {
            if (-not $wordToComplete) { return $true }
            $PSItem.replace("'", '') -like "$($wordToComplete.replace("'",''))*"
        }
        Write-Progress -Id 51806 -Activity 'Get Activated Roles' -Completed
        return $result
    }
}
function Disable-Role {
    <#
    .SYNOPSIS
    Deactivates an Azure PIM eligible resource role for use.
    .DESCRIPTION
    Use this command to deactivate an existing eligible activated role for use.
    The Rolename parameter supports autocomplete so you can tab complete your current active roles
    .EXAMPLE
    Get-JAzRole -Activated | Disable-JAzRole
    Deactivate all eligible activated roles.
    .EXAMPLE
    Disable-JAzRole <tab>
    Tab complete all eligible activated roles. You can also specify the first few letters of the role name (Owner, etc.) to filter to just that role for various contexts.
    .EXAMPLE
    Get-Role
    | Select -First 1
    | Disable-JAzRole
    Deactivate the first role in the list
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'RoleName')]
    param(
        #The role object provided from Get-JAzRole
        [Parameter(ParameterSetName='Role', Mandatory, ValueFromPipeline)][RoleAssignmentSchedule]$Role,
        #The role name to disable. This parameter supports tab completion
        [ArgumentCompleter([ActivatedRoleCompleter])]
        [Parameter(ParameterSetName='RoleName', Mandatory, Position=0)][String]$RoleName,
        #The name of the activation. This is a random guid by default, you should never need to specify this.
        [ValidateNotNullOrEmpty()][Guid]$Name = [Guid]::NewGuid()
    )

    process {
        if ($RoleName) { $Role = Resolve-RoleByName $RoleName }
        $roleActivateParams = @{
            Name                            = $Name
            Scope                           = $Role.ScopeId
            PrincipalId                     = $Role.PrincipalId
            RoleDefinitionId                = $Role.RoleDefinitionId
            RequestType                     = 'SelfDeactivate'
            LinkedRoleEligibilityScheduleId = $Role.Name
        }
        if ($PSCmdlet.ShouldProcess(
                "$($Role.RoleDefinitionDisplayName) on $($Role.ScopeDisplayName) ($($Role.ScopeId))",
                "Deactivate Role"
            )) {
            try {
                New-AzRoleAssignmentScheduleRequest @roleActivateParams -ErrorAction Stop
            } catch {
                if (-not ($PSItem.FullyQualifiedErrorId -like 'ActiveDurationTooShort*')) {
                    $PSCmdlet.WriteError($PSItem)
                    return
                }

                $PSItem.ErrorDetails = 'Sorry, you must wait 5 minutes after activating a role before you can disable it.'
                $PSCmdlet.WriteError($PSItem)
                return
            }
        }
    }
}
