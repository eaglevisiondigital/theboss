# Phase 8A sanitized merchant diagnostics

Phase 8A remains **INCOMPLETE**. The original hosted post-submission failure
remains **UNKNOWN**. This diagnostic release is not a speculative repair or
permission to open another acceptance window. All previous acceptance history
and sanitized incident disclosures remain authoritative.

## Capture and privacy boundary

The pinned Next.js **16.3.7** bundled documentation and type declarations define
`Instrumentation.onRequestError`, `instrumentation-client.ts` and the App Router
error boundary's **`retry`** prop. These supported interfaces are used directly;
no experimental reporting hook, error-interface change or monitoring vendor was
introduced.

Only `/app/merchants` and its existing mutation route emit the
`BOSS_MERCHANT_DIAGNOSTIC ` JSON channel. The serializer reconstructs an explicit
field allowlist: schema, UTC timestamp, validated public commit/deployment IDs,
constant route template, finite phase/stage/classification/operation, opaque
correlation/parent IDs, allowlisted observing file, actual known HTTP status,
finite exception category, decimal Next digest and nullable safe source location.
Existing Netlify `COMMIT_REF`/`DEPLOY_ID` metadata is compiled into the build;
no production environment variable or credential is added.

No arbitrary error message, Error object, request, query, command, receipt,
projection, stack, user/merchant identifier, contact, proof, redemption capability,
cookie, token or session is serialized. Stack parsing examines only bounded frame
lines and emits an exact allowlisted repository file/line/column. Unknown names,
confidential digests, query-bearing frames, unlisted files and unsafe identifiers
are discarded. A diagnostic sink failure cannot break business operations.

`observed_at` identifies the capture boundary, not necessarily the throwing file.
`source` is populated only when an original allowlisted frame is available.
Minified/transformed production errors can leave it null. No source maps are
published and no source location is invented. Page/read/contract/render stage
records plus the server digest still narrow the failing boundary. A streamed
RSC exception does not imply HTTP 500; unknown status stays null.

Server records go to existing function logs. Browser records stay in the current
approved diagnostic browser console; there is no client upload, storage, cookie,
logging endpoint, database table or broad telemetry transport. This channel does
not intercept or sanitize the framework/provider's separate default logs. Safe
review must filter and export only this channel, never unrestricted native logs.

## Correlation

The existing proxy overwrites the diagnostic request header with a fresh UUIDv4.
It is an opaque trace value, confers no authority, and contains no resource ID.
The merchant page, RPC read, contract validation and server error hook share it.
The existing mutation route returns its own opaque correlation header alongside
the unchanged response. Browser response receipt, refresh and next rendered read
form an in-memory parent chain. A receipt event means the HTTP response arrived;
the subsequent refresh event occurs only after the existing successful-body gate.

If rendering fails before new props arrive, the client boundary retains the last
mutation/read correlation. The Next digest joins it to the fresh server error
correlation. Time/deployment/route/stages disambiguate matching digests; a digest
alone is not a globally unique request identifier. Trace memory is cleared when
leaving merchant routes and disappears on full reload. No session extraction or
private URL propagation is needed.

## Local verification — October 8, 2026

The isolated production-built harness uses the real page, layout, MerchantPortal,
contracts, mutation route and hooks. Auth/RPC/proxy boundaries are replaced only
inside a private local copy, with no network/database/Auth connection. The input
is the reconstructed controlled canonical pending-review projection shape; it is
not a retained original RPC response. Only synthetic controlled business data is
used. The local fault injection is absent from repository/deployed source.

Native draft submission → confirmed receipt → refresh → pending-review render
passed. A second local submission deliberately threw a harmless TypeError in the
merchant page after the receipt. At **17:32:09.670 UTC**, the browser showed the
safe global recovery UI and digest **932486183**, matching the server hook.
Server correlation **745921ed-d4a4-4ca1-af70-f4b1d7dcf010** identifies the failed
page render; browser correlation **587765bd-a73c-4371-9556-36bbc26be38c** links the
confirmed mutation and refresh to the boundary. The bundled exception had no
allowlisted original source frame; `source` correctly remained null.

After removing the local-only fault, native **Try again** used `retry`, fetched a
new read, and restored pending-review rendering at **17:33:13.354 UTC**, with
correlation **01146321-fdb7-427d-a3f3-5a5d458d6eae** parented to that mutation.
Full reload passed at **17:35:31.405 UTC**. Neither local controlled exception nor
recoverable hydration reporting establishes the original hosted cause.

