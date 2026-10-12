import type { Json } from "../supabase/database.types";
import { boundedText, collection, finiteKeys, integer, isRecord, oneOf, optionalTime, text, uuid } from "../coordination/input";
import { footballControlTypes, footballFieldsByPlay, footballRequiredByPlay, footballOperations, footballPlayTypes, footballSignedStatKeys, footballStatKeys, type Football, type FootballCapabilities, type FootballDrive, type FootballField, type FootballGame, type FootballPlay, type FootballPlayType, type FootballPlayer, type FootballSide, type FootballTeam, type FootballTotals } from "./contracts";

const base = ["game_id", "expected_version"];
export const footballRosterFields = ["roster_id", "receiver_roster_id", "defender_roster_id", "tackler_roster_id", "forced_fumble_roster_id", "recovery_roster_id", "returner_roster_id", "pass_defender_roster_id"] as const;
const boolFields = ["touchdown", "made", "touchback", "fumble", "automatic_first_down", "loss_of_down", "no_play"];
const sideFields = ["recovery_side", "result_side"];
export const footballPlayFields = [...footballRosterFields, "assisting_roster_ids", "yards", "return_yards", "kick_yards", "kick_distance", "interception_spot", ...boolFields, ...sideFields, "base_play_type", "penalty_status", "penalty_yards", "result_ball_spot", "result_down", "result_distance"] as const;
const fields: Record<typeof footballOperations[number], readonly string[]> = {
  "football.configure": [...base, "quarter_seconds", "overtime_format", "overtime_seconds", "max_overtime_periods", "play_clock_seconds", "lineup_size", "enforce_lineup", "kneel_counts_as_rush"],
  "football.period.start": base, "football.period.end": base, "football.clock.start": base, "football.clock.stop": base,
  "football.clock.set": [...base, "clock_ms", "reason"],
  "football.state.set": [...base, "side", "ball_spot", "down", "distance", "primary_direction", "reason"],
  "football.lineup.set": [...base, "side", "roster_ids"], "football.substitute": [...base, "side", "out_roster_id", "in_roster_id"],
  "football.play.add": [...base, "play_type", "side", ...footballPlayFields],
  "football.play.correct": [...base, "play_type", "side", ...footballPlayFields, "event_id", "reason"],
  "football.play.reverse": [...base, "event_id", "reason"],
};
export const footballSide = (value: unknown): value is FootballSide => oneOf(value, ["primary", "opponent"]);
const validReason = (value: unknown) => boundedText(value, 500) && value.trim().length > 0;
const ids = (value: unknown, maximum: number, minimum = 0) => Array.isArray(value) && value.length >= minimum && value.length <= maximum && value.every(uuid) && new Set(value).size === value.length;
function validPlayFields(input: Record<string, unknown>) {
  const type = input.play_type as FootballPlayType;
  const payload = Object.fromEntries(Object.entries(input).filter(([key]) => ![...base, "play_type", "side", "event_id", "reason"].includes(key)));
  if (!finiteKeys(payload, footballFieldsByPlay[type]) || footballRequiredByPlay[type]?.some(key => payload[key] === undefined)) return false;
  for (const key of footballRosterFields) if (input[key] !== undefined && !uuid(input[key])) return false;
  if (input.assisting_roster_ids !== undefined && !ids(input.assisting_roster_ids, 4)) return false;
  for (const key of boolFields) if (input[key] !== undefined && typeof input[key] !== "boolean") return false;
  for (const key of sideFields) if (input[key] !== undefined && !footballSide(input[key])) return false;
  for (const key of ["return_yards", "kick_yards", "interception_spot", "penalty_yards", "result_ball_spot"]) if (input[key] !== undefined && !integer(input[key], 0, 100)) return false;
  if (input.yards !== undefined && !integer(input.yards, -100, 100) || input.kick_distance !== undefined && !integer(input.kick_distance, 1, 100) || input.result_down !== undefined && !integer(input.result_down, 1, 4) || input.result_distance !== undefined && !integer(input.result_distance, 1, 100)) return false;
  if (input.base_play_type !== undefined && !oneOf(input.base_play_type, ["rush", "pass_complete", "sack", "none"]) || input.penalty_status !== undefined && !oneOf(input.penalty_status, ["accepted", "declined", "offsetting"])) return false;
  const result = ["result_side", "result_ball_spot", "result_down", "result_distance"];
  if (result.some(key => input[key] !== undefined) && !result.every(key => input[key] !== undefined)) return false;
  if (type === "sack" && Number(input.yards) >= 0 || type === "kneel" && Number(input.yards) > 0 || ["pass_incomplete", "spike"].includes(type) && input.yards !== undefined && input.yards !== 0 || type === "fumble" && (input.base_play_type === "sack" && Number(input.yards) >= 0 || input.base_play_type === "none" && input.yards !== 0 || input.receiver_roster_id !== undefined && input.base_play_type !== "pass_complete" || input.defender_roster_id !== undefined && input.base_play_type !== "sack")) return false;
  if (input.result_ball_spot !== undefined && (input.result_ball_spot === 100 ? !(["kickoff_return", "punt_return"].includes(type) && input.touchdown === true) : Number(input.result_distance) > 100 - Number(input.result_ball_spot))) return false;
  if (input.touchback === true && (Number(input.return_yards ?? 0) !== 0 || input.touchdown === true) || type === "penalty" && input.automatic_first_down === true && (input.loss_of_down === true || input.penalty_status === "accepted" && input.result_down !== 1)) return false;
  const assistants = Array.isArray(input.assisting_roster_ids) ? input.assisting_roster_ids : [];
  const primary = input.tackler_roster_id ?? ((type === "sack" || type === "fumble" && input.base_play_type === "sack") ? input.defender_roster_id : undefined);
  if (assistants.length && (!primary || assistants.includes(primary)) || (type === "sack" || type === "fumble" && input.base_play_type === "sack") && input.defender_roster_id && input.tackler_roster_id && input.defender_roster_id !== input.tackler_roster_id) return false;
  return true;
}
export function parseFootballCommand(value: unknown): { operation: typeof footballOperations[number]; input: Record<string, Json | undefined> } | null {
  if (!isRecord(value) || !finiteKeys(value, ["operation", "input"]) || !oneOf(value.operation, footballOperations) || !isRecord(value.input)) return null;
  const operation = value.operation as typeof footballOperations[number], input = value.input;
  if (!finiteKeys(input, fields[operation]) || !uuid(input.game_id) || !integer(input.expected_version, 1)) return null;
  if (operation === "football.configure" && (!integer(input.quarter_seconds, 60, 3600) || !oneOf(input.overtime_format, ["none", "timed", "possession"]) || !integer(input.overtime_seconds, 60, 1800) || !integer(input.max_overtime_periods, 0, 8) || !(input.play_clock_seconds === null || integer(input.play_clock_seconds, 5, 60)) || !integer(input.lineup_size, 1, 11) || typeof input.enforce_lineup !== "boolean" || typeof input.kneel_counts_as_rush !== "boolean")) return null;
  if (operation === "football.configure" && (input.overtime_format === "none") !== (input.max_overtime_periods === 0)) return null;
  if (operation === "football.clock.set" && (!integer(input.clock_ms, 0, 3600000) || !validReason(input.reason))) return null;
  if (operation === "football.state.set" && (!footballSide(input.side) || !integer(input.ball_spot, 0, 99) || !integer(input.down, 1, 4) || !integer(input.distance, 1, 100) || Number(input.distance) > 100 - Number(input.ball_spot) || !oneOf(input.primary_direction, ["increasing", "decreasing"]) || !validReason(input.reason))) return null;
  if (["football.lineup.set", "football.substitute"].includes(operation) && !footballSide(input.side)) return null;
  if (operation === "football.lineup.set" && !ids(input.roster_ids, 11, 1)) return null;
  if (operation === "football.substitute" && (!uuid(input.out_roster_id) || !uuid(input.in_roster_id) || input.out_roster_id === input.in_roster_id)) return null;
  if (["football.play.add", "football.play.correct"].includes(operation) && (!oneOf(input.play_type, footballPlayTypes) || !footballSide(input.side) || !validPlayFields(input))) return null;
  if (["football.play.correct", "football.play.reverse"].includes(operation) && (!uuid(input.event_id) || !validReason(input.reason))) return null;
  return { operation, input: input as Record<string, Json | undefined> };
}
export function projectFootballTotals(value: unknown): FootballTotals | null {
  if (!isRecord(value)) return null;
  for (const key of footballStatKeys) {
    if (key === "long_field_goal" && value[key] === null) continue;
    if (!integer(value[key], footballSignedStatKeys.includes(key) ? -Number.MAX_SAFE_INTEGER : 0, Number.MAX_SAFE_INTEGER)) return null;
  }
  return Object.fromEntries(footballStatKeys.map(key => [key, value[key]])) as FootballTotals;
}
export function projectFootballField(value: unknown): FootballField | null {
  if (!isRecord(value) || !(value.possession_side === null || footballSide(value.possession_side)) || !integer(value.ball_spot, 0, 100) || !integer(value.down, 1, 4) || !integer(value.distance, 1, 100) || !integer(value.line_to_gain, 0, 100) || value.line_to_gain !== Math.min(100, value.ball_spot + value.distance) || value.goal_to_go !== (value.line_to_gain === 100) || !oneOf(value.primary_direction, ["increasing", "decreasing"]) || !integer(value.drive_number, 0) || !oneOf(value.phase, ["scrimmage", "try", "kickoff"]) || !(value.scoring_side === null || footballSide(value.scoring_side)) || (value.phase === "try") !== footballSide(value.scoring_side)) return null;
  if (value.phase === "scrimmage" && (value.ball_spot === 100 || value.distance > 100 - value.ball_spot)) return null;
  return { possession_side: value.possession_side as FootballSide | null, ball_spot: value.ball_spot, down: value.down, distance: value.distance, line_to_gain: value.line_to_gain, goal_to_go: value.goal_to_go, primary_direction: value.primary_direction as FootballField["primary_direction"], drive_number: value.drive_number, phase: value.phase as FootballField["phase"], scoring_side: value.scoring_side as FootballSide | null };
}
type ProjectionContext = { family: boolean; visibleRosterIds: Set<string>; live: boolean; stats: boolean; playByPlay: boolean; lineups: boolean; canReviewEpochs: boolean };
export function projectFootball(value: unknown, context: ProjectionContext): Football | null {
  if (!isRecord(value) || typeof value.configured !== "boolean") return null;
  const raw = isRecord(value.capabilities) ? value.capabilities : {}, controls = !context.family && context.live;
  const capabilities: FootballCapabilities = { configure: controls && raw.configure === true, operate: controls && raw.operate === true, correct: controls && raw.correct === true, stats: context.stats && raw.stats === true, lineups: controls && context.lineups && raw.lineups === true };
  if (!value.configured) return { configured: false, capabilities: { ...capabilities, operate: false, correct: false, stats: false, lineups: false } };
  const field_state = projectFootballField(value.field_state);
  if (!field_state || value.engine_version !== "football-v1" || !integer(value.quarter_seconds, 60, 3600) || !oneOf(value.overtime_format, ["none", "timed", "possession"]) || !integer(value.overtime_seconds, 60, 1800) || !integer(value.max_overtime_periods, 0, 8) || !(value.play_clock_seconds === null || integer(value.play_clock_seconds, 5, 60)) || !integer(value.lineup_size, 1, 11) || typeof value.enforce_lineup !== "boolean" || typeof value.kneel_counts_as_rush !== "boolean" || !integer(value.period_number, 0, 12) || !oneOf(value.period_status, ["pending", "active", "ended"]) || !integer(value.clock_ms, 0, 3600000) || typeof value.clock_running !== "boolean" || typeof value.clock_observed_at !== "string" || !optionalTime(value.clock_observed_at)) return null;
  if ((value.overtime_format === "none") !== (value.max_overtime_periods === 0) || value.period_number > 4 + value.max_overtime_periods || value.clock_ms > (value.period_number > 4 ? value.overtime_seconds : value.quarter_seconds) * 1000) return null;
  const entry_roster = capabilities.operate ? collection(value.entry_roster, row => uuid(row.id) && footballSide(row.side) ? { id: row.id, side: row.side, display_name: text(row, "display_name", "Athlete", 200), jersey_number: boundedText(row.jersey_number, 30) ? row.jersey_number : null, active: row.active === true } : null, 1000) : [];
  const visible = new Set(context.visibleRosterIds); for (const row of entry_roster) visible.add(row.id);
  const player = (row: Record<string, unknown>): FootballPlayer | null => { const stats = projectFootballTotals(row.stats); return stats && uuid(row.roster_id) && visible.has(row.roster_id) && footballSide(row.side) ? { roster_id: row.roster_id, side: row.side, display_name: text(row, "display_name", "Athlete", 200), jersey_number: boundedText(row.jersey_number, 30) ? row.jersey_number : null, stats } : null; };
  const team = (row: Record<string, unknown>): FootballTeam | null => { const stats = projectFootballTotals(row.stats); return stats && footballSide(row.side) ? { side: row.side, stats } : null; };
  const play = (row: Record<string, unknown>, entry = false): FootballPlay | null => {
    if (!uuid(row.id) || !integer(row.sequence, 1) || !integer(row.origin_sequence, 1) || !integer(row.period_number, 0, 12) || !integer(row.clock_ms, 0, 3600000) || !oneOf(row.type, [...footballPlayTypes, ...footballControlTypes]) || typeof row.active !== "boolean" || ((entry || !capabilities.correct) && !row.active) || entry && !oneOf(row.type, footballPlayTypes)) return null;
    const payload: FootballPlay["payload"] = {};
    if (isRecord(row.payload)) {
      for (const key of footballRosterFields) if (uuid(row.payload[key]) && visible.has(row.payload[key])) payload[key] = row.payload[key];
      for (const key of ["assisting_roster_ids", "roster_ids"]) if (ids(row.payload[key], key === "roster_ids" ? 11 : 4)) payload[key] = (row.payload[key] as string[]).filter(id => visible.has(id));
      for (const key of boolFields) if (typeof row.payload[key] === "boolean") payload[key] = row.payload[key];
      for (const key of sideFields) if (footballSide(row.payload[key])) payload[key] = row.payload[key];
      for (const key of ["return_yards", "kick_yards", "interception_spot", "penalty_yards", "result_ball_spot"]) if (integer(row.payload[key], 0, 100)) payload[key] = row.payload[key];
      for (const [key, min, max] of [["yards", -100, 100], ["kick_distance", 1, 100], ["result_down", 1, 4], ["result_distance", 1, 100]] as const) if (integer(row.payload[key], min, max)) payload[key] = row.payload[key];
      if (oneOf(row.payload.base_play_type, ["rush", "pass_complete", "sack", "none"])) payload.base_play_type = row.payload.base_play_type;
      if (oneOf(row.payload.penalty_status, ["accepted", "declined", "offsetting"])) payload.penalty_status = row.payload.penalty_status;
    }
    return { id: row.id, sequence: row.sequence, origin_sequence: row.origin_sequence, period_number: row.period_number, clock_ms: row.clock_ms, side: footballSide(row.side) ? row.side : null, type: row.type as FootballPlay["type"], payload, before_field: projectFootballField(row.before_field), after_field: projectFootballField(row.after_field), active: row.active };
  };
  return { configured: true, engine_version: value.engine_version, quarter_seconds: value.quarter_seconds, overtime_format: value.overtime_format as FootballGame["overtime_format"], overtime_seconds: value.overtime_seconds, max_overtime_periods: value.max_overtime_periods, play_clock_seconds: value.play_clock_seconds as number | null, lineup_size: value.lineup_size, enforce_lineup: value.enforce_lineup, kneel_counts_as_rush: value.kneel_counts_as_rush, period_number: value.period_number, period_status: value.period_status as FootballGame["period_status"], clock_ms: value.clock_ms, clock_running: value.clock_running, clock_observed_at: value.clock_observed_at, field_state, capabilities, entry_roster,
    lineups: capabilities.lineups ? collection(value.lineups, row => footballSide(row.side) && ids(row.roster_ids, 11, 1) ? { side: row.side, roster_ids: (row.roster_ids as string[]).filter(id => entry_roster.some(entry => entry.id === id && entry.side === row.side)) } : null, 2) : [],
    players: capabilities.stats ? collection(value.players, player, 1000) : [], teams: capabilities.stats ? collection(value.teams, team, 2) : [],
    plays: context.playByPlay ? collection(value.plays, row => play(row), 500).sort((a, b) => a.sequence - b.sequence) : [], entry_plays: controls && (capabilities.operate || capabilities.correct) ? collection(value.entry_plays, row => play(row, true), 500).sort((a, b) => a.sequence - b.sequence) : [], more_plays: context.playByPlay && value.more_plays === true,
    drives: capabilities.stats && context.playByPlay ? collection<FootballDrive>(value.drives, row => integer(row.drive_number, 1) && footballSide(row.side) && integer(row.start_period, 0, 12) && integer(row.start_clock_ms, 0, 3600000) && integer(row.start_ball_spot, 0, 100) && (row.end_period === null || integer(row.end_period, 0, 12)) && (row.end_clock_ms === null || integer(row.end_clock_ms, 0, 3600000)) && (row.end_ball_spot === null || integer(row.end_ball_spot, 0, 100)) && integer(row.play_count, 0) ? { drive_number: row.drive_number, side: row.side, start_period: row.start_period, start_clock_ms: row.start_clock_ms, start_ball_spot: row.start_ball_spot, end_period: row.end_period as number | null, end_clock_ms: row.end_clock_ms as number | null, end_ball_spot: row.end_ball_spot as number | null, play_count: row.play_count, end_reason: boundedText(row.end_reason, 80) ? row.end_reason : null, result: boundedText(row.result, 80) ? row.result : null } : null, 100) : [],
    final_epochs: !context.family && context.canReviewEpochs && capabilities.stats ? collection(value.final_epochs, row => integer(row.epoch, 1) && integer(row.event_cutoff, 0) && integer(row.game_version, 1) && integer(row.roster_revision, 1) && row.engine_version === "football-v1" ? { epoch: row.epoch, event_cutoff: row.event_cutoff, game_version: row.game_version, roster_revision: row.roster_revision, engine_version: row.engine_version, current_authoritative: row.current_authoritative === true, players: collection(row.players, player, 1000), teams: collection(row.teams, team, 2) } : null, 100) : [] };
}
