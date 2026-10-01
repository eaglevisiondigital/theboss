# Digital Money Board page

## Approved October 1, 2026

Owner approved the revised desktop mockup and instructed implementation/publication.
Audience is fundraising organizers, not supporters making a donation at that moment.
Visual contract: `money-board-desktop-approved.png`; preserve composition, photos,
black/orange/white identity, original Money Board device artwork and section order.

Hero: Help your supporters Give like a Boss. A signature fundraising experience.
Only from Boss. Bring Donate, Spin, visible progress and participant sharing together
on one digital board. Avoid unsubstantiated claims that no competitor exists.

## Implementation

Route `/money-board`; responsive semantic HTML and scoped CSS, approved shared
header/footer, accessible headings and navigation. Donate/Spin and tile examples
are illustrative static previews, not payment controls. Primary CTA opens the
existing fundraising intake; secondary hero CTA anchors to setup steps.

Sections: organizer hero; Donate/Spin; available/reserved/claimed; campaign identity,
participant links/QR and reporting; setup/share/progress; Boss ecosystem; final CTA.
Anonymous support is qualified where enabled. Confirmed gifts stay claimed.
Features and illustrative product examples retain their qualifications.

## Assets

- Approved revised desktop mockup preserved in this directory and
  `public/design/money-board-approved.png`.
- Original approved product phone: `public/images/approved/money-board.jpeg`.
  SVG clipping removes surrounding pale background without redrawing device UI.
- Hero photograph: `public/images/approved/money-board-hero.png`, generated as a
  clean background derived from the approved mockup, removing page text and phone.
- Team, family and laptop previews reuse approved mockup artwork via SVG viewBox.
- All marketing copy, CTAs and tile explanations are real semantic page content.

## Verification

Production build and TypeScript pass. Chromium at 1440, 1024, 768, 390 and 320 pixels:
no horizontal overflow, one h1, organizer-focused copy, image loading, tile-state
copy, setup anchor, mobile navigation and Escape. All 13 distinct navigation
paths return HTTP 200. Primary intake and Fundraising CTA click-throughs pass.
No runtime errors. Desktop/mobile screenshots reviewed; phone background and
laptop crop corrected. No real lead submission or payment attempted.

Public release verification is recorded on PR #2 after publication. This page
implements the public website only; it does not add Money Board payment operations.
