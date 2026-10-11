"use client";
import { fundraisingFetch, fundraisingClientRendered, fundraisingClientDiagnostic } from "@/lib/fundraising/diagnostics-client";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { money } from "@/lib/fundraising/contracts";
import type { AllocationCommand, AllocationData, AllocationQuery } from "@/lib/fundraising-allocation/contracts";
import { parseAllocationCommand } from "@/lib/fundraising-allocation/contracts";

const text = (value: unknown) => typeof value === "string" || typeof value === "number" ? String(value) : "";
function minor(value: unknown, currency: string) {
 const amount = typeof value === "string" && /^-?\d+$/.test(value) ? Number(value) : value;
 return typeof amount === "number" && Number.isSafeInteger(amount) ? money(amount, currency) : "Pending verification";
}
export function AllocationConsole({ data, scope, diagnosticId }: { data: AllocationData; scope: AllocationQuery; diagnosticId?: string }) {
 useEffect(()=>fundraisingClientRendered(diagnosticId,"src/components/fundraising/allocation-console.tsx"),[diagnosticId]);
 const router = useRouter(), [busy, setBusy] = useState(false), [notice, setNotice] = useState("");
 const retry = useRef<{ fingerprint: string; command: AllocationCommand } | null>(null);
 async function save(event: FormEvent<HTMLFormElement>) {
  event.preventDefault();const form = new FormData(event.currentTarget), selected = data.platform_policies.find(policy => policy.id === form.get("platform_policy_id"));
  if (!selected) { setNotice("Select an approved platform policy.");return; }
  const starts = Date.parse(String(form.get("starts_at"))), ends = form.get("ends_at") ? Date.parse(String(form.get("ends_at"))) : null;
  if (!Number.isFinite(starts) || ends !== null && !Number.isFinite(ends)) { setNotice("Enter valid effective dates.");return; }
  const input = { campaign_id: scope.campaign_id, ...(scope.team_id ? { team_id: scope.team_id } : {}), ...(scope.unit_id ? { unit_id: scope.unit_id } : {}), channel: selected.channel, platform_policy_id: selected.id,
   organization_bps: Number(form.get("organization_bps")), destination_bps: Number(form.get("destination_bps")), participant_bps: Number(form.get("participant_bps")),
   starts_at: new Date(starts).toISOString(), ...(form.get("ends_at") ? { ends_at: new Date(ends!).toISOString() } : {}) };
  const fingerprint = JSON.stringify(input), command = retry.current?.fingerprint === fingerprint ? retry.current.command : parseAllocationCommand({ action: "allocation_policy.create", request_id: crypto.randomUUID(), input });
  if (!command) { setNotice("Review the exact scope, dates and allocation percentages.");return; }
  retry.current = { fingerprint, command };setBusy(true);setNotice("");
  try {
   const response = await fundraisingFetch("/app/fundraising/allocation/mutate", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(command) }, "allocation.command"), result: unknown = await response.json();
   if (response.ok && typeof result === "object" && result !== null && "ok" in result && result.ok === true) { retry.current = null;setNotice("Allocation revision saved. Earlier transactions keep their captured policy.");fundraisingClientDiagnostic({stage:"response_accepted",observedAt:"src/components/fundraising/allocation-console.tsx",classification:"confirmed-success"});fundraisingClientDiagnostic({stage:"refresh_requested",observedAt:"src/components/fundraising/allocation-console.tsx"});router.refresh(); }
   else setNotice("The revision could not be confirmed. Review your current authority and reuse this request when retrying.");
  } catch { setNotice("The revision could not be confirmed. Keep the same inputs when retrying."); } finally { setBusy(false); }
 }
 return <>
  <p>Platform revenue uses its separately approved policy. Internal fundraising credit is a noncash designation of organization proceeds; it does not create another payable, fee payment or Wallet grant.</p>
  <p role="status" aria-live="polite">{notice}</p>
  {data.can_manage && <section><h2>Local allocation revision</h2>{data.platform_policies.length ? <form className="bucks-form" onSubmit={save}>
   <label>Approved platform policy<select name="platform_policy_id" required><option value="">Select policy</option>{data.platform_policies.map(policy => <option key={text(policy.id)} value={text(policy.id)}>{text(policy.channel)} · revision {text(policy.revision)}</option>)}</select></label>
   <label>Organization designation, basis points<input name="organization_bps" type="number" min={0} max={10000} step={1} required /></label>
   <label>Exact team or ministry designation, basis points<input name="destination_bps" type="number" min={0} max={scope.team_id || scope.unit_id ? 10000 : 0} step={1} required /></label>
   <label>Participant internal credit, basis points<input name="participant_bps" type="number" min={0} max={10000} step={1} required /></label>
   <label>Effective start<input name="starts_at" type="datetime-local" required /></label><label>Effective end, optional<input name="ends_at" type="datetime-local" /></label>
   <p>The designations must total 10,000 basis points and remain within the selected platform policy. Sources without a participant retain the unassigned participant portion as organization designation.</p>
   <button disabled={busy}>Save immutable revision</button>
  </form> : <p>An authorized platform reviewer must establish the channel economics before local allocations can be configured.</p>}</section>}
  <section><h2>Captured transaction reporting</h2><p>This page contains up to 100 exact-scope transactions. Donation principal, product sales, processor cash and internal credit are separate measures.</p>
   {data.source_page.length ? data.source_page.map(source => <article className="bucks-card" key={text(source.checkout_id)}>
    <h3>{text(source.channel)} · {text(source.state)}</h3><dl>
     <dt>Gross verified provider cash</dt><dd>{minor(source.gross_verified_cash_minor, data.currency)}</dd>
     <dt>Gross donation principal</dt><dd>{minor(source.gross_donation_minor, data.currency)}</dd>
     <dt>Confirmed donation refunds</dt><dd>{minor(source.confirmed_donation_refunds_minor, data.currency)}</dd>
     <dt>Net donation principal</dt><dd>{minor(source.net_donation_minor, data.currency)}</dd>
     <dt>Digital card sales</dt><dd>{minor(source.gross_digital_card_sales_minor, data.currency)}</dd>
     <dt>Physical card sales</dt><dd>{minor(source.gross_physical_card_sales_minor, data.currency)}</dd>
     <dt>Product-sale refunds</dt><dd>{minor(source.product_sale_refunds_minor, data.currency)}</dd>
     <dt>Net product sales</dt><dd>{minor(source.net_product_sales_minor, data.currency)}</dd>
     <dt>Product-sale organization credit</dt><dd>{minor(source.product_sale_organization_credit_minor, data.currency)}</dd>
     <dt>Platform revenue</dt><dd>{minor(source.platform_revenue_minor, data.currency)}</dd>
     <dt>Actual processor cost</dt><dd>{minor(source.actual_processor_cost_minor, data.currency)}</dd>
     <dt>Original verified organization allocation</dt><dd>{minor(source.organization_allocation_minor, data.currency)}</dd>
     <dt>Independent Wallet earning</dt><dd>{minor(source.wallet_earning_minor, data.currency)}</dd>
     <dt>Wallet source adjustment</dt><dd>{minor(source.wallet_source_correction_minor, data.currency)}</dd>
     <dt>Pending payment principal</dt><dd>{minor(source.pending_payment_minor, data.currency)}</dd>
     <dt>Prepared checkout reserved tile value</dt><dd>{minor(source.reserved_tile_value_minor, data.currency)}</dd>
     <dt>Permanently claimed tiles</dt><dd>{text(source.permanently_claimed_tiles)}</dd>
     <dt>Organization payable</dt><dd>{minor(source.organization_payable_minor, data.currency)}</dd>
     <dt>Organization paid</dt><dd>{minor(source.organization_paid_minor, data.currency)}</dd>
     <dt>Organization deficit</dt><dd>{minor(source.organization_deficit_minor, data.currency)}</dd>
     <dt>Provider settlement</dt><dd>{text(source.provider_settlement)}</dd><dt>Payout ownership</dt><dd>{text(source.organization_payout_status)}</dd>
    </dl>{Array.isArray(source.noncash_designations) && source.noncash_designations.map((entry, index) => entry && typeof entry === "object" && "category" in entry && "amount_minor" in entry ? <p key={index}>{text(entry.category)}: {minor(entry.amount_minor, data.currency)} internal credit</p> : null)}
   </article>) : <p>No captured sources in this scope.</p>}
   {data.next_after && <a className="button button-outline" href={`/app/fundraising/allocation?${new URLSearchParams({ campaign: scope.campaign_id, ...(scope.team_id ? { team: scope.team_id } : {}), ...(scope.unit_id ? { unit: scope.unit_id } : {}), after: data.next_after })}`}>Next transactions</a>}
  </section>
 </>;
}
