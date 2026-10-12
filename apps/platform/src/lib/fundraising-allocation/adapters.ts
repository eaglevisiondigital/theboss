import type { FundraisingChannel } from "./contracts";

/** These interfaces use the caller's own deployment and database. They confer no access. */
export type CanonicalFundraisingOrigin = Readonly<{
 contractVersion: 1; brandKey: string; organizationId: string; campaignId: string;
 destination: { kind: "organization" | "team" | "ministry" | "project"; resourceId: string };
 participantId: string | null; originPersonId: string | null; creditedPersonId: string | null; referrerPersonId: string | null;
 channel: FundraisingChannel; fundCode: string | null; currency: string;
}>;
export interface TenantIdentityAdapter { resolvePublishedPath(path: string): Promise<CanonicalFundraisingOrigin | null> }
export interface FundraisingAuthAdapter { authorizeCurrentResource(operation: string, origin: CanonicalFundraisingOrigin): Promise<boolean> }
export interface BrandPresentationAdapter { presentation(brandKey: string): Readonly<{ name: string; logoPath: string | null; locale: string }> }
export interface PaymentDestinationAdapter {
 /** One verified merchant route per checkout. No implied split across merchant IDs. */
 resolve(origin: CanonicalFundraisingOrigin): Promise<Readonly<{ accountId: string; routingRevisionId: string; policyRevisionId: string; merchantOwner: "organization" | "platform"; settlementMode: "direct_provider" | "platform_managed" }> | null>;
}
export interface OptionalFundraisingBenefitsAdapter {
 /** Independent eligibility contracts, never inferred from attribution or donation size alone. */
 eligibility(origin: CanonicalFundraisingOrigin): Promise<Readonly<{ walletPolicyId: string | null; membershipProductRevisionId: string | null }>>;
}
export type FundraisingAdapters = Readonly<{ tenant: TenantIdentityAdapter; auth: FundraisingAuthAdapter; brand: BrandPresentationAdapter; payments: PaymentDestinationAdapter; benefits?: OptionalFundraisingBenefitsAdapter }>;
export async function resolveAuthorizedFundraising(adapters: FundraisingAdapters, path: string, operation: string) {
 if (!/^[a-f0-9]{48}$/.test(path)) return null;
 const origin = await adapters.tenant.resolvePublishedPath(path);
 if (!origin || origin.contractVersion !== 1 || !await adapters.auth.authorizeCurrentResource(operation, origin)) return null;
 return { origin, presentation: adapters.brand.presentation(origin.brandKey) };
}
