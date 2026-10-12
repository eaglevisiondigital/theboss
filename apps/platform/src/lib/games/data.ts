import "server-only";
import { createClient } from "../supabase/server";
import { emptyGames, type GameQuery } from "./contracts";
import { projectGameData } from "./input";
import { isRecord } from "../coordination/input";
export async function loadGames(query: GameQuery, resolveGameRange = false) {
  const rpcQuery = resolveGameRange && query.game_id ? Object.fromEntries(Object.entries(query).filter(([key]) => key !== "from" && key !== "to")) : query;
  try { const client = await createClient(); const { data, error } = await client.rpc("boss_games_read", { p_query: rpcQuery }); return error ? emptyGames(query, error.code !== "PT403", error.code === "PT403") : projectGameData(data, query) ?? emptyGames(query, true); }
  catch { return emptyGames(query, true); }
}
export async function gamesNavigationAvailable() { try { const client = await createClient(); const { data, error } = await client.rpc("boss_games_read", { p_query: { view: "navigation" } }); return !error && isRecord(data) && data.navigation_available === true; } catch { return false; } }
