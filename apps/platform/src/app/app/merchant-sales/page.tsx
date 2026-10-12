import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadMerchants } from "@/lib/merchants/data";
import { merchantQuery } from "@/lib/merchants/input";
import { MerchantSales } from "@/components/merchants/sales";
import { headers } from "next/headers";
import { emitMerchantDiagnostic, MERCHANT_CORRELATION_HEADER, validMerchantCorrelation } from "@/lib/merchants/diagnostics";
export const metadata: Metadata = { title: "Merchant sales workspace", robots: { index: false, follow: false } };
export const dynamic = "force-dynamic";
export default async function MerchantSalesPage({ searchParams }: { searchParams: Promise<Record<string,string|string[]|undefined>> }) { const supplied=(await headers()).get(MERCHANT_CORRELATION_HEADER),correlationId=validMerchantCorrelation(supplied)?supplied:crypto.randomUUID();
 emitMerchantDiagnostic({correlationId,route:"/app/merchant-sales",stage:"page_enter",phase:"server-component",observedAt:"src/app/app/merchant-sales/page.tsx",operation:"sales.read"});
 await requireSession("/app/merchant-sales");const input=await searchParams,query=merchantQuery(input,"sales");if(!query)return <p role="status">Review the sales context.</p>;return <><h1>Merchant sales workspace</h1><MerchantSales diagnosticCorrelation={correlationId} query={query} data={await loadMerchants(query,false,correlationId)} /></>; }
