import type { Json } from "../supabase/database.types";

export const fundraisingChannels = ["money_board", "direct_support", "digital_card", "physical_card"] as const;
export type FundraisingChannel = typeof fundraisingChannels[number];
export const isRecord = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === "object" && !Array.isArray(value);
export const isUuid = (value: unknown): value is string => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
const hasControl = (value: string) => Array.from(value).some(char => char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127);
const fields = {
 "brand.create": ["key", "name"],
 "origin.bind": ["campaign_id", "brand_id", "fund_code"],
 "platform_policy.create": ["organization_id", "campaign_id", "channel", "currency", "settlement_policy_id", "product_revision_id", "agreement_reference", "exception_reference", "participant_credit_max_bps", "wallet_permitted", "starts_at", "ends_at"],
 "allocation_policy.create": ["campaign_id", "team_id", "unit_id", "channel", "platform_policy_id", "organization_bps", "destination_bps", "participant_bps", "starts_at", "ends_at"],
 "delegation.create": ["campaign_id", "person_id", "team_id", "unit_id", "starts_at", "ends_at"],
 "delegation.revoke": ["campaign_id", "delegation_id"],
 "wallet_channel.bind": ["campaign_id", "channel", "wallet_policy_id", "starts_at", "ends_at"],
 "destination.create": ["campaign_id", "kind", "team_id", "unit_id", "board_id", "fundraiser_id", "referrer_person_id", "goal_minor", "starts_at", "ends_at"],
 "destination.publish": ["campaign_id", "destination_id"],
 "destination.archive": ["campaign_id", "destination_id"],
 "unit_board.create": ["campaign_id", "unit_id", "title", "goal_minor", "start_minor", "increment_minor", "tile_count", "reservation_seconds", "visibility"],
} as const;
export type AllocationAction = keyof typeof fields;
const required: Record<AllocationAction, readonly string[]> = {
 "brand.create": ["key", "name"], "origin.bind": ["campaign_id", "brand_id", "fund_code"],
 "platform_policy.create": ["organization_id", "channel", "currency", "settlement_policy_id", "agreement_reference", "participant_credit_max_bps", "wallet_permitted", "starts_at"],
 "allocation_policy.create": ["campaign_id", "channel", "platform_policy_id", "organization_bps", "destination_bps", "participant_bps", "starts_at"],
 "delegation.create": ["campaign_id", "person_id", "starts_at", "ends_at"], "delegation.revoke": ["campaign_id", "delegation_id"],
 "wallet_channel.bind": ["campaign_id", "channel", "wallet_policy_id", "starts_at"],
 "destination.create": ["campaign_id", "kind", "goal_minor"], "destination.publish": ["campaign_id", "destination_id"], "destination.archive": ["campaign_id", "destination_id"],
 "unit_board.create": ["campaign_id", "unit_id", "title", "goal_minor", "start_minor", "increment_minor", "tile_count"],
};
export type AllocationCommand = { action: AllocationAction; request_id: string; input: Record<string, Json> };
export function parseAllocationCommand(value: unknown): AllocationCommand | null {
 if (!isRecord(value) || Object.keys(value).some(key => !["action", "request_id", "input"].includes(key)) || !isUuid(value.request_id)
  || typeof value.action !== "string" || !Object.hasOwn(fields, value.action) || !isRecord(value.input)) return null;
 const action = value.action as AllocationAction, input = value.input;
 if (Object.keys(input).some(key => !(fields[action] as readonly string[]).includes(key)) || required[action].some(key => input[key] === undefined || input[key] === null)) return null;
 for (const [key, item] of Object.entries(input)) {
  if (key.endsWith("_id") && !isUuid(item)) return null;
  if (key.endsWith("_bps") && (typeof item !== "number" || !Number.isSafeInteger(item) || item < 0 || item > 10000)) return null;
  if (key.endsWith("_minor") && (typeof item !== "number" || !Number.isSafeInteger(item) || item < 1 || item > 1_000_000_000_000)) return null;
  if (["starts_at", "ends_at"].includes(key) && (typeof item !== "string" || !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(item) || !Number.isFinite(Date.parse(item)))) return null;
 }
 if (input.ends_at !== undefined && (input.starts_at === undefined || Date.parse(String(input.ends_at)) <= Date.parse(String(input.starts_at)))) return null;
 if (input.team_id && input.unit_id) return null;
 if (input.channel !== undefined && !fundraisingChannels.includes(input.channel as FundraisingChannel)) return null;
 if (input.currency !== undefined && (typeof input.currency !== "string" || !/^[A-Z]{3}$/.test(input.currency))) return null;
 for (const key of ["name", "title", "fund_code", "agreement_reference", "exception_reference"]) if (input[key] !== undefined && (typeof input[key] !== "string" || !String(input[key]).trim() || String(input[key]).length > (["fund_code", "agreement_reference", "exception_reference"].includes(key) ? 100 : 120) || hasControl(String(input[key])))) return null;
 if (action === "brand.create" && (typeof input.key !== "string" || !/^[a-z][a-z0-9_]{1,63}$/.test(input.key))) return null;
 if (action === "platform_policy.create" && (typeof input.wallet_permitted !== "boolean" || ["digital_card", "physical_card"].includes(String(input.channel)) !== !!input.product_revision_id)) return null;
 if (action === "allocation_policy.create" && (Number(input.organization_bps) + Number(input.destination_bps) + Number(input.participant_bps) !== 10000 || Number(input.destination_bps) > 0 && !input.team_id && !input.unit_id)) return null;
 if (action === "delegation.create" && !input.team_id && !input.unit_id) return null;
 if (action === "wallet_channel.bind" && !["money_board", "direct_support"].includes(String(input.channel))) return null;
 if (action === "destination.create" && (!["organization", "team", "ministry", "project"].includes(String(input.kind)) || (input.kind === "organization" ? !!input.team_id || !!input.unit_id : input.kind === "team" ? !input.team_id || !!input.unit_id : !input.unit_id || !!input.team_id))) return null;
 if (action === "unit_board.create" && (typeof input.tile_count !== "number" || !Number.isSafeInteger(input.tile_count) || input.tile_count < 1 || input.tile_count > 2_147_483_647
  || input.reservation_seconds !== undefined && (typeof input.reservation_seconds !== "number" || !Number.isInteger(input.reservation_seconds) || input.reservation_seconds < 480 || input.reservation_seconds > 600)
  || input.visibility !== undefined && !["private", "public"].includes(String(input.visibility)))) return null;
 return { action, request_id: value.request_id, input: input as Record<string, Json> };
}
export type AllocationQuery = { campaign_id: string; team_id?: string; unit_id?: string; after?: string };
export function allocationQuery(input: Record<string, string | string[] | undefined>): AllocationQuery | null {
 if (!isUuid(input.campaign) || input.team && !isUuid(input.team) || input.unit && !isUuid(input.unit) || input.team && input.unit || input.after && !isUuid(input.after)) return null;
 return { campaign_id: input.campaign, ...(input.team ? { team_id: input.team as string } : {}), ...(input.unit ? { unit_id: input.unit as string } : {}), ...(input.after ? { after: input.after as string } : {}) };
}
export type AllocationData = { version: 3; campaign_id: string; organization_id: string; currency: string; can_manage: boolean; can_manage_platform: boolean; accounting_kind: "noncash_designation"; source_page: Record<string, unknown>[]; platform_policies: Record<string, unknown>[]; allocation_policies: Record<string, unknown>[]; next_after: string | null };
const policyFields = ["id", "revision", "channel", "settlement_policy_id", "platform_policy_id", "participant_credit_max_bps", "wallet_permitted", "organization_bps", "destination_bps", "participant_bps", "starts_at", "ends_at"];
const sourceFields = ["checkout_id", "channel", "currency", "state", "gross_verified_cash_minor", "gross_donation_minor", "confirmed_donation_refunds_minor", "net_donation_minor", "gross_digital_card_sales_minor", "gross_physical_card_sales_minor", "product_sale_refunds_minor", "net_product_sales_minor", "product_sale_organization_credit_minor", "platform_revenue_minor", "actual_processor_cost_minor", "organization_allocation_minor", "wallet_earning_minor", "wallet_source_correction_minor", "pending_payment_minor", "reserved_tile_value_minor", "permanently_claimed_tiles", "provider_settlement", "organization_payout_status", "organization_payable_minor", "organization_paid_minor", "organization_deficit_minor"];
const snapshotFields = ["brand_id", "fund_code", "platform_policy_id", "allocation_policy_id", "settlement_policy_id", "routing_id", "account_id"];
function finiteRow(value: Record<string, unknown>, fields: readonly string[]): Record<string, unknown> {
 const result: Record<string, unknown> = {};
 for (const key of fields) {
  const item = value[key];
  if (item === null || typeof item === "boolean" || typeof item === "number" && Number.isSafeInteger(item) || typeof item === "string" && item.length <= 120 && !hasControl(item)) result[key] = item;
 }
 return result;
}
export function safeAllocationData(value: unknown): AllocationData | null {
 if (!isRecord(value) || value.version !== 3 || !isUuid(value.campaign_id) || !isUuid(value.organization_id) || typeof value.currency !== "string" || !/^[A-Z]{3}$/.test(value.currency) || value.accounting_kind !== "noncash_designation"
 || typeof value.can_manage !== "boolean" || typeof value.can_manage_platform !== "boolean") return null;
 const lists = ["source_page", "platform_policies", "allocation_policies"] as const;
 for (const key of lists) if (!Array.isArray(value[key]) || value[key].length > 100 || value[key].some(item => !isRecord(item))) return null;
 if (value.next_after !== null && !isUuid(value.next_after)) return null;
 const sources: Record<string, unknown>[] = (value.source_page as Record<string, unknown>[]).map(row => ({ ...finiteRow(row, sourceFields),
  policy_snapshot: isRecord(row.policy_snapshot) ? finiteRow(row.policy_snapshot, snapshotFields) : null,
  noncash_designations: Array.isArray(row.noncash_designations) && row.noncash_designations.length <= 4 ? row.noncash_designations.filter(isRecord).map(entry => finiteRow(entry, ["category", "amount_minor"])) : [],
 }));
 if (sources.some(row => !isUuid(row.checkout_id) || !fundraisingChannels.includes(row.channel as FundraisingChannel) || row.currency !== value.currency)) return null;
 const platform = (value.platform_policies as Record<string, unknown>[]).map(row => finiteRow(row, policyFields)), local = (value.allocation_policies as Record<string, unknown>[]).map(row => finiteRow(row, policyFields));
 if ([...platform, ...local].some(row => !isUuid(row.id) || !fundraisingChannels.includes(row.channel as FundraisingChannel))) return null;
 return { version: 3, campaign_id: value.campaign_id, organization_id: value.organization_id, currency: value.currency, can_manage: value.can_manage, can_manage_platform: value.can_manage_platform, accounting_kind: "noncash_designation",
 source_page: sources, platform_policies: platform, allocation_policies: local, next_after: value.next_after as string | null };
}
