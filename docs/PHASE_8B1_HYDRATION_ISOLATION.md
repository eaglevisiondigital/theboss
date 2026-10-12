# Phase 8B1 browser and React hydration isolation

October 9, 2026 UTC. **Investigation and narrow local correction complete. Phase 8B1 remains INCOMPLETE; the original controlled hosted window remains UNUSED.** No hosted Boss application read was performed in this assignment.

## Conclusion and evidence boundary

**PROVEN:** the shared communications timestamp formatter used the environment's implicit timezone during server rendering and initial client hydration. A populated notification drawer is rendered in the authenticated shell even when closed. With UTC on the server and PDT in the browser, its `<time>` text differs. The actual pinned framework emits recoverable React error 418, then reports the same error object through the global error channel before Partner's effect registers its read context. Partner still renders successfully milliseconds later.

**SUPPORTED POSSIBILITY:** this shared mechanism explains the shape of the earlier Partner/Merchant events. **UNKNOWN:** the producing module of the historical hosted event at `2026-10-09T14:39:19.363Z`. Its finite records do not include a recoverable callback, React code or the actual mismatching text. It is not retrospectively identified as hydration recovery. A deliberate uncaught script exception also reproduced the generic pre-render/error-then-success pattern. Successful rendering is not proof that an error was harmless.

## Exact inspected path

Root layout → authenticated app layout → navigation and NotificationDrawer → NotificationCard → prior `thread.tsx` formatter → server/client `<time>` markup. The Partner administration/discovery and Merchant server pages, projections, client workspaces, instrumentation, trace registration and native `src/app/error.tsx` boundary were inspected. The first mismatch is shared shell timestamp text; no Partner business command, invalid DOM nesting, offer lifecycle or session transition is needed for the local reproduction.

The synthetic instant `2026-10-09T13:00:00Z` produced `Oct 9, 1:00 PM UTC` in server HTML and `Oct 9, 6:00 AM PDT` in the browser. Empty drawer and static-page controls did not produce the error. Disabling only the disposable diagnostic listener did not prevent it.

## Production-mode differential matrix

Every row is **LOCAL APPLICATION VERIFIED**, with synthetic projections and no real authentication. Times below are October 9, 2026 UTC. “418” means the recoverable callback and same-error-object global dispatch were both observed, not inferred from timing. After timestamps are successful local-render witnesses with no recoverable/global event in that navigation.

| Case | Before repair | Before first callback/global / render | After repair / render |
|---|---|---|---|
| A: static, no app shell | No error | render 15:25:51.151 | No error / 15:38:27.658 |
| B: exact app shell, populated drawer | 418; `time` boundary | 15:26:19.593 / 15:26:19.601 | No error / 15:38:37.399 |
| C: actual Partner administration | 418; pre-trace global error | 15:26:23.663 / 15:26:23.665 | No error / 15:37:47.866 |
| D: actual Partner discovery | 418 | 15:27:03.436 / 15:27:03.438 | No error / 15:39:01.040 |
| E: actual Merchant workspace | 418 | 15:27:07.507 / 15:27:07.510 | No error / 15:39:05.723 |
| F: Partner global diagnostic listener disabled locally | 418 still emitted | 15:27:21.429 / 15:27:21.433 | No error / 15:39:15.715 |
| G: Partner normal listener restored | 418 | 15:28:22.368 / 15:28:22.370 | No error / 15:41:46.282 |
| Partner empty drawer | No error | render 15:27:45.455 | Separate populated repaired row above |
| Ordinary Chrome | 418 | 15:28:08.967 / 15:28:08.978 | No error / 15:37:51.925 |
| Clean Chrome Guest | 418 | 15:29:34.393 / 15:29:34.396 | No error / 15:39:00.268 |

Guest's native extensions page stated extensions are unavailable to Guest users. No production sessions/storage were migrated or read. Extension injection is not necessary for this local reproducer; that does not exclude all possible historical hosted causes. The after-repair browser still displayed PDT, proving localization was preserved.

The disposable copy used actual Next 16.3.7 and React 19.3.0, production mode and a UTC server. Actual source routes/layout/components were retained, with synthetic Supabase transport at the local factory seam. Its build used webpack because the disposable symlinked dependencies are outside Turbopack's root; it does not reproduce the Netlify adapter environment. The repository's ordinary production build used its unchanged compiler configuration. No live RPC, Auth session, provider or database write was made by the harness.

Only the disposable copy of Next's `react-client-callbacks/on-recoverable-error.js` and `error-boundary-callbacks.js` was instrumented. Causal records used WeakMap identity of the actual error object/cause to link callbacks to global dispatch. Local component-stack examination exported only a finite allowlist; the minified stack identified `time`, while the exact source, empty/populated differential and repair identify NotificationCard/formatter. Production framework internals, global error handling and diagnostic source were not patched or suppressed.

## Negative controls

| Deliberate local fault | Exact evidence | Result |
|---|---|---|
| Independent hydration text mismatch | callback 15:39:55.810; global 15:39:55.811; React 418 | `react_recoverable`, no native boundary; repaired timestamps do not hide other mismatches |
| Component-render exception | callback 15:40:19.201; native boundary at 15:40:19.290 | `react_caught`, actual “We couldn’t load this page.” heading |
| Server-render exception | server 15:40:36.356; caught callback 15:40:36.465; boundary 15:40:36.473 | server/boundary digest `1838474822` matches; source remains null; serialized React 441 not mislabeled recoverable |
| Promise rejection | rejection 15:40:51.357; render 15:40:51.360 | `unhandled_rejection`, no recoverable callback |
| Unrelated reportError before the normal listener registers | global 15:41:03.821; render 15:41:03.838 | `unattributed_window_error`; local witness sees it, normal listener is not yet registered |
| Actual uncaught script throw before trace initialization | global 15:41:24.305; Partner window_error/uninitialized 15:41:24.306; render 15:41:24.312 | `unattributed_window_error`; successful render does not make it hydration or safe |

