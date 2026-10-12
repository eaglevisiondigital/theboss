import type { Json } from "../supabase/database.types";
import { boundedText, collection, finiteKeys, integer, isRecord, oneOf, optionalTime, text, uuid } from "../coordination/input";
import { soccerControlTypes, soccerOperations, soccerPlayTypes, soccerStatKeys, type Soccer, type SoccerCapabilities, type SoccerGame, type SoccerPlayer, type SoccerPlay, type SoccerSide, type SoccerTeam, type SoccerTotals } from "./contracts";

const base = ["game_id", "expected_version"], event = ["event_type", "side", "roster_id", "goalkeeper_roster_id", "scoring_event_id"];
const fields: Record<typeof soccerOperations[number], readonly string[]> = {
  "soccer.configure": [...base, "regulation_segments", "segment_seconds", "extra_time_segments", "extra_time_seconds", "lineup_size", "enforce_lineup", "allow_reentry", "max_substitutions"],
  "soccer.segment.start": base, "soccer.segment.end": base, "soccer.clock.start": base, "soccer.clock.stop": base,
  "soccer.clock.set": [...base, "clock_ms", "reason"], "soccer.added_time.set": [...base, "added_time_seconds", "reason"],
  "soccer.lineup.set": [...base, "side", "roster_ids", "goalkeeper_roster_id"], "soccer.keeper.set": [...base, "side", "goalkeeper_roster_id"],
  "soccer.substitute": [...base, "side", "out_roster_id", "in_roster_id", "goalkeeper_roster_id"],
  "soccer.event.add": [...base, ...event], "soccer.event.correct": [...base, ...event, "event_id", "reason", "out_roster_id", "in_roster_id"], "soccer.event.reverse": [...base, "event_id", "reason"],
};
const validReason = (value: unknown) => boundedText(value, 500) && value.trim().length > 0;
const side = (value: unknown): value is SoccerSide => oneOf(value, ["primary", "opponent"]);
const ids = (value: unknown, max = 11) => Array.isArray(value) && value.length <= max && value.every(uuid) && new Set(value).size === value.length;
export function parseSoccerCommand(value: unknown): { operation: typeof soccerOperations[number]; input: Record<string, Json | undefined> } | null {
  if (!isRecord(value) || !finiteKeys(value, ["operation", "input"]) || !oneOf(value.operation, soccerOperations) || !isRecord(value.input)) return null;
  const operation = value.operation as typeof soccerOperations[number], input = value.input;
  if (!finiteKeys(input, fields[operation]) || !uuid(input.game_id) || !integer(input.expected_version, 1)) return null;
  if (operation === "soccer.configure" && (![2, 4].includes(input.regulation_segments as number) || !integer(input.segment_seconds, 60, 5400) || ![0, 2].includes(input.extra_time_segments as number) || !integer(input.extra_time_seconds, 60, 1800) || !integer(input.lineup_size, 1, 11) || typeof input.enforce_lineup !== "boolean" || typeof input.allow_reentry !== "boolean" || !(input.max_substitutions === null || integer(input.max_substitutions, 0, 100)))) return null;
  if (operation === "soccer.clock.set" && (!integer(input.clock_ms, 0, 7_200_000) || !validReason(input.reason))) return null;
  if (operation === "soccer.added_time.set" && (!integer(input.added_time_seconds, 0, 1800) || !validReason(input.reason))) return null;
  if (["soccer.lineup.set", "soccer.keeper.set", "soccer.substitute"].includes(operation) && !side(input.side)) return null;
  if (operation === "soccer.lineup.set" && !ids(input.roster_ids)) return null;
  if (input.goalkeeper_roster_id !== undefined && !uuid(input.goalkeeper_roster_id)) return null;
  if (operation === "soccer.keeper.set" && !uuid(input.goalkeeper_roster_id)) return null;
  if (operation === "soccer.substitute" && (!uuid(input.out_roster_id) || !uuid(input.in_roster_id) || input.out_roster_id === input.in_roster_id)) return null;
  if (operation === "soccer.event.add" || operation === "soccer.event.correct") {
    if (!oneOf(input.event_type, operation === "soccer.event.correct" ? [...soccerPlayTypes, "keeper_set", "substitution"] : soccerPlayTypes) || !side(input.side)) return null;
    if (input.roster_id !== undefined && !uuid(input.roster_id)) return null;
    if (["assist", "second_yellow"].includes(input.event_type) && !uuid(input.roster_id)) return null;
    if (input.event_type === "assist" ? !uuid(input.scoring_event_id) : input.scoring_event_id !== undefined) return null;
    if (!["shot_saved", "penalty_saved", "keeper_set", "substitution"].includes(input.event_type) && input.goalkeeper_roster_id !== undefined) return null;
    if (input.event_type === "keeper_set" && (!uuid(input.goalkeeper_roster_id) || input.roster_id !== undefined)) return null;
    if (input.event_type === "substitution" ? !uuid(input.out_roster_id) || !uuid(input.in_roster_id) || input.out_roster_id === input.in_roster_id || input.roster_id !== undefined : input.out_roster_id !== undefined || input.in_roster_id !== undefined) return null;
  }
  if (["soccer.event.correct", "soccer.event.reverse"].includes(operation) && (!uuid(input.event_id) || !validReason(input.reason))) return null;
  return { operation, input: input as Record<string, Json | undefined> };
}

