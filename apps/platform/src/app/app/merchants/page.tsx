import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadMerchants } from "@/lib/merchants/data";
import { merchantQuery } from "@/lib/merchants/input";
import { MerchantPortal } from "@/components/merchants/portal";
import { headers } from "next/headers";
import { emitMerchantDiagnostic, MERCHANT_CORRELATION_HEADER, validMerchantCorrelation } from "@/lib/merchants/diagnostics";
export const metadata: Metadata = { title: "Merchant workspace", robots: { index: false, follow: false } };
export const dynamic = "force-dynamic";
export default async function MerchantPage({ searchParams }: { searchParams: Promise<Record<string,string|string[]|undefined>> }) {
 const supplied = (await headers()).get(MERCHANT_CORRELATION_HEADER);
 const correlationId = validMerchantCorrelation(supplied) ? supplied : crypto.randomUUID();
 emitMerchantDiagnostic({correlationId,stage:"page_enter",phase:"server-component",observedAt:"src/app/app/merchants/page.tsx"});
 await requireSession("/app/merchants");
 const input=await searchParams,query=merchantQuery(input,"portal");
 if(!query)return <p role="status">Review the merchant context.</p>;
 return <><h1>Merchant workspace</h1><MerchantPortal diagnosticCorrelation={correlationId} data={await loadMerchants(query,false,correlationId)} merchantId={typeof input.merchant_id==="string" ? input.merchant_id : undefined} locationId={typeof input.location_id==="string" ? input.location_id : undefined} /></>;
}