A React root-level uncaught callback was instrumented but not separately exercised; the actual uncaught JavaScript control above was exercised. No new production origin classifier was added. The original acceptance STOP rule remains intact.

## Minimal repair and regression

`CommunicationTimestamp` supplies fixed UTC server and first-hydration output with React's supported `useSyncExternalStore` server snapshot, then uses the browser timezone after hydration. This follows [React's server-rendering contract](https://react.dev/reference/react/useSyncExternalStore#adding-support-for-server-rendering). Absolute `dateTime` values, invalid-date handling and final local-time formatting are preserved. Notification cards, message/edited timestamps, delivery history and conversation-list timestamps share the correction; the old formatter export remains compatible.

The real NotificationCard timezone regression **failed before repair** (UTC vs PDT text) and passes afterward. Three checked-in regressions cover UTC/Los Angeles/Auckland, date crossover, both DST transitions, invalid timestamps and message/delivery absolute instants. The production-mode browser matrix separately exercises real client hydration rather than treating SSR tests as hydration proof.

No security policy, contract/projection shape, notification operations, authorization, module configuration, schema, migration, dependencies or business rule changed. No production fault injector, diagnostic endpoint, logging vendor, timeout increase or error suppression was added.

## Validation, confidentiality and baselines

Local focused Partner/Merchant/Sales/privacy/diagnostic/hydration tests **103/103 PASS**. Full application tests **666/666 PASS**, zero failures/skips. Strict typecheck, `eslint --max-warnings=0`, normal production build and `git diff --check` PASS. The first typecheck was blocked by duplicate ignored `.next` generated files; only that generated directory was cleared and the complete validation then passed. Inert repository CI-format environment values were used, not working credentials. Existing database/security CI must pass for the repair commit; actual run IDs and Git deployment metadata are recorded in the final report/PR after observation.

Read-only administrator-first canonical verification at `2026-10-09T15:39:29.269148Z`, baseline/boundary checks through `15:39:52.227305Z`: administrator valid; **119 migrations; all six approved hashes unchanged; 264/264 original business counts/hashes equal**. Sixteen public plus one private Partner tables total zero rows; providers/operational configuration OFF; pending notification work zero; intact RLS/ACL/helper paths and mapping boundaries. Existing role/membership/module baselines are unchanged, so no temporary authority arose. Merchant, financial, Wallet, membership, sports and achievements remain unchanged. No canonical mutation or advisor-affecting schema change was made.

Only finite synthetic causal fields were retained privately (directory 0700/file 0600), reopened equal; prior historical exports remain unchanged. No password, token, session, privileged key, provider secret, redemption capability or historical proxy value was requested, retrieved, exported or committed. No real customer/youth/provider records were used. An active-window race during native Chrome cleanup was promptly checked; the original owner window remained available. No security or credential setting changed. The disposable loopback server was stopped and its synthetic raw runner buffer removed after finite server-error filtering.

## 24-point return record

1. Starting SHA `6e37b406ff8ae7f324c6e08e3e2581b02bd008ab`; repair/final SHA is reported after commit.
2. Shared root/auth shell findings: populated closed drawer's timestamp is nondeterministic across timezones.
3. Static page: clean before/after.
4. Authenticated shell: 418 before, clean after.
5. Partner administration: 418 before, clean after.
6. Partner discovery: 418 before, clean after.
7. Merchant: 418 before, clean after; synthetic only.
8. Listener differential: observer, not necessary cause; normal listener retained.
9. Clean Guest: reproduced before, clean after; no copied sessions/extensions.
10. Pinned framework: actual Next 16.3.7/React 19.3.0 callbacks, production local matrix.
11. Recoverable attribution: same-object callback → window_error proven locally.
12. Uncaught attribution: deliberate script exception distinct; historical producer UNKNOWN.
13. Proven local source: shared NotificationCard → communication formatter → time text.
14. Local root cause timezone mismatch; historical hosted origin UNKNOWN/supported possibility.
15. Actual application defect established; no Partner business/security defect inferred.
16. Small shared timestamp correction; failing-before/passing-after regression and real browser matrix.
17. Finite private synthetic evidence only; no credential/session extraction or export.
18. Full application 666/666; focused 103/103.
19. Strict typecheck/zero-warning lint/production build PASS.
20. Exact commit CI and READY release results are independently returned after observation; no CI success implies hosted acceptance.
21. Canonical 119/six hashes/admin/264 baselines/zero Partner records-work/OFF verified read-only.
22. Existing PR #3 must stay OPEN/DRAFT/UNMERGED; actual state returned after update.
23. Hosted window UNUSED; no new production Boss application read, fixture or temporary authority.
24. Main Boss Chat must separately decide whether to authorize a bounded post-repair harmless-read diagnostic preflight. Require exact READY build, baseline/admin checks and matching safe server/browser evidence; STOP on any unexpected error. Only a successful separately authorized preflight can support a later decision to resume the original unused window under its reviewed recovery/deadlines. No automatic restart, error waiver or Phase 8B2.
