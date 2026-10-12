import type { Game } from "../games/contracts";
import type { FootballEntry, FootballField, FootballGame, FootballPlayType, FootballTotals } from "./contracts";
export const footballPlayLabels: Record<FootballPlayType, string> = { rush: "Rush", pass_complete: "Completed pass", pass_incomplete: "Incomplete pass", sack: "Sack", kneel: "Kneel", spike: "Spike", interception: "Interception", fumble: "Fumble and recovery", fumble_recovery: "Recovery-only outcome", turnover_on_downs: "Turnover on downs", kickoff: "Kickoff", kickoff_return: "Kickoff with return", punt: "Punt", punt_return: "Punt with return", field_goal: "Field goal attempt", extra_point: "Extra point attempt", two_point: "Two-point attempt", safety: "Safety", penalty: "Penalty", touchdown: "Attributed touchdown" };
export function footballClock(milliseconds: number) { const seconds = Math.floor(milliseconds / 1000); return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`; }
export function footballClockEstimate(state: Pick<FootballGame, "clock_running" | "clock_ms" | "clock_observed_at">, now: number) { const elapsed = state.clock_running ? Math.max(0, now - Date.parse(state.clock_observed_at)) : 0; return Math.max(0, state.clock_ms - elapsed); }
export function footballPeriod(period: number) { return period === 0 ? "Awaiting kickoff" : period <= 4 ? `Quarter ${period}` : `Overtime ${period - 4}`; }
export function footballBallPosition(spot: number) { return spot === 50 ? "Midfield" : spot < 50 ? `Own ${spot}` : `Opponent ${100 - spot}`; }
export function footballDown(field: FootballField) { return `${["", "1st", "2nd", "3rd", "4th"][field.down]} & ${field.goal_to_go ? "goal" : field.distance}`; }
export function footballCorrectionEntries(game: Pick<Game, "primary" | "opponent" | "roster" | "roster_revision">, state: FootballGame): FootballEntry[] {
  if (!state.capabilities.correct) return [];
  const entries = new Map(state.entry_roster.filter(row => row.active).map(row => [row.id, row]));
  for (const row of game.roster) {
    if (!row.active || row.revision !== game.roster_revision) continue;
    const side = row.team_id === game.primary.team_id ? "primary" : row.team_id === game.opponent.team_id ? "opponent" : null;
    if (side) entries.set(row.id, { id: row.id, side, display_name: row.display_name, jersey_number: row.jersey_number, active: true });
  }
  return [...entries.values()];
}
export const footballStatSections: { label: string; stats: readonly [keyof FootballTotals, string][] }[] = [
  { label: "Passing", stats: [["passing_completions", "CMP"], ["passing_attempts", "ATT"], ["passing_yards", "YDS"], ["passing_touchdowns", "TD"], ["interceptions_thrown", "INT"], ["sacks_taken", "SK"]] },
  { label: "Rushing", stats: [["rush_attempts", "CAR"], ["rushing_yards", "YDS"], ["rushing_touchdowns", "TD"], ["long_rush", "LONG"], ["fumbles", "FUM"], ["fumbles_lost", "LOST"], ["kneels", "KNEEL"], ["kneel_yards", "KNEEL YDS"]] },
  { label: "Receiving", stats: [["receptions", "REC"], ["targets", "TGT"], ["receiving_yards", "YDS"], ["receiving_touchdowns", "TD"], ["long_reception", "LONG"]] },
  { label: "Defense", stats: [["solo_tackles", "SOLO"], ["assisted_tackles", "AST"], ["tackles", "TKL"], ["tackles_for_loss", "TFL"], ["sacks", "SACK"], ["defensive_interceptions", "INT"], ["pass_defenses", "PD"], ["forced_fumbles", "FF"], ["fumble_recoveries", "FR"], ["defensive_touchdowns", "TD"], ["interception_return_yards", "INT YDS"], ["fumble_return_yards", "FR YDS"]] },
  { label: "Kicking and punting", stats: [["field_goals_made", "FGM"], ["field_goals_attempted", "FGA"], ["long_field_goal", "LONG FG"], ["extra_points_made", "XPM"], ["extra_points_attempted", "XPA"], ["punts", "PUNTS"], ["punt_yards", "PUNT YDS"], ["long_punt", "LONG PUNT"], ["punt_touchbacks", "TB"]] },
  { label: "Returns", stats: [["kick_returns", "KR"], ["kick_return_yards", "KR YDS"], ["kick_return_touchdowns", "KR TD"], ["long_kick_return", "LONG KR"], ["punt_returns", "PR"], ["punt_return_yards", "PR YDS"], ["punt_return_touchdowns", "PR TD"], ["long_punt_return", "LONG PR"]] },
];
