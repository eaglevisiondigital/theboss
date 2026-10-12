import type { Json } from "../supabase/database.types";
import { finiteKeys, isRecord } from "../coordination/input";
import { statUuid } from "../stat-intelligence/input";
const fields = {
  "competition.create": ["organization_id", "parent_unit_id", "name"],
  "edition.create": ["competition_id", "sport_key", "season_id", "name", "cross_organization", "team_result_audience", "starts_at", "ends_at"],
  "group.create": ["edition_id", "kind", "name", "organization_unit_id"],
  "entry.create": ["edition_id", "team_id"], "entry.approve": ["edition_id", "entry_id"], "entry.end": ["edition_id", "entry_id"],
  "group.assign": ["edition_id", "entry_id", "group_id", "starts_at", "ends_at"], "group.end": ["edition_id", "membership_id"],
  "policy.activate": ["edition_id", "configuration", "reason"],
  "game.assign": ["edition_id", "game_id", "primary_entry_id", "opponent_entry_id", "game_type", "counts_for_standings", "group_ids", "reason"],
  "ruling.create": ["edition_id", "group_id", "assignment_id", "primary_entry_id", "opponent_entry_id", "kind", "outcome", "amount", "standings_primary_score", "standings_opponent_score", "reversal_of_id", "effective_at", "reason"],
  "definition.create": ["edition_id", "source_organization_id", "team_id", "season_id", "product", "source_kind", "name", "metric_key", "metric_kind", "direction", "qualification", "competition_only", "allow_partial"],
  "definition.end": ["edition_id", "definition_id"], "access.grant": ["edition_id", "person_id", "ends_at"], "access.end": ["edition_id", "assignment_id"], "edition.archive": ["edition_id"],
  "ranking.rebuild": ["edition_id", "product", "group_id", "definition_id"],
} as const;
export type RankingAction = keyof typeof fields;
export type RankingCommand = { action: RankingAction; request_id: string; input: Record<string, Json | undefined> };
export function parseRankingCommand(v: unknown): RankingCommand | null {
  if (!isRecord(v) || !finiteKeys(v, ["action", "request_id", "input"]) || typeof v.action !== "string" || !Object.hasOwn(fields, v.action) || !statUuid(v.request_id) || !isRecord(v.input) || !finiteKeys(v.input, fields[v.action as RankingAction]) || JSON.stringify(v).length > 18000) return null;
  const action = v.action as RankingAction, i = v.input;
  if (action !== "competition.create" && action !== "edition.create" && !statUuid(i.edition_id)) return null;
  for (const [k, value] of Object.entries(i)) {
    if (value === null || value === undefined) return null;
    if (k.endsWith("_id") && !statUuid(value)) return null;
    if (["cross_organization", "counts_for_standings", "competition_only", "allow_partial"].includes(k) && typeof value !== "boolean") return null;
    if (["amount", "standings_primary_score", "standings_opponent_score"].includes(k) && (typeof value !== "number" || !Number.isFinite(value) || Math.abs(value) > 1000000)) return null;
    if (["name", "reason"].includes(k) && (typeof value !== "string" || !value.trim() || value.trim().length > (k === "name" ? 200 : 500))) return null;
    if (k === "group_ids" && (!Array.isArray(value) || value.length > 16 || !value.every(statUuid))) return null;
    if (["configuration", "qualification"].includes(k) && !isRecord(value)) return null;
    if (["starts_at", "ends_at", "effective_at"].includes(k) && (typeof value !== "string" || !Number.isFinite(Date.parse(value)))) return null;
  }
  if (action === "competition.create" && (!statUuid(i.organization_id) || typeof i.name !== "string")) return null;
  if (action === "edition.create" && (!statUuid(i.competition_id) || typeof i.name !== "string" || !["basketball", "soccer", "football", "volleyball", "baseball", "softball"].includes(String(i.sport_key)))) return null;
  if (action === "ranking.rebuild" && (!["standings", "leaderboard", "records"].includes(String(i.product)) || i.product !== "standings" && !statUuid(i.definition_id) || i.product === "standings" && i.definition_id !== undefined)) return null;
  return { action, request_id: v.request_id, input: i as RankingCommand["input"] };
}
