# The Boss approved homepage implementation

Desktop design approved by Dave on September 30, 2026. Source of truth:
`public/design/approved-desktop.png`.

Mobile first-slice adaptation: `docs/design/mobile-first-slice.png`.
The mobile reference is prepared for review and is not recorded as owner-approved.

## Implementation checkpoint

Only the header, hero and ecosystem section are implemented in this branch, following
section 112 of the supplied master handoff. The earlier frontend remains preserved
on `build/premium-site-v1`. Existing interior routes, intake forms and architecture
remain available; their design and content have not yet been revised to this scope.

The homepage uses editable semantic HTML for all text, navigation and CTAs.
The hero is an image asset reconstructed from the approved visual direction.
The B+ header artwork and the three card photos use SVG viewports onto the exact
approved desktop raster, so their proportions and source pixels are preserved.
They are not redrawn marks. Inter is locally hosted under its included SIL license.

Photography must look natural and photographic, without synthetic skin, distorted
hands/faces, impossible clothing or unnatural proportions. Generated imagery is
not represented as documentary photography or real customers. The imagery is
illustrative, with no invented testimonials, merchant relationships or metrics.

## Locked content for remaining homepage sections

1. Boss Bucks Discounts: useful everyday savings, with approved product reference.
2. Digital Money Board: Donate or Spin, visible progress, participant/team credit.
3. Family Boss Bucks: raise or earn value through approved campaigns to help cover
   approved sports fees, registration, gear, camps, tournaments and eligible travel.
4. Coming soon: use Boss Bucks to purchase gas and restaurant gift cards.
5. Integrity: family/participant wallet value cannot be withdrawn or bank-transferred.
   Only eligible team and organization proceeds may be transferred to approved bank
   accounts. Family value and organizational settlement are separate ledgers.
6. Boss Engage, Family Hub and merchant partnership, then a concise final CTA/footer.

Discount membership access and earned wallet value must be explained separately.
No unlaunched feature is described as available. Exact trial and donation rules
belong on the relevant interior pages: configurable 30/60/90-day trials, optional
independent donations, current qualifying thank-you gift threshold more than $25.

## Hosting

Existing Netlify project: bossplus, bc4662a5-57c4-4fdc-8754-aa1be8aa9a8a.
Git preview workflow is available. This branch is for review, not production.
No production cutover or PR merge until the hosted preview is approved.
