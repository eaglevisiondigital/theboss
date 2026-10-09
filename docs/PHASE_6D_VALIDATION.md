# Phase 6D validation

Phase 6D extends existing Phase 6B Competition Editions with sport-neutral
single-elimination tournament stages, brackets, revisions, seeds, matches,
advancements and rulings. Canonical Supabase project `ilykgwgmxtrrikreacrz`
contains the three Phase 6D migrations; migration history is 73.

Fresh disposable PostgreSQL 17 validation passed the complete historical suite:
15,429 SQL/bootstrap assertions and 195 genuine coordinated races. Phase 6D adds
86 dedicated SQL assertions, 16 dynamic wrapper-security checks and ten genuine
two-connection races. The
new assertions cover deterministic generation, manual and standings-snapshot
seeding, unresolved ties, byes, play-in dependencies, third place, official
result advancement, correction reconciliation, downstream locks, rulings,
rebuild equality, cross-organization privacy, stale authority, forged resources
and raw ACL closure.

Bounded measurements passed without changing the database timeout: 16-team
generation 10.851 ms, 32-team generation 11.397 ms, 64-team generation 15.919 ms,
64-team projection rebuild 15.932 ms and official-result advancement 8.459 ms.

All seven public tournament tables and the private receipt table have RLS enabled,
no policies and no direct `anon` or `authenticated` table grants. Only
`boss_tournament_read(jsonb)` and `boss_tournament_mutate(uuid,jsonb)` are exposed
to `authenticated`; no tournament function is exposed to `anon`. Every helper has
a fixed empty search path.

Canonical TypeScript types are 321,982 bytes before the final newline, with file
SHA-256 `250db8073077cd06807ce601bc0cf232865e60c1383e3e01b13a0c21a186168d`.
Typecheck, zero-warning lint, 420/420 application tests and the production build
pass after generation and again after hosted cleanup documentation. The first
final-validation invocation reached and passed typecheck, lint and all 420 tests,
then correctly rejected a production build missing `BOSS_PLATFORM_ORIGIN`; the
complete rerun supplied the approved public origin and passed every stage.

Post-cleanup Supabase security advisors report 138 intentional closed-RLS INFO
findings and the one pre-existing leaked-password-protection WARN. Performance
advisors report 264 unused-index INFO findings and the existing Auth connection
allocation INFO. No Auth setting, database timeout or unrelated policy changed.

Production deploy `6ac4de6ca7ae43000821e72b` is READY and published from
`d5e8a5709ecd205a7de7f9294d33c9a3c456e656`. Implementation-head GitHub runs
`37458092236` and `37458086948` both passed their application and database jobs.
The final closure-head CI result is recorded after the documentation commit.

One fixed hosted window began from a recorded canonical baseline at
11:43:48.809265 UTC. Administrator-first cleanup was recorded at 11:56:04.044106;
explicit restoration completed at 11:56:32.488355; comprehensive zero-residual
verification passed at 11:57:04.685359. The cleanup target was 12:18:48.809265
and hard expiry 12:28:48.809265. The window was never extended. Full evidence is
in [the hosted acceptance record](PHASE_6D_HOSTED_ACCEPTANCE.md).
