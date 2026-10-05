import type { Json } from "../supabase/database.types";
import { boundedText, collection, finiteKeys, integer, isRecord, oneOf, text, uuid } from "../coordination/input";
import { volleyballFactTypes, volleyballOperations, volleyballOutcomes, volleyballStatKeys, type Volleyball, type VolleyballCapabilities, type VolleyballConfiguration, type VolleyballPayload, type VolleyballProfile, type VolleyballSide, type VolleyballStats } from "./contracts";
import { resolveSelection, trackingPresets } from "../stat-tracking/profile";
const side = (v: unknown): v is VolleyballSide => oneOf(v, ["primary", "opponent"]);
const ids = (v: unknown, min = 1) => Array.isArray(v) && v.length >= min && v.length <= 6 && v.every(uuid) && new Set(v).size === v.length;
const reason = (v: unknown) => boundedText(v, 500) && v.trim().length > 0;
export function parseVolleyballConfiguration(v: unknown): VolleyballConfiguration | null {
  if (!isRecord(v) || !finiteKeys(v, ["best_of", "normal_target", "deciding_target", "win_by_two", "score_cap", "court_size", "strict_rotation", "enforce_lineup", "substitution_limit", "allow_reentry", "libero_enabled", "libero_can_serve"]) || (v.best_of !== 3 && v.best_of !== 5) || !integer(v.normal_target, 2, 99) || !integer(v.deciding_target, 2, 99) || !integer(v.court_size, 1, 6)) return null;
  if (["win_by_two", "strict_rotation", "enforce_lineup", "allow_reentry", "libero_enabled", "libero_can_serve"].some(k => typeof v[k] !== "boolean") || v.strict_rotation && !v.enforce_lineup || v.libero_can_serve && !v.libero_enabled) return null;
  if (v.score_cap !== undefined && (!integer(v.score_cap, Math.max(v.normal_target, v.deciding_target), 999)) || v.substitution_limit !== undefined && !integer(v.substitution_limit, 1, 999)) return null;
  return v as VolleyballConfiguration;
}
export function validVolleyballPayload(kind: string, v: unknown): v is VolleyballPayload {
  if (!isRecord(v)) return false;
  let fields: string[] = [], required: string[] = [];
  switch (kind) {
    case "set_start": break;
    case "lineup_set": fields = ["roster_ids", "libero_roster_id"]; required = ["roster_ids"]; break;
    case "substitution": fields = ["out_roster_id", "in_roster_id"]; required = fields; break;
    case "rally":
      if (!oneOf(v.outcome, volleyballOutcomes)) return false;
      fields = v.outcome === "team_point" ? ["outcome"] : v.outcome === "assisted_block" ? ["outcome", "blocker_roster_ids"] : v.outcome === "ace" ? ["outcome", "roster_id", "receiver_roster_id"] : ["outcome", "roster_id"]; required = ["outcome"]; break;
    case "assist": fields = ["roster_id", "kill_event_id"]; required = ["kill_event_id"]; break;
    case "attack_attempt": case "dig": case "reception": case "blocking_error": fields = ["roster_id"]; break;
    default: return false;
  }
  if (!finiteKeys(v, fields) || required.some(k => v[k] === undefined)) return false;
  for (const [k, val] of Object.entries(v)) if (k !== "outcome" && !(["roster_ids", "blocker_roster_ids"].includes(k) ? ids(val, k === "blocker_roster_ids" ? 2 : 1) : uuid(val))) return false;
  return !(kind === "substitution" && v.out_roster_id === v.in_roster_id);
}
export function parseVolleyballCommand(v: unknown): { operation: typeof volleyballOperations[number]; input: Record<string, Json | undefined> } | null {
  if (!isRecord(v) || !finiteKeys(v, ["operation", "input"]) || !oneOf(v.operation, volleyballOperations) || !isRecord(v.input)) return null;
  const input = v.input, op = v.operation as typeof volleyballOperations[number], base = ["game_id", "expected_version"];
  const extra = op === "volleyball.configure" ? ["configuration"] : op === "volleyball.event.reverse" ? ["event_id", "reason"] : op === "volleyball.set.start" ? ["side"] : ["side", "payload", ...(op.startsWith("volleyball.event.") ? ["event_type"] : []), ...(op === "volleyball.event.correct" ? ["event_id", "reason"] : [])];
  if (!finiteKeys(input, [...base, ...extra]) || [...base, ...extra].some(k => input[k] === undefined) || !uuid(input.game_id) || !integer(input.expected_version, 1)) return null;
  if (op === "volleyball.configure") { if (!parseVolleyballConfiguration(input.configuration)) return null; }
  else if (op === "volleyball.event.reverse") { if (!uuid(input.event_id) || !reason(input.reason)) return null; }
  else {
    if (!side(input.side)) return null;
    const kind = op === "volleyball.set.start" ? "set_start" : op === "volleyball.lineup.set" ? "lineup_set" : op === "volleyball.substitute" ? "substitution" : input.event_type;
    if (typeof kind !== "string" || !validVolleyballPayload(kind, op === "volleyball.set.start" ? {} : input.payload)) return null;
    if (op === "volleyball.event.correct" && (!uuid(input.event_id) || !reason(input.reason))) return null;
  }
  return { operation: op, input: input as Record<string, Json | undefined> };
}
export function projectVolleyballStats(v: unknown): VolleyballStats | null {
  if (!isRecord(v)) return null;
  const result = {} as VolleyballStats;
  for (const k of volleyballStatKeys) {
    const row = v[k];
    if (!isRecord(row) || !oneOf(row.coverage, ["tracked", "not_tracked", "partially_tracked"]) || !oneOf(row.reason, ["declared", "legacy_unknown"])) return null;
    const n = row.recorded_value;
    if (n !== null && !(k === "hitting_percentage" ? typeof n === "number" && Number.isFinite(n) && n >= -1 && n <= 1 : integer(n, 0, 1000000)) || row.coverage === "not_tracked" && n !== null) return null;
    result[k] = { recorded_value: n as number | null, coverage: row.coverage as VolleyballStats[typeof k]["coverage"], reason: row.reason as VolleyballStats[typeof k]["reason"] };
  }
  return result;
}
export function projectVolleyball(v: unknown, context: { family: boolean; visibleRosterIds: string[]; live: boolean; stats: boolean; lineups: boolean; playByPlay: boolean; canReviewEpochs: boolean }): Volleyball | null {
  if (!isRecord(v) || !isRecord(v.capabilities)) return null;
  const caps: VolleyballCapabilities = { configure: !context.family && context.live && v.capabilities.configure === true, operate: !context.family && context.live && v.capabilities.operate === true, correct: !context.family && context.live && v.capabilities.correct === true, stats: context.stats && v.capabilities.stats === true, lineups: !context.family && context.live && context.lineups && v.capabilities.lineups === true };
  if (v.configured === false) return { configured: false, capabilities: caps };
  const config = parseVolleyballConfiguration(v.configuration), s = v.state;
  if (!config || v.configured !== true || v.engine_version !== "volleyball-v1" || !isRecord(s) || !integer(s.set_number, 0, 5) || !oneOf(s.set_status, ["pending", "active", "completed", "match_complete"]) || !["primary_points", "opponent_points", "primary_sets", "opponent_sets", "service_sequence"].every(k => integer(s[k], 0, 1000000)) || !(s.serving_side === null || side(s.serving_side)) || !isRecord(v.tracking)) return null;
  const tracking = {} as Record<VolleyballSide, VolleyballProfile>;
  for (const key of ["primary", "opponent"] as const) {
    const p = v.tracking[key];
    if (!isRecord(p) || !uuid(p.snapshot_id) || !isRecord(p.selection) || !oneOf(p.selection.preset, trackingPresets) || !Array.isArray(p.selection.enabled) || !p.selection.enabled.every(k => typeof k === "string") || !Array.isArray(p.selection.quick) || !p.selection.quick.every(k => typeof k === "string")) return null;
    try { const selection = resolveSelection("volleyball", "custom", p.selection.enabled, p.selection.quick); tracking[key] = { snapshot_id: p.snapshot_id, selection: { ...selection, preset: p.selection.preset as typeof trackingPresets[number] }, can_manage: !context.family && context.live && p.can_manage === true, profile_version: integer(p.profile_version, 0) ? p.profile_version : 0 }; } catch { return null; }
  }
  const entries = !context.family && (caps.operate || caps.correct) ? collection(v.entry_roster, r => uuid(r.id) && side(r.side) ? { id: r.id, side: r.side, display_name: text(r, "display_name", "Athlete", 200), jersey_number: boundedText(r.jersey_number, 30) ? r.jersey_number : null, active: r.active === true } : null, 500) : [];
  const allowed = new Set([...context.visibleRosterIds, ...entries.map(r => r.id)]), lineups: Record<VolleyballSide, string[]> = { primary: [], opponent: [] };
  for (const key of ["primary", "opponent"] as const) if (!context.family && isRecord(v.lineups) && Array.isArray(v.lineups[key])) lineups[key] = v.lineups[key].filter((id): id is string => uuid(id) && allowed.has(id)).slice(0, 6);
  const players = caps.stats ? collection(v.players, r => uuid(r.roster_id) && allowed.has(r.roster_id) && side(r.side) && projectVolleyballStats(r.stats) ? { roster_id: r.roster_id, side: r.side, display_name: text(r, "display_name", "Athlete", 200), jersey_number: boundedText(r.jersey_number, 30) ? r.jersey_number : null, stats: projectVolleyballStats(r.stats)! } : null, 500) : [];
  const teams = caps.stats ? collection(v.teams, r => side(r.side) && projectVolleyballStats(r.stats) ? { side: r.side, stats: projectVolleyballStats(r.stats)! } : null, 2) : [];
  const plays = context.playByPlay || caps.operate || caps.correct ? collection(v.plays, r => {
    if (!uuid(r.id) || !integer(r.sequence, 1) || !integer(r.origin_sequence, 1) || !side(r.side) || !oneOf(r.event_type, volleyballFactTypes) || !isRecord(r.payload)) return null;
    const p: VolleyballPayload = {};
    for (const k of ["outcome", "kill_event_id"]) if (typeof r.payload[k] === "string" && (k === "outcome" ? oneOf(r.payload[k], volleyballOutcomes) : uuid(r.payload[k]))) p[k] = r.payload[k];
    for (const k of ["roster_id", "receiver_roster_id", "libero_roster_id", "out_roster_id", "in_roster_id"]) if (uuid(r.payload[k]) && allowed.has(r.payload[k])) p[k] = r.payload[k];
    for (const k of ["roster_ids", "blocker_roster_ids"]) if (Array.isArray(r.payload[k])) p[k] = r.payload[k].filter((id): id is string => uuid(id) && allowed.has(id)).slice(0, 6);
    return { id: r.id, sequence: r.sequence, origin_sequence: r.origin_sequence, ...(integer(r.set_number, 0, 5) && integer(r.primary_points, 0, 1000000) && integer(r.opponent_points, 0, 1000000) ? { set_number: r.set_number, primary_points: r.primary_points, opponent_points: r.opponent_points } : {}), event_type: r.event_type as typeof volleyballFactTypes[number], side: r.side, payload: p, active: r.active === true };
  }, 500) : [];
  return { configured: true, server_roster_id: !context.family && config.strict_rotation && uuid(v.server_roster_id) && allowed.has(v.server_roster_id) ? v.server_roster_id : null, engine_version: "volleyball-v1", configuration: config, capabilities: caps, state: { set_number: s.set_number, set_status: s.set_status as "pending" | "active" | "completed" | "match_complete", primary_points: s.primary_points as number, opponent_points: s.opponent_points as number, primary_sets: s.primary_sets as number, opponent_sets: s.opponent_sets as number, serving_side: s.serving_side, service_sequence: s.service_sequence as number, sets: collection(s.sets, r => integer(r.number, 1, 5) && integer(r.primary_points, 0, 1000000) && integer(r.opponent_points, 0, 1000000) && side(r.winner) ? { number: r.number, primary_points: r.primary_points, opponent_points: r.opponent_points, winner: r.winner, deciding: r.deciding === true } : null, 5) }, entry_roster: entries, lineups, tracking, players, teams, plays, final_epochs: !context.family && context.canReviewEpochs ? collection(v.final_epochs, r => integer(r.epoch, 1) && integer(r.event_cutoff, 1) ? { epoch: r.epoch, event_cutoff: r.event_cutoff, current_authoritative: r.current_authoritative === true } : null, 100) : [] };
}
