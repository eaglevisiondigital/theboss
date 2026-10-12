"use client";
import { useState } from "react";
import { discountRecord } from "@/lib/discounts/contracts";
export function PrivateDelivery({ organizationId, orderId }: { organizationId?: string; orderId: string }) {
 const [busy,setBusy] = useState(false), [notice,setNotice] = useState(""), [delivery,setDelivery] = useState<{ email: string | null; address: Record<string,string> | null } | null>(null);
 async function read() {
  if (busy || !organizationId) return;setBusy(true);
  try {
   const response = await fetch("/app/boss-bucks/discounts/delivery", { method: "POST", cache: "no-store", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ organization_id: organizationId, order_id: orderId }) }), data: unknown = await response.json();
   if (!response.ok || !discountRecord(data) || data.ok !== true) { setNotice("Private fulfillment access is unavailable or restricted.");return; }
   if (!discountRecord(data.delivery)) { setNotice("No private delivery contact was supplied for this order.");return; }
   setDelivery({ email: typeof data.delivery.email === "string" ? data.delivery.email : null, address: discountRecord(data.delivery.address) ? Object.fromEntries(Object.entries(data.delivery.address).filter(([,v]) => typeof v === "string")) as Record<string,string> : null });setNotice("");
  } catch { setNotice("Private fulfillment information could not be confirmed."); } finally { setBusy(false); }
 }
 return <div>{delivery ? <><p>Private fulfillment contact</p>{delivery.email && <p>{delivery.email}</p>}{delivery.address && <address>{Object.values(delivery.address).map((line,n) => <div key={n}>{line}</div>)}</address>}<button className="button button-outline" onClick={() => setDelivery(null)}>Hide private delivery information</button></> : <button disabled={busy || !organizationId} className="button button-outline" onClick={read}>View private delivery information</button>}<p role="status">{notice}</p></div>;
}
