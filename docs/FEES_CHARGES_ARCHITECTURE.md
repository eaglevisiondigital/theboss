# Fees, obligations and offline allocations: Phase 3B

Boss owns canonical charges and allocation history. This phase executes authorized
cash/check recording only. Processor, wallet, settlement, payout and refund execution
remain outside Phase 3B. Validation and live status is recorded separately in
[CURRENT_BUILD_STATE.md](CURRENT_BUILD_STATE.md).

## Obligations and explicit adjustments

All value uses integer minor units and one uppercase currency per charge/payment.
`registration_fee_rules` configure future required/optional fees. Registration
start snapshots active required rules; submission creates actual `charges`, including
waitlisted submissions. Charge type/title can describe registration, team, season,
camp, trip, event, deposit, uniform or another approved organization obligation.
Optional fees are not automatically assessed; an authorized explicit charge can
create the actual obligation. Each charge retains same-tenant registration,
participant/household and optional canonical event/fee-rule provenance.

Original charge amount is immutable. `charge_adjustments` append signed nonzero
discount, coupon, scholarship, credit or surcharge entries with reason and recorder.
Discount/credit values are negative; surcharges positive. Adjusted obligation cannot
become negative or less than money already applied. Balance is derived:

`original amount + adjustments − applied allocations = balance due`.

No mutable balance or independent paid Boolean is authoritative. Status derives as
unpaid, partially paid, paid, overdue, waived or canceled. A charge can be explicitly
canceled only with zero applied payment; active plan history is canceled and retained.
Withdrawal/denial does not infer a financial refund or silently erase a charge.

## Offline receipts and partial allocation

`payment.record_offline` needs the applicable offering-scope
`payments.record_offline`, enabled fees/offline-payment features and current tenant
context for every allocation. Finance capability is distinct from registration
review/document/medical capability. Ordinary coaches and registrars gain no payment
recording power through their role names.

The immutable `payments` record preserves method, amount, currency, canonical payer,
received timestamp, reference/note and canonical recorder. Cash and check are the
only accepted methods in both the database table constraint and executable command.
Check requires a reference/check number; ACH
means electronically processed banking and is never treated as a manual check.
The payer must be an actual participant, submitting person, verified payment-authorized
guardian or active member of the selected registration household. A guessed global
person ID or the finance operator's identity alone cannot select an unrelated payer.

`payment_allocations` permits many partial receipts against one obligation and one
receipt allocated to several obligations. Each positive allocation references a
same-tenant, same-currency active charge. A payment contains 1–50 unique charge
allocations whose sum must equal its full amount; unapplied funds are not modeled
as a general settlement wallet. Charge balance cannot be over-allocated. Immutable
allocation/status/reversal-reference columns preserve an integration boundary,
but no reversal/refund execution is exposed in this phase.

For a 50,000-minor-unit charge, 10,000 cash and 15,000 check allocations leave
25,000 due. A future independently authorized card or restricted Boss Bucks source
could supply another allocation; Phase 3B offers neither action. No card data,
processor credentials or bank account data is collected in Boss.

Sorted charge locks and physical owner-row updates serialize competing receipts
and adjustments. Stale higher-isolation snapshots fail safely. Actor/request input
hash receipts prevent duplicate financial records on retry and recheck current
authority. One SQL transaction commits payment, all allocations, receipt and safe
audit together; a later denied allocation rolls back the whole request.

## Installments and discounts

An authorized `payment_plan.create` configures 1–60 positive installments with
ordered due dates whose sum equals the complete adjusted obligation. Amounts
already received remain part of that original schedule basis; remaining balance
still derives from real allocations. Only one active plan per charge is allowed.
Installments are immutable. Explicit cancellation retains their history and permits
a reviewed replacement. An active plan must be canceled before an adjustment that
would invalidate its schedule. No autocharge, retry collection or installment-specific
settlement attribution is implemented.

Coupons are offering-specific active fixed/percentage configurations with dates,
usage limits and explicit adjustment records at submission. Fixed discounts are
bounded by actual obligation and distributed deterministically across frozen fee
rules. Percentage calculations use integer basis points. Usage updates are locked
with registration capacity and remain auditable. Fixed coupon application requires
one currency across the frozen fee rules, since no conversion or cross-currency
minor-unit arithmetic is authorized. Percentage coupons are computed per charge.
Sibling, early-registration,
organization and scholarship discounts can use explicit coupons or authorized
manual adjustments; no silent automatic family/early pricing engine is inferred.

## Future processor and Boss Bucks boundary

Card, ACH and Boss Bucks are planned method types documented in a nonexecuting
application contract. They are not permitted live `payments.method` values.
The column uses constrained text, so a separately approved future migration can
extend its cash/check-only check after the provider/value path is validated.
Explicit approved credits currently use charge adjustments rather than another
payment method. No method-label change alone may enable a payment action.

A future provider adapter must create canonical Boss allocation evidence from
verified idempotent transaction references. External
providers do not replace Boss obligations, authority, eligibility or reversal rules.
Processor webhooks, settlement ledgers, dependent-allocation reversals, payouts and
provider choice require separately approved implementation.

One family can have one master Boss Bucks wallet across organizations, with
organization-specific restricted sub-balances. Fundraising-earned value remains
attributed to its originating organization. For example, Chiefs 24,000 + Royals
17,500 + Renegades 31,000 can show a master total of 72,500 minor units, while
Renegades-eligible spend is only 31,000. Organization A's funds cannot automatically
pay Organization B's fees. Future parent-to-organization fees can accept eligible
restricted Boss Bucks when sufficient value exists, alongside split tender.

Before future allocation, the wallet/ledger must atomically verify the source
organization, charge eligibility, available restricted balance, actor/family
authority, idempotency and reversal dependencies. Phase 3B preserves charge,
method, source-reference and allocation boundaries but creates no wallet, restricted
balance, debit, transferable value, fundraising ledger or actual Boss Bucks action.

See [Permissions](PERMISSIONS_MODEL.md), [Registration](REGISTRATION_ARCHITECTURE.md)
and [Decisions](DECISIONS.md).


## Phase 7A canonical extension — COMPLETE

Phase 7A fundraising intents retain donor fee-cover preference only. No fee
quote, processor fee, net settlement, payout, payment collection, receivable
allocation or Boss Bucks credit is executed. Future reviewed payment adapters
must verify external evidence, match exact intent/currency/amount and bind one
idempotent source reference. They then feed immutable success evidence, receipt
and reward qualification. Refund/chargeback/reward reversal must append source
lineage and safely reverse dependent allocations/issuance in later phases;
paid tile identity is never silently reopened by a reversal.
