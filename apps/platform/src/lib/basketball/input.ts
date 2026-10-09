import type { Json } from "../supabase/database.types";
import { boundedText, collection, finiteKeys, integer, isRecord, oneOf, optionalTime, text, uuid } from "../coordination/input";
import { basketballControlTypes, basketballOperations, basketballPlayTypes, basketballStatKeys, type Basketball, type BasketballCapabilities, type BasketballGame, type BasketballPlayer, type BasketballPlay, type BasketballSide, type BasketballTeam, type BasketballTotals } from "./contracts";

const base = ["game_id", "expected_version"];
const event = ["event_type", "side", "roster_id", "scoring_event_id"];
const fields: Record<typeof basketballOperations[number], readonly string[]> = {
  "basketball.configure": [...base, "regulation_periods", "period_seconds", "overtime_seconds", "lineup_size", "enforce_lineup"],
  "basketball.period.start": base, "basketball.period.end": base, "basketball.clock.start": base, "basketball.clock.stop": base,
  "basketball.clock.set": [...base, "clock_ms", "reason"],
  "basketball.lineup.set": [...base, "side", "roster_ids"],
  "basketball.substitute": [...base, "side", "out_roster_id", "in_roster_id"],
  "basketball.event.add": [...base, ...event],
  "basketball.event.correct": [...base, ...event, "event_id", "reason"],
  "basketball.event.reverse": [...base, "event_id", "reason"],
};
const validReason = (value: unknown) => boundedText(value, 500) && value.trim().length > 0;
export function parseBasketballCommand(value: unknown): { operation: typeof basketballOperations[number]; input: Record<string, Json | undefined> } | null {
  if (!isRecord(value) || !finiteKeys(value, ["operation", "input"]) || !oneOf(value.operation, basketballOperations) || !isRecord(value.input)) return null;
  const operation = value.operation as typeof basketballOperations[number], input = value.input;
  if (!finiteKeys(input, fields[operation]) || !uuid(input.game_id) || !integer(input.expected_version, 1)) return null;
  if (operation === "basketball.configure" && (![2, 4].includes(input.regulation_periods as number) || !integer(input.period_seconds, 60, 3600) || !integer(input.overtime_seconds, 60, 1800) || !integer(input.lineup_size, 1, 5) || typeof input.enforce_lineup !== "boolean")) return null;
  if (operation === "basketball.clock.set" && (!integer(input.clock_ms, 0, 3_600_000) || !validReason(input.reason))) return null;
  if (operation === "basketball.lineup.set" && (!oneOf(input.side, ["primary", "opponent"]) || !Array.isArray(input.roster_ids) || input.roster_ids.length > 5 || !input.roster_ids.every(uuid) || new Set(input.roster_ids).size !== input.roster_ids.length)) return null;
  if (operation === "basketball.substitute" && (!oneOf(input.side, ["primary", "opponent"]) || !uuid(input.out_roster_id) || !uuid(input.in_roster_id) || input.in_roster_id === input.out_roster_id)) return null;
  if (operation === "basketball.event.add" || operation === "basketball.event.correct") {
    if (!oneOf(input.event_type, basketballPlayTypes) || !oneOf(input.side, ["primary", "opponent"])) return null;
    if (input.roster_id !== undefined && !uuid(input.roster_id)) return null;
    if (["assist", "steal", "block", "personal_foul"].includes(input.event_type) && !uuid(input.roster_id)) return null;
    if (input.event_type === "assist" ? !uuid(input.scoring_event_id) : input.scoring_event_id !== undefined) return null;
  }
  if ((operation === "basketball.event.correct" || operation === "basketball.event.reverse") && (!uuid(input.event_id) || !validReason(input.reason))) return null;
  return { operation, input: input as Record<string, Json | undefined> };
}

