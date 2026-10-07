import type { Json } from "../supabase/database.types";
import { record, sharePath, type FundraisingCommand } from "./contracts";
import { statUuid } from "../stat-intelligence/input";
const fields: Record<string, string[]> = {
 "campaign.create": ["organization_id", "name", "description", "currency", "goal_minor", "starts_at", "ends_at", "launch_at", "scope", "targets", "channels", "allow_anonymous", "allow_recurring", "allow_fee_cover", "allow_team_sharing", "allow_adult_self_sharing", "leaderboard_visibility", "indexable", "branding", "reward_policy"],
 "campaign.publish": ["campaign_id", "expected_version"], "campaign.status": ["campaign_id", "expected_version", "status"], "fundraiser.enroll": ["campaign_id", "entries"], "fundraiser.accept": ["campaign_id", "fundraiser_id", "display_name", "leaderboard_opt_in"], "fundraiser.end": ["campaign_id", "fundraiser_id"], "share.create": ["campaign_id", "fundraiser_id"], "share.reset": ["campaign_id", "fundraiser_id"],
 "board.create": ["campaign_id", "fundraiser_id", "team_id", "title", "goal_minor", "start_minor", "increment_minor", "tile_count", "reservation_seconds", "visibility"], "board.configure": ["campaign_id", "board_id", "expected_version", "title", "goal_minor", "start_minor", "increment_minor", "tile_count", "reservation_seconds", "visibility"], "board.generate": ["campaign_id", "board_id", "expected_version"], "board.publish": ["campaign_id", "board_id", "expected_version"], "board.archive": ["campaign_id", "board_id", "expected_version"],
};
export function parseFundraisingCommand(v: unknown, guest = false): FundraisingCommand | null {
 if (!record(v) || Object.keys(v).some(k => !["action", "request_id", "input"].includes(k)) || typeof v.action !== "string" || !statUuid(v.request_id) || !record(v.input)) return null;
 const allowed = guest ? ({ reserve: ["path", "ordinal", "capability"], intent: ["path", "ordinal", "capability", "display_name", "email", "mobile", "anonymous", "fee_cover", "months", "amount_minor", "source", "trial_capability"], release: ["path", "capability"] } as Record<string, string[]>)[v.action] : fields[v.action];
 if (!allowed || Object.keys(v.input).some(k => !allowed.includes(k)) || Object.values(v.input).some(x => x === null)) return null;
 if (guest && (!sharePath(v.input.path) || typeof v.input.capability !== "string" || !/^[a-f0-9]{64}$/.test(v.input.capability))) return null;
 if (v.input.trial_capability !== undefined && (typeof v.input.trial_capability !== "string" || !/^[a-f0-9]{64}$/.test(v.input.trial_capability))) return null;
 for (const [key, value] of Object.entries(v.input)) { if (key.endsWith("_id") && !statUuid(value)) return null; if (["amount_minor", "goal_minor", "start_minor", "increment_minor", "tile_count", "ordinal", "expected_version", "months", "reservation_seconds"].includes(key) && (typeof value !== "number" || !Number.isSafeInteger(value) || value < 1)) return null; }
 return v as FundraisingCommand;
}
export function fundraisingQuery(v: Record<string, unknown>, family = false): Record<string, Json> | null { const q: Record<string, Json> = { mode: family ? "family" : "organization" }; for (const [param, key] of [["org", "organization_id"], ["team", "team_id"], ["unit", "unit_id"], ["child", "child_id"], ["campaign", "campaign_id"]]) { const value = v[param]; if (value === undefined || value === "") continue; if (!statUuid(value)) return null; q[key] = value; } return q; }
