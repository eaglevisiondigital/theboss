import "server-only";
import { createClient } from "../supabase/server";
import { emptyAthleteHistory, type AthleteHistoryQuery } from "./contracts";
import { projectAthleteHistory } from "./input";

export async function loadAthleteHistory(query: AthleteHistoryQuery) {
  try {
    const client = await createClient();
    const { data, error } = await client.rpc("boss_athlete_history_read", { p_query: query });
    return error ? emptyAthleteHistory(error.code !== "PT403", error.code === "PT403") : projectAthleteHistory(data, query) ?? emptyAthleteHistory(true);
  } catch { return emptyAthleteHistory(true); }
}
