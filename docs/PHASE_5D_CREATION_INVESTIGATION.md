# Phase 5D Football game-creation investigation

**October 5, 2026: root cause proven; narrow fix validated, migrated, released
and verified after direct authorization. Phase 5D remains INCOMPLETE. No
acceptance window, live game or temporary authority was created during this
investigation and release.**

Starting branch/head: `build/boss-platform-v1`,
`cbce2889a5f1895ed71c2a944a09e854d7cbc4c1`. PR #3 is OPEN / DRAFT / UNMERGED.

## Proven cause and safe evidence

**Classification A: Calendar candidate/projection issue**, with a contributing
frontend feedback defect (B). Calendar validly permits an internal opponent to
be recorded while targeting only the scheduling team. Existing Game Center
architecture requires the internal opponent to participate as an explicit target
of that same Calendar event. The write path enforced that condition; the
candidate read path did not. It therefore offered an uncreatable matchup.

The immutable `event.create` audit
`835c5050-321b-4dcd-9782-df93f803573b`, created
**2026-10-05 00:26:18.893365 UTC**, proves that retained controlled event
`7e407db7-552c-427e-b3e1-7bad5161167a` had version 1, scheduled status,
one Falcons team target, start **00:25 UTC** and end **01:25 UTC**. It was a
single occurrence in UTC, member visibility and unpublished. Its retained game
details name the existing same-organization Wildcats opponent, home location
and scheduled game status. The native Calendar mutation stores targets and
opponent independently; it does not automatically add the opponent as a target.
There is no intervening `event.update` audit. Cleanup archived the event at
version 2; it did not add an opponent target or create a game.

Safe Supabase edge metadata establishes both submissions reached the RPC:

| Attempt | RPC edge timestamp UTC | RPC status | PostgreSQL error timestamp UTC | Safe error |
| --- | --- | --- | --- | --- |
| Original | 2026-10-05 00:29:07.753 | 422 | 00:29:07.792 | `PT422: Invalid game context` |
| One retry | 2026-10-05 00:30:20.823 | 422 | 00:30:20.917 | `PT422: Invalid game context` |

Only method, path, status, timing, SQLSTATE, whitelisted error text and function
names were retrieved. Request headers, JWT/session/cookie values and raw SQL log
statements were not retrieved. The function contexts show the Football,
Soccer and Basketball wrappers reaching `games_command_phase5a` through
`games_mutate`. This is an evidenced validation failure, not a transport timeout.

The exact failing boundary requires that an internal opponent be among the
event's team targets. All other observed fields in that boundary were valid:
distinct Falcons/Wildcats, active Football sport, standard competition and
targeted primary team. **No canonical game was inserted and later removed.**
Canonical reads found zero linked games, zero Football games/states/facts/seals,
zero event-bound create receipts and zero notification sources for this event.
The only Game Center receipt in the window is the successful feature save.

The generic form mapped HTTP 422 to its unconfirmed/retry message. The server
correctly returned validation status 422; the UI wording concealed that fact.

## Exact path and boundaries

1. Native Calendar `event.create` accepts an authorized explicit target list and
   separately validated same-organization internal opponent.
2. `boss_games_read` -> `boss_private.games_read` selects authorized scheduled
   competitive occurrences. Before this fix it checked create permission on the
   opponent, but omitted the opponent's actual event-target relationship.
3. `projectGameData` bounds and validates candidate identity/version/key/teams.
4. `GameCreate` resolves `event_id:occurrence_key`, then builds the current
   candidate's event version, selected primary team, `sport_key=football` and
   `competition_type=standard`.
5. `GameForm` validates with `parseGameCommand`, creates a request UUID and sends
   same-origin JSON POST to `/app/games/mutate`.
6. The route -> `performGameMutation` checks same-origin POST, JSON body limit,
   finite fields, request UUID, command parser and verified current caller.
7. `public.boss_games_mutate` -> private dispatcher checks live Auth, locks the
   caller/request idempotency key and invokes the current sport wrappers.
8. `game.create` falls through all three sport wrappers to the common Calendar
   boundary. Authorization/module/version/occurrence/opponent checks precede
   context validation. Missing opponent target raises the observed PT422.
9. Canonical insert, `games_append`, receipt creation and refreshed game
   projection occur only after that boundary; none occurred for this event.

