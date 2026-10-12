# Partner Network architecture

**PHASE 8B1 LOCAL IMPLEMENTATION COMPLETE / PRODUCTION RELEASE PENDING EXPLICIT APPROVAL**

Three economic domains stay distinct: native Merchant Platform offers/redemption; licensed external partner benefits; evidence for potential commissionable partner transactions. None establishes another. The six additive migrations introduce 16 public relations and one private receipt relation, anchored to existing people, commerce, Phase 7E products/memberships and native merchant markets. Native merchant commands, discovery and redemption source are unchanged.

The registry is a stable provider identity. Immutable configuration revisions declare one of seven delivery methods and individually enabled capabilities. Separate immutable legal revisions and approval/termination events determine licensing. The provider's finite lifecycle is prospect → evaluation → contract_pending → approved → configured, with explicit suspended/terminated/archived paths. Version comparison prevents lost state reviews. Configured means technical configuration recorded, never operational.

Publication decisions expose independent membership_eligible, territory_eligible, catalog_available, licensing_valid, provider_operational, fulfillment_possible and visible facts. All must pass. Operational and credential-readiness CHECK constraints are permanently false in this phase; generic edits and the explicit integration.activate command cannot open that boundary. The public directory and authenticated discovery return an honest empty projection. Imported mocks never become active consumer listings.

Architecture reuses canonical Auth/current-person/role checks, the existing commerce module, original source-validity/subject/geography helpers and canonical audit events. It adds no Supabase project, identity, merchant engine, membership engine, Wallet balance or processor. Every consequential command is transactionally audited with safe IDs and caller-bound request receipts. Provider locks serialize catalog/lifecycle/territory/evidence transitions. Current actor/module/permission checks precede even receipt replay.

Administration is platform-side at /app/partners with exact provider selection. Ordinary merchant roles receive no Partner permission. Restricted/unavailable states are explicit; successful mutations refresh only after a validated committed receipt; uncertain outcomes retain the same request for safe reconciliation. Consumer /app/partners/discovery distinguishes local, national, travel and gift-card categories without claiming an operational network.

Favorites/private activity are deliberately not persisted in a second engine. Future favorites must use canonical subject authority; sharing a household does not authorize another member's activity. Organic ranking sorts separately from any future paid-placement contract. No sponsor or billing integration is activated.

See the licensing, catalog, adapter, travel, gift-card, revenue, validation, manifest and release-plan documents for exact extension boundaries.

No canonical migration, deployment, commit/push, PR update, production test authority or live provider execution is authorized by this checkpoint. Phase 8A remains COMPLETE with its prior evidence limitations; Phase 8B2 has not started.
