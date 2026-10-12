import { configuredPaymentRuntime } from "@/lib/payments/configured";
import { acceptPaymentWebhook } from "@/lib/payments/webhook-ingress";
export const dynamic="force-dynamic";
export async function POST(request:Request,{params}:{params:Promise<{accountId:string}>}){
 const {accountId}=await params;
 const status=await acceptPaymentWebhook(request,accountId,configuredPaymentRuntime());
 return Response.json({accepted:status===202},{status,headers:{"cache-control":"private, no-store","netlify-cdn-cache-control":"no-store"}});
}
