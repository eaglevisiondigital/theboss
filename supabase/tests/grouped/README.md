# Grouped Money Board local validation

Synthetic disposable infrastructure only. No script in this directory is a production endpoint, migration runner against hosted Supabase, payment adapter or credential recovery tool.

## Database

Run `PG_BINDIR=/path/to/postgresql17/bin bash supabase/tests/run-local.sh --testgrouped` for seven focused suites plus fourteen observed two-connection contention races. Run the same harness without a selector for all historical SQL/bootstrap/sealed/concurrency gates and the new suites. The runner rejects unsafe sockets/users, binds no TCP, rejects host authentication, uses a private directory and destroys its cluster. The existing `--upgrade8b1` still stops at migration 119 and independently verifies the historical 113→119 release.

`schema-contract.sql` emits only proposed schema/RPC metadata and supplemental TypeScript. `generate-types.sh` checks the stored contract, rejects a deliberate transactional column addition and a deliberately mistyped TypeScript identifier, then proves the restored positive contract. Existing canonical `src/lib/supabase/database.types.ts` is unchanged because production remains at 119. Canonical regeneration is a later authorized release gate.

The financial suites call existing **private** trusted payment preparation/dispatch/receive/correction contracts with synthetic local account metadata; no provider adapter, network submission, actual processor binding, Auth password/token or live source is used. These contract calls do not establish real payment-provider certification.

## Real Next/React/native browser acceptance

1. Bootstrap 119 historical migrations plus the four proposals in a private `/tmp/boss-db-test.*/socket` database, then apply `browser-fixture.sql` there only.
2. Build the platform with its canonical public URL and an explicitly nonfunctional synthetic publishable string, loopback origin and telemetry disabled. Do not load production keys.
3. Start the production Next build on loopback. Set `BOSS_GROUP_TEST_SOCKET`, `PG_BINDIR` and `NODE_OPTIONS=--import=/absolute/path/networkless-preload.mjs` before startup. This test-only preload routes five allowlisted public RPCs to the actual disposable PostgreSQL functions and rejects every other non-loopback network request. Each native cart write commits; a transport that rolls it back cannot test persistence.
4. Serve the loopback application over temporary local HTTPS using a private self-signed localhost certificate. Match the configured platform origin. Keep the real Secure/HttpOnly/SameSite=Strict cookie attributes. Never disable them to make a test pass.
5. Run `browser-acceptance.mjs` with `BOSS_GROUP_TEST_SOCKET`, `PG_BINDIR`, `BOSS_LOCAL_UI_ORIGIN=https://localhost:port`, a local `BOSS_TEST_PLAYWRIGHT_MODULE` and optional `BOSS_TEST_BROWSER_EXECUTABLE`. Use a fresh isolated browser context; never attach the owner's hosted profile. `BOSS_TEST_OUTPUT` selects a private artifact location outside the repository.
6. The seventeen native checks cover server/client rendering; canonical multi-tile totals; page navigation and full reload persistence; five exact viewport widths; three mobile columns; bounded menus; amount-fit/hidden skip-link assertions; keyboard/Home/End/Escape/outside-click/Tab; exact Jump including large amounts at 320px; atomic reservation; unpaid preparation; awaiting-payment reload; cancel/clear; no client exceptions; and actual-route rejection of mark-paid.
7. Close the browser context; stop local servers; delete the temporary certificate/key directory and disposable database. Retain only sanitized test summaries/screenshots. The harness never reads cookies, browser storage, Auth material or private payment proofs.

Classify this as **LOCAL APPLICATION VERIFIED** and **SQL/RUNTIME VERIFIED**, never hosted production PASS. PostgREST/Auth HTTP issuance/actual provider callbacks are not emulated by the PostgreSQL compatibility bootstrap or this allowlisted fetch transport.

## Populated additive upgrade

Run `PG_BINDIR=/path/to/postgresql17/bin bash supabase/tests/grouped/upgrade.sh` separately from the full runner. It starts with exactly 119 historical migrations, creates synthetic legacy card success/correction and unresolved ACH, snapshots every original public table rowset, applies only the four proposals and checks all original counts/SHA-256 values unchanged. Legacy claims, net corrections, old gross and financial pending protection must remain correct. It destroys its private database and performs no network or provider execution.
