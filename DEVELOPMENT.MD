# Terminology

The terminology in the API is terrible, so here's the general translation to PIM terminology in the context of activating a role:

- **roleAssignmentSchedule** - Lists all activated roles in effect, both eligible and persistent (aka active). You can
distinguish by the assignmentType property.
- **roleAssignmentScheduleInstance** - A 1:1 mapping to a role assignment schedule, and is referenced by the
roleAssignmentScheduleId.
This API shows similar info but also includes the role assignment OriginId and ScheduleId (no idea what these are for).
Unlike the PIMv2 api, you can't expand the roleAssingment schedule (previously known as a linkedEligibleROleAssignment)
in a single query
- **roleAssignmentScheduleRequest** - CREATE on this to "activate" an eligible role, and then use the resultant ID to
track the activation process. Usually it will simply be provisioned unless you have an approval workflow set up, but as far as I can tell you can't
see when the role actually has gone into effect.
- **roleEligibilitySchedules** - Lists all roles that are eligible to be activated. Instances are similar 1:1 mappings
like roleAssignment but seem to contain less info and thus are less useful

Both Activation and Deactivation go thru the `roleAssignmentScheduleRequest` API, calling either `SelfActivate` or `SelfDeactivate`.
For `SelfDeactivate`, you must provide the roleAssignmentScheduleInstance ID, **not** the schedule id.

## Detecting activations

Unfortunately the request ends at the "Provisioning" status and we can't use it to detect when a role activates. In order to do that we have to watch for the role to be Activated

## References

https://docs.microsoft.com/en-us/azure/active-directory/privileged-identity-management/pim-apis

https://docs.microsoft.com/en-us/graph/api/resources/privilegedidentitymanagement-root?view=graph-rest-beta&preserve-view=true#migrate-to-pim-v3-api-for-azure-ad-roles-role-management-apis
