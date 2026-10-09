# Final amount-range picker — 2026-10-09

Updated preview: https://boss-money-board-design-preview.netlify.app/

Starting SHA: `45409f37f61e3d298a20e20d97eddd7e88d27454` on `codex/digital-money-board-preview`.

Final isolated Netlify deployment: `6ac966a0db28a6fe94bf4eed`, READY, project `303ca07b-86a3-4fae-83c8-5699d0101f1c`. An initial picker deployment (`6ac966378528b32df28988c1`) was superseded by the tested scroll-away dismissal correction. No other Netlify project was deployed or configured.

## Changes

Replaced only the native Amount Range select with a 360px desktop menu button, dark floating popover, two balanced option columns, orange checked range, and single-column scrollable mobile menu. Jump to Amount remains alongside, now a bold orange button with contrasting dark text. The floating menu positions above/below as space permits and clears the fixed navigation/cart. Closed menus occupy no tile space.

The controller provides native Enter/Space activation, arrow navigation (spatial two-column navigation on desktop), Home/End, Escape with focus restoration, outside pointer/focus dismissal, forward Tab to Jump to Amount, reverse Tab to the trigger, and visible keyboard focus. Checked state, expanded state, control labels, menu description and the existing polite status announcement reflect current page selection. Timer-driven rerender preserves the focused option. Scrolling the trigger out of view dismisses the menu rather than leaving an expanded off-screen control.

Generated ranges and existing page boundaries are retained: all ranges for boards with up to 20 pages, otherwise first/last plus up to seven nearby pages, at most nine options. Jump remains available for arbitrary configured amounts. No state-model change: cart remains in-memory and persists across page/range/mode navigation; reload/reset still resets the demonstration as before.

Source changes: `public/index.html`, `public/styles.css` (scoped additions), `public/demo.mjs` (picker wiring only), new `public/range-picker.mjs`, new `range-picker.test.mjs`, and static-artifact allowlist updated from 12 to 13 public files. No changes to `public/state.mjs`, previous cart/state tests, artwork, fonts, progress, Donate/Spin, tile styling, cart, checkout simulation, Latest Support or lower-page layout. All prior reports/security disclosures are retained unchanged.

## Validation

- **37/37 automated tests PASS:** all existing 27 plus 10 focused tests executing the shipping picker controller. Covers bounded large-board ranges; selected/focused ARIA state; desktop/mobile keyboard movement; Home/End; Escape; pointer selection; outside dismissal; Tab/Shift+Tab; rerender focus; integration with actual generated pages/cart/jump; scroll-away dismissal. Full result: `evidence/range-picker/tests.txt`.
- JavaScript syntax checks, artifact-isolation check and Git whitespace/diff checks PASS.
- Native local and hosted interaction checks PASS: Space opens, Enter selects, focus-only navigation does not change page, selected range persists on reopen, menu closes before page navigation, Escape restores trigger, outside click closes without stealing focus, Tab reaches Jump to Amount, scrolling away closes the menu. Cart `$5` remained through selection of page 10 and jump to `$175`; polite status reports the selected page and preserved cart.
- Large hosted board: 20,000 pages, nine options at a middle range, selected `$499,951–$500,000`, no horizontal overflow. Synthetic browser-local data only.
- At 320×640 with a selected tile, popup bottom 478px; sticky cart top 490px. The menu clears both cart and navigation. After Jump, focused tile bottom 371.93px versus sticky-cart top 850px at 320×1000; no persistent menu obstructs it.
- Hosted error/warning console inventory empty.
- Read-only public artifact verification: all 12 served files match local SHA-256 (the thirteenth `_headers` config is applied by Netlify). CSP `connect-src 'none'`, `form-action 'none'`, `frame-ancestors 'none'`, noindex and other isolation headers unchanged. Evidence: `static-artifact-sha256.json`.

| Actual hosted viewport | Selector width | Option columns | Page scroll width |
| --- | ---: | ---: | ---: |
| 1440×1000 | 360px | 2 | 1440px |
| 1280×1000 | 360px | 2 | 1280px |
| 768×1000 | 360px | 2 | 768px |
| 390×1000 | 251.125px | 1 | 390px |
| 320×1000 | 181.125px | 1 | 320px |

All five widths: no horizontal overflow, orange Jump button alongside, menu contained in viewport, closed picker leaves tiles unobstructed. Measurements: `evidence/range-picker/hosted-responsive.json`; native interaction observations: `hosted-interactions.json`. Screenshots for each width: `hosted-{width}-open.jpg` and `hosted-{width}-closed.jpg`. The responsive override was reset after testing. Accessibility semantics and keyboard behavior were inspected; no separate screen-reader user session was claimed.

## Isolation and completion

Only 13 reviewed static files were uploaded; evidence, tests and repository files are excluded from deployment. No backend, network API, account, persistent browser storage, database, Wallet or real payment processing is connected. No Supabase, production fundraising, public Boss website, PR #3 or production platform change; no later phase started. Production checkout remains `4b20ba6fec9b0491c3bbcb57d1d56ca3787495b4` and clean. No credential/session/proxy material was inspected, reused or included.

Applicable preview validation is the test/syntax/isolation/native-browser suite above. The preview branch is outside the production CI branch/path triggers; no new production application/database CI result is claimed. Final visual approval remains with the owner. Work stops after this isolated preview refinement.
