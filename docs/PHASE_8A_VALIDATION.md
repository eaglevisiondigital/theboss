# Phase 8A validation

Status: LOCAL GATE PASS; canonical release and hosted acceptance pending.

The complete PostgreSQL 17 historical run passes 22,673 unique SQL/bootstrap/sealed
assertions: 22,612 in 142 SQL suites, 28 trusted bootstrap checks and 33 sealed-source
checks. Sum each category row once in each final suite summary; do not count the
repeated 730-check Phase 3B cleanup summary or isolated tournament SQL replay.
New merchant coverage: 247 dedicated assertions across eight suites. Historical
generic catalog/RLS/ACL checks expand by 977 assertions with new schema/functions;
original catalog expected counts remain unchanged through exact new-key exclusions.
All 308 genuine coordinated races pass; fifteen are new Phase 8A races. Separate
focused final verification passes 209 canonical schema/RLS/ACL/path/index checks
and twelve administrator-first recovery checks. Do not count repeated focused runs
as additional unique coverage.

Coverage: current exact identity/role/resource/territory, raw-access denial,
listing-only, independent claim review, immutable terms, all four structured offer
types, qualification/exclusions/stacking, revision/reset preservation, selected and
future locations, local schedule/DST, local/state/nationwide country boundaries,
legitimate household source versus membership alone, source/module/person/role
expiry/revocation, replay, two-clerk/final-use races, correction/rebuild, sales
conversion/reassignment, in-app notification lineage/deduplication and 10,000
merchants/40,000 locations/10,000 offers/10,000 leads.

Latest strict typecheck, zero-warning lint, 579/579 application tests and production
build pass. The build uses a nonfunctional public-format fixture, never live Auth
or privileged credentials. Twenty-eight synthetic local render/label/focus checks
pass seven surfaces at 1280/768/390/320. Paging retains finite discovery filters and
rejects private values. Local rendered evidence is separate from hosted acceptance.

Canonical pre-release read-only state: ACTIVE_HEALTHY, 107 migrations, original
administrator active, zero effective controlled membership sources; original
module/relationship/payment/Wallet/sports and Phase 7E hashes captured privately.
No canonical migration, deployment, hosted window, temporary authority or release
commit has occurred. Canonical generated types remain the previous validated
107-migration types; a narrow staged RPC boundary awaits canonical regeneration.

Advisors before release: intentional closed raw RLS/no-policy INFO, existing leaked
password protection WARN, unused-index INFO and absolute Auth connection allocation
INFO. No Auth change, index removal or request timeout increase. Post-migration
advisors and canonical schema/type checks remain required.
See [RLS notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection),
[index notice](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)
and [Auth allocation](https://supabase.com/docs/guides/deployment/going-into-prod).

Local harness incidents: macOS exhausted its shared-memory stub allocation during
a disposable restart. Only the exact failed test's unattached 56-byte stub was
removed after process/key verification. Existing PostgreSQL services and kernel
settings were unchanged. Test-only timing and recovery calls were corrected;
final focused gates pass. No production mutation or security exception resulted.

## Canonical authorization gate

Automatic approval review rejected the first `phase8a_merchant_core` migration
before execution because the source attachment was not accepted as explicit typed
authorization for the exact Phase 8A production mutation. Read-only recheck at
02:56:10.980992 UTC October 8 confirms 107 migrations, zero merchant tables/roles,
active controlled identity and valid original administrator. All prepared SQL byte
hashes remain unchanged. No workaround or indirect execution was attempted.
Direct typed approval was requested for the six exact manifest sources and the
remaining bounded release steps. No live window or temporary access was activated.

The final application recheck removed two duplicate generated Next.js cache type
files, then passed strict typecheck/lint/579 tests/build again. Discovery filter
values persist in the native form and favorite filtering explicitly applies to
offers from favorite merchants. No SQL/migration byte changed for this UI polish.

## Authorized canonical release — October 8, 2026

Direct typed owner authorization cleared the historical review gate. All six exact
prepared SQL sources were applied at 04:07:16–04:07:34 UTC, without changing their
SHA-256 hashes. Canonical history is **113**. All **209/209** live schema/RLS/ACL/
search-path/index checks pass; all thirty pre-release business-table hashes remain
exact. Canonical TypeScript types were regenerated and the staged merchant RPC
casts removed. Post-generation typecheck, zero-warning lint, **579/579** application
tests and the production build pass. A duplicate generated Next cache type copy
was removed before the successful strict recheck; no source security change.

Post-migration advisors: 272 intentional closed-raw-table RLS/no-policy INFO
findings; existing leaked-password-protection WARN; 541 unused-index INFO findings;
absolute Auth connection allocation INFO. No Auth or policy weakening, index
removal or timeout increase. Deployment/CI and the single controlled hosted window
remain pending. No temporary authority or new trial source has been created.

## Release CI harness portability correction

The first release push `2a396fc62852b75d91bd05b9d87909302809affc` passed both
application CI jobs and deployed READY. Database CI passed historical SQL and
prior races, then failed the new Phase 8A expected-error matcher because the
pinned minimal PostgreSQL image lacks ripgrep. The expected duplicate-claim
PT409 occurred; the missing matcher executable caused the failure. The single
matcher now uses standard fixed-string grep available in that image. Focused
247 assertions, 209 schema checks, twelve recovery checks and fifteen races pass
after this harness-only fix. No application/schema/migration/security behavior
changed. Fresh full CI is required before controlled hosted activation.

The exact private bounded setup, legitimate native trial RPC, all five sequential
restricted-role transitions and administrator-first cleanup were additionally
preflighted in disposable PostgreSQL. Six selected recovery assertions pass.
Private script field/lifecycle/fixture errors were corrected before any live
authority activation. One exact 56-byte orphan from the failed sandbox startup
was removed only after key, owner, unattached state and dead-process verification;
other running PostgreSQL services/kernel settings were untouched.
