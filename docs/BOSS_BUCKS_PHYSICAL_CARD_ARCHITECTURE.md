# Boss Bucks physical card architecture

Status: Phase 7E COMPLETE within the approved unavailable-provider boundary.

Each batch is explicitly platform-, organization- or campaign-owned and tied to
one immutable physical product revision. Each canonical credential has a unique
UUID and `BBC-` serial, separately indexed private activation digest, inventory/
assignment/sale/claim state, original item lineage and immutable history. Serial
knowledge alone grants no access. Batch creation/print handoff is privileged,
bounded and one-time; raw activation codes exist only in the authorized response
and print operator's memory/download. Replays and normal inventory reads never
recover codes. Hashing uses PostgreSQL's built-in SHA-256; extension privileges
are not broadened.

Operations are limited to 1,000 distinct cards per command, not a 500-card global
inventory limit. Projections use bounded keyset reads; full FK indexes support
parent operations in addition to serial/digest and inventory access indexes.
The local scale fixture uses 6,000 cards. Platform unassigned stock is visible only
to platform authority and can be allocated only under an eligible revision and
explicit current destination scope. Organization and campaign ownership do not
implicitly authorize another organization or fundraiser.

Printing and participant allocation are not payment. Bulk assign/return preserves
exact organization/campaign/fundraiser scope and current participant relationships.
No cash mark-paid, manual fabricated capture or unsupported offline payment path
exists. Verified physical product payment allocates exactly one eligible credential
per original item with row locking, `SKIP LOCKED` and a unique item link. Shortage
creates awaiting-inventory fulfillment rather than false delivery or duplicate stock.

Claim requires the serial and private activation proof, a live verified Boss actor,
current module policy and the product's exact subject policy. The configured
physical validity anchor is print, verified sale or activation. An unconfigured
anchor/duration fails closed. The included digital trial starts on actual successful
claim, not inventory printing; 90 days is a configurable approved suggestion. An
existing active trial is retained without a second active trial, and a paid/higher
coverage source remains authoritative without downgrade. Physical validity and
attached digital access are projected independently.

Replacement requires exact same organization/revision, a claimed original and an
eligible unsold replacement, with a recorded lost/damaged/compromised reason. It
preserves persistent subject, original claim date, source term, sale/attribution
and original serial history. Old activation proof is revoked. A second paid
membership/trial is not issued and no casual subject transfer is allowed.

Original-item refunds/corrections retire the original credential and every current
replacement descendant, revoke their proofs and terminate the original included
trial. Audited replacement ancestors remain `replaced`; the final descendant is
void. Unclaimed, unshipped stock may return only through its supported original
item correction. Claimed/shipped credentials never silently recycle. Voiding an
unsupported replacement also finds its original trial through the immutable chain.
A reviewed/ambiguous original order holds all descendant credential validity.

Lifecycle/expiry maintenance is bounded and never extends a configured validity
window. Controlled cleanup explicitly voids eligible cards, revokes temporary
source access and archives retired batches before the deadline, preserving history.
Real customer/youth cards or document contents are not acceptance fixtures.
