# Phase 6A — Season + Career Statistical Intelligence Foundation

Status: **APPROVED IMPLEMENTATION CONTRACT — PHASE 6A ONLY**. Main Boss Chat directly authorized implementation and release on October 5, 2026, subject to the five decisions below. October 5, 2026 audit baseline: `build/boss-platform-v1`, `2e5e8ae1a1fafb3eab92eedb69c95bc68f217fda`. GitHub PR #3 independently verified OPEN/DRAFT/UNMERGED at that same head. Basketball, Soccer, Football, Volleyball, Baseball and Softball remain COMPLETE. At contract approval, no implementation or live changes had occurred; subsequent results must be recorded separately.

The Main Boss Chat direction and approved decisions below are binding. Proposed internal storage names may follow the model below; they do not authorize later modules. Existing sport seals remain authoritative; statistical intelligence is a disposable, reproducible projection. Historical disclosures and prior acceptance evidence remain unchanged.

## Approved Main Boss Chat decisions — supersede original recommendations

1. **Season:** use season captured by canonical sealed game/epoch provenance, never current or later team season. Null stays null, excluded from named seasons and labeled unassigned/legacy in authorized career totals. No silent finalized-game reassignment; correction requires reviewed refinalization semantics.
2. **GP:** require finite positive sport-specific accepted participation evidence at the seal cutoff. Rostered alone never means played. Accepted court/lineup/substitution/rotation/keeper/pitcher/defensive/baserunning/PA participation and athlete-attributed accepted facts may establish confirmed GP. Expose complete/partial/unknown participation coverage; no fabricated exact GP or GS.
3. **Inclusion:** explicitly version classification as official/exhibition/scrimmage/practice/controlled_test/excluded/pending. Only eligible official games with a current authoritative final epoch enter default totals. No classification by record names. Archive/publication is independent. Existing unreliable classification stays pending; synthetic acceptance resources have explicit provenance and cannot contaminate real official totals.
4. **ERA:** workload is integer outs. ERA=ER×basis_innings×3/outs. Defaults Baseball9, Fastpitch Softball7; preserve explicitly reviewed differing conventions and version. Mixed conventions return components/metadata and unavailable mixed ERA, never silent normalization. WHIP=(BB_allowed+H_allowed)×3/outs. No per-game rate averaging.
5. **Freshness:** implement hybrid rebuildable contribution+summary model. Finalize/reopen/refinalize atomically change generation/dirty scopes. Bounded eager refresh where safe; otherwise return explicit pending/current metadata, never known-stale authoritative totals. Deterministic rebuild and concurrent workers converge idempotently.

Implementation authorization includes forward migrations only after disposable PostgreSQL17 validation, six-sport coverage/formula/participation/privacy assertions, historical and new coordinated races, canonical types, application checks/build, canonical deployment, one fixed controlled hosted window with prepared independent recovery and immediate cleanup, commit/push and PR #3 update. PR remains OPEN/DRAFT/UNMERGED. No later phase.

## 1. Authoritative source model

Use `game_finalizations` plus the matching `game_basketball_finalizations` / `game_basketball_final_stats`, Soccer, Football, Volleyball equivalents, and `game_diamond_finalizations` / `game_diamond_final_stats` for Baseball and Softball. Join by canonical finalization UUID, organization, game, epoch and frozen roster revision. Player rows join their immutable `game_roster_snapshots` by roster UUID and revision; team rows have null roster UUID. Derive side ownership from the original game's primary/opponent team, never current membership. An external opponent has no invented Boss team or athlete identity.

A normalized internal source contract references existing seals, not copied raw plays: organization, original unit/team, both season IDs, sport, game/event/occurrence, finalization/epoch, roster/revision, person/participant, side, source-stat ID, seal timestamp, engine version, source cutoffs, coverage references and finite metric values. An adapter validates all composite associations before admitting a contribution. Invalid provenance is reported and excluded, never silently coerced.

Primary audit anchors (repository-relative):

- `supabase/migrations/20261004052521_phase5a_game_center_core.sql`: game identity, frozen rosters and immutable canonical finalizations.
- `20261004140729_phase5b_basketball_core.sql` and `20261004140744_phase5b_basketball_integration.sql`: typed Basketball totals/seals.
- `20261004172028_phase5c_soccer_core.sql` and the Phase 5C integration migration: typed Soccer totals, participation intervals and nullable keeper evidence.
- `20261004232222_phase5d_football_core.sql`, `20261004232241_phase5d_football_integration.sql`, `20261004232246_phase5d_athlete_history.sql`: finite Football metrics, seals and persistent-person history.
- `20261005142103_phase5e_stat_tracking.sql`, `20261005142049_phase5e_volleyball_core.sql`, `20261005142133_phase5e_volleyball_integration.sql`, `20261005142141_phase5e_volleyball_history.sql`: profile snapshots, side/player coverage, Volleyball seals and legacy annotation.
- `20261005163647_phase5f_diamond_core.sql`, `20261005163717_phase5f_diamond_seals_history.sql`, `20261005165247_phase5f_runner_projection_fix.sql`: shared Diamond seals, six-sport history and corrected projection.

