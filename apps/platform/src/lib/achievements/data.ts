import "server-only";
import { createClient } from "../supabase/server";
import type { Json } from "../supabase/database.types";
import { emptyAchievements, projectAchievements } from "./input";
export async function loadAchievements(query: Record<string, Json> = {}) {
  try {
    const client = await createClient(), { data, error } = await client.rpc("boss_achievement_read", { p_query: query });
    return error ? { ...emptyAchievements(), restricted: error.code === "PT403", unavailable: error.code !== "PT403" } : projectAchievements(data) ?? { ...emptyAchievements(), unavailable: true };
  } catch { return { ...emptyAchievements(), unavailable: true }; }
}
