import { basketballStatKeys } from "../basketball/contracts";
import { soccerStatKeys } from "../soccer/contracts";
import { footballStatKeys, footballPlayTypes } from "../football/contracts";

export const trackingSports = ["basketball", "soccer", "football", "volleyball"] as const;
export type TrackingSport = typeof trackingSports[number];
export const catalogVersion = "boss-tracking-v1";
export type StatClass = "required" | "optional" | "derived" | "advanced";
export type InputMode = "action_first" | "player_first";
export type StatDefinition = {
  key: string; label: string; short_label: string; category: string; classification: StatClass;
  available: boolean; default_enabled: boolean; modes: readonly InputMode[];
  dependencies: readonly string[]; actions: readonly string[]; prompts: readonly string[];
  order: number; quick_eligible: boolean; scopes: readonly ("game" | "team" | "player")[];
};
function definition(key: string, order: number, classification: StatClass = "optional", dependencies: string[] = [], actions: string[] = [key], short_label?: string): StatDefinition {
  const input = classification === "optional" || classification === "required";
  return { key, label: key.replaceAll("_", " "), short_label: short_label ?? key.replaceAll("_", " "), category: classification === "required" ? "game_state" : classification === "derived" ? "derived" : "statistics", classification,
    available: classification !== "advanced", default_enabled: classification === "required", modes: input ? ["action_first", "player_first"] : [], dependencies, actions: input ? actions : [], prompts: [], order, scopes: classification === "required" ? ["game"] : ["team", "player"], quick_eligible: classification === "optional" && actions.length > 0 };
}
const vb = [
  definition("rally", 0, "required", [], ["team_point"], "Point"),
  definition("set_state", 1, "required", [], ["set_start"], "Set"),
  definition("service_state", 2, "required", [], [], "Serve"),
  definition("participation", 3, "required", [], ["lineup_set", "substitution"], "Court"),
  definition("kills", 10, "optional", ["attack_attempts"], ["kill"], "Kill"),
  definition("attack_attempts", 11, "optional", [], ["attack_attempt"], "Attack"),
  definition("attack_errors", 12, "optional", ["attack_attempts"], ["attack_error"], "Attack error"),
  definition("hitting_percentage", 13, "derived", ["kills", "attack_attempts", "attack_errors"]),
  definition("assists", 14, "optional", ["kills"], ["assist"], "Assist"),
  definition("digs", 15, "optional", [], ["dig"], "Dig"),
  definition("service_attempts", 16, "derived", ["service_state", "rally"]),
  definition("service_aces", 17, "optional", [], ["ace"], "Ace"),
  definition("service_errors", 18, "optional", [], ["service_error"], "Service error"),
  definition("solo_blocks", 19, "optional", [], ["solo_block"], "Solo block"),
  definition("block_assists", 20, "optional", [], ["assisted_block"], "Assisted block"),
  definition("blocks", 21, "derived", ["solo_blocks", "block_assists"]),
  definition("blocking_errors", 22, "optional", [], ["blocking_error"], "Block error"),
  definition("receptions", 23, "optional", [], ["reception"], "Reception"),
  definition("reception_errors", 24, "optional", ["receptions"], ["reception_error"], "Reception error"),
  definition("points", 25, "derived", ["rally"]),
  definition("set_wins", 26, "derived", ["set_state"]),
  definition("player_attribution", 27, "optional", [], [], "Player credit"),
  definition("passing_rating", 90, "advanced", ["receptions"], []),
  definition("rotation_efficiency", 91, "advanced", ["rally", "participation"], []),
];
for (const key of ["points", "set_wins"]) vb.find(s => s.key === key)!.scopes = ["team"];
vb.find(s => s.key === "kills")!.prompts = ["assists"];

