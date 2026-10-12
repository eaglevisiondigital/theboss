import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import test from "node:test";
import { createAuthorizeNetAdapter, normalizeAuthorizeNet } from "../src/lib/payments/providers/authorize-net";
import { createNmiAdapter, normalizeNmi } from "../src/lib/payments/providers/nmi";
import { decimalAmount, providerMinor, type ProviderAccountContext, type ProviderCommand, type ProviderCredentials, type ProviderFetch } from "../src/lib/payments/providers/contracts";
import { providerJson } from "../src/lib/payments/providers/http";
import { verifiedWebhook } from "../src/lib/payments/providers/webhooks";
import { executePaymentOperation, type OperationClaim, type PaymentExecutionRepository } from "../src/lib/payments/execution";

// These are nonfunctional local contract fixtures, never real provider keys,
// profiles, collection tokens or payment instruments. No network is contacted.
const account: ProviderAccountContext = { id: "controlled-account", organizationId: "controlled-org", provider: "authorize_net", environment: "sandbox", merchantReference: "controlled-merchant", country: "US", currency: "USD", capabilities: ["card_sale", "auth_capture", "ach", "saved_profile", "refund", "partial_refund"], verified: true };
const credentials: ProviderCredentials = { provider: "authorize_net", environment: "sandbox", merchantReference: account.merchantReference, apiLogin: "LOCAL-CONTRACT-ONLY", transactionKey: "LOCAL-CONTRACT-ONLY", signatureKey: "a".repeat(128) };
const command: ProviderCommand = { kind: "sale", requestReference: "localcontract0000001", amountMinor: "35000", currency: "USD", method: "card", tokenizedMethod: { kind: "opaque", descriptor: "COMMON.ACCEPT.INAPP.PAYMENT", value: "LOCAL-CONTRACT-ONLY" } };
const nmiAccount = { ...account, provider: "nmi" as const };
const nmiCredentials = { ...credentials, provider: "nmi" as const, apiKey: "LOCAL-CONTRACT-ONLY", signatureKey: "LOCAL-CONTRACT-SIGNATURE-ONLY" };
const nmiCommand = { ...command, tokenizedMethod: { kind: "nmi_token" as const, value: "a".repeat(24) } };
function json(value: unknown) { return new Response(JSON.stringify(value), { headers: { "Content-Type": "application/json" } }); }
function stub(value: unknown) { const calls: { url: string; init: RequestInit }[] = []; const fetcher: ProviderFetch = async (url, init) => { calls.push({ url, init }); return json(value); }; return { calls, fetcher }; }
const anetSale = { transactionResponse: { responseCode: "1", transId: "LOCAL-TRANSACTION", authAmount: "350.00" }, refId: command.requestReference };
const nmiSale = { id: "LOCAL-TRANSACTION", amount: "350.00", currency: "USD", response: "1", status: "pendingsettlement", order_details: { id: command.requestReference } };

