# Phase 4A validation and controlled hosted acceptance

Phase 4A is implemented and locally validated. Direct typed Phase 4A authorization
was received on October 2, 2026. All five prepared migrations were applied to the
canonical Boss project at 06:20 UTC. Final local validation passes 6,086 SQL
assertions, 24 races, strict typecheck, zero-warning lint, 164 application tests
and production build with canonical generated types. The reviewed controlled
hosted acceptance plan is complete, including immediate restoration and cleanup.
The narrow Calendar reminder copy correction is committed, pushed and published.
Both application and database CI jobs pass for the published copy fix. Hosted
reinspection confirms the corrected copy, restored administrator access and
closed communications after temporary assignment removal.

Starting branch SHA: `e9e110737609b58dd171a8e5c482102d8b86aed0`.
Branch: `build/boss-platform-v1`. PR [#3](https://github.com/eaglevisiondigital/theboss/pull/3)
is verified open, draft and unmerged. Copy-fix source checkpoint:
`5c5e34161193d6114add4a3c791094223829e654`. The final private handoff records
the subsequent documentation commit and final branch head. No later module started.

## Applied migrations

The eighteen previous migration files retain their original SHA-256 values.
These five new files bootstrap successfully on fresh disposable PostgreSQL 17:

1. `20261002062003_phase4a_communications_core.sql`: canonical channels, messages,
   audiences, read state, attachments/reports, least-privilege mappings and explicit
   false-default guardian communication flags.
2. `20261002062020_phase4a_communications_operations.sql`: finite signed operations,
   safe projections, private Storage intents/leases, reporting/moderation and search.
3. `20261002062028_phase4a_notifications_core.sql`: shared source, recipient,
   preference and channel-delivery records, templates and current source authority.
4. `20261002062035_phase4a_notifications_engine.sql`: bounded resumable audience
   processing, deduplication, existing-module source hooks, reminders and safe history.
5. `20261002062040_phase4a_communications_catalog_projection.sql`: marks the existing
   messaging catalog entry as implemented Communications without assigning access.

## Verified local checks

The full fresh database run passed **6,086 SQL assertions** and **24 coordinated
two-connection races**. This includes all earlier phases and the actual trusted
administrator bootstrap source. SQL and race counts are separate.

| Phase 4A suite | Passed assertions |
| --- | ---: |
| Communications authorization/integrity | 151 |
| Communications rollback verifier | 21 |
| Notifications/integration/preferences/retries | 87 |
| Notifications rollback verifier | 25 |
| Independent catalog/RLS/API security | 314 |
| Phase 4A SQL total | 598 |

Both new rollback verifiers completed with every residual fixture count zero.
After migration, the same 21- and 25-assertion verifiers also passed in the canonical
project and rolled back completely. The disposable cluster was removed after the
full run. Eight new races verify message request deduplication, unique monotonic
sequencing, nonregressing read watermarks, fail-closed higher-isolation writes,
notification source uniqueness, SKIP LOCKED processing and identical preference
request replay. The sixteen prior races also pass.

Separate private operator recovery and temporary Messaging assignment dry runs
pass 21 and 16 additional disposable assertions, outside the 6,086 repository
suite total. Recovery preserves selected immutable anchors and unrelated sentinels;
administrator restoration and authority cleanup use separate commits.
Cleanup-failure injection was not executed. Those disposable clusters were removed.
Actual hosted restoration and exact cleanup are recorded below.

Local PostgreSQL is 17.11 and Node is 24.20.0. The platform's final full
`npm run validate` passed strict typecheck, zero-warning lint,
**164 application tests** and the production build. It ran in a physically isolated
copy with locked dependencies, matching source and synthetic public configuration;
no production environment file was copied. Protected communication/notification
routes remain dynamic. Hosted acceptance exposed one Calendar reminder copy issue:
the regression failed with the old copy, and the corrected copy passes all 23
focused Calendar tests and the full application run. No new schema correction
was required by hosted acceptance.

Focused coverage includes cross-tenant/forged-resource denial, exact unit/team
scope, revoked guardian/team/role access, household-alone denial, unknown-age and
minor safeguards, private attachment operation gates, lost-response replay without
reissuing upload access, disabled-moderation denial and exact authorized Calendar
occurrence selection. A two-child parent receives one notification with both team
contexts. New backdated grants cannot receive older queued sources. The retry
fixture advances finite bounded pages before asserting an attempted fault;
production queue limits are unchanged.

Historical catalog checks exclude the ten independently tested new permissions
while retaining their original exact expected sets. The independent Phase 4A suite
verifies the evolved totals: 21 roles, 44 permissions, 306 mappings and 63 public
tables. New Boss-facing communications copy contains no em dashes.

## Canonical and release checkpoint

Canonical target: `the-boss-platform`, ref `ilykgwgmxtrrikreacrz`.
Dedicated platform: <https://thebossplatform.netlify.app>.

The canonical history contains all 23 expected migrations in order. The five
Phase 4A files retain their locally validated SQL bytes and match canonical
versions. TypeScript database types were regenerated from this schema.
Fresh advisors found 45 informational closed-table RLS notices, one existing
leaked-password-protection Auth warning, 93 informational unused indexes and one
existing Auth absolute-connection informational notice. Closed raw tables are
deliberate; no Auth configuration was changed.

Initial production deployment `6abf4e2daf06dd0008738bc4` was published at
06:25:14 UTC on the dedicated platform from implementation commit `3ae01d8`.
It supported the controlled hosted acceptance below. The Calendar copy correction
was subsequently pushed in `5c5e34161193d6114add4a3c791094223829e654` and published
in ready production deployment `6abf5e71e1d34800080c7459` at 07:34:37 UTC.

CI initially passed every SQL suite but failed because the minimal PostgreSQL
image has no `rg`. One race-script check now uses portable `grep -Fq`; its
assertions are unchanged. All eight Phase 4A races passed again under a
system-only PATH with `rg` absent. Both GitHub runs for fix commit `bf1e729` passed
their database and application jobs:
[36973793675](https://github.com/eaglevisiondigital/theboss/actions/runs/36973793675)
and [36973790415](https://github.com/eaglevisiondigital/theboss/actions/runs/36973790415).
Those runs verify the portable-script checkpoint. Both database and application
jobs also pass for the published Calendar copy correction:
[36979250988](https://github.com/eaglevisiondigital/theboss/actions/runs/36979250988)
and [36979246519](https://github.com/eaglevisiondigital/theboss/actions/runs/36979246519).

## Completed controlled hosted acceptance

Direct human approval resolved the missing controlled Messaging assignment by
authorizing exactly one temporary assignment of the existing catalog entry.
The reviewed parent, exact-team coach and separate family receipt windows used
only existing controlled identities and relationships. The fixed window began
at 06:58:30 UTC on October 2, 2026, with a maximum deadline of 07:58:30 UTC;
that deadline was never extended. No new Auth identity or broader role was added.

| Hosted check | Observed result |
| --- | --- |
| Parent and coach communications | Restricted parent viewed and sent in the authorized team conversation; exact-team coach access succeeded. |
| Private team announcement receipt | A distinct synthetic staff-authored announcement appeared in the authorized parent inbox. |
| Organization announcement replay | Administrator submission succeeded; parent and coach replay POSTs were denied; restored administrator replay returned the same single thread/message. |
| Read state | Mark conversation read persisted after reload; Mark all read changed four unread notifications to zero and reload retained zero. |
| Drawer accessibility | Enter moved focus to the heading; Shift+Tab remained inside; Escape closed the drawer and restored trigger focus. |
| Pins and moderation | Coach Pin and restored administrator Unpin succeeded; parent Report and administrator Dismiss succeeded without removing the source message. |
| Preferences and history | One scoped disabled-email preference saved and replayed without duplication; scoped history displayed eight safe channel rows; queue processing returned Saved. |
| Calendar deduplication | One material reschedule produced one parent notification with two qualifying team contexts and exactly one sent in-app/one suppressed email row; reprocessing added no duplicate. |
| Communication deduplication | Each distinct staff source produced one authorized parent notification; the signed actor's own message produced zero self notifications. |
| Family receipts | Signed registration submission, approval and synthetic $1 USD cash recording produced authorized family receipts; the paid balance removed outstanding-fee access. |
| Household-only denial | Removing guardian capabilities while household membership remained current closed source access and denied stale signed POSTs. |
| Mobile | At 390 and 320 pixels, document scroll width equaled viewport width; the 320-pixel authorized attachment interaction reached download initiation. |

The separate family receipt window enabled only `can_register` and
`can_manage_payments`, with the exact existing household and child organization
relationships. Its other five guardian capabilities stayed false. Communications
used the two explicit receive/send flags. Household membership and legacy family
flags never substituted for communication authority.

Distinct staff-authored source creation was a reviewed synthetic operator fixture
action. It establishes authorized recipient behavior, not a separate staff Auth
login. Hosted direct messaging remained disabled. All records and document bytes
used for acceptance were synthetic; the cash receipt records no real transfer.

## Attachment result and evidence limits

The authorized private attachment was a 1,771-byte synthetic file. The hosted UI
reported Private download started only after an OK response, completed Blob read,
bounded size check and local download-anchor activation. The server additionally
checks current caller/attachment authority, the private bucket/path, successful
Storage retrieval, MIME, nonempty bounded size and recognized file signature.
After guardian authority was removed, a stale hosted POST was denied within two
minutes of the last authorized access and the attachment became unavailable.

The in-app browser exposed no saved file or download handle within the observed
window. Saved-file completion and downloaded byte/hash equality were therefore
not independently verified. The server does not compare the retrieved body hash
to the canonical stored hash. This evidence limit does not establish a download
failure and is not represented as a saved-file hash PASS.

Hosted search, an independent second-team conversation positive, an independently
authenticated minor session and an additional raw forged hosted POST matrix were
not performed. Applicable server policy is covered by local SQL/application tests;
those checks are not relabeled as hosted observations. Observed hosted denials
include restricted announcement replay and revoked guardian/household-only actions.

## Immediate restoration and retained evidence

The original administrator was restored independently in all six controlled
windows. All selected temporary authority ended at **07:29:01 UTC**, before the
unchanged one-hour deadline. Final exact residual checks show:

- Zero current selected temporary roles, guardian authority or any of the seven
  capability flags, household/child organization authority, upload intents or
  download leases; the temporary Messaging assignment is inactive and ended.
- Zero controlled preferences after one exact audited deletion restored the absent
  baseline; zero pending controlled sources, expansion jobs or deliveries.
- Zero external email sent/delivered rows. Historical source, receipt and audit
  records remain retained with current visibility governed by current authority.
- Six created threads retained archived at version 2 and the synthetic Calendar
  event retained archived at version 3.
- The synthetic registration and offering retained archived; one $1 cash payment
  and its single allocation retained with paid balance zero. No new roster added.

The temporary assignment used the existing module catalog and retained its reviewed
creation configuration. Cleanup preserves immutable synthetic history. Controlled
activation, fixture actions, signed operations, preference removal and restoration
have audit evidence; the final safe metadata count is 64 audit entries. Actual
fixture identifiers, operator SQL, personal data and screenshots remain private
outside this repository.

## Operational limits and scope stop

Email has no approved live provider/sender. Templates and an injected adapter are
implemented and tested; hosted email work remains `suppressed/not_configured`,
with zero external sends. Provider provisioning, durable external worker identity,
webhook verification and operational scheduling require separate approved activation.
SMS/push are future channels. All integrated alert categories are optional; the
server-owned mandatory-policy foundation does not invent a mandatory business rule.

Audience jobs are bounded and resumable. Reminder preparation is bounded to the
documented window/source limits and operator-driven. Historical mutable capability
values are not fully reconstructed; creation/start windows and current source
authority apply. Retention/purging, live provider choice and production minor policy
remain explicit product/operational decisions. Private attachments have type/magic,
size and authority checks; no antivirus or legal-consent claim is made.

No actual password, credential, token or session value was requested, read,
printed or added to source/evidence. Existing signed browser requests were used
without inspecting authentication material. No real youth/customer document data
was used. No temporary controlled family or communications authority remains active.
Reviewed hosted acceptance is complete. The published Calendar copy correction
passes CI and hosted reinspection. The final handoff supplies the documentation
SHA and PR update evidence. No Phase 4B or other next phase has been started.
