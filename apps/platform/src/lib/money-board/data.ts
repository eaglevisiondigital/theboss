import { emitFundraisingDiagnostic, type FundraisingTrace } from "../fundraising/diagnostics";
import "server-only";
import { createClient } from "../supabase/server";
import { sharePath } from "../fundraising/contracts";
import { safeBoard } from "./contracts";
import type { MoneyBoardClient } from "./mutation";
async function loadMoneyBoardImpl(path:string,after=0) { if(!sharePath(path)||!Number.isSafeInteger(after)||after<0||after>2_147_483_647)return null;
 try { const client=await createClient() as unknown as MoneyBoardClient,{data,error}=await client.rpc("boss_money_board_public",{path,after_ordinal:after});return error?null:safeBoard(data); } catch { return null; } }

export async function loadMoneyBoard(path:string,after=0, trace?: FundraisingTrace) {
 if(trace)emitFundraisingDiagnostic({...trace,phase:"server-component",stage:"read_started",observedAt:"src/lib/money-board/data.ts",operation:"board.read"});
 const result=await loadMoneyBoardImpl(path,after);
 if(trace)emitFundraisingDiagnostic({...trace,phase:"server-component",stage:result?"read_completed":"read_failed",observedAt:"src/lib/money-board/data.ts",operation:"board.read",classification:result?"event":"upstream-unavailable"});
 return result;
}
