import { boundedText, collection, finiteKeys, integer, isRecord, oneOf, text, uuid } from "../coordination/input";
import { resolveSelection, trackingPresets } from "../stat-tracking/profile";
import type { Json } from "../supabase/database.types";
import { diamondCauses, diamondOperations, diamondPitches, diamondResults, diamondSports, diamondStatKeys, type DiamondFact, type DiamondRule, type DiamondSide, type DiamondState, type DiamondView } from "./contracts";
import { validateDiamondRule } from "./reducer";

const nullableId = (v: unknown) => v === null || uuid(v);
const side = (v: unknown): v is DiamondSide => oneOf(v, ["primary", "opponent"]);
const reason = (v: unknown) => boundedText(v, 500) && !!v.trim() && !Array.from(v).some(c => c.charCodeAt(0) < 32 || c.charCodeAt(0) === 127);
export function parseDiamondRule(value: unknown): DiamondRule | null {
  if (!isRecord(value)) return null;
  try { validateDiamondRule(value as DiamondRule); return value as DiamondRule; } catch { return null; }
}
export function validDiamondFact(v: unknown, corrected = false): boolean {
  if (!isRecord(v) || typeof v.kind !== "string") return false;
  let fields: string[], required: string[];
  switch (v.kind) {
    case "lineup_set":
      fields = ["kind", "side", "order", "positions", "pitcher"]; required = fields;
      if (!side(v.side) || !Array.isArray(v.order) || !v.order.length || v.order.length > 30 || !v.order.every(nullableId) || !isRecord(v.positions) || !Object.entries(v.positions).every(([k, id]) => /^[1-9]$/.test(k) && nullableId(id)) || !nullableId(v.pitcher)) return false;
      break;
    case "half_start":
      fields = ["kind", "placed_runner"]; required = ["kind"];
      if (v.placed_runner !== undefined && (!isRecord(v.placed_runner) || !finiteKeys(v.placed_runner, ["key", "roster_id"]) || !uuid(v.placed_runner.key) || !nullableId(v.placed_runner.roster_id))) return false;
      break;
    case "pa_start":
      fields = ["kind", "key", "batter", ...(corrected ? ["pitch_tracking"] : [])]; required = fields;
      if (!uuid(v.key) || !nullableId(v.batter) || corrected && typeof v.pitch_tracking !== "boolean") return false;
      break;
    case "pitch":
      fields = ["kind", "outcome", ...(corrected ? ["pitch_tracking", "pitch_gap"] : [])]; required = fields.filter(k => k !== "pitch_gap");
      if (v.pitch_gap !== undefined && typeof v.pitch_gap !== "boolean") return false;
      if (!oneOf(v.outcome, diamondPitches) || corrected && typeof v.pitch_tracking !== "boolean") return false;
      break;
    case "play": case "advance":
      fields = ["kind", "moves", ...(v.kind === "play" ? ["result", ...(corrected ? ["pitch_gap"] : [])] : [])]; required = fields.filter(k => k !== "pitch_gap");
      if (v.pitch_gap !== undefined && typeof v.pitch_gap !== "boolean") return false;
      if (v.kind === "play" && !oneOf(v.result, diamondResults) || !Array.isArray(v.moves) || !v.moves.length || v.moves.length > 4) return false;
      for (const m of v.moves) if (!isRecord(m) || !finiteKeys(m, ["from", "to", "out", "cause", "force", "batter_before_first", "earned", "rbi"]) || !integer(m.from, v.kind === "play" ? 0 : 1, 3) || !(m.to === null || integer(m.to, 1, 4)) || !oneOf(m.cause, diamondCauses) || ["out", "force", "batter_before_first"].some(k => typeof m[k] !== "boolean") || m.earned !== undefined && typeof m.earned !== "boolean" || m.rbi !== undefined && typeof m.rbi !== "boolean") return false;
      break;
    case "pitcher_change":
      fields = ["kind", "side", "pitcher", "key"]; required = fields;
      if (!side(v.side) || !nullableId(v.pitcher) || !uuid(v.key)) return false;
      break;
    case "fielding":
      fields = ["kind", "side", "roster_id", "position", "stat", "play_event_id"]; required = fields;
      if (!side(v.side) || !nullableId(v.roster_id) || !(v.position === null || typeof v.position === "string" && /^[1-9]$/.test(v.position)) || !oneOf(v.stat, ["putouts", "assists", "errors", "double_plays"]) || !uuid(v.play_event_id)) return false;
      break;
    case "substitution":
      fields = ["kind", "side", "out_roster_id", "in_roster_id", "mode", "position"]; required = fields.filter(k => k !== "position");
      if (!side(v.side) || !uuid(v.out_roster_id) || !uuid(v.in_roster_id) || !oneOf(v.mode, ["offensive", "defensive", "pinch_hitter", "pinch_runner"]) || v.position !== undefined && (typeof v.position !== "string" || !/^[2-9]$/.test(v.position))) return false;
      break;
    default: return false;
  }
  return finiteKeys(v, fields) && required.every(k => v[k] !== undefined);
}
export function parseDiamondCommand(v: unknown): { operation: typeof diamondOperations[number]; input: Record<string, Json | undefined> } | null {
  if (!isRecord(v) || !finiteKeys(v, ["operation", "input"]) || !oneOf(v.operation, diamondOperations) || !isRecord(v.input)) return null;
  const op = v.operation as typeof diamondOperations[number], i = v.input;
  const extra = op === "diamond.configure" ? ["configuration"] : op === "diamond.event.reverse" ? ["event_id", "reason"] : ["payload", ...(op === "diamond.event.correct" ? ["event_id", "reason"] : [])];
  const fields = ["game_id", "sport_key", "expected_version", ...extra];
  if (!finiteKeys(i, fields) || fields.some(k => i[k] === undefined) || !uuid(i.game_id) || !oneOf(i.sport_key, diamondSports) || !integer(i.expected_version, 1)) return null;
  if (op === "diamond.configure") { const c = parseDiamondRule(i.configuration); if (!c || c.sport !== i.sport_key) return null; }
  else if (op === "diamond.event.reverse") { if (!uuid(i.event_id) || !reason(i.reason)) return null; }
  else {
    if (!validDiamondFact(i.payload, op === "diamond.event.correct")) return null;
    if (op === "diamond.event.correct") { if (!uuid(i.event_id) || !reason(i.reason)) return null; }
    else {
      const kinds: Partial<Record<typeof diamondOperations[number], DiamondFact["kind"]>> = { "diamond.lineup.set": "lineup_set", "diamond.pa.start": "pa_start", "diamond.pitch.add": "pitch", "diamond.play.add": "play", "diamond.runner.advance": "advance", "diamond.substitute": "substitution", "diamond.pitcher.change": "pitcher_change", "diamond.half.start": "half_start", "diamond.fielding.add": "fielding" };
      if (!isRecord(i.payload) || kinds[op] !== i.payload.kind) return null;
    }
  }
  return { operation: op, input: i as Record<string, Json | undefined> };
}
function coveredStats(v: unknown): DiamondView["teams"][number]["stats"] {
  const output: DiamondView["teams"][number]["stats"] = {};
  if (!isRecord(v)) return output;
  for (const k of diamondStatKeys) {
    const item = v[k];
    if (!isRecord(item) || !oneOf(item.coverage, ["tracked", "not_tracked", "partially_tracked"]) || !(item.recorded_value === null || typeof item.recorded_value === "number" && Number.isFinite(item.recorded_value) && item.recorded_value >= 0)) continue;
    output[k] = { recorded_value: item.coverage === "not_tracked" ? null : item.recorded_value as number | null, coverage: item.coverage as "tracked" | "not_tracked" | "partially_tracked" };
  }
  return output;
}
export function projectDiamond(v: unknown, context: { sport: string; family: boolean; visibleRosterIds: readonly string[]; live: boolean; stats: boolean; lineups: boolean; canReviewEpochs: boolean }): DiamondView | null {
  if (!isRecord(v) || v.sport_key !== context.sport || !oneOf(v.sport_key, diamondSports) || typeof v.configured !== "boolean" || !isRecord(v.capabilities)) return null;
  const caps = { configure: !context.family && context.live && v.capabilities.configure === true, operate: !context.family && context.live && v.capabilities.operate === true, correct: !context.family && context.live && v.capabilities.correct === true, stats: context.stats && v.capabilities.stats === true, lineups: !context.family && context.live && context.lineups && v.capabilities.lineups === true };
  const empty: DiamondView = { configured: v.configured, sport_key: v.sport_key as DiamondView["sport_key"], capabilities: caps, entry_roster: [], players: [], teams: [], plays: [], final_epochs: [], tracking: {} };
  if (!v.configured) return empty;
  const c = parseDiamondRule(v.configuration), s = v.state;
  if (!c || c.sport !== v.sport_key || v.engine_version !== "diamond-v1" || !isRecord(s) || !integer(s.inning, 1, 99) || !oneOf(s.half, ["top", "bottom"]) || !oneOf(s.status, ["pregame", "active", "half_complete"]) || !integer(s.outs, 0, 3) || !integer(s.primary_score, 0) || !integer(s.opponent_score, 0) || !side(s.batting_side) || !side(s.defensive_side) || s.batting_side === s.defensive_side || !Array.isArray(s.bases) || s.bases.length !== 3 || !isRecord(s.orders) || !isRecord(s.positions) || !isRecord(s.pitchers) || !isRecord(s.cursors) || !integer(s.lineup_revision, 0) || !Array.isArray(s.completed_halves) || !Array.isArray(s.appearances)) return null;
  const allowed = new Set(context.visibleRosterIds);
  const entry = !context.family && (caps.operate || caps.correct) ? collection(v.entry_roster, row => uuid(row.id) && side(row.side) && typeof row.active === "boolean" ? { id: row.id, side: row.side, display_name: text(row, "display_name", "Athlete", 200), jersey_number: typeof row.jersey_number === "string" ? row.jersey_number.slice(0, 20) : null, active: row.active } : null, 400) : [];
  for (const row of entry) allowed.add(row.id);
  const mask = (value: unknown, identities = false): unknown => {
    if (Array.isArray(value)) return value.map(x => mask(x, identities));
    if (isRecord(value)) return Object.fromEntries(Object.entries(value).map(([k, x]) => [k, mask(x, identities || ["order", "orders", "positions", "used", "pitchers", "batter", "pitcher", "roster_id", "responsible_pitcher", "in_roster_id", "out_roster_id"].includes(k))]));
    return identities && typeof value === "string" && !allowed.has(value) ? null : value;
  };
  const tracking: DiamondView["tracking"] = {};
  for (const sd of ["primary", "opponent"] as const) {
    const p = isRecord(v.tracking) ? v.tracking[sd] : null;
    if (!isRecord(p) || !isRecord(p.selection) || !oneOf(p.selection.preset, trackingPresets) || !Array.isArray(p.selection.enabled) || !p.selection.enabled.every(k => typeof k === "string") || !Array.isArray(p.selection.quick) || !p.selection.quick.every(k => typeof k === "string")) continue;
    try { tracking[sd] = { selection: { ...resolveSelection(c.sport, "custom", p.selection.enabled, p.selection.quick), preset: p.selection.preset as typeof trackingPresets[number] }, coverage: isRecord(p.coverage) ? p.coverage : {}, profile_version: !context.family && integer(p.profile_version, 0) ? p.profile_version : 0, can_manage: !context.family && p.can_manage === true }; } catch { /* invalid declarations never become entry expectations */ }
  }
  const plays = context.live ? collection(v.plays, row => uuid(row.id) && integer(row.sequence, 1) && integer(row.origin_sequence, 1, row.sequence) && typeof row.event_type === "string" && isRecord(row.payload) && integer(row.inning, 1, 99) && oneOf(row.half, ["top", "bottom"]) && side(row.batting_side) && integer(row.outs, 0, 3) && integer(row.runs, 0, 4) ? { id: row.id, sequence: row.sequence, origin_sequence: row.origin_sequence, event_type: row.event_type, inning: row.inning, half: row.half as "top" | "bottom", batting_side: row.batting_side, outs: row.outs, runs: row.runs, payload: mask(row.payload) as Record<string, Json> } : null, 500) : [];
  return { ...empty, engine_version: "diamond-v1", configuration: c, state: mask(s) as DiamondState, entry_roster: entry,
    players: caps.stats ? collection(v.players, row => uuid(row.roster_id) && allowed.has(row.roster_id) && side(row.side) ? { roster_id: row.roster_id, side: row.side, display_name: text(row, "display_name", "Athlete", 200), stats: coveredStats(row.stats) } : null, 400) : [],
    teams: caps.stats ? collection(v.teams, row => side(row.side) ? { side: row.side, stats: coveredStats(row.stats) } : null, 2) : [],
    plays, tracking, final_epochs: !context.family && context.canReviewEpochs ? collection(v.final_epochs, row => integer(row.epoch, 1) && typeof row.current_authoritative === "boolean" ? { epoch: row.epoch, current_authoritative: row.current_authoritative } : null, 100) : [],
  };
}
