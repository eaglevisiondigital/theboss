# Phase 6D validation

Phase 6D extends existing Phase 6B Competition Editions with sport-neutral
single-elimination tournament stages, brackets, revisions, seeds, matches,
advancements and rulings. Canonical Supabase project `ilykgwgmxtrrikreacrz`
contains the three Phase 6D migrations; migration history is 73.

Fresh disposable PostgreSQL 17 validation passed the complete historical suite,
86 Phase 6D SQL assertions and ten genuine two-connection Phase 6D races. The
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
pass after generation.

Supabase security advisors retain the intentional closed-RLS informational group
and the pre-existing leaked-password-protection warning. Performance advisors
retain the unused-index informational group and existing Auth connection-allocation
informational finding. No Auth setting, database timeout or unrelated policy changed.
