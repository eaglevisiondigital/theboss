import { isUuid } from "@/lib/partners/contracts";
import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadPartners } from "@/lib/partners/data";
import { PartnerWorkspace } from "@/components/partners/workspace";
import {headers}from"next/headers";
import {emitPartnerDiagnostic,PARTNER_CORRELATION_HEADER,validPartnerCorrelation}from"@/lib/partners/diagnostics";
export const metadata:Metadata={title:"Partner Network",robots:{index:false,follow:false}};
export const dynamic="force-dynamic";
export default async function PartnerPage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){const supplied=(await headers()).get(PARTNER_CORRELATION_HEADER),correlationId=validPartnerCorrelation(supplied)?supplied:crypto.randomUUID();emitPartnerDiagnostic({correlationId,phase:"server-component",stage:"page_enter",observedAt:"src/app/app/partners/page.tsx",operation:"partners.read"});const input=await searchParams;const provider=isUuid(input.provider_id)?input.provider_id:undefined;await requireSession("/app/partners");return <><h1>Partner Network administration</h1><PartnerWorkspace diagnosticCorrelation={correlationId} data={await loadPartners(provider,correlationId)}/></>;}
