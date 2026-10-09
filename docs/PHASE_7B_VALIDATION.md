# Phase 7B validation

Starting branch: build/boss-platform-v1, 98a2b47f3f5339eab93eef9b685bb4ffb15d6e26.
Five prepared validated SQL files plus one narrow corrective migration applied to canonical Boss. Tool-recorded canonical
versions are 20261007035435, 20261007035439, 20261007035442, 20261007035446 ,
20261007035450 and corrective 20261007040726; local filenames match that history without changing validated SQL.
History is 89. Live checks pass for 11 wallet tables, RLS, zero raw anon/authenticated/
service-role ACL, trusted helper closure, empty search paths and complete FK indexes.
No earning policy or historical source credit was seeded.

Full historical PostgreSQL 17 run passed, including bootstrap, sealed sources and
228 coordinated races (217 historical + 11 wallet). Final focused Phase 7B run
passed operations 13, long-ledger 10, policy/preview 18, scopes 8 and wallet/ACL 165;
7 additional malformed-journal assertions pass. New explicit Phase 7B total: 221.
Across the full run plus the final focused additions: 18,850 SQL/bootstrap/sealed
assertions (18,790 full-run table-reported + 33 sealed + 27 new focused additions).
Historical schema/ACL loops legitimately expand with the new domain; this total
is measured from current output rather than adding 221 to an old handoff count.
Historical catalog assertions exclude only the exact four new permissions and
eleven reviewed wallet tables; their historical invariants remain enforced.

All six malformed journals were rejected: floating single posting, unbalanced
pair, wrong currency, wrong organization clearing, foreign original journal and
premature expiration. Failed writes leave the original two grants/four postings
intact. Private owner resolution retains the captured source policy and household
snapshot while appending explicit current-authority ownership evidence.

All 11 real observed lock-wait races pass: competing first grants, duplicate source,
grant/reversal, reversal replay, policy/grant, guardian revoke/read, invalid source/
grant, posting/rebuild, expiry/read, expiry/rebuild and immutable restriction.
Eight-second request/database ceilings remain unchanged. Disposable fixtures use
synthetic identities only, no live credentials, no network and no paid production
fixture. The local shared-memory limit blocked a parallel test launch; only this
task's verified unattached 56-byte orphan was removed. No unrelated process,
segment or kernel setting was changed. Both clusters were subsequently removed.

Typecheck, zero-warning lint, 454/454 application tests and production build pass
before release; post-generation checks and CI gate are recorded in the final
handoff. All actual family/admin/empty components rendered at 1280/768/390/320
with zero horizontal overflow and zero unlabeled visible form controls. Statuses
use explicit text; source references appear only in authorized organization slices.

Advisors: no ERROR; pre-existing leaked-password protection WARN remains. RLS
without policies is intentional deny-by-default with raw ACL closed. Performance
notices are unused indexes and Auth absolute connection allocation; no missing
wallet FK index was reported. See PHASE_7B_ADVISORS.json for remediation links.
Auth settings were not changed. Prior dependency/security exceptions remain
disclosed; Phase 7B changes no dependencies and grants no provider secret access.

Canonical positive issuance classification: SQL/RUNTIME VERIFIED; HOSTED POSITIVE
UNVERIFIED DUE TO APPROVED NON-PAYMENT SOURCE LIMITATION. Canonical trusted
success evidence count is zero. Hosted empty-wallet acceptance and explicit cleanup
are complete; see PHASE_7B_ACCEPTANCE_ADDENDUM.md. Final application deployed
95a044723a921171936e9081f1282f6de35c708d; no temporary authority remains.

The final explicit-access regression exposed a table-specific trigger dispatch
defect before any temporary hosted authority was activated. The shared identity
trigger evaluated a wallet-only field on an access row. Corrective migration
20261007040726 dispatches by table before resolving fields; it changes no identity
rule or permission. All six Phase 7B suites and 11 races pass after correction,
including explicit access ending, fresh-authority replay denial, independent
guardian revocation, two-currency separation, retirement and immutable currency.
Canonical generated type structure is unchanged by the private trigger fix.

Hosted 320px verification then exposed an outer organization form selector that
was missing from the local component fixture. The existing sizing rule now covers
that control; the fixture includes the outer form. Post-fix typecheck, zero-warning
lint, all 454 tests and build pass. Native published own-org report at 320px has
innerWidth = scrollWidth = 320. All other hosted wallet/preview/Family Hub widths
passed. Final canonical generation matches committed types exactly.

Post-correction canonical verification: 89 migrations, 11 wallet tables with RLS,
zero raw anon/authenticated/service_role table grants, zero unindexed wallet FKs
and zero wallet routines lacking empty search_path. Security/performance advisors
have no ERROR; post-cleanup unused-index count is 343 after controlled read activity.
No Auth or timeout setting changed. All temporary authority ended before the fixed
cleanup target; sports baselines and source hashes match. Expected updated_at
changes on restored historical relationships are transparently retained.

The superseded 084e4b7 push run failed the historical Attendance Calendar race
synchronization; its equivalent PR run passed. It did not report a wallet assertion
failure. Local full historical and corrected focused runs passed. Final head CI
is checked separately and recorded in the final release handoff; this failed
historical run is not erased or described as a pass.
