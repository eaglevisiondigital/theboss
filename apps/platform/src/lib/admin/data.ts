import "server-only";
import { createClient } from "../supabase/server";
import type { AdminView, AdminViewData } from "./contracts";
import { readAdminView } from "./read";

export async function loadAdminView(view: AdminView, organizationId?: unknown, query?: unknown): Promise<AdminViewData> {
  return readAdminView(view, async request => {
    const client = await createClient();
    const rpc = client as unknown as {
      rpc(name: "boss_admin_read", args: { p_view: string; p_organization_id: string | null; p_query: string | null }): PromiseLike<{ data: unknown; error: unknown }>;
    };
    return rpc.rpc("boss_admin_read", request);
  }, organizationId, query);
}
