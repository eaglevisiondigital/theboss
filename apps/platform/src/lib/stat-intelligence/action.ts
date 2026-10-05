import { finiteKeys, isRecord } from "../coordination/input";
import { statUuid } from "./input";
import { statSports } from "./contracts";
export const competitionClasses = ["official", "exhibition", "scrimmage", "practice", "controlled_test", "excluded", "pending"] as const;
export type StatAction = { operation: "classify"; game_id: string; classification: typeof competitionClasses[number]; reason: string } | { operation: "rebuild"; query: { organization_id: string; team_id: string; season_id: string; sport_key: string }; after_game?: string };
export function parseStatAction(value: unknown): StatAction | null {
  if (!isRecord(value)) return null;
  if (value.operation === "classify" && finiteKeys(value, ["operation", "game_id", "classification", "reason"]) && statUuid(value.game_id) && typeof value.classification === "string" && competitionClasses.some(c => c === value.classification) && typeof value.reason === "string" && value.reason.trim().length > 0 && value.reason.trim().length <= 500) return { operation: "classify", game_id: value.game_id, classification: value.classification as typeof competitionClasses[number], reason: value.reason.trim() };
  if (value.operation === "rebuild" && finiteKeys(value, ["operation", "query", "after_game"]) && isRecord(value.query) && finiteKeys(value.query, ["organization_id", "team_id", "season_id", "sport_key"]) && statUuid(value.query.organization_id) && statUuid(value.query.team_id) && statUuid(value.query.season_id) && typeof value.query.sport_key === "string" && statSports.includes(value.query.sport_key as typeof statSports[number]) && (value.after_game === undefined || statUuid(value.after_game))) return { operation: "rebuild", query: { organization_id: value.query.organization_id, team_id: value.query.team_id, season_id: value.query.season_id, sport_key: value.query.sport_key }, ...(value.after_game ? { after_game: value.after_game } : {}) };
  return null;
}
