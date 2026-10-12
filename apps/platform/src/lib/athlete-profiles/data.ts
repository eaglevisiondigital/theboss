import "server-only";
import { createHash } from "node:crypto";
import { createClient } from "../supabase/server";
import { emptyAthleteProfiles } from "./contracts";
import { projectAthleteProfiles, projectShowcase } from "./input";
export async function loadAthleteProfiles(profileId?: string) {
  try { const client = await createClient(); const { data, error } = await client.rpc("boss_athlete_profile_read", { p_profile_id: profileId, p_participant_id: undefined }); return error ? { ...emptyAthleteProfiles(), restricted: error.code === "PT403", unavailable: error.code !== "PT403" } : projectAthleteProfiles(data) ?? { ...emptyAthleteProfiles(), unavailable: true }; } catch { return { ...emptyAthleteProfiles(), unavailable: true }; }
}
export async function athleteProfilesNavigationAvailable() { try { const client = await createClient(); const { data, error } = await client.rpc("boss_athlete_profile_navigation"); return !error && data === true; } catch { return false; } }
export async function loadRecruitingShowcase(token: string) {
  if (!/^[A-Za-z0-9_-]{43,128}$/.test(token)) return { available: false } as const;
  try { const client = await createClient(); const tokenDigest = createHash("sha256").update(token).digest("hex"); const { data, error } = await client.rpc("boss_recruiting_showcase_read", { p_token_digest: tokenDigest }); return error ? { available: false } as const : projectShowcase(data) ?? { available: false } as const; } catch { return { available: false } as const; }
}