Authorization was sufficient: the captured original platform-administrator
assignment was active, carried `games.create`, and remained intact. Native
`games.configure` audit `cb574b5a-2201-4d10-85f6-c9cdd77dbeb0` at
**00:28:38.446459 UTC** enabled Game Center before both failed submissions.
The earlier preparation omission was corrected before the first game-create
attempt; it did not cause this PT422. The bounded Sports/Calendar window was
still active. Reaching the context boundary also establishes that the earlier
authorization, event-version and occurrence checks passed.

Football engine gates do not run for `game.create`; they apply to configured
engine operations. A focused test creates Football with only `game_center`
enabled and no Football engine state. Basketball and Soccer use the same
candidate/write boundary. UUID/FK, distinct-side, sport, occurrence uniqueness,
competition and lifecycle constraints remain unchanged; the rejected request
did not reach the canonical insert or Football triggers.

For an unchanged form command, `GameForm` retains the request UUID by its JSON
signature. The observed retry followed that path. Neither rejected transaction
commits a receipt: the receipt table represents successful mutations, not failed
or pending requests. Original request UUID and byte-for-byte original payload
cannot be independently recovered from these safe metadata/receipt records;
that evidence limit is retained. Both attempts nevertheless establish the same
database rejection. No new game was created to diagnose replay.

## Validated narrow fix

- CLI-created migration
  `20261005103919_phase5d_game_candidate_validation.sql` adds one indexed
  opponent-target existence predicate to the existing bounded candidate query.
  The rest of the read function is preserved. Existing write authorization,
  ACLs, RLS, engine gates, configuration and data are unchanged.
- Game Center administrator setup guidance explains that both participating
  teams must be Calendar targets for an internal matchup.
- The generic native form labels HTTP 422 as a validation failure; unknown
  outcomes still retain safe idempotent retry wording.

Migration SHA256:
`2eed671c7a09fbff77b359d746a7eff4c08213d48c1af8c7fc456250dd0a0b03`.
Canonical original read-body MD5 is `1c1dc7e64ecebe4915c3e4dfc1a3a0ac` and exactly
matches the local original. Validated replacement MD5 is
`7b85e9c9ce6c4707042ee5a2cf73627d`. The replacement keeps stable execution,
empty search path, existing owner and execute ACL; it grants no new authority.

Disposable PostgreSQL reproduction passed native Calendar creation and exact
PT422 rejection/retry before failing the candidate-exclusion regression. After
the fix all **12 focused assertions passed**, including no failed receipt/game,
two-target candidate eligibility, Football creation with engine features off,
same-identity successful replay, absence of premature engine state and valid
Basketball/Soccer/external-opponent compatibility. Separate existing Game Center
suites passed **635 assertions and 22 two-connection races**. Both disposable
clusters were removed. The full Football suite was not repeated.

Typecheck PASS; lint PASS with zero warnings; **339/339 application tests PASS**;
production build PASS. The initial aggregate validation command reached build
without the required public environment and correctly refused it. Build was then
run successfully with canonical project URL, approved platform origin and the
existing synthetic publishable-key fixture. No production credential was read.
Hosted deployment will use existing platform environment without changing it.

## Live release, historical approval boundary and restoration correction

Automatic approval review initially rejected the attempted production migration
because it did not accept the earlier attachment as explicit live-production
authorization. That rejected action made no change. Main Boss later supplied
direct authorization for this exact release. Canonical migration
`20261005110330_phase5d_game_candidate_validation` then applied successfully.
Canonical history contains **45 migrations** and the live read-body MD5 is the
validated replacement `7b85e9c9ce6c4707042ee5a2cf73627d`. Owner `postgres`,
security-definer status, stable volatility, empty search path and authenticated
execute ACL remain intact. Regenerated public TypeScript types are byte-identical.
No data, grant, policy, configuration or acceptance fixture was changed.

Post-apply disposable validation passed the focused 12 assertions and existing
Game Center 635 assertions plus 22 two-connection races. Typecheck, zero-warning
lint, 339/339 application tests and production build passed. The application
feedback/guidance change is released through the existing Boss platform branch.
Read-only hosted health and baseline checks follow deployment. A new acceptance
window remains outside this release.

Release-tool disclosure: the Netlify helper emitted a one-time proxy deployment
URL and the deploy reader returned a routing token in tool output. A general
browser inventory also surfaced credential-bearing URL material from an unrelated
open tab. None of those values was used, repeated, saved to a file, committed or
included in this record. No Boss password, Auth token, session value or privileged
database key was requested or used. Owner-side expiry/revocation review is needed;
this task therefore does not claim zero credential-material exposure.

