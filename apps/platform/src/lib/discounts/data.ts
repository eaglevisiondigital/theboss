import "server-only";
import { createClient } from "../supabase/server";
import type { Json } from "../supabase/database.types";
import { emptyDiscounts, validDiscountData, type DiscountCatalogItem, type DiscountData } from "./contracts";
export async function loadDiscounts(query: Record<string, Json>): Promise<DiscountData> {
 try { const client = await createClient(), { data, error } = await client.rpc("boss_discounts_read", { query }); if (error || !validDiscountData(data)) return { ...emptyDiscounts, restricted: error?.code === "PT403", unavailable: error?.code !== "PT403" }; return { ...emptyDiscounts, ...data }; } catch { return { ...emptyDiscounts, unavailable: true }; }
}
export async function loadPublicDiscounts(path: string): Promise<DiscountCatalogItem[]> {
 if (!/^[a-f0-9]{48}$/.test(path)) return [];
 try { const client = await createClient(), { data, error } = await client.rpc("boss_discounts_catalog", { path }); return !error && Array.isArray(data) ? data as DiscountCatalogItem[] : []; } catch { return []; }
}
