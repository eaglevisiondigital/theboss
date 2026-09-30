# Tenancy model

## IMPLEMENTED

An organization is the primary tenant. Canonical people, participants and
households persist independently of a single organization. Membership and scoped
assignment records connect them to the context in which access is evaluated.
The implementation uses one schema with tenant keys and RLS rather than per-tenant
code forks. Current deployment/test evidence belongs in
[CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).
All six migrations are applied to the canonical Boss project. Live inspection
verified RLS on all 22 tables, 22 authenticated SELECT policies, no mutation
policies, no anonymous table rights and no client write grants. Live verification
passed 269 assertions and confirmed fixture rollback. The final disposable run
passed 911 SQL assertions plus three coordinated hierarchy checks: unsafe edits
failed with `23514` at READ COMMITTED and `40001` at REPEATABLE READ/SERIALIZABLE,
with no cycle. Fixtures and the temporary cluster were removed. Application and
CI validation remain separate from these database results.

### Structural tenant boundaries

`organization_id` anchors units, seasons, teams, organization memberships,
team memberships and organization module records. Composite FKs require units,
seasons and teams referenced by another tenant-scoped record to belong to that
record's organization. Units cannot point across organizations or form cycles.
Generated target columns also constrain role assignment organization/unit/team
scopes to real, matching tenant records.

Person, participant and household IDs are global canonical identifiers. They
are not globally readable. A shared identifier or contact value establishes no
cross-tenant access. Household and guardian relationships are separate from
organization/team membership.

### Read access

Every foundation table has RLS. `anon` receives no application table privileges
or policies. `authenticated` receives SELECT only, subject to caller-bound policy
checks. A usable Boss identity requires an active account/person mapping, a
non-anonymous authenticated request and a matching managed Auth user ID.

| Resource | Baseline access |
| --- | --- |
| Canonical person | Own identity, currently verified dependent profile authority, or explicit platform `person.profile.view` |
| User account | Own account mapping or explicit platform `person.profile.view`; guardian authority does not expose a dependent's account record |
| Organization and units | Active organization membership or the relevant scoped view permission |
| Season | Organization context or a legitimate active relationship with one of its teams |
| Private team | Active relationship with that team or a permission covering its actual context |
| Membership history | Own relationship rows or a reader with the corresponding scope/permission |
| Household | Active membership in that household or explicitly privileged household permission |
| Household membership/guardian relationship | Own relationship rows or explicitly privileged household permission; household membership alone does not expose every member's private relationships |
| Participant | Own/authorized dependent participant or explicitly permitted organization/team/platform context |
| Product access records | Authorized visibility of the record's subject; existence never grants unrelated record access |
| Audit history | Explicit `audit.view` permission in the applicable context |

Private person birth dates/contact information do not become visible to an
organization or team merely through roster membership. Explicit verified guardian
profile authority is separate from household participation. No public/minor
identity projection exists in this phase.

### Permission scope

Membership type labels do not grant administrative authority. A role contributes
only its active permission mappings, through an active assignment within its
relationship window. Team scope matches the specific team; it never supplies an
organization-wide permission. Organization-unit scope matches the exact unit and
resources directly anchored there. It does not implicitly inherit down descendant
units. A permission check validates the actual organization/unit/team resource
context before considering any role assignment.

The approved catalog permits organization owner, organization administrator and
athletic director assignments only at organization scope. Program and sport
administrators are restricted to organization-unit scope; coaches and other team
roles are restricted to team scope. Platform roles use platform scope only.
Allowed scope types are immutable catalog identity. The 112 seeded mappings do
not assign a role to anyone, and management keys do not enable client mutations.

Platform-scoped assignments may cross tenants only for permissions actually mapped
to the role. Authentication alone, module activation, an entitlement and a feature
flag supply no permission. See [PERMISSIONS_MODEL.md](PERMISSIONS_MODEL.md) for
the canonical permission contract and catalog decisions.

Inactive, suspended, future or expired relationships do not authorize further
resource access. A person may still read their own historical relationship rows;
reading history does not reactivate its authority.

### Mutation boundary

Client Data API roles cannot create, update, delete or truncate foundation rows.
Only the migration owner and trusted server-side `service_role` writers can
populate the model. Service role bypasses RLS and therefore is a privileged
boundary requiring independent server authorization, input validation and audit
context in future workflows. Its credentials must never enter browser code.
Audit grants and triggers further restrict service writers to appending events.
No administrative write endpoint is implemented in Phase 2A.

Explicit object ACLs and hardened `postgres` future defaults prevent accidental
client grants. Managed owners' defaults are a separate documented operational
boundary; application migrations must continue to declare grants/revokes and RLS.

## APPROVED BUT NOT IMPLEMENTED

Future authorized workflows can combine permission, relationship, module,
entitlement, visibility and context. Public publication needs an approved safe
projection and explicit policy. Tenant administration, relationship provisioning
and unit-scope inheritance beyond exact matches need subsequent approved work.

## FUTURE

No organization-specific product forks, tenant billing, payment allocation,
regional discount rules, module workflows or cross-product data sharing are
implemented. Canonical Boss records remain within its dedicated backend.
