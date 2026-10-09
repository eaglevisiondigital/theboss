import { requireSession } from "@/lib/auth/session";
import { PartnerDiscovery } from "@/components/partners/discovery";
export const dynamic="force-dynamic";
export default async function PartnerDiscoveryPage(){await requireSession("/app/partners/discovery");return <PartnerDiscovery/>;}
