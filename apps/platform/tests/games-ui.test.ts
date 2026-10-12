import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { GameConsole } from "../src/components/games/console";
import { GameHub } from "../src/components/games/hub";
import { calendarGameHref, currentCalendarKey, GameCard } from "../src/components/games/presentation";
import { projectGameData, parseGameQuery } from "../src/lib/games/input";
import { emptyGames } from "../src/lib/games/contracts";

const id = "00000000-0000-4000-8000-000000000001", event = "00000000-0000-4000-8000-000000000002", team = "00000000-0000-4000-8000-000000000003";
const query = parseGameQuery({ org: id, game: id, from: "2026-10-04", to: "2026-10-07" })!;
const router: AppRouterInstance = { back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {}, bfcacheId: "games-ui-test" };
const row = { id, organization_id: id, event_id: event, occurrence_key: "2026-10-04T18:00:00", occurrence_mode: "single", version: 3, status: "live", start_at: "2026-10-04T23:00:00Z", end_at: "2026-10-05T00:00:00Z", timezone: "America/Chicago", title: "Controlled Falcons game", sport_key: "basketball", sport_label: "Basketball", primary: { team_id: team, label: "Falcons", score: 10, final_score: 10 }, opponent: { team_id: null, label: "External opponent", score: 8, final_score: 8 }, home_away: "home", roster_revision: 1, capabilities: { manage: true, operate: true, finalize: true, correct: true, start: true, view_roster: true }, roster: [], history: [], operators: [], finalizations: [] };
const data = (changes: Record<string, unknown> = {}, family = false) => projectGameData({ features: { game_center: true, game_operations: true }, games: [row], ...changes }, family ? { ...query, view: "family" } : query)!;
const render = (node: ReturnType<typeof createElement>) => renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, node));
test("Game Center administrators can see the internal-matchup Calendar target requirement", () => {
  const list = { ...query, game_id: undefined };
  const html = render(createElement(GameConsole, { data: data({ capabilities: { configure: true, create: false } }), query: list }));
  assert.match(html, /include both participating teams in the Calendar event&#x27;s targets/);
  assert.doesNotMatch(html, /Open a Calendar game in Game Center/);
  const family = render(createElement(GameConsole, { data: data({ capabilities: { configure: true } }, true), query: { ...list, view: "family" } }));
  assert.doesNotMatch(family, /include both participating teams/);
});
test("assigned operator game detail shows score controls and explicit finalization confirmation", () => {
  const html = render(createElement(GameConsole, { data: data(), query })); assert.match(html, /Record score summary/); assert.match(html, /Finalize game/); assert.match(html, /<input(?=[^>]*name="confirmed")(?=[^>]*required)[^>]*>/); assert.match(html, /ordinary operations will close/); assert.match(html, /Calendar event/); assert.match(html, /Attendance and RSVP/); assert.doesNotMatch(html, /Career|Basketball shots|Live scoring engine/);
});
test("post-Start internal game projects and renders its roster, operator and four-operation history without a final seal", () => {
  const otherTeam = "00000000-0000-4000-8000-000000000004";
  const syntheticId = (n: number) => `00000000-0000-4000-8000-${n.toString().padStart(12, "0")}`;
  const postStart = {
    ...row, version: 4, home_away: "neutral", competition_type: "tournament", roster_revision: 1, finalization_count: 0,
    start_at: "2026-10-04T06:00:00+00:00", end_at: "2026-10-04T07:00:00+00:00", occurrence_key: "2026-10-04T01:00:00",
    primary: { team_id: team, label: "Falcons", score: 0, final_score: null }, opponent: { team_id: otherTeam, label: "Wildcats", score: 0, final_score: null },
    capabilities: { manage: true, roster_snapshot: false, operate: true, start: false, resume: false, finalize: true, correct: true, publish: false, view_roster: true },
    roster: [1, 2, 3].map(n => ({ id: syntheticId(10 + n), person_id: syntheticId(20 + n), participant_id: syntheticId(30 + n), team_id: n === 3 ? otherTeam : team, display_name: `Synthetic Athlete ${n}`, jersey_number: null, position_label: null, active: true, captain: false, starter: false, availability: "unknown", checkin_state: null, revision: 1 })),
    operators: [{ id: syntheticId(40), person_id: syntheticId(41), role_assignment_id: syntheticId(42), team_id: team, display_name: "Synthetic administrator", function_key: "game_administrator", status: "active", ends_at: "2026-10-04T06:25:00+00:00" }],
    history: ["game.create", "game.roster.snapshot", "game.operator.assign", "game.start"].map((operation, n) => ({ id: syntheticId(50 + n), sequence: n + 1, version: n + 1, operation, created_at: `2026-10-04T05:3${n}:00.123456+00:00`, correction_of: null, summary: ["Game linked", "Roster snapshot captured", "Operator assigned", "Game started"][n] })),
    finalizations: [],
  };
  const projected = data({ games: [postStart] });
  assert.equal(projected.games[0].status, "live"); assert.equal(projected.games[0].version, 4);
  assert.equal(projected.games[0].roster.length, 3); assert.equal(projected.games[0].operators.length, 1);
  assert.deepEqual(projected.games[0].history.map(operation => operation.sequence), [1, 2, 3, 4]);
  assert.equal(projected.games[0].primary.final_score, null); assert.equal(projected.games[0].opponent.final_score, null);
  assert.deepEqual(projected.games[0].finalizations, []);
  const html = render(createElement(GameConsole, { data: projected, query }));
  for (const expected of ["Neutral site", "Wildcats", "Synthetic Athlete 3", "Game started", "End assignment for Synthetic administrator", "Update game status", "Record score summary", "Finalize game", "Calendar event", "Attendance and RSVP"]) assert.ok(html.includes(expected), expected);
  assert.doesNotMatch(html, /Start Game|Refresh roster snapshot|Snapshot game roster|Reverse score summary|Sealed final results|Reopen for correction/);
});
test("game start requires a labeled review confirmation and snapshot context", () => {
  const html = render(createElement(GameConsole, { data: data({ games: [{ ...row, status: "scheduled", capabilities: { ...row.capabilities, roster_snapshot: true } }] }), query })); assert.match(html, /Start Game/); assert.match(html, /reviewed the matchup and roster snapshot/); assert.match(html, /Refresh roster snapshot/); assert.doesNotMatch(html, /Record score summary|Finalize game/);
});
test("scorekeeper UI cannot finalize, reopen, publish, assign or view another private roster", () => {
  const html = render(createElement(GameConsole, { data: data({ games: [{ ...row, capabilities: { operate: true } }] }), query })); assert.match(html, /Record score summary/); assert.doesNotMatch(html, /Finalize game|Reopen for correction|Game operator assignments|Publish game summary|Game roster/);
});
test("family view exposes matchup and safe result without any operating or administrative controls", () => {
  const html = render(createElement(GameConsole, { data: data({}, true), query: { ...query, view: "family" } })); assert.match(html, /Falcons/); assert.match(html, /External opponent/); assert.doesNotMatch(html, /Game controls|Record score|Finalize game|Reopen for correction|Game operator assignments|Game history/);
});
test("disabled operation feature and final lifecycle close ordinary live controls", () => {
  const disabled = render(createElement(GameConsole, { data: data({ features: { game_center: true, game_operations: false } }), query })); assert.doesNotMatch(disabled, /Record score summary|Finalize game|Start Game|Assign game operator/);
  const final = render(createElement(GameConsole, { data: data({ games: [{ ...row, status: "final", finalization_count: 1 }] }), query })); assert.match(final, /Falcons wins/); assert.match(final, /Reopen for correction/); assert.match(final, /Reason for reopening/); assert.doesNotMatch(final, /Record score summary|Start Game|Finalize game/);
});
test("disabled and inaccessible Game Center display distinct safe messages", () => {
  const disabled = render(createElement(GameConsole, { data: emptyGames(query), query })); assert.match(disabled, /not enabled/); assert.doesNotMatch(disabled, /Game controls/);
  const restricted = render(createElement(GameConsole, { data: emptyGames(query, false, true), query })); assert.match(restricted, /restricted in this context/); assert.doesNotMatch(restricted, /temporarily unavailable/);
  const unavailable = render(createElement(GameConsole, { data: emptyGames(query, true), query })); assert.match(unavailable, /temporarily unavailable/);
});
test("Calendar links follow one-time schedule changes while recurring links retain original key", () => {
  const game = data().games[0], moved = { ...game, start_at: "2026-10-05T23:30:00Z" };
  assert.equal(currentCalendarKey(moved), "2026-10-05T18:30:00"); assert.match(calendarGameHref(moved), /occurrence=2026-10-05T18%3A30%3A00/); assert.match(calendarGameHref(moved), /date=2026-10-05/);
  assert.equal(currentCalendarKey({ ...moved, occurrence_mode: "recurring" }), game.occurrence_key);
});
test("Game Center list and family integration use authorized identity links and escaped labels", () => {
  const safe = data({ games: [{ ...row, title: '<img src=x onerror="unsafe()">' }] }).games[0];
  const html = render(createElement(GameCard, { game: safe })); assert.match(html, /&lt;img/); assert.doesNotMatch(html, /<img/); assert.match(html, new RegExp(`game=${id}`));
  const hub = render(createElement(GameHub, { family: true, data: data({}, true), query: { ...query, view: "family" } })); assert.match(hub, /Family games/); assert.match(hub, /view=family/); assert.doesNotMatch(hub, /Record score|Finalize game/);
});
test("operator choices retain both exact teams for the same organization role assignment", () => {
  const other = "00000000-0000-4000-8000-000000000004";
  const candidates = [team, other].map(team_id => ({ person_id: id, role_assignment_id: event, team_id, display_name: "Controlled administrator", functions: ["game_administrator"] }));
  const html = render(createElement(GameConsole, { data: data({ operator_candidates: candidates }), query }));
  for (const teamId of [team, other]) assert.match(html, new RegExp(`value="${event}:${teamId}"`));
  assert.match(html, /Assignment ends \(your device timezone\)/);
});
test("elevated correction can reverse an eligible score without pretending to be an assigned scorer", () => {
  const game = { ...row, capabilities: { correct: true }, history: [{ id: event, sequence: 3, version: 3, operation: "game.score.set", created_at: "2026-10-04T23:05:00Z", summary: "Score 0:0 to 10:8" }] };
  const html = render(createElement(GameConsole, { data: data({ games: [game] }), query })); assert.match(html, /Reverse score summary/); assert.match(html, /Score 0:0 to 10:8/); assert.doesNotMatch(html, /Record score summary|Assign game operator|Finalize game/);
});
test("a started delayed game can resume while its roster stays sealed", () => {
  const delayed = { ...row, status: "delayed", capabilities: { manage: true, operate: true, resume: true, roster_snapshot: false, start: false } };
  const html = render(createElement(GameConsole, { data: data({ games: [delayed] }), query }));
  const transitions = html.match(/<select name="status" required="">([\s\S]*?)<\/select>/)?.[1] ?? "";
  assert.match(transitions, /<option value="live">Live<\/option>/); assert.doesNotMatch(transitions, /<option value="pregame">/); assert.doesNotMatch(html, /Start Game|Refresh roster snapshot|Snapshot game roster/);
  const family = render(createElement(GameConsole, { data: data({ games: [delayed] }, true), query: { ...query, view: "family" } }));
  assert.doesNotMatch(family, /Update game status|Game controls/);
});
test("a pre-start delay keeps explicit start and never offers a lifecycle shortcut to live", () => {
  const delayed = { ...row, status: "delayed", capabilities: { manage: true, operate: true, resume: false, roster_snapshot: true, start: true } };
  const html = render(createElement(GameConsole, { data: data({ games: [delayed] }), query }));
  const transitions = html.match(/<select name="status" required="">([\s\S]*?)<\/select>/)?.[1] ?? "";
  assert.match(html, /Start Game/); assert.match(html, /Refresh roster snapshot/); assert.match(transitions, /<option value="pregame">Pregame<\/option>/); assert.doesNotMatch(transitions, /<option value="live">/);
});
test("only current administrators receive finite Game Center settings, including before enablement", () => {
  const settings = { organization_id: id, configuration_version: 3, features: { game_center: false }, capabilities: { configure: true } };
  const html = render(createElement(GameConsole, { data: data(settings), query }));
  assert.match(html, /Game Center settings/); assert.match(html, /Save Game Center settings/); assert.match(html, /Head coach game management/); assert.match(html, /not enabled/); assert.doesNotMatch(html, /name="(?:stats|livestream|live_scoring)"/);
  const family = render(createElement(GameConsole, { data: data(settings, true), query: { ...query, view: "family" } }));
  assert.doesNotMatch(family, /Save Game Center settings|Head coach game management/);
  const missing = render(createElement(GameConsole, { data: data({ ...settings, configuration_version: 0 }), query }));
  assert.match(missing, /Activate Sports/); assert.doesNotMatch(missing, /Save Game Center settings/);
});

test("family game Attendance link preserves selected child across module navigation", () => {
  const child = "00000000-0000-4000-8000-000000000005";
  const html = render(createElement(GameConsole, { data: data({}, true), query: { ...query, view: "family", child_person_id: child } }));
  const href = html.match(/href="([^"]+)"[^>]*>Attendance and RSVP<\/a>/)?.[1];
  assert.ok(href);
  const url = new URL(href.replaceAll("&amp;", "&"), "https://boss.example");
  assert.equal(url.pathname, "/app/attendance");
  assert.equal(url.searchParams.get("child"), child);
  assert.equal(url.searchParams.get("view"), "family");
  assert.equal(url.searchParams.get("event"), event);
  assert.equal(url.searchParams.has("from"), false);
  assert.equal(url.searchParams.has("to"), false);
});

