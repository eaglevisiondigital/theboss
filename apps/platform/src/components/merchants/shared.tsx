"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { Json } from "@/lib/supabase/database.types";
import { type Terms, type MerchantData, type Market } from "@/lib/merchants/contracts";
import { parseMerchantCommand, type MerchantCommand } from "@/lib/merchants/input";
import { money } from "@/lib/fundraising/contracts";
import type { MerchantAction } from "@/lib/merchants/fields";
import { requestMerchantMutation } from "@/lib/merchants/action";
import { merchantDiagnosticOperation } from "@/lib/merchants/diagnostics";
import { merchantClientDiagnostic } from "@/lib/merchants/diagnostics-client";
export type Act = (action: MerchantAction, input: Record<string, Json>) => Promise<Record<string, unknown> | null>;
export function useMerchantAction() {
 const router = useRouter(), [busy, setBusy] = useState(false), [message, setMessage] = useState("");
 const pending = useRef<MerchantCommand | null>(null), sending=useRef(false), [retry, setRetry] = useState(false);
 async function send(command: MerchantCommand): Promise<Record<string, unknown> | null> {
  if (sending.current) return null;
  sending.current=true;setBusy(true);setRetry(false);
  try {
   const result=await requestMerchantMutation(command);
   if(result.outcome!=="confirmed-success") {
    setMessage(result.message);setRetry(result.outcome==="unknown");
    if(result.outcome==="confirmed-rejection")pending.current=null;
    return null;
   }
   setMessage(result.receipt.replayed ? "Existing request confirmed." : "Change confirmed.");pending.current=null;
   merchantClientDiagnostic({stage:"refresh_requested",observedAt:"src/components/merchants/shared.tsx",operation:merchantDiagnosticOperation(command.action)});
   try {router.refresh();}catch(error){merchantClientDiagnostic({stage:"client_exception",observedAt:"src/components/merchants/shared.tsx",classification:"refresh-failed",error});setMessage("Change confirmed. The workspace could not be refreshed. Reload to review it.");}
   return result.receipt;
  } finally {sending.current=false;setBusy(false);}
 }
 const act: Act = async (action, input) => {
  // An unknown result retains the exact command. Never replace its request ID/input.
  if(sending.current || pending.current) {setMessage("Confirm the pending request using Retry the same request before another change.");return null;}
  const command = parseMerchantCommand({ action, input, request_id: crypto.randomUUID() });
  if (!command) { setMessage("Review the merchant fields."); return null; }
  pending.current=command;return send(command);
 };
 return { act, busy:busy || retry, status: <div role="status" aria-live="polite"><p>{message}</p>{retry && <button className="button button-outline" disabled={busy} onClick={() => { if (pending.current) void send(pending.current); }}>Retry the same request</button>}</div> };
}
export const formText = (form: FormData, name: string) => String(form.get(name) ?? "").trim();
export function optionalText(form: FormData, name: string) { const v = formText(form, name); return v ? { [name]: v } : {}; }
export function optionalDate(form: FormData, name: string) { const v = formText(form, name); return v && Number.isFinite(Date.parse(v)) ? { [name]: new Date(v).toISOString() } : {}; }
export function MarketChoice({ markets = [], name = "market_id" }: { markets?: Market[]; name?: string }) { return <label>Approved market<select required name={name}>{markets.map(g => <option key={g.id} value={g.id}>{g.market} · {g.region}, {g.country}</option>)}</select></label>; }
export function TermsSummary({ terms: t }: { terms: Terms }) {
 return <div className="merchant-terms"><p>{t.offer_type === "percentage_off" ? `${(t.discount_bps ?? 0) / 100}% off` : t.offer_type === "fixed_amount_off" ? `${money(t.amount_minor ?? 0,t.currency ?? "USD")} off` : t.offer_type === "bogo" ? `Buy ${t.buy_quantity} ${t.purchase_description}. Receive ${t.benefit_quantity} ${t.benefit_description} at ${(t.discount_bps ?? 0) / 100}% off.` : `${t.benefit_quantity} ${t.benefit_description} complimentary`}</p><p>{t.description}</p><p>Qualifying purchase: {t.qualification === "minimum_amount" ? `Minimum ${money(t.minimum_minor ?? 0,t.currency ?? "USD")}` : t.qualification === "item" ? t.qualifying_description : "No minimum"}</p><p>Exclusions: {t.exclusions || "No additional exclusions specified"}</p><p>Stacking: {t.stacking === "none" ? "Not stackable" : t.stacking === "merchant_promotions" ? "With merchant promotions" : t.stacking_policy}</p></div>;
}
export function MerchantState({ data }: { data: MerchantData }) { return data.restricted ? <p role="status">This merchant or location context is restricted.</p> : data.unavailable ? <p role="status">The merchant workspace is temporarily unavailable.</p> : null; }

export function CategoryChoice({ categories = [], all = false, defaultValue }: { categories?: { key: string; name: string }[]; all?: boolean; defaultValue?: string }) { return <label>Category<select name="category" defaultValue={defaultValue}>{all && <option value="">All categories</option>}{categories.map(c=><option key={c.key} value={c.key}>{c.name}</option>)}</select></label>; }
