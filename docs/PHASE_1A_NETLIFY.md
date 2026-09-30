# Phase 1A Netlify platform isolation

Verified and configured September 30, 2026 (America/Chicago). Only the existing `thebossplatform` site's settings were changed. No manual or platform deployment was triggered, no environment values were retrieved or written, and no domain or public website configuration was changed. Opening the draft PR subsequently triggered an automatic `bossplus` website preview under its existing policy, described below.

## Implemented and verified

The platform site's missing required public Supabase configuration was confirmed by the signed-in dashboard: **No environment variables set for this project**. Its untrusted fork deploy policy already requires approval. Builds were stopped first, before rebinding paths or the production branch, to use the assignment's safe preparation exception.

| Setting | Before | Saved after configuration |
| --- | --- | --- |
| Site | `thebossplatform`, `cf09c44d-f28b-45aa-8a18-e4fa81e2008f` | Same existing site |
| Repository | `github.com/eaglevisiondigital/theboss` | Same repository |
| Production branch | `main` | `build/boss-platform-v1` |
| Runtime | Not set | Next.js |
| Base directory | `/` | `apps/platform` |
| Package directory | Not set | Not set; configuration is found in the base directory |
| Build command | Not set | `npm run build` |
| Publish directory | `.` | `.next` relative to base; dashboard displays `apps/platform/.next` |
| Functions directory | Default `netlify/functions` | Default relative to base; dashboard displays `apps/platform/netlify/functions` |
| Build status | Active | **Stopped** |
| Branch deploys | Production branch only | Production branch only |
| Deploy Previews | PRs against production/branch deploy branches | **Disabled** pending reviewed backend/context setup |
| Node dashboard default | `24.x` | Same; nested source selects `24.20.0` |
| Build image | Ubuntu Noble 24.04 | Same |
| Deploy log visibility | Public | Same; future log policy review is pending |
| Allowed production deployment methods | All | Same; no manual deployment performed |

`apps/platform/netlify.toml` supplies independent build/publish settings and static-response noindex headers without a root `base` override. Netlify searches configuration in package, base, then root order. The package field is deliberately unset because the independent package, lockfile and configuration share the base. Netlify's current OpenNext adapter handles SSR automatically; no manual adapter pin or authored Netlify function is needed. The default functions directory does not imply an authored business function exists. [Netlify monorepo configuration](https://docs.netlify.com/build/configure-builds/monorepos/), [Next.js on Netlify](https://docs.netlify.com/build/frameworks/framework-setup-guides/nextjs/overview/).

## Published artifact and preview behavior

The project reader's current-deploy pointer remains `6abcceeae6153d4425c55b1d`, `ready`, exactly matching the pre-change pointer. The dashboard overview independently confirms **Currently published**, `main@47eb2f9`, published at 3:57 AM, links to that exact deploy ID, and shows **Builds are stopped**. The full commit SHA recorded in Phase 0 is `47eb2f94a86737bae0a0dc5ecb0a083dac9a0aa4`. Site preparation does not replace that existing root artifact. The new shell is **not hosted or production-validated** yet. [Existing platform deploy](https://app.netlify.com/projects/thebossplatform/deploys/6abcceeae6153d4425c55b1d).

Stopped builds prevent Netlify production builds, branch builds and deploy previews on Git pushes or build triggers. Local/manual upload remains possible, but was not used. No site was unpublished or deleted. [Stop or activate builds](https://docs.netlify.com/build/configure-builds/stop-or-activate-builds/).

The Phase 1A draft PR targets `main`, while this platform site is bound to `build/boss-platform-v1`. It intentionally receives no platform deploy preview. If previews are later enabled with the default target policy, only PRs against the configured production branch would qualify. Do not re-enable `main` as a branch-deploy branch just to obtain a preview: that would rebuild the website baseline in the platform path. Choose an approved platform review/release flow and isolated preview backend first.

After draft PR #3 opened, the unchanged `bossplus` site's existing PR-to-main policy automatically produced [website preview #3](https://deploy-preview-3--bossplus.netlify.app), deploy `6abce14c4ead130008be679e`. It uses that site's repository-root static pipeline, not the nested Next.js platform pipeline, and is not platform/auth validation. No public website setting was changed to cause or suppress it. A post-PR reader check confirmed all three current published deployment pointers above remain unchanged. Future website/platform PR filtering needs an approved integration decision; this assignment does not change website policies.

No Supabase project branch, staging database, auth callback URL, production domain or customer account was created. Future preview credentials must be context-specific and must never include privileged production credentials. The shell's framework noindex controls cover server responses; the nested Netlify header covers static responses. These remain local implementation until a reviewed deployment succeeds.

## Public website regression evidence

All relevant visible developer-settings regions were captured before any platform mutation and re-read after refreshing both public site dashboards. Exact visible-region comparisons found **zero changes** for `thebossplus` and `bossplus`, including repository, build settings, deployment methods, dependencies, branch/preview policy, build image, collaboration tools, snippet injection and pretty URLs. The only differences across all three sites were the intended platform Build settings and Branches and deploy contexts regions.

| Public site setting | `thebossplus` before and after | `bossplus` before and after |
| --- | --- | --- |
| Site ID | `e4276a55-854b-4a45-ae44-92b08330552c` | `bc4662a5-57c4-4fdc-8754-aa1be8aa9a8a` |
| Repository | `github.com/eaglevisiondigital/theboss` | Same repository |
| Production branch | `build/premium-site-v1` | `main` |
| Base / package | `/` / not set | `/` / not set |
| Runtime / command / publish | Next.js / `npm run build` / `.next` | Not set / not set / `.` |
| Functions | `netlify/functions` | `netlify/functions` |
| Build status | Active | Active |
| Branch deploys | Production branch only | Production branch only |
| Deploy Previews | PRs against production/branch deploy branches | Same policy |
| Logs / methods / Node / image | Public / all / `24.x` / Noble 24.04 | Same values |
| Current-deploy pointer | `6abc309fcc7a2f00082a5a16`, `ready` | `6ab9dd948acfaf00088fc347`, `ready` |

Current-deploy pointers, primary/branch URLs, visitor access control flags and forms flags also compare equal through the Netlify project reader. This is point-in-time preservation evidence, not an exhaustive audit of every private dashboard setting. Website branch/PR history checks and local builds are recorded separately in the Phase 1A completion report.

Machine-readable settings comparisons and publication evidence are retained privately outside this public repository in the implementation workspace. The configuration table and preservation results above are the public implementation record. No variable values, tokens or hidden session data were read or published.

## Remaining authorized/manual setup

Before reactivating builds, a separately approved setup must provide `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` for this site in the intended build/runtime contexts; select and review any required server-only origin configuration; review Supabase auth provider/signup policy, origins and exact callback URLs; and select the platform preview/backend strategy. Do not copy website variables or another product's database credentials.

After that setup, reactivate only this platform site's builds and perform a reviewed shell deployment from `build/boss-platform-v1`. Verify Netlify resolves `apps/platform/netlify.toml`, installs the nested lockfile and Node version, uses the automatic Next.js adapter, returns the intended headers, protects `/app`, exchanges and refreshes auth cookies safely, and keeps authenticated responses out of shared caches. Actual hosted SSR/adapter/session behavior is pending this deployment.

Public log/access policy and a long-term platform domain/release branch remain decisions for the main Boss Chat. No production secrets or environment variables were added in Phase 1A.
