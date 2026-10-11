import { fundraisingRequestTrace, fundraisingResponse, fundraisingRouteException } from "@/lib/fundraising/diagnostics-server";
import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { isSameOriginPost } from "@/lib/auth/request-security";
import { readBoundedJson } from "@/lib/communications/input";
import { sharePath, record } from "@/lib/fundraising/contracts";
import { statUuid } from "@/lib/stat-intelligence/input";
import type { MoneyBoardClient } from "@/lib/money-board/mutation";
export const dynamic="force-dynamic";
export async function POST(request:NextRequest,{params}:{params:Promise<{path:string}>}) {const trace=fundraisingRequestTrace(request,"/fundraise/[path]/candidate");let baseFinish=preventAuthCaching;const finish=(r:NextResponse)=>fundraisingResponse(trace,baseFinish(r));try{
 const {path}=await params;if(!sharePath(path)||!isSameOriginPost(request,getRequestOrigin(request,getServerEnvironment().platformOrigin)))return finish(NextResponse.json({ok:false},{status:403}));
 if(request.headers.get("content-type")?.split(";")[0].trim().toLowerCase()!=="application/json")return finish(NextResponse.json({ok:false},{status:422}));
 const body=await readBoundedJson(request,50_000);if(!record(body)||Object.keys(body).some(k=>k!=="excluded")||!Array.isArray(body.excluded)||body.excluded.length>1000||body.excluded.some(v=>!statUuid(v)))return finish(NextResponse.json({ok:false},{status:422}));
 const route=createRouteClient(request);baseFinish=route.finish;const {data,error}=await(route.client as unknown as MoneyBoardClient).rpc("boss_money_board_candidate",{path,excluded:body.excluded});
 if(error||!record(data))return finish(NextResponse.json({ok:false},{status:503}));
 const c=data.candidate;if(c!==null&&(!record(c)||!statUuid(c.id)||typeof c.ordinal!=="number"||!Number.isSafeInteger(c.ordinal)||c.ordinal<1||typeof c.amount_minor!=="number"||!Number.isSafeInteger(c.amount_minor)||c.amount_minor<1))return finish(NextResponse.json({ok:false},{status:503}));
 return finish(NextResponse.json({ok:true,candidate:c===null?null:{id:(c as Record<string,unknown>).id,ordinal:(c as Record<string,unknown>).ordinal,amount_minor:(c as Record<string,unknown>).amount_minor}}));
 }catch(error){fundraisingRouteException(trace,error);return finish(NextResponse.json({ok:false},{status:503}));}}
