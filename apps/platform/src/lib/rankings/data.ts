import "server-only";
import { createClient } from "../supabase/server";
import { emptyRankings, type RankingQuery } from "./contracts";
import { projectRankings } from "./input";
export async function loadRankings(query: RankingQuery) {
  try {
    const client = await createClient();
    const { data, error } = await client.rpc("boss_ranking_read", { p_query: query });
    return error ? { ...emptyRankings(), restricted: error.code === "PT403", unavailable: error.code !== "PT403" } : projectRankings(data) ?? { ...emptyRankings(), unavailable: true };
  } catch { return { ...emptyRankings(), unavailable: true }; }
}

export async function rankingsNavigationAvailable() { try { const client = await createClient(); const { data, error } = await client.rpc("boss_ranking_read", { p_query: { view: "navigation" } }); return !error && typeof data === "object" && data !== null && "navigation_available" in data && data.navigation_available === true; } catch { return false; } }
