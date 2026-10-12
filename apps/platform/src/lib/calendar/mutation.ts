import type { Json } from "../supabase/database.types";
import { getVerifiedIdentity } from "../auth/verified-identity";
import { isSameOriginPost } from "../auth/request-security";
import { readCalendarInput, projectCalendarMutation, projectCalendarPreview } from "./input";

export type CalendarMutationClient = {
  auth: Parameters<typeof getVerifiedIdentity>[0]["auth"] & { getUser(): Promise<{ data: { user: { id: string; is_anonymous?: boolean } | null }; error: unknown }> };
  rpc(name: "boss_calendar_mutate" | "boss_calendar_preview", args: { p_command: Json; p_request_id?: string }): PromiseLike<{ data: unknown; error: { code?: string } | null }>;
};
const failures: Record<string, { status: number; error: string }> = {
  PT401: { status: 401, error: "Please sign in again to continue." },
  PT403: { status: 403, error: "You do not have permission to make this calendar change." },
  PT409: { status: 409, error: "The event changed or has a scheduling conflict. Refresh and review it." },
  PT422: { status: 422, error: "Review the event fields, times and targets, then try again." },
};
export async function performCalendarMutation(request: Request, client: CalendarMutationClient, origin: string, preview = false) {
  const fail = (status: number, error: string) => ({ status, body: { ok: false as const, error } });
  if (!isSameOriginPost(request,origin)) return fail(403,"Request not permitted.");
  const input = await readCalendarInput(request,preview); if (!input) return fail(422,failures.PT422.error);
  try {
    const identity = await getVerifiedIdentity(client); if (!identity) return fail(401,failures.PT401.error);
    const { data: current, error: authError } = await client.auth.getUser();
    if (authError || !current.user || current.user.id !== identity.subject || current.user.is_anonymous) return fail(401,failures.PT401.error);
    const { data, error } = await client.rpc(preview ? "boss_calendar_preview" : "boss_calendar_mutate", { p_command: input.command, ...(preview ? {} : { p_request_id: input.request_id }) });
    if (error) { const safe = failures[error.code ?? ""]; return safe ? fail(safe.status,safe.error) : fail(503,"Calendar changes are unavailable. Please try again."); }
    if (preview) { const result = projectCalendarPreview(data); return result ? { status: 200, body: { ok: true as const, preview: result } } : fail(503,"The conflict check could not be confirmed."); }
    const result = projectCalendarMutation(data);
    return result && result.request_id === input.request_id ? { status: 200, body: { ok: true as const, result } } : fail(503,"The change could not be confirmed. Refresh before trying again.");
  } catch { return fail(503,"Calendar changes are unavailable. Please try again."); }
}
