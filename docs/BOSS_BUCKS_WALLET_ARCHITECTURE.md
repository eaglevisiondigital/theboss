# Phase 7B: Boss Bucks family wallet

Status: COMPLETE; canonical release, bounded hosted acceptance and explicit cleanup complete.
See PHASE_7B_ACCEPTANCE_ADDENDUM.md for classified evidence and approved source limitation.
The Phase 7B handoff approves this internal,
non-spending value boundary. No payment provider or production earning rate is seeded.

One canonical household owns one wallet for each currency contract. Children are
earning attribution, never separate spending buckets. Each wallet account is
permanently restricted to its originating organization. Family currency totals
are display aggregates; they are not unrestricted accounts or cash.

The journal uses signed integer minor units. Issuance posts a positive amount to
the household organization account and the exact negative amount to that
organization/currency clearing account. Reversal or expiration posts the opposite
pair and references the original grant/journal. Deferred constraints enforce
exactly two matching postings, balanced currency, original source restrictions,
and one termination per grant. Journals, postings, grants, source snapshots and
policy revisions reject updates, deletes and truncation. Balances derive directly
from indexed postings and current grant availability; no mutable balance cache
exists. Reconstruction is therefore a fresh projection, without generation lag.

Explicit wallet access is bound to a currently verified guardian relationship,
the false-default `can_manage_boss_bucks` capability, and current actor/dependent
membership in the specified household. Manager and viewer access are explicit.
Household membership, another guardian flag, a team role, or knowing an ID never
substitutes for these checks. Organization finance receives only its organization
slice. Team and dependent self visibility default closed. Lock fences and fresh
clock-time checks enforce revocation after waits.

Campaign earning revisions are immutable: none or percentage of verified gross,
0–10,000 integer basis points, explicit currency and approved source channels.
Rounding uses integer floor. No delay or expiration is assumed. An optional
explicit delay/expiration belongs to the revision. Each newly created contribution
intent snapshots the applicable earning revision and explicitly bound household.
No historical intent is backfilled. A fundraiser household must be explicitly
bound by its authorized guardian with wallet authority before that snapshot.
Unresolved ownership holds issuance; no new household is inferred or created.
Supporter trial/gift policy remains independent.

Only the private trusted success boundary can issue. A grant references one
canonical successful contribution and its immutable source snapshot, with unique
source consumption. Parent-first locking serializes policy/source correction and
issuance. Current invalid source state denies issuance after waits. Termination
preserves attribution and cannot make a family balance negative. Unpaid recurring
installments earn nothing. Campaign archival preserves existing grants; archived
organizations preserve history while availability is withheld. Team transfers
never rewrite source organization, participant or campaign provenance.

Family activity is cursor-paged; organization reports are tenant-scoped and
bounded. The canonical charge preview separately checks current payment authority,
charge household/participant/organization and currency; it returns due, same-org
available, the smaller potentially eligible amount and remaining future tender.
It makes no allocation, debit or payment. Public fundraising/recruiting tokens
never authorize a wallet. Family views omit donors and private source references.

Phase 7C must authorize an atomic same-org debit/allocation and split tender for
any valid parent-to-organization charge. Phase 7D must decide settlement and
already-spent source reversal liability; no negative wallet or payout behavior
is invented here. Phase 7E membership cards/discounts remain a separate product.

Canonical hosted positive issuance is permitted only with legitimate trusted
controlled success evidence and supported recovery. With no such source, the
approved classification is: SQL/RUNTIME VERIFIED; HOSTED POSITIVE UNVERIFIED DUE
TO APPROVED NON-PAYMENT SOURCE LIMITATION. No synthetic paid evidence will be
inserted into canonical production to satisfy a hosted checkbox.

Exact held-source ownership resolution is private and requires the current explicit
fundraiser binding plus current wallet guardian authority. It appends an immutable
owner-resolution record and consumes only the source's originally captured policy.
It cannot create a policy snapshot for a historical intent or credit a none-policy
source. The owner resolution path is not exposed to authenticated clients.

API minor-unit amounts are decimal strings, formatted with integer arithmetic.
Family activity uses 50-row tuple cursors; organization family slices use 100-row
wallet cursors. Child/campaign breakdown and fundraiser choices are bounded at
100 each; totals still cover the entire authorized ledger. Organization finance
may see trusted source references in its own slice; family/public projections omit
those references and donor details. None of these bounded lists load national data.

The current trusted invalid-source path terminates an unspent original grant in
full once, including a partial-refund signal. It does not invent a proportional
partial-refund allocation or already-spent deficit rule. Those dependent-allocation
and settlement choices require Main Boss Chat direction before Phase 7C/7D.

Fresh reads fence guardian/access/module state and the wallet; postings take the
same wallet exclusively. Reconstruction shares that fence. No timeout was raised.
No provider or expiration scheduler is enabled; expired value is excluded by the
current clock before a bounded trusted expiration batch materializes its journal.
