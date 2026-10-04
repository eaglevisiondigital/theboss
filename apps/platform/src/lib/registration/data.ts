import "server-only";
import { createClient } from "../supabase/server";
import { emptyRegistrationData, type RegistrationData, type RegistrationQuery } from "./contracts";
import { readRegistrationData } from "./read";

export async function loadRegistrations(query: RegistrationQuery): Promise<RegistrationData> {
  try {
    const client = await createClient();
    return await readRegistrationData(query, async p_query => await client.rpc("boss_registration_read", { p_query }));
  } catch { return { ...emptyRegistrationData, unavailable: true }; }
}
export async function registrationNavigationAvailable() {
  const data = await loadRegistrations({ view: "family" });
  return !data.unavailable && (data.organizations.length > 0 || data.registrations.length > 0 || data.offerings.length > 0);
}