test("minor currency conversion is exact and rejects zero/fractional/overflow input", () => {
 assert.equal(decimalAmount("35000"), "350.00"); assert.equal(decimalAmount("1"), "0.01");
 for (const bad of ["0", "01", "1.2", "-1", "1000000001", "1e2", "NaN"]) assert.equal(decimalAmount(bad), null);
 assert.equal(providerMinor("350.01"), "35001"); assert.equal(providerMinor("0.01"), "1");
 for (const bad of ["0.001", "1e2", "-1", "10000000.01", null, {}]) assert.equal(providerMinor(bad), undefined);
});
test("Authorize.Net tokenized sale captures without claiming settlement", async () => {
 const s = stub(anetSale); const adapter = createAuthorizeNetAdapter(s.fetcher);
 const result = await adapter.execute(account, credentials, command); assert.equal(result.state, "captured");
 assert.equal(adapter.supportsNativeIdempotency, false); assert.equal(s.calls.length, 1);
 assert.equal(s.calls[0].url, "https://apitest.authorize.net/xml/v1/request.api");
 const body = JSON.parse(s.calls[0].init.body as string).createTransactionRequest;
 assert.equal(body.transactionRequest.amount, "350.00"); assert.equal(body.transactionRequest.payment.opaqueData.dataDescriptor, "COMMON.ACCEPT.INAPP.PAYMENT");
 assert.equal(body.transactionRequest.payment.creditCard, undefined); assert.equal(s.calls[0].init.redirect, "error"); assert.equal(s.calls[0].init.cache, "no-store");
});
for (const patch of [{ verified: false }, { environment: "production" as const }, { provider: "nmi" as const }, { merchantReference: "unrelated-merchant" }, { capabilities: [] }]) {
 test(`Authorize.Net rejects mismatched/unverified account ${JSON.stringify(patch)}`, async () => {
  const s = stub(anetSale); assert.equal((await createAuthorizeNetAdapter(s.fetcher).execute({ ...account, ...patch }, credentials, command)).state, "unknown"); assert.equal(s.calls.length, 0);
 });
}
test("Authorize.Net production money movement is disabled independently of valid context", async () => {
 const s = stub(anetSale); const a = { ...account, environment: "production" as const }; const c = { ...credentials, environment: "production" as const };
 assert.equal((await createAuthorizeNetAdapter(s.fetcher).execute(a, c, command)).state, "unknown"); assert.equal(s.calls.length, 0);
});
test("Authorize.Net auth and capture remain distinct", async () => {
 const s = stub(anetSale); const adapter = createAuthorizeNetAdapter(s.fetcher);
 assert.equal((await adapter.execute(account, credentials, { ...command, kind: "authorize" })).state, "authorized");
 assert.equal((await adapter.execute(account, credentials, { ...command, kind: "capture", transactionReference: "LOCAL-TRANSACTION" })).state, "captured");
 assert.equal(JSON.parse(s.calls[1].init.body as string).createTransactionRequest.transactionRequest.transactionType, "priorAuthCaptureTransaction");
});
test("Authorize.Net ACH accepted submission remains pending", () => assert.equal(normalizeAuthorizeNet(anetSale, { kind: "sale", method: "ach" }).state, "ach_pending"));
test("Authorize.Net authoritative settlement is a separate result", () => assert.equal(normalizeAuthorizeNet({ transaction: { transId: "LOCAL-TRANSACTION", transactionStatus: "settledSuccessfully", settleAmount: "350.00" } }, command).state, "settled"));
test("Authorize.Net decline/error/duplicate are conservatively distinct", () => {
 assert.equal(normalizeAuthorizeNet({ transactionResponse: { responseCode: "2", transId: "0" } }, command).state, "declined");
 for (const responseCode of ["3", "4"]) assert.equal(normalizeAuthorizeNet({ transactionResponse: { responseCode, transId: "LOCAL-TRANSACTION", errors: [{ errorText: "DO NOT RECORD" }] } }, command).state, "unknown");
 assert.equal(normalizeAuthorizeNet({ transaction: { transactionStatus: "settledSuccessfully" } }, command).state, "unknown");
});
test("Authorize.Net partial refund uses the original reference and masked last four only", async () => {
 const s = stub(anetSale); const result = await createAuthorizeNetAdapter(s.fetcher).execute(account, credentials, { ...command, kind: "refund", amountMinor: "1000", transactionReference: "LOCAL-TRANSACTION", lastFour: "0000" });
 assert.equal(result.state, "refund_pending"); const body = JSON.parse(s.calls[0].init.body as string).createTransactionRequest.transactionRequest;
 assert.equal(body.refTransId, "LOCAL-TRANSACTION"); assert.deepEqual(body.payment.creditCard, { cardNumber: "0000", expirationDate: "XXXX" });
});
test("Authorize.Net unsupported ACH refund is fail closed", async () => {
 const s = stub(anetSale); assert.equal((await createAuthorizeNetAdapter(s.fetcher).execute(account, credentials, { ...command, kind: "refund", method: "ach", transactionReference: "LOCAL-TRANSACTION", lastFour: "0000" })).state, "unknown"); assert.equal(s.calls.length, 0);
});
test("bounded refunds require certified partial-refund account capability", async () => {
 const a = stub(anetSale); const n = stub(nmiSale);
 const refund = { ...command, kind: "refund" as const, amountMinor: "1000", transactionReference: "LOCAL-TRANSACTION", lastFour: "0000" };
 assert.equal((await createAuthorizeNetAdapter(a.fetcher).execute({ ...account, capabilities: ["refund"] }, credentials, refund)).state, "unknown");
 assert.equal((await createNmiAdapter(n.fetcher).execute({ ...nmiAccount, capabilities: ["refund"] }, nmiCredentials, refund)).state, "unknown");
 assert.equal(a.calls.length + n.calls.length, 0);
});
test("provider responses project safe metadata without provider text/address/unmasked data", () => {
 const result = normalizeAuthorizeNet({ transaction: { transId: "LOCAL-TRANSACTION", transactionStatus: "settledSuccessfully", payment: { creditCard: { cardNumber: "UNMASKED-DATA-MUST-NOT-BE-KEPT", cardType: "Visa" } }, billTo: { firstName: "DO NOT RECORD" }, messages: [{ text: "DO NOT RECORD" }], AVSResponse: "Y", cardCodeResponse: "M" } }, command);
 assert.equal(result.method, undefined); assert.equal(JSON.stringify(result).includes("DO NOT RECORD"), false); assert.deepEqual(result.risk, { avs: "Y", cvvResult: "M" });
});
test("NMI sale uses exact sandbox route, token-only JSON, disabled provider receipts", async () => {
 const s = stub(nmiSale); const adapter = createNmiAdapter(s.fetcher); const result = await adapter.execute(nmiAccount, nmiCredentials, nmiCommand);
 assert.equal(result.state, "captured"); assert.equal(adapter.supportsNativeIdempotency, false); assert.equal(s.calls[0].url, "https://sandbox.nmi.com/api/v5/payments/sale");
 const body = JSON.parse(s.calls[0].init.body as string); assert.deepEqual(Object.keys(body.payment_details), ["payment_token"]); assert.equal(body.customer_receipt, false); assert.deepEqual(body.order_details, { id: command.requestReference });
});
test("NMI production endpoint is fail closed pending account certification", async () => {
 const s = stub(nmiSale); assert.equal((await createNmiAdapter(s.fetcher).execute({ ...nmiAccount, environment: "production" }, { ...nmiCredentials, environment: "production" }, nmiCommand)).state, "unknown"); assert.equal(s.calls.length, 0);
});
test("NMI rejects foreign collection tokens and account/method mismatch", async () => {
 const s = stub(nmiSale); const a = createNmiAdapter(s.fetcher);
 assert.equal((await a.execute(nmiAccount, nmiCredentials, command)).state, "unknown");
 assert.equal((await a.execute(nmiAccount, { ...nmiCredentials, merchantReference: "other" }, nmiCommand)).state, "unknown");
 assert.equal((await a.execute({ ...nmiAccount, capabilities: ["card_sale"] }, nmiCredentials, { ...nmiCommand, method: "ach" })).state, "unknown"); assert.equal(s.calls.length, 0);
});
test("NMI ACH pending, card auth, settlement and refund have separate states", () => {
 assert.equal(normalizeNmi(nmiSale, { kind: "sale", method: "ach" }).state, "ach_pending");
 assert.equal(normalizeNmi(nmiSale, { kind: "authorize", method: "card" }).state, "authorized");
 assert.equal(normalizeNmi({ ...nmiSale, status: "complete" }, command).state, "settled");
 assert.equal(normalizeNmi(nmiSale, { kind: "refund", method: "card" }).state, "refund_pending");
 assert.equal(normalizeNmi({ ...nmiSale, response: "3" }, command).state, "unknown");
});
test("NMI refund never passes zero as full refund and includes ACH variant", async () => {
 const s = stub(nmiSale); const a = createNmiAdapter(s.fetcher);
 assert.equal((await a.execute(nmiAccount, nmiCredentials, { ...nmiCommand, kind: "refund", amountMinor: "0", transactionReference: "LOCAL-TRANSACTION" })).state, "unknown"); assert.equal(s.calls.length, 0);
 await a.execute(nmiAccount, nmiCredentials, { ...nmiCommand, kind: "refund", amountMinor: "1000", method: "ach", transactionReference: "LOCAL-TRANSACTION" });
 assert.deepEqual(JSON.parse(s.calls[0].init.body as string), { amount: "10.00", payment: "check" });
});
test("NMI retrieval uses the stored transaction and no replacement sale", async () => {
 const s = stub({ ...nmiSale, status: "complete" }); const result = await createNmiAdapter(s.fetcher).retrieve(nmiAccount, nmiCredentials, { transactionReference: "LOCAL-TRANSACTION", method: "card", operation: "sale" });
 assert.equal(result.state, "settled"); assert.equal(s.calls[0].init.method, "GET"); assert.equal(s.calls[0].url.endsWith("/payments/LOCAL-TRANSACTION"), true);
});
test("NMI profile save keeps references only; remote customer-wide deletion is disabled", async () => {
 const s = stub({ response: "1", id: "LOCAL-PROFILE", transaction_id: "LOCAL-TRANSACTION" }); const a = createNmiAdapter(s.fetcher);
 assert.deepEqual((await a.execute(nmiAccount, nmiCredentials, { ...nmiCommand, kind: "save_profile", amountMinor: "0" })).profile, { customerReference: "LOCAL-PROFILE" });
 assert.equal((await a.execute(nmiAccount, nmiCredentials, { ...nmiCommand, kind: "revoke_profile", amountMinor: "0" })).state, "unknown"); assert.equal(s.calls.length, 1);
});
for (const provider of ["authorize_net", "nmi"] as const) {
 test(`${provider} webhook validates raw-body signature and returns only routing hints`, () => {
  const c = provider === "authorize_net" ? credentials : nmiCredentials;
  const body = new TextEncoder().encode(JSON.stringify(provider === "authorize_net" ? { notificationId: "LOCAL-EVENT", eventType: "net.authorize.payment.authcapture.created", payload: { id: "LOCAL-TRANSACTION", amount: "350.00", private_data: "DO NOT RECORD" } } : { event_id: "LOCAL-EVENT", event_type: "transaction.sale.success", event_body: { transaction_id: "LOCAL-TRANSACTION", private_data: "DO NOT RECORD" } }));
  const signature = provider === "authorize_net" ? "sha512=" + createHmac("sha512", Buffer.from(c.signatureKey!, "hex")).update(body).digest("hex") : "t=LOCAL-NONCE,s=" + createHmac("sha256", c.signatureKey!).update("LOCAL-NONCE.").update(body).digest("hex");
  const headers = new Headers({ [provider === "authorize_net" ? "x-anet-signature" : "webhook-signature"]: signature });
  const result = verifiedWebhook(provider, body, headers, c); assert.equal(result?.transactionReference, "LOCAL-TRANSACTION"); assert.equal(result?.bodyDigest.length, 64); assert.equal(JSON.stringify(result).includes("DO NOT RECORD"), false);
  assert.equal(verifiedWebhook(provider, new TextEncoder().encode("altered"), headers, c), null); assert.equal(verifiedWebhook(provider, body, headers, { ...c, signatureKey: provider === "authorize_net" ? "b".repeat(128) : "WRONG-LOCAL-FIXTURE" }), null);
  assert.equal(verifiedWebhook(provider, body, headers, { ...c, provider: provider === "authorize_net" ? "nmi" : "authorize_net" }), null); assert.equal(verifiedWebhook(provider, new Uint8Array(65_537), headers, c), null);
 });
}
test("provider transport discards errors/invalid JSON/excessive body/redirects without retries", async () => {
 for (const fetcher of [async () => { throw new Error("PRIVATE MESSAGE MUST NOT LEAVE TRANSPORT"); }, async () => new Response("PRIVATE MESSAGE", { status: 401 }), async () => new Response("not-json"), async () => new Response("x".repeat(262_145)), async () => new Response("{}", { headers: { "Content-Length": "262145" } })]) assert.equal(await providerJson(fetcher, "https://example.invalid", {}), null);
 assert.deepEqual(await providerJson(async () => new Response("\uFEFF{}"), "https://example.invalid", {}), {});
});
function repository(firstDispatch: boolean, transactionReference?: string) {
 let claimed = false; let finished: unknown; const claim: OperationClaim = { operationId: "LOCAL-OPERATION", generation: "LOCAL-GENERATION", account, command, firstDispatch, transactionReference };
 const value: PaymentExecutionRepository = { async claim() { if (claimed) return null; claimed = true; return claim; }, async finish(_claim, result) { finished = result; return true; } };
 return { value, finished: () => finished };
}
test("concurrent payment workers cause one initial dispatch", async () => {
 const r = repository(true); const s = stub(anetSale); const adapter = createAuthorizeNetAdapter(s.fetcher);
 const results = await Promise.all([executePaymentOperation("LOCAL-OPERATION", r.value, adapter, async () => credentials, command.tokenizedMethod), executePaymentOperation("LOCAL-OPERATION", r.value, adapter, async () => credentials, command.tokenizedMethod)]);
 assert.deepEqual(results.sort(), ["skipped", "updated"]); assert.equal(s.calls.length, 1);
});
test("timeout/recovered dispatch without reference is unresolved and never recharged", async () => {
 const r = repository(false); const s = stub(anetSale);
 await executePaymentOperation("LOCAL-OPERATION", r.value, createAuthorizeNetAdapter(s.fetcher), async () => credentials, command.tokenizedMethod);
 assert.deepEqual(r.finished(), { state: "unknown" }); assert.equal(s.calls.length, 1); assert.ok(JSON.parse(s.calls[0].init.body as string).getUnsettledTransactionListRequest);
});
test("recovered dispatch queries original transaction", async () => {
 const r = repository(false, "LOCAL-TRANSACTION"); const s = stub({ transaction: { transId: "LOCAL-TRANSACTION", transactionStatus: "settledSuccessfully", settleAmount: "350.00" } });
 await executePaymentOperation("LOCAL-OPERATION", r.value, createAuthorizeNetAdapter(s.fetcher), async () => credentials);
 assert.equal(s.calls.length, 1); assert.equal(JSON.parse(s.calls[0].init.body as string).getTransactionDetailsRequest.transId, "LOCAL-TRANSACTION");
});
test("unconfigured execution stays unknown without simulated payment", async () => {
 const r = repository(true); await executePaymentOperation("LOCAL-OPERATION", r.value, null, async () => null); assert.deepEqual(r.finished(), { state: "unknown" });
});
test("success without verified amount remains a reconciliation hint", async () => {
 const r = repository(true); const s = stub({ transactionResponse: { responseCode: "1", transId: "LOCAL-TRANSACTION" } });
 await executePaymentOperation("LOCAL-OPERATION", r.value, createAuthorizeNetAdapter(s.fetcher), async () => credentials, command.tokenizedMethod);
 assert.deepEqual(r.finished(), { state: "unknown", transactionReference: "LOCAL-TRANSACTION" });
});
for (const patch of [{ settleAmount: "351.00" }, { transId: "UNRELATED-TRANSACTION" }]) {
 test(`recovered evidence mismatch rejected ${JSON.stringify(patch)}`, async () => {
  const r = repository(false, "LOCAL-TRANSACTION"); const s = stub({ transaction: { transId: "LOCAL-TRANSACTION", transactionStatus: "settledSuccessfully", settleAmount: "350.00", ...patch } });
  await executePaymentOperation("LOCAL-OPERATION", r.value, createAuthorizeNetAdapter(s.fetcher), async () => credentials); assert.deepEqual(r.finished(), { state: "unknown" });
 });
}

