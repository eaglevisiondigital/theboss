import type { Metadata } from "next";
import Link from "next/link";
import { requireSession } from "@/lib/auth/session";
import { loadMerchants } from "@/lib/merchants/data";
import { merchantQuery } from "@/lib/merchants/input";
import { MerchantDirectory } from "@/components/merchants/discovery";
export const metadata: Metadata = { title: "Boss Bucks member deals", robots: { index: false, follow: false } };
export const dynamic = "force-dynamic";
export default async function DealsPage({ searchParams }: { searchParams: Promise<Record<string,string|string[]|undefined>> }) { await requireSession("/app/boss-bucks/deals");const input=await searchParams,query=merchantQuery(input,"consumer");if(!query)return <p role="status">Review the discovery filters.</p>;return <><h1>Boss Bucks member deals</h1><nav className="bucks-tabs" aria-label="Boss Bucks areas"><Link href="/app/boss-bucks/discounts">Your discount membership</Link><Link href="/app/boss-bucks">Your separate Wallet</Link><Link href="/merchant-directory">Public merchant directory</Link></nav><MerchantDirectory query={query} data={await loadMerchants(query)} member marketId={typeof input.market_id==="string" ? input.market_id : undefined} /></>; }
