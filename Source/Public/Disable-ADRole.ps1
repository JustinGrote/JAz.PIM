using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace Microsoft.Graph.Powershell.Models

class EligibleActivatedRoleCompleter : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        [List[CompletionResult]]$result = Get-ADRole -EligibleActivated | ForEach-Object {
            $scope = if ($PSItem.DirectoryScopeId -ne '/') {
                " -> $($PSItem.DirectoryScopeId) "
            }
            "'{0} $scope({1})'" -f $PSItem.RoleName, $PSItem.RoleAssignmentScheduleId
        } | Where-Object {
            if (-not $wordToComplete) { return $true }
            $PSItem.replace("'", '') -like "$($wordToComplete.replace("'",''))*"
        }
        return $result
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
    Get-Role -EligibleActivated | Disable-Role
    Deactivate all eligible activated roles.
    .EXAMPLE
    Disable-Role <tab>
    Tab complete all eligible activated roles. You can also specify the first few letters of the role name (Owner, etc.) to filter to just that role for various contexts.
    .EXAMPLE
    Get-Role
    | Select -First 1
    | Disable-Role
    Deactivate the first role in the list
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'RoleName')]
    param(
        #The role object provided from Get-Role
        [Parameter(ParameterSetName = 'Role', Mandatory, ValueFromPipeline)][MicrosoftGraphUnifiedRoleAssignmentScheduleInstance]$Role,
        #The role name to disable. This parameter supports tab completion
        [ArgumentCompleter([EligibleActivatedRoleCompleter])]
        [Parameter(ParameterSetName = 'RoleName', Mandatory, Position = 0)][String]$RoleName,
        #The name of the activation. This is a random guid by default, you should never need to specify this.
        [ValidateNotNullOrEmpty()][Guid]$Name = [Guid]::NewGuid()
    )
    begin {
        if (-not (Get-Command New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -ErrorAction SilentlyContinue)) {
            if ((Get-MgProfile).Name -ne 'beta') {
                throw "This command requires the beta commands to be activated. Please run {Select-MgProfile 'Beta'} and try again"
            }
        }
    }
    process {
        if ($RoleName) {
            #This finds a guid inside parentheses.
            $guidExtractRegex = '.+\(([{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?)\)', '$1'
            [Guid]$roleGuid = $RoleName -replace $guidExtractRegex -as [Guid]
            if (-not $roleGuid) { throw "RoleName $roleName was in an incorrect format. It should have (RoleNameGuid) somewhere in the body" }
            $Role = Get-ADRole -EligibleActivated | Where-Object RoleAssignmentScheduleId -EQ $roleGuid
            if (-not $Role) { throw "RoleGuid $roleGuid from $RoleName was not found as an eligible role for this user" }
        }
        # You would think only targetScheduleId and Action would be required, but the rest are as well.
        [MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]$request = @{
            Action           = 'SelfDeactivate'
            RoleDefinitionId = $Role.RoleDefinitionId
            DirectoryScopeId = $Role.DirectoryScopeId
            PrincipalId      = $Role.PrincipalId
            TargetScheduleId = $Role.RoleAssignmentScheduleId
        }

        if ($PSCmdlet.ShouldProcess(
                $Role.RoleName,
                'Deactivate Role'
            )) {
            try {
                $response = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $request -ErrorAction Stop
            } catch {
                if (-not ($PSItem.FullyQualifiedErrorId -like 'ActiveDurationTooShort*')) {
                    $PSCmdlet.WriteError($PSItem)
                    return
                }

                $PSItem.ErrorDetails = 'You must wait at least 5 minutes after activating a role before you can disable it.'
                $PSCmdlet.WriteError($PSItem)
                return
            }

            # Only partial information is returned from the response. We can intelligently re-hydrate this from our request.
            if ($response.RoleDefinitionId -ne $request.RoleDefinitionId) {
                throw 'The returned RoleDefinitionId does not match the request. This is a bug'
            }
            $response.RoleDefinition = $role.RoleDefinition

            if ($response.PrincipalId -ne $request.PrincipalId) {
                throw 'The returned PrincipalId does not match the request. This is a bug'
            }
            $response.Principal = $role.Principal
            $response.EndDateTime = [DateTime]::Now()
            return $response
        }
    }
}
