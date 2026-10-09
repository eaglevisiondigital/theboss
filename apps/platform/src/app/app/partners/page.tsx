import { isUuid } from "@/lib/partners/contracts";
import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadPartners } from "@/lib/partners/data";
import { PartnerWorkspace } from "@/components/partners/workspace";
export const metadata:Metadata={title:"Partner Network",robots:{index:false,follow:false}};
export const dynamic="force-dynamic";
export default async function PartnerPage({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){const input=await searchParams;const provider=isUuid(input.provider_id)?input.provider_id:undefined;await requireSession("/app/partners");return <><h1>Partner Network administration</h1><PartnerWorkspace data={await loadPartners(provider)}/></>;}
