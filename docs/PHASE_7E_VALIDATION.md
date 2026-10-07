# Phase 7E validation

Status: LOCAL VALIDATION; live release/acceptance pending. Starting source
`8760547f4e69e5c097640030090f1d92e87ac237`. Canonical history remains 101.

Application typecheck, zero-warning lint, 562/562 tests and production build pass.
Compilation uses only a nonfunctional format fixture for the public configuration,
never a working provider or privileged credential. The complete historical SQL/bootstrap/sealed run passes **21,449 unique
assertions** (21,388 in 134 SQL suites; 28 bootstrap; 33 sealed-source). Count
each suite summary once; exclude the repeated Phase 3B cleanup summary and isolated
tournament SQL replay. Automatic historical RLS/catalog checks expand with the
new schema, in addition to **251 dedicated Phase 7E assertions** in eight suites.
All **293 coordinated races** pass, including **10 new Phase 7E races**.
Separate focused gates pass 81 schema relation/function checks and four exact
activation/recovery contract checks in a disposable database.

New coverage includes exact person/household claims, RLS/ACL, immutable terms,
current-authority replay, 30/60/90-day trials, strict USD >2500 gifts, original
trial fallback, 6,000-card inventory, assignment versus sale, physical replacement/
refund lineage, product capture/final ACH, exactly-once fulfillment, original-item
refunds, source review holds, unclaimed guest purchase without guessed identities,
preissued claim denial under review, finite SQL delivery input and currency totals.

Provider-positive evidence is SQL/RUNTIME VERIFIED; LOCAL CONTRACT TESTED;
SANDBOX UNAVAILABLE. No hosted paid success is fabricated. Operational provider
and recurring execution stay fail-closed. No Auth policy change or timeout increase.

Local rendered layout/label/status checks pass for consumer, organization and
public membership screens at 1280/768/390/320. Revalidate the final render and record
hosted evidence separately. These checks are not a general accessibility certification.

## Historical preauthorization live gate

Canonical release was blocked before the first migration executed. Recheck confirms
101 migration entries and zero Phase 7E public tables. Canonical types remain the
validated 101-migration Phase 7D types; regeneration is pending application. The
current remote SHA and PR CI remain Phase 7D evidence, not Phase 7E release evidence.
No hosted window or temporary authority was activated. See the exact checkpoint.

Pre-release advisors show only the previously disclosed leaked-password-protection
warning, intentional closed raw RLS/no-policy information, unused-index information
and absolute Auth-connection-allocation information. No unrelated Auth change or
index removal was made. Post-migration advisors remain required.

## Canonical post-migration verification

Direct typed owner authorization received; six exact tested migrations applied,
101 → 107. All 81 live relation/function/RLS/ACL/search-path/index checks pass in a
read-only transaction. Original baseline hashes/counts are equal and administrator
remains valid. Canonical TypeScript types generated from 107 migrations. Security
advisors: intentional closed raw RLS/no-policy INFO and preexisting leaked-password
protection WARN. Performance: unused-index INFO and absolute Auth connection
allocation INFO. No new advisor error, Auth change or index removal.
See [RLS notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection),
[index notice](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)
and [Auth allocation](https://supabase.com/docs/guides/deployment/going-into-prod).

Post-generation strict typecheck, zero-warning lint, **562/562** application tests
and production build pass against the canonical 107-migration types. Four
duplicate local Next.js generated cache files were removed before validation;
no application or database behavior changed for that local artifact correction.

A final narrow native-form fix honors unassigned platform stock by omitting its
organization field only when platform ownership and the explicit unassigned
choice are both selected. Organization/campaign ownership retains exact scope.
Regression coverage and final typecheck/lint/**563/563** tests/build pass. No SQL
source, permission or production policy changed for this form correction.
