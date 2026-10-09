# Phase 7D validation checkpoint

Status: COMPLETE within the approved unavailable-provider boundary, from `dc55c6cb2f9dc11c0b111b5783a4ec174721c361`. The historical checkpoint below records the original 95-migration state; canonical history is now 101. PR #3 remains open, draft and unmerged. Actual hosted closure is recorded in [acceptance](PHASE_7D_ACCEPTANCE_ADDENDUM.md).

## Historical pre-release validation checkpoint (preserved)

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

## Release CI harness correction

Implementation `37ea3eda85c25261e20be0b4266979db0e9d617e` deployed READY through
the existing Boss Git deployment at **18:01:20.023 UTC October 7** (deploy
`6ac688c3cf574700087a54c6`). Both push/PR application jobs passed. Their database
jobs passed SQL/bootstrap/sealed suites and prior concurrency checks, then exited
127 because the new Phase 7D race fixture generator called Python, which is absent
from the pinned networkless PostgreSQL image. The hosted acceptance window stayed
inactive.

The narrow correction replaces Python fixture transformations with the image's
existing awk/sed and computes the synthetic capability digest in PostgreSQL.
Race scenarios, SQL assertions, migration bytes, application behavior, runner
isolation, statement timeout and security policy are unchanged. The focused
disposable run passes all 318 Phase 7D assertions and 22 observed races; its
cluster was removed. Replacement full release CI remains required before
activating the single hosted window.

Replacement push and PR CI passed on
`c425cb05ca5cff331a0ecd020036f4857cd90219`; PR run `37665654817` database completed
**18:32:02 UTC**. This was the complete historical database job in the unchanged
pinned, networkless PostgreSQL image, including all 283 races. Both application
jobs passed typecheck/lint/543 tests/build. No runner network access, dependency
installation, timeout increase or assertion removal was used to make it pass.

## Controlled hosted closure

The sole fixed window activated **18:33:27.198907 UTC**, stop-new deadline
**18:48:27.198907**, cleanup target **18:53:27.198907**, hard expiry
**19:03:27.198907**. Explicit restoration confirmed **18:38:28.206401**, and
zero-residual verification **18:38:55.818434**. There was no extension, repeated
window, failed restoration transaction or deadline overrun. Administrator-first
verification preceded relationship/module restoration in the same transaction.

Native signed acceptance passed $500 unpaid charge, $0 Bucks/$500 external split,
disabled collection, sandbox draft create/disable, exact-route disabled boundary,
empty finance/payout-unavailable states, required explicit policy fields, navigation,
reload, four widths/accessibility, Child2/nonexistent-charge/unrelated-org family
GET denial and post-guardian-revocation denial while household memberships stayed
active. Native charge cancellation and post-cleanup family/admin views passed.
No processor request or instrument entry occurred. Native selector mismatches
were resolved by fresh visible state and caused no duplicate request/window.

Exact selected business baseline matches guardian/all capabilities, household
memberships, original 20 module rows and unchanged role/org/team hashes. Wallet
remains retired/access ended; registration/offering archived, charge canceled,
sandbox draft disabled, new module inactive/configuration cleared. Payments and
allocations remain 6/6; grants/trusted success zero. All 65 sports-source rows and
one achievement match the fresh superset hashes. Pending controlled notification
sources, expansions and deliveries are zero. No binding/checkout/operation/tender/
settlement/recurring work exists. Only expected inactive/canceled controlled
fixtures, six payment-history rows and two native request receipts remain.

Final read confirms exactly **101** migrations, unchanged six SQL hashes and
canonical type hash `c3f1b28abe85d54523ccf8e56d9334cd53fa71a6cc737c91784f35b0ea1cc5e0`.
Final closure edits are documentation only; delivery/PR records its exact head/CI.

Sanitized process disclosure: during earlier checkpoint review, a historical
controlled Phase 7C recovery snippet was inadvertently included in tool output.
It contained controlled restoration steps/identifiers, no credential/session/key,
instrument or real person data. It is not reproduced in committed reports, and
Phase 7D activation/recovery scripts stayed private. Prior timeout/security/proxy
disclosures remain intact; no historical credential-bearing URL/value was searched,
inspected, tested, reproduced or reused.
