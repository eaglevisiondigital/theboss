# Phase 7C Boss Bucks payments and split tender

Status: COMPLETE. Six migrations are canonical, implementation deployed and the
sole hosted window cleaned up. Positive hosted financial evidence is limited
by the explicitly approved absence of trusted paid sources.

The approved scope makes `boss_bucks` an internal method on the existing
canonical payments and allocations. Charges retain their existing derived
balance, adjustment and immutable payment-plan schedule. Cash/check receipts
remain separate tenders. No provider, settlement, transfer, cashout or merchant
execution is enabled.

## Identity, authority and transaction boundary

Family spending requires the current authenticated Boss identity, an active
wallet manager access record, current explicit Boss Bucks guardian authority,
current payment guardian authority over every selected participant, and an
active matching household, organization, currency and charge. Neither a role
nor household membership substitutes for these relationship checks. Finance
reversal requires the separate `boss_bucks.payment_reverse` permission in the
original organization; financial reporting is insufficient.

Up to 50 allocations may share one payment. The server selects grants, never
the caller. Selection uses earliest expiration (unbounded last), availability,
issuance and stable identifier. A bounded grant batch fails atomically if the
requested value cannot be satisfied within the batch. A preview is informational.

Authority rows are fenced in the existing module/role/membership/guardian order.
Sorted canonical charge rows are locked and physically fenced before the wallet,
account and sorted grant rows. Wallet mutations also physically fence the wallet
to force a serialization failure for an older repeatable-read snapshot. Source
ingestion retains campaign/fundraiser/intent locks before wallet/account/grants;
spending never takes those source locks. Request locks follow the resource locks.
Deadlock/serialization failures are retryable conflicts, with no partial commit.

## Ledger signs and lineage

Positive household postings are family value; negative postings consume it.
Original issuance credits household and debits the original earning clearing
account. Spending debits household and credits organization redemption clearing.
Payment restoration reverses that pair against the original grant. Expiration
and unspent source correction debit household and credit earning clearing.

An invalidated spent amount debits a separate household/organization recovery
account and credits earning clearing. Its negative balance is an internal
recovery claim, never negative spendable value. A later same-organization earning
is fully issued with its original provenance, then recovery debits that earning's
household value and credits the recovery account. Other organizations/currencies
cannot satisfy that claim. Immutable claim movements identify both the invalid
source and replacement earning.

Every payment links to a tender record, its allocation-consumption slices and
balanced per-grant journals. The slices identify the original grant and therefore
its trusted success, captured policy, participant, campaign and organization.
Reversals append canonical reversed payment/allocation rows and restoration
slices; no completed payment, grant or source history is rewritten.

Source corrections use the remaining authoritative gross source amount,
monotonically decreasing. Entitlement is `floor(remaining * captured_bps / 10000)`.
Unspent value is removed first. The spent excess becomes an explicit recovery
claim. Expired value is never resurrected. Source correction does not change a
completed charge allocation.

## Binding covered-recovery release rule

Main Boss Chat resolved the financial hold on October 7, 2026. A payment return
reduces the invalid source's recovery exposure. Any covered amount that must be
unwound returns through the actual recorded replacement applications, ordered by
application timestamp descending, then stable movement ID descending. Existing
outstanding exposure is canceled first; only the covered remainder needs a
satisfaction unwind. Partial returns release only that covered remainder, never
an unrelated grant or all of a larger historical application.

The original invalid grant receives no household credit. Its cancellation credits
recovery and debits redemption clearing, with the original consumption restoration
and canonical reversed payment/allocation as immutable evidence. Each replacement
release credits its own household account and debits recovery, linking the exact
original application and root payment return. Its availability, expiration,
source policy and attribution remain unchanged.

If a replacement source was subsequently invalidated, released invalid value is
removed through that source's reversal pair. Its now-reduced dependent recovery
is canceled with recovery credit/earning-clearing debit, rather than a second
redemption debit. Explicit cause-release and invalid-removal journal references
connect this dependent cancellation to the same root payment return. Any later
replacement applications for that dependent claim unwind by the same rule.
Expired replacement value is immediately expired under its original grant.
Only currently legitimate, available, unexpired value becomes spendable.

Dependencies advance from older claims to later grants; deferred proofs reject
nonchronological, cross-wallet, cross-organization, cross-currency, over-release,
unbacked cancellation and excessive current source value. Physical wallet
serialization remains authoritative. A request exceeding 64 dependency levels or
1,000 unwind movements fails atomically with a retryable conflict; it never
partially commits a payment return. These are execution safety bounds, not a new
permission, external debt or source-validity exception.

## Future external tender contract

An immutable checkout correlation identifier associates committed internal
tenders with one future attempt. Phase 7D must implement a separately authorized,
bounded reservation/commit/release lifecycle, provider idempotency, current
authorization rechecks, charge/wallet expiry, settlement and recovery exposure.
Phase 7C neither reserves external value nor creates a provider payment. A
remaining charge balance means unpaid; internal redemption has no processor fee.
