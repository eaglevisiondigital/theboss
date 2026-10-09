import type { NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";
import { MERCHANT_CORRELATION_HEADER, merchantDiagnosticPath } from "@/lib/merchants/diagnostics";

import {PARTNER_CORRELATION_HEADER,PARTNER_PARENT_HEADER,partnerDiagnosticRoute,validPartnerCorrelation}from"@/lib/partners/diagnostics";

export async function proxy(request: NextRequest) {
  // Overwrite caller input. This opaque diagnostic value grants no authority.
  if (merchantDiagnosticPath(request.nextUrl.pathname)) request.headers.set(MERCHANT_CORRELATION_HEADER, crypto.randomUUID());
  if(partnerDiagnosticRoute(request.nextUrl.pathname)){request.headers.set(PARTNER_CORRELATION_HEADER,crypto.randomUUID());if(!validPartnerCorrelation(request.headers.get(PARTNER_PARENT_HEADER)))request.headers.delete(PARTNER_PARENT_HEADER);}
  return updateSession(request);
}

export const config = {
  matcher: ["/app/:path*", "/login"],
};
