# Phase 8B1 portable schema/type probe repair

## October 9, 2026 UTC scope

Main Boss Chat directly authorized repair of the validation harness from starting SHA `157d677c4bbc109936d4b0d131b60e009ef96aa2`, followed by conditional resumption of the original unused hosted window. Phase 8B1 remains INCOMPLETE until its release gates and authorized acceptance are verified. The earlier failed CI and security disclosures remain historical evidence.

## Demonstrated defect and correction

The unchanged pinned PostgreSQL 17.11 image lacks `python3`. The prior Python schema probe therefore stopped both database CI jobs before their acceptance assertions. This is a harness portability defect, not a canonical migration or Partner business defect.

The replacement uses only Bash and `psql`, already required by the existing isolated runner. Read-only PostgreSQL catalog queries deterministically compare all sixteen public Partner table names, column order/names, raw PostgreSQL types and nullability, plus the three public RPC names, argument names/types/modes/default counts, return types and function kinds. The same query renders the supplemental TypeScript contract and compares it exactly with the committed file. A compile-only type bridge checks its table rows and RPC argument/return structures against the canonical generated types used by the application.

The expected catalog metadata is committed separately from the implementation. Validation never updates it or the generated types automatically. A real mismatch exits nonzero. The probe accepts only the disposable runner's private socket, database and user. Its nullable-column negative control runs in a transaction that is rolled back before comparison. A separate generated-type mismatch must also be rejected, followed by a fresh restored positive catalog/type comparison.

No migration, application behavior, RLS/ACL, Auth/session rule, provider restriction, PostgreSQL timeout or CI container configuration changed. The obsolete Python script is removed. No Python installation, network dependency, skipped test or unconditional-success fallback is introduced.

## Validation gates

Focused disposable PostgreSQL validation passed 522 Partner assertions and ten coordinated races. Both deliberate schema/type mismatches were rejected; the restored positive contract passed. Strict typecheck, zero-warning lint, all 645 application tests and production build passed with the canonical type bridge included.

Docker/Podman/Colima are unavailable on this computer. Actual pinned-image verification is therefore required through the existing unchanged GitHub database job, with its digest, offline network, read-only repository and unprivileged controls preserved. Local PostgreSQL success is not classified as pinned-container verification. Push and PR database/application jobs must all pass and the corrected commit must be deployed READY before any hosted activation.

Full historical SQL/race totals, actual pinned CI results, deployment and acceptance outcomes are recorded in the dated validation/completion addenda once observed. No hosted window or temporary authority was activated while preparing this repair. Canonical read-only verification at `2026-10-09T07:48:01.878794Z` confirmed 119 migrations, six unchanged source hashes, original administrator validity, zero Partner resources/operational configuration/pending work and equality of all 264 original selected business baselines. Phase 8B2 has not started.

## Fresh complete local validation after portability repair

October 9, 2026 UTC: the complete disposable PostgreSQL run exited successfully and removed its cluster. Actual unique totals are 23,726 SQL assertions in 149 suites (23,204 historical/generic plus 522 Partner), 28 bootstrap and 33 sealed-source checks: **23,787 aggregate**. All **318 coordinated races** passed (308 historical plus ten Partner). Repeated cleanup/tournament summaries are excluded from unique totals. Both probe negative controls rejected mismatches and restored positive verification passed. The preserved Phase 8A schema gate passed 209/209 and its administrator-first recovery passed twelve checks separately; Partner lifecycle/recovery passed 277. The prior 2,065 independent upgrade-preservation checks remain historical evidence because this task changes no migration.

Strict typecheck, zero-warning lint, **645/645 application tests** and production build passed after the canonical compile-only bridge was included. Actual pinned-image verification and release/hosted results remain pending until independently observed; local success does not substitute for CI.