function totals(row: Record<string, unknown>): BasketballTotals | null {
  if (!basketballStatKeys.every(key => integer(row[key], 0, Number.MAX_SAFE_INTEGER))) return null;
  return Object.fromEntries(basketballStatKeys.map(key => [key, row[key]])) as BasketballTotals;
}
const side = (value: unknown): value is BasketballSide => oneOf(value, ["primary", "opponent"]);
type ProjectionContext = { family: boolean; visibleRosterIds: Set<string>; live: boolean; stats: boolean; playByPlay: boolean; lineups: boolean; canReviewEpochs: boolean };
export function projectBasketball(value: unknown, context: ProjectionContext): Basketball | null {
  if (!isRecord(value) || typeof value.configured !== "boolean") return null;
  const raw = isRecord(value.capabilities) ? value.capabilities : {}, controls = !context.family && context.live;
  const capabilities: BasketballCapabilities = { configure: controls && raw.configure === true, operate: controls && raw.operate === true, correct: controls && raw.correct === true, stats: context.stats && raw.stats === true, lineups: controls && context.lineups && raw.lineups === true };
  if (!value.configured) return { configured: false, capabilities: { ...capabilities, operate: false, correct: false, stats: false, lineups: false } };
  if (value.engine_version !== "basketball-v1" || ![2, 4].includes(value.regulation_periods as number) || !integer(value.period_seconds, 60, 3600) || !integer(value.overtime_seconds, 60, 1800) || !integer(value.lineup_size, 1, 5) || typeof value.enforce_lineup !== "boolean" || !integer(value.period_number, 0, 1000) || !integer(value.overtime_number, 0, 1000) || !oneOf(value.period_status, ["pending", "active", "ended"]) || !integer(value.clock_ms, 0, 3_600_000) || typeof value.clock_running !== "boolean" || !optionalTime(value.clock_observed_at)) return null;
  const allowedPlayerIds = new Set(context.visibleRosterIds);
  const projectPlayer = (row: Record<string, unknown>): BasketballPlayer | null => {
    const stats = totals(row);
    return stats && uuid(row.roster_id) && side(row.side) && allowedPlayerIds.has(row.roster_id) ? { ...stats, roster_id: row.roster_id, side: row.side, display_name: text(row, "display_name", "Athlete", 200), jersey_number: boundedText(row.jersey_number, 30) ? row.jersey_number : null } : null;
  };
  const projectTeam = (row: Record<string, unknown>): BasketballTeam | null => { const stats = totals(row); return stats && side(row.side) ? { ...stats, side: row.side } : null; };
  const entryRoster = capabilities.operate ? collection(value.entry_roster, row => uuid(row.id) && side(row.side) ? { id: row.id, side: row.side, display_name: text(row, "display_name", "Athlete", 200), jersey_number: boundedText(row.jersey_number, 30) ? row.jersey_number : null, active: row.active === true } : null, 1000) : [];
  const visibleNames = new Set(context.visibleRosterIds);
  for (const entry of entryRoster) { visibleNames.add(entry.id); allowedPlayerIds.add(entry.id); }
  const plays = context.playByPlay ? collection<BasketballPlay>(value.plays, row => {
    if (!uuid(row.id) || !integer(row.sequence, 1) || !integer(row.period_number, 0, 1000) || !integer(row.clock_ms, 0, 3_600_000) || !oneOf(row.event_type, [...basketballPlayTypes, ...basketballControlTypes]) || !integer(row.points, 0, 3) || typeof row.active !== "boolean" || (!capabilities.correct && !row.active)) return null;
    const visible = uuid(row.roster_id) && visibleNames.has(row.roster_id);
    return { id: row.id, sequence: row.sequence, period_number: row.period_number, clock_ms: row.clock_ms, side: side(row.side) ? row.side : null, event_type: row.event_type as BasketballPlay["event_type"], points: row.points, display_name: visible && boundedText(row.display_name, 200) ? row.display_name : null, jersey_number: visible && boundedText(row.jersey_number, 30) ? row.jersey_number : null, roster_id: visible ? row.roster_id as string : null, scoring_event_id: !context.family && uuid(row.scoring_event_id) ? row.scoring_event_id : null, active: row.active };
  }, 500).sort((a, b) => a.sequence - b.sequence) : [];
  return { configured: true, engine_version: value.engine_version, regulation_periods: value.regulation_periods as 2 | 4, period_seconds: value.period_seconds, overtime_seconds: value.overtime_seconds, lineup_size: value.lineup_size, enforce_lineup: value.enforce_lineup, period_number: value.period_number, overtime_number: value.overtime_number, period_status: value.period_status as BasketballGame["period_status"], clock_ms: value.clock_ms, clock_running: value.clock_running, clock_observed_at: value.clock_observed_at as string, capabilities, entry_roster: entryRoster,
    lineups: capabilities.lineups ? collection(value.lineups, row => side(row.side) && Array.isArray(row.roster_ids) && row.roster_ids.length <= 5 && row.roster_ids.every(uuid) && new Set(row.roster_ids).size === row.roster_ids.length ? { side: row.side, roster_ids: row.roster_ids.filter(id => entryRoster.some(entry => entry.id === id && entry.side === row.side)) } : null, 2) : [],
    players: capabilities.stats ? collection(value.players, projectPlayer, 1000) : [], teams: capabilities.stats ? collection(value.teams, projectTeam, 2) : [], plays, period_fouls: capabilities.stats ? collection(value.period_fouls, row => integer(row.period_number, 1, 30) && integer(row.primary) && integer(row.opponent) ? { period_number: row.period_number, primary: row.primary, opponent: row.opponent } : null, 30) : [], more_plays: context.playByPlay && value.more_plays === true,
    final_epochs: !context.family && context.canReviewEpochs && capabilities.stats ? collection(value.final_epochs, row => integer(row.epoch, 1) && integer(row.event_sequence) && integer(row.roster_revision, 1) && row.engine_version === "basketball-v1" ? { epoch: row.epoch, event_sequence: row.event_sequence, roster_revision: row.roster_revision, engine_version: row.engine_version, current_authoritative: row.current_authoritative === true, players: collection(row.players, projectPlayer, 1000), teams: collection(row.teams, projectTeam, 2) } : null, 100) : [] };
}
