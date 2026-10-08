"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { Json } from "@/lib/supabase/database.types";
import { record, type Terms, type MerchantData, type Market } from "@/lib/merchants/contracts";
import { parseMerchantCommand, type MerchantCommand } from "@/lib/merchants/input";
import { money } from "@/lib/fundraising/contracts";
import type { MerchantAction } from "@/lib/merchants/fields";
import { MERCHANT_CORRELATION_HEADER } from "@/lib/merchants/diagnostics";
import { merchantClientDiagnostic, merchantClientReceipt } from "@/lib/merchants/diagnostics-client";
export type Act = (action: MerchantAction, input: Record<string, Json>) => Promise<Record<string, unknown> | null>;
export function useMerchantAction() {
 const router = useRouter(), [busy, setBusy] = useState(false), [message, setMessage] = useState("");
 const pending = useRef<MerchantCommand | null>(null), [retry, setRetry] = useState(false);
 async function send(command: MerchantCommand): Promise<Record<string, unknown> | null> {
  if (busy) return null; setBusy(true); setRetry(false);
  try { const response = await fetch("/app/merchants/mutate", { method: "POST", credentials: "same-origin", headers: { "content-type": "application/json" }, body: JSON.stringify(command) });
   merchantClientReceipt(response.headers.get(MERCHANT_CORRELATION_HEADER),response.status,command.action==="offer.status"?"offer.status":"merchant.mutation");
   const data: unknown = await response.json();
   if (!record(data) || data.ok !== true) { setMessage(record(data) && typeof data.error === "string" ? data.error : "The change could not be confirmed."); setRetry(response.status >= 500); return null; }
   setMessage(data.replayed ? "Existing request confirmed." : "Change confirmed."); pending.current = null;
   merchantClientDiagnostic({stage:"refresh_requested",observedAt:"src/components/merchants/shared.tsx"});router.refresh();return data;
  } catch(error) { merchantClientDiagnostic({stage:"client_exception",observedAt:"src/components/merchants/shared.tsx",classification:"exception",error});setMessage("This request could not be confirmed. Retry the same request safely."); setRetry(true); return null; } finally { setBusy(false); }
 }
 const act: Act = async (action, input) => { const command = parseMerchantCommand({ action, input, request_id: crypto.randomUUID() }); if (!command) { setMessage("Review the merchant fields."); return null; } pending.current = command; return send(command); };
 return { act, busy, status: <div role="status" aria-live="polite"><p>{message}</p>{retry && <button className="button button-outline" disabled={busy} onClick={() => { if (pending.current) void send(pending.current); }}>Retry the same request</button>}</div> };
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
