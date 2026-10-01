# Current Build State

## Active website branch and preview

- Repository: `eaglevisiondigital/theboss`.
- Website branch: `build/approved-homepage`.
- Draft PR: #2.
- Review URL: https://deploy-preview-2--bossplus.netlify.app
- Netlify website project: `bossplus`, `bc4662a5-57c4-4fdc-8754-aa1be8aa9a8a`.
- Earlier public frontend is preserved on `build/premium-site-v1`.
- Homepage, Boss Bucks and Fundraising are published on bossplus. Shared main remains unmerged.

## September 30, 2026 homepage completion

The full approved desktop homepage is implemented as responsive semantic HTML:
header, photographic hero, three ecosystem cards, Boss Bucks Discounts, Digital
Money Board, Family Boss Bucks approved costs, coming-soon gas and restaurant
gift cards, Boss Engage, merchant invitation, final CTA and footer.

The exact approved raster remains the visual source of truth at
`public/design/approved-desktop.png`. Product and photographic crops reuse that
artwork; the hero uses its approved standalone asset. Photography keeps the
approved photographic appearance. Product examples are labeled illustrative.
All navigation and CTA destinations use the existing routes and lead forms.

Family and participant balances remain restricted to approved spending, with no
cash withdrawals or personal bank transfers. Only eligible team and organization
proceeds may transfer to approved organizational bank accounts. Discount
membership and earned Boss Bucks value have separate homepage explanations.
Gift cards are visibly marked coming soon. No wallet or payment backend was added.

See `docs/design/approved-homepage.md` and `docs/design/preview-qa.md` for the
implementation contract and verification record.

## Preserved foundation

Existing product, audience and company routes, Netlify intake forms, thank-you
flow, SEO metadata, preview noindex policy and architecture/security documentation
remain available. The prior form success-handler fix remains intact.

## Boss Bucks interior page

Owner approved the proposed desktop design and requested implementation and going
live on September 30, 2026. The responsive page is implemented at `/boss-bucks`.
It includes discount membership vs earned value, approved family costs, coming-soon
gift cards, fundraising steps and separate family/organization spending rules.
See `docs/design/boss-bucks-page.md` for asset provenance and verification.

## Next work

1. Publish and verify the approved responsive Digital Money Board page.
2. Prepare the Boss Engage interior-page mockup for owner review.
3. Extend the approved website identity through remaining interior pages.
4. Complete production contact, legal, abuse prevention and launch configuration.
5. Progressive integration with the separately released Boss platform.

Other interior pages retain the earlier foundation. Public website work preserves
the platform/backend strategy. Wallet and payment functionality is not added by
this website release.


## October 1 Fundraising checkpoint

Owner approved the Fundraising desktop mockup and directed implementation and
publication. The responsive route is implemented. Source and content contract:
`docs/design/fundraising-page.md`. Boss Bucks and the homepage were already
published and browser-verified from commit 930a3a4, Netlify deployment
6abd749baa010200085c0531. Fundraising was published and browser-verified from commit e781004179d7e44e5e8354edaa49a969d300fd71, Netlify deploy 6abe7fd495675f00080866a5.


## October 1 Digital Money Board checkpoint

Owner approved the organizer-focused revised mockup and authorized implementation
and publication. Responsive `/money-board` is implemented and locally verified.
See `docs/design/money-board-page.md` for content contract, assets and QA.
Publication confirmation and exact deployed revision will be recorded on PR #2.
The page markets the product to fundraising organizers. Operational payment and
wallet systems remain separate; thebossplatform is untouched.
