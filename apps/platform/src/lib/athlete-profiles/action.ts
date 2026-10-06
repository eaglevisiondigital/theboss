import type { Json } from "../supabase/database.types";
import { finiteKeys, isRecord } from "../coordination/input";
import { statUuid } from "../stat-intelligence/input";
const fields = {
  "profile.create": ["participant_id", "visibility", "safe_fields"], "profile.revise": ["profile_id", "expected_version", "visibility", "safe_fields"],
  "measurable.add": ["profile_id", "sport_key", "metric_key", "value", "unit", "measured_on", "provenance", "visibility", "organization_id", "team_id", "source_label"],
  "achievement.add": ["profile_id", "sport_key", "achievement_type", "title", "achieved_on", "season_id", "organization_id", "visibility", "source_record_event_id", "source_ranking_candidate_id"],
  "media.add": ["profile_id", "sport_key", "media_type", "url", "title", "source", "rights_state", "visibility"],
  "showcase.create": ["profile_id"], "showcase.revise": ["showcase_id", "expected_version", "profile_revision_id", "sport_keys", "visible_categories", "stat_metric_keys", "presentation"],
  "consent.grant": ["showcase_id", "showcase_revision_id", "approved_categories", "expires_at"], "showcase.publish": ["showcase_id", "expected_version"],
  "share.create": ["showcase_id", "expires_at"], "share.revoke": ["share_link_id"], "showcase.disable": ["showcase_id"], "profile.archive": ["profile_id"],
} as const;
export type AthleteProfileAction = keyof typeof fields;
export type AthleteProfileCommand = { action: AthleteProfileAction; request_id: string; input: Record<string, Json | undefined> };
export function parseAthleteProfileCommand(value: unknown): AthleteProfileCommand | null {
  if (!isRecord(value) || !finiteKeys(value, ["action", "request_id", "input"]) || typeof value.action !== "string" || !Object.hasOwn(fields, value.action) || !statUuid(value.request_id) || !isRecord(value.input) || !finiteKeys(value.input, fields[value.action as AthleteProfileAction]) || JSON.stringify(value).length > 32000) return null;
  const action = value.action as AthleteProfileAction, input = value.input;
  for (const [key, field] of Object.entries(input)) { if (field === null || field === undefined) return null; if (key.endsWith("_id") && !statUuid(field)) return null; }
  if (action === "profile.create" && (!statUuid(input.participant_id) || !isRecord(input.safe_fields))) return null;
  if (action === "profile.revise" && (!statUuid(input.profile_id) || typeof input.expected_version !== "number" || !isRecord(input.safe_fields))) return null;
  if (action === "showcase.revise" && (!statUuid(input.showcase_id) || !statUuid(input.profile_revision_id) || !Array.isArray(input.sport_keys) || !Array.isArray(input.visible_categories) || !Array.isArray(input.stat_metric_keys) || !isRecord(input.presentation))) return null;
  if (["consent.grant", "showcase.publish", "showcase.disable", "share.create"].includes(action) && !statUuid(input.showcase_id)) return null;
  if (["share.revoke"].includes(action) && !statUuid(input.share_link_id)) return null;
  return { action, request_id: value.request_id, input: input as AthleteProfileCommand["input"] };
}
