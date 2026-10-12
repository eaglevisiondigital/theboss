import assert from "node:assert/strict";
import test from "node:test";
import { basketballPlayTypes } from "../src/lib/basketball/contracts";
import { gameConsoleKey, parseGameCommand, parseGameQuery } from "../src/lib/games/input";
import type { GameCommand } from "../src/lib/games/contracts";
import { BasketballIntent } from "../src/lib/basketball/intent";
import { basketballData, basketballFeatures, basketballGameRaw, basketballId, basketballRaw, gameId, athleteId, playId } from "./basketball-fixture";

const base = { game_id: gameId, expected_version: 10 };
const shot = { operation: "basketball.event.add" as const, input: { ...base, event_type: "made_2", side: "primary", roster_id: athleteId } };
test("basketball commands whitelist typed event meaning and cannot accept points or authority overrides", () => {
  for (const type of basketballPlayTypes) assert.ok(parseGameCommand({ ...shot, input: { ...shot.input, event_type: type, ...(type === "assist" ? { scoring_event_id: playId } : {}) } }));
  for (const fields of [{ points: 3 }, { actor_person_id: athleteId }, { organization_id: gameId }, { sport_key: "basketball" }, { clock_ms: 3000 }, { event_type: "technical_foul" }, { event_type: "touchdown" }, { side: "other" }, { expected_version: 0 }, { roster_id: "known-id" }, { scoring_event_id: playId }, { roster_id: null }]) assert.equal(parseGameCommand({ ...shot, input: { ...shot.input, ...fields } }), null);
  assert.equal(parseGameCommand({ ...shot, operation: "basketball.stats.set" }), null);
});
test("unattributed events omit roster identifiers while athlete-only plays require an exact snapshot ID", () => {
  for (const event_type of ["made_2", "made_3", "made_ft", "missed_2", "missed_3", "missed_ft", "offensive_rebound", "defensive_rebound", "turnover"]) assert.ok(parseGameCommand({ operation: shot.operation, input: { ...base, side: "opponent", event_type } }));
  for (const event_type of ["assist", "steal", "block", "personal_foul"]) assert.equal(parseGameCommand({ operation: shot.operation, input: { ...base, side: "primary", event_type } }), null);
  for (const scoring_event_id of [undefined, null, "known-id"]) assert.equal(parseGameCommand({ ...shot, input: { ...shot.input, event_type: "assist", scoring_event_id } }), null);
});
test("basketball format, period clock and lineup inputs are finite, versioned and bounded", () => {
  const configure = { operation: "basketball.configure", input: { ...base, regulation_periods: 4, period_seconds: 480, overtime_seconds: 240, lineup_size: 5, enforce_lineup: true } };
  assert.ok(parseGameCommand(configure));
  for (const fields of [{ regulation_periods: 3 }, { regulation_periods: "4" }, { period_seconds: 59 }, { period_seconds: 3601 }, { overtime_seconds: 1801 }, { lineup_size: 6 }, { enforce_lineup: "true" }, { possession: "primary" }, { timeout_limit: 5 }]) assert.equal(parseGameCommand({ ...configure, input: { ...configure.input, ...fields } }), null);
  assert.ok(parseGameCommand({ operation: "basketball.clock.set", input: { ...base, clock_ms: 37000, reason: "Controlled clock correction" } }));
  for (const fields of [{ clock_ms: -1 }, { clock_ms: 1.5 }, { clock_ms: 3600001 }, { reason: " " }, { reason: "x".repeat(501) }, { reason: "unsafe\u0000text" }]) assert.equal(parseGameCommand({ operation: "basketball.clock.set", input: { ...base, clock_ms: 37000, reason: "Reviewed correction", ...fields } }), null);
  assert.ok(parseGameCommand({ operation: "basketball.lineup.set", input: { ...base, side: "primary", roster_ids: [athleteId] } }));
  for (const roster_ids of [[athleteId, athleteId], ["known-id"], Array.from({ length: 6 }, (_, n) => basketballId(n + 30)), null]) assert.equal(parseGameCommand({ operation: "basketball.lineup.set", input: { ...base, side: "primary", roster_ids } }), null);
  assert.equal(parseGameCommand({ operation: "basketball.substitute", input: { ...base, side: "primary", out_roster_id: athleteId, in_roster_id: athleteId } }), null);
});
test("correction and reversal retain exact event references and a bounded reason", () => {
  assert.ok(parseGameCommand({ operation: "basketball.event.correct", input: { ...shot.input, event_id: playId, reason: "Correct shot value" } }));
  assert.ok(parseGameCommand({ operation: "basketball.event.reverse", input: { ...base, event_id: playId, reason: "Duplicate controlled play" } }));
  for (const fields of [{ event_id: "known-id" }, { reason: "" }, { override_final: true }, { delete_original: true }]) assert.equal(parseGameCommand({ operation: "basketball.event.reverse", input: { ...base, event_id: playId, reason: "Reviewed reversal", ...fields } }), null);
});
test("entry and statistics projection whitelists minimal authorized athletes without private profile or audit values", () => {
  const game = basketballData().games[0]; assert.ok(game.basketball?.configured);
  assert.equal(game.basketball.entry_roster.length, 1); assert.equal(game.basketball.players.length, 1); assert.equal(game.basketball.players[0].points, 5); assert.equal(game.basketball.plays[1].display_name, null); assert.equal(game.basketball.plays[1].roster_id, null);
  assert.doesNotMatch(JSON.stringify(game.basketball), /OMIT_|absence_reason|checkin_state|person_id|request_id|correction_of|reason/);
});
test("exact operator entry IDs authorize minimal player stats even without private core roster permission", () => {
  const game = basketballData({ games: [{ ...basketballGameRaw, roster: [], capabilities: { operate: true, view_roster: false } }] }).games[0]; assert.ok(game.basketball?.configured);
  assert.equal(game.roster.length, 0); assert.equal(game.basketball.players.length, 1); assert.equal(game.basketball.players[0].roster_id, athleteId);
});
test("family projection strips entry, lineup, internal correction and sealed epoch authority and intersects children", () => {
  const data = basketballData({}, true), game = data.games[0]; assert.ok(game.basketball?.configured);
  assert.equal(game.basketball.capabilities.operate, false); assert.equal(game.basketball.capabilities.correct, false); assert.equal(game.basketball.entry_roster.length, 0); assert.equal(game.basketball.lineups.length, 0); assert.equal(game.basketball.final_epochs.length, 0); assert.equal(game.basketball.players.length, 1);
  const none = basketballData({ games: [{ ...basketballGameRaw, roster: [], capabilities: { view_roster: false }, basketball: basketballRaw }] }, true).games[0]; assert.ok(none.basketball?.configured); assert.equal(none.basketball.players.length, 0); assert.ok(none.basketball.plays.every(play => play.display_name === null && play.roster_id === null));
  assert.doesNotMatch(JSON.stringify(data), /OMIT_|OMIT_OTHER_CHILD/);
});
test("wrong-sport and malformed engine projections close basketball without losing the core game or unlocking manual scores", () => {
  const wrong = basketballData({ games: [{ ...basketballGameRaw, sport_key: "soccer" }] }).games[0]; assert.equal(wrong.basketball, null);
  for (const fields of [{ engine_version: "unknown" }, { period_status: "unknown" }, { clock_ms: -1 }, { clock_observed_at: "2026-02-30T01:00:00Z" }, { regulation_periods: "4" }]) { const game = basketballData({ games: [{ ...basketballGameRaw, basketball: { ...basketballRaw, ...fields } }] }).games[0]; assert.equal(game.basketball, null); assert.equal(game.engine_locked, true); }
});
test("finite basketball flags close retained controls and detailed views while the configured engine remains locked", () => {
  for (const flag of ["basketball_live_scoring", "basketball_stats", "game_operations"]) { const game = basketballData({ features: { ...basketballFeatures, [flag]: false } }).games[0]; assert.ok(game.basketball?.configured); assert.equal(game.basketball.capabilities.operate, false); assert.equal(game.basketball.capabilities.correct, false); assert.equal(game.engine_locked, true); }
  const disabled = basketballData({ features: { ...basketballFeatures, basketball_live_scoring: false } }).games[0]; assert.ok(disabled.basketball?.configured); assert.equal(disabled.basketball.players.length, 0); assert.equal(disabled.basketball.plays.length, 0);
});
test("bounded play and stat projections exclude malformed counters and historical plays from ordinary viewers", () => {
  const game = basketballData({ games: [{ ...basketballGameRaw, basketball: { ...basketballRaw, capabilities: { stats: true }, players: [{ ...basketballRaw.players[0], fga: -1 }], plays: [{ ...basketballRaw.plays[0], active: false }] } }] }).games[0]; assert.ok(game.basketball?.configured); assert.equal(game.basketball.players.length, 0); assert.equal(game.basketball.plays.length, 0);
  const large = basketballData({ games: [{ ...basketballGameRaw, basketball: { ...basketballRaw, plays: Array.from({ length: 501 }, () => basketballRaw.plays[0]) } }] }).games[0]; assert.ok(large.basketball?.configured); assert.equal(large.basketball.plays.length, 0);
});
function saved(version = 11, game_id = gameId) { return new Response(JSON.stringify({ ok: true, result: { game_id, version, replayed: false, message: "Saved.", private: "OMIT_PRIVATE" } }), { status: 200 }); }
test("a synchronous double tap emits one request and waits for the acknowledged server version", async () => {
  const intent = new BasketballIntent(() => basketballId(50)), calls: RequestInit[] = [];
  let finish!: (value: Response) => void;
  const first = intent.execute(shot, async (_url, init) => { calls.push(init!); return new Promise(resolve => { finish = resolve; }); });
  assert.equal((await intent.execute(shot, async () => saved())).kind, "busy"); assert.equal(calls.length, 1); finish(saved()); assert.equal((await first).kind, "saved"); assert.equal(intent.waitingFor(10), true); assert.equal(intent.waitingFor(11), false);
  assert.equal((await intent.execute(shot, async () => { throw new Error("Must not send stale version"); })).kind, "refresh");
  const body = JSON.parse(String(calls[0].body)); assert.equal(body.request_id, basketballId(50)); assert.equal(calls[0].credentials, "same-origin"); assert.equal(calls[0].cache, "no-store");
});
test("unknown outcomes retry the same request but the next confirmed identical play creates a new intent", async () => {
  let sequence = 50; const intent = new BasketballIntent(() => basketballId(sequence++)), requests: string[] = [];
  const transport = async (_url: RequestInfo | URL, init?: RequestInit) => { requests.push(JSON.parse(String(init?.body)).request_id); return requests.length === 1 ? new Response("bad upstream", { status: 503 }) : saved(requests.length === 2 ? 11 : 12); };
  assert.equal((await intent.execute(shot, transport)).kind, "unknown"); assert.equal((await intent.retryUnconfirmed(transport)).kind, "saved"); assert.equal(requests[0], requests[1]);
  assert.equal((await intent.execute({ ...shot, input: { ...shot.input, expected_version: 11 } }, transport)).kind, "saved"); assert.notEqual(requests[2], requests[1]);
});
test("transport denial, stale authority and mismatched resource results remain safe and unconfirmed", async () => {
  for (const [status, kind] of [[403, "denied"], [401, "denied"], [409, "refresh"], [422, "invalid"]] as const) { const result = await new BasketballIntent().execute(shot, async () => new Response(JSON.stringify({ ok: false, detail: "OMIT_PRIVATE" }), { status })); assert.equal(result.kind, kind); assert.doesNotMatch(result.message, /OMIT_PRIVATE/); }
  assert.equal((await new BasketballIntent().execute(shot, async () => saved(11, basketballId(99)))).kind, "unknown");
});
test("committed response loss followed by refreshed game data replays the immutable original intent before any new play", async () => {
  let sequence = 70, accepted = 0; const intent = new BasketballIntent(() => basketballId(sequence++)), requests: { request_id: string; command: typeof shot }[] = [], receipts = new Set<string>();
  const transport = async (_url: RequestInfo | URL, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body)) as typeof requests[number]; requests.push(body);
    if (!receipts.has(body.request_id)) { receipts.add(body.request_id); accepted++; }
    if (requests.length === 1) throw new Error("Controlled response loss after commit");
    return saved(10 + accepted);
  };
  const mutableShot = { ...shot, input: { ...shot.input } };
  assert.equal((await intent.execute(mutableShot, transport)).kind, "unknown"); assert.equal(accepted, 1); assert.equal(intent.hasUnconfirmed(), true);
  mutableShot.input.expected_version = 11;
  assert.equal((await intent.execute(mutableShot, transport)).kind, "unknown"); assert.equal(requests.length, 1);
  assert.equal((await intent.execute({ ...shot, input: { ...shot.input, event_type: "made_3", expected_version: 11 } }, transport)).kind, "unknown"); assert.equal(requests.length, 1);
  assert.equal((await intent.retryUnconfirmed(transport)).kind, "saved"); assert.deepEqual(requests[1], requests[0]); assert.equal(requests[1].command.input.expected_version, 10); assert.equal(accepted, 1); assert.equal(intent.hasUnconfirmed(), false);
  assert.equal((await intent.execute(mutableShot, transport)).kind, "saved"); assert.equal(accepted, 2); assert.notEqual(requests[2].request_id, requests[1].request_id);
});
test("definitive denial of an unconfirmed replay clears its local intent without authorizing another caller", async () => {
  const intent = new BasketballIntent();
  assert.equal((await intent.execute(shot, async () => { throw new Error("Controlled response loss"); })).kind, "unknown");
  assert.equal((await intent.retryUnconfirmed(async () => new Response(JSON.stringify({ ok: false }), { status: 403 }))).kind, "denied"); assert.equal(intent.hasUnconfirmed(), false);
});
test("basketball form recovery keeps original corrections, substitutions and controls after version-keyed form remounts", async () => {
  const commands: GameCommand[] = [
    { operation: "basketball.event.correct", input: { ...shot.input, event_id: playId, reason: "Correct the controlled shot" } },
    { operation: "basketball.substitute", input: { ...base, side: "primary", out_roster_id: athleteId, in_roster_id: basketballId(90) } },
    { operation: "basketball.clock.set", input: { ...base, clock_ms: 120000, reason: "Controlled clock correction" } },
    { operation: "basketball.period.end", input: base },
    { operation: "basketball.configure", input: { ...base, regulation_periods: 4, period_seconds: 480, overtime_seconds: 240, lineup_size: 5, enforce_lineup: false } },
  ];
  for (const command of commands) {
    const intent = new BasketballIntent(), requests: string[] = [];
    const transport = async (_url: RequestInfo | URL, init?: RequestInit) => { requests.push(String(init?.body)); if (requests.length === 1) throw new Error("Controlled response lost after commit"); return saved(11); };
    assert.equal((await intent.execute(command, transport)).kind, "unknown");
    const remountedCommand = { ...command, input: { ...command.input, expected_version: 11 } };
    assert.equal((await intent.execute(remountedCommand, transport)).kind, "unknown"); assert.equal(requests.length, 1);
    assert.equal((await intent.retryUnconfirmed(transport)).kind, "saved"); assert.equal(requests[0], requests[1]); assert.equal(JSON.parse(requests[1]).command.input.expected_version, 10);
  }
});
test("canonical game refresh preserves the page context key when default dates advance, while explicit navigation resets it", () => {
  const params = { org: basketballId(2), game: gameId }, before = parseGameQuery(params, new Date("2026-10-04T18:00:00Z"))!, after = parseGameQuery(params, new Date("2026-10-04T18:00:20Z"))!;
  assert.notEqual(before.from, after.from); assert.equal(gameConsoleKey(before, params), gameConsoleKey(after, params));
  assert.notEqual(gameConsoleKey(before, params), gameConsoleKey({ ...before, game_id: basketballId(99) }, params));
  assert.notEqual(gameConsoleKey(before, params), gameConsoleKey({ ...before, view: "family" }, params));
  assert.notEqual(gameConsoleKey(before, params), gameConsoleKey({ ...before, from: "2026-10-01T00:00:00.000Z" }, { ...params, from: "2026-10-01" }));
});
