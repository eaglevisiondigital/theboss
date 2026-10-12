# Global fundraising local amendment validation

This directory is local/disposable test infrastructure. It never connects to canonical Supabase, activates a provider, reads production environment files, or creates production authority. `run-local.sh` applies the exact 119 historical migrations, four frozen Grouped Checkout proposals and six additive amendment proposals to PostgreSQL 17 on a private Unix socket with TCP disabled. It destroys its own cluster.

## Reproduce

- Complete historical SQL, sealed-source and observed concurrency gates: `PG_BINDIR=/path/to/postgresql17/bin bash supabase/tests/run-local.sh`.
- Amendment cases and ten new races: the same runner with `--testglobal`.
- Populated 119→123→129 upgrade: `PG_BINDIR=/path/to/postgresql17/bin bash supabase/tests/global/upgrade.sh`. The original 119→123 proof checks every original public rowset. The 123→129 proof excludes only the explicitly added platform permission and its two platform role mappings, and removes the new nullable `money_boards.unit_id` field when comparing old rows. It does not backfill, reprice or reallocate historical sources. Intermediate proposals are checked for closed raw ACL/RLS after each migration.
- Generated local types: the full runner compares twelve tables and two RPCs to `schema-contract.json`, rejects deliberately altered schema/types, then confirms the restored contract. Existing canonical types are unchanged; canonical generation is a future authorized release gate.
- Native Next/React acceptance: build a separate copy in `/private/tmp/boss-global-local-build`, excluding all `.env*`, `.netlify`, generated output and credentials. Supply only the canonical public project URL and an explicitly nonfunctional synthetic publishable string. Set the origin to `https://localhost:31443`. Run `global/browser.sh` with `PG_BINDIR`, `BOSS_TEST_LOCAL_BUILD`, local `BOSS_TEST_PLAYWRIGHT_MODULE`, optional `BOSS_TEST_BROWSER_EXECUTABLE`, and private `BOSS_TEST_OUTPUT`. It boots all 129 migrations, serves the production build over disposable localhost TLS, uses the existing network-blocking PostgreSQL RPC transport and executes all seventeen original native checks at 1440/1280/768/390/320px, then six added organization/ministry checks at the same widths with Sports/Wallet disabled. It removes its database, servers and synthetic certificate material. It never attaches the owner's browser profile or reads cookies/storage.

All money, people, membership, account and provider evidence in fixtures is synthetic and isolated. Trusted private processor-contract calls test local accounting and recovery, not actual Authorize.Net/NMI execution or certification. The before-correction regression failures are retained as private sanitized summaries; unrestricted evidence/logs are excluded from the release archive.

## Boundaries

Platform economics remain separately immutable and platform-authorized. Organization/team/unit policies designate verified organization proceeds as **noncash** credit, creating no additional payable, fee settlement or Wallet grant. Ministry/project scopes use an exact existing organization-unit identifier, never a role-name assumption or descendant inheritance. Adapters define independent tenant/Auth/branding/payment/optional-benefit contracts; no Kingdom production deployment or database is activated.

Positive fixed platform charges are supported by native fundraising preparation only. Product sale prices retain the existing platform-owned immutable item economics; fee bills and Wallet redemption require zero for this additional fixed-charge field. Unsupported positive charges are rejected instead of silently ignored.

V3 reporting is exact-scope and bounded to 100 source records with UUID keyset pagination. It keeps provider gross cash, donation principal/refunds/net, physical/digital sales, product refunds/net/organization credit, platform revenue, actual processor cost, noncash credit, optional Wallet earning/correction, prepared-checkout reserved tile value, pending principal, permanent claims, settlement and payable/remittance/deficit amounts distinct. Unprepared cart reservations remain in the existing board V2 progress projection. These source measures are not new global mutable totals and do not redefine old reports.

The 10,000-tenant structural test and local two-connection races demonstrate specific index/isolation properties. They do not certify national production capacity, HTTP/Auth behavior, provider routing, or cross-product deployment. Those remain staged release/capacity gates.
