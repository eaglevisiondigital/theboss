# The Boss approved homepage implementation

Desktop design approved by Dave on September 30, 2026. Source of truth:
`public/design/approved-desktop.png`.

The first-slice mobile reference is `docs/design/mobile-first-slice.png`. It is
prepared for review and is not recorded as independently owner-approved.

## Completed homepage

Following section 112 of the supplied master handoff, the header, hero and first
major section were built and verified on the Netlify preview first. The owner
then directed continuation. The remaining homepage is now implemented on
`build/approved-homepage` in the approved sequence:

1. Header, hero and three ecosystem cards.
2. Boss Bucks Discounts with its approved phone and photographic presentation.
3. Digital Money Board with white tiles, Donate/Spin and progress preview.
4. Family Boss Bucks for sports fees, registrations, gear, children’s and youth
   camps, tournaments and eligible travel.
5. Coming soon: use Boss Bucks to purchase gas and restaurant gift cards.
6. Boss Engage and Family Hub platform preview.
7. Merchant invitation, final fundraising CTA and The Boss footer.

The earlier frontend remains preserved on `build/premium-site-v1`. Existing
interior routes, intake forms and architecture remain available. Their design
and content still need the planned interior-page review and implementation.

## Visual implementation contract

- Master brand THE BOSS; exact approved B+ source artwork, not a redrawn mark.
- Boss orange `#ff4f00`, ink `#080c0d`, white primary surfaces.
- White-label action buttons use the deeper brand orange `#d54200` for 4.56:1
  text contrast, including phone layouts. Headlines and brand artwork retain
  the approved bright orange. Hover buttons use `#ba3700`.
- Locally hosted Inter, including the SIL license. Heavy, tightly spaced headlines.
- Preserve approved headline wrapping, section sequence and black/white balance.
- Rectangular orange CTAs with modest radii, one clear primary action per section.
- Desktop phones cross the savings/Money Board boundary as in the approved design.
- Mobile uses deliberate stacked copy and photographic/product compositions.
- All public text, navigation, expense categories, schedule preview and CTAs are
  semantic HTML. Raster product screens are illustrative visual previews.
- Photographic and product crops use SVG viewports onto the exact approved
  desktop raster. Crop boundaries exclude baked-in marketing text where practical.
- Reuse approved assets. Do not redesign the homepage during implementation.
- No em dashes, invented testimonials, real-customer claims or live success totals.

Photography must look natural and photographic, without synthetic skin, distorted
hands/faces, impossible clothing or unnatural proportions. The approved illustrative
imagery is not represented as documentary photography or real customers.

## Family Boss Bucks integrity and product status

Discount membership access and earned wallet value are explained separately.
Family/participant value cannot be withdrawn or transferred to personal bank
accounts. Only eligible team and organization proceeds may settle to approved
organizational bank accounts. Family value and organization settlement remain
separate backend concepts; this website pass does not implement those ledgers.

Gas and restaurant gift cards are visibly coming soon. Product UI offers, names
and totals are illustrative examples, not verified relationships or live results.
The Engage schedule is labeled platform vision and does not imply a live account.

Detailed campaign rules belong on reviewed interior pages: configurable 30/60/90-day
trials, optional independent donations, current qualifying thank-you gift threshold
more than $25. No new business rule, price or allocation was invented in this pass.

## Hosting

Existing Netlify website project: bossplus, bc4662a5-57c4-4fdc-8754-aa1be8aa9a8a.
Git preview workflow uses draft PR #2. This branch is for review, not production.
No production cutover or PR merge until the hosted preview is approved.
