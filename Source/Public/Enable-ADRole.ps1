using namespace System.Xml
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace Microsoft.Graph.Powershell.Models

class ADEligibleRoleCompleter : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        Write-Progress -Id 51806 -Activity 'Get Eligible Roles' -Status 'Fetching from Azure' -PercentComplete 1
        [List[CompletionResult]]$result = Get-ADRole | ForEach-Object {
            $scope = if ($PSItem.DirectoryScopeId -ne '/') {
                "-> $($PSItem.Scope) "
            }
            "'{0} $scope({1})'" -f $PSItem.RoleName, $PSItem.Id
        } | Where-Object {
            if (-not $wordToComplete) { return $true }
            $PSItem.replace("'", '') -like "$($wordToComplete.replace("'",''))*"
        }
        Write-Progress -Id 51806 -Activity 'Get Eligible Roles' -Completed
        return $result
    }
}

function Enable-ADRole {
    <#
    .SYNOPSIS
    Activate an Azure AD PIM eligible role for use.
    .DESCRIPTION
    Use this command to activate a role for use. By default it will be active for 1 hour unless you specify an alternate duration.
    The Rolename parameter supports autocomplete so you can tab complete your available eligible roles.
    .NOTES
    The default activation period is 1 hour. You can override this with the `-Hours` parameter. You can make this persistent
    by putting this setting into your PowerShell profile:

    $PSDefaultParameterValues['Enable-JAz*Role:Hours'] = 5

    This can also be done with any parameter such as Justification however your company policy will dictate if you are
    allowed to do this. Follow common sense and only do this for Justification if you repeat the same task often.
    .EXAMPLE
    Get-JAzADRole | Enable-JAzADRole

    Enable all eligible roles for 1 hour
    .EXAMPLE
    Enable-JAzADRole <tab>

    Tab complete all eligible roles. You can also specify the first few letters of the role name (Owner, etc.) to filter to just that role for various contexts.
    .EXAMPLE
    Get-JAzADRole
    | Select -First 1
    | Enable-JAzADRole -Hours 5

    Enable the first eligible role for 5 hours
    .EXAMPLE
    Get-JAzADRole
    | Select -First 1
    | Enable-JAzADRole -NotBefore '4pm' -Until '5pm'

    Enable the first eligible role starting at 4pm and ending at 5pm. Supports any string formats that can be convered to a DateTime
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'RoleName')]
    param(
        #Role object provided from Get-JAzADRole
        [Parameter(ParameterSetName = 'RoleAssignmentSchedule', Mandatory, ValueFromPipeline)][MicrosoftGraphUnifiedRoleEligibilitySchedule]$Role,
        #Friendly name of the eligible role. Tab completion is available for this parameter, but it is generally not meant to be populated manually and must have the role name guid in parenthesis if specified manually.
        [Parameter(Position = 0, ParameterSetName = 'RoleName', Mandatory)]
        [ArgumentCompleter([ADEligibleRoleCompleter])]
        [string]$RoleName,
        #Justification for the activation. Depending on your policy, this may or may not be mandatory.
        [string]$Justification,
        #Ticket number for the activation. Depending on your policy, this may or may not be mandatory.
        [string]$TicketNumber,
        #Ticket system in which the ticket number exists. Depending on your policy, this may or may not be mandatory.
        [string]$TicketSystem,
        #Duration of the role activation. Defaults to 1 hour from activation. You can change the default by setting this in your profile: $PSDefaultParameterValues['Enable-JAz*Role:Hours'] = 5
        [ValidateNotNullOrEmpty()][int]$Hours = 1,
        #Date and time to enable the role. Defaults to now.
        [ValidateNotNullOrEmpty()][DateTime]$NotBefore = [DateTime]::Now,
        #Date and time at which the role is deactivated. If specified, this takes precedence over $Hours
        [DateTime][Alias('NotAfter')]$Until,
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
            $Role = Get-ADRole | Where-Object Id -EQ $roleGuid
            if (-not $Role) { throw "RoleGuid $roleGuid from $RoleName was not found as an eligible role for this user" }
        }
        #Adapted from https://docs.microsoft.com/en-us/graph/api/unifiedroleeligibilityschedulerequest-post-unifiedroleeligibilityschedulerequests?view=graph-rest-beta&tabs=powershell


        [MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]$request = @{
            Action           = 'SelfActivate'
            Justification    = $Justification
            RoleDefinitionId = $Role.RoleDefinitionId
            DirectoryScopeId = $Role.DirectoryScopeId
            PrincipalId      = $Role.PrincipalId
            ScheduleInfo     = @{
                StartDateTime = $NotBefore.ToString('o')
                Expiration    = @{}
            }
            # It's OK if these are null
            TicketInfo       = @{
                TicketNumber = $TicketNumber
                TicketSystem = $TicketSystem
            }
        }

        $expiration = $request.ScheduleInfo.Expiration

        if ($Until) {
            $expiration.Type = 'AfterDateTime'
            $expiration.EndDateTime = $Until
            [string]$roleExpireTime = $Until
        } else {
            $expiration.Type = 'AfterDuration'
            $expiration.Duration = [TimeSpan]::FromHours($Hours)
            [string]$roleExpireTime = $NotBefore.AddHours($Hours)
        }

        $userPrincipalName = $Role.Principal.AdditionalProperties.Item('userPrincipalName')
        if ($PSCmdlet.ShouldProcess(
                $userPrincipalName,
                "Activate $($Role.RoleDefinition.displayName) Role for scope $($Role.Scope) from $NotBefore to $roleExpireTime"
            )) {
            [MicrosoftGraphUnifiedRoleAssignmentScheduleRequest]$response = try {
                New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $request -ErrorAction Stop
            } catch {
                if (-not ($PSItem.FullyQualifiedErrorId -like 'RoleAssignmentRequestPolicyValidationFailed*')) {
                    $PSCmdlet.WriteError($PSItem)
                    return
                }

                if ($PSItem -match 'JustificationRule') {
                    $PSItem.ErrorDetails = 'Your PIM Policy requires you to supply a justification when activating this role. Use the -Justification Parameter.'
                }

                if ($PSItem -match 'ExpirationRule') {
                    $PSItem.ErrorDetails = 'Your PIM policy requires a shorter expiration than what you provided. Try the -NotAfter parameter to specify an earlier time.'
                }

                $PSCmdlet.WriteError($PSItem)
                return
            }

            # Only partial information is returned from the response. We can intelligently re-hydrate this from our request.
            'RoleDefinition', 'Principal', 'DirectoryScope' | Restore-GraphProperty $request $response $Role

            return $response
        }
    }
}
