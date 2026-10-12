import { fundraisingRequestTrace, fundraisingResponse, fundraisingRouteException } from "@/lib/fundraising/diagnostics-server";
import { type NextRequest, NextResponse } from "next/server";
import { createRouteClient } from "@/lib/supabase/route-client";
import { preventAuthCaching } from "@/lib/supabase/response";
import { getServerEnvironment } from "@/lib/env/server";
import { getRequestOrigin } from "@/lib/auth/request-origin";
import { cartCookieName, cartCookieOptions, performCartMutation, type MoneyBoardClient } from "@/lib/money-board/mutation";
export const dynamic = "force-dynamic";
export async function POST(request: NextRequest,{params}:{params:Promise<{path:string}>}) {
 const trace=fundraisingRequestTrace(request,"/fundraise/[path]/cart");let baseFinish=preventAuthCaching;const finish=(r:NextResponse)=>fundraisingResponse(trace,baseFinish(r));
 try { const {path}=await params,route=createRouteClient(request);baseFinish=route.finish;
  const result=await performCartMutation(request,route.client as unknown as MoneyBoardClient,getRequestOrigin(request,getServerEnvironment().platformOrigin),path,request.cookies.get(cartCookieName(path))?.value,trace);
  const response=NextResponse.json(result.body,{status:result.status});
  if(result.session) response.cookies.set(cartCookieName(path),result.session.value,cartCookieOptions(path,result.session.expires));
  return finish(response);
 } catch (error) { fundraisingRouteException(trace,error); return finish(NextResponse.json({ok:false,error:"The cart could not be confirmed. Retry the same request safely."},{status:503})); }
}
