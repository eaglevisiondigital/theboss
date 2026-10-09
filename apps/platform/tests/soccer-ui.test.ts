import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { GameConsole } from "../src/components/games/console";
import { soccerAddedTime, soccerAssistContexts, soccerClock, soccerCorrectionEntries, soccerMinutes, soccerSegment } from "../src/lib/soccer/presentation";
import { soccerData, soccerFeatures, soccerGameRaw, soccerRaw, soccerId, soccerQuery, athleteId, keeperId, playId } from "./soccer-fixture";
const router: AppRouterInstance = { back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {}, bfcacheId: "soccer-ui-test" };
const render = (data = soccerData(), family = false) => renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, createElement(GameConsole, { data, query: family ? { ...soccerQuery, view: "family" } : soccerQuery })));
test("Soccer detail layers fast sideline controls into the existing score and keeps manual summaries and Basketball closed", () => {
  const html = render(); for (const label of ["Sideline scorer", "Goal", "Shot off target", "Shot saved", "Penalty goal", "Penalty saved", "Yellow card", "Second yellow / red", "Red card", "Record assist", "Record Falcons save", "Match statistics", "Play by play"]) assert.ok(html.includes(label), label);
  assert.match(html, /type="button"[^>]*>Goal/); assert.match(html, /<button[^>]*disabled=""[^>]*>Second yellow \/ red/); assert.match(html, /<button[^>]*class="soccer-play-button"[^>]*>Yellow card/); assert.doesNotMatch(html, /Courtside scorer|Basketball controls are unavailable|Record score summary|Reverse score summary|OMIT_/);
});
test("Soccer own goals and saves state the conceding side and single canonical shot meaning", () => {
  const html = render(); assert.match(html, /Own goal · External opponent scores/); assert.match(html, /The selected team concedes/); assert.match(html, /no attacking athlete goal, shot or assist/); assert.match(html, /Use this instead of Shot saved for the same opponent attempt/); assert.match(html, /Goalkeeper: #1 · Controlled keeper/); assert.match(html, /I confirm the selected team conceded this own goal/);
});
test("family Soccer shows the authorized child and safe statistics while stripping scorer, keeper and correction authority", () => {
  const html = render(soccerData({}, true), true); assert.match(html, /Half 1|Match statistics|Controlled scorer/); assert.doesNotMatch(html, /Sideline scorer|Controlled keeper|Controlled substitute|Correct a recorded soccer play|Lineups, keepers|Sealed soccer results|Record score summary|OMIT_/);
});
test("read-only authorized Soccer views expose safe aggregates and no operator controls", () => {
  const data = soccerData({ games: [{ ...soccerGameRaw, capabilities: { view_roster: true }, soccer: { ...soccerRaw, capabilities: { stats: true } } }] }); const html = render(data); assert.match(html, /Match statistics|Team totals|Play by play/); assert.doesNotMatch(html, /Sideline scorer|Start clock|Correct a recorded soccer play|Reopen for correction/);
});
test("nonoperator Soccer correctors reuse only authorized current exact-team roster identities while family remains closed", () => {
  const opponentTeam = soccerId(700), row = soccerGameRaw.roster[0];
  const data = soccerData({ games: [{ ...soccerGameRaw, opponent: { ...soccerGameRaw.opponent, team_id: opponentTeam }, capabilities: { correct: true, view_roster: true }, soccer: { ...soccerRaw, capabilities: { correct: true, stats: true } }, roster: [row, { ...row, id: keeperId, team_id: opponentTeam, display_name: "Authorized opposing keeper" }, { ...row, id: soccerId(701), team_id: soccerId(702), display_name: "OMIT_UNRELATED" }, { ...row, id: soccerId(703), revision: 2, display_name: "OMIT_STALE" }, { ...row, id: soccerId(704), active: false, display_name: "OMIT_INACTIVE" }] }] });
  const game = data.games[0]; assert.ok(game.soccer?.configured);
  assert.equal(game.soccer.entry_roster.length, 0); assert.equal(game.soccer.capabilities.operate, false);
  const entries = soccerCorrectionEntries(game, game.soccer);
  assert.deepEqual(entries.map(entry => [entry.id, entry.side]), [[athleteId, "primary"], [keeperId, "opponent"]]);
  assert.doesNotMatch(JSON.stringify(entries), /person_id|participant_id|availability|checkin_state|OMIT_/);
  assert.doesNotMatch(render(data), /Sideline scorer|Lineups, keepers and substitutions/);
  const family = soccerData({}, true).games[0]; assert.ok(family.soccer?.configured);
  assert.deepEqual(soccerCorrectionEntries(family, family.soccer), []);
});
test("format includes youth size, reentry, substitution limit and optional extra time without operational shootout", () => {
  const html = render(soccerData({ games: [{ ...soccerGameRaw, status: "pregame", engine_locked: false, soccer: { configured: false, capabilities: { configure: true } } }] })); assert.match(html, /Two halves|Four youth quarters|Two extra-time segments when needed|Players per side|Maximum substitutions|Allow a substituted athlete to reenter|Configure soccer match/); assert.match(html, /Penalty shootouts are not available/); assert.doesNotMatch(html, /Sideline scorer|Record shootout/);
});
test("server elapsed clock displays announced added time and requires explicit segment end confirmation", () => {
  const html = render(); assert.match(html, /2:30 \+2/); assert.match(html, /Server clock at 23:02:30 UTC/); assert.match(html, /Set added time|Elapsed minutes in this segment|Reason for clock correction/); assert.match(html, /I confirm this segment is complete/); assert.match(html, /Moving the clock backward makes minutes and goalkeeper participation statistics unavailable/);
  const running = render(soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, clock_running: true } }] })); assert.match(running, /Stop clock/); assert.doesNotMatch(running, /Set segment clock|End half 1/);
  const quarter = render(soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, regulation_segments: 4, segment_number: 0, segment_status: "pending", clock_ms: 0, display_clock_ms: 0, playing_ms: 0 } }] })); assert.match(quarter, /Start quarter 1/); assert.doesNotMatch(quarter, /Start half 1/);
});
test("lineup and keeper forms expose exact eligible side and enforce policy wording and dismissal exclusions", () => {
  const html = render(); assert.match(html, /2 players per side|Complete lineup required|No reentry|Maximum 3 substitutions per side/); assert.match(html, /Designate Falcons keeper|Outgoing athlete|Incoming athlete|Record Falcons substitution/); assert.doesNotMatch(html, /OMIT_OTHER_CHILD/);
  const dismissed = render(soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, lineups: [{ side: "primary", roster_ids: [keeperId], goalkeeper_roster_id: keeperId, dismissed_roster_ids: [athleteId] }] } }] })); assert.match(dismissed, /Dismissed: #7 · Controlled scorer/); const selector = dismissed.match(/<span>Athlete<\/span><select[^>]*>([\s\S]*?)<\/select>/)?.[1] ?? ""; assert.doesNotMatch(selector, new RegExp(`value="${athleteId}"`));
});
test("unavailable minutes, keeper goals allowed and clean sheets render an explicit unavailable value", () => {
  const html = render(); assert.match(html, /<dt>MIN<\/dt><dd>2.5/); assert.match(html, /<dt>GA<\/dt><dd>--/); assert.match(html, /<dt>CS<\/dt><dd>--/); assert.match(html, /never inferred from roster presence/); assert.match(html, /Shootout attempts do not affect match statistics/);
  assert.equal(soccerMinutes(null), "--"); assert.equal(soccerMinutes(0), "0"); assert.equal(soccerClock(2700500), "45:00"); assert.equal(soccerAddedTime(90), "1:30"); assert.equal(soccerSegment({ regulation_segments: 2, segment_number: 3 }), "Extra time 1");
});
test("configured feature-off Soccer retains clock and engine ownership but suppresses all sport mutations and details", () => {
  const html = render(soccerData({ features: { ...soccerFeatures, soccer_live_scoring: false } })); assert.match(html, /Half 1|2:30/); assert.doesNotMatch(html, /Sideline scorer|Match statistics|Lineups, keepers|Correct a recorded soccer play|Record score summary|Reverse score summary/);
  const final = render(soccerData({ games: [{ ...soccerGameRaw, status: "final", soccer: { ...soccerRaw, capabilities: { stats: true } } }] })); assert.match(final, /Match statistics/); assert.doesNotMatch(final, /Sideline scorer|Start clock|Record score summary/);
});
test("Soccer play-by-play disabled preserves authorized assist and correction selectors without showing the timeline", () => {
  const data = soccerData({ features: { ...soccerFeatures, soccer_play_by_play: false } }), game = data.games[0]; assert.ok(game.soccer?.configured);
  assert.equal(game.soccer.plays.length, 0); assert.deepEqual(soccerAssistContexts(game.soccer.entry_plays, 1, { side: "primary", athlete: keeperId }).map(row => row.id), [playId]);
  const html = render(data); assert.match(html, /Accepted goal to assist|Correct a recorded soccer play|#8 · Controlled scorer/); assert.doesNotMatch(html, /Play by play|Recent plays|<ol class="soccer-play-list">/);
  const family = render(soccerData({ features: { ...soccerFeatures, soccer_play_by_play: false } }, true), true); assert.doesNotMatch(family, /Accepted goal to assist|Correct a recorded soccer play|Play by play|Recent plays/);
});
test("Soccer play-by-play escapes names, distinguishes own goals and preserves correction ordering without private audit contents", () => {
  const plays = [{ ...soccerRaw.plays[0], sequence: 20, active: false }, { ...soccerRaw.plays[0], id: soccerId(600), sequence: 21, display_name: "<script>unsafe</script>" }]; const html = render(soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, plays } }] })); assert.match(html, /Superseded|&lt;script&gt;unsafe&lt;\/script&gt;/); assert.doesNotMatch(html, /<script>unsafe|OMIT_|Correction reason:|actor_person_id/); const timeline = Array.from(html.matchAll(/<ol class="soccer-play-list">([\s\S]*?)<\/ol>/g)).at(-1)?.[1] ?? ""; assert.ok(timeline.indexOf("#20") < timeline.indexOf("#21"));
});
test("Soccer assist context requires an accepted same-segment same-side goal, a distinct known scorer and one assist", () => {
  const game = soccerData().games[0]; assert.ok(game.soccer?.configured); const plays = game.soccer.plays;
  assert.deepEqual(soccerAssistContexts(plays, 1, { side: "primary", athlete: keeperId }).map(row => row.id), [playId]); assert.equal(soccerAssistContexts(plays, 1, { side: "primary", athlete: athleteId }).length, 0); assert.equal(soccerAssistContexts(plays, 2, { side: "primary", athlete: keeperId }).length, 0);
  const assist = { ...plays[0], id: soccerId(601), event_type: "assist" as const, roster_id: keeperId, scoring_event_id: playId }; assert.equal(soccerAssistContexts([...plays, assist], 1, { side: "primary", athlete: keeperId }).length, 0); assert.equal(soccerAssistContexts([...plays, assist], 1, { side: "primary", athlete: keeperId, correctingEvent: assist.id }).length, 1);
});
test("Soccer permits a known assister for an unattributed team goal while preserving goal-context isolation and deduplication", () => {
  const game = soccerData().games[0]; assert.ok(game.soccer?.configured);
  const goal = { ...game.soccer.plays[0], roster_id: null, display_name: null, jersey_number: null };
  const options = { side: "primary" as const, athlete: keeperId };
  assert.deepEqual(soccerAssistContexts([goal], 1, options).map(row => row.id), [playId]);
  assert.equal(soccerAssistContexts([{ ...goal, side: "opponent" }], 1, options).length, 0);
  assert.equal(soccerAssistContexts([{ ...goal, segment_number: 2 }], 1, options).length, 0);
  assert.equal(soccerAssistContexts([{ ...goal, active: false }], 1, options).length, 0);
  assert.equal(soccerAssistContexts([{ ...goal, event_type: "own_goal" }], 1, options).length, 0);
  const assist = { ...goal, id: soccerId(602), event_type: "assist" as const, roster_id: keeperId, scoring_event_id: playId };
  assert.equal(soccerAssistContexts([goal, assist], 1, options).length, 0);
  assert.equal(soccerAssistContexts([goal, { ...assist, active: false }], 1, options).length, 1);
  assert.equal(soccerAssistContexts([goal, assist], 1, { ...options, correctingEvent: assist.id }).length, 1);
});
