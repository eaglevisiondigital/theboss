import { emitFundraisingDiagnostic, type FundraisingTrace } from "./diagnostics";
import "server-only";
import { createClient } from "../supabase/server";
import type { Json } from "../supabase/database.types";
import { emptyFundraising, record, sharePath, type FundraisingData, type PublicFundraising } from "./contracts";
async function loadFundraisingImpl(query: Record<string, Json>): Promise<FundraisingData> { try { const client = await createClient(), { data, error } = await client.rpc("boss_fundraising_read", { query }); if (error || !record(data) || !Array.isArray(data.campaigns)) return { ...emptyFundraising, mode: query.mode === "family" ? "family" : "organization", restricted: error?.code === "PT403", unavailable: error?.code !== "PT403" }; return data as unknown as FundraisingData; } catch { return { ...emptyFundraising, unavailable: true }; } }
async function loadPublicFundraisingImpl(path: string, ordinal = 0): Promise<PublicFundraising | null> { if (!sharePath(path)) return null; try { const client = await createClient(), { data, error } = await client.rpc("boss_fundraising_public", { path, offset_ordinal: Math.max(0, ordinal) }); return !error && record(data) && record(data.campaign) && data.payment_available === false ? data as unknown as PublicFundraising : null; } catch { return null; } }
export async function fundraisingNavigationAvailable() { try { const client = await createClient(), { data, error } = await client.rpc("boss_fundraising_navigation"); return !error && data === true; } catch { return false; } }

export async function loadFundraising(query: Record<string, Json>, trace?: FundraisingTrace): Promise<FundraisingData> {
 if(trace)emitFundraisingDiagnostic({...trace,phase:"server-component",stage:"read_started",observedAt:"src/lib/fundraising/data.ts",operation:"campaign.read"});
 const result=await loadFundraisingImpl(query);
 if(trace)emitFundraisingDiagnostic({...trace,phase:"server-component",stage:!result.unavailable && !result.restricted?"read_completed":"read_failed",observedAt:"src/lib/fundraising/data.ts",operation:"campaign.read",classification:!result.unavailable && !result.restricted?"event":result.restricted?"scope-denied":"upstream-unavailable"});
 return result;
}

export async function loadPublicFundraising(path: string, ordinal = 0, trace?: FundraisingTrace): Promise<PublicFundraising | null> {
 if(trace)emitFundraisingDiagnostic({...trace,phase:"server-component",stage:"read_started",observedAt:"src/lib/fundraising/data.ts",operation:"campaign.read"});
 const result=await loadPublicFundraisingImpl(path,ordinal);
 if(trace)emitFundraisingDiagnostic({...trace,phase:"server-component",stage:result?"read_completed":"read_failed",observedAt:"src/lib/fundraising/data.ts",operation:"campaign.read",classification:result?"event":"upstream-unavailable"});
 return result;
}
