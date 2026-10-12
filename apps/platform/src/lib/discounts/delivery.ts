import { isSameOriginPost } from "../auth/request-security";
import { readBoundedJson } from "../communications/input";
import { verifiedCommunicationCaller, type GuardedClient } from "../communications/mutation";
import type { Json } from "../supabase/database.types";
import { discountRecord } from "./contracts";
import { discountFailure } from "./mutation";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export type DeliveryClient = GuardedClient & { rpc(name: "boss_discounts_read", args: { query: Json }): PromiseLike<{ data: unknown; error: { code?: string } | null }> };
export async function performDiscountDeliveryRead(request: Request, client: DeliveryClient, origin: string) {
 if (!isSameOriginPost(request,origin)) return discountFailure("PT403");
 if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json") return discountFailure("PT422");
 const input = await readBoundedJson(request,4_000);
 if (!discountRecord(input) || Object.keys(input).some(k => !["organization_id","order_id"].includes(k)) || ![input.organization_id,input.order_id].every(v => typeof v === "string" && uuid.test(v))) return discountFailure("PT422");
 try {
  if (!await verifiedCommunicationCaller(client)) return discountFailure("PT401");
  const { data, error } = await client.rpc("boss_discounts_read", { query: { ...input, mode: "delivery" } });
  if (error) return discountFailure(error.code);
  if (!discountRecord(data) || data.mode !== "delivery") return discountFailure();
  if (data.delivery === null) return { status: 200, body: { ok: true, delivery: null } };
  if (!discountRecord(data.delivery) || Object.keys(data.delivery).some(k => !["email","address"].includes(k)) || data.delivery.email !== null && (typeof data.delivery.email !== "string" || data.delivery.email.length > 254)) return discountFailure();
  const address = data.delivery.address;
  if (address !== null && (!discountRecord(address) || Object.entries(address).some(([k,v]) => !["recipient","line1","line2","city","region","postal_code","country"].includes(k) || typeof v !== "string" || v.length > 200))) return discountFailure();
  return { status: 200, body: { ok: true, delivery: data.delivery } };
 } catch { return discountFailure(); }
}
