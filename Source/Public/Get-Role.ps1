#requires -module Az.Resources
using namespace Microsoft.Azure.Commands.Profile.Models

function Get-Role {
  [CmdletBinding()]
  param(
    #The subscription Id(s) to search for roles. This normally doesn't need to be specified, it will find all available roles.
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Id')][String]$Scope = '/',
    #Fetch roles for everyone, not just yourself. This usually requires additional permissions.
    [Switch]$All,
    #Only fetch activated eligible roles.
    [Parameter(ParameterSetName = 'Enabled')][Switch]$Activated
  )

  process {
    $filter = if (-not $All) {
      'asTarget()'
    }
    try {
      if ($Activated) {
        Get-AzRoleAssignmentScheduleInstance -Scope $scope -Filter $filter -ErrorAction stop |
          Where-Object AssignmentType -EQ 'Activated'
      } else {
        Get-AzRoleEligibilitySchedule -Scope $scope -Filter $filter -ErrorAction stop
      }
    } catch {
      if (-not ($PSItem.FullyQualifiedErrorId.Split(',')[0] -eq 'InsufficientPermissions')) {
        $PSCmdlet.WriteError($PSItem)
        return
      }

      $PSItem.ErrorDetails = "You specified -All but do not have sufficient rights to view all available roles at this scope, this usually requires Owner rights at the specified scope ($Scope)."

      $PSCmdlet.WriteError($PSItem)
      return
    }
  }
}

#Formatting for
# Update-TypeData -TypeName 'Microsoft.Azure.PowerShell.Cmdlets.Resources.Authorization.Models.Api20201001Preview.RoleEligibilityScheduleRequest' -DefaultDisplayPropertySet 'PrincipalEmail', 'ScopeDisplayName', 'RoleDefinitionDisplayName', 'ExpirationEndDateTime'

#Get active roles. Ones with Activated State
