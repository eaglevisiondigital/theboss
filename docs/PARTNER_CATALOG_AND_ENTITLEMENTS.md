# Partner catalog and entitlement integration

**PHASE 8B1 LOCAL IMPLEMENTATION COMPLETE / PRODUCTION RELEASE PENDING EXPLICIT APPROVAL**

Provider/external source identity is unique within the exact provider; equal external IDs from different providers are unrelated. Each canonical source has an immutable material revision with provider/source/contract anchors, category, public description, protected terms/exclusions, country/region/market, exact membership product/tier, fulfillment type, validity and digest. Reviews are append-only. Transaction evidence retains the exact applicable revision.

Imports are synthetic-only, individually schema-validated and bounded to 250 items / 1 MiB per command. Provider-scoped feed sequence/digest and source revision/digest enforce repeated-feed idempotency, changed-material conflicts and older-update quarantine. Invalid items roll back only their subtransaction; valid peers survive. Quarantine stores item index, constrained external ID and a finite category, never unrestricted raw body/private terms. Malformed timestamp regression fails before the local correction and passes afterward.

Delta omission is never withdrawal. A full feed withdraws omissions only under explicit configured permission and zero quarantined items. Arbitrarily large catalogs use an explicit paged snapshot with expected item count, bounded full pages, valid completed-run checks and explicit complete/abort. Delta interleaving is blocked during an open snapshot. Incomplete/invalid/aborted snapshots do not mass-withdraw. Expiry/stale verification/provider outage/pause are separate fail-closed facts. Reprocessing uses the same committed identity or a new ordered corrected revision; it never rewrites historical terms.

Member access reuses discount_subject, discount_source_valid, tier rank and existing membership/source tables. Exact product filtering occurs before source selection, so a higher-tier source for another product cannot authorize or mask this one. Country and local/state/nationwide coverage must match the canonical market and benefit/contract policy. A US nationwide entitlement cannot grant Canadian access. Source revocation, person inactivity and module closure retain the existing security boundary. Household membership alone is not personal membership authority.

No private catalog terms are public. Anonymous directory and member discovery are empty while all adapters are off. Platform-only review reads are bounded to 50 with provider/source pagination; exact-provider detail groups are each bounded to 50. Future unified discovery keeps native-versus-partner provenance and organic relevance separate from sponsorship. Favorites and household activity sharing remain deferred.

No canonical migration, deployment, commit/push, PR update, production test authority or live provider execution is authorized by this checkpoint. Phase 8A remains COMPLETE with its prior evidence limitations; Phase 8B2 has not started.
