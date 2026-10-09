import assert from "node:assert/strict";
import test from "node:test";
import type { DiamondFact, DiamondMove, DiamondRule, DiamondState } from "../src/lib/diamond/contracts";
import { battingRates, diamondFinalReady, displayedPitchCount, initialDiamond, inningsPitched, isAtBat, replayDiamond, transitionDiamond } from "../src/lib/diamond/reducer";

const rule = (sport: "baseball" | "softball" = "baseball"): DiamondRule => ({ version: "diamond-rules-v1", sport, home_side: "opponent", regulation_innings: sport === "baseball" ? 9 : 7, lineup_size: 4, continuous_batting: true, allow_reentry: false, stealing: true, dropped_third_strike: "first_unoccupied_or_two_outs", foul_bunt_third_strike: true, run_cap: null, tiebreak_from: null, dh: "none", dp_flex: "none", courtesy_runner: "none", mercy_margin: null, time_limit_minutes: null, pitch_limit: null, era_innings: sport === "baseball" ? 9 : 7 });
const move = (from: 0 | 1 | 2 | 3, to: 1 | 2 | 3 | 4 | null, cause: DiamondMove["cause"] = "hit", extra: Partial<DiamondMove> = {}): DiamondMove => ({ from, to, cause, out: to === null, force: false, batter_before_first: false, ...extra });
const opening: DiamondFact[] = [
  { kind: "lineup_set", side: "primary", order: ["p1", "p2", "p3", "p4"], positions: { "1": "p4", "2": "p3" }, pitcher: "p4" },
  { kind: "lineup_set", side: "opponent", order: ["o1", "o2", "o3", "o4"], positions: { "1": "o4" }, pitcher: "o4" },
  { kind: "half_start" },
];
function start(s: DiamondState, c = rule(), tracking = false, key = "pa1") { return transitionDiamond(c, s, { kind: "pa_start", key, batter: s.orders[s.batting_side][s.cursors[s.batting_side]], pitch_tracking: tracking }); }