test("historical rescheduled game Attendance link resolves its exact occurrence instead of the list range", () => {
  const moved = { ...row, start_at: "2025-01-05T23:30:00Z", end_at: "2025-01-06T00:30:00Z" };
  const html = render(createElement(GameConsole, { data: data({ games: [moved] }), query }));
  const href = html.match(/href="([^"]+)"[^>]*>Attendance and RSVP<\/a>/)?.[1];
  assert.ok(href);
  const url = new URL(href.replaceAll("&amp;", "&"), "https://boss.example");
  assert.equal(url.searchParams.get("occurrence"), "2025-01-05T17:30:00");
  assert.equal(url.searchParams.has("from"), false);
  assert.equal(url.searchParams.has("to"), false);
});

test("score reversal selects only the latest eligible update and respects reversal and final boundaries", () => {
  const latestId = "00000000-0000-4000-8000-000000000006";
  const history = [
    { id: event, sequence: 3, version: 3, operation: "game.score.set", created_at: "2026-10-04T23:05:00Z", summary: "Older score" },
    { id: latestId, sequence: 4, version: 4, operation: "game.score.set", created_at: "2026-10-04T23:06:00Z", summary: "Latest score" },
  ];
  const html = render(createElement(GameConsole, { data: data({ games: [{ ...row, capabilities: { correct: true }, history }] }), query }));
  const options = html.match(/<select name="operation_id" required="">([\s\S]*?)<\/select>/)?.[1] ?? "";
  assert.match(options, new RegExp(`value="${latestId}"`));
  assert.doesNotMatch(options, new RegExp(`value="${event}"`));
  for (const operation of ["game.score.reverse", "game.finalize", "game.reopen"]) {
    const closed = render(createElement(GameConsole, { data: data({ games: [{ ...row, capabilities: { correct: true }, history: [...history, { ...history[1], sequence: 5, operation }] }] }), query }));
    assert.doesNotMatch(closed, /Reverse score summary/);
  }
});
