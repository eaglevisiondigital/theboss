import "server-only";
import { createClient } from "../supabase/server";
import { emptyCommunications, type CommunicationQuery } from "./contracts";
import { projectCommunicationData } from "./input";
export async function loadCommunications(query: CommunicationQuery) { try { const client = await createClient(); const { data, error } = await client.rpc("boss_communications_read", { p_query: query }); return error ? { ...emptyCommunications, unavailable: true } : projectCommunicationData(data) ?? { ...emptyCommunications, unavailable: true }; } catch { return { ...emptyCommunications, unavailable: true }; } }
export async function communicationsNavigationAvailable() { const data = await loadCommunications({ view: "summary" }); return !data.unavailable && (data.organizations.length > 0 || data.threads.length > 0); }
