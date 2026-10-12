import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performMerchantMutation } from "@/lib/merchants/mutation";
import { emitMerchantDiagnostic, MERCHANT_CORRELATION_HEADER, validMerchantCorrelation } from "@/lib/merchants/diagnostics";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest) {
 const supplied=request.headers.get(MERCHANT_CORRELATION_HEADER),correlationId=validMerchantCorrelation(supplied)?supplied:crypto.randomUUID();
 let finish: (r: NextResponse) => NextResponse = preventAuthCaching;
 emitMerchantDiagnostic({correlationId,stage:"mutation_started",phase:"server-route",observedAt:"src/app/app/merchants/mutate/route.ts"});
 const response=(body:unknown,status:number)=>{const result=NextResponse.json(body,{status});result.headers.set(MERCHANT_CORRELATION_HEADER,correlationId);emitMerchantDiagnostic({correlationId,stage:"mutation_completed",phase:"server-route",observedAt:"src/app/app/merchants/mutate/route.ts",status});return finish(result);};
 try { const origin = getRequestOrigin(request, getServerEnvironment().platformOrigin), route = createRouteClient(request); finish = route.finish; const result = await performMerchantMutation(request, route.client, origin,correlationId); return response(result.body,result.status); }
 catch(error) { emitMerchantDiagnostic({correlationId,stage:"server_exception",phase:"server-route",observedAt:"src/app/app/merchants/mutate/route.ts",classification:"exception",error});return response({ok:false,outcome:"unknown",error:"The merchant change could not be confirmed."},503); }
}