These filenames without a directory prefix also refer to `supabase/migrations/`. The new adapter must consume full authoritative seals, not the bounded/paginated athlete-history RPC or UI rendering. That RPC is useful authorization/provenance precedent, not an aggregation feed.

## 2. Current-epoch selection

A source contributes exactly when its canonical game has `status = 'final'` and its canonical finalization epoch equals `games.finalization_count`; sport header and roster revision must match that finalization. `latest_sealed` alone is insufficient: reopening retains the latest seal but removes current authority. Do not select `max(epoch)` independently of canonical game state, nor count all immutable history rows.

Uniqueness is one selected canonical finalization per game, with one contribution per side/subject/stat definition. Fail closed on missing/contradictory matching sport seals. Publication, module flags, current memberships and current team labels do not rewrite this statistical identity. Explicit official classification is required as approved above; publication is never an athlete-history permission.

## 3. Athlete season aggregates

Key by persistent person + sport + canonical season UUID. Preserve organization in every component; an organization-owned season UUID is not a global year label. Use immutable canonical game-season provenance as the attribution season. Original-team season remains separately labeled provenance and never substitutes for game season.

Combine distinct original-team components within the same season only for an authorized projection. Return additive components, complete-only totals, partial/unknown observations, metric coverage, GP evidence, formula inputs and definition version. A family projection may combine multiple authorized origin teams; a current coach receives only independently authorized origin slices. Do not relabel different organizations' season UUIDs as the same season merely because names or dates match.

## 4. Athlete team-season aggregates

Key by organization + original team + canonical season + person + sport + definition version. Participant IDs remain source provenance; do not create a new participant on transfer. Retain a contribution manifest linking every contributing game, roster revision and selected epoch. Deduplicate a person's GP by game within each slice; duplicate roster/person associations are an integrity error, not additional appearances.

Team-season components are the privacy-preserving building blocks of broader totals. Stored all-history values must not be returned to a coach and then redacted on the client.

## 5. Athlete sport-career aggregates

Career combines compatible season components within one sport for the same persistent person. Preserve organization/team/season slices so current authorization can select the eligible subset. Include a separately identified unassigned-season component where valid history has no canonical season; it never becomes a fabricated season. Career GP is distinct qualifying game count, not blindly summed duplicated appearances.

No cross-sport statistical sum. Different engine/stat definitions or unit conventions are combined only through an explicitly versioned compatibility mapping. Self/guardian can retain history after origin relationships end under the established history contract. Organization readers see authorized organization contributions, not the subject's other tenants. A private full-career materialization is an optimization, not a disclosure entitlement.

## 6. Team season and sport-history aggregates

Use original canonical team + sport + season. Count one completed authoritative game per team side; scoring for/against comes from the selected canonical finalization, not summing attributed players. Sport team counters come from sealed team rows, not player sums: unattributed plays and sport credit conventions can make those sums differ legitimately.

Volleyball canonical score is sets; rally points remain a separate metric. Diamond scores are runs; Soccer scores goals. Preserve units. Team+sport history is the same compatible cross-season foundation, retaining season components. Expose completed-game and scoring contracts without W/L/T rankings, standings points or tiebreakers. Opponent identities and any safe public team totals follow existing Game Center disclosure rules, separate from private athlete statistics.

## 7. Coverage and denominator model

Each metric returns `complete_value`, `observed_value`, complete-game count, partial-game count, untracked-game count, legacy-unknown count, applicable-game count, participation uncertainty and units. `observed_value` is a labeled sum of available observations; it must never be labeled a complete season total when any applicable source is partial/unknown. No known measurements yields null, not zero. A measured zero has complete coverage and value zero. Non-applicable keeper/pitcher metrics are distinct from untracked applicable metrics.

Map existing `tracked` to complete declared tracking for that metric, subject to player attribution, reliable participation and source-specific dependencies. This is declared capture coverage, not proof that an operator recorded every real-world action. Preserve existing `partially_tracked`, `not_tracked`, and missing-seal `legacy_unknown`. Resolve Volleyball nested player-stat coverage and player-attribution restrictions; a side's tracked value alone does not guarantee tracked player statistics. Diamond must apply the sealed coverage semantics before reading optional zero counters. Historical legacy zeros cannot be promoted to measured zero.

