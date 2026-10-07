"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { BucksCommand } from "@/lib/boss-bucks/contracts";
const features = { wallet: "Wallet", fundraising_issuance: "Trusted fundraising issuance", family_wallet: "Family wallet", organization_wallet_reporting: "Organization reporting", charge_eligibility_preview: "Read-only charge preview" };
export function WalletFeatures({ organizationId, fields }: { organizationId: string; fields: Record<string, unknown> }) {
 const router = useRouter(), pending = useRef<BucksCommand | null>(null), [busy, setBusy] = useState(false), [notice, setNotice] = useState("");
 async function save(form: FormData) { setBusy(true); const input = { organization_id: organizationId, features: Object.fromEntries(Object.keys(features).map(k => [k, form.get(k) === "on"])) }, old = pending.current, command = old && JSON.stringify(old.input) === JSON.stringify(input) ? old : { action: "features.configure", request_id: crypto.randomUUID(), input }; pending.current = command;
 try { const response = await fetch("/app/boss-bucks/mutate", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(command) }), result = await response.json(); if (!response.ok || !result.ok) { setNotice(typeof result.error === "string" ? result.error : "The change could not be confirmed."); return; } pending.current = null; setNotice("Wallet features saved."); router.refresh(); } catch { setNotice("The change could not be confirmed. Retry safely."); } finally { setBusy(false); } }
 return <details><summary>Configure Boss Bucks features</summary><form action={save} className="bucks-form">{Object.entries(features).map(([key, label]) => <label className="fundraising-check" key={key}><input type="checkbox" name={key} defaultChecked={fields[`${key}_enabled`] === true} />{label}</label>)}<p>Earning requires a separate explicit campaign policy. Spending, transfers, settlement, cards and merchant discounts remain unavailable.</p><button className="button button-outline" disabled={busy}>Save wallet features</button><p role="status">{notice}</p></form></details>;
}
