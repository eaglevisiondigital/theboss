import { requireSession } from "@/lib/auth/session";
import { PartnerDiscovery } from "@/components/partners/discovery";
import {headers}from"next/headers";
import {emitPartnerDiagnostic,PARTNER_CORRELATION_HEADER,validPartnerCorrelation}from"@/lib/partners/diagnostics";
export const dynamic="force-dynamic";
export default async function PartnerDiscoveryPage(){
 const supplied=(await headers()).get(PARTNER_CORRELATION_HEADER),correlationId=validPartnerCorrelation(supplied)?supplied:crypto.randomUUID();
 const event=(stage:"page_enter"|"read_started"|"read_completed")=>emitPartnerDiagnostic({correlationId,route:"/app/partners/discovery",phase:"server-component",stage,observedAt:"src/app/app/partners/discovery/page.tsx",operation:"partners.discovery"});
 event("page_enter");event("read_started");await requireSession("/app/partners/discovery");event("read_completed");
 return <PartnerDiscovery diagnosticCorrelation={correlationId}/>;
}
