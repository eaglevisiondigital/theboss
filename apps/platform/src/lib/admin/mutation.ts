import type { Json } from "../supabase/database.types";
import { getVerifiedIdentity } from "../auth/verified-identity";
import { isSameOriginPost } from "../auth/request-security";
import { readAdminInput, projectMutationResults } from "./input";

export type AdminMutationClient = {
  auth: Parameters<typeof getVerifiedIdentity>[0]["auth"] & {
    getUser(): Promise<{ data: { user: { id: string; is_anonymous?: boolean } | null }; error: unknown }>;
  };
  rpc(name: "boss_admin_mutate", args: { p_commands: Json; p_request_id: string }): PromiseLike<{ data: unknown; error: { code?: string } | null }>;
};
const failures: Record<string, { status: number; error: string }> = {
  PT401: { status: 401, error: "Please sign in again to continue." },
  PT403: { status: 403, error: "You do not have permission to make these changes." },
  PT409: { status: 409, error: "These changes conflict with an existing record. Review your selection." },
  PT422: { status: 422, error: "Review the fields and relationships, then try again." },
};
export async function performAdminMutation(request: Request, client: AdminMutationClient, origin: string) {
  const fail = (status: number, error: string) => ({ status, body: { ok: false as const, error } });
  if (!isSameOriginPost(request, origin)) return fail(403, "Request not permitted.");
  const input = await readAdminInput(request);
  if (!input) return fail(422, failures.PT422.error);
  try {
    const identity = await getVerifiedIdentity(client);
    if (!identity) return fail(401, failures.PT401.error);
    const { data: current, error: authError } = await client.auth.getUser();
    if (authError || !current.user || current.user.id !== identity.subject || current.user.is_anonymous) return fail(401, failures.PT401.error);
    const { data, error } = await client.rpc("boss_admin_mutate", { p_commands: input.commands, p_request_id: input.request_id });
    if (error) {
      const safe = failures[error.code ?? ""];
      return safe ? fail(safe.status, safe.error) : fail(503, "Changes could not be saved. Please try again.");
    }
    const results = projectMutationResults(data);
    if (!results) return fail(503, "Changes could not be confirmed. Refresh before trying again.");
    return { status: 200, body: { ok: true as const, results } };
  } catch { return fail(503, "Changes could not be saved. Please try again."); }
}
