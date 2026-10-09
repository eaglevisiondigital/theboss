import { isRecord } from "../coordination/input";
import { statUuid } from "../stat-intelligence/input";
import type { Json } from "../supabase/database.types";

const actions = {
  "definition.create": ["organization_id", "owner_kind", "definition_key", "revision"],
  "definition.revise": ["definition_id", "expected_version", "revision"],
  "definition.set_status": ["definition_id", "expected_version", "status"],
  "definition.evaluate": ["definition_id", "organization_id", "revision_id"],
  "definition.rebuild": ["definition_id", "organization_id", "revision_id"],
  "standings.close": ["scope_id", "reason"],
  "award.nominate": ["definition_id", "organization_id", "team_id", "season_id", "profile_id", "achieved_at", "note"],
  "award.approve": ["nomination_id", "expected_version", "note"],
  "award.decline": ["nomination_id", "expected_version", "note"],
  "award.withdraw": ["nomination_id", "expected_version", "note"],
  "award.revoke": ["nomination_id", "expected_version", "note"],
  "award.restore": ["nomination_id", "expected_version", "note"],
  "display.set": ["achievement_id", "show_on_profile", "show_on_showcase"],
} as const;
export type AchievementAction = keyof typeof actions;
export type AchievementCommand = { action: AchievementAction; request_id: string; input: Record<string, Json> };
const revisionKeys = ["name", "description", "subject_type", "category", "source_kind", "sport_key", "team_id", "season_id", "metric_key", "threshold", "ranking_definition_id", "bracket_id", "standings_scope_id", "placement", "badge_icon", "tier", "approval_required", "showcase_eligible", "athlete_championship_policy", "effective_at", "historical_evaluation"];
function finiteFields(value: Record<string, unknown>): boolean {
  return Object.entries(value).every(([key, field]) => {
    if (field === null || field === undefined) return false;
    if (key.endsWith("_id")) return statUuid(field);
    if (["approval_required", "showcase_eligible", "historical_evaluation", "show_on_profile", "show_on_showcase"].includes(key)) return typeof field === "boolean";
    if (["threshold", "placement", "expected_version"].includes(key)) return typeof field === "number" && Number.isFinite(field) && field > 0 && (key === "threshold" || Number.isSafeInteger(field));
    if (key === "revision") return isRecord(field) && Object.keys(field).every(k => revisionKeys.includes(k)) && ["name", "subject_type", "category", "source_kind"].every(k => typeof field[k] === "string") && finiteFields(field);
    return typeof field === "string" && field.length <= (key === "description" ? 800 : 500);
  });
}
export function parseAchievementCommand(value: unknown): AchievementCommand | null {
  if (!isRecord(value) || Object.keys(value).some(k => !["action", "request_id", "input"].includes(k)) || typeof value.action !== "string" || !Object.hasOwn(actions, value.action) || !statUuid(value.request_id) || !isRecord(value.input) || JSON.stringify(value).length > 32768) return null;
  const action = value.action as AchievementAction, allowed: readonly string[] = actions[action], input = value.input;
  if (Object.keys(input).some(k => !allowed.includes(k)) || !finiteFields(input)) return null;
  const required = action === "definition.create" ? ["owner_kind", "definition_key", "revision"] : action === "award.nominate" ? ["definition_id", "organization_id", "achieved_at", "note"] : action === "definition.evaluate" || action === "definition.rebuild" ? ["definition_id"] : allowed;
  return required.every(k => Object.hasOwn(input, k)) ? { action, request_id: value.request_id as string, input: input as Record<string, Json> } : null;
}
export type AchievementCard = { id: string; achievement_id: string; profile_id?: string; name: string; title: string; category: string; subject_type: string; sport_key?: string; state: string; verification_level: string; achieved_at: string; recognized_at: string; badge_icon: string; tier?: string; current: boolean; current_holder: boolean; co_holder: boolean; show_on_profile: boolean; show_on_showcase: boolean; showcase_eligible: boolean };
export type AchievementData = { recognitions: AchievementCard[]; definitions: Record<string, Json>[]; nominations: Record<string, Json>[]; history: Record<string, Json>[]; catalog: Record<string, Json>; can_manage: boolean; can_issue: boolean; can_approve: boolean; next_cursor?: string; restricted: boolean; unavailable: boolean };
export const emptyAchievements = (): AchievementData => ({ recognitions: [], definitions: [], nominations: [], history: [], catalog: {}, can_manage: false, can_issue: false, can_approve: false, restricted: false, unavailable: false });
export function projectAchievements(value: unknown): AchievementData | null {
  if (!isRecord(value) || value.contract !== "achievements-v1" || ["can_manage", "can_issue", "can_approve"].some(k => typeof value[k] !== "boolean")) return null;
  for (const key of ["recognitions", "definitions", "nominations", "history"]) if (!Array.isArray(value[key]) || value[key].length > 50 || value[key].some(item => !isRecord(item))) return null;
  const recognitions = value.recognitions as Record<string, unknown>[];
  if (recognitions.some(r => !statUuid(r.id) || !statUuid(r.achievement_id) || typeof r.name !== "string" || !["current", "historical", "corrected", "revoked", "processing", "unavailable"].includes(String(r.state)) || !["boss_verified", "organization_verified"].includes(String(r.verification_level)))) return null;
  return { ...emptyAchievements(), recognitions: recognitions as unknown as AchievementCard[], definitions: value.definitions as Record<string, Json>[], nominations: value.nominations as Record<string, Json>[], history: value.history as Record<string, Json>[], catalog: isRecord(value.catalog) ? value.catalog as Record<string, Json> : {}, can_manage: value.can_manage as boolean, can_issue: value.can_issue as boolean, can_approve: value.can_approve as boolean, ...(statUuid(value.next_cursor) ? { next_cursor: value.next_cursor as string } : {}) };
}
