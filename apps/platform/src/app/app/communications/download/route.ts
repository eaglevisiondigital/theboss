import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performCommunicationDownload, type CommunicationAttachmentClient } from "@/lib/communications/attachments";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) {
  let finish: (response: NextResponse) => NextResponse = preventAuthCaching;
  try { const route = createRouteClient(request); finish = route.finish;
    const result = await performCommunicationDownload(request, route.client as unknown as CommunicationAttachmentClient, getRequestOrigin(request, getServerEnvironment().platformOrigin));
    if ("file" in result) return finish(new NextResponse(result.file, { status: 200, headers: { "Content-Type": result.mime, "Content-Disposition": `attachment; filename="${result.filename}"`, "X-Content-Type-Options": "nosniff" } }));
    return finish(NextResponse.json(result.body, { status: result.status }));
  } catch { return finish(NextResponse.json({ ok: false, error: "Private attachment access is unavailable. Please try again." }, { status: 503 })); }
}