for (const sport of ["baseball", "softball"] as const) {
  test(`${sport}: shared independent runner/score oracle and deterministic replay`, () => {
    const c = rule(sport);
    const facts: DiamondFact[] = [...opening,
      { kind: "pa_start", key: "pa1", batter: "p1", pitch_tracking: false }, { kind: "play", result: "single", moves: [move(0, 1)] },
      { kind: "pa_start", key: "pa2", batter: "p2", pitch_tracking: false }, { kind: "play", result: "double", moves: [move(1, 3), move(0, 2)] },
      { kind: "pa_start", key: "pa3", batter: "p3", pitch_tracking: false }, { kind: "play", result: "home_run", moves: [move(3, 4), move(2, 4), move(0, 4)] },
    ];
    const s = replayDiamond(c, facts);
    assert.equal(s.primary_score, 3); assert.equal(s.opponent_score, 0); assert.equal(s.outs, 0);
    assert.deepEqual(s.bases, [null, null, null]); assert.equal(s.cursors.primary, 3);
    const first = replayDiamond(c, facts.slice(0, 5)).bases[0]!;
    assert.equal(first.roster_id, "p1"); assert.equal(first.responsible_pitcher, "o4"); assert.equal(first.key, "pa1");
    assert.deepEqual(s, facts.reduce((state, f) => transitionDiamond(c, state, f), initialDiamond(c)));
  });
}
test("walk force chain and PA/AB conventions", () => {
  const c = rule(); let s = replayDiamond(c, opening);
  for (let i = 1; i <= 4; i++) { s = start(s, c, false, `walk${i}`); const occupied = s.bases.flatMap((r, n) => r ? [move((n + 1) as 1 | 2 | 3, (n + 2) as 2 | 3 | 4, "walk")] : []); s = transitionDiamond(c, s, { kind: "play", result: "walk", moves: [...occupied.reverse(), move(0, 1, "walk")] }); }
  assert.equal(s.primary_score, 1); assert.equal(s.bases[0]?.roster_id, "p4"); assert.equal(s.bases[2]?.roster_id, "p2");
  assert.equal(isAtBat("walk"), false); assert.equal(isAtBat("sacrifice_fly"), false); assert.equal(isAtBat("hit_by_pitch"), false); assert.equal(isAtBat("reached_on_error"), true);
  const active = start(s, c, false, "walk5");
  assert.throws(() => transitionDiamond(c, active, { kind: "play", result: "walk", moves: [move(0, 1, "walk")] }));
});
test("third-out ordering distinguishes timing play from force/batter-before-first", () => {
  const c = rule(); let s = replayDiamond(c, opening);
  s = start(s); s = transitionDiamond(c, s, { kind: "play", result: "triple", moves: [move(0, 3)] });
  for (let i = 0; i < 2; i++) { s = start(s, c, false, `out${i}`); s = transitionDiamond(c, s, { kind: "play", result: "other_out", moves: [move(0, null, "advance_on_play", { batter_before_first: true })] }); }
  s = start(s, c, false, "last");
  const timing = transitionDiamond(c, s, { kind: "play", result: "fielders_choice", moves: [move(3, 4), move(0, null)] });
  assert.equal(timing.primary_score, 1); assert.equal(timing.status, "half_complete");
  const forced = transitionDiamond(c, s, { kind: "play", result: "fielders_choice", moves: [move(3, 4), move(0, null, "fielders_choice", { force: true })] });
  assert.equal(forced.primary_score, 0);
  const first = transitionDiamond(c, s, { kind: "play", result: "other_out", moves: [move(3, 4), move(0, null, "advance_on_play", { batter_before_first: true })] });
  assert.equal(first.primary_score, 0);
  assert.throws(() => transitionDiamond(c, s, { kind: "play", result: "fielders_choice", moves: [move(0, null), move(3, 4)] }));
  const bottom = transitionDiamond(c, first, { kind: "half_start" });
  assert.equal(bottom.half, "bottom"); assert.equal(bottom.batting_side, "opponent"); assert.equal(bottom.outs, 0);
  assert.equal(bottom.completed_halves[0].outs, 3);
});
test("pitch count derives only from ordered facts; two-strike foul and foul bunt differ", () => {
  const c = rule(); let s = start(replayDiamond(c, opening), c, true);
  for (const outcome of ["called_strike", "swinging_strike", "foul", "foul"] as const) s = transitionDiamond(c, s, { kind: "pitch", outcome, pitch_tracking: true });
  assert.equal(s.pa?.strikes, 2); assert.equal(s.pa?.pitches, 4);
  s = transitionDiamond(c, s, { kind: "pitch", outcome: "foul_bunt", pitch_tracking: true });
  assert.equal(s.pa?.awaiting, "strikeout"); assert.equal(s.pa?.pitches, 5);
  assert.throws(() => transitionDiamond(c, s, { kind: "pitch", outcome: "ball", pitch_tracking: true }));
  assert.throws(() => transitionDiamond(c, s, { kind: "play", result: "single", moves: [move(0, 1)] }));
  s = transitionDiamond(c, s, { kind: "play", result: "strikeout", moves: [move(0, null, "advance_on_play", { batter_before_first: true })] });
  assert.equal(s.outs, 1); assert.equal(s.pa, null);
});
test("four balls require walk and count cannot be separately edited", () => {
  const c = rule(); let s = start(replayDiamond(c, opening), c, true);
  for (let i = 0; i < 4; i++) s = transitionDiamond(c, s, { kind: "pitch", outcome: "ball", pitch_tracking: true });
  assert.equal(s.pa?.balls, 4); assert.equal(s.pa?.awaiting, "walk");
  assert.throws(() => transitionDiamond(c, s, { kind: "play", result: "other_out", moves: [move(0, null)] }));
  assert.equal(transitionDiamond(c, s, { kind: "play", result: "walk", moves: [move(0, 1, "walk")] }).bases[0]?.roster_id, "p1");
});
test("untracked zero is absent and mid-PA pitch start is partial", () => {
  const c = rule(); let s = start(replayDiamond(c, opening), c, false);
  assert.deepEqual(displayedPitchCount(s.pa!), { value: null, coverage: "not_tracked" });
  assert.throws(() => transitionDiamond(c, s, { kind: "pitch", outcome: "ball", pitch_tracking: false }));
  s = transitionDiamond(c, s, { kind: "pitch", outcome: "ball", pitch_tracking: true });
  assert.deepEqual(displayedPitchCount(s.pa!), { value: 1, coverage: "partially_tracked" });
  assert.deepEqual(displayedPitchCount(start(replayDiamond(c, opening), c, true).pa!), { value: 0, coverage: "tracked" });
});
test("no duplicate occupancy/origin, backward advance, fabricated runner or scoring after third out", () => {
  const c = rule(); let s = start(replayDiamond(c, opening));
  assert.throws(() => transitionDiamond(c, s, { kind: "play", result: "single", moves: [move(0, 1), move(0, 2)] }));
  assert.throws(() => transitionDiamond(c, s, { kind: "play", result: "single", moves: [move(1, 2), move(0, 1)] }));
  s = transitionDiamond(c, s, { kind: "play", result: "single", moves: [move(0, 1)] }); s = start(s, c, false, "pa2");
  assert.throws(() => transitionDiamond(c, s, { kind: "play", result: "single", moves: [move(0, 1)] }));
  assert.throws(() => transitionDiamond(c, s, { kind: "advance", moves: [move(1, 1)] }));
});
test("pitcher change preserves inherited responsibility and appearance history", () => {
  const c = rule(); let s = start(replayDiamond(c, opening));
  assert.throws(() => transitionDiamond(c, s, { kind: "pitcher_change", side: "opponent", pitcher: "o3", key: "app2" }));
  s = transitionDiamond(c, s, { kind: "play", result: "single", moves: [move(0, 1)] });
  s = transitionDiamond(c, s, { kind: "pitcher_change", side: "opponent", pitcher: "o3", key: "app2" });
  assert.equal(s.appearances.length, 2); assert.equal(s.appearances[0].ended, true);
  assert.equal(s.appearances[1].inherited[0].responsible_pitcher, "o4"); assert.equal(s.bases[0]?.responsible_pitcher, "o4");
  s = start(s, c, false, "pa2"); assert.equal(s.pa?.pitcher, "o3");
});
test("steal/caught stealing/pinch runner preserve base and responsibility provenance", () => {
  const c = rule(); let s = start(replayDiamond(c, opening));
  s = transitionDiamond(c, s, { kind: "play", result: "single", moves: [move(0, 1)] });
  s = transitionDiamond(c, s, { kind: "advance", moves: [move(1, 2, "stolen_base")] });
  assert.equal(s.bases[1]?.roster_id, "p1"); assert.equal(s.bases[1]?.responsible_pitcher, "o4");
  s = transitionDiamond(c, s, { kind: "substitution", side: "primary", out_roster_id: "p1", in_roster_id: "p5", mode: "pinch_runner" });
  assert.equal(s.bases[1]?.roster_id, "p5"); assert.equal(s.bases[1]?.key, "pa1"); assert.equal(s.bases[1]?.responsible_pitcher, "o4");
  s = transitionDiamond(c, s, { kind: "advance", moves: [move(2, null, "caught_stealing")] });
  assert.equal(s.outs, 1); assert.deepEqual(s.bases, [null, null, null]);
  assert.throws(() => transitionDiamond(c, s, { kind: "substitution", side: "primary", out_roster_id: "p5", in_roster_id: "p1", mode: "offensive" }));
});
test("configurable regulation, run cap, extra inning placed-runner foundation", () => {
  const c = { ...rule(), regulation_innings: 1, tiebreak_from: 2, run_cap: 1 };
  let s = replayDiamond(c, opening);
  for (let i = 0; i < 2; i++) {
    s = start(s, c, false, `hr${i}`); s = transitionDiamond(c, s, { kind: "play", result: "home_run", moves: [move(0, 4)] });
    assert.equal(s.status, "half_complete");
    if (i === 0) s = transitionDiamond(c, s, { kind: "half_start" });
  }
  assert.throws(() => transitionDiamond(c, s, { kind: "half_start" }));
  s = transitionDiamond(c, s, { kind: "half_start", placed_runner: { roster_id: "p1", key: "placed2" } });
  assert.equal(s.inning, 2); assert.equal(s.bases[1]?.placed, true); assert.equal(s.bases[1]?.origin, "tiebreak");
});
test("outs-derived IP and rate oracle use conventional accounting, never decimal innings", () => {
  assert.equal(inningsPitched(14), "4.2"); assert.equal(inningsPitched(15), "5.0"); assert.throws(() => inningsPitched(1.5));
  const r = battingRates({ ab: 4, h: 2, doubles: 1, triples: 0, hr: 1, bb: 1, hbp: 0, sf: 0 });
  assert.deepEqual(r, { avg: 0.5, obp: 0.6, slg: 1.5, ops: 2.1 });
  assert.deepEqual(battingRates({ ab: 0, h: 0, doubles: 0, triples: 0, hr: 0, bb: 0, hbp: 0, sf: 0 }), { avg: null, obp: null, slg: null, ops: null });
});
test("invalid sport/rules, duplicate lineups and wrong order fail closed", () => {
  assert.throws(() => initialDiamond({ ...rule(), sport: "soccer" } as unknown as DiamondRule));
  assert.throws(() => initialDiamond({ ...rule(), dp_flex: "foundation_only" }));
  assert.throws(() => initialDiamond({ ...rule(), tiebreak_from: 9 }));
  assert.throws(() => transitionDiamond(rule(), initialDiamond(rule()), { kind: "lineup_set", side: "primary", order: ["p1", "p1", "p2", "p3"], positions: {}, pitcher: null }));
  assert.throws(() => transitionDiamond(rule(), replayDiamond(rule(), opening), { kind: "pa_start", key: "wrong", batter: "p2", pitch_tracking: false }));
});

