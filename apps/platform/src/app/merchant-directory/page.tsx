import type { Metadata } from "next";
import Link from "next/link";
import { Brand } from "@/components/brand";
import { loadMerchants } from "@/lib/merchants/data";
import { merchantQuery } from "@/lib/merchants/input";
import { MerchantDirectory } from "@/components/merchants/discovery";
export const metadata: Metadata = { title: "Boss merchant directory" };
export const dynamic = "force-dynamic";
export default async function MerchantDirectoryPage({ searchParams }: { searchParams: Promise<Record<string,string|string[]|undefined>> }) { const input=await searchParams,query=merchantQuery(input,"consumer");if(!query)return <p role="status">Review the directory filters.</p>;return <div className="container app-main"><header><Brand href="/" /><nav aria-label="Merchant network"><Link href="/app/merchants">Join the merchant network</Link></nav></header><main id="main-content"><h1>Boss merchant directory</h1><MerchantDirectory query={query} data={await loadMerchants(query,true)} marketId={typeof input.market_id==="string" ? input.market_id : undefined} /></main></div>; }
