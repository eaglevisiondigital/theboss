# Boss Bucks product orders and fulfillment

Status: Phase 7E local implementation; live release/acceptance pending.

`commerce` currently supplies a module identity, not a reusable active order engine.
The native order core is therefore deliberately limited to approved Boss Bucks
membership/card/coverage products. No apparel store, marketplace, Shopify or
GoAffPro implementation is activated. Orders/items preserve exact buyer or private
guest claim context, organization/campaign/fundraiser/share attribution, product
revision, quantity, geography, original price/economics and fulfillment mode.
Economics must be explicit and coherent; missing route/account/policy/configuration
keeps checkout unavailable. Campaign sale currency must match its product revision.

The existing Phase 7D checkout, normalized provider evidence, frozen eligibility
commit, canonical `payments`, tender/correction and settlement journals remain
financial authority. `payments.product_order_id` is the exact commercial identity
for a guest product payment, following the existing guest-fundraising boundary;
no Boss person is guessed. Deferred proof requires the same exact order/checkout/
committed provider success, and original-tender corrections preserve that order
lineage. Cash/check/Wallet payer requirements remain intact. This is no second
processor or ledger.

Verified card capture fulfills before batch/organization settlement; authorization
alone does not. ACH fulfills only at its approved final settled success. Unknown
outcomes retain the original operation and pending hold. Product eligibility is
frozen at valid dispatch; natural expiry afterward honors that original commit.
Explicit cancellation/invalidation routes a later verified positive to review
without allocation, membership, card activation or fundraising credit. Native
buyer cancellation is available only before dispatch, following the existing
unsubmitted checkout boundary. Submitted attempts require reviewed reconciliation.

Digital success issues exactly one configured source per original item; a guest
source remains pending claim. Physical success allocates canonical inventory and
creates fulfillment only after original verified payment. Fulfillment tracks
awaiting inventory, allocated, ready for pickup, packed, shipped, delivered or
canceled as appropriate. Pickup requires no shipping address or carrier API.
The private contact/address relation is raw-closed; ordinary product/fundraiser/team
projections never include it. A separate uncached, verified, exact-order fulfillment
read requires current organization feature and fulfillment authority. Buyer-entered
contact/address is not an identity merge or public campaign field.

Organization fundraising credit is the exact frozen product-revision amount. It
never creates Wallet value or Charge allocations. Product credit/refund history is
analytical attribution, with original finance authority held by the shared canonical
payment/settlement engine. Original-item refund requests reserve exact distinct
original items and cannot exceed/reuse a corrected or pending-refund item. Provider
confirmation is required before benefit/inventory/credit correction. Settlement
and dependent deficits use original item economics, never a later price revision.
Financial totals are grouped by currency; fundraiser reports disclose only their
campaign's attributed credit/counts, never platform retained amounts or contacts.

An unsolicited correction without exact original-item mapping is preserved at the
existing review boundary. It holds the affected order's benefit/payable/credit
projection before guessing financial attribution. It does not suspend unrelated
membership sources. There is no invented partial-item policy or automated release
of that review. A future reviewed resolution must supply the authoritative original
item mapping; an architecture/product contradiction returns to Main Boss Chat.

Current provider positives retain **LOCAL CONTRACT TESTED; SANDBOX UNAVAILABLE**.
No operational provider account/binding, private secret resolver, real instrument,
actual transaction, payout or recurring executor is introduced. Hosted acceptance
must verify this unavailable boundary truthfully; it cannot fabricate paid orders,
captures or settled sources. Claim/receipt email delivery is not a condition of
product fulfillment; no delivery provider is newly provisioned.
