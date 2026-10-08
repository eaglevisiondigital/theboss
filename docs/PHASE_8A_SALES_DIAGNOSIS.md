# Phase 8A Sales CRM confirmation diagnosis

## Sales confirmation diagnosis and narrow repair — October 8, 2026

Phase 8A remains **INCOMPLETE**. Starting SHA:
`8e82ed4a46744eee880d476ab19d799ca897570d`.

Read-only canonical evidence identifies the original lead receipt at
**19:06:35.538206 UTC**: exactly one receipt, with fields `action` (string),
`lead_id` (string), `merchant_id` (null), `version` (number), `replayed` (boolean).
No private receipt values, command digest, prospect/person data or Auth material
were retrieved for this comparison. The canonical Sales operation deliberately
returns a null merchant ID until conversion. The existing application validator
required all receipt IDs to be UUIDs and rejected this legitimate result after
RPC commit, returning HTTP 503 and the observed unconfirmed-change notice.

This application contract defect is **PROVEN**, including reproduction through
both the mutation function and the original real Next/React client/server path.
The original hosted HTTP trace remains unavailable, so additional transport
factors cannot be ruled out. The earlier offer-refresh root cause remains UNKNOWN;
its subsequently successful hosted acceptance is preserved without inventing a cause.

The correction permits null `merchant_id` only for `lead.create`, `lead.state`
and `lead.reassign`; conversion requires a UUID. All Sales receipts require their
exact canonical field sets. Unknown/private fields and malformed IDs remain denied.
No database operation, migration, business rule, RLS/Auth policy or timeout changed.

The existing finite diagnostics now cover `/app/merchant-sales`, its server read,
client render, supported Next server/error-boundary hooks and explicit lead/Sales
operations. Safe stages separate no HTTP, non-2xx, invalid JSON, invalid receipt,
accepted response, true pre-commit rejection and subsequent refresh/render failure.
Only allowlisted constant route/file/operation/classification, UTC/build identifiers,
opaque correlation, safe source/digest and known status are emitted. No payload,
response body, prospect/contact/person/merchant identifier or credential is logged.

The client distinguishes confirmed success, confirmed rejection and unknown result.
Unknown confirmation retains the exact validated command and request ID in memory;
new mutations are blocked until same-request retry resolves it. Retry uses the
existing signed mutation endpoint, canonical digest binding and current-authority
recheck. No receipt lookup endpoint or privileged recovery path was added. A page
reload clears ephemeral client memory; review canonical state before submitting a
new operation after reload. No automatic new-ID resubmission is performed.

Production-built local integration uses real Sales page/layout/components, route,
validation and refresh/reload behavior with canonical-shaped synthetic RPC only.
Fault injection and synthetic retry controls are confined to the private harness,
absent from repository/deployed source. Before: one commit, HTTP 503, unconfirmed
notice. After: accepted receipt, refreshed lead and one lead after reload. Loss,
server receipt rejection, HTTP-200 invalid JSON and invalid client receipt each
remain unknown and reconcile via identical replay without another lead. Denial
and conflict create zero leads. Changed input with the original request ID returns
409 through the real Next route. A confirmed response followed by a synthetic
render error records `refresh-failed`, with matching server/client digest. The
mutation/server-RPC/refreshed-read correlation chain matches.

Validation: **36/36 focused tests**, **599/599 application tests**, strict typecheck,
zero-warning lint and production build PASS. Ten added regression tests cover
Sales contracts/outcomes/replay and diagnostic privacy/route/error correlation.
Executable SQL is unchanged; no SQL suite rerun is required by this repair.
Existing SQL/runtime authorization/concurrency evidence remains authoritative.

Read-only live verification: **113 migrations**, original administrator valid,
zero effective operational/staff/Sales temporary authority, zero active controlled
merchant/location/market/lead/trial/campaign/product/capability or pending work.
All **30** original selected business hash/count baselines and the achievement
hash match. Original Phase 7E source/membership history, Phase 7D payments and
allocations, Wallet and sports remain unchanged. No production business-state
mutation or acceptance window occurred during this task.

The validated correction is released through existing Git CD; final SHA, CI,
READY deployment and read-only diagnostic retrieval are recorded in the release
handoff and PR #3. PR remains OPEN/DRAFT/UNMERGED. No Phase 8B or later module.

Remaining hosted evidence: corrected Sales success/replay and CRM activity,
pipeline/conversion have not been re-executed in production. Restricted editor/clerk,
wrong-location/forged requests, independent second-identity rules and remaining
responsive/accessibility evidence retain their prior honest classifications.
Previously passed offer/listing/trial/redemption scenarios are not reopened.

Recommended next decision: Main Boss Chat may separately authorize a narrowly
bounded Sales-only acceptance window with read-only baseline/diagnostic gates,
one native lead create, same-request retry only if unknown, refresh/reload,
feasible CRM follow-ons and administrator-first explicit cleanup. Restore/check
zero authority/work and all selected baselines before closure review. Do not
fabricate a second identity or infer hosted PASS from local tests. No new window
is authorized or opened by this diagnostic repair.
