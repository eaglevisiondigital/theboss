import { decimalAmount, providerCommandValid, providerContextValid, providerMinor, record, safeCode, safeReference, type PaymentProviderAdapter, type ProviderCommand, type ProviderFetch, type SafeProviderResult } from "./contracts";
import { providerJson, providerText } from "./http";
import { verifiedWebhook } from "./webhooks";
// The current public v5 reference specifies this sandbox host. Production
// remains closed until the exact merchant endpoint is certified and reviewed.
const sandboxBase = "https://sandbox.nmi.com/api/v5";
export function normalizeNmi(value: unknown, command: Pick<ProviderCommand, "kind" | "method">): SafeProviderResult {
 if (!record(value)) return { state: "unknown" };
 const transactionReference = safeReference(value.id);
 if (!transactionReference || transactionReference === "0") return { state: "unknown" };
 let state: SafeProviderResult["state"] = "unknown";
 const response = String(value.response ?? "");
 if (response === "2") state = "declined";
 else if (response === "1") {
  if (command.kind === "void") state = "voided";
  else if (command.kind === "refund") state = value.status === "complete" ? "refunded" : "refund_pending";
  else if (value.status === "complete") state = "settled";
  else if (command.kind === "authorize" || value.status === "pending") state = "authorized";
  else if (["pendingsettlement", "approved"].includes(String(value.status))) state = command.method === "ach" ? "ach_pending" : "captured";
 }
 const details = record(value.payment_details) ? value.payment_details : null;
 const masked = typeof details?.card_number === "string" && /^[0-9Xx*]*[Xx*]+[0-9]{4}$/.test(details.card_number) ? details.card_number.slice(-4) : undefined;
 const order = record(value.order_details) ? value.order_details : null;
 const customerReference = safeReference(value.customer_vault_id, 36);
 return { state, transactionReference, amountMinor: providerMinor(value.amount),
  currency: typeof value.currency === "string" && /^[A-Z]{3}$/.test(value.currency) ? value.currency : undefined,
  requestReference: safeReference(order?.id, 20),
  risk: { avs: safeCode(value.avs_response), cvvResult: safeCode(value.cvv_response) },
  ...(masked ? { method: { brand: safeCode(details?.card_type), lastFour: masked } } : {}),
  ...(customerReference ? { profile: { customerReference } } : {}),
  ...(state === "declined" ? { decline: "payment_declined" } : {}),
 };
}
export function createNmiAdapter(fetcher: ProviderFetch): PaymentProviderAdapter {
 return { provider: "nmi", supportsNativeIdempotency: false,
  async execute(account, credentials, command) {
   if (!providerContextValid(account, credentials) || account.provider !== "nmi" || account.environment !== "sandbox" || !credentials.apiKey || !providerCommandValid(account, command)) return { state: "unknown" };
   const headers = { "Content-Type": "application/json", Authorization: credentials.apiKey };
   // Removing a customer can also remove its other billing methods. Local
   // revocation remains available; remote deletion awaits an exact profile
   // ownership contract rather than broad deletion of a customer container.
   if (command.kind === "revoke_profile") return { state: "unknown" };
   if (command.kind === "save_profile") {
    if (command.tokenizedMethod?.kind !== "nmi_token" || !/^[a-f0-9]{24}$/i.test(command.tokenizedMethod.value)) return { state: "unknown" };
    const value = await providerJson(fetcher, `${sandboxBase}/customers`, { method: "POST", headers,
     body: JSON.stringify({ payment_details: { payment_token: command.tokenizedMethod.value } }) });
    if (!record(value) || String(value.response) !== "1" || !safeReference(value.id, 36)) return { state: "unknown" };
    return { state: "authorized", profile: { customerReference: safeReference(value.id, 36)! }, transactionReference: safeReference(value.transaction_id) };
   }
   const body: Record<string, unknown> = { amount: decimalAmount(command.amountMinor) };
   let path: string;
   if (["capture", "void", "refund"].includes(command.kind)) {
    if (!safeReference(command.transactionReference)) return { state: "unknown" };
    path = `/payments/${encodeURIComponent(command.transactionReference!)}/${command.kind}`;
    if (command.kind === "void") delete body.amount;
    if (command.kind === "refund" && command.method === "ach") body.payment = "check";
   } else {
    path = `/payments/${command.kind === "authorize" ? "auth" : "sale"}`;
    const token = command.tokenizedMethod;
    if (token?.kind === "nmi_token" && /^[a-f0-9]{24}$/i.test(token.value)) body.payment_details = { payment_token: token.value };
    else if (token?.kind === "profile" && safeReference(token.customerReference, 36) && !token.paymentReference) body.payment_details = { customer_vault_id: token.customerReference };
    else return { state: "unknown" };
    body.currency = command.currency; body.order_details = { id: command.requestReference }; body.dup_seconds = 28_800;
    // Provider receipts are disabled; Boss builds receipts from canonical
    // principal, allocation, fees and currency instead of provider text.
    body.customer_receipt = false;
   }
   return normalizeNmi(await providerJson(fetcher, sandboxBase + path, { method: "POST", headers, body: JSON.stringify(body) }), command);
  },
  async lookupRequest(account,credentials,query){
   if(!providerContextValid(account,credentials)||account.provider!=="nmi"||account.environment!=="sandbox"||!credentials.apiKey||!/^[a-z0-9]{20}$/.test(query.requestReference))return{state:"unknown"};
   const xml=await providerText(fetcher,"https://sandbox.nmi.com/api/query.php",{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({security_key:credentials.apiKey,order_id:query.requestReference,result_limit:"100",page_number:"0"}).toString()});
   // Extract only finite reference fields, never materialize customer/bank fields.
   // DTD/entity declarations and ambiguous matches are rejected outright.
   if(!xml||/<!DOCTYPE|<!ENTITY/i.test(xml))return{state:"unknown"};
   const transactions=[...xml.matchAll(/<transaction>([\s\S]*?)<\/transaction>/g)];if(transactions.length>100)return{state:"unknown"};
   const matches=transactions.filter(t=>t[1].match(/<order_id>([a-z0-9]{20})<\/order_id>/)?.[1]===query.requestReference);
   const id=matches.length===1?matches[0][1].match(/<transaction_id>([A-Za-z0-9_.:-]{1,100})<\/transaction_id>/)?.[1]:undefined;if(!id)return{state:"unknown"};
   const value=await providerJson(fetcher,`${sandboxBase}/payments/${encodeURIComponent(id)}`,{method:"GET",headers:{Authorization:credentials.apiKey}});
   const result=normalizeNmi(value,query);return result.requestReference===query.requestReference&&result.amountMinor===query.amountMinor?result:{state:"unknown"};
  },
  async retrieve(account, credentials, query) {
   if (!providerContextValid(account, credentials) || account.provider !== "nmi" || account.environment !== "sandbox" || !credentials.apiKey || !safeReference(query.transactionReference)) return { state: "unknown" };
   const value = await providerJson(fetcher, `${sandboxBase}/payments/${encodeURIComponent(query.transactionReference)}`, { method: "GET", headers: { Authorization: credentials.apiKey } });
   return normalizeNmi(value, { kind: query.operation, method: query.method });
  }, verifyWebhook: (body, headers, credentials) => verifiedWebhook("nmi", body, headers, credentials),
 };
}
