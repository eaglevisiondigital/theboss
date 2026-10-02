# Fundraising interior page

Status: approved October 1, 2026. Responsive implementation complete; release verification in progress.
Reference: fundraising-desktop-proposed.png.

The owner directed the next page after publication of the approved homepage and
Boss Bucks page. This design follows the approved mockup-first workflow. It has
now been implemented as the /fundraising route after explicit owner approval.

## Visual and content contract

Match the approved THE BOSS header, B+ logo, black/orange/white palette, heavy
Inter headings, photographic realism, product imagery and footer.

Story: photographic Fundraise Like a Boss hero; four campaign options (physical
and digital Boss Bucks cards, trial invitations, independent donations and Money
Board); approved Money Board showcase; discounts and configurable 30/60/90-day
trial invitations; optional donations and more-than-$25 qualifying thank-you gift;
team/participant attribution through links and QR codes; approved family costs
and separate organizational settlement; team-store connection; final intake CTA.

No invented customer results, partnerships, prices, allocation rules or testimonials.
All product amounts, names and offers are illustrative. Campaign features vary.
Discount membership and earned value are distinct. No family cash withdrawals or
personal bank transfers. Only eligible organizational proceeds may transfer to an
approved organization bank account.

## Implementation notes after approval

- Preserve original approved Money Board and Discounts source images, rather than
  the generated approximations inside this page mockup.
- Marketing copy, trial-duration labels and controls must be semantic HTML.
- Trial durations are campaign-configurable, not a supporter-side selection at
  this marketing stage; keep the three duration pills together with the trial copy.
- Thank-you membership qualification uses more than $25, not $25 or more. Display
  campaign terms and gift rules, and make donations explicitly optional.
- Mark the team-store connection as platform vision in implementation; the mockup
  does not show that label clearly enough. No functional commerce is implied.
- Keep all approved family categories including sports registration, team gear,
  children's/youth camps, tournaments and eligible travel in semantic copy.
- Use /fundraising/get-started for intake, /money-board for Money Board, /boss-bucks
  for savings. Select a supported existing destination for team stores without
  inventing an operational store or checkout.
- Restore the complete approved homepage footer navigation when implementing.
- Adapt to phones and compare browser renders with the approved mockup before
  publishing. Backend/payment work remains separate.

## Asset provenance

Built-in Imagegen generated the proposed mockup using the approved homepage,
approved Money Board phone and approved Discounts phone as visual references.
Prompt: create a full-length premium desktop Fundraising interior page matching
those references, with the ten sections and content rules specified above,
photographic sports/community imagery, legible copy and no fabricated results.

## Current production checkpoint

The approved homepage and Boss Bucks page were published September 30, 2026 from
commit 930a3a438cb0ae03a8f941cb439df6a2ea76a7c5, Netlify deployment
6abd749baa010200085c0531. The live Boss Bucks page was visually verified in the
cloud browser. The Fundraising release follows this production checkpoint.


## Implementation checkpoint

Semantic HTML implements the approved page story and controls. Original approved
Money Board and Discounts JPEG sources supply product UI. Clean photographic
crops supply the family, merchandise and team imagery. Built-in Imagegen created
`public/images/approved/fundraising-hero.png` from the approved hero: remove page
text and controls, retain the coach and youth team, sunset field, black/orange
apparel and dark left space for HTML copy. Campaign imagery is illustrative.

The approved homepage team-celebration crop replaces the proposed raster's
text-overlapped crop, preventing duplicated raster text behind the HTML copy.
Mobile presents the Money Board copy first, with team/phone visuals below.

Trial-duration pills are descriptive campaign options. Donations remain optional;
qualifying gifts use more than $25. Team-store CTA leads to the existing Engage
page, with the planned store connection labeled platform vision. Intake uses
/fundraising/get-started. No operational checkout, wallet, payment, authentication,
backend or platform release changes are part of this implementation.


## Verification

Next.js production build and TypeScript passed. Browser checks passed at 1440,
1024, 768, 390 and 320 pixels: no horizontal overflow, one h1, images loaded,
optional-donation and approved-spending rules present, anchor and mobile menu
working, all 14 destinations HTTP 200, and intake, Money Board and team-store
CTA navigation working. Desktop and phone screenshots were compared with the
approved design. Photograph crops and mobile order were corrected before release.