Per-game average uses only qualifying played games with complete metric coverage, summing values from exactly that same cohort. Example: GP 20, 15 complete rebound games => RPG = sum(rebounds in those 15 games)/15; five partial/untracked games are disclosed separately. If GP is uncertain, do not pretend a precise full-season GP denominator exists.

Rates require joint coverage of all inputs in the SAME sources. Independently complete H in one game and AB in another do not form valid AVG. Store per-formula joint-cohort component sums and counts, or rebuild them from bounded contributions; per-metric marginals alone cannot reproduce rates. Partial-cohort rates, if later approved, need a distinct label and eligibility policy. Default recommendation is complete-cohort rates plus disclosed observed totals. Coverage intervals cannot automatically supply elapsed-time or plate-appearance denominators; use only existing reliable sealed evidence.

## 8. Sport-specific aggregation contracts

| Sport | Audited canonical fields and reducers | Coverage/semantic limits |
|---|---|---|
| Basketball | Sum points, offensive/defensive/total rebounds, assists, steals, blocks, turnovers, personal_fouls, fgm/fga, tpm/tpa, ftm/fta. | Existing seals have typed counts, no minutes or GP column; roster-seeded zeros are not participation. Current legacy seals have no tracking seal. |
| Soccer | Sum goals, own_goals, assists, shots, shots_on_goal, saves, goals_allowed, yellow_cards, red_cards, fouls; sum reliable minutes; count true clean_sheet only in eligible complete keeper cohort. | Minutes/GA/clean_sheet may be null deliberately. Reliable keeper coverage requires participation completeness, attributed concessions and keeper intervals; clean_sheet is not simply team GA=0. False reliable clean_sheet is a measured failure, null is not. |
| Football | Sum passing completions/attempts/yards/TD, INT thrown, sacks taken/yards lost; rush attempts/yards/TD; receptions/targets/yards/TD; solo/assisted/total tackles, TFL, sacks, defensive INT/TD/pass defenses; fumbles/lost/forced/recoveries; FG and XP M/A, conversion M/A; punts/yards/touchbacks; kick/punt/INT/fumble return counts where present and yards/TD; points, TD, safeties, first downs, penalties/yards, kneels/yards, turnovers/down. | Preserve signed yards and existing kneel configuration. Long_rush/reception/punt/kick_return/punt_return/field_goal use MAX, never SUM. Null long_field_goal means no made attempt; zero is not substituted. Team tackles differ from summed individual assisted credits. No complete all-player participation seal. |
| Volleyball | Sum kills, attack_attempts, attack_errors, assists, digs, service_attempts/aces/errors, solo_blocks, block_assists, blocks, blocking_errors, receptions/errors; team points and set_wins separately. | Player points/set_wins are deliberately not tracked. One assisted block awards one team block but individual assist credits; never derive team blocks from player sum. Hitting percentage is recomputed. Coverage must honor attribution and nested player coverage. |
| Baseball / Softball | Separately sum pa, ab, runs, hits, singles/doubles/triples/home_runs, rbi, walks, hbp, strikeouts, sacrifice_bunts/flies, stolen_bases/caught_stealing; outs_pitched, batters_faced, hits/runs/earned_runs/walks/hbp/home_runs allowed, strikeouts_pitched, wild_pitches; pitches/strikes when tracked; putouts, assists, errors, double_plays. | Separate sports even though engine is diamond-v1. Optional pitching/fielding zero counts can be untracked. Outs are integers; rate units depend on sealed ERA configuration. Pitcher/fielding participation can occur with no positive counting stat. |

The finite Football adapter must whitelist every key in `football_stat_keys()` (including derived net_passing_yards, total_offensive_yards, return_yards, turnovers); validate compatible derivations, not add derived and base fields into a generic total. Diamond sealed AVG/OBP/SLG/OPS/ERA/WHIP/strike_percentage and Volleyball hitting_percentage are evidence/display fields, not summable inputs. No unsupported advanced metric or standard association formula is added merely because it is common in sport reporting.

## 9. Derived-stat formulas

Use exact numeric component sums, divide only with positive compatible denominator, round at presentation. Missing inputs/zero opportunity denominator => null with reason; retain negative legitimate values.

