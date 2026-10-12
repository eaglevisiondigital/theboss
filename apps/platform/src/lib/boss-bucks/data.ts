import "server-only";
import { createClient } from "../supabase/server";
import type { Json } from "../supabase/database.types";
import { bucksRecord, emptyBucks, type BucksData } from "./contracts";
export async function loadBucks(query: Record<string, Json>): Promise<BucksData> {
 try { const client = await createClient(), { data, error } = await client.rpc("boss_bucks_read", { query }); if (error || !bucksRecord(data) || !["family", "organization"].includes(String(data.mode))) return { ...emptyBucks, restricted: error?.code === "PT403", unavailable: error?.code !== "PT403" }; return { ...emptyBucks, ...data } as BucksData; }
 catch { return { ...emptyBucks, unavailable: true }; }
}
