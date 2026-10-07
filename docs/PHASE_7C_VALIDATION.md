# Phase 7C local validation checkpoint

Status: MIGRATED; release/controlled hosted acceptance in progress. The exact
binding-rule checkpoint passed the complete fresh historical runner: **18,899**
unique assertions (18,838 across 118 SQL suites, 28 bootstrap, 33 sealed-source)
and **261** coordinated races, including **461** Phase 7C assertions and **33**
Phase 7C races. Each SQL summary is counted once, excluding duplicate cleanup
echoes. Six exact migrations advanced canonical history **89→95**. No controlled
hosted window has been activated yet.

## Environment and isolation

PostgreSQL 17 disposable cluster with rejected host authentication, no TCP listener,
private 0700 Unix socket, statement logging disabled and canonical-like JIT off.
Only synthetic local fixtures are used. Normal test roles own no superuser/OS
privileges. The runner removes each cluster, including failed runs. No external
database, kernel/semaphore configuration or production environment is changed.

The complete runner now includes fourteen Phase 7C SQL suites and genuine independent
two-connection races. Each race confirms a waiting lock before releasing the
writer. Repeatable Read and Serializable contenders establish an older snapshot
and must fail with serialization conflict. Natural guardian/grant expiry, account
deactivation and managed-session removal are exercised without real Auth material.

## Checkpoint results

- Final fresh complete historical SQL/bootstrap/concurrency run: PASS, 18,899 assertions and 261 races.
  The prior checkpoint passed 18,802 unique SQL/bootstrap/sealed assertions and
  254 races; it preceded the binding release implementation and is retained as
  historical evidence, not the final release gate.
- Focused binding-release run: 459 SQL assertions and 33 observed races PASS.
  Seven independent release suites cover full $80, partial $30, multiple grants,
  expiration, invalid/partially invalid replacement and a shared dependency
  chain. Cross-organization release checks and both recovery/source/spend race
  orders pass. The final run must also include the subsequent two unpaired-release
  denial/atomicity assertions and the corresponding deferred proof.
- Typecheck: PASS, generated route types and strict `tsc --noEmit`.
- Lint: PASS, zero warnings.
- Application tests: 470/470 PASS.
- Production build: PASS. Final `npm run validate` also passes with nonfunctional
  public build-fixture configuration supplied only to that local process.
  The first build invocation correctly refused missing configuration; no real
  key was retrieved or stored to make a local build pass.
- `git diff --check` and shell syntax: PASS.
- Synthetic local rendered checkout/receipt/finance reversal: 1280, 768, 390 and
  320 widths have matching document/client widths and zero overflowing controls.
  Explicit accessible labels and disabled empty reversal form were inspected.
  This is local static rendering, not hosted signed-session or hydrated acceptance.
  The QA tab/server were closed and viewport override reset.

## Regression findings and corrections

Local defects were corrected before any canonical release: trigger/PLPGSQL aliases,
finite allocation validation, balanced deferred lineage/recovery proof, invalid
source/expiry restoration and canonical UUID lock order. Mixed-case UUID strings
could disguise a duplicate target in the existing offline allocation count and
new payment input; counts now compare canonical UUIDs. The existing applied Phase
3B migration is unchanged; its function receives the narrow additive fix in Phase
7C. New payment and offline regression cases retain external-tender denial.

The historical foreign-key-index check caught the new tender's composite
organization/payment FK lacking a matching leading-column index. The prepared
ledger migration now includes that index. Legacy catalog assertions explicitly
exclude the one approved new capability and six separately tested new tables
while preserving their old counts. The legacy tender CHECK now recognizes
ledger-backed Boss Bucks; raw orphan denial moves to the deferred-ledger proof
suite. The corresponding historical 3B total changes by one, with new integrity
coverage retained. Offline RPC remains cash/check only and rejects Boss Bucks;
card/ACH/adjustment tender CHECK denials remain intact.

## Performance evidence

201 required positive grant lots fail atomically; 200 lots funding 50 distinct
charge allocations succeed. 154-charge family checkout projection is bounded to
50, activity to 50 and payment history to 50. Finance projection is tenant scoped.
No authoritative mutable wallet balance or national private-table scan is added.

An initial local Family Hub read took 2,561.67 ms, exceeding the local two-second
target. Repeated per-grant payment visibility was batched by distinct payment IDs.
Subsequent focused measurements were 641-702 ms for the family projection,
149-245 ms for the 200-lot/50-charge spend, approximately 251-255 ms for deferred
proof, 75-86 ms for finance and approximately 6.1-6.3 ms for reconstruction.
Family payload was about 69 KB and finance about 91 KB, below the 100 KB target.
Eight-second limits remain unchanged. These are local measurements, not hosted
latency or a national-load guarantee. Historical production timeout/remediation
and proxy-credential disclosures are preserved.

The first complete historical run also exposed an eight-second timeout when
draining deferred proof for 5,000 trusted source grants. The new grant-book join
could repeatedly scan postings sharing one household account, and journal proof
read the same balance twice. A journal/account-parameterized lateral sum and one
local validation read preserve every invariant while avoiding those repeats.
The unchanged long-ledger regression then passed: family read 63.400 ms,
organization report 366.148 ms, reconstruction 10.877 ms, family payload 29,673
bytes. The eight-second deferred proof limit remains unchanged. This was a local
pre-release regression, not a canonical incident. The final combined historical
SQL/bootstrap/sealed-source/concurrency run passes after this fix.

