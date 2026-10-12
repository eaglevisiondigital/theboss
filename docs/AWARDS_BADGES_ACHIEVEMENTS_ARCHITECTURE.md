# Awards, badges and verified achievements

Manual award recognition preserves the explicitly approved achievement date;
automatic source effective-date and historical-evaluation policy does not suppress
a human decision about an earlier same-day accomplishment. Approval must create
or update its canonical honor atomically. If the recipient closes before initial
approval, the transaction conflicts and retains the nominated decision baseline.

Phase 6E extends `athlete_achievements`, the canonical Phase 6C athlete honor
store. Team and organization honors use `entity_achievements`; they never create
athlete identities or automatically award every current roster member. Shared
recognition state is a rebuildable projection over these canonical rows and their
immutable definition revisions, sources and human decisions. A badge is text,
category, date, verification level and a finite internal icon/tier, never truth
stored only in artwork.

## Sources and definitions

Finite rules consume current Phase 6A summaries/sealed contribution selectors,
Phase 6B qualified ranking candidates and record chronology, or Phase 6D official
placements. No sport formula, arbitrary SQL, uploaded SVG or copied display text
can qualify a recognition. No milestone threshold or universal tier is seeded.
Definitions are explicitly enabled, versioned and scoped. Boss-owned semantics
require platform capability; an organization can manage only its own definitions.
Statistical career recognition is scoped to the source organization and configured
team, with its scope labeled, rather than inferring cross-organization access.

Each source is identified by ID, generation, source manifest, originating
organization/team, sport and season. Milestones are unique by subject, immutable
definition revision and context. One evaluation can satisfy several separately
approved thresholds. Count milestones require complete metric coverage; rate
recognition uses the existing ranking qualification contract. Unknown data never
becomes zero or qualified. Record chronology keeps former holders and legitimate
co-holders; corrections change current state without deleting recognition.

Standings recognition requires an explicit authorized competition-close decision
over a current generation with one resolved first-place entry and no outstanding
counting result. Merely being first in an unfinished table does not mean champion.
Tournament athlete recognition additionally requires sealed, confirmed tournament
participation in the awarded team. Joining a roster later is insufficient.

## Decisions, corrections and work

Human-selected awards are labeled organization verified, distinct from Boss
source-derived facts. Nomination, approval, withdrawal, rejection, revocation and
restoration decisions are immutable. Definition policy determines whether approval
is required; no coach role implicitly approves. Private decision notes remain in
the issuing scope and never reach showcase or notification payloads. An award
cannot revoke a system fact; source corrections control automatic recognition.

Bounded evaluation/rebuild uses the same source adapter and uniqueness constraints.
Source changes dirty existing work; processing and unavailable state are explicit.
Profile rendering reads materialized facts and bounded recognition pages, never
replays play-by-play. Historical evaluation is optional and explicitly versioned.
Immutable decisions and recognition history are retained through rebuild.

## Privacy and presentation

Earning is separate from displaying. New recognition defaults to no showcase
display. Only current verified guardian profile authority can choose eligible display;
the existing versioned recruiting consent and active share-link boundary still
govern publication. Restricted record/leaderboard recognition is excluded from
showcase. A transferred athlete retains historical facts, but new-team staff can
view only recognition with an authorized current source-team context. No private
prior-team note, correction discussion or peer ranking crosses that boundary.

Family Hub and athlete profile views use the same subject authorization. Household
membership alone grants nothing. Team/organization management reuses exact live
roles and memberships. New raw tables have closed RLS/ACLs; only bounded,
caller-bound operations and safe projections are exposed. ID knowledge grants no
authority. Notifications reuse Phase 4A with live source authorization and deduped
delivery; there is no separate award messaging system.

No public youth directory, social feed, badge search, voting, points economy,
marketplace or later module is included. Existing sanitized incident history stays
intact. Hosted acceptance uses one fixed window with recorded baseline, rehearsed
recovery, administrator-first cleanup and explicit zero-residual verification.

## Freshness and history maintenance

Source selector generations are checked even while a materialized summary still has
its old current flag. A pending canonical source returns processing/unavailable. Count
milestone dates are computed from bounded ordered canonical contributions at threshold
crossing; profile rendering never replays raw plays. Refresh/rebuild may explicitly
name an older definition revision, preserving its original threshold and updating its
current derived state. Management exposes pending historical revision work. Distinct
source scopes and source games are authorized once per work request, avoiding repeated
permission checks for every athlete while keeping every origin game restricted.

The old ad hoc Phase 6C issuance command is closed. Historical rows remain immutable
and valid; new human honors require the enabled definition/decision workflow. The
exact-origin helper uses an explicit parameter reference to avoid SQL column ambiguity.

Phase 6E adds no public youth directory/feed, points economy, payment/marketplace,
provider activation or later module. Prior sanitized security disclosures remain intact.

## Explicit history-navigation presentation capability

`AchievementBadges` accepts `allowHistoryLink`, defaulting to `false`. Canonical
`id`, `achievement_id` and `source_type` remain legitimate projection fields;
their presence does not enable private navigation. Authenticated achievement,
profile and Family Hub compositions explicitly opt in; the public recruiting
composition never opts in. This is presentation only, not an authorization grant.
The private history operation still independently requires authentication and
resource authorization. Recruiting consent, sharing, source truth and RLS are
unchanged. The production page delegates to `RecruitingShowcaseView`, so its real
composition is tested with canonical identity fields and approved external media.
Public title/category/verification/date/current/corrected/historical labels remain.
No public management, Family, administrator or correction navigation is added.
