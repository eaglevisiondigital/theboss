# Phase 6C validation

Phase 6C adds one longitudinal Athlete Profile per canonical participant/person and
an explicitly consented, unlisted Recruiting Showcase. Canonical Supabase project
`ilykgwgmxtrrikreacrz` contains migrations `20261006095630`, `20261006095635` and
`20261006095640`; migration history is 70.

Disposable PostgreSQL 17 validation passed 15,327 SQL/bootstrap assertions and 185
coordinated races. Phase 6C contributes 272 authorization, identity, provenance,
consent, share, stale-write, transfer and raw-ACL assertions plus eight real races.
All 40 new foreign-key vectors are indexed. The ten public tables have RLS enabled
and no direct client grants; public entry functions are invokers, private helpers use
fixed empty search paths, and anonymous share reads receive no private-schema usage.

Generated canonical TypeScript types are 302,222 bytes with SHA-256
`c72b2e1c6f45532c0b6f45c8143fae0bdd4c9d51a4a2e2033f4cf4b1b76d33e3`.
Typecheck, zero-warning lint, 413/413 application tests and the Netlify production
build pass. The narrow hosted defect found during acceptance—missing staff entry
forms for already-supported verified measurables and achievements—has regression
coverage and is deployed in commit `507606972fa73040927afb324d42be2dc3f3273f`.

Security advisors report 130 `rls_enabled_no_policy` INFO findings for intentional
closed RLS surfaces and one pre-existing leaked-password-protection warning.
Performance advisors report 254 unused-index INFO findings and one existing Auth
connection-allocation INFO finding. No Auth setting, database timeout or unrelated
security policy changed.

Correction propagation is SQL/runtime verified against Phase 6A/6B current-generation
sources. It was not mutated in hosted acceptance because doing so would reopen sealed
sport-stat architecture solely for this scenario. This is an evidence limitation,
not a known defect.
