import { emptyStats, statSports, type StatData, type StatMetric, type StatQuery, type StatSummary } from "./contracts";
const object = (v: unknown): v is Record<string, unknown> => !!v && typeof v === "object" && !Array.isArray(v);
export const statUuid = (v: unknown): v is string => typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const number = (v: unknown): number | null => typeof v === "number" && Number.isFinite(v) ? v : null;
const count = (v: unknown): number => typeof v === "number" && Number.isSafeInteger(v) && v >= 0 ? v : 0;
export function parseStatQuery(raw: Record<string, string | string[] | undefined>): StatQuery | null {
  const sport = raw.stats_sport ?? (raw.history_sport || "basketball");
  if (typeof sport !== "string" || !statSports.some(s => s === sport)) return null;
  const query: StatQuery = { sport_key: sport as StatQuery["sport_key"] };
  for (const [field, source] of [["person_id", "child"], ["season_id", "stats_season"], ["team_id", "stats_team"], ["organization_id", "org"]] as const) {
    const v = raw[source]; if (v === undefined || v === "") continue; if (!statUuid(v)) return null; query[field] = v;
  }
  return query;
}
function summary(v: unknown): StatSummary | null {
  if (!object(v) || !object(v.metrics) || !object(v.rates) || Object.keys(v.metrics).length > 80 || Object.keys(v.rates).length > 30) return null;
  const metrics: Record<string, StatMetric> = {}, rates: StatSummary["rates"] = {};
  for (const [key, m] of Object.entries(v.metrics)) {
    if (!/^[a-z_]{1,48}$/.test(key) || !object(m)) return null;
    metrics[key] = { observed_value: number(m.observed_value), complete_value: number(m.complete_value), complete_games: count(m.complete_games), partial_games: count(m.partial_games), legacy_unknown_games: count(m.legacy_unknown_games), untracked_games: count(m.untracked_games), played_complete_games: count(m.played_complete_games), per_tracked_game: number(m.per_tracked_game) };
  }
  for (const [key, r] of Object.entries(v.rates)) {
    if (key === "era_basis_innings") continue;
    if (!/^[a-z_]{1,48}$/.test(key) || !object(r)) return null;
    rates[key] = { value: number(r.value), reason: typeof r.reason === "string" && r.reason.length <= 80 ? r.reason : null };
  }
  return { source_game_count: count(v.source_game_count), confirmed_gp: count(v.confirmed_gp), participation_unknown_games: count(v.participation_unknown_games), participation_partial_games: count(v.participation_partial_games), era_conventions: Array.isArray(v.era_conventions) ? v.era_conventions.filter((n): n is number => typeof n === "number" && Number.isInteger(n) && n >= 1 && n <= 20) : [], metrics, rates };
}
export function projectStats(v: unknown): StatData | null {
  if (!object(v) || v.contract !== "intelligence-v1" || typeof v.is_current !== "boolean" || typeof v.refresh_pending !== "boolean") return null;
  if (!v.is_current || v.refresh_pending) return { ...emptyStats(), refresh_pending: true };
  const total = summary(v.summary); if (!total || !Array.isArray(v.segments) || v.segments.length > 100) return null;
  const segments: StatData["segments"] = [];
  for (const s of v.segments) {
    if (!object(s) || !statUuid(s.organization_id) || !statUuid(s.team_id) || (s.season_id !== null && !statUuid(s.season_id)) || typeof s.source_watermark !== "string" || !/^[0-9a-f]{32}$/.test(s.source_watermark) || typeof s.refreshed_at !== "string" || !Number.isFinite(Date.parse(s.refreshed_at))) return null;
    const data = summary(s.summary); if (!data) return null;
    segments.push({ organization_id: s.organization_id, team_id: s.team_id, season_id: s.season_id, generation: count(s.generation), source_watermark: s.source_watermark, refreshed_at: s.refreshed_at, summary: data });
  }
  return { is_current: true, refresh_pending: false, summary: total, segments, unassigned_game_count: count(v.unassigned_game_count) };
}