## Canonical/published read-only verification

At `2026-10-07 06:19:14.501555 UTC`, canonical history was 89, last migration
`20261007040726`; Phase 7C tender table absent; original controlled platform
administrator grant active; effective controlled wallet access 0; controlled
wallet grants 0. No Phase 7C live writes were made.

PR #3 remains OPEN/DRAFT/UNMERGED at
`e65703adb5aa6cb03d4ba7bae475d52ae48ea26c`, titled
“Build Boss platform through Phase 7B Boss Bucks Wallet + Ledger”. Published
database and validate checks report SUCCESS. No Phase 7C CI/deploy was created.

## Prepared migration SHA-256 manifest

These exact tested SQL hashes were applied canonically. Filenames now match the
canonical MCP migration timestamps; only names changed, never SQL contents.

| Migration | SHA-256 |
| --- | --- |
| 20261007080035_phase7c_payment_ledger.sql | 0c222096fbb7f66000e7ea22e8db53576802d0c94cdfdc7542689b949c47c818 |
| 20261007080046_phase7c_payment_accounting.sql | 829441ea8dd26acaf4df6eca6d3e19774b24b6e11bcce370c9dbd07722053cef |
| 20261007080050_phase7c_payment_execution.sql | 56039ffa6667771f4446b18b5166c2629cd48f14a6d510e23500dc963f9a727d |
| 20261007080053_phase7c_source_recovery.sql | 6b97b31cc2a80c10cdffaae46e13a8348c64df345ebfe95abdd198b2385991fc |
| 20261007080057_phase7c_payment_projections.sql | 993fd73004c818474f60d0d196b131c80f48fa8dcd2bad82021dcafecc4a1b70 |
| 20261007080100_phase7c_payment_reversal.sql | 6261884004d9d96be633bfd7ec1522bc61f01f8e503c391f759b5627206e78ba |

No real customer/youth data was used. No password, Auth token/session value,
privileged key or historical Netlify proxy value was requested, retrieved,
printed, logged or committed. Existing connectors/CLI performed authenticated
read-only checks without returning credential material. No provider, external
settlement/payout, broader temporary authority or Phase 7D execution was started.

## Binding release implementation and regression evidence

The original invalid source receives no spendable restoration. Covered recovery
returns through actual application rows, most recently applied first; invalid
replacement value removes its released household posting and cancels dependent
recovery through earning clearing, with explicit cause-release/removal-journal
lineage. Expired replacement value retains original expiry. Full/partial and
shared-DAG cases rebuild to the ledger, and no grant is recreated.

The first new chain test had an incorrect row-count expectation: FIFO recovery
allows the same later grant to satisfy both older claims. It was corrected to
expect all four actual application links. A new test also initially referenced
the wrong audit table name; corrected to existing `boss_bucks_history`.
Final review demonstrated that an unpaired privileged release could otherwise
commit without its corresponding liability reduction. The deferred proof now
requires aggregate release no greater than matching cancellation for the same
claim/root payment return; an independent negative case verifies rollback.
The first historical binding run had already loaded the prior function before
that correction, so it stopped at the newly added denial assertion. The fresh full
run from the corrected migration files passes, including both negative assertions.

A disposable-cluster startup encountered macOS shared-memory slot exhaustion.
Exactly two empty owned 56-byte orphan headers, with zero attachments and dead
creator PIDs, were removed after read-only verification. No active database,
service, kernel/semaphore limit or production setting was changed. Subsequent
isolated test startup succeeded.

A Netlify read returned unfiltered deploy metadata, including a deployment-skew
identifier. This is a client-facing deploy fingerprint, as described by
[Netlify's framework API](https://docs.netlify.com/build/frameworks/frameworks-api/),
not an Auth/session/privileged credential. The value is not reproduced here or
used. Subsequent metadata output uses a safe field allowlist. The historical
Netlify deploy-site proxy disclosure remains unchanged; no proxy value was
searched for, retrieved or reused.

## Phase 7C canonical application

Six prepared migrations applied successfully on October 7 at 08:00:35–08:01:00
UTC. Read-only verification at **08:02:07.455778 UTC** confirms history 95, all
six tables, zero RLS/raw ACL/private-helper ACL/empty-search-path failures and
zero uncovered new foreign keys. Both public Boss Bucks RPCs are invoker,
empty-path, authenticated-only boundaries. Grants and tenders remain zero.
Canonical TypeScript types regenerated; focused post-generation validation is
running before commit/deployment.

Post-migration security advisor reports intentional closed-RLS/no-policy tables
and the pre-existing leaked-password-protection warning. Performance reports
unused indexes and the pre-existing absolute Auth connection allocation notice.
No new advisor category appears. Required financial FK indexes are retained.
No Auth or security policy setting was changed.
Remediation: [closed RLS notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[Auth password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection),
[unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index),
[Auth connection allocation](https://supabase.com/docs/guides/deployment/going-into-prod).
