# Athlete Profile and Recruiting Showcase architecture

## Phase 6C contract

Phase 6C adds one longitudinal presentation profile per existing participant. The
profile references the canonical participant/person pair and never creates a second
athlete identity. Team, organization, season, game, sealed-statistic, aggregate,
leaderboard and record origins remain authoritative in their existing modules.

The profile is private by default. Authenticated self, a current verified guardian,
and narrowly scoped current-team or organization staff can receive different
server-built projections. Possession of a profile, participant, team, revision or
showcase identifier grants no access. Household membership alone grants nothing.

## Provenance and revisions

Editable presentation values live in immutable profile revisions. Every revision
labels fields as athlete/guardian entered; it does not copy or upgrade verified
statistics. Organization field verifications and measurements are separate,
append-oriented records with actor, scope, source and verification level.
Measurements keep dated history and explicit units. Achievements retain issuer,
date/season, source and verification level.

Verified statistical highlights are selected references over current Phase 6A
materializations. Record and leaderboard achievements reference Phase 6B definitions
and current generation. Reads return nothing stale as current: pending source,
ranking or record generations yield an explicit pending/unavailable state. Phase 6C
contains no sport formula or correction engine.

## Visibility and consent

Profile states are finite: private, athlete/guardian, current-team staff and
organization staff. Recruiting publication is a separate showcase state and never
makes a profile searchable. Initial public discoverability is disabled.

A minor showcase requires a current verified guardian relationship with
`can_manage_profile`. Consent is versioned, field/category scoped and revocable.
Registration waivers and photo releases are not recruiting consent. An authenticated
athlete may edit permitted profile fields only when an existing age/policy contract
authorizes it; Phase 6C does not infer authority from an Auth account. Because no
approved self-publication age policy exists, initial showcase publication is
guardian-controlled for dependents and self-controlled only for the canonical adult
subject where existing identity policy proves that relationship.

## Showcase and share links

A showcase revision freezes presentation text, selected safe fields, media
references and verified-source selectors. Publication points to one approved
revision plus one active consent. Current verified facts are projected from their
authoritative current generations; an earlier showcase revision remains immutable.

Share links use 256-bit random tokens. PostgreSQL stores only a SHA-256 digest.
Links are individually revocable and optionally expiring. The unlisted page receives
only the approved showcase projection. It receives no family, roster, document,
contact, correction, internal navigation or administration capability. Revocation
is checked on every server read; responses are `no-store`, `private` where
appropriate and `noindex, nofollow, noarchive`. There is no public listing or
search endpoint.

## Youth and transfer privacy

Public/share projections exclude DOB, street address, guardian identity/contact,
household, attendance, medical, document, school-record and internal-note fields.
Class year or city/state is emitted only when explicitly present in the consented
revision; age is never derived from DOB.

A transferred athlete keeps one profile and canonical person/participant identity.
Historical facts keep the original team and organization. New-team staff receive
only current-team presentation fields and separately approved showcase facts.
Current membership creates no access to private prior-team corrections, staff notes,
rosters, communications or athlete comparison data.

## Media and contact boundary

Phase 6C accepts only bounded HTTPS highlight references with explicit approval
metadata. It does not implement unrestricted uploads or public media hosting.
Profile-image metadata records source and recruiting-publication consent; an
organization image is not automatically reusable.

Recruiter/contact interest is documented as a future transactional inbox: a bounded
request would identify the showcase and requester, retain message/rate-limit state,
and notify the athlete/guardian without exposing private contact information.
No recruiter CRM, verification claim, unrestricted account, messaging network or
public contact detail is implemented here.

## Authorization and operations

Six potential capabilities are added:

- `athlete_profiles.view`
- `athlete_profiles.manage`
- `athlete_profiles.verify`
- `recruiting_showcases.view`
- `recruiting_showcases.manage`
- `recruiting_showcases.publish`

Role mapping supplies only potential capability. Every staff operation additionally
requires current exact organization/team relationship and resource context.
Guardian/self authority is relationship-bound and action-specific. Public share
reads use only a valid token digest and approved active showcase revision.

Raw Phase 6C tables have RLS enabled and no direct client access. Authenticated
reads and writes use caller-bound transactional RPCs with bounded input,
idempotency receipts, current-session checks, optimistic versions and repeated
authorization after lock waits. Audit events record creation, edit, verification,
achievement, consent, publication, revision and share-link lifecycle changes without
copying private source values.

## Performance and scope

Profile reads are bounded to finite current projections and pages of measurement,
achievement and origin history. They do not replay raw game events, load complete
record history or make one request per season. Public projection has a single
digest lookup followed by bounded joins over indexed current materializations.

Phase 6C includes Family Hub and athlete-centered profile surfaces, consented
showcase, external highlight references and share-link lifecycle. Public athlete
directory/search, recruiter marketplace/CRM, direct private contact, full media
hosting, badges/gamification, NIL, payments, commerce and later modules are excluded.

## Phase 6E badge and recognition integration

Canonical athlete honors remain Phase 6C rows. New source-aware cards distinguish
current, historical, corrected, revoked, processing and unavailable state, verification
level, category, sport and date in text. Existing verified guardians may select eligible
showcase display separately from earning. The frozen showcase categories, current
consent and active share link remain required. Correction/freshness changes refresh
approved presentation without deleting history. Private peer rankings and award
decision notes are excluded. Current-team staff gain no prior-team origin authority.