| Metric | Complete joint-cohort formula |
|---|---|
| Basketball FG%, 3P%, FT% | 100 × SUM(makes)/SUM(attempts), respective paired fields |
| Per-game stat | complete played-cohort stat sum / distinct complete played-cohort games |
| Soccer shots-on-goal rate; save rate | SOG/shots; saves/(saves+GA), only compatible reliable keeper cohort for save rate |
| Football completion%, yards/attempt, yards/carry, yards/reception, punt average, FG%/XP% | completions/attempts ×100; passing_yards/passing_attempts; rushing_yards/rush_attempts; receiving_yards/receptions; punt_yards/punts; respective M/A ×100 |
| Volleyball HIT% | (SUM(kills)−SUM(attack_errors))/SUM(attack_attempts); ratio, not 0–100 percentage |
| Diamond AVG | H/AB |
| Diamond OBP | (H+BB+HBP)/(AB+BB+HBP+SF) |
| Diamond SLG; OPS | (1B+2×2B+3×3B+4×HR)/AB; OBP+SLG over the common complete cohort for all OPS inputs |
| Diamond ERA; WHIP | ER×(3×ERA innings convention)/outs_pitched; (BB_allowed+H_allowed)×3/outs_pitched |
| Diamond strike percentage | 100×strikes/pitches where both fully tracked |

No averaging of game ratios. Do not derive PA from a guessed formula when canonical pa exists. Finite statistical output contains no engine payload or sensitive metadata. ERA conventions (e.g., 7 vs 9 innings) require separate compatibility buckets or an explicitly approved normalized reporting convention; no silent mixed-convention career ERA. Do not invent passer rating, official clean-sheet rules or leader eligibility. Future formulas must have a definition version and source mapping.

## 10. Participation / GP and future GS

Recommend tri-state game participation: `played`, `did_not_play`, `unknown`, with evidence/version. A roster/stat row is not played. GP can be reported as verified lower bound plus unknown-game count until complete participation evidence exists; exact GP is available only for a complete classified cohort.

- Basketball: positive credited count proves involvement, but a zero-stat player may have played. Final state/roster cannot reconstruct all earlier court appearances. Do not replay raw events merely to invent aggregate GP. Unknown stays unknown unless an existing sealed participation contract is demonstrably complete.
- Soccer: reliable sealed minutes >0 proves played; reliable zero minutes can establish no time under the engine's complete interval model. When participation_complete is false or minutes null, qualifying credited actions may prove involvement, but no action does not prove absence. Keeper eligibility uses the engine's reliable evidence, not roster position text.
- Football: credited attempts/receptions/returns/tackles etc. establish participation. Zero credits cannot establish DNP; linemen may play without credit. Signed yards alone may cancel to zero, so opportunity counts matter. No complete GP from roster.
- Volleyball: credited action establishes involvement. Final lineup does not prove complete appearance history; bench/zero-stat court players require immutable participation evidence not currently present as an explicit final-stat field.
- Diamond: PA/BF or credited pitching/fielding/running action proves participation. outs_pitched>0 is sufficient but not necessary for a pitcher who allowed runners without an out. Final batting/defensive lineup alone cannot certify all zero-stat appearances. Do not manufacture pitcher GP, position GP or GS.

Frozen roster `starter` is roster intent, not actual Games Started. Additional immutable appearance evidence may be proposed in a later authorized sport-source amendment; Phase 6A must not become another raw entry/replay system. Confirmed GP with honest participation coverage is approved. Participation extraction may inspect accepted immutable participation/fact identity at the sealed cutoff; statistical values still come exclusively from seals. Do not introduce raw entry or recalculate seal totals from facts.

## 11. Team-change behavior

Transfer changes live relationships only. Source organization/team, immutable roster/person/participant, finalization and season IDs remain untouched. Example 12 Falcons + 9 Wildcats qualifying distinct games => authorized athlete season GP21 only when participation coverage establishes all 21. Otherwise show observed counts and uncertainty. Same-game duplicate sources are deduplicated by canonical game for personal GP.

Current Wildcats membership grants Wildcats-origin slices only where existing staff policy authorizes them. It grants no private Falcons contributions or correction authority, including through season totals, career totals, coverage counts, search, cursors or manifests. Guardian/self may retain both origin slices despite old membership ending. A later consent grant is a separate product, not implicit transfer behavior.

## 12. Privacy and authorization

Separate internal computation from live entitlement and finite presentation. Reuse established historical self/verified guardian semantics and Game Center origin-context resource policies; do not invent broader role permissions. Household membership alone remains insufficient.

| Reader | Proposed permitted projection |
|---|---|
| Self | Own compatible sport history across origin relationships, subject to existing active identity checks |
| Guardian | Exact currently verified authorized child history; natural expiry/revocation denies next request |
| Origin team staff | Independently authorized original-team/resource slices; history permission cannot imply correction |
| Current team staff | Current-team-origin slices, never prior private history solely because of current relationship |
| Organization administrator | Independently permitted origin-organization/resource slices; not another tenant or automatic family-history override |
| Platform administrator | Existing policy only; no newly invented private athlete bypass |
| Future sharing recipient | Denied until a separately approved explicit resource/consent/expiry model exists |
| Anonymous/public | Closed; published game is not athlete-career publication |

