import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { GameConsole } from "../src/components/games/console";
import { basketballAssistContexts, basketballClock, basketballPeriod, shootingPercentage } from "../src/lib/basketball/presentation";
import { basketballData, basketballGameRaw, basketballRaw, basketballQuery, basketballFeatures, basketballId } from "./basketball-fixture";

const router: AppRouterInstance = { back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {}, bfcacheId: "basketball-ui-test" };
const render = (data = basketballData(), family = false) => renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, createElement(GameConsole, { data, query: family ? { ...basketballQuery, view: "family" } : basketballQuery })));
test("basketball detail offers fast typed shot buttons and keeps the canonical score path closed", () => {
  const html = render(); for (const label of ["Courtside scorer", "Recent plays", "Made 2", "Made 3", "Made free throw", "Missed 2", "Personal foul", "Record assist", "Start clock", "Box score", "Play by play", "Quarter 1 fouls: Falcons 1"]) assert.ok(html.includes(label), label);
  assert.doesNotMatch(html, /Record score summary|Reverse score summary|OMIT_|Absence reason/); assert.match(html, /type="button"[^>]*>Made 2/); assert.match(html, /Server clock at 23:01:41 UTC/);
});
test("court athlete selection uses only the exact entry roster while team scoring stays explicitly unattributed", () => {
  const html = render(); assert.match(html, /#7 · Controlled athlete/); assert.match(html, /Team \/ unattributed/); assert.doesNotMatch(html, /OMIT_OTHER_CHILD|OMIT_JERSEY/); assert.match(html, /<button[^>]*disabled=""[^>]*>Steal/); assert.match(html, /<button[^>]*disabled=""[^>]*>Record assist/);
});
test("family basketball offers safe score, period and child statistics without any scorer or correction controls", () => {
  const html = render(basketballData({}, true), true); assert.match(html, /Quarter 1|Box score|Controlled athlete/); assert.doesNotMatch(html, /Courtside scorer|Start clock|Correct a recorded play|Lineups and substitutions|Sealed basketball results|Record score summary|OMIT_/);
});
test("coach view remains read only with safe aggregate and authorized athlete statistics", () => {
  const game = { ...basketballGameRaw, capabilities: { view_roster: true }, basketball: { ...basketballRaw, capabilities: { stats: true } } };
  const html = render(basketballData({ games: [game] })); assert.match(html, /Box score|Play by play|Team totals/); assert.doesNotMatch(html, /Courtside scorer|Start clock|Correct a recorded play|Reopen for correction/);
});
test("closed or disabled basketball leaves no manual-score escape and preserves safe engine summary", () => {
  const disabled = render(basketballData({ features: { ...basketballFeatures, basketball_live_scoring: false } })); assert.match(disabled, /Quarter 1/); assert.doesNotMatch(disabled, /Courtside scorer|Box score|Record score summary|Reverse score summary/);
  const final = render(basketballData({ games: [{ ...basketballGameRaw, status: "final", basketball: { ...basketballRaw, capabilities: { stats: true } } }] })); assert.doesNotMatch(final, /Courtside scorer|Start clock|Record score summary/); assert.match(final, /Box score/);
});
test("configuration renders explicit quarter or half format and bounded partial-lineup policy before activation", () => {
  const html = render(basketballData({ games: [{ ...basketballGameRaw, status: "pregame", basketball: { configured: false, capabilities: { configure: true } }, engine_locked: false }] }));
  assert.match(html, /Four quarters|Two halves|Maximum tracked players on court|Require a complete configured lineup|Configure basketball game/); assert.doesNotMatch(html, /Courtside scorer|Possession|Timeout limit/);
});
test("period and clock controls require explicit end confirmation while live plays close outside an active period", () => {
  const live = render(); assert.match(live, /I confirm this period is complete/); assert.match(live, /Reason for clock setting/);
  const pending = render(basketballData({ games: [{ ...basketballGameRaw, basketball: { ...basketballRaw, period_number: 0, period_status: "pending", clock_ms: 480000 } }] })); assert.match(pending, /Start quarter 1/); assert.match(pending, /<fieldset[^>]*disabled/); assert.doesNotMatch(pending, /End quarter 1/);
  const running = render(basketballData({ games: [{ ...basketballGameRaw, basketball: { ...basketballRaw, clock_running: true } }] })); assert.match(running, /Stop clock/); assert.doesNotMatch(running, /Set period clock|End quarter 1/);
});
test("safe play-by-play escapes names and preserves chronological corrections without reasons or audit material", () => {
  const corrected = { ...basketballRaw, plays: [{ ...basketballRaw.plays[0], sequence: 11, active: false }, { ...basketballRaw.plays[0], id: "00000000-0000-4000-8000-000000000099", sequence: 12, display_name: "<script>unsafe</script>" }] };
  const html = render(basketballData({ games: [{ ...basketballGameRaw, basketball: corrected }] })); assert.match(html, /Superseded/); assert.match(html, /&lt;script&gt;unsafe&lt;\/script&gt;/); assert.doesNotMatch(html, /<script>unsafe|OMIT_REASON|OMIT_REQUEST/); const plays = Array.from(html.matchAll(/<ol class="basketball-play-list">([\s\S]*?)<\/ol>/g)).at(-1)?.[1] ?? ""; assert.ok(plays.indexOf("#11") < plays.indexOf("#12"));
});
test("shooting percentages and clock/period labels derive display values without inventing incomplete stats", () => {
  assert.equal(shootingPercentage(0, 0), "--"); assert.equal(shootingPercentage(2, 3), "66.7%"); assert.equal(basketballClock(379000), "6:19"); assert.equal(basketballClock(999), "0:01"); assert.equal(basketballPeriod({ regulation_periods: 2, period_number: 2 }), "Half 2"); assert.equal(basketballPeriod({ regulation_periods: 4, period_number: 5 }), "Overtime 1");
  const html = render(); assert.match(html, /66.7%/); assert.match(html, /Minutes and plus-minus are not published/);
});
test("assist contexts match the selected period, authorized side and distinct shooter without duplicating an existing assist", () => {
  const old = { ...basketballRaw.plays[0], id: basketballId(60), period_number: 1 }, current = { ...basketballRaw.plays[0], id: basketballId(61), period_number: 2 }, sameAthlete = { ...current, id: basketballId(62), roster_id: basketballId(63) };
  const game = basketballData({ games: [{ ...basketballGameRaw, basketball: { ...basketballRaw, period_number: 2, entry_roster: [...basketballRaw.entry_roster, { id: basketballId(63), side: "primary", display_name: "Second controlled athlete", jersey_number: "8", active: true }], plays: [old, current, sameAthlete, { ...current, id: basketballId(64), event_type: "made_ft" }, { ...current, id: basketballId(65), side: "opponent" }, { ...current, id: basketballId(66), roster_id: null }] } }] }).games[0];
  assert.ok(game.basketball?.configured);
  const plays = game.basketball.plays;
  assert.deepEqual(basketballAssistContexts(plays, 2, { side: "primary", athlete: basketballId(63) }).map(row => row.id), [basketballId(61)]);
  const currentShot = plays.find(row => row.id === basketballId(61))!;
  const assist = { ...currentShot, id: basketballId(67), event_type: "assist" as const, scoring_event_id: currentShot.id, roster_id: basketballId(63), points: 0 };
  assert.equal(basketballAssistContexts([...plays, assist], 2, { side: "primary", athlete: basketballId(63) }).length, 0);
  assert.deepEqual(basketballAssistContexts([...plays, assist], 2, { side: "primary", athlete: basketballId(63), correctingEvent: assist.id }).map(row => row.id), [currentShot.id]);
  const html = render(basketballData({ games: [{ ...basketballGameRaw, basketball: { ...basketballRaw, period_number: 2, plays: [old, current] } }] }));
  const selector = html.match(/<span>Made field goal to assist<\/span><select[^>]*>([\s\S]*?)<\/select>/)?.[1] ?? "";
  assert.match(selector, new RegExp(`value="${current.id}"`)); assert.doesNotMatch(selector, new RegExp(`value="${old.id}"`));
});
