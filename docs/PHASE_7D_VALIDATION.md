# Phase 7D validation checkpoint

Status: final release validation in progress; unpublished from `dc55c6cb2f9dc11c0b111b5783a4ec174721c361`. Fresh canonical read: ACTIVE_HEALTHY, exactly 95 migrations and none Phase 7D. PR #3 remains open, draft and unmerged; published baseline CI passes.

The original two populated migrations are preserved byte-for-byte. The reported six validated drafts were not present: four dependent CLI-generated migrations now complete the actual six-file source set. No claimed hash is substituted for a missing file. The final manifest must record the actual tested six hashes before canonical application.

Focused disposable PostgreSQL 17 validation passes **318 Phase 7D assertions** and **22 observed two-connection races**. Eight-second SQL timeout, private Unix socket/no TCP, synthetic fixtures and cluster cleanup remain unchanged. The last complete historical run passes **20,442 unique SQL/bootstrap/sealed assertions**: 20,381 across 126 SQL suites, 28 trusted bootstrap and 33 sealed-source assertions. All **283 races** pass, including 261 historical and 22 Phase 7D. Each suite summary is counted once; repeated historical cleanup echoes and the isolated tournament SQL replay are excluded. The disposable cluster was removed.

Application validation: strict typecheck, zero-warning lint and production build pass with a nonfunctional local publishable-key fixture. **543/543** application tests pass, including provider contracts, unknown reference retrieval, financial input security, receipts, disabled execution, signed route boundaries and rendered UI. Canonical type regeneration/post-generation checks remain release steps.

Synthetic rendered family and finance views pass 1280/768/390/320 widths with no document overflow, missing form labels or unnamed buttons, and an accessible status announcement. Fresh isolated headless Chrome uses only a loopback synthetic preview and a disposable profile; no existing Auth/browser profile is accessed. Updated touch/focus presentation also passes the same checks.

Provider evidence is **LOCAL CONTRACT TESTED; SANDBOX UNAVAILABLE** for Authorize.Net/NMI. No real provider request, instrument or production money movement occurs. The private operational DB/secret resolver remains unprovisioned and recurring execution inactive; deployed checkout/webhook paths fail closed. No provider result is fabricated.

Financial decisions: capture success is distinct from authorization/batch settlement/payout; ACH pending holds and unknown holds survive original intent/tile clocks; committed eligibility survives natural campaign expiry; explicit invalidation prevents automatic downstream effects. Partial refunds before and after settlement, direct-settlement deficits, future same-org offsets, settlement request review, authoritative ACH returns and original-tender refunds pass. Canonical wallet/source recovery and immutable tile chronology remain authoritative.

Live migration, advisor, hosted acceptance, baseline/cleanup, deployment and final CI evidence will be appended after the gated release. No temporary authority has been activated at this checkpoint; no Phase 7E work is started.

## Canonical application

All six exact SQL sources applied successfully to `ilykgwgmxtrrikreacrz`, history **95→101**, at 17:49:54–17:50:09 UTC October 7. Actual versions and byte hashes are in [manifest](PHASE_7D_MIGRATION_MANIFEST.md). Canonical types are regenerated; post-generation validation caught and corrected a JSON array type-narrowing issue, without changing authorization or money behavior.

Canonical checks: all 33 new public raw tables have RLS; zero raw ACL leakage to anon/authenticated/service_role/NOLOGIN worker; zero anonymous private-schema access or signed-worker execution; zero unsafe rails helper search paths. The private worker remains NOLOGIN/non-super/non-bypass/non-inherit. No processing account/binding/checkout/settlement/recurring work or controlled-window audit existed after migration. Financial, role/membership, all 65 sports-source and achievement baselines remain equal.

Security advisor: intentional closed RLS tables without policies ([explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)); existing [leaked-password-protection warning](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Performance: informational [unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index) and [absolute Auth connection allocation](https://supabase.com/docs/guides/deployment/going-into-prod). No Auth setting changed, no protective index removed, no timeout increased.

The initial migration call was automatically rejected before execution because the attachment was not accepted as exact production authorization. A fresh read confirmed no write; direct typed owner authorization was received, and only then were the same six hash-tested sources applied.

Post-generation validation: strict typecheck, zero-warning lint, **543/543** application tests and production build PASS against actual canonical types. The new read RPC uses the generated signature with bounded JSON shape validation. No production secret was read. Final schema filenames match canonical versions with identical SQL bytes; historical release checks and all 283 races remain valid.
