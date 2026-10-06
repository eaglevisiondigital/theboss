import type { Json } from "../supabase/database.types";
import { finiteKeys, isRecord } from "../coordination/input";
import { statUuid } from "../stat-intelligence/input";
import { statSports } from "../stat-intelligence/contracts";
import { emptyRankings, rankingProducts, type RankingData, type RankingEdition, type RankingQuery } from "./contracts";
const numeric = (v: unknown) => typeof v === "number" && Number.isFinite(v) ? v : null;
const text = (v: unknown, limit = 500) => typeof v === "string" && v.length <= limit ? v : null;
const json = (v: unknown): Json | null => v === undefined || v === null ? null : JSON.stringify(v).length <= 32000 ? v as Json : null;
const dayMs = 86400000;
export function competitionGameRange(now = new Date()) {
  return { from: new Date(now.getTime() - 63 * dayMs).toISOString(), to: new Date(now.getTime() + 30 * dayMs).toISOString() };
}
function edition(v: unknown): RankingEdition | null {
  if (!isRecord(v) || !statUuid(v.id) || !text(v.name, 200) || typeof v.sport_key !== "string" || !statSports.some(s => s === v.sport_key)) return null;
  return { id: v.id, name: v.name as string, sport_key: v.sport_key, ...(statUuid(v.competition_id) ? { competition_id: v.competition_id } : {}), ...(statUuid(v.season_id) ? { season_id: v.season_id } : {}), ...(text(v.competition_name, 200) ? { competition_name: v.competition_name as string } : {}), can_manage: v.can_manage === true, can_policy_manage: v.can_policy_manage === true };
}
export function parseRankingQuery(raw: Record<string, string | string[] | undefined>): RankingQuery | null {
  const q: RankingQuery = { limit: 50 };
  for (const [key, field] of [["organization_id", "org"], ["edition_id", "edition"], ["definition_id", "definition"], ["group_id", "group"]] as const) { const v = raw[field]; if (v === undefined || v === "") continue; if (!statUuid(v)) return null; q[key] = v; }
  if (!q.organization_id && !q.edition_id) return null;
  if (raw.product !== undefined) { if (typeof raw.product !== "string" || !rankingProducts.some(p => p === raw.product)) return null; q.product = raw.product as RankingQuery["product"]; }
  if (q.product && q.product !== "standings" && !q.definition_id || q.product === "standings" && q.definition_id) return null;
  if (raw.history !== undefined) { if (raw.history !== "true" || q.product !== "records") return null; q.history = true; }
  if (raw.cursor !== undefined) { if (typeof raw.cursor !== "string" || raw.cursor.length > 2048) return null; try { const v: unknown = JSON.parse(raw.cursor); if (!isRecord(v) || !finiteKeys(v, ["after_id", "scope_id", "generation", "rank", "id", "recognized_at"])) return null; q.cursor = v as Json; } catch { return null; } }
  return q;
}
export function projectRankings(v: unknown): RankingData | null {
  if (!isRecord(v) || v.contract !== "rankings-v1") return null;
  const out = emptyRankings();
  if (v.freshness !== undefined) { if (typeof v.freshness !== "string" || !["current", "refreshing", "pending", "unavailable"].includes(v.freshness)) return null; out.freshness = v.freshness as RankingData["freshness"]; }
  out.generation = numeric(v.generation) ?? 0; out.next_cursor = isRecord(v.next_cursor) ? json(v.next_cursor) : null;
  for (const k of ["can_create", "can_manage", "can_policy_manage", "can_standings_manage", "can_leaderboard_manage", "can_records_manage", "can_rebuild"] as const) out[k] = v[k] === true;
  if (v.edition !== undefined) { out.edition = edition(v.edition); if (!out.edition) return null; }
  for (const k of ["editions", "definitions", "groups", "entries", "rows"] as const) if (v[k] !== undefined && (!Array.isArray(v[k]) || v[k].length > 100)) return null;
  for (const e of v.editions as unknown[] ?? []) { const projected = edition(e); if (!projected) return null; out.editions.push(projected); }
  for (const d of v.definitions as unknown[] ?? []) { if (!isRecord(d) || !statUuid(d.id) || !text(d.name, 200) || !["leaderboard", "records"].includes(String(d.product)) || !text(d.source_kind, 50) || !text(d.metric_key, 64)) return null; out.definitions.push({ id: d.id, name: d.name as string, product: d.product as "leaderboard" | "records", source_kind: d.source_kind as string, metric_key: d.metric_key as string }); }
  for (const g of v.groups as unknown[] ?? []) { if (!isRecord(g) || !statUuid(g.id) || !text(g.name, 200) || !text(g.kind, 40)) return null; out.groups.push({ id: g.id, name: g.name as string, kind: g.kind as string }); }
  for (const e of v.entries as unknown[] ?? []) { if (!isRecord(e) || !statUuid(e.id) || !statUuid(e.team_id) || !text(e.name, 200) || !text(e.status, 40)) return null; out.entries.push({ id: e.id, team_id: e.team_id, name: e.name as string, status: e.status as string }); }
  if (out.freshness !== "current" && Array.isArray(v.rows) && v.rows.length) return null;
  for (const r of v.rows as unknown[] ?? []) {
    if (!isRecord(r) || !text(r.id, 200)) return null;
    const rank = numeric(r.rank); if (rank !== null && (!Number.isSafeInteger(rank) || rank < 1)) return null;
    const state = text(r.qualification_state, 40); if (state !== null && !["qualified", "incomplete", "below_minimum", "unqualified", "no_policy", "not_applicable"].includes(state) || rank !== null && state !== null && state !== "qualified") return null;
    out.rows.push({ id: r.id as string, label: text(r.label, 200) ?? text(r.subject_key, 200) ?? "Recorded performance", rank, wins: numeric(r.wins), losses: numeric(r.losses), ties: numeric(r.ties), games_played: numeric(r.games_played), points: numeric(r.points), win_percentage: numeric(r.win_percentage), scoring_for: numeric(r.scoring_for), scoring_against: numeric(r.scoring_against), value: numeric(r.value), qualification_state: state, current_holder: r.current_holder === true, achieved_at: text(r.achieved_at, 64), recognized_at: text(r.recognized_at, 64), event_type: text(r.event_type, 64), explanation: json(r.explanation), coverage: json(r.coverage), qualification: json(r.qualification), provenance: json(r.source_manifest) });
  }
  return out;
}
