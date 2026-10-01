import "server-only";
import { createClient } from "../supabase/server";
import { emptyRegistrationData, type RegistrationData, type RegistrationQuery } from "./contracts";
import { projectRegistrationData } from "./input";

export async function loadRegistrations(query: RegistrationQuery): Promise<RegistrationData> {
  try {
    const client = await createClient();
    const { data, error } = await client.rpc("boss_registration_read", { p_query: query });
    return error ? { ...emptyRegistrationData, unavailable: true } : projectRegistrationData(data) ?? { ...emptyRegistrationData, unavailable: true };
  } catch { return { ...emptyRegistrationData, unavailable: true }; }
}
export async function registrationNavigationAvailable() {
  const data = await loadRegistrations({ view: "family" });
  return !data.unavailable && (data.organizations.length > 0 || data.registrations.length > 0 || data.offerings.length > 0);
}