Read-only native hosted checks passed: Game Center loads as disabled for the
restored organization; existing administrator can read the retained archived
Football event, whose opponent and single Falcons target are visible. Canonical
checks confirm valid original administrator, no new controlled team memberships
or operators, guardian/household/original Child1 membership baseline equality,
exact operational module configuration/status/windows and zero event-bound
notification sources or work. No private game or stat payload was retrieved.

**Correction to prior report wording:** operational baseline equality is not
revision-counter equality. Recovery audit
`2a3c9f3b-d26d-435c-829e-abe279244db3` explicitly records
`monotonic_version_preserved`. Calendar revision advanced **10 -> 12** and Sports
**15 -> 18** through activation/configuration/restoration. Those counters are
valid audit history and confer no authority. They were not rolled back. Earlier
claims of exact configuration-*and-version* equality were incorrect. This
correction preserves the original acceptance/cleanup history rather than
rewriting it; restoration still completed before the original cleanup deadline.

After approval and read-only fix-release verification, recommend returning to
Main Boss Chat for a separately approved controlled acceptance window. Its first
gate must explicitly target both participating teams in native Calendar, verify
the exact candidate/version/occurrence/sport, then confirm exactly one canonical
Football game and one successful receipt before activating operators, guardian
authority, transfer or Wildcats memberships. Stop and recover if that gate fails.
This investigation does not open that window.

## Requested 33-point return

1. Starting SHA: `cbce2889a5f1895ed71c2a944a09e854d7cbc4c1`.
2. Hosted availability: authenticated Game Center and Calendar reads verified.
3. Archived event: version 2, archived/unpublished, single Falcons target,
   internal Wildcats opponent; immutable creation audit establishes version 1.
4. Path: Calendar -> candidate -> GameCreate/GameForm -> same-origin mutation
   route -> parser -> RPC -> sport wrappers -> common context validation.
5. Candidate: erroneously omitted the internal-opponent target requirement.
6. Form: Football input is supported; HTTP 422 was misleadingly called unknown.
7. Parser: focused native-shape Football command is accepted unchanged.
8. Server: both original and retry reached Supabase RPC with status 422.
9. Database: both reached the common dispatcher and raised Invalid game context.
10. Idempotency: no failed/pending receipt; original request ID not recoverable
    from safe evidence. Unchanged form retry retains its ID by implementation.
11. Authorization: original active platform administrator and required gates
    passed before the context failure.
12. Feature gate: Game Center enabled before attempts; no premature Football gate.
13. Constraints/triggers: preserved; insert was never reached.
14. Other sports: shared boundary; valid Basketball/Soccer creation still passes.
15. Local reproduction: exact PT422 reproduced; candidate regression failed
    before and passed after the fix.
16. Root cause: A, candidate/write context mismatch; B, misleading error feedback.
17. Fix: narrow candidate predicate, target guidance and validation feedback;
    live-applied and released after direct authorization.
18. Regressions: 12 SQL assertions and three new application tests.
19. Typecheck: PASS.
20. Lint: PASS, zero warnings.
21. Application tests: 339/339 PASS.
22. SQL: focused 12 plus existing 635 assertions and 22 races PASS.
23. Build: PASS with existing synthetic public environment fixture.
24. Deployment: released through the existing Boss platform branch; read-only
    deployment and health verification recorded in the final handoff.
25. Hosted checks: read-only baseline/archive/admin/game/receipt/work checks PASS.
26. Final SHA: exact pushed documentation successor recorded in the final handoff.
27. PR #3: OPEN / DRAFT / UNMERGED; no merge.
28. New window: recommend only after approved fix release and new owner approval.
29. First gate: valid both-target Calendar occurrence -> one confirmed Football
    game/receipt before any temporary acceptance authority.
30. No temporary authority created: confirmed.
31. Wildcats memberships not created: confirmed; no new controlled memberships.
32. Credential disclosure: release tools emitted a one-time Netlify proxy URL,
    deploy routing token and unrelated-tab credential-bearing URL in tool output.
    None was used/repeated/stored/committed; no Boss password/Auth/session/key was
    requested or used. Owner-side expiry/revocation review remains. No real
    youth/customer data or invented DOB.
33. No later phase started: confirmed. STOP at this investigation/release boundary.
