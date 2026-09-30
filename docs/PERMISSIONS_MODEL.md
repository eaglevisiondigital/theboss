# Boss foundation permissions

## IMPLEMENTED

Identity is resolved from the verified Auth subject through an active
`user_accounts` mapping to an active canonical `people` row. A valid Auth login
without that mapping grants no core data access. User-editable Auth metadata is
never consulted. Anonymous Auth identities are rejected by the identity helper.

Permissions belong to roles through `role_permissions`. Assignments belong to
people and carry a lifecycle window and one validated scope: platform,
organization, organization unit or team. Role keys and permitted scope kinds
are immutable catalog identity; changing a scope definition requires a reviewed
migration. No `is_admin` column, implicit role from membership labels or
automatic role assignment exists.

| Scope | Permission reach |
| --- | --- |
| Platform | Cross-tenant access only for explicitly mapped permissions |
| Organization | Matching organization and resources inside that tenant |
| Organization unit | Exact unit and resources attached directly to it |
| Team | Exact team; does not grant organization-wide authority |

Organization-unit descendants do not inherit authority automatically. Actual
organization/unit/team references are validated before a scoped permission is
considered. Assignments, roles and permissions must be active; assignment windows
must include the current time. Tenant/resource status checks also fail closed.
An expired relationship cannot grant access, although a person may still read
their own historical relationship row.

The catalog contains the approved foundation role names, the example foundation
permissions and two canonical identity permissions, `person.profile.view` and
`person.profile.manage`. Those two distinguish private person information from
participant metadata. The approved initial matrix contains 112 explicit
role-permission pairs. No person receives a role automatically.

| Role | Allowed assignment scope | Seeded potential permissions |
| --- | --- | --- |
| Super administrator, platform administrator | Platform | All 17 foundation keys |
| Support, sales, compliance | Platform | `organization.view` only |
| Finance, merchant network staff | Platform | None; no current operational need or module permission is inferred |
| Organization owner, organization administrator | Organization | The 15 approved operational keys, excluding canonical person profile keys |
| Athletic director | Organization | Organization/member view; team/roster view/manage; participant view/manage; household view; roles view |
| Program administrator, sport administrator | Organization unit | Organization/team/roster/participant view/manage and roles view, limited to exact unit context |
| Head coach | Team | Team/roster view/manage and participant view |
| Assistant coach | Team | Team/roster/participant view |
| Team administrator | Team | Team/roster view/manage |
| Team staff | Team | Team/roster view |
| Volunteer coordinator, scorekeeper, livestream operator | Team | Team view only |

Support/compliance are limited to organization visibility because no narrower
approved support or compliance operational context exists yet. Finance has no
current need for the optional organization visibility grant. Future module powers
are not inferred from any role name. Owner and administrator remain separate
catalog definitions even where their current permission sets are equal.

Mappings define potential capability. Organization-scoped `household.view` does
not expose global households: the foundation has no approved tenant-household
authority relationship. Those reads remain self-related or explicitly platform
privileged. Unit scopes do not imply organization membership-list authority;
memberships have no unit resource anchor. A future resource model/workflow must
settle either extension before those grants can authorize such operations.

The permission catalog reserves `manage` and `roles.assign` capabilities but
does not implement their mutation workflows. Authenticated Data API clients have
SELECT only, subject to RLS. There are no client INSERT/UPDATE/DELETE policies or
grants, even for a person holding a platform-scoped role. Trusted server writers
must use a separately secured, reviewed path; no such application path is added.

## Protected reads

- People: own identity, a dependent covered by currently verified explicit
  guardian profile authority, or explicit platform `person.profile.view`.
- Participants: own/dependent record or matching scoped
  `participant.profile.view`. This does not expose another person's DOB/contact.
- Organizations/units/seasons: active organization relationship or scoped read
  permission. An active team relationship can also reveal that team's season.
- Private teams: actual active team relationship or scoped `team.view`.
- Organization member lists/other team roster rows: respective scoped read
  permissions; the person's own relationship history remains readable.
- Households: active household relationship or platform `household.view`.
  Membership/guardian rows are self-related or explicitly platform privileged.
  Household membership never grants another person's private profile authority.
- Role assignments/audit events: exact scoped `roles.view`/`audit.view`.
  Own role history is readable; being an audit actor is not a read grant.
- Catalog definitions: active canonical Boss identity required. Configuration
  JSON is for low-risk settings and must contain no secrets or private profiles.

Modules, entitlements, flags and visibility do not grant permissions. Access-check
helpers first check subject visibility and then current status/windows; membership
entitlements additionally require an active underlying relationship and parent
resource. Seeing relationship history does not activate product access.

## APPROVED BUT NOT IMPLEMENTED

Canonical account provisioning, authorized mutations, audit capture, role
delegation and reviewed field projections need their specific implementation
direction. No real person is
automatically granted a role. Guardian register/document/payment/waiver flags are
stored foundations only; their corresponding business actions are not built.

## FUTURE

Business operations must combine caller identity, relationship, scoped permission,
appropriate entitlement/module capability, rollout availability, visibility and
resource context. Permission alone is not a replacement for those module rules.
Consent, sensitive-field projections, cross-unit inheritance and rollout override
precedence are not inferred by this foundation.
