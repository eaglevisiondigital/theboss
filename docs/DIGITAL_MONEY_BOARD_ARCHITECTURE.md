# Digital Money Board — Phase 7A

Status: Phase 7A COMPLETE; canonical release and the fixed hosted non-payment
acceptance window passed with explicit cleanup. Uses existing `money_board` plus
live `fundraising` context. Paid claims remain SQL/runtime evidence only.

A board belongs to exactly one canonical campaign and optionally one fundraiser
or exact team. Unique null-aware ownership prevents accidental duplicate default
boards. A participant has one board per fundraiser/campaign. Organization/team
boards use safe public paths; participant boards use the current approved fundraiser
share. Boards never create duplicate campaigns or participant identities.

Configuration is title, goal, positive starting amount, positive increment, explicit
bounded count, visibility and reservation duration 480–600 seconds (default 600).
Approved starting choices 1/5/10/20 and increments 1/5/10/20/50/100 support validated
positive custom amounts. All canonical money uses integer currency minor units;
presentation uses the currency's decimal precision.

Generation is deterministic: `start + (ordinal - 1) * increment`. Every generation
has immutable settings and unique ordinal/amount tiles. Preview includes tile count,
smallest/largest amount, arithmetic-series sum, board/participant/campaign goals and
“If all claimed” text. It never claims that generated value equals a goal unless it
does. Generations are versioned before paid claims. Regeneration is rejected while
an unpaid reservation remains live or any authoritative paid evidence exists.
Paid tile IDs, prices, source attribution and public donor/anonymous preference
remain preserved. Ordinary edits never reopen paid tiles.

Current state is derived: `available`, `reserved`, `payment_pending`, `claimed`.
A row lock plus current campaign/module/relationship checks gives exactly one
reservation winner. A short random supporter capability is hashed at rest.
Server expiration determines availability; reads can show an expired unpaid tile
as available without rewriting attempt history or requiring a cron. A stale
capability cannot create an intent. Explicit release/archive preserves attempts.

Intent creation retains canonical tile price and provenance, optional monthly
6–12-month commitment and fee-cover preference. The public experience states that
no payment processing is available, takes no card/bank detail and cannot mark a tile
paid. First trusted recurring success claims the tile; future installments remain
unpaid plans. Paid fixtures remain disposable, with no production fake-payment path.

Public views page at most 100 tiles, show textual states and confirmed progress,
use premium black/orange/white styling, keyboard controls, accessible form labels,
announcements and a reservation countdown. The canonical share URL generates its QR.
Public projections omit private/internal identity, donor contact and administration
fields. Mobile validation must cover 1280/768/390/320 widths before closure.

Generation uses batches of at most 10,000 tiles per transaction. The tested
100,000-tile scenario is not a product cap. Positive integer count, tile amount
and exact aggregate precision limits protect storage and projection arithmetic.
Scale checks exercise bounded first/last pages under the existing eight-second
database ceiling. Full historical SQL/races, new
same-tile/expiry/pause/removal/regeneration/success/recurrence/reward/revocation races,
application tests, advisors and one fixed hosted non-payment window remain release
gates. No live payment, wallet or next-phase work is included.


Generation uses at most 10,000 tiles per request and can continue the same
unpaid generation. Partial generations cannot publish. 100,000 is the validated
performance scale, not a product board-size ceiling. Integer storage and exact
JavaScript minor-unit projection bounds apply. Board configuration changes
create a new immutable generation only before settled claims/current reservations.
Leaderboards default off; public participants additionally require current
approved display/share and explicit guardian/adult opt-in. Exact program views
and participant cursors retain bounded payloads.


## Phase 7B wallet boundary

Phase 7B wallet grant provenance references canonical success evidence, intent, board/tile, share/QR and source reference. Reservations and unpaid tiles never earn Boss Bucks. The may-earn indicator reveals no family balance or wallet identity; reward membership qualification is independent. No paid fixture or mark-paid route is introduced.

See [wallet architecture](BOSS_BUCKS_WALLET_ARCHITECTURE.md).


## Phase 7D provider-pending tile hold

After valid provider submission, ordinary tile/intent expiry cannot release or reassign an unresolved tile. Pending ACH counts no raised value, reward, paid claim or wallet earning. Final approved ACH or captured CARD applies the existing trusted success chain once, using frozen provenance/policies even after natural expiry. Explicit cancellation/release followed by contradictory success creates canonical unallocated review and no second claimant. Refunds preserve the historical permanent tile claim.

## Phase 7E membership/product integration

Status: local implementation; canonical release and hosted acceptance pending.

Phase 7E campaign membership/trial/gift/card options coexist with the existing board; they do not replace tiles, bypass reservations, mark support paid or mint Wallet grants from product purchases. Gift conversion uses the original exact donor/intent and trusted >2500 USD qualification. Private claims never reveal board supporter account, household, shipping or Wallet data.

See [membership](BOSS_BUCKS_MEMBERSHIP_ARCHITECTURE.md), [physical cards](BOSS_BUCKS_PHYSICAL_CARD_ARCHITECTURE.md) and [fulfillment](BOSS_BUCKS_PRODUCT_FULFILLMENT_ARCHITECTURE.md).
