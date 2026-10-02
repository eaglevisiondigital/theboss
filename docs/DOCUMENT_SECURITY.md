# Private document security: Phase 3B

This is an implementation/security contract. Live advisor, hosted and deployment
results belong in [CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md). It does not
certify malware removal, legal compliance or an operational retention program.

## Requirement and lifecycle

Immutable `document_requirements` versions define title/key, standard/identity/
medical classification, required status, allowed PDF/JPEG/PNG types, maximum bytes,
optional validity period and explicit medical emergency eligibility. A new version
changes future offering attachments; existing registrations preserve their original
requirement snapshot. Emergency eligibility is allowed only for medical documents.

Each `registration_documents` row belongs to an actual tenant, registration and
participant. It retains requirement snapshot, upload/review provenance, optimistic
version, expiration and renewal dates. States are missing, upload pending,
submitted, under review, approved, rejected, expired and waived. Review requires
`documents.review`, an authorized offering scope and explicit reason; reviewer and
database review time are canonical. Expired approvals project as expired. Renewal
uses a new random object path and a fresh intent, never overwrites a prior object.
Metadata transitions are retained in private version history and safe audit events.
Reminder delivery and object-retention cleanup are future work.

## Private Storage and upload

`boss-registration-documents` is private, has a 10 MiB ceiling and permits only
configured PDF/JPEG/PNG metadata. Hosted binary uploads enforce a stricter 5 MiB
actual-stream limit and basic format signatures. Requirement limits can be lower.
Neither client Content-Length nor declared MIME alone is accepted as validation.

The authenticated server requests a 15-minute `document.intent`. PostgreSQL
requires actual self/verified guardian `can_register` and `can_view_documents`,
current participant, active Registration/document features and a live owned Auth
session. The intent binds actor, Auth session, exact document, MIME, byte size,
optional prepared digest and an immutable generated object name:
`organization/registration/document/intent.ext`. A new intent invalidates unused
older intents for that document.

Storage INSERT RLS permits only the server-established `object.upload` operation.
It rechecks the current session/actor/guardian/features, unused unexpired intent,
document upload-pending state, exact current object name and MIME/size metadata.
Storage's permission preflight temporarily inserts MIME plus `contentLength` and
rolls that transaction back; persisted backend metadata contains MIME plus `size`.
Both representations must exactly match the intent. If both size fields are
present, both must match; malformed, missing or conflicting sizes are denied.
Completion independently verifies the persisted object's actual backend `size`
and MIME, consumes the intent and marks the document submitted in a transaction
with audit and receipt. Preflight metadata alone cannot complete a document.
See the [Supabase upload implementation](https://github.com/supabase/storage/blob/master/src/storage/uploader.ts).

A separate intent-bound SELECT branch supports upload permission checks that use
INSERT RETURNING. It applies only during `object.upload`, grants no byte retrieval
and creates no read lease. Existing names, upsert, UPDATE and DELETE remain closed.
The application uploads raw binary bytes with the authenticated user client rather
than a service credential. Multipart boundary overhead cannot substitute for the
exact intended file size.

The hosted server computes a digest of received bytes to bind idempotent content.
Changed bytes with the same request IDs cannot silently replay the earlier intent.
The digest is prepared provenance, not an independent hash of Storage content and
not antivirus evidence. Basic magic checks can reject misleading types but cannot
prove a PDF/image safe. An authorized direct Storage client remains constrained by
RLS/MIME/size metadata, without independently executing the hosted byte decoder.
No scanning/content-disarm pipeline is implemented. Manual review and restricted
retrieval remain the Phase 3B boundary; broader operational scanning policy needs
separate approved work.

## Audited ordinary access

Raw metadata tables and object paths have no ordinary client table grants. An
authorized guardian with `can_view_documents` or scoped `documents.view` requests
`document.access` with purpose ordinary. Every request reauthorizes and audits,
then creates a two-minute private actor/Auth-session lease. Storage SELECT permits
that lease only during `object.get_authenticated`, the authenticated download GET.
It checks the lease and current authority again for every byte request. Role inactivation,
expiration, guardian capability removal, module/feature closure or relationship
expiry therefore closes an existing lease immediately.

Operation checks compare exact trusted Storage route names, normalizing only the
optional `storage.` prefix; empty, unset or partial operations are denied. Signed
upload URLs, signed download URLs, listing, info/HEAD, copying, moving and image
rendering are denied even while an intent or lease is valid. Storage's signed
routes mint bearer capabilities and later operate as an internal superuser, which
would bypass the current-authority lease requirement. The platform supports no
such flow. See [Storage operation helpers](https://supabase.com/docs/guides/storage/schema/helper-functions),
[signed download delivery](https://github.com/supabase/storage/blob/master/src/http/routes/object/getSignedObject.ts)
and [signed upload delivery](https://github.com/supabase/storage/blob/master/src/http/routes/object/uploadSignedObject.ts).

The hosted download route obtains the audited lease, validates the exact echoed
resource/path/type and downloads with that user's client. It returns a private
binary attachment with safe filename, no-sniff and existing no-store/CDN isolation.
The UI receives no public file URL or reusable signed URL. Sensitive access does
not save a second copy of file/medical contents in an idempotency receipt. Audit
payloads contain actor/action/resource/purpose/team/time and safe metadata rather
than the document body, medical answer, credential or session token.

## Exact-team emergency access

Emergency access needs Registration/documents/emergency features, an active exact
team `documents.emergency_view` assignment, actual active coach/staff membership
and the participant's active membership in that same active team. Organization-wide
authority, sibling teams, inactive memberships, ordinary roster visibility and
knowing resource IDs do not satisfy that emergency path. The lease records the
exact team, and Storage rechecks it on every authenticated download GET.

Emergency documents must additionally be classified medical, explicitly marked
emergency eligible in the frozen requirement and approved/unexpired. Identity or
birth-certificate documents are never exposed through emergency access. Audited
`emergency.access` returns necessary contact/medical/physician fields; insurance
is excluded from the emergency projection. Ordinary authorized document reviewers
or actual family document authority may use the separately audited ordinary path.
Coaches do not acquire ordinary medical answers, all documents or finance powers.

## Boundaries and future operations

Storage privacy cannot revoke bytes a permitted reader has already downloaded.
Database owners and deployed server code remain trusted operational boundaries.
Expired intent/object cleanup, retention/deletion, scanning, notification delivery,
recovery/incident runbooks and legal consent policy require separate work. No Auth
security setting is weakened to make uploads or review easier.

See [Permissions](PERMISSIONS_MODEL.md), [Registration](REGISTRATION_ARCHITECTURE.md)
and [Forms/waivers](FORMS_WAIVERS_ARCHITECTURE.md).
