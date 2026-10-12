import { type NextRequest,NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { performPartnerMutation } from "@/lib/partners/mutation";
import {emitPartnerDiagnostic,PARTNER_CORRELATION_HEADER,PARTNER_PARENT_HEADER,validPartnerCorrelation}from"@/lib/partners/diagnostics";
export const dynamic="force-dynamic";
export async function POST(request:NextRequest) {
 const supplied=request.headers.get(PARTNER_CORRELATION_HEADER),correlationId=validPartnerCorrelation(supplied)?supplied:crypto.randomUUID(),parent=request.headers.get(PARTNER_PARENT_HEADER);
 let finish:(response:NextResponse)=>NextResponse=preventAuthCaching;
 emitPartnerDiagnostic({correlationId,parentCorrelationId:parent,route:"/app/partners/mutate",phase:"server-route",stage:"mutation_started",observedAt:"src/app/app/partners/mutate/route.ts"});
 const respond=(body:unknown,status:number)=>{const response=NextResponse.json(body,{status});response.headers.set(PARTNER_CORRELATION_HEADER,correlationId);emitPartnerDiagnostic({correlationId,parentCorrelationId:parent,route:"/app/partners/mutate",phase:"server-route",stage:"http_response",observedAt:"src/app/app/partners/mutate/route.ts",status});return finish(response);};
 try {const origin=getRequestOrigin(request,getServerEnvironment().platformOrigin),route=createRouteClient(request);finish=route.finish;
 const result=await performPartnerMutation(request,route.client,origin,correlationId,parent);return respond(result.body,result.status);
 }catch(error){emitPartnerDiagnostic({correlationId,parentCorrelationId:parent,route:"/app/partners/mutate",phase:"server-route",stage:"server_exception",observedAt:"src/app/app/partners/mutate/route.ts",classification:"exception",error});return respond({ok:false,outcome:"unknown",error:"This provider change could not be confirmed."},503);}
}