Staff season-history eligibility after membership ends must follow existing resource policy; if not defined, deny and ask Main Boss Chat. Projection metadata reports its authorized scope, not counts of hidden sources. Filter before summation; even an opaque cross-team career scalar can disclose prior private data. Whole-career caches are accessible only for already authorized whole-history self/guardian paths, never current coaches by cache key.

## 13. Season identity

Canonical `seasons` is organization-owned with optional parent_unit_id; teams and games both have nullable season_id. Game identity, including season, is protected by `games_identity`. Existing history distinguishes game season from original team season and filters by original team season. Preserve both IDs, not current season names as attribution truth.

Approved athlete/team aggregation uses canonical sealed game season consistently on both sides, including when the opponent team season differs. Preserve original-team season separately. Never coalesce conflicting non-null IDs or infer season from dates/name. Missing season goes to an explicitly unassigned slice; career inclusion may still be possible with valid seals. No global season entity or arbitrary 2026 grouping is added.

Capture immutable provenance references; current display labels may change and are not historical name snapshots. Audit that team season remains protected against rewrite; any legitimate historical reassignment needs an explicit audited correction design, not editing game source IDs. Exact unit/team scope remains; no implicit descendant inheritance.

## 14. Reopen / refinalization behavior

Recommended transactional selector/generation invalidation at canonical game state change: epoch1 final => selected epoch1; reopen => selected null and affected summary generations dirty; epoch2 final => selected epoch2 and affected generations dirty. Old seals remain immutable. Refinalization changes each game contribution by replacement, not append-to-totals. The previous epoch is accessible historical evidence but contributes zero to current summaries while reopened.

Reads may return an explicitly pending/currently unavailable projection during refresh; they must never label epoch1 current after committed reopen. For a pinned read transaction, a coherent snapshot before a concurrent reopen is legitimate and has an as-of marker; a new request after commit must observe invalidation. Do not expose stale materialization as authoritative during supersession. This invalidation hook is proposed future implementation, not installed now.

## 15. Idempotency

Canonical finalization receipts retain existing semantics. Unique refresh work key: game + selected-state generation + aggregation-definition version. Unique contribution key: finalization + side + roster-or-team subject + definition version. Summary identity includes dimensions and version; an update compares expected generation before publishing.

Receipt replay creates no second finalization/contribution; duplicate queue delivery converges on the same selected target. Reopen-to-null is a real desired state, not a missing job. Transactions replace/rebuild a affected slice atomically; never apply unguarded numeric deltas from duplicate deliveries. Retain bounded internal receipts/audit without any Auth material.

## 16. Concurrency

| Race | Required behavior |
|---|---|
| Finalization vs refresh | Reader/worker sees coherent committed seals or remains pending; no half-seal publish |
| Refinalization vs refresh | Old worker fails generation compare; latest selector wins |
| Two workers | Slice lock plus generation compare yields one published state; repeat is a no-op |
| Season reassignment attempt | Existing source identity constraints deny; do not migrate totals silently |
| Membership/guardian change vs read | Serialize relevant authority rows, recheck live identity/expiry after waits, filter exact origin slices |
| Read during supersession | Return a coherent validated generation or pending; never mixed old/new totals |
| Receipt replay | No second epoch or summary increment |
| Rebuild vs new final/reopen | Build staging snapshot, then verify generations under locks before publish; retry changed slices |

Maintain existing event→game→authority lock order in mutations. New invalidation must not take summary locks on a path that inverts worker order. Workers may compute outside locks, then lock event/game in canonical order, selectors and sorted summary keys for short validation/publish. Never hold summary locks then acquire game locks. Multi-game/slice batches require sorted deterministic order, bounded lock timeout and retry budget. Read-side source validation and revocation locking require a coherent snapshot protocol; test actual independent connections, not only sequential SQL. No slow rebuild under a request's guardian lock.

## 17. Materialization recommendation

| Approach | Assessment |
|---|---|
| Direct computed seals | Excellent correctness oracle and initial bounded slice fallback; repeated long careers become expensive |
| Global materialized view | Rebuildable but broad refresh costs and private mixed-origin rows make it unsuitable as directly exposed API |
| Numeric incremental deltas | Fast but difficult maxima, joint cohorts, duplicates and supersession; unnecessary first-version risk |
| Hybrid, recommended | Canonical selector/invalidation + replaceable per-game projections + origin-slice summaries + optional private career summaries; bounded queued refresh and direct-seal oracle |

