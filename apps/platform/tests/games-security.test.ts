import assert from "node:assert/strict";
import test from "node:test";
import { BOSS_SUPABASE_URL } from "../src/lib/env/validation";
import { parseGameCommand, parseGameQuery, projectGameData, projectGameResult } from "../src/lib/games/input";
import { performGameMutation, type GameClient } from "../src/lib/games/mutation";
import { gameFormFailureMessage } from "../src/lib/games/feedback";

const actor = "00000000-0000-4000-8000-000000000001", game = "00000000-0000-4000-8000-000000000002", team = "00000000-0000-4000-8000-000000000003", event = "00000000-0000-4000-8000-000000000004", participant = "00000000-0000-4000-8000-000000000005", requestId = "00000000-0000-4000-8000-000000000006", origin = "https://games.boss.invalid";
const score = { operation: "game.score.set", input: { game_id: game, expected_version: 3, primary_score: 10, opponent_score: 8 } };
const create = { operation: "game.create", input: { event_id: event, expected_event_version: 1, occurrence_key: "2026-10-04T18:00:00", primary_team_id: team, sport_key: "basketball", competition_type: "standard" } };
test("Football create preserves the native occurrence, sport and event revision through the route", async () => {
  const command = { operation: "game.create", input: { ...create.input, occurrence_key: "2026-10-05T00:25:00", sport_key: "football" } };
  assert.deepEqual(parseGameCommand(command), command);
  const m = mock();
  assert.equal((await performGameMutation(request(command), m.client, origin)).status, 200);
  assert.deepEqual(m.calls, [{ name: "boss_games_mutate", args: { p_request_id: requestId, p_command: command } }]);
});
test("a known game-create validation rejection is not presented as an unknown outcome", async () => {
  const m = mock();
  m.client.rpc = async () => ({ data: null, error: { code: "PT422" } });
  const result = await performGameMutation(request({ ...create, input: { ...create.input, sport_key: "football" } }), m.client, origin);
  assert.equal(result.status, 422);
  assert.match(gameFormFailureMessage(result.status), /Review.*Calendar matchup targets/);
  assert.doesNotMatch(gameFormFailureMessage(result.status), /could not be confirmed|Retry to safely check/);
  assert.match(gameFormFailureMessage(503), /could not be confirmed.*same request/);
});
function request(command: unknown = score, headers: Record<string, string> = {}, body?: string) { return new Request(`${origin}/app/games/mutate`, { method: "POST", headers: { origin, host: "games.boss.invalid", "sec-fetch-site": "same-origin", "content-type": "application/json", ...headers }, body: body ?? JSON.stringify({ request_id: requestId, command }) }); }
function mock() { const calls: unknown[] = []; let checks = 0;
  const client: GameClient = { auth: { getClaims: async () => ({ data: { claims: { sub: actor, iss: `${BOSS_SUPABASE_URL}/auth/v1`, role: "authenticated", exp: Math.floor(Date.now() / 1000) + 120 } }, error: null }), getUser: async () => { checks++; return { data: { user: { id: actor, is_anonymous: false } }, error: null }; } }, rpc: async (name, args) => { calls.push({ name, args }); return { data: { game_id: game, version: 4, replayed: false, message: "Saved.", internal_note: "OMIT_PRIVATE_FIELD" }, error: null }; } };
  return { client, calls, checks: () => checks };
}
export const rawGame = { id: game, organization_id: actor, event_id: event, occurrence_key: "2026-10-04T18:00:00", occurrence_mode: "single", version: 3, status: "live", start_at: "2026-10-04T23:00:00Z", end_at: "2026-10-05T00:00:00Z", timezone: "America/Chicago", title: "Controlled Falcons game", sport_key: "basketball", sport_label: "Basketball", primary: { team_id: team, label: "Falcons", score: 10, final_score: null }, opponent: { team_id: null, label: "External opponent", score: 8, final_score: null }, home_away: "home", capabilities: { view_roster: true, manage: true, operate: true, finalize: true, correct: true, publish: true }, roster: [{ id: requestId, person_id: actor, participant_id: participant, team_id: team, display_name: "Controlled athlete", active: true, availability: "unknown", revision: 1, date_of_birth: "OMIT_PRIVATE_FIELD", absence_reason: "OMIT_PRIVATE_FIELD" }], operators: [{ id: requestId, person_id: actor, role_assignment_id: event, function_key: "scorekeeper", team_id: team, display_name: "Controlled operator", status: "active" }], history: [{ id: requestId, sequence: 3, version: 3, operation: "game.score.set", created_at: "2026-10-04T23:05:00Z", summary: "Score 10 to 8", actor_contact: "OMIT_PRIVATE_FIELD" }], finalizations: [] };
const query = parseGameQuery({ org: actor, from: "2026-10-04", to: "2026-10-07" })!;

