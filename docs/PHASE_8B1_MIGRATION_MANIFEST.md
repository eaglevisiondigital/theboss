# Phase 8B1 exact proposed migration manifest

## Controlled production release addendum: October 9, 2026 UTC

**Canonical foundation applied; Phase 8B1 remains INCOMPLETE pending deployment, CI and the single controlled hosted acceptance window.** Main Boss Chat directly authorized the exact frozen sources and controlled release. Canonical `ilykgwgmxtrrikreacrz` advanced from 113 to 119 with matching SHA-256 content at every migration boundary. The sixteen public tables and private receipt are empty before acceptance. All adapters and credential readiness remain structurally OFF.

Preflight verified branch/remote `4fc7ab53d4d23a75c2eaedebfd3485948ebbe009`, healthy canonical project, original administrator, zero merchant/staff/Sales temporary grants, no pending notification work, and 264 original business table hash/count baselines. All 264 remained equal after migration. Independent disposable administrator-first recovery passed 277 checks. No production role assignment, membership, household, guardian or module configuration changed.

All six source filenames/bytes/hashes are unchanged. The connector assigns canonical ledger timestamps; filenames remain the approved source identifiers. Historical audit found eight documented Phase 6D/6E connector timestamps differing from filenames. Of the original 113 stored SQL hashes, 112 match local source (including normal edge whitespace); the original Football core differs only by the previously documented `scoring_side` forward repair, already present canonically through `phase5d_football_conversion_state`. No historical source or ledger was altered by this release.

Schema checks: 16 public / 1 private relations, RLS enabled throughout, zero raw ACL grants, pinned private helper paths, zero unexpected helper/mapping grants, three public invoker/constant RPCs, zero missing FK-leading indexes, exactly six keys/twelve mappings to the two existing platform roles. No providers, credentials or financial posting seeded.

Canonical database types were regenerated at 119. Application calls now use generated RPC signatures directly, without staged casts. A supplemental disposable schema probe remains validation evidence only. Frozen migration bytes were not changed. Fresh Partner validation passed 522 SQL assertions and 10 coordinated races. Strict typecheck, zero-warning lint, 645/645 application tests and production build passed after clearing duplicate ignored generated Next.js output; no source repair was required for that local artifact collision.

Advisors: 289 intentional closed-table RLS/no-policy INFO notices (including 17 new Partner tables); the existing leaked-password-protection WARN; 555 unused-index INFO notices (44 Partner indexes); existing absolute Auth connection allocation INFO. No policy, Auth, index or timeout setting changed. Remediation references: [closed RLS](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection), [indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index), [Auth allocation](https://supabase.com/docs/guides/deployment/going-into-prod).

Existing Netlify Git CD was read-only verified: repository `eaglevisiondigital/theboss`, active Next.js build, base `apps/platform`, production branch `build/boss-platform-v1`, no platform PR previews. No separate public website configuration changed. Commit/deployment/hosted results will be appended when verified. No controlled hosted window or temporary production authority has been activated yet. Phase 8B2 has not started.

### Canonical application ledger

| Migration name | Canonical version | Applied SQL SHA-256 |
|---|---|---|
| `phase8b1_provider_registry` | `20261009071854` | `980e0219c20eaa01542f132fd2fcf284f8160c82b20dd13fe5ebb0aa3abcfd74` |
| `phase8b1_contract_licensing` | `20261009071944` | `cdc54fb6ae37862a33949125ce9fd9587c8bb1626219ca1a2a563776b5556ce2` |
| `phase8b1_catalog_evidence` | `20261009071956` | `5ecdfc6f808e902c575bc854b434ae6cd32574e248b7fe2cd2543b5d304cbcd9` |
| `phase8b1_revenue_foundation` | `20261009072014` | `be07073abb5631837d2bc185c45a11ef34e82c692b2066d9e4928159774e0fd8` |
| `phase8b1_commands_ingestion` | `20261009072034` | `42bea2325716c2b8a083643827530903deffe61d70b1e7c4b1a4a4f621262c1e` |
| `phase8b1_projections_integrity` | `20261009072053` | `7a3d14b1c6e4b7953afe86b8e00e3c7fa41f7393d3bbeafcaf9b6936620ea250` |

## Preserved historical local checkpoint

**PHASE 8B1 LOCAL IMPLEMENTATION COMPLETE / PRODUCTION RELEASE PENDING EXPLICIT APPROVAL**

Starting branch/head: build/boss-platform-v1 / 4fc7ab53d4d23a75c2eaedebfd3485948ebbe009. Canonical read-only history is 113. Proposed history after separate explicit approval is 119. All original 113 migration byte sequences are unchanged. Six narrow additive sources, in this exact order:

| Filename under supabase/migrations | SHA-256 | Bytes |
|---|---|---:|
| `20261009045245_phase8b1_provider_registry.sql` | `980e0219c20eaa01542f132fd2fcf284f8160c82b20dd13fe5ebb0aa3abcfd74` | 5073 |
| `20261009045300_phase8b1_contract_licensing.sql` | `cdc54fb6ae37862a33949125ce9fd9587c8bb1626219ca1a2a563776b5556ce2` | 4582 |
| `20261009045301_phase8b1_catalog_evidence.sql` | `5ecdfc6f808e902c575bc854b434ae6cd32574e248b7fe2cd2543b5d304cbcd9` | 6322 |
| `20261009045322_phase8b1_revenue_foundation.sql` | `be07073abb5631837d2bc185c45a11ef34e82c692b2066d9e4928159774e0fd8` | 4515 |
| `20261009045337_phase8b1_commands_ingestion.sql` | `42bea2325716c2b8a083643827530903deffe61d70b1e7c4b1a4a4f621262c1e` | 28862 |
| `20261009045339_phase8b1_projections_integrity.sql` | `7a3d14b1c6e4b7953afe86b8e00e3c7fa41f7393d3bbeafcaf9b6936620ea250` | 18489 |

Consequences: 16 new public tables; one private caller-bound receipt table; pinned private helpers and three public invoker/constant RPCs; six exact permission keys mapped to two existing platform roles (12 mappings). No new role, role assignment, organization/team membership, guardian/household relationship, provider seed, Auth setting, production key, existing application table alteration or financial posting. RLS/ACL closes new relations and helpers at every migration boundary. FK/index validation includes composite provider anchors and nonpartial FK-leading indexes.

All raw table access is revoked for PUBLIC, anon, authenticated, service_role and boss_payment_worker. Authenticated may execute only the two private caller-bound read/mutate entry points through public invoker RPCs. Anonymous may execute only the constant empty directory. Provider operations and credentials_ready are structurally locked OFF.

Clean installation and exact upgrade checks use PostgreSQL 17 disposable Unix sockets with no TCP listener. The separate upgrade preflight compares all original relation contracts, functions/ACLs and seeded rows, allowing only six permissions/twelve mappings. See PHASE_8B1_VALIDATION.md for the final run results. Any byte change invalidates this manifest and requires refreezing/revalidation before approval. Do not apply this manifest yet.

No canonical migration, deployment, commit/push, PR update, production test authority or live provider execution is authorized by this checkpoint. Phase 8A remains COMPLETE with its prior evidence limitations; Phase 8B2 has not started.
