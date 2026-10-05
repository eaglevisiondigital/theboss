import { volleyballStatKeys } from "../volleyball/contracts";
import { footballStatKeys } from "../football/contracts";
import { projectFootballTotals } from "../football/input";
import { basketballStatKeys } from "../basketball/contracts";
import { soccerStatKeys } from "../soccer/contracts";
import { boundedText, collection, integer, isRecord, oneOf, optionalTime, text, uuid, validOccurrenceKey } from "../coordination/input";
import { gameStatuses } from "../games/contracts";
import { historySports, type AthleteHistoryData, type AthleteHistoryQuery, type AthleteHistoryRecord, type HistoricalStats, type HistoryCursor, type HistorySport, type HistorySubject } from "./contracts";

export const historicalStatKeys: Record<HistorySport, readonly string[]> = {
  basketball: basketballStatKeys,
  soccer: [...soccerStatKeys, "goals_allowed", "minutes", "clean_sheet"],
  football: footballStatKeys,
  volleyball: volleyballStatKeys,
};
const instant = (value: unknown): value is string => typeof value === "string" && Boolean(optionalTime(value));
const nullableId = (value: unknown): value is string | null => value === null || uuid(value);
export function parseAthleteHistoryQuery(params: Record<string, string | string[] | undefined>): AthleteHistoryQuery | null {
  const query: AthleteHistoryQuery = { limit: 20 };
  for (const [param, field] of [["child", "child_person_id"], ["history_season", "season_id"]] as const) {
    const value = params[param]; if (value !== undefined && value !== "") { if (!uuid(value)) return null; query[field] = value; }
  }
  if (params.history_sport !== undefined && params.history_sport !== "") { if (!oneOf(params.history_sport, historySports)) return null; query.sport_key = params.history_sport as HistorySport; }
  if (params.history_limit !== undefined) { if (typeof params.history_limit !== "string" || !/^\d{1,2}$/.test(params.history_limit) || !integer(Number(params.history_limit), 1, 50)) return null; query.limit = Number(params.history_limit); }
  const cursor = [params.before_sealed_at, params.before_finalization_id, params.before_stat_id];
  if (cursor.some(value => value !== undefined)) {
    if (!instant(cursor[0]) || !uuid(cursor[1]) || !uuid(cursor[2])) return null;
    query.before_sealed_at = cursor[0]; query.before_finalization_id = cursor[1]; query.before_stat_id = cursor[2];
  }
  return query;
}
export function projectHistoricalStats(sport: HistorySport, value: unknown): HistoricalStats | null {
  if (!isRecord(value) || !historicalStatKeys[sport].length) return null;
  if (sport === "football") { const stats = projectFootballTotals(value); return stats ? { ...stats } : null; }
  const stats: HistoricalStats = {};
  for (const key of historicalStatKeys[sport]) {
    const item = value[key];
    if (sport === "volleyball") { if (!(item === null || (key === "hitting_percentage" ? typeof item === "number" && Number.isFinite(item) && item >= -1 && item <= 1 : integer(item, 0, Number.MAX_SAFE_INTEGER)))) return null; }
    else if (sport === "soccer" && key === "clean_sheet") { if (!(item === null || typeof item === "boolean")) return null; }
    else if (sport === "soccer" && key === "minutes") { if (!(item === null || typeof item === "number" && Number.isFinite(item) && item >= 0 && item <= 1440)) return null; }
    else if (sport === "soccer" && key === "goals_allowed") { if (!(item === null || integer(item, 0))) return null; }
    else if (!integer(item, 0, Number.MAX_SAFE_INTEGER)) return null;
    stats[key] = item as number | boolean | null;
  }
  return stats;
}
export function projectAthleteHistory(value: unknown, query: AthleteHistoryQuery): AthleteHistoryData | null {
  if (!isRecord(value) || value.version !== "athlete-history-v1" || !Array.isArray(value.subjects) || !Array.isArray(value.records) || value.records.length > query.limit || value.subjects.length > 101 || !uuid(value.subject_person_id) || typeof value.has_more !== "boolean") return null;
  const subjects = collection<HistorySubject>(value.subjects, row => uuid(row.person_id) && boundedText(row.display_name, 200) && oneOf(row.relationship, ["self", "dependent"]) ? { person_id: row.person_id, display_name: row.display_name, relationship: row.relationship as HistorySubject["relationship"] } : null, 101);
  if (subjects.length !== value.subjects.length || new Set(subjects.map(row => row.person_id)).size !== subjects.length || !subjects.some(row => row.person_id === value.subject_person_id) || query.child_person_id && query.child_person_id !== value.subject_person_id) return null;
  const records = collection<AthleteHistoryRecord>(value.records, row => {
    if (!oneOf(row.sport_key, historySports) || row.engine_version !== `${row.sport_key}-v1` || row.person_id !== value.subject_person_id || ![row.id, row.person_id, row.participant_id, row.organization_id, row.team_id, row.game_id, row.event_id, row.roster_id, row.finalization_id].every(uuid) || !nullableId(row.origin_team_season_id) || !nullableId(row.game_season_id) || !integer(row.roster_revision, 1) || !integer(row.epoch, 1) || !integer(row.event_sequence, 0) || !integer(row.operation_sequence, 0) || !instant(row.sealed_at) || typeof row.occurrence_key !== "string" || !validOccurrenceKey(row.occurrence_key) || !oneOf(row.side, ["primary", "opponent"]) || !oneOf(row.game_status, gameStatuses) || typeof row.current_authoritative !== "boolean" || typeof row.latest_sealed !== "boolean") return null;
    if (query.sport_key && row.sport_key !== query.sport_key || query.season_id && row.origin_team_season_id !== query.season_id && row.game_season_id !== query.season_id) return null;
    const stats = projectHistoricalStats(row.sport_key as HistorySport, row.stats); if (!stats) return null;
    if (row.sport_key === "volleyball" && (!isRecord(row.tracking_coverage) || historicalStatKeys.volleyball.some(k => !oneOf((row.tracking_coverage as Record<string, unknown>)[k], ["tracked", "not_tracked", "partially_tracked"]) || (row.tracking_coverage as Record<string, unknown>)[k] === "not_tracked" && stats[k] !== null))) return null;
    return { id: row.id as string, sport_key: row.sport_key as HistorySport, engine_version: row.engine_version, person_id: row.person_id as string, participant_id: row.participant_id as string, organization_id: row.organization_id as string, organization_name: text(row, "organization_name", "Originating organization", 200), team_id: row.team_id as string, team_name: text(row, "team_name", "Originating team", 200), origin_team_season_id: row.origin_team_season_id, origin_team_season_name: row.origin_team_season_id && boundedText(row.origin_team_season_name, 200) ? row.origin_team_season_name : null, game_season_id: row.game_season_id, game_season_name: row.game_season_id && boundedText(row.game_season_name, 200) ? row.game_season_name : null, game_id: row.game_id as string, event_id: row.event_id as string, occurrence_key: row.occurrence_key, roster_id: row.roster_id as string, roster_revision: row.roster_revision, finalization_id: row.finalization_id as string, epoch: row.epoch, sealed_at: row.sealed_at, event_sequence: row.event_sequence, operation_sequence: row.operation_sequence, side: row.side as "primary" | "opponent", current_authoritative: row.current_authoritative && row.latest_sealed && row.game_status === "final", latest_sealed: row.latest_sealed, game_status: row.game_status as string, ...(row.coverage_reason === "legacy_unknown" ? { coverage_reason: "legacy_unknown" as const } : {}), ...(isRecord(row.tracking_coverage) ? { tracking_coverage: Object.fromEntries(Object.entries(row.tracking_coverage).filter(([k, v]) => historicalStatKeys[row.sport_key as HistorySport].includes(k) && oneOf(v, ["tracked", "not_tracked", "partially_tracked"]))) as AthleteHistoryRecord["tracking_coverage"] } : {}), stats };
  }, 50);
  if (records.length !== value.records.length || new Set(records.map(row => row.id)).size !== records.length) return null;
  let next_cursor: HistoryCursor | null = null;
  if (value.next_cursor !== null) { if (!isRecord(value.next_cursor) || !instant(value.next_cursor.sealed_at) || !uuid(value.next_cursor.finalization_id) || !uuid(value.next_cursor.stat_id)) return null; next_cursor = { sealed_at: value.next_cursor.sealed_at, finalization_id: value.next_cursor.finalization_id, stat_id: value.next_cursor.stat_id }; }
  if (value.has_more !== (next_cursor !== null) || value.has_more && records.length === 0) return null;
  const last = records.at(-1);
  if (next_cursor && (!last || next_cursor.stat_id !== last.id || next_cursor.finalization_id !== last.finalization_id || next_cursor.sealed_at !== last.sealed_at)) return null;
  return { subjects, subject_person_id: value.subject_person_id, records, has_more: value.has_more, next_cursor };
}
