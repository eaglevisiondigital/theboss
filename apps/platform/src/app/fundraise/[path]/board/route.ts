import { fundraisingRequestTrace, fundraisingResponse } from "@/lib/fundraising/diagnostics-server";
import { type NextRequest, NextResponse } from "next/server";
import { loadMoneyBoard } from "@/lib/money-board/data";
import { preventAuthCaching } from "@/lib/supabase/response";
export const dynamic="force-dynamic";
export async function GET(request:NextRequest,{params}:{params:Promise<{path:string}>}) {
 const trace=fundraisingRequestTrace(request,"/fundraise/[path]/board"),finish=(r:NextResponse)=>fundraisingResponse(trace,preventAuthCaching(r));
 const {path}=await params,values=request.nextUrl.searchParams.getAll("after");
 if(values.length>1||values.some(v=>!/^\d{1,10}$/.test(v)))return finish(NextResponse.json({ok:false},{status:422}));
 const board=await loadMoneyBoard(path,Number(values[0]??0),trace);return finish(NextResponse.json(board?{ok:true,board}:{ok:false},{status:board?200:404}));
}
