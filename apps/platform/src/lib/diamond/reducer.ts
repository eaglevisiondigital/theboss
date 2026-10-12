import { diamondCauses, diamondPitches, diamondResults, diamondSports, type DiamondFact, type DiamondMove, type DiamondPA, type DiamondRule, type DiamondRunner, type DiamondSide, type DiamondState } from "./contracts";

// Pure practice/preview reducer. The database remains the official write authority.
const other = (side: DiamondSide): DiamondSide => side === "primary" ? "opponent" : "primary";
function reject(message: string): never { throw new Error(message); }
const bounded = (n: unknown, min: number, max: number) => typeof n === "number" && Number.isSafeInteger(n) && n >= min && n <= max;
export function validateDiamondRule(c: DiamondRule): void {
  const allowed = ["version", "sport", "home_side", "regulation_innings", "lineup_size", "continuous_batting", "allow_reentry", "stealing", "dropped_third_strike", "foul_bunt_third_strike", "run_cap", "tiebreak_from", "dh", "dp_flex", "courtesy_runner", "mercy_margin", "time_limit_minutes", "pitch_limit", "era_innings"];
  if (!c || Object.keys(c).length !== allowed.length || Object.keys(c).some(k => !allowed.includes(k)) || c.version !== "diamond-rules-v1" || !diamondSports.includes(c.sport) || !["primary", "opponent"].includes(c.home_side) || !bounded(c.regulation_innings, 1, 20) || !bounded(c.lineup_size, 1, 30) || !bounded(c.era_innings, 1, 20)) reject("Invalid Diamond rule profile");
  for (const k of ["continuous_batting", "allow_reentry", "stealing", "foul_bunt_third_strike"] as const) if (typeof c[k] !== "boolean") reject("Invalid Diamond policy");
  if (!["disabled", "first_unoccupied_or_two_outs"].includes(c.dropped_third_strike)) reject("Invalid dropped-third-strike policy");
  for (const k of ["run_cap", "tiebreak_from", "mercy_margin", "time_limit_minutes", "pitch_limit"] as const) if (c[k] !== null && !bounded(c[k], 1, k === "time_limit_minutes" || k === "pitch_limit" ? 600 : 100)) reject("Invalid Diamond limit");
  for (const k of ["dh", "dp_flex", "courtesy_runner"] as const) if (!["none", "foundation_only"].includes(c[k])) reject("Unsupported association policy");
  if (c.tiebreak_from !== null && c.tiebreak_from <= c.regulation_innings) reject("Tiebreak must start after regulation");
  if (c.sport === "baseball" && c.dp_flex !== "none" || c.sport === "softball" && c.dh !== "none") reject("Wrong-sport policy");
}
export function initialDiamond(c: DiamondRule): DiamondState {
  validateDiamondRule(c);
  return { inning: 1, half: "top", status: "pregame", outs: 0, primary_score: 0, opponent_score: 0, half_runs: 0, batting_side: other(c.home_side), defensive_side: c.home_side, bases: [null, null, null], orders: { primary: Array<string | null>(c.lineup_size).fill(null), opponent: Array<string | null>(c.lineup_size).fill(null) }, positions: { primary: {}, opponent: {} }, used: { primary: [], opponent: [] }, cursors: { primary: 0, opponent: 0 }, pitchers: { primary: null, opponent: null }, lineup_revision: 0, pa: null, appearances: [], completed_halves: [] };
}
function closeHalf(s: DiamondState, reason: "third_out" | "run_cap") {
  s.completed_halves.push({ inning: s.inning, half: s.half, side: s.batting_side, runs: s.half_runs, outs: s.outs, reason });
  s.status = "half_complete"; s.pa = null; s.bases = [null, null, null];
}
function appearance(s: DiamondState, key: string) {
  const current = s.appearances.findLast(a => a.side === s.defensive_side && !a.ended);
  if (current?.pitcher === s.pitchers[s.defensive_side]) return;
  const boundary = { inning: s.inning, half: s.half, outs: s.outs, primary_score: s.primary_score, opponent_score: s.opponent_score };
  if (current) { current.ended = true; current.exit = { ...boundary }; }
  s.appearances.push({ key, side: s.defensive_side, pitcher: s.pitchers[s.defensive_side], entry_inning: s.inning, entry_half: s.half, inherited: s.bases.filter((r): r is DiamondRunner => r !== null).map(r => ({ ...r })), ended: false, entry: { ...boundary }, exit: null, outs_recorded: 0, batters_faced: 0 });
}
function moves(s: DiamondState, list: DiamondMove[], batter: DiamondRunner | null, result: string | null): void {
  if (!Array.isArray(list) || list.length > 4 || list.length === 0) reject("A bounded movement sequence is required");
  const sources = new Set<number>(), next = s.bases.map(r => r && { ...r });
  const scored: DiamondRunner[] = []; let outs = s.outs, nullifyRuns = false, thirdOut = false;
  for (const m of list) {
    if (!m || Object.keys(m).some(k => !["from", "to", "out", "cause", "force", "batter_before_first", "earned", "rbi"].includes(k)) || !bounded(m.from, 0, 3) || !diamondCauses.includes(m.cause) || typeof m.out !== "boolean" || typeof m.force !== "boolean" || typeof m.batter_before_first !== "boolean" || m.earned !== undefined && typeof m.earned !== "boolean" || m.rbi !== undefined && typeof m.rbi !== "boolean") reject("Invalid runner movement");
    if (sources.has(m.from)) reject("Runner origin consumed twice");
    sources.add(m.from);
    const runner = m.from === 0 ? batter : s.bases[m.from - 1];
    if (!runner) reject("Runner origin is empty");
    if (thirdOut) reject("Movement after third out is invalid");
    if (m.out) {
      if (m.to !== null || m.earned || m.rbi || m.batter_before_first && m.from !== 0) reject("Invalid out attribution");
      outs++;
      if (outs > 3) reject("More than three outs");
      if (outs === 3) { thirdOut = true; nullifyRuns = m.force || m.batter_before_first; }
    } else {
      if (!bounded(m.to, 1, 4) || m.to! <= m.from || m.force || m.batter_before_first || m.to !== 4 && (m.earned !== undefined || m.rbi !== undefined)) reject("Invalid safe advance");
      if (m.to === 4) scored.push(runner);
    }
    if (m.from > 0) next[m.from - 1] = null;
  }
  for (const m of list) if (!m.out && m.to !== 4) {
    const runner = m.from === 0 ? batter! : s.bases[m.from - 1]!;
    if (next[m.to! - 1]) reject("Two runners occupy one base");
    next[m.to! - 1] = runner;
  }
  // A surviving trailing runner cannot pass a surviving lead runner, including
  // scoring before that runner. Retired runners do not impose an endpoint.
  const endpoints = new Map<number, { to: number; order: number }>();
  for (let origin = batter ? 0 : 1; origin <= 3; origin++) {
    if (origin === 0 ? !batter : !s.bases[origin - 1]) continue;
    const index = list.findIndex(m => m.from === origin), m = list[index];
    if (!m?.out) endpoints.set(origin, { to: m?.to ?? origin, order: index });
  }
  for (const [trail, a] of endpoints) for (const [lead, b] of endpoints) {
    if (trail >= lead) continue;
    if (a.to > b.to || a.to === 4 && b.to === 4 && a.order < b.order) reject("Runner cannot pass a lead runner");
  }
  if (result !== null && !sources.has(0)) reject("Terminal PA must resolve batter-runner");
  if (result === null && sources.has(0)) reject("Standalone advance cannot invent a batter-runner");
  if (["walk", "intentional_walk", "hit_by_pitch", "catcher_interference"].includes(result ?? "")) {
    const b = list.find(m => m.from === 0)!;
    if (b.out || b.to !== 1) reject("Awarded batter must reach first");
    for (let base = 1; base <= 3 && s.bases[base - 1]; base++) {
      const forced = list.find(m => m.from === base);
      if (!forced || forced.out || forced.to !== base + 1) reject("Awarded advance must resolve forced runners");
    }
  }
  const batterMove = list.find(m => m.from === 0);
  const hitBase = ["single", "double", "triple", "home_run"].indexOf(result ?? "") + 1;
  if (hitBase > 0 && (!batterMove || batterMove.out || batterMove.to! < hitBase)) reject("Hit result contradicts batter advance");
  if (result === "home_run" && list.some(m => m.out || m.to !== 4) || result === "home_run" && s.bases.some((r, i) => r && !sources.has(i + 1))) reject("Home run must score all runners");
  if (["strikeout", "other_out", "sacrifice_fly", "sacrifice_bunt"].includes(result ?? "") && !batterMove?.out) reject("Out result requires batter retired");
  if (next.filter(Boolean).some((r, i, arr) => arr.findIndex(x => x!.key === r!.key) !== i)) reject("Duplicate runner identity");
  s.bases = next; s.outs = outs;
  const runs = nullifyRuns ? 0 : scored.length;
  if (s.batting_side === "primary") s.primary_score += runs; else s.opponent_score += runs;
  s.half_runs += runs;
}
export function diamondFinalReady(c: DiamondRule, s: DiamondState): boolean {
  if (s.inning < c.regulation_innings || s.pa) return false;
  const homeAhead = (c.home_side === "primary" ? s.primary_score : s.opponent_score) > (c.home_side === "primary" ? s.opponent_score : s.primary_score);
  return s.status === "half_complete" && s.half === "bottom" && s.primary_score !== s.opponent_score || homeAhead && (s.status === "half_complete" && s.half === "top" || s.status === "active" && s.half === "bottom");
}
export function transitionDiamond(c: DiamondRule, previous: DiamondState, fact: DiamondFact): DiamondState {
  validateDiamondRule(c);
  const s = structuredClone(previous);
  if (!fact || !["lineup_set", "half_start", "pa_start", "pitch", "play", "advance", "pitcher_change", "substitution", "fielding"].includes(fact.kind)) reject("Invalid Diamond fact");
  if (fact.kind === "lineup_set") {
    if (!["primary", "opponent"].includes(fact.side) || s.status !== "pregame" || !Array.isArray(fact.order) || fact.order.length !== c.lineup_size || fact.order.some(r => r !== null && (typeof r !== "string" || !r)) || new Set(fact.order.filter(Boolean)).size !== fact.order.filter(Boolean).length) reject("Invalid initial batting order");
    if (!fact.positions || Object.keys(fact.positions).some(k => !/^[1-9]$/.test(k)) || Object.values(fact.positions).some(v => v !== null && !fact.order.includes(v)) || fact.pitcher !== null && !fact.order.includes(fact.pitcher)) reject("Invalid defensive alignment");
    const defenders = Object.values(fact.positions).filter(Boolean);
    if (new Set(defenders).size !== defenders.length || fact.positions["1"] !== undefined && fact.positions["1"] !== fact.pitcher) reject("Defensive alignment conflicts with pitcher");
    s.orders[fact.side] = [...fact.order]; s.positions[fact.side] = { ...fact.positions }; s.pitchers[fact.side] = fact.pitcher;
    s.used[fact.side] = fact.order.filter((r): r is string => r !== null); s.lineup_revision++; return s;
  }
  if (fact.kind === "half_start") {
    if (diamondFinalReady(c, s)) reject("Ordinary game ending reached; finalize or correct");
    if (s.status !== "pregame" && s.status !== "half_complete" || s.orders.primary.length !== c.lineup_size || s.orders.opponent.length !== c.lineup_size) reject("Half cannot start");
    if (s.status === "half_complete") {
      if (s.half === "bottom") { s.inning++; s.half = "top"; } else s.half = "bottom";
    }
    if (s.inning > 99) reject("Game inning bound exceeded");
    s.batting_side = s.half === "bottom" ? c.home_side : other(c.home_side); s.defensive_side = other(s.batting_side);
    s.outs = 0; s.half_runs = 0; s.status = "active"; s.bases = [null, null, null];
    const placed = c.tiebreak_from !== null && s.inning >= c.tiebreak_from;
    if (placed !== !!fact.placed_runner) reject("Configured tiebreak runner is required only in extra innings");
    if (fact.placed_runner) {
      const r = fact.placed_runner;
      if (!r.key || r.roster_id !== null && !s.orders[s.batting_side].includes(r.roster_id)) reject("Invalid tiebreak runner");
      s.bases[1] = { key: r.key, roster_id: r.roster_id, responsible_pitcher: s.pitchers[s.defensive_side], origin: "tiebreak", placed: true };
    }
    appearance(s, `half:${s.inning}:${s.half}`); return s;
  }
  if (fact.kind === "fielding") {
    if (!["primary", "opponent"].includes(fact.side) || !["putouts", "assists", "errors", "double_plays"].includes(fact.stat) || !fact.play_event_id || fact.position !== null && !/^[1-9]$/.test(fact.position)) reject("Invalid fielding attribution");
    return s;
  }
  if (s.status !== "active") reject("Active half required");
  if (fact.kind === "pa_start") {
    if (s.pa || typeof fact.pitch_tracking !== "boolean" || !fact.key || fact.batter !== s.orders[s.batting_side][s.cursors[s.batting_side]] || fact.batter !== null && s.bases.some(r => r?.roster_id === fact.batter)) reject("Batter/order/PA is inconsistent");
    s.pa = { key: fact.key, side: s.batting_side, batter: fact.batter, pitcher: s.pitchers[s.defensive_side], inning: s.inning, half: s.half, balls: 0, strikes: 0, pitches: 0, strike_pitches: 0, pitch_coverage: fact.pitch_tracking ? "tracked" : "not_tracked", awaiting: null }; return s;
  }
  if ((fact.kind === "pitch" || fact.kind === "play") && fact.pitch_gap && s.pa && s.pa.pitch_coverage !== "not_tracked") s.pa.pitch_coverage = "partially_tracked";
  if (fact.kind === "pitch") {
    if (!s.pa || s.pa.awaiting || fact.pitch_tracking !== true || !diamondPitches.includes(fact.outcome)) reject("Pitch requires an active tracked PA");
    if (s.pa.pitch_coverage === "not_tracked") s.pa.pitch_coverage = "partially_tracked";
    s.pa.pitches++;
    if (fact.outcome === "ball") { s.pa.balls++; if (s.pa.balls === 4) s.pa.awaiting = "walk"; }
    else if (fact.outcome === "in_play") { s.pa.strike_pitches++; s.pa.awaiting = "in_play"; }
    else { s.pa.strike_pitches++; if (fact.outcome !== "foul" && (fact.outcome !== "foul_bunt" || c.foul_bunt_third_strike) || s.pa.strikes < 2) s.pa.strikes++; if (s.pa.strikes === 3) s.pa.awaiting = "strikeout"; }
    return s;
  }
  if (fact.kind === "pitcher_change") {
    if (!["primary", "opponent"].includes(fact.side) || fact.side !== s.defensive_side || !fact.key || fact.pitcher === s.pitchers[fact.side] || fact.pitcher !== null && !s.orders[fact.side].includes(fact.pitcher)) reject("Invalid eligible pitcher change");
    // Mid-PA pitcher responsibility is rules-complex: require a PA boundary.
    if (s.pa) reject("Pitcher change requires a plate-appearance boundary");
    s.pitchers[fact.side] = fact.pitcher;
    if (fact.pitcher !== null) { for (const k of Object.keys(s.positions[fact.side])) if (s.positions[fact.side][k] === fact.pitcher) delete s.positions[fact.side][k]; }
    s.positions[fact.side]["1"] = fact.pitcher; s.lineup_revision++; appearance(s, fact.key); return s;
  }
  if (fact.kind === "substitution") {
    if (!["primary", "opponent"].includes(fact.side) || !["offensive", "defensive", "pinch_hitter", "pinch_runner"].includes(fact.mode) || !fact.in_roster_id || !fact.out_roster_id || fact.in_roster_id === fact.out_roster_id || s.orders[fact.side].includes(fact.in_roster_id) || !c.allow_reentry && s.used[fact.side].includes(fact.in_roster_id)) reject("Invalid substitution/re-entry");
    const index = s.orders[fact.side].indexOf(fact.out_roster_id);
    if (index < 0 || s.pa || s.pitchers[fact.side] === fact.out_roster_id) reject("Substitution requires an eligible slot at a PA boundary; use pitcher change for pitcher");
    const runner = s.bases.find(r => r?.roster_id === fact.out_roster_id);
    if (fact.mode === "pinch_runner" ? fact.side !== s.batting_side || !runner : !!runner) reject("Runner substitution must use pinch-runner workflow");
    s.orders[fact.side][index] = fact.in_roster_id; s.used[fact.side].push(fact.in_roster_id);
    for (const k of Object.keys(s.positions[fact.side])) if (s.positions[fact.side][k] === fact.out_roster_id) s.positions[fact.side][k] = fact.in_roster_id;
    if (fact.position !== undefined) {
      if (!/^[2-9]$/.test(fact.position)) reject("Invalid fielding position");
      for (const k of Object.keys(s.positions[fact.side])) if (s.positions[fact.side][k] === fact.in_roster_id) delete s.positions[fact.side][k];
      s.positions[fact.side][fact.position] = fact.in_roster_id;
    }
    if (runner) runner.roster_id = fact.in_roster_id;
    s.lineup_revision++; return s;
  }
  const pa = s.pa;
  const priorOuts = s.outs;
  if (fact.kind === "play") {
    if (!pa || !diamondResults.includes(fact.result)) reject("Terminal result requires an active PA");
    if (pa.awaiting === "walk" && fact.result !== "walk" || pa.awaiting === "strikeout" && !["strikeout", "dropped_third_strike"].includes(fact.result) || pa.awaiting === "in_play" && ["walk", "intentional_walk", "strikeout"].includes(fact.result)) reject("Terminal result contradicts pitch count");
    if (pa.pitch_coverage === "tracked" && !pa.awaiting && !["intentional_walk", "hit_by_pitch", "catcher_interference"].includes(fact.result)) reject("Tracked PA requires terminal pitch evidence");
    if (fact.result === "dropped_third_strike" && (c.dropped_third_strike === "disabled" || s.outs < 2 && s.bases[0] !== null)) reject("Dropped third strike is not available");
    const runner: DiamondRunner = { key: pa.key, roster_id: pa.batter, responsible_pitcher: pa.pitcher, origin: fact.result === "reached_on_error" ? "error" : fact.result === "hit_by_pitch" ? "hit_by_pitch" : fact.result === "catcher_interference" ? "interference" : fact.result === "dropped_third_strike" ? "dropped_third_strike" : ["walk", "intentional_walk"].includes(fact.result) ? "walk" : "hit", placed: false };
    moves(s, fact.moves, runner, fact.result);
    s.cursors[s.batting_side] = (s.cursors[s.batting_side] + 1) % c.lineup_size; s.pa = null;
  } else if (fact.kind === "advance") {
    if (pa?.awaiting) reject("Resolve terminal PA before standalone advances");
    if (fact.moves.some(m => !["stolen_base", "caught_stealing", "pickoff", "wild_pitch", "passed_ball", "balk", "defensive_indifference", "advance_on_play"].includes(m.cause))) reject("Invalid standalone advance cause");
    if (!c.stealing && fact.moves.some(m => ["stolen_base", "caught_stealing"].includes(m.cause))) reject("Stealing is disabled");
    if (fact.moves.some(m => m.cause === "stolen_base" && m.out || ["caught_stealing", "pickoff"].includes(m.cause) && !m.out)) reject("Advance cause contradicts outcome");
    moves(s, fact.moves, null, null);
  }
  const currentAppearance = s.appearances.findLast(a => a.side === s.defensive_side && !a.ended);
  if (currentAppearance) { currentAppearance.outs_recorded += s.outs - priorOuts; if (fact.kind === "play") currentAppearance.batters_faced++; }
  if (s.outs === 3) closeHalf(s, "third_out");
  else if (c.run_cap !== null && s.half_runs >= c.run_cap) closeHalf(s, "run_cap");
  return s;
}
export function replayDiamond(c: DiamondRule, facts: readonly DiamondFact[]): DiamondState {
  return facts.reduce((s, f) => transitionDiamond(c, s, f), initialDiamond(c));
}
export function inningsPitched(outs: number): string {
  if (!bounded(outs, 0, 297)) reject("Invalid outs pitched");
  return `${Math.floor(outs / 3)}.${outs % 3}`;
}
export function battingRates(s: { ab: number; h: number; doubles: number; triples: number; hr: number; bb: number; hbp: number; sf: number }) {
  for (const v of Object.values(s)) if (!bounded(v, 0, 10000)) reject("Invalid batting totals");
  const singles = s.h - s.doubles - s.triples - s.hr;
  if (singles < 0 || s.h > s.ab) reject("Invalid hit reconciliation");
  const avg = s.ab ? s.h / s.ab : null, denominator = s.ab + s.bb + s.hbp + s.sf;
  const obp = denominator ? (s.h + s.bb + s.hbp) / denominator : null;
  const slg = s.ab ? (singles + 2 * s.doubles + 3 * s.triples + 4 * s.hr) / s.ab : null;
  return { avg, obp, slg, ops: obp !== null && slg !== null ? obp + slg : null };
}
export function isAtBat(result: string): boolean {
  if (!diamondResults.includes(result as typeof diamondResults[number])) reject("Invalid batter result");
  return !["walk", "intentional_walk", "hit_by_pitch", "sacrifice_bunt", "sacrifice_fly", "catcher_interference"].includes(result);
}
export function displayedPitchCount(pa: DiamondPA): { value: number | null; coverage: DiamondPA["pitch_coverage"] } {
  return { value: pa.pitch_coverage === "not_tracked" ? null : pa.pitches, coverage: pa.pitch_coverage };
}
