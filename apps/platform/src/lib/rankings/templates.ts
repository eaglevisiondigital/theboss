import type { StatSport } from "../stat-intelligence/contracts";
export const bossStandingsTemplateVersion = "boss-standings-v1";
// Starting points only. An explicit policy activation governs actual ordering.
export function bossStandingsTemplate(sport: StatSport) {
  return { template: sport, order_by: sport === "soccer" ? "points" : "win_percentage", tie_weight: 0.5, allow_ties: !["basketball", "volleyball"].includes(sport), ...(sport === "soccer" ? { win_points: 3, tie_points: 1, loss_points: 0 } : {}), allow_manual_resolution: false, mini_table_restart: false, tiebreaks: [] };
}
export const rankingRateMetrics = {
  basketball: ["fg_percentage", "three_point_percentage", "ft_percentage", "two_point_percentage"],
  soccer: ["shots_on_goal_rate", "save_percentage"],
  football: ["completion_percentage", "passing_yards_per_attempt", "yards_per_carry", "yards_per_reception", "punt_average", "field_goal_percentage", "extra_point_percentage"],
  volleyball: ["hitting_percentage"],
  baseball: ["avg", "obp", "slg", "ops", "whip", "era", "strike_percentage"],
  softball: ["avg", "obp", "slg", "ops", "whip", "era", "strike_percentage"],
} satisfies Record<StatSport, string[]>;