Recommendation: hybrid with slice recomputation initially; incremental replacement can later optimize measured hotspots. Stored normalized contributions are disposable projection data, not copied raw facts or a second truth. Reads gate on generation/freshness and live authorization. No browser-controlled refresh or publicly executable privileged worker RPC. Approved freshness policy uses bounded eager/read refresh with explicit pending fallback; zero stale-authoritative disclosure is mandatory.

## 18. Rebuild strategy

Versioned staged rebuild reads selected canonical seals and coverage; validate associations and formula cohorts, generate sorted manifests/checksums and reconcile against independent direct-seal totals. Publish bounded slices only if source generation still matches. Concurrent changes dirty/retry affected slices. Keep previous definition generation for audit/rollback, not current statistical truth.

Deleting all aggregate caches must leave canonical evidence intact and permit identical results. Backfill unassigned/legacy sources honestly. Report rejected provenance/unsupported definitions rather than fabricate data. A rebuild consumes immutable seals, never raw-event replay or editable UI. Reconciliation must check source set membership as well as numeric totals: coincidentally equal values can conceal duplicate/missing epochs.

## 19. Versioning

Propose immutable aggregation definition version and per-sport metric/formula version, including units, reducer, applicability, coverage mapping, joint cohort and participation definition. Reference source engine version, finalization UUID/epoch/roster revision, tracking snapshot/catalog and cutoff, immutable coverage seal where present. Legacy absence is explicit.

Summary manifests reference contribution generation/definition; do not copy full engine state, profile JSON or names into every metric row. Preserve enough linked inputs to rebuild exactly. New formula versions build separate generations and require explicit activation; never silently change old outputs. Mixed version/unit incompatibility produces separated buckets and a reason, not a numeric merge.

## 20. Performance plan

Target bounded dashboard reads: person+sport+season, origin-team+season, authorized person+sport career, organization+sport+season report. Candidate indexes begin with organization/team/person and sport/season/definition as query patterns require; source manifest lookups index game/finalization and affected dimension keys. Use actual EXPLAIN plans before approving new redundant indexes. Existing source context/roster indexes are useful, not proof of million-person performance.

Paginate manifests/reports by stable keyset (proposed default20/max50); cap metric lists, batch sizes and requested seasons. A self career read uses precomputed compatible summaries rather than career game replay. Staff uses authorized origin summaries. Long-term career may span many teams: define bounded reporting/pagination and optionally private full-career cache without losing origin authorization. Queue lag, dirty generations, source rejection, rebuild duration, lock waits and row scans are measurable internal signals. Set performance budgets using disposable scale fixtures, not today's six controlled games. No private authenticated CDN cache; any future caching is private and still rechecks authorization on each request.

## 21. RLS / security

Proposed internal tables remain closed to PUBLIC/anon/authenticated and exposed service-role table access, with RLS defense in depth. Do not grant aggregate SELECT directly. Only finite authenticated read wrappers may enter caller-bound private authorization code; revoke default function EXECUTE, fix search_path, qualify relations, avoid caller-selected actor IDs and never trust user_metadata. Existing reviewed wrapper/definer pattern must preserve current checks, not bypass RLS to fix access failures.

Raw contribution, worker, manifest and rebuild helpers stay inaccessible to normal clients. Validate every organization/team/person/season UUID combination and page cursor against current scope; unknown/forged resource must not leak existence through totals/counts/errors. No credentials/session values are stored as aggregate provenance. Worker computation has no user disclosure privilege. No new role/permission grant is implied by this architecture. Security review must include aggregate differencing across filters and authorization-cache invalidation.

## 22. Existing-data audit and unresolved decisions

Read-only canonical audit of `ilykgwgmxtrrikreacrz` at **2026-10-05 18:33:29.415021–18:33:29.415045 UTC**, followed by count-only provenance/key inspection. No person names, document contents, credentials or session material were retrieved.

| Sport | Games | Sealed epochs | Current epochs | Older epochs | Epochs lacking tracking seal | Player rows / team rows |
|---|---:|---:|---:|---:|---:|---:|
| Basketball | 1 | 2 | 1 | 1 | 2 | 6 / 4 |
| Soccer | 1 | 2 | 1 | 1 | 2 | 10 / 4 |
| Football | 1 | 2 | 1 | 1 | 2 | 6 / 4 |
| Volleyball | 1 | 2 | 1 | 1 | 0 | 6 / 4 |
| Baseball | 1 | 3 | 1 | 2 | 0 | 9 / 6 |
| Softball | 1 | 1 | 1 | 0 | 0 | 3 / 2 |

