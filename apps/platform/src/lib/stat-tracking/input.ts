import { boundedText, finiteKeys, integer, isRecord, oneOf, optionalTime, uuid } from "../coordination/input";
import type { Json } from "../supabase/database.types";
import { trackingSports, type TrackingSport } from "./catalog";
import { resolveSelection, trackingPresets, type TrackingPreset } from "./profile";
export function parseTrackingCommand(v: unknown): { operation: "tracking.profile.set"; input: Record<string, Json | undefined> } | null {
  if (!isRecord(v) || !finiteKeys(v, ["operation", "input"]) || v.operation !== "tracking.profile.set" || !isRecord(v.input)) return null;
  const i = v.input;
  if (!finiteKeys(i, ["sport_key", "scope_type", "organization_id", "unit_id", "team_id", "season_id", "game_id", "side", "expected_profile_version", "expected_game_version", "preset", "enabled", "quick", "status", "ends_at", "reason"]) || !oneOf(i.sport_key, trackingSports) || !oneOf(i.scope_type, ["platform", "organization", "organization_unit", "team", "season", "game"]) || !integer(i.expected_profile_version, 0) || !oneOf(i.preset, trackingPresets) || !boundedText(i.reason, 500) || !i.reason.trim()) return null;
  const scopes: Record<string, string[]> = { platform: [], organization: ["organization_id"], organization_unit: ["organization_id", "unit_id"], team: ["organization_id", "team_id"], season: ["organization_id", "team_id", "season_id"], game: ["organization_id", "game_id", "side"] };
  const required = scopes[i.scope_type];
  for (const k of ["organization_id", "unit_id", "team_id", "season_id", "game_id", "side"]) {
    if (required.includes(k) ? k === "side" ? !oneOf(i[k], ["primary", "opponent"]) : !uuid(i[k]) : i[k] !== undefined) return null;
  }
  if (i.scope_type === "game" ? !integer(i.expected_game_version, 1) : i.expected_game_version !== undefined) return null;
  if (i.status !== undefined && !oneOf(i.status, ["active", "inactive"]) || i.ends_at !== undefined && !optionalTime(i.ends_at)) return null;
  if (i.enabled !== undefined && (!Array.isArray(i.enabled) || !i.enabled.every(k => typeof k === "string")) || i.quick !== undefined && (!Array.isArray(i.quick) || !i.quick.every(k => typeof k === "string"))) return null;
  try { resolveSelection(i.sport_key as TrackingSport, i.preset as TrackingPreset, i.enabled as string[] | undefined, i.quick as string[] | undefined); } catch { return null; }
  return { operation: "tracking.profile.set", input: i as Record<string, Json | undefined> };
}
