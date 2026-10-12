import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { GameConsole } from "../src/components/games/console";
import { buildFootballPlay, PlayFields } from "../src/components/football/console";
import { footballBallPosition, footballClock, footballClockEstimate, footballCorrectionEntries, footballDown, footballPeriod } from "../src/lib/football/presentation";
import { parseGameCommand } from "../src/lib/games/input";
import { footballData, footballFeatures, footballGameRaw, footballRaw, footballQuery, field, athleteId, receiverId, gameId, footballId } from "./football-fixture";
const router: AppRouterInstance = { back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {}, bfcacheId: "football-ui-test" };
const render = (data = footballData(), family = false) => renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, createElement(GameConsole, { data, query: family ? { ...footballQuery, view: "family" } : footballQuery })));
test("Football provides structured sideline plays, field state and grouped box score within existing game detail", () => {
  const html = render(); for (const label of ["Sideline scorer", "Completed pass", "Incomplete pass", "Sack", "Fumble and recovery", "Kickoff with return", "Punt with return", "Confirm field position and down", "Football box score", "Passing", "Receiving", "Football play by play", "Drives", "Sealed football results"]) assert.ok(html.includes(label), label);
  assert.match(html, /2nd &amp; 8 · Own 42/); assert.match(html, /Line to gain: Midfield/); assert.match(html, /6:19/); assert.match(html, /Play yards \(negative for loss\)/); assert.doesNotMatch(html, /Record score summary|Reverse score summary|Courtside scorer|Match statistics|OMIT_|Raw JSON|JSON input/);
});
test("family Football displays only the authorized child and safe aggregates without scoring or correction controls", () => {
  const html = render(footballData({}, true), true); assert.match(html, /Football box score|Controlled passer|Quarter 1/); assert.doesNotMatch(html, /Sideline scorer|Controlled receiver|Controlled defender|Correct a recorded football play|Confirm field position|Football lineups|Sealed football results|OMIT_/);
});
test("Football setup selects explicit youth/timed/possession format and stores optional play-clock foundation", () => {
  const html = render(footballData({ games: [{ ...footballGameRaw, status: "pregame", engine_locked: false, football: { configured: false, capabilities: { configure: true } } }] })); for (const text of ["Four quarters", "No overtime", "Timed periods", "Operator-confirmed possession periods", "Players per side", "Count quarterback kneels", "automated play-clock and penalty enforcement are not available"]) assert.ok(html.includes(text), text); assert.doesNotMatch(html, /Sideline scorer/);
});
test("Football highlights halftime, overtime and touchdown try/kickoff dependencies", () => {
  const game = (extra: Record<string, unknown>) => render(footballData({ games: [{ ...footballGameRaw, football: { ...footballRaw, ...extra } }] }));
  assert.match(game({ period_number: 2, period_status: "ended", clock_ms: 0 }), /Halftime|Start quarter 3/);
  assert.match(game({ period_number: 5, overtime_format: "possession", max_overtime_periods: 2, clock_ms: 0 }), /Overtime 1|End overtime 1|possession-format policy/);
  const tryHtml = game({ field_state: { ...field, phase: "try", scoring_side: "primary" } }); assert.match(tryHtml, /Touchdown try for Falcons|extra-point or two-point attempt before the next play/);
  assert.match(game({ field_state: { ...field, phase: "kickoff" } }), /Kickoff \/ receiving possession required|confirmed receiving placement before scrimmage resumes/);
});
test("Football PBP-off preserves current correction choices and keeps injected drive history unavailable", () => {
  const html = render(footballData({ features: { ...footballFeatures, football_play_by_play: false } })); assert.match(html, /Correct a recorded football play|#8 · Completed pass|Recent accepted plays/); assert.doesNotMatch(html, /Football play by play|<summary>Drives/);
  const disabled = render(footballData({ features: { ...footballFeatures, football_live_scoring: false } })); assert.match(disabled, /Quarter 1|6:19/); assert.doesNotMatch(disabled, /Sideline scorer|Football box score|Correct a recorded|Record score summary/);
});
test("Football structured whole-play builder records kick-return and fumble exactly once without injected fields", () => {
  const form = new FormData(); for (const [key, value] of Object.entries({ roster_id: athleteId, returner_roster_id: receiverId, kick_yards: "50", return_yards: "20", result_side: "opponent", result_ball_spot: "30", result_down: "1", result_distance: "10", actor_person_id: "OMIT_ACTOR" })) form.set(key, value);
  const command = buildFootballPlay({ id: gameId, version: 10 }, "primary", "kickoff_return", form); assert.equal(command.operation, "football.play.add"); assert.equal(command.input.play_type, "kickoff_return"); assert.equal(command.input.kick_yards, 50); assert.equal(command.input.return_yards, 20); assert.equal(command.input.actor_person_id, undefined); assert.ok(parseGameCommand(command));
  form.delete("returner_roster_id"); form.set("base_play_type", "rush"); form.set("recovery_side", "opponent"); form.set("recovery_roster_id", receiverId); form.set("yards", "-2"); form.delete("kick_yards"); const fumble = buildFootballPlay({ id: gameId, version: 10 }, "primary", "fumble", form); assert.equal(fumble.input.base_play_type, "rush"); assert.equal(fumble.input.yards, -2); assert.equal(fumble.input.recovery_side, "opponent"); assert.ok(parseGameCommand(fumble));
  const missed = buildFootballPlay({ id: gameId, version: 10 }, "primary", "extra_point", new FormData()); assert.equal(missed.input.made, false);
});
test("Football whole-play controls show only meaningful type and base-action fields", () => {
  const game = footballData().games[0], state = game.football; assert.ok(state?.configured);
  const fields = (type: "fumble" | "fumble_recovery" | "punt_return" | "touchdown" | "turnover_on_downs", defaults = {}) => renderToStaticMarkup(createElement(PlayFields, { game, state, side: "primary", type, entries: state.entry_roster, defaults }));
  const rushFumble = fields("fumble"); assert.match(rushFumble, /One fumble \/ recovery outcome|Recovering team|Forced-fumble defender/); assert.doesNotMatch(rushFumble, /name="receiver_roster_id"|name="result_side"|name="defender_roster_id"/);
  assert.match(fields("fumble", { base_play_type: "pass_complete" }), /name="receiver_roster_id"/);
  assert.match(fields("fumble", { base_play_type: "sack" }), /name="defender_roster_id"/);
  assert.doesNotMatch(fields("fumble_recovery"), /name="yards"|name="base_play_type"|name="forced_fumble_roster_id"/);
  assert.match(fields("punt_return"), /Kicker \/ punter|Opposing returner|Resulting possession|do not record the kick a second time/);
  assert.doesNotMatch(fields("touchdown"), /name="yards"|name="result_side"/); assert.doesNotMatch(fields("turnover_on_downs"), /name="roster_id"/);
});
test("Football clock estimate is clamped display only and field notation is possession-relative", () => {
  const observed = Date.parse(footballRaw.clock_observed_at); assert.equal(footballClockEstimate({ ...footballRaw, clock_running: true }, observed + 2000), 377000); assert.equal(footballClockEstimate({ ...footballRaw, clock_running: true }, observed + 500000), 0); assert.equal(footballClockEstimate({ ...footballRaw, clock_running: true }, observed - 2000), 379000); assert.equal(footballClockEstimate(footballRaw, observed + 2000), 379000);
  assert.equal(footballClock(379999), "6:19"); assert.equal(footballPeriod(6), "Overtime 2"); assert.equal(footballBallPosition(65), "Opponent 35"); assert.equal(footballBallPosition(35), "Own 35"); assert.equal(footballDown({ ...field, possession_side: "primary", primary_direction: "increasing", phase: "scrimmage", scoring_side: null }), "2nd & 8");
});
test("Football nonoperator correctors use only active authorized current roster revision", () => {
  const row = footballGameRaw.roster[0], opponentTeam = footballId(800); const data = footballData({ games: [{ ...footballGameRaw, opponent: { ...footballGameRaw.opponent, team_id: opponentTeam }, capabilities: { correct: true, view_roster: true }, football: { ...footballRaw, capabilities: { correct: true, stats: true } }, roster: [row, { ...row, id: receiverId, team_id: opponentTeam }, { ...row, id: footballId(801), revision: 2 }, { ...row, id: footballId(802), active: false }, { ...row, id: footballId(803), team_id: footballId(804) }] }] }); const game = data.games[0]; assert.ok(game.football?.configured); assert.deepEqual(footballCorrectionEntries(game, game.football).map(entry => [entry.id, entry.side]), [[athleteId, "primary"], [receiverId, "opponent"]]);
});
