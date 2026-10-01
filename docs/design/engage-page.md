# Boss Engage page

## Owner-approved October 1, 2026

Visual contract: `engage-desktop-approved.png`, final corrected apparel version.
Preserve approved layout, typography and black/orange/white Boss identity.
Audience: leaders choosing organization/team management; families are shown as a
connected experience across multiple organizations, not only one organization's teams.

Family headline: Multiple kids. Multiple teams. Multiple organizations. One Family Hub.
Copy explicitly covers schools, clubs and organizations; filters by child, team or
organization, or a combined family week. This presentation does not authorize data
access across unrelated organizations or implement platform permissions.

Photography is varied: elementary-age boys/girls soccer with coaches; father, teen
volleyball player and younger baseball player; teenage boys basketball; girls cheer.
Apparel reads BOSS (two S letters), hats a single B. Original B+ app identity remains.
No girls in football pads or boys in cheerleading uniforms in the approved imagery.

## Implementation

Responsive `/engage` uses semantic HTML and scoped CSS plus the existing approved
header/footer. Marketing text and CTAs remain real page content. Device previews
reuse approved artwork with SVG clipping; product interactions are illustrative.
Hero CTAs anchor to operations and family sections. Family Hub, Fundraising, Boss
Bucks, team-store inquiry and Get Started use existing routes.

Original approved mockup is preserved in docs/design and public/design.
Clean standalone hero `public/images/approved/engage-hero.png` was derived from the
approved mockup using image generation to remove overlaid text/devices. It retains
photographic visual style; the imagery is illustrative, not a real customer claim.
Other photos/devices reuse the final approved artwork. Message preview uses semantic
HTML; RSVP choices are examples, not functioning participation controls.

## Verification

Production build and TypeScript passed. Chromium at 1440, 1024, 768, 390 and 320 pixels
passed: no overflow, one h1, cross-organization family copy, anchors, images, mobile
navigation/Escape, and no runtime errors. All 12 distinct navigation destinations
returned HTTP 200. Family Hub, Fundraising, Boss Bucks and team-store CTA clicks passed.
Desktop/mobile renders reviewed and photo/device placement refined.

No lead form submission, actual registration, messages, payments or backend changes.
Platform-vision and illustrative-preview qualifications remain visible.
Exact publication and browser verification are recorded on PR #2 after release.
