import test from "node:test";
import assert from "node:assert/strict";
import { allocationQuery, parseAllocationCommand, safeAllocationData } from "../src/lib/fundraising-allocation/contracts";
import { resolveAuthorizedFundraising, type FundraisingAdapters, type CanonicalFundraisingOrigin } from "../src/lib/fundraising-allocation/adapters";
import { performAllocationMutation, type AllocationClient } from "../src/lib/fundraising-allocation/mutation";
const id = "00000000-0000-4000-8000-000000000001", other = "00000000-0000-4000-8000-000000000002";
const input = { campaign_id: id, team_id: id, channel: "money_board", platform_policy_id: id, organization_bps: 1000, destination_bps: 4000, participant_bps: 5000, starts_at: "2026-10-10T00:00:00Z" };
const command = { action: "allocation_policy.create", request_id: id, input };
test("allocation command preserves exact scope, cents basis and immutable revision identity", () => {
 assert.deepEqual(parseAllocationCommand(command), command);
 for (const extra of [{ organization_id: id }, { platform_basis_points: 0 }, { wallet_amount_minor: 5000 }, { unit_id: other }, { participant_bps: 10001 }, { starts_at: "2026-10-10T00:00" }, { ends_at: "2026-10-09T00:00:00Z" }, { organization_bps: 1.1 }, { channel: "client_invented" }]) assert.equal(parseAllocationCommand({ ...command, input: { ...input, ...extra } }), null);
 assert.equal(parseAllocationCommand({ ...command, request_id: "invalid" }), null);
 assert.equal(parseAllocationCommand({ ...command, bypass: true }), null);
});
test("finite platform economics, bounded delegation and destination contracts", () => {
 assert.ok(parseAllocationCommand({ action: "platform_policy.create", request_id: id, input: { organization_id: id, channel: "direct_support", currency: "USD", settlement_policy_id: id, agreement_reference: "Reviewed contract", participant_credit_max_bps: 10000, wallet_permitted: false, starts_at: input.starts_at } }));
 assert.equal(parseAllocationCommand({ action: "delegation.create", request_id: id, input: { campaign_id: id, person_id: id, starts_at: input.starts_at, ends_at: "2026-10-11T00:00:00Z" } }), null);
 assert.ok(parseAllocationCommand({ action: "destination.create", request_id: id, input: { campaign_id: id, kind: "project", unit_id: id, goal_minor: 50000 } }));
 assert.equal(parseAllocationCommand({ action: "destination.create", request_id: id, input: { campaign_id: id, kind: "organization", team_id: id, goal_minor: 50000 } }), null);
 assert.equal(parseAllocationCommand({ action: "unit_board.create", request_id: id, input: { campaign_id: id, unit_id: id, title: "Ministry", goal_minor: 50000, start_minor: 100, increment_minor: 100, tile_count: 100000, reservation_seconds: 1200 } }), null);
});
test("allocation report rejects unbounded lists and strips nested noncontract values", () => {
 const source = { checkout_id: id, channel: "money_board", currency: "USD", gross_donation_minor: "3000", policy_snapshot: { brand_id: id, secret: "excluded" }, noncash_designations: [{ category: "participant_credit", amount_minor: "500", person_details: "excluded" }], browser_material: "excluded" };
 const data = { version: 3, campaign_id: id, organization_id: id, currency: "USD", accounting_kind: "noncash_designation", can_manage: true, can_manage_platform: false, source_page: [source], platform_policies: [], allocation_policies: [], next_after: null };
 const parsed = safeAllocationData(data)!;assert.ok(parsed);assert.equal(JSON.stringify(parsed).includes("excluded"), false);
 assert.equal(safeAllocationData({ ...data, source_page: Array(101).fill(source) }), null);
 assert.equal(safeAllocationData({ ...data, source_page: [{ ...source, currency: "CAD" }] }), null);
 assert.equal(safeAllocationData({ ...data, version: 2 }), null);
 assert.deepEqual(allocationQuery({ campaign: id, unit: other }), { campaign_id: id, unit_id: other });
 assert.equal(allocationQuery({ campaign: id, team: id, unit: other }), null);
 assert.equal(allocationQuery({ campaign: [id] }), null);
});
test("portable adapters resolve canonical ownership then current resource authority", async () => {
 const origin: CanonicalFundraisingOrigin = { contractVersion: 1, brandKey: "kingdom_raise", organizationId: id, campaignId: id, destination: { kind: "ministry", resourceId: other }, participantId: null, creditedPersonId: null, originPersonId: null, referrerPersonId: null, channel: "money_board", fundCode: "YOUTH-CAMP", currency: "USD" };
 let authorized = false, calls = 0;
 const adapters: FundraisingAdapters = { tenant: { async resolvePublishedPath() { calls++;return origin; } }, auth: { async authorizeCurrentResource() { return authorized; } }, brand: { presentation() { return { name: "Synthetic Kingdom Raise adapter", logoPath: null, locale: "en-US" }; } }, payments: { async resolve() { return null; } } };
 assert.equal(await resolveAuthorizedFundraising(adapters, "invalid", "reserve"), null);assert.equal(calls, 0);
 assert.equal(await resolveAuthorizedFundraising(adapters, "a".repeat(48), "reserve"), null);authorized = true;
 const result = await resolveAuthorizedFundraising(adapters, "a".repeat(48), "reserve");assert.equal(result?.origin.participantId, null);assert.equal(result?.origin.organizationId, id);
});
test("allocation route rejects cross-origin input before Auth or RPC and keeps exceptions sanitized", async () => {
 let calls = 0;
 const client = { rpc() { calls++;throw Error("unsafe upstream detail"); }, auth: {} } as unknown as AllocationClient;
 const response = await performAllocationMutation(new Request("https://boss.example/app/fundraising/allocation/mutate", { method: "POST", headers: { host: "boss.example", origin: "https://other.example", "content-type": "application/json" }, body: JSON.stringify(command) }), client, "https://boss.example");
 assert.equal(response.status, 403);assert.equal(calls, 0);assert.equal(JSON.stringify(response).includes("unsafe upstream"), false);
 const malformed = await performAllocationMutation(new Request("https://boss.example/app/fundraising/allocation/mutate", { method: "POST", headers: { host: "boss.example", origin: "https://boss.example", "content-type": "application/json" }, body: JSON.stringify({ ...command, input: { ...input, team_id: "forged" } }) }), client, "https://boss.example");assert.equal(malformed.status, 422);assert.equal(calls, 0);
});

