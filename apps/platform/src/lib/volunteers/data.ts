import "server-only";
import { createClient } from "../supabase/server";
import { emptyVolunteers, type VolunteerQuery } from "./contracts";
import { projectVolunteerData } from "./input";
export async function loadVolunteers(query: VolunteerQuery) {
  try { const client = await createClient(); const { data, error } = await client.rpc("boss_volunteers_read", { p_query: query }); return error ? { ...emptyVolunteers, unavailable: true } : projectVolunteerData(data) ?? { ...emptyVolunteers, unavailable: true }; }
  catch { return { ...emptyVolunteers, unavailable: true }; }
}
export async function volunteersNavigationAvailable() { const now = new Date(); const data = await loadVolunteers({ view: "upcoming", from: now.toISOString(), to: new Date(now.getTime() + 30 * 86_400_000).toISOString() }); return !data.unavailable && (data.navigation_available || data.features.volunteers === true || data.commitments.some(shift => shift.my_assignment?.status === 'active')); }
