# JAz.PIM Privileged Identity Management Activation Module

Provides a friendly wrapper to the Az PIM Cmdlets for self activation and deactivation of roles.
This currently only supports Azure Resource Roles, Azure AD roles is coming very soon.

## Usage Quickstart

The command help has lots of examples.

`Enable-JAzRole` and `Disable-JAzRole` support autocomplete so using these commands with
tab or ctrl-enter is typically all that you need.

If you want to activate multiple roles at once, use `Get-JAzRole` and pipe the ones you want to activate to `Enable-JAzRole`

The equivalents for Azure AD Roles is `Enable-JAzADRole` and `Disable-JAzADRole` and the behavior is mostly equivalent.
