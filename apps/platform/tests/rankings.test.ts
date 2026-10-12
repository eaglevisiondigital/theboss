import test from "node:test";
import assert from "node:assert/strict";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { emptyRankings } from "../src/lib/rankings/contracts";
import { competitionGameRange, parseRankingQuery, projectRankings } from "../src/lib/rankings/input";
import { parseRankingCommand } from "../src/lib/rankings/action";
import { performRankingMutation, type RankingClient } from "../src/lib/rankings/mutation";
import { RankingsHub } from "../src/components/rankings/hub";
const id = "10000000-0000-0000-0000-000000000001", other = "10000000-0000-0000-0000-000000000002", origin = "https://platform.boss.invalid";
const command = { action: "ranking.rebuild", request_id: id, input: { edition_id: other, product: "standings" } };
function request(body: unknown = command, headers = {}) { return new Request(`${origin}/app/competitions/mutate`, { method: "POST", headers: { origin, host: "platform.boss.invalid", "content-type": "application/json", ...headers }, body: JSON.stringify(body) }); }
function mock() {
  const calls: unknown[] = [];
  const client: RankingClient = { auth: { getClaims: async () => ({ data: { claims: { sub: id, iss: "https://ilykgwgmxtrrikreacrz.supabase.co/auth/v1", role: "authenticated", exp: Math.floor(Date.now() / 1000) + 60 } }, error: null }), getUser: async () => ({ data: { user: { id } }, error: null }) }, rpc: async (name, args) => { calls.push([name, args]); return { data: { contract: "rankings-v1", id: other, action: "ranking.rebuild", complete: false, replayed: false, ignored: "UNNEEDED_PRIVATE_PAYLOAD" }, error: null }; } };
  return { client, calls };
}
test("ranking filters reject forged scope and absent comparative definition", () => {
  for (const q of [{ org: "forged" }, { org: id, product: "arbitrary" }, { edition: id, product: "leaderboard" }, { edition: id, product: "standings", definition: other }, { org: id, cursor: "invalid" }, { org: [id] }]) assert.equal(parseRankingQuery(q), null);
  assert.deepEqual(parseRankingQuery({ org: id }), { organization_id: id, limit: 50 });
});
test("competition game picker stays within the Game Center range contract", () => {
  const now = new Date("2026-10-06T08:10:00.000Z"), range = competitionGameRange(now);
  assert.equal(Date.parse(range.to) - Date.parse(range.from), 93 * 86400000);
  assert.ok(Date.parse(range.from) <= Date.parse("2026-10-04T15:00:00.000Z"));
});
test("projection fails closed on stale rows, invalid qualification and unbounded pages", () => {
  for (const v of [{ contract: "rankings-v1", freshness: "pending", rows: [{ id, label: "STALE_PRIVATE_PEER", rank: 1 }] }, { contract: "rankings-v1", freshness: "current", rows: [{ id, rank: 1, qualification_state: "below_minimum" }] }, { contract: "rankings-v1", freshness: "current", rows: Array.from({ length: 101 }, () => ({ id })) }]) assert.equal(projectRankings(v), null);
});
test("untracked stays unavailable and measured zero stays zero", () => {
  const data = projectRankings({ contract: "rankings-v1", freshness: "current", rows: [{ id, label: "Measured zero", rank: 1, value: 0, qualification_state: "qualified" }, { id: other, label: "Not tracked", rank: null, value: null, qualification_state: "incomplete" }] }); assert.ok(data);
  const html = renderToStaticMarkup(createElement(RankingsHub, { data, query: { edition_id: id, definition_id: other, product: "leaderboard" } }));
  for (const expected of [/Measured zero/, />0</, /Incomplete coverage/, /Unavailable/, /Unranked/]) assert.match(html, expected);
});
test("restricted UI reveals no peer table or rank", () => {
  const html = renderToStaticMarkup(createElement(RankingsHub, { data: { ...emptyRankings(), restricted: true }, query: { edition_id: id, product: "records" } })); assert.match(html, /restricted/); assert.doesNotMatch(html, /<table|Current holder/);
});
test("command rejects broader authority and malformed booleans", () => {
  assert.ok(parseRankingCommand(command));
  for (const c of [{ ...command, actor_person_id: id }, { ...command, input: { ...command.input, organization_override: other } }, { ...command, action: "public.publish" }, { ...command, input: { edition_id: "forged", product: "standings" } }, { action: "game.assign", request_id: id, input: { edition_id: other, counts_for_standings: "true" } }]) assert.equal(parseRankingCommand(c), null);
});
test("signed POST denies cross-origin before Auth/RPC", async () => { const m = mock(); assert.equal((await performRankingMutation(request(undefined, { origin: "https://attacker.invalid" }), m.client, origin)).status, 403); assert.equal(m.calls.length, 0); });
test("unsupported content and oversized requests never reach RPC", async () => {
 const m = mock(); for (const req of [request(undefined, { "content-type": "text/plain" }), request({ ...command, input: { ...command.input, reason: "x".repeat(19000) } })]) assert.equal((await performRankingMutation(req, m.client, origin)).status, 422); assert.equal(m.calls.length, 0);
});
test("changed or anonymous identity cannot mutate", async () => {
 const m = mock(); m.client.auth.getUser = async () => ({ data: { user: { id: other } }, error: null }); assert.equal((await performRankingMutation(request(), m.client, origin)).status, 401);
 m.client.auth.getUser = async () => ({ data: { user: { id, is_anonymous: true } }, error: null }); assert.equal((await performRankingMutation(request(), m.client, origin)).status, 401); assert.equal(m.calls.length, 0);
});
test("bounded rebuild response strips private payload and keeps retry receipt", async () => {
 const m = mock(); for (let n = 0; n < 2; n++) { const result = await performRankingMutation(request(), m.client, origin); assert.equal(result.status, 200); assert.doesNotMatch(JSON.stringify(result), /UNNEEDED_PRIVATE_PAYLOAD/); assert.equal("complete" in result.body && result.body.complete, false); } assert.deepEqual(m.calls[0], m.calls[1]);
});
test("revocation and conflict statuses are finite", async () => { const m = mock(); for (const [code, status] of [["PT403", 403], ["40001", 409], ["PT409", 409], ["PT422", 422]] as const) { m.client.rpc = async () => ({ data: null, error: { code } }); assert.equal((await performRankingMutation(request(), m.client, origin)).status, status); } });
test("missing completion or mismatched operation fails closed", async () => {
 const m = mock(); for (const data of [{ contract: "rankings-v1", id: other, action: "ruling.create", complete: true, replayed: false }, { contract: "rankings-v1", id: other, action: "ranking.rebuild", replayed: false }]) { m.client.rpc = async () => ({ data, error: null }); assert.equal((await performRankingMutation(request(), m.client, origin)).status, 503); }
});
