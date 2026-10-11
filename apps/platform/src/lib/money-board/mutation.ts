import { emitFundraisingDiagnostic, fundraisingResult, fundraisingOperation, type FundraisingTrace } from "../fundraising/diagnostics";
import { randomBytes } from "node:crypto";
import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { fundraisingFailure } from "../fundraising/mutation";
import { sharePath } from "../fundraising/contracts";
import { parseCartCommand, safeCart } from "./contracts";
import type { Json } from "../supabase/database.types";
export interface MoneyBoardClient { rpc(name: "boss_money_board_cart" | "boss_money_board_public" | "boss_money_board_candidate", args: Record<string, Json>): PromiseLike<{ data: unknown; error: { code?: string } | null }> }
export const cartCookieName = (path: string) => `__Secure-boss-board-${path}`;
export const cartCookieOptions = (path: string, expires: string) => ({ secure: true, httpOnly: true, sameSite: "strict" as const, path: `/fundraise/${path}`, expires: new Date(expires) });
async function executeMutation(request: Request, client: MoneyBoardClient, origin: string, path: string, existing?: string, trace?: FundraisingTrace) {
 if (!sharePath(path) || !isSameOriginPost(request,origin)) return { ...fundraisingFailure("PT403"), session: null };
 if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return { ...fundraisingFailure("PT422"), session: null };
 const command = parseCartCommand(await readBoundedJson(request,8192),path); if (!command) return { ...fundraisingFailure("PT422"), session: null };
 if (!existing && command.action !== "open" || existing !== undefined && !/^[a-f0-9]{64}$/.test(existing)) return { ...fundraisingFailure("PT404"), session: null };
 const capability = existing ?? randomBytes(32).toString("hex");
 try {
  if(trace) emitFundraisingDiagnostic({...trace,phase:"server-route",stage:"mutation_started",observedAt:"src/lib/money-board/mutation.ts",operation:fundraisingOperation(command.action,true)});
  const { data,error } = await client.rpc("boss_money_board_cart",{command: command as unknown as Json,session_capability:capability});
  if(error) return { ...fundraisingFailure(error.code), session: null };
  const cart = safeCart(data); if (!cart) return { ...fundraisingFailure(), session: null };
  return { status:200, body:{ok:true,cart}, session:existing ? null : {value:capability,expires:cart.session_expires_at} };
 } catch (error) { if(trace)emitFundraisingDiagnostic({...trace,phase:"server-route",stage:"server_exception",observedAt:"src/lib/money-board/mutation.ts",classification:"exception",error}); return { ...fundraisingFailure(), session:null }; }
}

export async function performCartMutation(request: Request, client: MoneyBoardClient, origin: string, path: string, existing?: string, trace?: FundraisingTrace) {
 const result = await executeMutation(request, client, origin, path, existing, trace);
 fundraisingResult(trace,"fundraising.command",result.status,"src/lib/money-board/mutation.ts");
 return result;
}
