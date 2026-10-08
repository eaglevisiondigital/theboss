import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";
import { MERCHANT_CORRELATION_HEADER, merchantDiagnosticPath } from "@/lib/merchants/diagnostics";

export async function proxy(request: NextRequest) {
  // Overwrite caller input. This opaque diagnostic value grants no authority.
  if (merchantDiagnosticPath(request.nextUrl.pathname)) request.headers.set(MERCHANT_CORRELATION_HEADER, crypto.randomUUID());
  return updateSession(request);
}

export const config = {
  matcher: ["/app/:path*", "/login"],
};