test("unknown Authorize.Net request is queried by its original reference without redispatch",async()=>{
 const calls:RequestInit[]=[];let count=0;
 const adapter=createAuthorizeNetAdapter(async(_url,init)=>{calls.push(init);return new Response(JSON.stringify(count++===0?{transactions:[{transId:"LOCAL-FOUND",invoiceNumber:command.requestReference}]}:{transaction:{transId:"LOCAL-FOUND",transactionStatus:"capturedPendingSettlement",authAmount:"350.00",order:{invoiceNumber:command.requestReference}}}));});
 const r=repository(false);await executePaymentOperation("LOCAL",r.value,adapter,async()=>credentials);
 assert.equal(calls.length,2);assert.ok(JSON.parse(calls[0].body as string).getUnsettledTransactionListRequest);assert.ok(JSON.parse(calls[1].body as string).getTransactionDetailsRequest);assert.equal((r.finished() as {state:string}).state,"captured");
});
test("ambiguous Authorize.Net reference stays unknown rather than choosing a transaction",async()=>{
 const s=stub({transactions:[{transId:"LOCAL-A",invoiceNumber:command.requestReference},{transId:"LOCAL-B",invoiceNumber:command.requestReference}]});
 assert.deepEqual(await createAuthorizeNetAdapter(s.fetcher).lookupRequest!(account,credentials,command),{state:"unknown"});assert.equal(s.calls.length,1);
});

