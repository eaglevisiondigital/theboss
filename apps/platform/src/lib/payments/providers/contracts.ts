export const providerKeys = ["authorize_net", "nmi"] as const;
export type ProviderKey = typeof providerKeys[number];
export type ProviderEnvironment = "sandbox" | "production";
export type ExternalMethod = "card" | "ach";
export const capabilityKeys = ["card_sale", "auth_capture", "ach", "saved_profile", "refund", "partial_refund", "webhook", "settlement_query"] as const;
export type ProviderCapability = typeof capabilityKeys[number];
export const providerCapabilities: Readonly<Record<ProviderKey, readonly ProviderCapability[]>> = {
 authorize_net: capabilityKeys, nmi: capabilityKeys,
};
export type ProviderState = "unknown" | "authorized" | "captured" | "ach_pending" | "settled" | "declined" | "failed" | "voided" | "refund_pending" | "refunded" | "returned";
export type DeclineCategory = "payment_declined" | "invalid_method" | "authentication_required" | "temporarily_unavailable";
export type SafeProviderResult = Readonly<{
 state: ProviderState; transactionReference?: string; amountMinor?: string; currency?: string;
 requestReference?: string; occurredAt?: string; decline?: DeclineCategory;
 risk?: Readonly<{ avs?: string; cvvResult?: string; decision?: string }>;
 profile?: Readonly<{ customerReference: string; paymentReference?: string }>;
 method?: Readonly<{ brand?: string; lastFour?: string }>;
}>;
export type ProviderAccountContext = Readonly<{
 id: string; organizationId: string; provider: ProviderKey; environment: ProviderEnvironment;
 merchantReference: string; country: "US" | "CA"; currency: string;
 capabilities: readonly ProviderCapability[]; verified: boolean;
}>;
/** Supplied by the approved private secret resolver. Never a public DTO or log. */
export type ProviderCredentials = Readonly<{
 provider: ProviderKey; environment: ProviderEnvironment; merchantReference: string;
 apiLogin?: string; transactionKey?: string; apiKey?: string; signatureKey?: string;
}>;
export type TokenizedMethod =
 | Readonly<{ kind: "opaque"; descriptor: string; value: string }>
 | Readonly<{ kind: "nmi_token"; value: string }>
 | Readonly<{ kind: "profile"; customerReference: string; paymentReference?: string }>;
export type ProviderCommand = Readonly<{
 kind: "sale" | "authorize" | "capture" | "void" | "refund" | "save_profile" | "revoke_profile";
 requestReference: string; amountMinor: string; method: ExternalMethod; currency: string;
 transactionReference?: string; tokenizedMethod?: TokenizedMethod; lastFour?: string;
}>;
export type ProviderQuery = Readonly<{ transactionReference: string; method: ExternalMethod; operation: ProviderCommand["kind"] }>;
export type ProviderWebhook = Readonly<{ eventReference: string; transactionReference: string; type: string; bodyDigest: string }>;
export interface PaymentProviderAdapter {
 readonly provider: ProviderKey;
 /** Correlation references/duplicate windows are not permanent idempotency. */
 readonly supportsNativeIdempotency: false;
 execute(account: ProviderAccountContext, credentials: ProviderCredentials, command: ProviderCommand): Promise<SafeProviderResult>;
 lookupRequest?(account: ProviderAccountContext, credentials: ProviderCredentials, query: Omit<ProviderCommand, "tokenizedMethod">): Promise<SafeProviderResult>;
 retrieve(account: ProviderAccountContext, credentials: ProviderCredentials, query: ProviderQuery): Promise<SafeProviderResult>;
 verifyWebhook(body: Uint8Array, headers: Headers, credentials: ProviderCredentials): ProviderWebhook | null;
}
export type ProviderFetch = (input: string, init: RequestInit) => Promise<Response>;
export function providerContextValid(account: ProviderAccountContext, credentials: ProviderCredentials): boolean {
 return account.verified && providerKeys.includes(account.provider) && ["sandbox", "production"].includes(account.environment)
  && credentials.provider === account.provider && credentials.environment === account.environment
  && credentials.merchantReference === account.merchantReference
  && ["US", "CA"].includes(account.country) && /^[A-Z]{3}$/.test(account.currency)
  && account.capabilities.every(c => providerCapabilities[account.provider].includes(c));
}
export function decimalAmount(minor: string): string | null {
 if (!/^[1-9][0-9]{0,9}$/.test(minor) || BigInt(minor) > 1_000_000_000n) return null;
 const value = BigInt(minor); return `${value / 100n}.${String(value % 100n).padStart(2, "0")}`;
}
export function providerMinor(value: unknown): string | undefined {
 if (typeof value !== "string" && typeof value !== "number") return;
 const text = String(value); if (!/^(0|[1-9][0-9]{0,7})(\.[0-9]{1,2})?$/.test(text)) return;
 const [whole, fractional = ""] = text.split("."); const n = BigInt(whole) * 100n + BigInt(fractional.padEnd(2, "0"));
 return n <= 1_000_000_000n ? String(n) : undefined;
}
export function record(value: unknown): value is Record<string, unknown> { return !!value && typeof value === "object" && !Array.isArray(value); }
export function safeReference(value: unknown, max = 100): string | undefined { return typeof value === "string" && /^[A-Za-z0-9_.:-]+$/.test(value) && value.length <= max ? value : undefined; }
export function safeCode(value: unknown): string | undefined { return typeof value === "string" && /^[A-Za-z0-9_-]{1,30}$/.test(value) ? value : undefined; }
export function providerCommandValid(account: ProviderAccountContext, command: ProviderCommand): boolean {
 const capability = ({ sale: command.method === "ach" ? "ach" : "card_sale", authorize: "auth_capture", capture: "auth_capture", void: "auth_capture", refund: "refund", save_profile: "saved_profile", revoke_profile: "saved_profile" } as const)[command.kind];
 return !!capability && account.capabilities.includes(capability) && /^[a-z0-9]{20}$/.test(command.requestReference)
  // Until a verified original-amount/full-refund contract exists, every bounded
  // amount refund requires explicitly certified partial-refund capability too.
  && (command.kind !== "refund" || account.capabilities.includes("partial_refund"))
  && ["USD", "CAD", "GBP", "DKK", "NOK", "PLN", "SEK", "EUR", "AUD", "NZD"].includes(command.currency)
  && command.currency === account.currency && ["card", "ach"].includes(command.method)
  && (command.method !== "ach" || account.capabilities.includes("ach"))
  && (decimalAmount(command.amountMinor) !== null || ["save_profile", "revoke_profile"].includes(command.kind) && command.amountMinor === "0");
}