These are all stored epochs/player rows, not current-season totals or new acceptance results. Main Boss Chat has resolved the original review questions below; retained here as the pre-approval design history, superseded by the approved decisions above. Zero missing game seasons, null person/participant links, missing original team seasons, team/game season mismatches and broken player roster organization/game/revision joins were found in this small existing sample. Null roster_id on team rows is intentional. Schema still permits missing seasons, and external opponent/team/unit and reliability fields can be null. Runtime tests must cover them even though this sample lacks missing seasons.

Tracking seal top-level metric states total 353 `tracked`, 109 `not_tracked`, 18 `partially_tracked` entries (excluding nested player_stat_coverage). These are metric entries across epochs/sides, not people/games; nested coverage is separately required by adapters. Legacy Basketball/Soccer/Football have no seal coverage and must remain unknown. Current selectors count one epoch in each of six games. Basketball/Soccer/Baseball/Softball have archived schedule epochs (2/2/3/1 respectively); Football/Volleyball schedule_status is not archived in this count. This observation does not reopen cleanup or establish remaining authority; game publication/authority and schedule archival are distinct states.

Review decisions before implementation:

1. Confirm origin-team-season versus game-season attribution, including mismatched opponent seasons and unassigned career components. Recommendation is existing history's origin-team convention.
2. Approve unknown/lower-bound GP and GS availability. If exact GP is required for all sports, approve a separate immutable participation-source amendment; existing zero-stat rows are insufficient.
3. Confirm whether scheduling archival changes statistical inclusion. Recommendation: preserve authoritative sealed history independent of scheduling archival; synthetic tenants remain segregated, and archived season history remains useful. If controlled fixtures require statistical exclusion, define an explicit canonical eligibility mechanism, never name-based test detection. Current-authoritative rule remains mandatory.
4. Approve complete joint-cohort rates and separately labeled observed/legacy totals; never backfill legacy coverage as complete.
5. Choose ERA normalization/buckets when configured innings conventions differ. Recommendation: preserve separate conventions until a reporting policy is approved.
6. Approve pending/refresh freshness UX and staff historical read capability mapping where existing policies do not explicitly define a season dashboard. No broader permissions are assumed.

No observed production defect is asserted by these architecture questions. Sample counts do not prove source completeness at production scale. All prior security/incident disclosures remain in their existing documents.

## 23. Standings boundary

Future Phase 6B may consume a deterministic completed-game result contract: original org/unit/team/season/sport, game/finalization/epoch, opponents, canonical scoring units, competition context and current-authoritative state. No standings table, W/L/T product, points system, conference/division rule, head-to-head, differential/tiebreaker, forfeit or tournament policy is implemented here. Canceled/postponed/reopened games supply no current final-stat contribution; future official-result policy must separately govern standings.

## 24. Leaderboard boundary

Future Phase 6B receives versioned compatible metric components/rates, authorized scope, participation uncertainty, joint coverage and qualifying denominators. Ranking/minimum attempts/minutes/games, tie handling and inclusion policies require configuration and product approval. Phase 6A creates no ranking endpoint/UI. Current staff cannot rank hidden prior-team career data through an aggregate bypass.

## 25. Records boundary

Future records may reference game/season/career/team/org projections and exact definition/source manifest generation. Reopen invalidates current record candidates and refinalization creates a new reproducible candidate; historical records policy is deferred. No record claim, eligibility rule or mutable record truth is implemented.

## 26. Athlete-profile boundary

Future Phase 6C can consume authorized private statistical projections with explicit coverage, scope, definitions and provenance. Private canonical, family-visible, consent-shareable and publicly published are separate disclosure categories. Phase 6A exposes no recruiting/public profile, export/share URL, consent model or broad discoverability. Existing self/guardian authorization cannot be converted into permission to publish a child's data.

## 27. Proposed migrations, tables and RPC/read model

**Approved implementation model.** At contract commit no migration files exist yet. Implementation batches:

1. Definitions and source adapters: immutable finite metric/compatibility registry and verified internal current-seal projection.
2. Selection and invalidation: `stat_game_selections` keyed game with target finalization/null + generation; canonical transaction hook; bounded internal `stat_refresh_work` unique target/version receipts.
3. Disposable projection storage: `stat_game_contributions` unique finalization/side/subject/version with source references and normalized metric/cohort evidence; `stat_origin_summaries` keyed origin dimensions/subject/sport/season/version; optional private `stat_career_summaries`. Separate manifest/member relation and generation/checksum metadata, all reproducible.
4. Authorized read wrappers and operational reconciliation: finite `boss_athlete_season_read`, `boss_athlete_career_read`, `boss_team_season_read`; private refresh/rebuild/reconcile helpers; closed ACL/RLS and exact capability mapping.

