import { decimalAmount, providerCommandValid, providerContextValid, providerMinor, record, safeCode, safeReference, type PaymentProviderAdapter, type ProviderAccountContext, type ProviderCommand, type ProviderCredentials, type ProviderFetch, type SafeProviderResult } from "./contracts";
import { providerJson } from "./http";
import { verifiedWebhook } from "./webhooks";
const endpoint = { sandbox: "https://apitest.authorize.net/xml/v1/request.api", production: "https://api.authorize.net/xml/v1/request.api" } as const;
function merchant(credentials: ProviderCredentials) { return { name: credentials.apiLogin, transactionKey: credentials.transactionKey }; }
function anetStatus(status: unknown, method: "card" | "ach"): SafeProviderResult["state"] {
 return ({ authorizedPendingCapture: "authorized", capturedPendingSettlement: method === "ach" ? "ach_pending" : "captured", settledSuccessfully: "settled", refundPendingSettlement: "refund_pending", refundSettledSuccessfully: "refunded", voided: "voided", declined: "declined", couldNotSettle: "failed", returnedItem: "returned" } as Record<string, SafeProviderResult["state"]>)[String(status)] ?? "unknown";
}
export function normalizeAuthorizeNet(value: unknown, command: Pick<ProviderCommand, "kind" | "method">): SafeProviderResult {
 if (!record(value)) return { state: "unknown" };
 const result = value.transaction ?? value.transactionResponse; if (!record(result)) return { state: "unknown" };
 const transactionReference = safeReference(String(result.transId ?? ""));
 let state = anetStatus(result.transactionStatus, command.method);
 if (!result.transactionStatus) {
  if (String(result.responseCode) === "1" && transactionReference && transactionReference !== "0") state = command.kind === "authorize" ? "authorized" : command.kind === "void" ? "voided" : command.kind === "refund" ? "refund_pending" : command.method === "ach" ? "ach_pending" : "captured";
  else if (String(result.responseCode) === "2") state = "declined";
  // Error/duplicate code can describe an already processed operation. Unknown
  // remains reconcilable; a generic API error is not a declined charge.
 }
 if (!transactionReference || transactionReference === "0") state = state === "declined" ? state : "unknown";
 const methodData = result.payment; const card = record(methodData) && record(methodData.creditCard) ? methodData.creditCard : null;
 const masked = card && typeof card.cardNumber === "string" && /^[Xx*]+[0-9]{4}$/.test(card.cardNumber) ? card.cardNumber.slice(-4) : undefined;
 const customer = record(result.profile) ? result.profile : null;
 return { state, ...(transactionReference && transactionReference !== "0" ? { transactionReference } : {}),
  amountMinor: providerMinor(result.settleAmount ?? result.authAmount),
  requestReference: record(result.order) ? safeReference(result.order.invoiceNumber, 20) : safeReference(value.refId, 20),
  risk: { avs: safeCode(result.AVSResponse ?? result.avsResultCode), cvvResult: safeCode(result.cardCodeResponse ?? result.cvvResultCode) },
  ...(masked ? { method: { lastFour: masked, brand: safeCode(card?.cardType) } } : {}),
  ...(customer && safeReference(customer.customerProfileId) ? { profile: { customerReference: safeReference(customer.customerProfileId)!, paymentReference: safeReference(customer.customerPaymentProfileId) } } : {}),
  ...(state === "declined" ? { decline: "payment_declined" } : {}),
 };
}
export function createAuthorizeNetAdapter(fetcher: ProviderFetch, allowProductionMoneyMovement = false): PaymentProviderAdapter {
 return { provider: "authorize_net", supportsNativeIdempotency: false,
  async execute(account, credentials, command) {
   if (!providerContextValid(account, credentials) || account.provider !== "authorize_net" || !credentials.apiLogin || !credentials.transactionKey || !providerCommandValid(account, command)
    || account.environment === "production" && !allowProductionMoneyMovement) return { state: "unknown" };
   if (command.kind === "revoke_profile" || command.kind === "save_profile") return profileOperation(fetcher, account, credentials, command);
   const types = { sale: "authCaptureTransaction", authorize: "authOnlyTransaction", capture: "priorAuthCaptureTransaction", void: "voidTransaction", refund: "refundTransaction" } as const;
   const transaction: Record<string, unknown> = { transactionType: types[command.kind], amount: decimalAmount(command.amountMinor), currencyCode: command.currency };
   if (["capture", "void", "refund"].includes(command.kind)) {
    if (!safeReference(command.transactionReference)) return { state: "unknown" }; transaction.refTransId = command.transactionReference;
    if (command.kind === "refund") { if (command.method !== "card" || !/^[0-9]{4}$/.test(command.lastFour ?? "")) return { state: "unknown" }; transaction.payment = { creditCard: { cardNumber: command.lastFour, expirationDate: "XXXX" } }; }
   } else {
    const token = command.tokenizedMethod;
    if (token?.kind === "opaque" && token.descriptor === "COMMON.ACCEPT.INAPP.PAYMENT" && token.value.length >= 1 && token.value.length <= 4096) transaction.payment = { opaqueData: { dataDescriptor: token.descriptor, dataValue: token.value } };
    else if (token?.kind === "profile" && safeReference(token.customerReference) && safeReference(token.paymentReference)) transaction.profile = { customerProfileId: token.customerReference, paymentProfile: { paymentProfileId: token.paymentReference } };
    else return { state: "unknown" };
    transaction.order = { invoiceNumber: command.requestReference };
    transaction.transactionSettings = { setting: [{ settingName: "duplicateWindow", settingValue: "28800" }] };
   }
   const value = await providerJson(fetcher, endpoint[account.environment], { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ createTransactionRequest: { merchantAuthentication: merchant(credentials), refId: command.requestReference, transactionRequest: transaction } }) });
   return normalizeAuthorizeNet(value, command);
  },
  async lookupRequest(account, credentials, query) {
   if (!providerContextValid(account,credentials) || account.provider !== "authorize_net" || !credentials.apiLogin || !credentials.transactionKey || !/^[a-z0-9]{20}$/.test(query.requestReference)) return { state: "unknown" };
   const list = await providerJson(fetcher,endpoint[account.environment],{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({getUnsettledTransactionListRequest:{merchantAuthentication:merchant(credentials),paging:{limit:1000,offset:1}}})});
   if (!record(list) || !Array.isArray(list.transactions) || list.transactions.length>1000) return {state:"unknown"};
   const matches=list.transactions.filter(t=>record(t) && t.invoiceNumber===query.requestReference);
   if(matches.length!==1 || !record(matches[0]) || !safeReference(String(matches[0].transId??""))) return {state:"unknown"};
   const value=await providerJson(fetcher,endpoint[account.environment],{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({getTransactionDetailsRequest:{merchantAuthentication:merchant(credentials),transId:String(matches[0].transId)}})});
   const result=normalizeAuthorizeNet(value,query);
   return result.requestReference===query.requestReference && result.amountMinor===query.amountMinor ? result : {state:"unknown"};
  },
  async retrieve(account, credentials, query) {
   if (!providerContextValid(account, credentials) || account.provider !== "authorize_net" || !credentials.apiLogin || !credentials.transactionKey || !safeReference(query.transactionReference)) return { state: "unknown" };
   const value = await providerJson(fetcher, endpoint[account.environment], { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ getTransactionDetailsRequest: { merchantAuthentication: merchant(credentials), transId: query.transactionReference } }) });
   return normalizeAuthorizeNet(value, { kind: query.operation, method: query.method });
  }, verifyWebhook: (body, headers, credentials) => verifiedWebhook("authorize_net", body, headers, credentials),
 };
}
async function profileOperation(fetcher: ProviderFetch, account: ProviderAccountContext, credentials: ProviderCredentials, command: ProviderCommand): Promise<SafeProviderResult> {
 const token = command.tokenizedMethod;
 if (command.kind === "revoke_profile") {
  if (token?.kind !== "profile" || !safeReference(token.customerReference) || !safeReference(token.paymentReference)) return { state: "unknown" };
  const value = await providerJson(fetcher, endpoint[account.environment], { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ deleteCustomerPaymentProfileRequest: { merchantAuthentication: merchant(credentials), customerProfileId: token.customerReference, customerPaymentProfileId: token.paymentReference } }) });
  return record(value) && record(value.messages) && value.messages.resultCode === "Ok" ? { state: "voided" } : { state: "unknown" };
 }
 // Profile creation is based on a verified prior transaction, never raw card data.
 if (!safeReference(command.transactionReference)) return { state: "unknown" };
 const value = await providerJson(fetcher, endpoint[account.environment], { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ createCustomerProfileFromTransactionRequest: { merchantAuthentication: merchant(credentials), transId: command.transactionReference } }) });
 if (!record(value) || !record(value.messages) || value.messages.resultCode !== "Ok" || !safeReference(value.customerProfileId)) return { state: "unknown" };
 const paymentIds = value.customerPaymentProfileIdList;
 return { state: "authorized", profile: { customerReference: safeReference(value.customerProfileId)!, paymentReference: Array.isArray(paymentIds) ? safeReference(paymentIds[0]) : undefined } };
}
