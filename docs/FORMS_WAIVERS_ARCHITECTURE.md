# Forms, waivers and signed evidence: Phase 3B

Published definitions and completed evidence are canonical Boss records, separate
from mutable registration workflow state. Runtime/deployment evidence belongs in
[CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).

## Bounded form language

A form is `{fields:[...]}` with 1–100 ordered fields and a bounded 64,000-byte
definition. Stable field keys, labels and optional section/help/content define its
presentation. Supported types are short/long text, email, phone, number, date,
dropdown, radio, checkbox, multi-select, yes/no, address, private file reference,
acknowledgment, signature/consent, emergency-contact reference and content.
Selections use 1–50 unique configured choices; text and numeric constraints are
finite. Rendering uses text/content rather than executable HTML or scripts.

Conditional `show_if` and `required_if` arrays contain 1–5 conjunctive predicates.
Each predicate uses the finite `source`, optional `field`, `op` and primitive
`value` vocabulary. Sources are an earlier answer, canonical participant age or
bounded registration context (`grade`, `payment_plan_selected`,
`travel_team_selected`). Operators are `equals`, `not_equals`, `includes`, `lt`
and `gte`, with type checks. Answer references point backward only. Arbitrary
expressions, forward cycles, SQL, JavaScript and caller-defined authority are
rejected.

PostgreSQL evaluates definitions and answers; client validation supports useful
editing and errors but cannot establish completion. Unknown answer fields, invalid
types, disallowed selections and forged private document references fail. Drafts
permit missing required values but validate supplied values. Finalization applies
visibility/conditional-required rules and freezes the response. Submission
reevaluates every required final response against its frozen definition and current
registration context.

`file_upload` answers reference actual submitted/reviewed documents belonging to
that registration, rather than arbitrary URLs. Emergency references select the
canonical restricted record rather than copying medical data into a public form.
Signature fields require actual current signing authority at finalization, even
when a guardian can save ordinary draft answers.

## Versioning and sensitivity

`registration_form_versions` stores immutable organization/form-key versions.
Publishing a later version replaces the future offering attachment while preserving
old versions, registration snapshots and answers. Draft answers have their own
optimistic version. Final submitted answers reject update/delete, including a
later request with a different request ID. Existing finalized evidence is not
silently rewritten to match new definitions.

A form is classified ordinary or medical. Family medical entry requires document
authority as well as registration authority. Ordinary read projections suppress
medical answers for everyone. `form.access` rechecks verified guardian document
authority or scoped `documents.view`, then audits the current retrieval and returns
only the authorized version/answers/completion evidence. Coach registration-summary
permission and finance permission cannot reveal those answers. The sensitive
response is excluded from retry receipts and application error logs.

The same audited path can return an empty not-started definition to an authorized
family before its first medical response. That read creates no answer row and
supplies no invented answer version. Staff document authority can review the
definition but cannot gain family editing or signing authority from the response.

## Waiver and signature evidence

`registration_waiver_versions` stores immutable organization/key version, title,
consent text, canonical publisher/time, signer type and effective interval. The
body permits up to 60,000 characters subject to the overall mutation byte bound.
Future publication affects future offering requirements; registrations retain the
original waiver version and consent text.

`waiver.sign` requires `consent:true`, an actual typed signer name and current
`can_sign_waivers` or actual self authority, plus the version's signer policy.
A guardian-only waiver rejects self signing; participant-only rejects another
person signing. A role, household label or forged participant ID cannot substitute
for the actual signer relationship. The immutable signature records registration,
participant, waiver version, canonical signer, name, database timestamp, consent,
full signed version snapshot and authenticated provenance. It records no asserted
verified client IP. Repeated identical requests return existing evidence only
after current authorization; a later definition cannot alter an old signature.

Stored evidence supports later document rendering and reviewed legal workflows.
Phase 3B does not create signed PDFs, biometric signatures, notarization, legal
enforceability guarantees or a new age/guardian-consent regime. Retention,
correction/reconsent and jurisdictional requirements require separately approved
direction. Sensitive evidence is excluded from safe audit field/status metadata.

See [Registration](REGISTRATION_ARCHITECTURE.md),
[Document security](DOCUMENT_SECURITY.md) and [Permissions](PERMISSIONS_MODEL.md).
