import test from "node:test";
import assert from "node:assert/strict";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { parseStatQuery, projectStats } from "../src/lib/stat-intelligence/input";
import { emptyStats } from "../src/lib/stat-intelligence/contracts";
import { StatIntelligenceHub } from "../src/components/stat-intelligence/hub";
test("finite stat filters reject forged identifiers and unsupported sports", () => {
  assert.equal(parseStatQuery({ child: "forged" }), null); assert.equal(parseStatQuery({ stats_sport: "all" }), null); assert.equal(parseStatQuery({ stats_sport: ["basketball"] }), null); assert.deepEqual(parseStatQuery({}), { sport_key: "basketball" });
});
test("pending projection discards stale totals before rendering", () => {
  const projected = projectStats({ contract: "intelligence-v1", is_current: false, refresh_pending: true, summary: { points: 999 }, segments: [{ person: "HIDDEN" }] });
  assert.ok(projected); assert.equal(projected.summary, null); const html = renderToStaticMarkup(createElement(StatIntelligenceHub, { data: projected, title: "Athlete career" })); assert.match(html, /refresh pending/); assert.doesNotMatch(html, /999|HIDDEN/);
});
test("restricted and unavailable views contain no statistical detail", () => {
  for (const state of ["restricted", "unavailable"] as const) { const html = renderToStaticMarkup(createElement(StatIntelligenceHub, { data: { ...emptyStats(), [state]: true }, title: "Statistics" })); assert.doesNotMatch(html, /Confirmed GP|Generation|<dd>/); }
});
test("measured zero, partial observation and Not tracked remain distinct", () => {
  const metric = { observed_value: 0, complete_value: 0, complete_games: 1, partial_games: 0, untracked_games: 0, legacy_unknown_games: 0, played_complete_games: 1, per_tracked_game: 0 };
  const data = projectStats({ contract: "intelligence-v1", is_current: true, refresh_pending: false, unassigned_game_count: 1, summary: { source_game_count: 2, confirmed_gp: 1, participation_unknown_games: 1, metrics: { points: metric, rebounds: { ...metric, complete_value: null, complete_games: 0, untracked_games: 2 }, assists: { ...metric, complete_value: null, observed_value: 3, partial_games: 1, complete_games: 0 } }, rates: {} }, segments: [] }); assert.ok(data);
  const html = renderToStaticMarkup(createElement(StatIntelligenceHub, { data, title: "Athlete career" })); for (const text of ["Tracked cohort total: 0", "Not tracked", "Observed: 3", "unknown participation", "unassigned / legacy"]) assert.ok(html.includes(text), text);
});
test("invalid aggregate contract cannot surface unknown payload fields", () => {
  assert.equal(projectStats({ contract: "forged", is_current: true }), null); assert.equal(projectStats({ contract: "intelligence-v1", is_current: true, refresh_pending: false, summary: {} }), null);
});
