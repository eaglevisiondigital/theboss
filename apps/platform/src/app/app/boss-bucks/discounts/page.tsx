import type { Metadata } from "next";
import Link from "next/link";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { loadDiscounts } from "@/lib/discounts/data";
import { discountsQuery } from "@/lib/discounts/input";
import { DiscountsConsole } from "@/components/discounts/console";
export const metadata: Metadata = { title: "Boss Bucks Discounts" };
export const dynamic = "force-dynamic";
export default async function DiscountsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
 await requireSession("/app/boss-bucks/discounts"); const input = await searchParams, admin = await loadAdminView("home", input.org), org = typeof input.org === "string" ? input.org : admin.organizationId ?? undefined, query = discountsQuery({ ...input, ...(org ? { org } : {}) });
 if (!query) return <p role="status">Review the membership filters.</p>; const data = await loadDiscounts(query), suffix = org ? `?org=${org}` : "";
 return <><h1>Boss Bucks Discounts</h1><nav className="bucks-tabs" aria-label="Boss Bucks areas"><Link href={`/app/boss-bucks${suffix}`}>Wallet: earned fundraising value</Link><Link href={`/app/boss-bucks/discounts${suffix}`} aria-current={input.view !== "organization" ? "page" : undefined}>Discounts: membership access</Link><Link href={`/app/boss-bucks/discounts?view=organization${org ? `&org=${org}` : ""}`}>Products &amp; inventory</Link></nav>
 {input.view === "organization" && <form method="get" className="discount-form"><input type="hidden" name="view" value="organization" /><label>Organization<select name="org" defaultValue={org}>{admin.organizations.map(o => <option key={o.id} value={o.id}>{o.label}</option>)}</select></label><button className="button button-outline">View products</button></form>}
 <DiscountsConsole data={data} organizationId={org} path={typeof input.path === "string" ? input.path : undefined} /></>;
}