Names are tentative. Season-null uniqueness must be explicit (distinct unassigned slice), no sentinel fake season. Organization-bound composite FKs validate original resources; personal cross-tenant career is composed from protected origin slices rather than assigned to a fabricated organization. Manifest binds source stat/finalization/roster and coverage references, while summaries retain additive, MAX and joint-cohort reducers. No editable aggregate command or client worker execution.

Read result: contract/definition version, subject and authorized dimensions, as-of source generation/freshness, metric unit/value/coverage/denominator/reason, participation evidence status and bounded provenance cursor. Self/guardian selection uses existing persistent person rules. Team/org queries accept finite validated scopes, not arbitrary SQL/filter expressions. Refresh state cannot leak hidden games. Whether these wrappers attach to current Game Center feature entitlement or a new intelligence feature requires Main Boss Chat's decision; do not add flags/permissions silently.

## 28. Proposed tests

Disposable PostgreSQL suites must construct real canonical sealed sources for all six sports, compare direct-seal oracle to cache, and verify:

- one authoritative epoch per game; reopen removes, refinalize replaces; historical epochs immutable; receipt replay and duplicate work no-op;
- every additive/MAX metric, signed yards, team/player credit differences, null reliability, Diamond integer outs and configured ERA units;
- measured zero vs unknown/untracked/partial; player attribution; dependency and same-source joint cohorts; 20 GP/15 complete rebounds denominator; zero denominators; OPS joint cohort;
- zero-stat roster is not played/GS; confirmed appearances and uncertain GP; no invented identity/season;
- multi-team same-season, cross-season/cross-tenant career, missing/mismatched season, external opponents, archived provenance and manifest deduplication;
- unauthorized tenant/team/unit/person/season/cursor, current-team vs prior-team, self, verified/revoked/expired guardian, household-only denial, ended staff membership, administrator resource limits, anonymous/public denial and direct table/helper ACL denial;
- deletion/rebuild equality by source set/checksum and numeric/cohort output; unsupported versions quarantined, new definition version explicitly activated;
- genuine two-connection finalization/refresh, reopen/refresh, refinalize/old worker, two workers, rebuild/publication, guardian revocation/expiry and source reads during supersession; bounded locks/retries and no deadlock inversion;
- scaled disposable fixtures for millions-person access patterns and bounded query plans, no full career replay per page, authorization filter before composition;
- application contract parsing, finite fields, coverage labels, pending behavior, navigation and mobile rendering once an implementation is separately approved.

Exact assertion/race counts must be set from implemented coverage later, not invented here. Existing 13,430 assertion/153 race/372 app-test results remain historical Phase 5F evidence, not new Phase 6A validation. Final implementation validation would include bootstrap, SQL/races, types, typecheck/lint/tests/build and advisors after authorized schema work.

## 29. Proposed hosted acceptance

**Plan only; no window opened.** After explicit implementation/live authorization, use synthetic existing controlled identities/resources and a single fixed reviewed bounded window. Record baseline, prepare recovery before grants, pass canonical creation/source gates first, minimize temporary scope and stop-new/cleanup/hard-expiry times; never extend expiry. No password/token/cookie extraction or real youth data.

Verify native self/guardian season/career readings, exact-team origin summary, two-team portability without new-team historical disclosure, household-only and revoked guardian denial, coverage displays, formula oracle, reopen pending/removal then new-epoch replacement, request replay, bounded pagination, repeated navigation/reload and 390px/320px layouts through approved tooling. Demonstrate stale authority denial using legitimate native requests. No test-only production endpoint to forge requests; any tooling limitation must be classified honestly and not converted into hosted PASS from SQL.

Immediately explicitly restore baseline/admin/module/relationships, end all temporary authority even if naturally expired, archive controlled resources as reviewed, drain/cancel controlled pending work and verify exact selected baseline plus zero residual authority. Preserve audit timestamps safely. If creation fails, tooling prevents safe continuation, architecture conflicts arise or cleanup deadline is at risk, stop scenarios and recover. Specific temporary grants require their own reviewed authorization; this document authorizes none.

## 30. Explicit deferred work and stop condition

Phase 6A implementation/migrations/types/UI/jobs and release are authorized under the five approved decisions. Deferred: standings, leaderboards, records (Phase 6B); athlete/recruiting/public/shared profiles (Phase 6C); additional sports or sport-source participation amendments; tournaments, association-specific official statistics policy, notifications about rankings, fundraising, Boss Bucks, Money Board, processors, commerce, livestreaming, SMS/Twilio and push infrastructure.

Main Boss Chat has approved the five decisions above and authorized Phase 6A implementation, validation and release. Stop after the complete Phase 6A report. Standings, leaderboards, records, profiles and all later work remain deferred. The original architecture-only audit did not perform implementation or live changes.