const basketballActions: Record<string, string[]> = {
  offensive_rebounds: ["offensive_rebound"], defensive_rebounds: ["defensive_rebound"], assists: ["assist"], steals: ["steal"], blocks: ["block"], turnovers: ["turnover"], personal_fouls: ["personal_foul"],
  fga: ["missed_2", "missed_3"], fta: ["missed_ft"],
};
const basketball = [definition("scoring", 0, "required", [], ["made_2", "made_3", "made_ft"], "Score"), definition("game_state", 1, "required", [], ["period_start", "period_end", "clock_start", "clock_stop", "lineup_set", "substitution"]),
  ...basketballStatKeys.map((k, i) => definition(k, i + 10, basketballActions[k] ? "optional" : "derived", k === "rebounds" ? ["offensive_rebounds", "defensive_rebounds"] : k === "points" || ["fgm", "tpm", "ftm"].includes(k) ? ["scoring"] : k === "tpa" ? ["fga"] : [], basketballActions[k] ?? [])),
  definition("player_attribution", 40, "optional", [], []), definition("shooting_percentage", 41, "derived", ["fgm", "fga"]),
];
basketball.find(s => s.key === "scoring")!.prompts = ["assists"];
basketball.find(s => s.key === "fga")!.prompts = ["offensive_rebounds", "defensive_rebounds"];
const soccerActions: Record<string, string[]> = { assists: ["assist"], shots: ["shot_off_target", "shot_saved", "shot_blocked", "penalty_miss", "penalty_saved"], saves: ["shot_saved", "penalty_saved"], yellow_cards: ["yellow_card", "second_yellow"], red_cards: ["red_card"], fouls: ["foul"] };
const soccer = [definition("scoring", 0, "required", [], ["goal", "penalty_goal", "own_goal"], "Goal"), definition("game_state", 1, "required", [], ["segment_start", "segment_end", "clock_start", "clock_stop", "lineup_set", "keeper_set", "substitution"]),
  ...soccerStatKeys.map((k, i) => definition(k, i + 10, soccerActions[k] ? "optional" : "derived", ["goals", "own_goals"].includes(k) ? ["scoring"] : k === "shots_on_goal" ? ["shots"] : [], soccerActions[k] ?? [])), definition("player_attribution", 40, "optional", [], []),
];
soccer.find(s => s.key === "scoring")!.prompts = ["assists"];
// Football keeps required placement fields and the complete play-centric engine.
// Quick actions select play families; no numeric counter is independently edited.
const football = [definition("play_state", 0, "required", [], [...footballPlayTypes], "Play"), definition("game_state", 1, "required", [], ["period_start", "period_end", "clock_start", "clock_stop", "state_set", "lineup_set", "substitution"]),
  ...footballStatKeys.map((k, i) => definition(k, i + 10, "derived", ["play_state"], [])),
  definition("player_attribution", 80, "optional", [], []),
  ...["rush", "pass_complete", "pass_incomplete", "punt", "field_goal", "penalty"].map((k, i) => definition(`quick_${k}`, i + 81, "optional", ["play_state"], [k], k.replaceAll("_", " "))),
];
export const statCatalog: Record<TrackingSport, readonly StatDefinition[]> = { basketball, soccer, football, volleyball: vb };
export function validateCatalog(sport: TrackingSport): void {
  const entries = statCatalog[sport], keys = new Set(entries.map(e => e.key));
  if (keys.size !== entries.length) throw new Error("Duplicate stat key");
  const done = new Set<string>(), pending = new Set<string>();
  const visit = (key: string) => {
    if (pending.has(key)) throw new Error("Cyclic stat dependency");
    if (done.has(key)) return;
    const entry = entries.find(e => e.key === key);
    if (!entry) throw new Error("Unknown stat dependency");
    pending.add(key); entry.dependencies.forEach(visit); pending.delete(key); done.add(key);
    if (entry.prompts.some(k => !keys.has(k))) throw new Error("Unknown contextual prompt");
  };
  entries.forEach(e => visit(e.key));
}
