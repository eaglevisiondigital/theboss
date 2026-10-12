import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { record, safeReference, type ProviderCredentials, type ProviderWebhook } from "./contracts";
function matchHex(actual: string, expected: string): boolean {
 if (!/^[a-f0-9]+$/i.test(actual) || actual.length !== expected.length) return false;
 return timingSafeEqual(Buffer.from(actual, "hex"), Buffer.from(expected, "hex"));
}
/** Returns a routing hint only. The worker must retrieve authoritative details. */
export function verifiedWebhook(provider: "authorize_net" | "nmi", body: Uint8Array, headers: Headers, credentials: ProviderCredentials): ProviderWebhook | null {
 if (credentials.provider !== provider || !credentials.signatureKey || body.length > 65_536) return null;
 let verified: boolean;
 if (provider === "authorize_net") {
  if (!/^[a-f0-9]{128}$/i.test(credentials.signatureKey)) return null;
  const match = /^sha512=([a-f0-9]{128})$/i.exec(headers.get("x-anet-signature") ?? "");
  verified = !!match && matchHex(match[1], createHmac("sha512", Buffer.from(credentials.signatureKey, "hex")).update(body).digest("hex"));
 } else {
  const match = /^t=([A-Za-z0-9_-]{1,100}),s=([a-f0-9]{64})$/i.exec(headers.get("webhook-signature") ?? "");
  // NMI documents this value as a nonce, not a guaranteed Unix timestamp.
  // Persistent account/event uniqueness provides replay protection.
  verified = !!match && matchHex(match[2], createHmac("sha256", credentials.signatureKey).update(match[1] + ".").update(body).digest("hex"));
 }
 if (!verified) return null;
 try {
  const value: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(body)); if (!record(value)) return null;
  const payload = provider === "authorize_net" ? value.payload : value.event_body;
  if (!record(payload)) return null;
  const eventReference = safeReference(provider === "authorize_net" ? value.notificationId : value.event_id, 200);
  const transactionReference = safeReference(String(provider === "authorize_net" ? payload.id ?? "" : payload.transaction_id ?? ""));
  const type = safeReference(provider === "authorize_net" ? value.eventType : value.event_type, 100);
  if (!eventReference || !transactionReference || !type) return null;
  return { eventReference, transactionReference, type, bodyDigest: createHash("sha256").update(body).digest("hex") };
 } catch { return null; }
}