function totals(row: Record<string, unknown>): SoccerTotals | null {
  if (!soccerStatKeys.every(key => integer(row[key], 0, Number.MAX_SAFE_INTEGER)) || !(row.goals_allowed === null || integer(row.goals_allowed)) || !(row.minutes === null || typeof row.minutes === "number" && Number.isFinite(row.minutes) && row.minutes >= 0 && row.minutes <= 1440) || !(row.clean_sheet === null || typeof row.clean_sheet === "boolean")) return null;
  return { ...Object.fromEntries(soccerStatKeys.map(key => [key, row[key]])), goals_allowed: row.goals_allowed, minutes: row.minutes, clean_sheet: row.clean_sheet } as SoccerTotals;
}
type ProjectionContext = { family: boolean; visibleRosterIds: Set<string>; live: boolean; stats: boolean; playByPlay: boolean; lineups: boolean; canReviewEpochs: boolean };
export function projectSoccer(value: unknown, context: ProjectionContext): Soccer | null {
  if (!isRecord(value) || typeof value.configured !== "boolean") return null;
  const raw = isRecord(value.capabilities) ? value.capabilities : {}, controls = !context.family && context.live;
  const capabilities: SoccerCapabilities = { configure: controls && raw.configure === true, operate: controls && raw.operate === true, correct: controls && raw.correct === true, stats: context.stats && raw.stats === true, lineups: controls && context.lineups && raw.lineups === true };
  if (!value.configured) return { configured: false, capabilities: { ...capabilities, operate: false, correct: false, stats: false, lineups: false } };
  if (value.engine_version !== "soccer-v1" || ![2, 4].includes(value.regulation_segments as number) || !integer(value.segment_seconds, 60, 5400) || ![0, 2].includes(value.extra_time_segments as number) || !integer(value.extra_time_seconds, 60, 1800) || !integer(value.lineup_size, 1, 11) || typeof value.enforce_lineup !== "boolean" || typeof value.allow_reentry !== "boolean" || !(value.max_substitutions === null || integer(value.max_substitutions, 0, 100)) || !integer(value.segment_number, 0, 6) || !integer(value.extra_time_number, 0, 2) || !oneOf(value.segment_status, ["pending", "active", "ended"]) || !integer(value.clock_ms, 0, 7_200_000) || !integer(value.display_clock_ms, 0, 28_800_000) || !integer(value.playing_ms, 0, 43_200_000) || typeof value.clock_running !== "boolean" || !optionalTime(value.clock_observed_at) || !integer(value.added_time_seconds, 0, 1800) || typeof value.participation_complete !== "boolean") return null;
  const entryRoster = capabilities.operate ? collection(value.entry_roster, row => uuid(row.id) && side(row.side) ? { id: row.id, side: row.side, display_name: text(row, "display_name", "Athlete", 200), jersey_number: boundedText(row.jersey_number, 30) ? row.jersey_number : null, active: row.active === true } : null, 1000) : [];
  const visible = new Set(context.visibleRosterIds); for (const entry of entryRoster) visible.add(entry.id);
  const player = (row: Record<string, unknown>): SoccerPlayer | null => { const stats = totals(row); return stats && uuid(row.roster_id) && visible.has(row.roster_id) && side(row.side) ? { ...stats, roster_id: row.roster_id, side: row.side, display_name: text(row, "display_name", "Athlete", 200), jersey_number: boundedText(row.jersey_number, 30) ? row.jersey_number : null } : null; };
  const team = (row: Record<string, unknown>): SoccerTeam | null => { const stats = totals(row); return stats && side(row.side) ? { ...stats, side: row.side } : null; };
  const projectPlay = (row: Record<string, unknown>, activeOnly = false): SoccerPlay | null => {
    if (!uuid(row.id) || !integer(row.sequence, 1) || !integer(row.segment_number, 0, 6) || !integer(row.clock_ms, 0, 7_200_000) || !integer(row.display_clock_ms, 0, 28_800_000) || !integer(row.playing_ms, 0, 43_200_000) || !oneOf(row.event_type, [...soccerPlayTypes, ...soccerControlTypes]) || typeof row.active !== "boolean" || ((activeOnly || !capabilities.correct) && !row.active)) return null;
    if (activeOnly && !oneOf(row.event_type, [...soccerPlayTypes, "keeper_set", "substitution"])) return null;
    const named = uuid(row.roster_id) && visible.has(row.roster_id);
    return { id: row.id, sequence: row.sequence, segment_number: row.segment_number, clock_ms: row.clock_ms, display_clock_ms: row.display_clock_ms, playing_ms: row.playing_ms, side: side(row.side) ? row.side : null, event_type: row.event_type as SoccerPlay["event_type"], display_name: named && boundedText(row.display_name, 200) ? row.display_name : null, jersey_number: named && boundedText(row.jersey_number, 30) ? row.jersey_number : null, roster_id: named ? row.roster_id as string : null, goalkeeper_roster_id: !context.family && uuid(row.goalkeeper_roster_id) && visible.has(row.goalkeeper_roster_id) ? row.goalkeeper_roster_id : null, scoring_event_id: !context.family && uuid(row.scoring_event_id) ? row.scoring_event_id : null, active: row.active };
  };
  const plays = context.playByPlay ? collection<SoccerPlay>(value.plays, row => projectPlay(row), 500).sort((a, b) => a.sequence - b.sequence) : [];
  const entryPlays = controls && (capabilities.operate || capabilities.correct) ? collection<SoccerPlay>(value.entry_plays, row => projectPlay(row, true), 500).sort((a, b) => a.sequence - b.sequence) : [];
  return { configured: true, engine_version: value.engine_version, regulation_segments: value.regulation_segments as 2 | 4, segment_seconds: value.segment_seconds, extra_time_segments: value.extra_time_segments as 0 | 2, extra_time_seconds: value.extra_time_seconds, lineup_size: value.lineup_size, enforce_lineup: value.enforce_lineup, allow_reentry: value.allow_reentry, max_substitutions: value.max_substitutions, segment_number: value.segment_number, extra_time_number: value.extra_time_number, segment_status: value.segment_status as SoccerGame["segment_status"], clock_ms: value.clock_ms, display_clock_ms: value.display_clock_ms, playing_ms: value.playing_ms, clock_running: value.clock_running, clock_observed_at: value.clock_observed_at as string, added_time_seconds: value.added_time_seconds, participation_complete: value.participation_complete, capabilities, entry_roster: entryRoster,
    lineups: capabilities.lineups ? collection(value.lineups, row => side(row.side) && ids(row.roster_ids) && ids(row.dismissed_roster_ids, 1000) ? { side: row.side, roster_ids: (row.roster_ids as string[]).filter(id => entryRoster.some(entry => entry.id === id && entry.side === row.side)), goalkeeper_roster_id: uuid(row.goalkeeper_roster_id) && entryRoster.some(entry => entry.id === row.goalkeeper_roster_id && entry.side === row.side) ? row.goalkeeper_roster_id : null, dismissed_roster_ids: (row.dismissed_roster_ids as string[]).filter(id => entryRoster.some(entry => entry.id === id && entry.side === row.side)) } : null, 2) : [],
    players: capabilities.stats ? collection(value.players, player, 1000) : [], teams: capabilities.stats ? collection(value.teams, team, 2) : [], plays, entry_plays: entryPlays, more_plays: context.playByPlay && value.more_plays === true,
    final_epochs: !context.family && context.canReviewEpochs && capabilities.stats ? collection(value.final_epochs, row => integer(row.epoch, 1) && integer(row.event_cutoff) && integer(row.game_version, 1) && integer(row.roster_revision, 1) && row.engine_version === "soccer-v1" ? { epoch: row.epoch, event_cutoff: row.event_cutoff, game_version: row.game_version, roster_revision: row.roster_revision, engine_version: row.engine_version, participation_complete: row.participation_complete === true, current_authoritative: row.current_authoritative === true, players: collection(row.players, player, 1000), teams: collection(row.teams, team, 2) } : null, 100) : [] };
}
