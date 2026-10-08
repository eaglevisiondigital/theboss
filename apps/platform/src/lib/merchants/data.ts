import "server-only";
import { createClient } from "../supabase/server";
import type { Json } from "../supabase/database.types";
import { validMerchantData, type MerchantData } from "./contracts";
export async function loadMerchants(query: Record<string, Json>, directory = false): Promise<MerchantData> {
 try { const client = await createClient(), { data, error } = await client.rpc(directory ? "boss_merchants_directory" : "boss_merchants_read", { query: directory ? Object.fromEntries(Object.entries(query).filter(([k]) => k !== "mode")) : query }); if (error || !validMerchantData(data)) return { restricted: error?.code === "PT403", unavailable: error?.code !== "PT403" }; return data; } catch { return { unavailable: true }; }
}
