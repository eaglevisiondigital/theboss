# Boss Bucks Discounts membership architecture

Phase 7E source checkpoint: `8760547f4e69e5c097640030090f1d92e87ac237`.
Status: LOCAL IMPLEMENTATION; canonical release and hosted acceptance pending.

Boss Bucks Wallet is earned, organization-restricted fundraising value. Boss Bucks
Discounts is consumer product access. Neither grants the other, organization/team
access, guardian authority, finance authority or future merchant administration.
The existing `boss_bucks` module owns finite `discount_membership`,
`membership_trials`, `physical_cards`, `membership_sales` and `membership_upgrades`
features. Existing wallet/payment features stay independent and fail closed.

`discount_products` preserves stable product identity. Immutable
`discount_product_revisions` own configured geography, subject/claim policy,
consumer price, term, trial, card validity and frozen sale economics. Dated
revision events enable/disable revisions. No production product, term, market,
organization credit, retained amount or settlement policy is seeded. The approved
configurable USD price suggestions are base 2500, state +1999 and nationwide +3900
minor units. A coherent approved payment route and policy are required for sales.

`discount_memberships` preserves one exact product/subject/country/region/market
identity. Subjects are an explicit signed person or an explicitly configured
household. Household-primary-contact claim policy requires current primary
contact authority; household benefit viewing is product policy, never guardian or
business authority. No email/mobile matching, guessed account merge or casual
subject transfer exists. Sources and append-only revocations/history preserve
commercial origin, original product revision, dates and corrections.

Canonical Phase 2A `entitlements` project dated effective product access through
`discount_entitlement_links`. Source validity is checked again when an entitlement
is used: expiry, cancellation, suspension, source reversal, review hold and module
disable deny access even if a cached projection row has not been rebuilt. No
parallel generic entitlement engine or mutable wallet balance is introduced.
Bounded maintenance can retire expired projections without extending any source.

Trials support configured 30/60/90-day terms. Guest trials preserve a canonical
7A donor and pending membership. A high-entropy one-time private claim handoff,
stored only as a digest, attaches access to the intended verified account/household.
It cannot be recovered from ordinary reads or replay receipts. An exact-subject
lock and current-source checks prevent duplicate active trials. Replay always
requires fresh actor, subject and module authority.

Gift qualification uses the existing trusted 7A qualification and immutable
product snapshot: USD support strictly greater than 2500 qualifies; 2500 does not,
2501 does. Card capture follows the approved 7D timing; ACH requires final verified
settlement. Anonymous public display does not block private fulfillment. An exact
private donation capability retrieves the handoff; contact identity is not merged.
A trial-to-gift conversion retains the original trial and starts the configured
full gift term at verified payment success. Reversal removes the gift and falls
back only to an original trial that is still valid; expired trials never revive.
The immutable historical 7A `gift_pending` qualification is evidence of origin,
not the current membership fulfillment state.

Coverage is local/configured home market, configured state/region, or nationwide
within the configured country where active markets exist. No GPS, travel booking,
merchant offers or country entitlement guess is added. Upgrades require an exact
current underlying product/subject/country/region/market, an explicitly permitted
starting tier, and verified original payment. They co-terminate with the base;
no guessed proration, state credit or term extension exists. Higher-tier ordering
cannot substitute an unrelated product or an expired/reviewed base. Renewal/source
kinds preserve a future next-term contract; recurring renewal, automatic downgrade
and new renewal economics remain unconfigured, not fabricated.

Raw membership/commercial/private claim relations have RLS enabled and no browser,
anonymous, service-role or payment-worker table access. Narrow signed projections
and commands enforce current server authority and exact scope. Catalog management
is platform-only; approved organization roles receive only membership/inventory/
fulfillment capability, with underlying relationship/feature checks still required.
Consumer reads contain only the intended person/household. Fundraiser reports expose
attributed credit and counts, never retained platform economics or buyer contacts.
Normal projection data never includes activation secrets, claim digests, shipping
addresses, Auth material or provider bindings.

Consumer Discounts cards and Family Hub show brand, persistent member display
identity, source, geographic tier/country, dates and active/trial/expired state.
Public campaign product options coexist with direct support and Money Board.
Private purchase/gift handoffs retain the original opaque proof in page memory;
unknown requests retry the same request, never manufacture another success.

Phase 4A notification history and recipient/visibility/deduplication rules are reused
for trial, activation, gift, fulfillment and upgrade events. Private claims and
contact details are never notification payloads. Email delivery is not required
for entitlement fulfillment; no new email provider, SMS or push infrastructure is
activated. Expiry enforcement does not depend on reminder delivery.

Future Merchant Platform contract: an authorized offer/location projection may
ask for a bounded current product-coverage answer for an exact subject and
configured location. It must consume source-validated entitlement facts, minimize
PII and independently authorize merchant operations. Physical credential validity
is separate from the attached digital-trial window. No merchant/redemption endpoint
or general commerce module is implemented by Phase 7E.