Nine new tests verify exact fields, sensitive sentinels, valid/source-rejected
frames, hostile getters, failing sinks, supported server hook, route isolation,
response/read parent links and safe error-boundary rendering. **26/26** focused
merchant/diagnostic tests and **589/589** complete application tests pass. Strict
typecheck, zero-warning lint and production build pass. No migration, database
permission, business contract, Auth rule or timeout changed.

## Retention, access and retrieval gate

Existing Netlify project function logs (`___netlify-server-handler`) retain server
channel records. Conservatively plan for **24 hours**, not a guaranteed seven
days: longer retention depends on plan. Lambda-compatible historical logs can
retain only the last **4 KB per invocation**, so logs may truncate; these finite
events are deliberately small. Export filtered records promptly during a future
approved window instead of relying on indefinite provider retention.
[Netlify function log retention](https://docs.netlify.com/build/functions/logs/).

The site owner and already authorized Netlify project users with function-log
access can review them. No new access is granted. Browser console capture is
ephemeral/tool-bounded: export its allowlisted rows before closing/reloading the
diagnostic session. Export only the reconstructed finite record fields to an
owner-controlled private local JSONL artifact (directory 0700, file 0600), outside
Git, retained until Main Boss Chat review and owner-directed removal. Review the
sanitized report or explicitly shared sanitized artifact; never copy entire
provider log panels, network dumps or credential-bearing metadata.

Before any future acceptance window:

1. Verify Git CD is READY for the diagnostic commit and the existing signed app
   remains usable. Perform only an ordinary read of the already archived
   controlled merchant; do not reactivate it or submit a business mutation.
2. Capture its `client_rendered` correlation from the finite browser channel.
3. In existing Netlify function logs, use the text filter for that opaque ID and
   a bounded UTC-derived historical interval. Read only prefixed channel JSON.
4. Retrieve matching page/read stages and commit/deployment identity, independently
   of the browser record. Revisit the filtered historical query and retain the
   sanitized subset privately. Record actual UTC times and retrieval outcome in
   the diagnostic completion report and PR.
5. If retrieval or export is unavailable/truncated, **STOP**. Do not start an
   acceptance window, fabricate a diagnostic or add an endpoint/vendor workaround.

The release completion report records the live retrieval result. A harmless
read establishes current channel retrieval; it cannot guarantee every future
failure survives provider truncation. During a separately authorized final window,
keep an authorized reviewer on the filtered log stream and export immediately
after each relevant stage/failure, then perform administrator-first cleanup.

## Remaining Phase 8A work

Main Boss Chat must separately authorize the final controlled acceptance window.
Record the exact restored baseline, narrow grants, fixed scenario stop/cleanup/hard
expiry, and preflighted recovery first. Revisit offer submission with this channel
enabled, preserve any failure before cleanup, and stop on a new boundary failure.
Publication, weekly-special, membership/redemption, restricted-role, sales CRM
and populated responsive scenarios retain their existing hosted-unverified labels.
No Phase 8B or Partner Network integration is part of diagnostic readiness.

## Sales coverage extension — October 8, 2026

The channel now additionally covers `/app/merchant-sales`. Sales page/read/render
and Next error hooks share the same opaque correlation architecture. Explicit
operations: `lead.create`, `lead.activity`, `lead.state`, `lead.reassign`,
`lead.convert`, `sales.grant`, `sales.end`, `sales.read`. The existing shared
mutation route still emits its constant merchant route boundary; action-specific
RPC/receipt records identify Sales through finite operation categories and share
that route correlation. No resource context is serialized.

New finite stages/classifications distinguish transport response loss, non-2xx,
HTTP-200 invalid JSON, canonical receipt rejection, confirmed response, true
rejection and a subsequent refresh/render error. Browser failure after accepted
receipt is `refresh-failed`; it does not reverse the recorded success. No raw
body/header, prospect information, command/receipt, private identifiers or arbitrary
error text is retained. Existing merchant privacy, filtering, retention and export
rules above remain unchanged. See [Sales diagnosis](PHASE_8A_SALES_DIAGNOSIS.md).

A denied replay does not resolve the original unknown commit. The client preserves
that original command/request ID, keeps new actions blocked, and emits the finite
`reconciliation_unavailable`/`unknown-result` stage until canonical replay succeeds
or the owner reviews state. No raw receipt or additional lookup endpoint is added.
