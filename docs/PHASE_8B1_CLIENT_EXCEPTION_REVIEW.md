# Phase 8B1 client exception attribution review

## October 9, 2026 UTC: diagnostic review and local reproduction

**Phase 8B1 remains INCOMPLETE. The original controlled hosted window remains UNUSED.** Starting source is `1ed576798239927b46965c629ab73a9a2d8b2a96`. Main Boss Chat separately authorized this investigation, minimum necessary finite attribution improvements and an optional diagnostic-only release. It did not authorize a Partner fixture, temporary production authority, acceptance resumption or Phase 8B2.

### Original five-record evidence

The original private export remains unchanged outside Git. All records identify diagnostic commit `afef25e41c616780f81c36db71b53a6a05705927`, deployment `6ac8e5e7801e9100080b4e51` and constant route `/app/partners`.

| UTC on October 9 | Phase/stage | Correlation | Actual evidence |
| --- | --- | --- | --- |
| 13:06:07.790 | server-component / page_enter | `c6a29eaa-99dc-415c-b445-6456df11cc28` | Page entered. |
| 13:06:08.210 | server-component / read_started | Same read correlation | Read started. |
| 13:06:08.670 | server-component / read_completed | Same read correlation | HTTP 200. |
| 13:06:10.472 | client / client_exception | `a2e7e9b8-6343-4291-ac3c-be6a7dc16cc4` | Generic `Error`; source/digest/status null; observer is the global instrumentation hook. |
| 13:06:10.475 | client / client_rendered | Original read correlation | Workspace rendered; no visible boundary was observed. |

**Historical root cause remains UNKNOWN.** The separate exception UUID is not proof of another HTTP request or business operation. Successful rendering does not identify an exception as harmless.

### Established listener and framework behavior

The two original global listeners in `src/instrumentation-client.ts` passed `event.error` and `event.reason` through the same Partner stage/classification/observer. They did not preserve which listener fired. Route selection identifies the current exact Partner pathname, not the origin of the exception. No arbitrary event object, event filename, private URL or browser storage is required or retained.

The actual pinned versions are Next.js **16.3.7** and React/React DOM **19.3.0**. Bundled Next documentation places synchronous client instrumentation before React hydration. `next/dist/client/app-index.js` installs `onRecoverableError`; `react-client-callbacks/on-recoverable-error.js` calls `reportGlobalError`, whose modern-browser implementation is `reportError`. That produces a global error event. In production, the callback does not populate its development-only recoverable-error WeakSet. Thus neither the generic error shape nor a public instrumentation hook establishes a production event as recoverable. No Next internal module was imported or patched in production.

The global `error` listener is non-capturing. Ordinary non-bubbling resource-element failures are not themselves evidence from this listener; historical metadata cannot identify or exclude all script/resource-related causes. Unhandled rejection, recoverable framework reporting, unrelated global code and actual uncaught code remain possible origins. An error caught by the explicit native boundary can instead produce an `error_boundary` record without a global exception.

