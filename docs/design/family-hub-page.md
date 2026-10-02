# Boss Family Hub page

## Approved October 1, 2026

Owner approved `family-hub-desktop-approved.png` and authorized implementation and
publication. Preserve its black/orange/white identity, layout and photographic
appearance. Brand: THE BOSS and official B+ icon. Apparel BOSS (two S letters),
single-B caps, varied ages and sports. No girls in football pads or boys in cheer.

Core message: multiple kids, multiple teams, multiple organizations, one connected
family. Combined calendars filter by child, team or organization. Each child has
a personal fundraising link/QR and progress view. Eligible fundraising credits
support approved family expenses; cash redemption is only for organizations.

## Implementation and assets

`/family-hub` is responsive semantic HTML with shared approved header/footer.
All primary copy, CTAs, features, wallet rules and participant progress cards are
HTML. Device and photo art reuse the approved mockup through SVG crops. Hero
`public/images/approved/family-hub-hero.png` was derived with image generation from
the approved mockup to remove website overlays while keeping the family and brand.
Photography is illustrative, not a claim that these are customers.

Hero CTAs navigate to page sections. Final CTAs route to `/get-started` and
`/engage`. Product screens and sample fundraising/QR previews are clearly labeled
illustrative and do not perform account, sharing, calendar or wallet operations.
The sample URL strings from the raster mockup are replaced by generic example
labels, avoiding unsupported functional links. Backend and permissions unchanged.

## Verification

Production build/TypeScript and diff whitespace check pass. Chromium verified
1440, 1024, 768, 390 and 320 pixel widths: no horizontal overflow, one h1, expected
cross-organization and wallet restriction copy, both hero anchor links, mobile
navigation/Escape, decoded images and no runtime errors. Twelve navigation
routes return HTTP 200; Get Started and Engage click-throughs pass. Desktop/mobile
screenshots reviewed; hero photo placement refined to keep the family visible.

Publication and exact deployment revision are recorded on PR #2 after live
verification. No payment, registration, messaging or backend deployment included.
