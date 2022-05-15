using namespace Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Models.Api20201001Preview
using namespace Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Models
using namespace System.Xml
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class EligibleRoleCompleter : IArgumentCompleter {
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        Write-Progress -Id 51806 -Activity 'Get Eligible Roles' -Status 'Fetching from Azure' -PercentComplete 1
        [List[CompletionResult]]$result = Get-Role | ForEach-Object {
            "'{0} -> {1} ({2})'" -f $PSItem.RoleDefinitionDisplayName, $PSItem.ScopeDisplayName, $PSItem.Name
        } | Where-Object {
            if (-not $wordToComplete) { return $true }
            $PSItem.replace("'", '') -like "$($wordToComplete.replace("'",''))*"
        }
        Write-Progress -Id 51806 -Activity 'Get Eligible Roles' -Completed
        return $result
    }
}

function Enable-Role {
    <#
    .SYNOPSIS
    Activate an Azure PIM eligible role for use.
    .DESCRIPTION
    Use this command to activate a role for use. By default it will be active for 1 hour unless you specify an alternate duration.
    The Rolename parameter supports autocomplete so you can tab complete your available eligible roles.
    .EXAMPLE
    Get-JAzRole | Enable-JAzRole

    Enable all eligible roles for 1 hour
    .EXAMPLE
    Enable-JAzRole <tab>

    Tab complete all eligible roles. You can also specify the first few letters of the role name (Owner, etc.) to filter to just that role for various contexts.
    .EXAMPLE
    Get-JAzRole
    | Select -First 1
    | Enable-JAzRole -Hours 5

    Enable the first eligible role for 5 hours
    .EXAMPLE
    Get-JAzRole
    | Select -First 1
    | Enable-JAzRole -NotBefore '4pm' -Until '5pm'

    Enable the first eligible role starting at 4pm and ending at 5pm. Supports any string formats that can be convered to a DateTime
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'RoleName')]
    param(
        #Role object provided from Get-Role
        [Parameter(ParameterSetName = 'RoleAssignmentSchedule', Mandatory, ValueFromPipeline)][RoleAssignmentSchedule]$Role,
        #Friendly name of the eligible role. Tab completion is available for this parameter, but it is generally not meant to be populated manually and must have the role name guid in parenthesis if specified manually.
        [Parameter(Position = 0, ParameterSetName = 'RoleName', Mandatory)]
        [ArgumentCompleter([EligibleRoleCompleter])]
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
        [ValidateNotNullOrEmpty()][Guid]$Name = [Guid]::NewGuid(),
        #By default, the command returns the request response before the role activation is fully processed.
        #If specified, the command will not return until the role is actually visibile in role activations, useful for
        #waiting for approvals or not taking further action.
        [Switch]$Wait
    )

    process {
        if ($RoleName) {
            #This finds a guid inside parentheses.
            $guidExtractRegex = '.+\(([{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?)\)', '$1'
            [Guid]$roleGuid = $RoleName -replace $guidExtractRegex -as [Guid]
            if (-not $roleGuid) { throw "RoleName $roleName was in an incorrect format. It should have (RoleNameGuid) somewhere in the body" }
            $Role = Get-Role | Where-Object Name -EQ $roleGuid
            if (-not $Role) { throw "RoleGuid $roleGuid from $RoleName was not found as an eligible role for this user" }
        }

        $roleActivateParams = @{
            Name                            = $Name
            Scope                           = $Role.ScopeId
            PrincipalId                     = $Role.PrincipalId
            RoleDefinitionId                = $Role.RoleDefinitionId
            RequestType                     = 'SelfActivate'
            LinkedRoleEligibilityScheduleId = $Role.Name
            ExpirationDuration              = $expirationDuration
            Justification                   = $Justification
        }

        if ($Until) {
            $roleActivateParams.ExpirationType = 'AfterDateTime'
            $roleActivateParams.ExpirationEndDateTime = $Until
            [string]$roleExpireTime = $Until
        } else {
            $roleActivateParams.ExpirationType = 'AfterDuration'
            $roleActivateParams.ExpirationDuration = [XmlConvert]::ToString([TimeSpan]::FromHours($Hours))
            [string]$roleExpireTime = $NotBefore.AddHours($Hours)
        }

        if ($TicketNumber) {
            $roleActivateParams.TicketNumber = $TicketNumber
        }
        if ($TicketSystem) {
            $roleActivateParams.TicketSystem = $TicketSystem
        }

        if ($PSCmdlet.ShouldProcess(
                "$($Role.RoleDefinitionDisplayName) on $($Role.ScopeDisplayName) ($($Role.ScopeId))",
                "Activate Role from $NotBefore to $roleExpireTime"
            )) {
            try {
                $response = New-AzRoleAssignmentScheduleRequest @roleActivateParams -ErrorAction Stop
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
        }
        if ($Wait) {
            do {
                $roleActivation = Get-AzRoleAssignmentScheduleRequest -Name $response.Name -Scope $response.Scope -ErrorAction Stop
            } while (-not $roleActivation)
        }

        return $response
    }
}
