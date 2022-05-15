# JAz.PIM Privileged Identity Management Activation Module

Provides a friendly wrapper to the Az PIM Cmdlets for self activation and deactivation of roles using the new PIMv3 API.
This supports both Azure Resource Roles and Azure AD Roles.

## Usage Quickstart

```powershell
Install-Module JAz.Pim
Connect-AzAccount
Enable-JAzRole <tab or shift-enter>
Disable-JAzRole <tab or shift-enter>

Connect-MgGraph -Scopes 'RoleEligibilitySchedule.ReadWrite.Directory'
Select-MgProfile 'beta'
Enable-JAzADRole <tab or shift-enter>
Disable-JAzADRole <tab or shift-enter>
```

## Additional Notes

The Enable/Disable commands fully support -WhatIf and -Verbose if you want to see what would happen first.

If you want to activate multiple roles at once, use `Get-JAzRole` and pipe the ones you want to activate to `Enable-JAzRole`

The equivalents for Azure AD Roles is `Enable-JAzADRole` and `Disable-JAzADRole` and the behavior is mostly equivalent.

The module also supports re-prefixing so you can do `import-module Jaz.PIM -Prefix 'Az' -verbose` and get more 'Az'-like commands

The scope is currently limited to "self" activation, but may expand in scope to approvals, enabling role schedules for others, etc.

In this module we also establish a new terminology difference between "Active" and "Activated" roles. An "Activated" role
is an eligible role that has been activated. All Activated roles are Active roles, but not all Active roles are
Activated roles (some Active roles are persistently assigned). Persistent Active roles are currently outside the scope
of this module.

## Microsoft Graph Scope Permissions

Please note currently the Azure AD Roles use the Graph PowerShell SDK, but the default scopes in the Graph App don't
cover role management. I'm debating whether to roll a new published app for this purpose, but either way you may need
to use Connect-MgGraph with an appropriate scope like 'RoleEligibilitySchedule.ReadWrite.Directory' or 'RoleManagement.ReadWrite.Directory'
and this may require admin consent to add the scope to your Powershell Graph enterprise app instance in your tenant.

Note that this is a **delegated** scope grant, not an **application** scope grant, so the user still needs sufficient permissions
to perform actions, and self-actions usually don't require anything other than being a regular user in the environment.
