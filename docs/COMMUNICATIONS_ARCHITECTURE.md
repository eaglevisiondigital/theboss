# Communications core

Phase 4A uses the existing Messaging module with the Communications label. One
canonical thread/message model handles scoped staff channels, exact-team chat,
bounded direct/group/family conversation and announcements. Organization-owned
threads have immutable tenant and context anchors. Multi-team announcements use
one thread/message plus separately validated audience rows; they never merge
private team membership. A public label is retained for future publication, but
this phase supplies no anonymous announcement feed or public attachment URL.

Current relationships and exact permission scope determine access on every read,
send, retry and file operation. An organization administrator cannot read a private
direct/group/family conversation without current explicit membership. Scoped
staff can manage authorized team channels; team role assignments additionally need
current actual coach/staff membership. Exact units reach their directly attached
teams, with no descendant inheritance. Parents cannot broadcast announcements
merely through parent/team/household relationships. Finance receives no chat keys.
Direct/group creation and sending require a mapped permission in that exact
context, explicit guardian send authority for a current dependent, or approved
self-participant policy. Ordinary organization membership supplies recipient
context without creating sender authority. Assistant/team staff sending remains
behind the disabled-by-default staff-send feature even in an invited group.

Eight closed RLS tables hold threads, explicit group members, announcement
contexts, messages, private revisions, canonical-person read watermarks,
attachments and moderation reports. Client roles have no raw table read/write
access. Public invoker RPCs delegate to finite caller-bound private read/mutation
functions; arbitrary-person helpers used by notification workers remain private.
No service credential is required by the app. The signed managed session and
canonical active identity are resolved before every protected operation.

The read surface returns names-only discovery within authorized current scopes,
recent threads, at most 50 messages per page, scoped search, safe attachment
metadata, permitted operations and efficient unread aggregates. Read state belongs
to the canonical person, is recorded in PostgreSQL and advances monotonically.
Self-authored and removed messages are excluded from unread counts. Reading a
message advances that conversation's watermark through that message. The client
cannot mark future messages read. New messages receive a per-thread serialized
sequence, preventing collisions during concurrent writes.

Messages contain bounded plain text, rendered with escaped UI output. Sender edits
and removals have a default 15-minute window, configurable from zero to 60 minutes.
Edits preserve private revision evidence. Moderator removal suppresses the ordinary
body, pins and attachments while retaining canonical history. Reports and finite
moderation status changes are auditable. Audit records omit private message bodies,
report detail, attachment paths and credential/session values. Idempotent receipts
retain request hashes and safe operation/resource metadata, not another message
body copy. An identical retry rechecks current authority before returning a result.

Attachments use the private `boss-communication-attachments` bucket. PDF, JPEG and
PNG are bounded to 5 MiB, with matching MIME/size intent metadata. The app additionally
checks streamed bytes and basic file signatures; this does not certify malware
absence. Upload intents are actor/session bound and expire after 15 minutes.
Authenticated exact Storage upload permits INSERT RETURNING only for that intent.
Completion checks persisted object metadata. Existing announcement attachment
completion binds the first visible announcement message; it does not create chat.
Chat/group files remain ready until an authorized message links them. A file cannot
be reused across tenants, threads or authors. Every download creates an audited,
session-bound two-minute lease and rechecks current channel/message authority.
If the final completion response is lost, a matching actor/session retry returns
the same ready/attached record under current authority. Consumed upload intents
stay closed; recovery creates no additional upload or download permission.
Only authenticated byte GET and its managed authenticated-info preflight are allowed.
Signing, listing, copying, public reads, overwriting and operation-less SQL reads are
closed. Removing membership or authority invalidates an existing lease immediately.

Active-module defaults enable communications, announcements, in-app notification
projection and guardian visibility. Team chat, direct/group messaging, participant
messaging, minor groups, attachments, staff sending, moderation and email notification
availability default off. Module lifecycle and individual feature flags close their
server paths and UI operations. Numeric policy settings are validated independently.
No SMS, push, live email provider secret or later business module is implemented by
these communications records. See [minor safeguards](MINOR_COMMUNICATION_SAFETY.md)
and the separate notification/email architecture for delivery behavior.

SQL acceptance uses synthetic rollback fixtures and actual client database roles.
Coordinated disposable two-connection tests cover duplicate request serialization,
unique message ordering, monotonic read state and safe higher-isolation conflicts.
Runtime/live/deployment evidence and assertion counts are recorded separately in
CURRENT_BUILD_STATE.md; migration files alone do not establish successful deployment.