Reference behavior: [Next client instrumentation](https://nextjs.org/docs/app/api-reference/file-conventions/instrumentation-client), [React hydration callbacks](https://react.dev/reference/react-dom/client/hydrateRoot#parameters), [HTML error reporting](https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception). The pinned installed source, rather than assumptions about newer releases, is authoritative for this build.

### Correlation initialization

`PartnerWorkspace` registers its read correlation through `partnerClientRendered` in a passive effect. Before registration, the global handler has no supplied correlation. Its fallback is the registered mutation response, read, boundary or a newly generated UUID, in that order. Local experiments establish that an early global error/rejection can receive a fresh UUID before the read is registered; v1 did not record cache state, so the precise historical fallback branch cannot be established from those five records alone.

| Context | Existing correlation behavior; unchanged by this improvement |
| --- | --- |
| Before first effect / hydration before read registration | Fresh opaque UUID if no context exists. Not a request identity. |
| After successful render | Registered read correlation. |
| While a mutation awaits its response | Still the registered read; the explicit mutation-start record has its own client trace. Do not infer that the global event originated in that mutation. |
| After response / during refresh | Registered response correlation; refreshed render links its parent response then registers the new read. |
| Initial boundary / retry | Boundary correlation retained for retry until rendering establishes a read. |

### Prior Merchant comparison

The earlier retained Merchant observation at `08:00:54.966Z` was a generic Error with null source/digest and no visible boundary, followed by successful archived Merchant rendering at `08:00:54.971Z`. Its read completed HTTP 200 at `08:00:53.410Z`; commit `7c44c6251c436a13996c464b4798d4fd34d0a137`, deployment `6ac89ee8964e350008f5fd4a`, read/render correlation `64c48270-e001-4908-a1b6-b72236f1a415`. Merchant and Partner use the same global hook and effect-time registration pattern. These are shared observations and mechanisms, **not proof of a common cause**. The retained Merchant summary does not contain its exception correlation. Merchant/Sales handlers and diagnostic schema remain unchanged.

### Minimum justified improvement

Only three production source files change: `src/instrumentation-client.ts`, `src/lib/partners/diagnostics-client.ts` and `src/lib/partners/diagnostics.ts`.

- Future Partner global records distinguish **window_error** from **unhandled_rejection**, based only on the listener that actually fired. They retain `client_exception` and the stop requirement.
- Partner schema **boss.partner.diagnostic.v2** adds only finite `trace_state`: `uninitialized`, `read`, `mutation_response` or `boundary`; null for server/missing/invalid context. It describes registered context **before** the current event, not error origin or operation identity. A `client_rendered` event may therefore carry `uninitialized` while explicitly naming the read being registered immediately afterward.
- Existing finite category/digest/source filtering is unchanged. No raw event, message, stack, filename, URL, request body or personal/provider/Auth identifier is added. Existing unknown-result/idempotency semantics, UUID fallback and confirmation/boundary behavior are unchanged.
- No event is automatically labeled `recoverable_framework_event`; no exception is suppressed or canceled. Historical v1 exports are not rewritten or retroactively classified.

### Actual local integration evidence

The existing disposable harness ran production-mode pinned Next/React with its supported Webpack build (the dependency symlink is incompatible with the disposable Turbopack filesystem root). It used actual Partner page/route/components and synthetic local identity/RPC transport. All fault producers and seams stayed outside Git/production. This is **LOCAL APPLICATION VERIFIED**, not hosted or canonical feature acceptance.

| Experiment | Actual result |
| --- | --- |
| Successful initial render | `client_rendered`; no exception. |
| Global Error before first render | `window_error`, uninitialized, fresh UUID at `14:20:16.261Z`; different read/render UUID at `14:20:16.272Z`; no boundary. |
| Unhandled rejection before first render | `unhandled_rejection`, uninitialized at `14:20:25.033Z`; successful render at `14:20:25.034Z`; no boundary. |
| Deliberate SSR/client text mismatch | Actual Next recoverable hydration reporting produced `window_error`, generic Error, null source/digest at `14:20:34.465Z`, followed by render at `14:20:34.466Z`; no boundary. The controlled producer proves this local case only. |
| Actual Partner component throw | Native boundary at `14:20:50.235Z`; no successful Partner render and no global-exception record. |
| Actual server page throw | Server exception and native boundary matched digest `650705309`; boundary `14:21:26.604Z`. |
| Native server-boundary retry | Same boundary correlation at `14:21:43.971Z`, then recovered render `14:21:44.022Z`. |
| Post-render global error/rejection | Distinct listener classifications; both use registered read. |
| In-flight native mutation | Deliberate global event retained read context, without claiming mutation origin. |
| Confirmed response and router refresh | Deliberate event used mutation-response context; new render linked the response. One synthetic provider and one receipt remained, with no automatic duplicate. |
| Full reload / discovery navigation | Successful populated reload and discovery render. |
| Broken diagnostic sink | Workspace continued rendering; no diagnostic recursion or boundary. |

The local hydration, global-error and rejection experiments can all reproduce the broad historical sequence. **This demonstrates that timing plus generic Error is insufficient, not that the historical event was hydration recovery.** Production minified/unlisted frames remain null rather than being copied or guessed.

Finite server/client evidence is owner-private, mode 0600 in a 0700 directory, reopened and matched. The runner's transient synthetic framework output was filtered to finite records and its unfiltered buffer removed; no unrestricted production/browser logs or confidential data were exported. The local server and task tab were closed.

### Validation and release boundary

Nine new attribution/privacy/regression tests: **seven failed before / nine passed after**. Focused Partner/Merchant diagnostics: **30/30 PASS**. Full application suite: **663/663 PASS**. Strict typecheck, zero-warning lint and production build PASS. Only ignored duplicate generated Next artifacts were cleared. No migration or database layer changed; fresh full push/PR SQL/security/recovery CI is required for the diagnostic release and reported separately after actual completion.

Read-only canonical pre-release checks at `14:14:48.411632Z` through `14:14:57.117902Z` confirm the original administrator, **119** migrations, six approved unchanged hashes, intact RLS/ACL/helper paths, **264/264** original baselines, zero Partner rows/configuration/work and adapters OFF. No production role, relationship, fixture or financial state was mutated. Optional release/READY and any one harmless read result are appended after observation, never presumed here. No two-read acceptance preflight is resumed by that diagnostic read.

### Exact acceptance-gate recommendation

**Keep the existing stop rule.** Unexpected `window_error`, `unhandled_rejection`, `client_exception`, contract/HTTP failure or boundary still stops new scenarios. `trace_state=uninitialized`, a new diagnostic UUID, HTTP 200 or a subsequent successful render is not an exemption. Historical retrieval remains UNSATISFIED/UNKNOWN and the continuous live-monitoring alternative remains conditional.

Do not approve a recoverable-event exemption from these historical records. A future narrowly defined exception would require independently specific first-party framework attribution that distinguishes recovery from unrelated/uncaught errors, preserves finite-only privacy and still stops on unmatched events. Review that separately with Main Boss Chat before resuming the original unused window. No Phase 8B2 or formal Phase 8B1 closure follows from this investigation.
