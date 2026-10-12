import type { SoccerEntry, SoccerGame, SoccerPlay, SoccerPlayType, SoccerSide } from "./contracts";
import type { Game, GameCommand } from "../games/contracts";
export const soccerPlayLabels: Record<SoccerPlayType, string> = { goal: "Goal", shot_off_target: "Shot off target", shot_saved: "Shot saved", shot_blocked: "Shot blocked", penalty_goal: "Penalty goal", penalty_miss: "Penalty missed", penalty_saved: "Penalty saved", own_goal: "Own goal", assist: "Assist", yellow_card: "Yellow card", second_yellow: "Second yellow / red", red_card: "Red card", foul: "Foul" };
export function soccerClock(milliseconds: number) { const seconds = Math.floor(milliseconds / 1000); return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`; }
export function soccerSegment(state: Pick<SoccerGame, "regulation_segments" | "segment_number">, number = state.segment_number) { return number === 0 ? "Awaiting kickoff" : number > state.regulation_segments ? `Extra time ${number - state.regulation_segments}` : `${state.regulation_segments === 2 ? "Half" : "Quarter"} ${number}`; }
export function soccerMinutes(minutes: number | null) { return minutes === null ? "--" : Number.isInteger(minutes) ? String(minutes) : minutes.toFixed(1); }
export function soccerAddedTime(seconds: number) { return seconds % 60 === 0 ? `${seconds / 60}` : `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`; }
export function soccerAssistContexts(plays: SoccerPlay[], segment: number, options: { side?: SoccerSide; athlete?: string; correctingEvent?: string } = {}) {
  return plays.filter(play => play.active && play.segment_number === segment && ["goal", "penalty_goal"].includes(play.event_type) && (!options.side || play.side === options.side) && (!options.athlete || play.roster_id !== options.athlete) && !plays.some(assist => assist.active && assist.event_type === "assist" && assist.scoring_event_id === play.id && assist.id !== options.correctingEvent));
}
/** Corrections may reuse independently authorized roster identities without granting entry authority. */
export function soccerCorrectionEntries(game: Pick<Game, "primary" | "opponent" | "roster" | "roster_revision">, state: SoccerGame): SoccerEntry[] {
  if (!state.capabilities.correct) return [];
  const entries = new Map(state.entry_roster.filter(row => row.active).map(row => [row.id, row]));
  for (const row of game.roster) {
    if (!row.active || row.revision !== game.roster_revision) continue;
    const side = game.primary.team_id && row.team_id === game.primary.team_id ? "primary" : game.opponent.team_id && row.team_id === game.opponent.team_id ? "opponent" : null;
    if (side) entries.set(row.id, { id: row.id, side, display_name: row.display_name, jersey_number: row.jersey_number, active: true });
  }
  return [...entries.values()];
}
export const oppositeSide = (side: SoccerSide): SoccerSide => side === "primary" ? "opponent" : "primary";
/** A save is the opponent's one canonical shot outcome, never a second save event. */
export function soccerSaveCommand(gameId: string, version: number, defendingSide: SoccerSide, goalkeeperId?: string): GameCommand { return { operation: "soccer.event.add", input: { game_id: gameId, expected_version: version, event_type: "shot_saved", side: oppositeSide(defendingSide), ...(goalkeeperId ? { goalkeeper_roster_id: goalkeeperId } : {}) } }; }