import{authorizeNetBatches,authorizeNetBatchPage,nmiReportPage}from"../src/lib/payments/providers/reporting";
test("Authorize.Net batch reporting is bounded, safe and does not invent processor cost",async()=>{
 const s=stub({transactions:[{transId:"LOCAL-BATCH-TX",invoiceNumber:command.requestReference,transactionStatus:"settledSuccessfully",settleAmount:"350.00",private_data:"DROP-REPORT-DATA"}]});const rows=await authorizeNetBatchPage(s.fetcher,{...account,capabilities:[...account.capabilities,"settlement_query"]},credentials,"LOCAL-BATCH",0);assert.equal(rows?.[0].amountMinor,"35000");assert.doesNotMatch(JSON.stringify(rows),/DROP-REPORT|fee|customer/);assert.deepEqual(JSON.parse(s.calls[0].init.body as string).getTransactionListRequest.paging,{limit:100,offset:1});
});
test("provider batch date ranges cannot scan full history",async()=>{let calls=0;const fetcher=async()=>{calls++;return new Response('{}');};assert.equal(await authorizeNetBatches(fetcher,account,credentials,"2026-01-01","2026-10-07"),null);assert.equal(calls,0);});
test("NMI reporting rejects entity declarations before reference extraction",async()=>{let requests=0;assert.equal(await nmiReportPage(async()=>{requests++;return new Response('<!DOCTYPE x><nm_response/>');},{...account,provider:"nmi",capabilities:["settlement_query"]}, {provider:"nmi",environment:"sandbox",merchantReference:account.merchantReference,apiKey:"LOCAL-ONLY-CONTRACT"},"2026-10-01","2026-10-02",0),null);assert.equal(requests,1);});
