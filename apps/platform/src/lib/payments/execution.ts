import { providerContextValid, type PaymentProviderAdapter, type ProviderAccountContext, type ProviderCommand, type ProviderCredentials, type SafeProviderResult, type TokenizedMethod } from "./providers/contracts";
export type OperationClaim = Readonly<{
 operationId: string; generation: string; account: ProviderAccountContext;
 command: Omit<ProviderCommand, "tokenizedMethod">;
 /** True only on the first durable transition from prepared to dispatched. */
 firstDispatch: boolean;
 transactionReference?: string;
}>;
export interface PaymentExecutionRepository {
 /** Must fence current authority/configuration and atomically persist dispatch. */
 claim(operationId: string): Promise<OperationClaim | null>;
 /** Appends normalized evidence only; financial commitment is a separate gate. */
 finish(claim: OperationClaim, result: SafeProviderResult): Promise<boolean>;
}
export type PrivateCredentialResolver = (account: ProviderAccountContext) => Promise<ProviderCredentials | null>;
/** No transport retry: a recovered dispatch is retrieved or left unresolved. */
export async function executePaymentOperation(operationId: string, repository: PaymentExecutionRepository, adapter: PaymentProviderAdapter | null, resolve: PrivateCredentialResolver, token?: TokenizedMethod): Promise<"skipped" | "updated" | "stale"> {
 const claim = await repository.claim(operationId); if (!claim) return "skipped";
 let result: SafeProviderResult = { state: "unknown" };
 try {
  const credentials = adapter ? await resolve(claim.account) : null;
  if (adapter && credentials && adapter.provider === claim.account.provider && providerContextValid(claim.account, credentials)) {
   if (claim.firstDispatch) {
    let lastFour=claim.command.lastFour;
    if(claim.command.kind==="refund" && claim.command.method==="card" && adapter.provider==="authorize_net" && claim.command.transactionReference && !lastFour){
     const original=await adapter.retrieve(claim.account,credentials,{transactionReference:claim.command.transactionReference,method:"card",operation:"sale"});
     if(original.transactionReference===claim.command.transactionReference && original.state==="settled")lastFour=original.method?.lastFour;
    }
    result = await adapter.execute(claim.account, credentials, { ...claim.command, tokenizedMethod: token, lastFour });
   }
   else if (!claim.transactionReference && adapter.lookupRequest) result = await adapter.lookupRequest(claim.account, credentials, claim.command);
   else if (claim.transactionReference) result = await adapter.retrieve(claim.account, credentials, { transactionReference: claim.transactionReference, method: claim.command.method, operation: claim.command.kind });
  }
  if (result.currency && result.currency !== claim.command.currency || result.amountMinor && result.amountMinor !== claim.command.amountMinor
   || result.requestReference && result.requestReference !== claim.command.requestReference
   || !claim.firstDispatch && claim.transactionReference && result.transactionReference && result.transactionReference !== claim.transactionReference) result = { state: "unknown" };
  if (!["save_profile", "revoke_profile"].includes(claim.command.kind) && !["unknown", "declined", "failed"].includes(result.state)
   && (!result.transactionReference || result.amountMinor !== claim.command.amountMinor)) {
   // A success code without verifiable amount is a polling hint, never financial
   // completion. Keep only its safe transaction reference for reconciliation.
   result = { state: "unknown", transactionReference: result.transactionReference };
  }
 } catch { result = { state: "unknown" }; }
 return await repository.finish(claim, result) ? "updated" : "stale";
}
