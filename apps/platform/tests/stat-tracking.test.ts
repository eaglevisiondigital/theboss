import assert from "node:assert/strict";
import test from "node:test";
import { statCatalog, trackingSports, validateCatalog } from "../src/lib/stat-tracking/catalog";
import { contextualPrompts, coveredValue, resolveSelection } from "../src/lib/stat-tracking/profile";
import { createPracticeSession, requireOfficialCommand } from "../src/lib/stat-tracking/practice";

test("all sport adapter catalogs are finite acyclic and preserve required game facts", () => {
  for (const sport of trackingSports) {
    validateCatalog(sport);
    const scoreOnly = resolveSelection(sport, "score_only");
    assert.ok(statCatalog[sport].filter(s => s.classification === "required").every(s => scoreOnly.enabled.includes(s.key)));
    assert.deepEqual(scoreOnly.quick, sport === "baseball" || sport === "softball" ? ["play_state"] : []);
  }
});
test("Volleyball custom selection closes dependencies and preserves Quick Stats order", () => {
  const p = resolveSelection("volleyball", "custom", ["kills", "assists", "digs"], ["digs", "kills"]);
  assert.ok(p.enabled.includes("attack_attempts"));
  assert.deepEqual(p.quick, ["digs", "kills"]);
  assert.ok(!p.enabled.includes("receptions"));
  assert.deepEqual(contextualPrompts("volleyball", "kill", p), ["assists"]);
  assert.deepEqual(contextualPrompts("volleyball", "kill", resolveSelection("volleyball", "custom", ["kills"])), []);
});
test("Quick Stats and selections reject unsupported, duplicate, wrong-sport and disabled inputs", () => {
  assert.throws(() => resolveSelection("volleyball", "custom", ["receptions"], ["kills"]));
  assert.throws(() => resolveSelection("volleyball", "custom", ["kills", "kills"]));
  assert.throws(() => resolveSelection("volleyball", "custom", ["passing_yards"]));
  assert.throws(() => resolveSelection("volleyball", "custom", ["passing_rating"]));
  assert.throws(() => resolveSelection("volleyball", "custom", ["kills"], ["kills", "kills"]));
  const keys = statCatalog.volleyball.filter(s => s.quick_eligible).slice(0, 9).map(s => s.key);
  assert.throws(() => resolveSelection("volleyball", "custom", keys, keys));
});
test("untracked differs from measured zero; later enablement and disable/re-enable remain partial", () => {
  const interval = (from_sequence: number, enabled: boolean) => ({ from_sequence, enabled, snapshot_id: `s${from_sequence}` });
  assert.deepEqual(coveredValue(0, [interval(1, false)], 2, 30), { recorded_value: null, coverage: "not_tracked", reason: "declared" });
  assert.equal(coveredValue(0, [interval(1, true)], 2, 30).coverage, "tracked");
  assert.equal(coveredValue(3, [interval(1, false), interval(20, true)], 2, 30).coverage, "partially_tracked");
  assert.equal(coveredValue(3, [interval(1, true), interval(10, false), interval(20, true)], 2, 30).coverage, "partially_tracked");
  assert.equal(coveredValue(3, [interval(20, true)], 2, 30).coverage, "partially_tracked");
  assert.equal(coveredValue(0, null, 2, 30).reason, "legacy_unknown");
  assert.throws(() => coveredValue(0, [interval(3, true), interval(2, false)], 1, 30));
});
test("practice is synthetic isolated state and cannot pass the official mutation boundary", () => {
  const profile = resolveSelection("volleyball", "essential"), session = createPracticeSession("volleyball", profile);
  session.profile.quick.length = 0;
  assert.ok(profile.quick.length > 0);
  assert.ok(session.participants.every(p => p.key.startsWith("practice:")));
  assert.throws(() => requireOfficialCommand(session));
});

test("migration catalog definitions match the versioned runtime catalog", async () => {
  const { readFile } = await import("node:fs/promises");
  const sql=(await Promise.all(["20261005142103_phase5e_stat_tracking.sql", "20261005163704_phase5f_diamond_integration.sql"].map(name=>readFile(new URL(`../../../supabase/migrations/${name}`,import.meta.url),"utf8")))).join("\n");
  const definitions=[...sql.matchAll(/values\('([a-z]+)','boss-tracking-v1','([^']+)','((?:[^']|'')+)'::jsonb\)/g)].map(m=>({sport:m[1],key:m[2],definition:JSON.parse(m[3].replaceAll("''","'"))}));
  assert.equal(definitions.length,trackingSports.reduce((n,s)=>n+statCatalog[s].length,0));
  for(const sport of trackingSports) for(const item of statCatalog[sport]) assert.deepEqual(definitions.find(d=>d.sport===sport&&d.key===item.key)?.definition,item);
});

test("scoped profile receipts match configuration context without pretending to be a game", async () => {
  const { parseGameCommand, projectGameResult, gameResultMatchesCommand } = await import("../src/lib/games/input");
  const org="10000000-0000-4000-8000-000000000001", profile="10000000-0000-4000-8000-000000000002";
  const command=parseGameCommand({operation:"tracking.profile.set",input:{sport_key:"volleyball",scope_type:"organization",organization_id:org,expected_profile_version:0,preset:"essential",reason:"Controlled configuration test"}})!;
  assert.ok(command);
  const result=projectGameResult({profile_id:profile,profile_version:1,game_id:null,organization_id:org,version:1,replayed:false})!;
  assert.ok(result);assert.equal(gameResultMatchesCommand(result,command),true);
  assert.equal(gameResultMatchesCommand({...result,organization_id:profile},command),false);
  assert.equal(projectGameResult({profile_id:profile,profile_version:0,game_id:null,version:1,replayed:false}),null);
  assert.equal(parseGameCommand({...command,input:{...command.input,team_id:profile}}),null);
});
