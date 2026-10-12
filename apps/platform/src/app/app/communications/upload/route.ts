import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performCommunicationUpload, type CommunicationAttachmentClient } from "@/lib/communications/attachments";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) {
  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try { const route = createRouteClient(request); finish = route.finish;
    const result = await performCommunicationUpload(request, route.client as unknown as CommunicationAttachmentClient, getRequestOrigin(request, getServerEnvironment().platformOrigin));
    return finish(NextResponse.json(result.body, { status: result.status }));
  } catch { return finish(NextResponse.json({ ok: false, error: "Private attachment access is unavailable. Please try again." }, { status: 503 })); }
}
