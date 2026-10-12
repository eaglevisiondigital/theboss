import type { PaymentProviderAdapter, ProviderAccountContext } from "./providers/contracts";
import type { PaymentExecutionRepository, PrivateCredentialResolver } from "./execution";
export type PrivatePaymentRuntime = Readonly<{
 adapter: PaymentProviderAdapter; repository: PaymentExecutionRepository; resolveCredentials: PrivateCredentialResolver;
 account(id: string): Promise<ProviderAccountContext | null>;
 /** Exact account/transaction and previously dispatched operation only. */
 dispatchedCheckout(accountId: string, transactionReference: string): Promise<string | null>;
}>;
