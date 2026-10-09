"use client";
import { useState } from "react";
import type { Json } from "@/lib/supabase/database.types";
import type { ChargePreview, BucksReceipt, BucksPayment } from "@/lib/boss-bucks/contracts";
import { bucksAmount, bucksDecimal, bucksMoney as money } from "@/lib/boss-bucks/money";

export function BucksCheckout({ charge: c, busy, pay }: { charge: ChargePreview; busy: boolean; pay: (action: string, input: Record<string, Json>) => Promise<void> }) {
 const [chosen, setChosen] = useState(bucksDecimal(c.eligible_minor, c.currency));
 const amount = bucksAmount(chosen, c.currency), valid = amount !== null && BigInt(amount) <= BigInt(c.eligible_minor);
 const remaining = BigInt(c.due_minor) - BigInt(valid ? amount : 0);
 return <article className="bucks-card"><h4>{c.title}</h4><p>{c.organization} · {c.currency}</p><dl><div><dt>Amount due</dt><dd>{money(c.due_minor, c.currency)}</dd></div><div><dt>Boss Bucks available for this organization</dt><dd>{money(c.available_minor, c.currency)}</dd></div><div><dt>Maximum Boss Bucks</dt><dd>{money(c.eligible_minor, c.currency)}</dd></div><div><dt>Remaining balance</dt><dd>{money(remaining.toString(), c.currency)}</dd></div></dl><p>Only Boss Bucks earned with {c.organization} can pay this obligation.</p>
 {c.payment_available ? <form className="bucks-form" action={() => valid ? pay("payment.spend", { wallet_id: c.wallet_id, organization_id: c.organization_id, currency: c.currency, amount_minor: amount, allocations: [{ charge_id: c.charge_id, amount_minor: amount }] }) : undefined}><label>Boss Bucks to apply ({c.currency})<input inputMode="decimal" name="amount" value={chosen} onChange={e => setChosen(e.target.value)} required maxLength={16} /></label><p>Choose the full eligible amount or a smaller amount. Any remaining balance stays unpaid.</p>{!valid && <p role="status">Enter a positive amount within the maximum Boss Bucks shown.</p>}<button className="button button-primary" disabled={busy || !valid}>Use Boss Bucks</button></form> : <p>{BigInt(c.eligible_minor) === 0n ? "No Boss Bucks are available to apply to this charge." : "Boss Bucks payment is unavailable for this charge's current settings or authority."}</p>}
 </article>;
}
export function BucksPaymentReceipt({ receipt: r }: { receipt: BucksReceipt }) {
 return <section className="bucks-card" aria-label="Boss Bucks payment receipt"><h3>{r.status === "reversed" ? "Boss Bucks payment reversed" : "Boss Bucks payment recorded"}</h3><p>{r.organization} · {new Date(r.at).toLocaleDateString("en-US", { timeZone: "UTC" })}</p><p>{money(r.amount_minor, r.currency)} · Boss Bucks</p>{r.charges.map(c => <div key={c.charge_id}><h4>{c.title}</h4><p>{money(c.amount_minor, r.currency)} {r.status === "reversed" ? "reversed" : "applied"} · Balance at this receipt: {money(c.remaining_minor, r.currency)}</p></div>)}<p>Reference: {r.payment_id}</p></section>;
}
export function BucksPaymentReversal({ payment: p, busy, reverse }: { payment: BucksPayment; busy: boolean; reverse: (action: string, input: Record<string, Json>) => Promise<void> }) {
 const allocations = p.allocations.filter(a => BigInt(a.reversible_minor) > 0n);
 const [allocationId, setAllocationId] = useState(allocations[0]?.id ?? ""), [chosen, setChosen] = useState(""), [reason, setReason] = useState("");
 const allocation = allocations.find(a => a.id === allocationId), amount = bucksAmount(chosen, p.currency);
 const valid = !!allocation && amount !== null && BigInt(amount) <= BigInt(allocation.reversible_minor) && !!reason.trim() && reason.length <= 200;
 if (!allocations.length || p.status === "reversed") return null;
 return <details className="bucks-card"><summary>Reverse an authorized Boss Bucks payment</summary><form className="bucks-form" action={() => valid ? reverse("payment.reverse", { payment_id: p.payment_id, reason: reason.trim(), allocations: [{ allocation_id: allocationId, amount_minor: amount }] }) : undefined}><label>Original allocation<select value={allocationId} onChange={e => { setAllocationId(e.target.value); setChosen(""); }}>{allocations.map(a => <option key={a.id} value={a.id}>{a.title} · Up to {money(a.reversible_minor, p.currency)}</option>)}</select></label><label>Amount to reverse ({p.currency})<input inputMode="decimal" value={chosen} onChange={e => setChosen(e.target.value)} required maxLength={16} /></label><label>Reason<input value={reason} onChange={e => setReason(e.target.value)} required maxLength={200} /></label><p>A reversal reopens the corresponding charge balance. Returned value retains its original organization, source validity and expiration.</p><button className="button button-outline" disabled={busy || !valid}>Reverse selected amount</button></form></details>;
}
