# Modules and product access

## IMPLEMENTED

Phase 2A implements the capability/access/rollout data foundation only. These
three concerns remain separate from authorization. Deployment and validation
status is recorded in [CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).
All six foundation migrations are applied to the canonical Boss project. Live
inspection verified 13 module definitions and no operational activations,
entitlements or feature flags after fixture rollback. The live suite passed 269
assertions. The final disposable run passed 911 SQL assertions and three
concurrent hierarchy checks, with no cycle and verified fixture/cluster cleanup.
Application and CI validation remain separate from these database results.

| Concern | Tables | Meaning |
| --- | --- | --- |
| Organization capability | `modules`, `organization_modules` | Catalog and dated organization activation/configuration |
| Product access | `entitlements` | Dated access records for an explicit subject |
| Rollout/availability | `feature_flags`, `feature_flag_overrides` | Definitions and dated platform/organization/person overrides |
| Authorization | `roles`, `permissions`, `role_permissions`, `role_assignments` | Independent permission decision in resource context |

The authorization catalog seeds 19 roles, 17 permissions and 112 approved
role-permission mappings. Those potential capabilities require a valid active
assignment in its permitted scope; no real assignments are seeded. Organization
owner/administrator and athletic director use organization scope, program/sport
administrators use exact organization-unit scope, and team roles use team scope.
These mappings implement no business module or client write API.

### Modules

Module keys are stable, unique catalog identifiers. The approved catalog covers
`fundraising`, `boss_bucks`, `sports`, `engage`, `registration`, `documents`,
`messaging`, `volunteers`, `money_board`, `commerce`, `livestream`, `fan` and
`reporting`. Their catalog presence does not mean product functionality exists.
The catalog migration records the final seed implementation; no organizations,
families, teams or customers are seed data.

`organization_modules` links a real organization/module with a lifecycle state,
source, start/end window and object-shaped configuration. Activation defaults to
inactive. Relationship identity/start fields are immutable; changes can end an
old period and create another. The `organization_module_active` helper checks the
caller's authorized subject visibility, an active module and a current active
activation. It does not grant permission to read any other data.

### Entitlements

An entitlement targets an organization, person, household or explicit membership.
Membership targets require `membership_kind` of organization, team or household;
conditional generated FKs prevent ambiguous or nonexistent subjects. Records
include type/key, lifecycle/window, provenance and object-shaped configuration.
They default to inactive and have no hard-coded prices or geographic products.

The `has_active_entitlement` helper first checks authorized subject visibility,
then the entitlement's status/window/key and active subject. Membership subjects
also require a current active underlying relationship and active parent resources.
Seeing one's historical membership or its entitlement row does not activate
product access. An entitlement does not replace scoped permission or authorize
an unrelated organization, team, person or household.
No entitlement purchasing, assignment UI, pricing engine or commercial workflow
is implemented.

### Feature flags

Definitions have a unique key, enabled value, lifecycle and configuration.
Rollout classifications are `experimental`, `phased`, `organization_pilot`,
`emergency_disable` and `internal_only`. Flags default disabled. Overrides target
platform, organization or person, with real FKs for organization/person scopes and
an explicit status/window. Phase 2A does not seed speculative flag definitions.

These records supply a configurable foundation. Rollout percentages, precedence
resolution, emergency-disable evaluation and application feature gates have not
been implemented. A classification alone neither changes runtime behavior nor
authorizes access. No RLS predicate uses a flag or entitlement as a permission.

### Protection

Product-access tables have RLS and explicit client SELECT grants only. Catalog
reads require a usable canonical identity. Organization activations, entitlements
and overrides remain subject/context restricted. Trusted server writers may
populate them; there is no client write API or module administration UI.
See [SECURITY_MODEL.md](SECURITY_MODEL.md) and
[PERMISSIONS_MODEL.md](PERMISSIONS_MODEL.md).

## APPROVED BUT NOT IMPLEMENTED

Future module endpoints must separately evaluate applicable capability,
entitlement, rollout, permission, relationship, visibility and resource context.
The Phase 2A helpers provide foundations for those checks, without selecting new
pricing, assignment, publishing or flag-resolution rules.

## FUTURE

All business-module workflows remain unimplemented: campaigns/donations/referrals,
Boss Bucks memberships and geographic discounts, Money Board, payments/ledgers,
merchants/offers/redemption, registration/forms, document/storage workflows,
messaging/notifications, volunteer scheduling, games/scoring/statistics,
livestreaming, products/orders/fulfillment and CRM. No seed or configuration row
activates an implementation of these products.
