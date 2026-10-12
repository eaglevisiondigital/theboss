import "server-only";
import type { PaymentProviderAdapter } from "./providers/contracts";
/** No operational payment worker/account/secret resolver is provisioned. */
export function configuredPaymentProvider(): PaymentProviderAdapter | null { return null; }
import type { PrivatePaymentRuntime } from "./runtime";
/** Provisioning requires approved private DB/secret infrastructure and account certification. */
export function configuredPaymentRuntime(): PrivatePaymentRuntime | null { return null; }