test("a runner cannot pass an occupied lead base or score first", () => {
  let s = replayDiamond(rule(), opening);
  s = transitionDiamond(rule(), start(s), { kind: "play", result: "single", moves: [move(0, 1)] });
  const pa = start(s, rule(), false, "second");
  assert.throws(() => transitionDiamond(rule(), pa, { kind: "play", result: "triple", moves: [move(0, 3)] }), /lead runner/);
  assert.throws(() => transitionDiamond(rule(), pa, { kind: "play", result: "home_run", moves: [move(0, 4), move(1, 4)] }), /lead runner/);
  assert.equal(transitionDiamond(rule(), pa, { kind: "play", result: "home_run", moves: [move(1, 4), move(0, 4)] }).primary_score, 2);
});
test("a server-declared pitch observation gap permits truthful partial PA completion", () => {
  let s = start(replayDiamond(rule(), opening), rule(), true);
  s = transitionDiamond(rule(), s, { kind: "pitch", outcome: "ball", pitch_tracking: true });
  assert.throws(() => transitionDiamond(rule(), s, { kind: "play", result: "single", moves: [move(0, 1)] }));
  const next = transitionDiamond(rule(), s, { kind: "play", pitch_gap: true, result: "single", moves: [move(0, 1)] });
  assert.equal(next.bases[0]?.roster_id, "p1"); assert.equal(next.pa, null);
});
test("ordinary finalization permits home-ahead skipped bottom and walkoff, never ties", () => {
 const c={...rule(),regulation_innings:1};const base=replayDiamond(c,opening);
 const top={...base,status:"half_complete"as const,opponent_score:1,outs:3};assert.equal(diamondFinalReady(c,top),true);
 const bottom={...base,half:"bottom"as const,opponent_score:1};assert.equal(diamondFinalReady(c,bottom),true);
 assert.equal(diamondFinalReady(c,{...bottom,primary_score:1}),false);
 assert.throws(()=>transitionDiamond(c,top,{kind:"half_start"}));
});
