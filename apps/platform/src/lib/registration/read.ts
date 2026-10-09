import { emptyRegistrationData, type RegistrationData, type RegistrationQuery } from "./contracts";
import { projectRegistrationData, uuidPattern } from "./input";

type RegistrationReader = (query: RegistrationQuery) => Promise<{ data: unknown; error: unknown }>;
const unavailable = (): RegistrationData => ({ ...emptyRegistrationData, unavailable: true });

export async function readRegistrationData(query: RegistrationQuery, read: RegistrationReader): Promise<RegistrationData> {
  try {
    const initial = await read(query);
    if (initial.error) return unavailable();
    const data = projectRegistrationData(initial.data);
    if (!data) return unavailable();
    const organizationId = data.detail?.organization_id;
    if (query.organization_id || !query.registration_id ||
      typeof data.detail?.id !== "string" || data.detail.id.toLowerCase() !== query.registration_id.toLowerCase() ||
      typeof organizationId !== "string" || !uuidPattern.test(organizationId)) return data;

    // The first guarded read authorizes the detail. Its organization is only a
    // query context for a second read, which rechecks the same caller's access.
    const scoped = await read({ ...query, organization_id: organizationId });
    return scoped.error ? unavailable() : projectRegistrationData(scoped.data) ?? unavailable();
  } catch { return unavailable(); }
}
