# Current Build State

## Active website branch and preview

- Repository: `eaglevisiondigital/theboss`.
- Website branch: `build/approved-homepage`.
- Draft PR: #2.
- Review URL: https://deploy-preview-2--bossplus.netlify.app
- Netlify website project: `bossplus`, `bc4662a5-57c4-4fdc-8754-aa1be8aa9a8a`.
- Earlier public frontend is preserved on `build/premium-site-v1`.
- Production cutover and merge remain pending owner approval.

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

1. Verify hosted Boss Bucks publication and record its release checkpoint.
2. Prepare the Fundraising interior mockup for owner review.
3. Extend the approved website identity through remaining interior pages.
4. Complete production contact, legal, abuse prevention and launch configuration.
5. Progressive integration with the separately released Boss platform.

Other interior pages retain the earlier foundation. Public website work preserves
the platform/backend strategy. Wallet and payment functionality is not added by
this website release.
