import type { GameCommand } from "../games/contracts";
import { volleyballOutcomes, type VolleyballSide } from "./contracts";
import { parseVolleyballCommand } from "./input";
export function buildVolleyballEntry(gameId: string, version: number, action: string, side: VolleyballSide, rosterId: string | null, extra: Record<string, string | string[]> = {}): GameCommand | null {
  const terminal = volleyballOutcomes.includes(action as typeof volleyballOutcomes[number]);
  const payload: Record<string, string | string[]> = { ...(terminal ? { outcome: action } : {}), ...(rosterId && action !== "team_point" && action !== "assisted_block" ? { roster_id: rosterId } : {}), ...extra };
  return parseVolleyballCommand({ operation: "volleyball.event.add", input: { game_id: gameId, expected_version: version, event_type: terminal ? "rally" : action, side, payload } });
}