test("native settlement UI separates organization routing from platform policy authorship", async () => {
 const [{ createElement }, { renderToStaticMarkup }, { AppRouterContext }, { PaymentsConsole }] = await Promise.all([
  import("react"), import("react-dom/server"), import("next/dist/shared/lib/app-router-context.shared-runtime.js"), import("../src/components/payments/console")
 ]);
 const router = { bfcacheId: "synthetic-local", back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {} };
 const render = (can_configure_policy: boolean) => renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, createElement(PaymentsConsole, { organizationId: id, data: { mode: "organization", can_configure: true, can_configure_policy, accounts: [], routes: [], routing_scopes: [] } })));
 const organization = render(false);assert.match(organization, /Add a draft merchant account/);assert.match(organization, /Configure an exact payment route/);assert.doesNotMatch(organization, /Add an explicit settlement policy/);
 assert.match(render(true), /Add an explicit settlement policy/);
});
test("native allocation report renders explicit monetary metrics and noncash credit without policy escalation", async () => {
 const [{ createElement }, { renderToStaticMarkup }, { AppRouterContext }, { AllocationConsole }] = await Promise.all([
  import("react"), import("react-dom/server"), import("next/dist/shared/lib/app-router-context.shared-runtime.js"), import("../src/components/fundraising/allocation-console")
 ]);
 const router = { bfcacheId: "synthetic-local", back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {} };
 const data = safeAllocationData({ version: 3, campaign_id: id, organization_id: id, currency: "USD", accounting_kind: "noncash_designation", can_manage: true, can_manage_platform: false,
  source_page: [{ checkout_id: id, channel: "money_board", currency: "USD", state: "completed", gross_donation_minor: "2501", net_donation_minor: "2400", product_sale_refunds_minor: "0", net_product_sales_minor: "0", reserved_tile_value_minor: "0", permanently_claimed_tiles: 2, organization_payable_minor: "2000", organization_paid_minor: "0", organization_deficit_minor: "0", noncash_designations: [{ category: "participant_credit", amount_minor: "500" }] }], platform_policies: [], allocation_policies: [], next_after: null })!;
 const html = renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, createElement(AllocationConsole, { data, scope: { campaign_id: id } })));
 for (const label of ["Net donation principal", "Net product sales", "Prepared checkout reserved tile value", "Permanently claimed tiles", "Organization payable", "Organization paid", "Organization deficit"]) assert.ok(html.includes(label), label);
 assert.match(html, /\$24\.00/);assert.match(html, /\$5\.00.*internal credit/);assert.match(html, /does not create another payable/);assert.doesNotMatch(html, /name="platform_basis_points"/);
});
test("fixed fundraising fee contract preserves old callers and rejects unsupported pricing contexts", async () => {
 const { parsePaymentCommand } = await import("../src/lib/payments/input");
 const policy = { action: "policy.create", request_id: id, input: { organization_id: id, purpose: "fundraising", currency: "USD", organization_basis_points: 7000, platform_basis_points: 3000, product_cost_basis_points: 0, processor_fee_owner: "platform", availability_seconds: 0 } };
 assert.ok(parsePaymentCommand(policy));assert.ok(parsePaymentCommand({ ...policy, input: { ...policy.input, platform_fee_minor: 100 } }));
 for (const purpose of ["fees", "products", "boss_bucks"]) { assert.equal(parsePaymentCommand({ ...policy, input: { ...policy.input, purpose, platform_fee_minor: 100 } }), null);assert.ok(parsePaymentCommand({ ...policy, input: { ...policy.input, purpose, platform_fee_minor: 0 } })); }
});
