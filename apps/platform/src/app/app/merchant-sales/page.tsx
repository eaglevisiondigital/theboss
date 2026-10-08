import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadMerchants } from "@/lib/merchants/data";
import { merchantQuery } from "@/lib/merchants/input";
import { MerchantSales } from "@/components/merchants/sales";
export const metadata: Metadata = { title: "Merchant sales workspace", robots: { index: false, follow: false } };
export const dynamic = "force-dynamic";
export default async function MerchantSalesPage({ searchParams }: { searchParams: Promise<Record<string,string|string[]|undefined>> }) { await requireSession("/app/merchant-sales");const input=await searchParams,query=merchantQuery(input,"sales");if(!query)return <p role="status">Review the sales context.</p>;return <><h1>Merchant sales workspace</h1><MerchantSales query={query} data={await loadMerchants(query)} /></>; }
