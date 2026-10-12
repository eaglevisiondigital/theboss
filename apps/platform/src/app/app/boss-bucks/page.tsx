import type { Metadata } from "next";
import Link from "next/link";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { loadBucks } from "@/lib/boss-bucks/data";
import { bucksQuery } from "@/lib/boss-bucks/input";
import { BucksConsole } from "@/components/boss-bucks/console";
export const metadata: Metadata = { title: "Boss Bucks Wallet" };
export const dynamic = "force-dynamic";
export default async function BucksPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
 await requireSession("/app/boss-bucks"); const input = await searchParams, admin = await loadAdminView("home", input.org), organization = input.view === "organization", org = typeof input.org === "string" ? input.org : admin.organizationId ?? undefined, query = bucksQuery({ ...input, org }, organization);
 if (!query) return <p role="status">Review the wallet filters.</p>; const data = await loadBucks(query);
 return <><h1>Boss Bucks Wallet</h1><nav className="bucks-tabs" aria-label="Wallet views"><Link href="/app/boss-bucks">Family wallet</Link><Link href="/app/boss-bucks/discounts">Discounts memberships</Link><Link href={`/app/boss-bucks?view=organization${org ? `&org=${org}` : ""}`}>Organization report</Link></nav>{organization && <form method="get" className="bucks-form"><input type="hidden" name="view" value="organization" /><label>Organization<select name="org" defaultValue={org}>{admin.organizations.map(o => <option key={o.id} value={o.id}>{o.label}</option>)}</select></label><button className="button button-outline">View organization</button></form>}<BucksConsole data={data} filters={Object.fromEntries(Object.entries(input).filter((entry): entry is [string, string] => typeof entry[1] === "string"))} walletId={typeof query.wallet_id === "string" ? query.wallet_id : undefined} organizationId={organization ? org : undefined} /></>;
}
