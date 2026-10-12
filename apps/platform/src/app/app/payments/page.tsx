import type { Metadata } from "next";
import Link from "next/link";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { loadPayments } from "@/lib/payments/data";
import { paymentQuery } from "@/lib/payments/input";
import { PaymentsConsole } from "@/components/payments/console";
export const metadata: Metadata = { title: "Payments and Settlement" };
export const dynamic = "force-dynamic";
export default async function PaymentsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
 await requireSession("/app/payments"); const input = await searchParams, admin = await loadAdminView("home", input.org), organization = input.view === "organization", org = typeof input.org === "string" ? input.org : admin.organizationId ?? undefined, query = paymentQuery({ ...input, ...(organization ? { org } : {}) });
 return <><h1>Payments and settlement</h1><nav className="bucks-tabs" aria-label="Payment views"><Link href="/app/payments">Family payments</Link><Link href={`/app/payments?view=organization${org ? `&org=${org}` : ""}`}>Organization finance</Link></nav>{organization && <form method="get" className="bucks-form"><input type="hidden" name="view" value="organization" /><label>Organization<select name="org" defaultValue={org}>{admin.organizations.map(o => <option key={o.id} value={o.id}>{o.label}</option>)}</select></label><button className="button button-outline">View organization</button></form>}{query ? <PaymentsConsole data={await loadPayments(query)} organizationId={organization ? org : undefined} /> : <p role="status">Select an organization or review the payment filters.</p>}</>;
}
