# JAz.PIM Privileged Identity Management Activation Module

Provides a friendly wrapper to the Az PIM Cmdlets for self activation and deactivation of roles using the new PIMv3 API.
This supports both Azure Resource Roles and Azure AD Roles.

The scope is currently limited to "self" activation, but may expand in scope to approvals, enabling role schedules for others, etc.

Please note currently the Azure AD Roles use the Graph PowerShell SDK, but the default scopes in the Graph App don't
cover role management. I'm debating whether to roll a new published app for this purpose, but either way you may need
to use Connect-MgGraph with an appropriate scope like 'RoleEligibilitySchedule.ReadWrite.Directory' or 'RoleManagement.ReadWrite.Directory'
and this may require admin consent to add the scope to your Powershell Graph enterprise app instance in your tenant.

Note that this is a **delegated** scope grant, not an **application** scope grant, so the user still needs sufficient permissions
to perform actions, and self-actions usually don't require anything other than being a regular user in the environment.

## Usage Quickstart

```powershell
Install-Module Az.Pim
Connect-AzAccount
Enable-AzRole <tab or shift-enter>
Disable-AzRole <tab or shift-enter>

Connect-MgGraph -Scopes 'RoleEligibilitySchedule.ReadWrite.Directory'
Enable-AzADRole <tab or shift-enter>
Disable-AzADRole <tab or shift-enter>
```

If you want to activate multiple roles at once, use `Get-JAzRole` and pipe the ones you want to activate to `Enable-JAzRole`

The equivalents for Azure AD Roles is `Enable-JAzADRole` and `Disable-JAzADRole` and the behavior is mostly equivalent.
