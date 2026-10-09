import assert from "node:assert/strict";
import test from "node:test";
import type { GameCommand } from "../src/lib/games/contracts";
import { parseGameCommand } from "../src/lib/games/input";
import { GameIntent } from "../src/lib/games/intent";
import { BasketballIntent } from "../src/lib/basketball/intent";
import { SoccerIntent } from "../src/lib/soccer/intent";
import { soccerPlayTypes } from "../src/lib/soccer/contracts";
import { soccerSaveCommand } from "../src/lib/soccer/presentation";
import { soccerData, soccerFeatures, soccerGameRaw, soccerRaw, soccerId, gameId, athleteId, keeperId, substituteId, playId } from "./soccer-fixture";

const base = { game_id: gameId, expected_version: 10 }, goal: GameCommand = { operation: "soccer.event.add", input: { ...base, side: "primary", event_type: "goal", roster_id: athleteId } };
test("soccer outcomes are finite and cannot submit goals, statistics, sport or authority overrides", () => {
  for (const event_type of soccerPlayTypes) assert.ok(parseGameCommand({ ...goal, input: { ...goal.input, event_type, ...(event_type === "assist" ? { scoring_event_id: playId } : {}) } }), event_type);
  for (const fields of [{ goals: 1 }, { points: 1 }, { actor_person_id: athleteId }, { sport_key: "soccer" }, { team_id: gameId }, { clock_ms: 1000 }, { event_type: "save" }, { event_type: "shootout_goal" }, { event_type: "made_2" }, { side: "other" }, { roster_id: null }, { roster_id: "known-id" }, { expected_version: 0 }]) assert.equal(parseGameCommand({ ...goal, input: { ...goal.input, ...fields } }), null);
  assert.equal(parseGameCommand({ ...goal, operation: "soccer.stats.set" }), null);
});
test("saved shots have one attacking outcome and only their optional defending keeper while assists and second yellows require an athlete", () => {
  const save = soccerSaveCommand(gameId, 10, "primary", keeperId); assert.ok(parseGameCommand(save)); assert.equal(save.input.side, "opponent"); assert.equal(save.input.event_type, "shot_saved"); assert.equal(save.input.goalkeeper_roster_id, keeperId); assert.equal(save.input.roster_id, undefined);
  assert.ok(parseGameCommand(soccerSaveCommand(gameId, 10, "opponent"))); assert.equal("goalkeeper_roster_id" in soccerSaveCommand(gameId, 10, "opponent").input, false);
  for (const event_type of ["assist", "second_yellow"]) assert.equal(parseGameCommand({ ...goal, input: { ...base, side: "primary", event_type } }), null);
  for (const event_type of ["yellow_card", "red_card", "foul"]) assert.ok(parseGameCommand({ ...goal, input: { ...base, side: "opponent", event_type } }));
  for (const fields of [{ goalkeeper_roster_id: keeperId }, { scoring_event_id: playId }, { goalkeeper_roster_id: null }]) assert.equal(parseGameCommand({ ...goal, input: { ...goal.input, ...fields } }), null);
  assert.ok(parseGameCommand({ ...goal, input: { ...goal.input, event_type: "penalty_saved", goalkeeper_roster_id: keeperId } }));
  assert.equal(parseGameCommand({ ...goal, input: { ...goal.input, event_type: "assist", scoring_event_id: null } }), null);
});
test("match format, added time, ascending clock and participation inputs are bounded and exact", () => {
  const configure = { operation: "soccer.configure", input: { ...base, regulation_segments: 2, segment_seconds: 2700, extra_time_segments: 2, extra_time_seconds: 900, lineup_size: 7, enforce_lineup: true, allow_reentry: false, max_substitutions: 3 } }; assert.ok(parseGameCommand(configure));
  assert.ok(parseGameCommand({ ...configure, input: { ...configure.input, regulation_segments: 4, extra_time_segments: 0, max_substitutions: null } }));
  for (const fields of [{ regulation_segments: 3 }, { segment_seconds: 5401 }, { extra_time_segments: 1 }, { extra_time_seconds: 59 }, { lineup_size: 12 }, { allow_reentry: "true" }, { max_substitutions: 101 }, { max_substitutions: -1 }, { shootout_enabled: true }]) assert.equal(parseGameCommand({ ...configure, input: { ...configure.input, ...fields } }), null);
  for (const added_time_seconds of [0, 120, 1800]) assert.ok(parseGameCommand({ operation: "soccer.added_time.set", input: { ...base, added_time_seconds, reason: "Controlled added time" } }));
  for (const added_time_seconds of [-1, 1801, 0.5]) assert.equal(parseGameCommand({ operation: "soccer.added_time.set", input: { ...base, added_time_seconds, reason: "Controlled added time" } }), null);
  assert.ok(parseGameCommand({ operation: "soccer.clock.set", input: { ...base, clock_ms: 7200000, reason: "Controlled correction" } }));
  assert.equal(parseGameCommand({ operation: "soccer.clock.set", input: { ...base, clock_ms: 1000, reason: " " } }), null);
  assert.ok(parseGameCommand({ operation: "soccer.lineup.set", input: { ...base, side: "primary", roster_ids: [athleteId, keeperId], goalkeeper_roster_id: keeperId } }));
  for (const roster_ids of [[athleteId, athleteId], ["known-id"], Array.from({ length: 12 }, (_, n) => soccerId(n + 200))]) assert.equal(parseGameCommand({ operation: "soccer.lineup.set", input: { ...base, side: "primary", roster_ids } }), null);
  assert.equal(parseGameCommand({ operation: "soccer.substitute", input: { ...base, side: "primary", out_roster_id: athleteId, in_roster_id: athleteId } }), null);
});
test("safe participation corrections are finite leaf replacements and never accept arbitrary timeline overrides", () => {
  for (const command of [{ operation: "soccer.event.correct", input: { ...base, event_id: playId, event_type: "substitution", side: "primary", out_roster_id: athleteId, in_roster_id: substituteId, reason: "Correct controlled substitution" } }, { operation: "soccer.event.correct", input: { ...base, event_id: playId, event_type: "keeper_set", side: "primary", goalkeeper_roster_id: keeperId, reason: "Correct keeper designation" } }, { operation: "soccer.event.reverse", input: { ...base, event_id: playId, reason: "Controlled duplicate" } }]) assert.ok(parseGameCommand(command));
  for (const fields of [{ event_type: "clock_set" }, { event_type: "lineup_set" }, { segment_number: 2 }, { override_final: true }, { event_id: "known-id" }, { reason: "x".repeat(501) }]) assert.equal(parseGameCommand({ operation: "soccer.event.correct", input: { ...goal.input, event_id: playId, reason: "Controlled correction", ...fields } }), null);
});
test("Soccer entry and stats preserve nullable participation and whitelist exact operator athlete identities", () => {
  const game = soccerData({ games: [{ ...soccerGameRaw, roster: [], capabilities: { operate: true, view_roster: false } }] }).games[0]; assert.ok(game.soccer?.configured); assert.equal(game.roster.length, 0); assert.equal(game.soccer.entry_roster.length, 3); assert.equal(game.soccer.players.length, 2); assert.equal(game.soccer.players[0].minutes, 2.5); assert.equal(game.soccer.players[0].goals_allowed, null); assert.equal(game.soccer.players[0].clean_sheet, null); assert.equal(game.soccer.plays[2].roster_id, null);
  assert.doesNotMatch(JSON.stringify(game.soccer), /OMIT_|person_id|absence_reason|actor_person_id|request_id|reason/);
});
test("family Soccer intersects authorized children and removes all entry, keeper lineup, correction and sealed authority", () => {
  const game = soccerData({}, true).games[0]; assert.ok(game.soccer?.configured); assert.equal(game.soccer.entry_roster.length, 0); assert.equal(game.soccer.lineups.length, 0); assert.equal(game.soccer.final_epochs.length, 0); assert.equal(game.soccer.players.length, 1); assert.equal(game.soccer.capabilities.operate, false); assert.equal(game.soccer.capabilities.correct, false); assert.equal(game.soccer.plays[2].display_name, null);
  const empty = soccerData({ games: [{ ...soccerGameRaw, roster: [], capabilities: { view_roster: false } }] }, true).games[0]; assert.ok(empty.soccer?.configured); assert.equal(empty.soccer.players.length, 0); assert.ok(empty.soccer.plays.every(row => row.roster_id === null && row.goalkeeper_roster_id === null && row.scoring_event_id === null));
  assert.doesNotMatch(JSON.stringify(game.soccer), /Controlled keeper|OMIT_/);
});
test("private Soccer entry contexts remain independent of visible play-by-play and close for family, readers and disabled write flags", () => {
  const game = soccerData({ features: { ...soccerFeatures, soccer_play_by_play: false } }).games[0]; assert.ok(game.soccer?.configured);
  assert.equal(game.soccer.plays.length, 0); assert.equal(game.soccer.entry_plays.length, 3);
  assert.equal(game.soccer.entry_plays[0].roster_id, athleteId); assert.equal(game.soccer.entry_plays[2].roster_id, null); assert.equal(game.soccer.entry_plays[2].display_name, null);
  assert.doesNotMatch(JSON.stringify(game.soccer.entry_plays), /OMIT_|actor_person_id|request_id|reason/);
  const corrector = soccerData({ features: { ...soccerFeatures, soccer_play_by_play: false }, games: [{ ...soccerGameRaw, capabilities: { correct: true, view_roster: true }, soccer: { ...soccerRaw, capabilities: { correct: true, stats: true } } }] }).games[0]; assert.ok(corrector.soccer?.configured);
  assert.equal(corrector.soccer.capabilities.operate, false); assert.equal(corrector.soccer.entry_roster.length, 0); assert.equal(corrector.soccer.entry_plays[0].roster_id, athleteId);
  const reader = soccerData({ games: [{ ...soccerGameRaw, capabilities: { view_roster: true }, soccer: { ...soccerRaw, capabilities: { stats: true } } }] }).games[0]; assert.ok(reader.soccer?.configured); assert.deepEqual(reader.soccer.entry_plays, []);
  const family = soccerData({}, true).games[0]; assert.ok(family.soccer?.configured); assert.deepEqual(family.soccer.entry_plays, []);
  for (const flag of ["soccer_live_scoring", "soccer_stats", "game_operations"]) { const closed = soccerData({ features: { ...soccerFeatures, [flag]: false } }).games[0]; assert.ok(closed.soccer?.configured); assert.deepEqual(closed.soccer.entry_plays, []); }
});
test("private Soccer entry context accepts bounded active correctable facts and rejects other controls or superseded targets", () => {
  const goal = soccerRaw.entry_plays[0], contexts = [goal, { ...goal, id: soccerId(710), event_type: "keeper_set" }, { ...goal, id: soccerId(711), event_type: "substitution" }, { ...goal, id: soccerId(712), event_type: "segment_start" }, { ...goal, id: soccerId(713), event_type: "engine_configure" }, { ...goal, id: soccerId(714), active: false }];
  const game = soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, entry_plays: contexts } }] }).games[0]; assert.ok(game.soccer?.configured);
  assert.deepEqual(game.soccer.entry_plays.map(row => row.event_type), ["goal", "keeper_set", "substitution"]);
  const large = soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, entry_plays: Array.from({ length: 501 }, () => goal) } }] }).games[0]; assert.ok(large.soccer?.configured); assert.deepEqual(large.soccer.entry_plays, []);
});
test("configured Soccer remains engine locked through wrong sport, malformed projection or disabled finite flags", () => {
  assert.equal(soccerData({ games: [{ ...soccerGameRaw, sport_key: "basketball" }] }).games[0].soccer, null);
  for (const fields of [{ engine_version: "soccer-v2" }, { segment_number: 7 }, { clock_ms: -1 }, { display_clock_ms: -1 }, { participation_complete: "true" }, { clock_observed_at: "2026-02-30T00:00:00Z" }]) { const game = soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, ...fields } }] }).games[0]; assert.equal(game.soccer, null); assert.equal(game.engine_locked, true); }
  for (const flag of ["soccer_live_scoring", "soccer_stats", "game_operations"]) { const game = soccerData({ features: { ...soccerFeatures, [flag]: false } }).games[0]; assert.ok(game.soccer?.configured); assert.equal(game.soccer.capabilities.operate, false); assert.equal(game.soccer.capabilities.correct, false); assert.equal(game.engine_locked, true); }
});
test("Soccer stats and history reject malformed totals and bound arrays without inventing partial stats", () => {
  for (const fields of [{ minutes: -0.5 }, { minutes: "2.5" }, { goals_allowed: -1 }, { shots_on_goal: -1 }, { clean_sheet: "true" }]) { const game = soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, players: [{ ...soccerRaw.players[0], ...fields }] } }] }).games[0]; assert.ok(game.soccer?.configured); assert.equal(game.soccer.players.length, 0); }
  const large = soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, plays: Array.from({ length: 501 }, () => soccerRaw.plays[0]) } }] }).games[0]; assert.ok(large.soccer?.configured); assert.equal(large.soccer.plays.length, 0);
  const ordinary = soccerData({ games: [{ ...soccerGameRaw, soccer: { ...soccerRaw, capabilities: { stats: true }, plays: [{ ...soccerRaw.plays[0], active: false }] } }] }).games[0]; assert.ok(ordinary.soccer?.configured); assert.equal(ordinary.soccer.plays.length, 0);
});
function saved(version = 11, game_id = gameId) { return new Response(JSON.stringify({ ok: true, result: { game_id, version, replayed: false, message: "Saved." } }), { status: 200 }); }
test("sport wrappers reject cross-sport input while the selected-game controller supports either finite sport", async () => {
  const basketball: GameCommand = { operation: "basketball.event.add", input: { ...base, side: "primary", event_type: "made_2" } };
  assert.equal((await new SoccerIntent().execute(basketball)).kind, "invalid"); assert.equal((await new BasketballIntent().execute(goal)).kind, "invalid");
  assert.equal((await new GameIntent().execute(goal, async () => saved())).kind, "saved"); assert.equal((await new GameIntent().execute(basketball, async () => saved())).kind, "saved");
});
test("lost committed Soccer outcomes block all new sport intent across refresh and replay the original version and request ID", async () => {
  const commands: GameCommand[] = [goal, soccerSaveCommand(gameId, 10, "primary", keeperId), { operation: "soccer.event.correct", input: { ...goal.input, event_id: playId, reason: "Controlled goal correction" } }, { operation: "soccer.substitute", input: { ...base, side: "primary", out_roster_id: athleteId, in_roster_id: substituteId } }, { operation: "soccer.clock.set", input: { ...base, clock_ms: 120000, reason: "Controlled clock" } }, { operation: "soccer.segment.end", input: base }];
  for (const command of commands) {
    let id = 400, accepted = 0; const controller = new GameIntent(() => soccerId(id++)), receipts = new Set<string>(), requests: string[] = [];
    const transport = async (_url: RequestInfo | URL, init?: RequestInit) => { requests.push(String(init?.body)); const body = JSON.parse(requests.at(-1)!); if (!receipts.has(body.request_id)) { receipts.add(body.request_id); accepted++; } if (requests.length === 1) throw new Error("Controlled committed response loss"); return saved(10 + accepted); };
    assert.equal((await controller.execute(command, transport)).kind, "unknown");
    const refreshed = { ...command, input: { ...command.input, expected_version: 11 } }; assert.equal((await controller.execute(refreshed, transport)).kind, "unknown"); assert.equal(requests.length, 1);
    assert.equal((await controller.execute({ operation: "basketball.event.add", input: { ...base, expected_version: 11, event_type: "made_2", side: "primary" } }, transport)).kind, "unknown"); assert.equal(requests.length, 1);
    assert.equal((await controller.retryUnconfirmed(transport)).kind, "saved"); assert.equal(requests[0], requests[1]); assert.equal(accepted, 1);
    assert.equal((await controller.execute(refreshed, transport)).kind, "saved"); assert.equal(accepted, 2); assert.notEqual(JSON.parse(requests[2]).request_id, JSON.parse(requests[1]).request_id);
  }
});
test("Soccer double tap and definitive denial preserve synchronous serialization without leaking response detail", async () => {
  const controller = new SoccerIntent(); let finish!: (response: Response) => void, calls = 0;
  const first = controller.execute(goal, async () => { calls++; return new Promise(resolve => { finish = resolve; }); }); assert.equal((await controller.execute(goal, async () => saved())).kind, "busy"); assert.equal(calls, 1); finish(saved()); assert.equal((await first).kind, "saved"); assert.equal(controller.waitingFor(10), true);
  for (const status of [401, 403, 409, 422]) { const intent = new SoccerIntent(); assert.equal((await intent.execute(goal, async () => { throw new Error("Controlled response loss"); })).kind, "unknown"); const result = await intent.retryUnconfirmed(async () => new Response(JSON.stringify({ ok: false, secret: "OMIT_SERVER_DETAIL" }), { status })); assert.equal(intent.hasUnconfirmed(), false); assert.doesNotMatch(result.message, /OMIT_SERVER_DETAIL/); }
  assert.equal((await new SoccerIntent().execute(goal, async () => saved(11, soccerId(999)))).kind, "unknown");
});
