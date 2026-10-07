# Phase 7D settlement and reconciliation

Current status: LOCAL IMPLEMENTATION VALIDATED; final release gates in progress.
The financial timing decisions are resolved.

Historical pre-resolution status (retained): PROPOSED LOCAL DESIGN; settlement
accounting was not implemented or live and the timing decision remained open.
No production rate, fee, hold interval or payout destination
is inferred. Versioned explicit policies retain organization/platform/product-cost
shares, fee ownership and availability timing. A missing policy or actual fee
evidence holds economic attribution for review; it does not silently create a
100% organization payable or a zero-cost processor assumption.

One canonical balanced settlement journal spans all providers. Dimensions retain
organization/account/currency/payment/allocation/method and captured policy.
Boss Bucks creates internal redemption exposure separately from provider cash.
No family recovery claim or wallet balance is used as an organization deficit.

Direct-provider settlement is reconciled to provider batches and excludes Boss
payout requests. Platform-managed payable may be requested only within available
attributable value, after same-organization recovery offsets and existing requests.
No outbound bank rail is activated. Requests are not labeled paid until distinct
trusted settlement evidence exists. Bank destinations are references, never raw
credentials.

Refund/dispute adjustments consume still-unpaid payable first. Already-settled
exposure opens an explicit same-organization recovery claim. Future payable offsets
that claim under immutable lineage; available payout never becomes an unexplained
negative number. Cumulative source reversals are bounded by original economics.

Reconciliation classifies matched, pending, missing provider/Boss, amount, fee and
settlement mismatches. Bounded account/cursor batches preserve immutable evidence;
unexplained differences require review and never silently rewrite canonical truth.
Signed webhook hints require exact account/signature verification and durable event
deduplication. Authoritative transaction polling supplements webhook evidence;
arrival order alone never reverses a terminal financial state.

Manual finance reconciliation and a private worker contract must be implemented before
any operational scheduler. Autopay, automated daily execution and actual outbound
payouts remain inactive until separately approved infrastructure and policies exist.

## Binding continuation decision, October 7, 2026

Main Boss Chat resolved the earlier holds recorded above. Those paragraphs are
historical checkpoint context, superseded by this section and the amendment in
[FUNDRAISING_ARCHITECTURE.md](FUNDRAISING_ARCHITECTURE.md). Verified card capture is
payment/fundraising success before settlement; authorization is not. ACH pending
and unknown outcomes hold resources durably after short expiry, never create
success or trigger a new charge automatically. Submission commits immutable
eligibility, exact account/attempt/routing/settlement and reward/earning revisions.
Natural expiry preserves that in-flight eligibility; explicit terminal
invalidation/cancel/release routes later money to canonical unallocated review.

Local dependent execution, settlement and correction implementations are under
validation. Settlement sources are exactly once per canonical tender. Missing
policy/actual fee evidence holds attribution. Provider settlement never duplicates
payment, fundraising progress or earnings; direct-provider sources cannot request
a second Boss payout. Refund-before-settlement uses remaining principal/gross,
not the original already-refunded economic amount. Source corrections preserve
original capture chronology and the existing Phase 7C earning recovery chain.
No live-provider or release-completion claim is made by these local checks.