test("game creation binds an explicit sport and competitive occurrence with Calendar version", () => {
  assert.ok(parseGameCommand(create));
  for (const fields of [{ sport_key: "Falcons basketball program" }, { sport_key: "basketball_live" }, { expected_event_version: 0 }, { occurrence_key: "2026-02-30T18:00:00" }, { occurrence_key: "2026-10-04T24:00:00" }, { occurrence_key: "2026-10-04T18:00:00Z" }, { primary_team_id: "known-id" }, { competition_type: "multiteam" }]) assert.equal(parseGameCommand({ ...create, input: { ...create.input, ...fields } }), null);
});
test("Game Center configuration accepts only versioned finite Sports capability switches", () => {
  const configuration = { operation: "games.configure", input: { organization_id: actor, expected_version: 1, configuration: { game_center: true, game_operations: false } } };
  assert.ok(parseGameCommand(configuration));
  for (const fields of [{ expected_version: 0 }, { game_id: game }, { configuration: {} }, { configuration: { stats: true } }, { configuration: { game_center: "true" } }, { configuration: { game_center: true, module_status: "active" } }]) assert.equal(parseGameCommand({ ...configuration, input: { ...configuration.input, ...fields } }), null);
});
test("configuration response binds the exact organization and cannot substitute a game result", async () => {
  const command = { operation: "games.configure", input: { organization_id: actor, expected_version: 1, configuration: { game_center: true } } }, m = mock();
  m.client.rpc = async () => ({ data: { game_id: null, organization_id: actor, version: 2, replayed: false }, error: null });
  assert.equal((await performGameMutation(request(command), m.client, origin)).status, 200);
  m.client.rpc = async () => ({ data: { game_id: null, organization_id: event, version: 2, replayed: false }, error: null });
  assert.equal((await performGameMutation(request(command), m.client, origin)).status, 503);
  m.client.rpc = async () => ({ data: { game_id: game, version: 2, replayed: false }, error: null });
  assert.equal((await performGameMutation(request(command), m.client, origin)).status, 503);
  m.client.rpc = async () => ({ data: { game_id: null, organization_id: actor, version: 2, replayed: false }, error: null });
  assert.equal((await performGameMutation(request(score), m.client, origin)).status, 503);
});
test("game operations reject injected actor, tenant, engine and last-write-wins inputs", () => {
  assert.ok(parseGameCommand(score));
  for (const fields of [{ actor_id: actor }, { organization_id: actor }, { expected_version: 0 }, { expected_version: "3" }, { primary_score: -1 }, { opponent_score: 1.5 }, { primary_score: 1000001 }, { score_event: { type: "goal" } }, { clock_seconds: 15 }, { override_permission: true }]) assert.equal(parseGameCommand({ ...score, input: { ...score.input, ...fields } }), null);
  assert.equal(parseGameCommand({ ...score, authorization: { is_admin: true } }), null);
  for (const operation of ["game.touchdown", "game.stats.aggregate", "game.clock.set", "role.grant"]) assert.equal(parseGameCommand({ ...score, operation }), null);
});
test("operator assignments require canonical referenced role, exact team, finite function and expiry", () => {
  const assignment = { operation: "game.operator.assign", input: { game_id: game, expected_version: 3, person_id: actor, role_assignment_id: event, team_id: team, function_key: "scorekeeper", ends_at: "2026-10-05T02:00:00Z" } };
  assert.ok(parseGameCommand(assignment));
  for (const fields of [{ role_assignment_id: null }, { team_id: null }, { team_id: "any-team" }, { function_key: "livestream_operator" }, { function_key: "statistician" }, { ends_at: null }, { ends_at: "2026-02-30T18:00:00Z" }, { ends_at: "infinity" }, { permissions: ["games.finalize"] }]) assert.equal(parseGameCommand({ ...assignment, input: { ...assignment.input, ...fields } }), null);
});
test("final reopening and reversal require explicit finite correction input", () => {
  assert.ok(parseGameCommand({ operation: "game.reopen", input: { game_id: game, expected_version: 3, reason: "Controlled correction" } }));
  for (const reason of ["", " ", "x".repeat(501), "unsafe\u0000reason"]) assert.equal(parseGameCommand({ operation: "game.reopen", input: { game_id: game, expected_version: 3, reason } }), null);
  assert.ok(parseGameCommand({ operation: "game.score.reverse", input: { game_id: game, expected_version: 3, operation_id: event } }));
  assert.equal(parseGameCommand({ operation: "game.finalize", input: { game_id: game, expected_version: 3, calculate_career_stats: true } }), null);
});
test("game filters validate dates, exact identifiers, repeated fields and finite views", () => {
  assert.ok(query); assert.equal(query.to, "2026-10-08T00:00:00.000Z");
  for (const fields of [{ org: [actor, team] }, { team: "bad" }, { game: [game] }, { unit: "descendants" }, { child: "bad" }, { from: "2026-02-30", to: "2026-03-03" }, { from: "2026-10-04", to: "2027-10-04" }, { status: "finalized_with_stats" }, { view: "public" }]) assert.equal(parseGameQuery(fields), null);
});
test("game projection omits private profile, absence reasons, contact and unknown feature flags", () => {
  const data = projectGameData({ features: { game_center: true, game_operations: true, live_scoring: true, stats: true }, games: [rawGame], private_session: "OMIT_PRIVATE_FIELD" }, query);
  assert.ok(data); assert.equal(data.games[0].primary.score, 10); assert.equal(data.games[0].roster.length, 1); assert.doesNotMatch(JSON.stringify(data), /OMIT_PRIVATE_FIELD|private_session|absence_reason|date_of_birth/); assert.equal("live_scoring" in data.features, false); assert.equal("stats" in data.features, false);
});
test("family projection forcibly strips operating controls, operators, internal history and management choices", () => {
  const data = projectGameData({ features: { game_center: true }, capabilities: { create: true, configure: true }, games: [rawGame], operator_candidates: [{ person_id: actor, role_assignment_id: event, display_name: "OMIT_OPERATOR", team_id: team, functions: ["game_administrator"] }] }, { ...query, view: "family" });
  assert.ok(data); assert.equal(data.games[0].capabilities.operate, false); assert.equal(data.games[0].capabilities.finalize, false); assert.equal(data.games[0].capabilities.correct, false); assert.equal(data.games[0].operators.length, 0); assert.equal(data.games[0].history.length, 0); assert.equal(data.operator_candidates.length, 0); assert.equal(data.capabilities.create, false); assert.doesNotMatch(JSON.stringify(data), /OMIT_OPERATOR/);
});
test("view-only projections omit private roster and operator candidates without corresponding capability", () => {
  const data = projectGameData({ features: {}, games: [{ ...rawGame, capabilities: {} }], operator_candidates: [{ person_id: actor, role_assignment_id: event, display_name: "OMIT_OPERATOR", functions: ["scorekeeper"] }] }, query);
  assert.ok(data); assert.equal(data.games[0].roster.length, 0); assert.equal(data.games[0].operators.length, 0); assert.equal(data.games[0].history.length, 0); assert.equal(data.operator_candidates.length, 0);
});
test("game projection discards invalid times, malformed identities and oversized collections", () => {
  for (const fields of [{ id: "bad" }, { timezone: "Not/AZone" }, { start_at: "2026-02-30T18:00:00Z" }, { occurrence_key: "forged" }, { sport_key: "guessed" }]) assert.equal(projectGameData({ features: {}, games: [{ ...rawGame, ...fields }] }, query)?.games.length, 0);
  assert.equal(projectGameData({ features: {}, games: Array.from({ length: 101 }, () => rawGame) }, query)?.games.length, 0);
  assert.equal(projectGameResult({ game_id: game, version: 0, replayed: false }), null);
});
test("same-origin and current nonanonymous identity gate every game mutation", async () => {
  const m = mock(); assert.equal((await performGameMutation(request(score, { origin: "https://attacker.invalid" }), m.client, origin)).status, 403); assert.equal(m.calls.length, 0);
  for (const user of [null, { id: event }, { id: actor, is_anonymous: true }]) { m.client.auth.getUser = async () => ({ data: { user }, error: null }); assert.equal((await performGameMutation(request(), m.client, origin)).status, 401); }
  assert.equal(m.calls.length, 0);
});
test("game mutation retries keep the request identifier and reverify the current caller", async () => {
  const m = mock(); for (let i = 0; i < 2; i++) assert.equal((await performGameMutation(request(), m.client, origin)).status, 200);
  assert.equal(m.checks(), 2); assert.deepEqual(m.calls[0], m.calls[1]); assert.doesNotMatch(JSON.stringify(await performGameMutation(request(), m.client, origin)), /OMIT_PRIVATE_FIELD/);
});
test("revoked or stale game writes surface safe denial/conflict without database details", async () => {
  const m = mock();
  for (const [code, status] of [["PT403", 403], ["PT409", 409], ["PT422", 422], ["57014", 503]] as const) { m.client.rpc = async () => ({ data: null, error: { code, detail: "OMIT_PRIVATE_FIELD" } }); const result = await performGameMutation(request(), m.client, origin); assert.equal(result.status, status); assert.doesNotMatch(JSON.stringify(result), /OMIT_PRIVATE_FIELD|57014/); }
  m.client.rpc = async () => ({ data: { game_id: event, version: 4, replayed: false }, error: null }); assert.equal((await performGameMutation(request(), m.client, origin)).status, 503);
});
test("malformed, oversized and non-JSON game requests never call the database", async () => {
  const m = mock(); for (const req of [request(score, { "content-type": "text/plain" }), request(score, { "content-type": "application/jsonp" }), request(score, { "content-length": "16001" }), request(score, {}, "{"), request(score, {}, "x".repeat(16001)), request({ ...score, input: { ...score.input, actor_id: actor } })]) assert.equal((await performGameMutation(req, m.client, origin)).status, 422); assert.equal(m.calls.length, 0);
});
