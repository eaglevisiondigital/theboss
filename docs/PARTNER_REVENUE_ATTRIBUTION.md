# Partner revenue evidence and attribution

**PHASE 8B1 LOCAL IMPLEMENTATION COMPLETE / PRODUCTION RELEASE PENDING EXPLICIT APPROVAL**

Partner commission policies, transaction sources and events form a separate immutable evidence layer. They do not post to the Boss Bucks Wallet, donations, organization fundraising, native redemption or Phase 7D settlement journals. Every source has exact provider/external transaction, immutable benefit/contract/policy, currency/eligible amount, timestamp and synthetic-evidence/ reference. Optional canonical person and native Sales lead FKs retain internal provenance; neither grants provider access nor rep commission authority.

Lifecycle distinguishes discovery/referral/handoff/request/confirmation/fulfillment/settlement reports from cancellation/refund/correction. A click is not earned commission. Delayed confirmation must follow a valid request. Duplicate external transaction/events conflict or replay the exact prior request; provider-scoped locks preserve correction/confirmation races. Corrections reference exactly one original refund for the same source; historical evidence survives. Cross-currency and out-of-policy-date sources are rejected.

Policies are immutable fixed/percentage/zero/unknown with integer minor units and parts-per-million rate precision; currency/date/recognition condition are explicit. The projection is an estimate only, permanently earned_revenue=false and settlement_executed=false. Percentage partial refunds reduce the eligible base using precise integer/numeric arithmetic. Flat-fee partial-refund treatment remains unknown because no contractual allocation was supplied. Cancellations/reversed sources project zero; unknown economics remain null.

No actual revenue recognition, invoice, provider settlement, payout, commission collection or external payment is implemented. Future recognition/nonpayment/dispute/settlement accounting must be separately approved and preserve contract/correction provenance. Native merchant acquisition attribution is an optional independent reference, never automatically a partner-purchase rep payout.

No canonical migration, deployment, commit/push, PR update, production test authority or live provider execution is authorized by this checkpoint. Phase 8A remains COMPLETE with its prior evidence limitations; Phase 8B2 has not started.
