import "server-only";
import { createClient } from "../supabase/server";
import { emptyStats, type StatKind, type StatQuery } from "./contracts";
import { projectStats } from "./input";
export async function loadStats(kind: StatKind, query: StatQuery) {
  try {
    const client = await createClient();
    const name = kind === "athlete_career" ? "boss_athlete_career_read" : kind === "athlete_season" ? "boss_athlete_season_read" : "boss_team_season_read";
    const { data, error } = await client.rpc(name, { p_query: query });
    return error ? { ...emptyStats(), restricted: error.code === "PT403", unavailable: error.code !== "PT403" } : projectStats(data) ?? { ...emptyStats(), unavailable: true };
  } catch { return { ...emptyStats(), unavailable: true }; }
}
