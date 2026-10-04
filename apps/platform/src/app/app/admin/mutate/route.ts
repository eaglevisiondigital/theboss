import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performAdminMutation, type AdminMutationClient } from "@/lib/admin/mutation";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try {
    const origin = getRequestOrigin(request, getServerEnvironment().platformOrigin);
    const route = createRouteClient(request);
    finish = route.finish;
    // Narrow RPC contract is kept separate from generated database row types.
    const result = await performAdminMutation(request, route.client as unknown as AdminMutationClient, origin);
    return finish(NextResponse.json(result.body, { status: result.status }));
  } catch {
    return finish(NextResponse.json({ ok: false, error: "Changes could not be saved. Please try again." }, { status: 503 }));
  }
}
