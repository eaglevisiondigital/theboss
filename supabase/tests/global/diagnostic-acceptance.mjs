// Native local browser acceptance; no production session or hosted window.
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { parseFundraisingDiagnostic, FUNDRAISING_DIAGNOSTIC_PREFIX, FUNDRAISING_CORRELATION_HEADER } from '../../../apps/platform/src/lib/fundraising/diagnostics.ts';
const require = createRequire(import.meta.url), { chromium } = require(process.env.BOSS_TEST_PLAYWRIGHT_MODULE);
const socket = process.env.BOSS_GROUP_TEST_SOCKET, bin = process.env.PG_BINDIR, origin = process.env.BOSS_LOCAL_UI_ORIGIN, output = process.env.BOSS_TEST_OUTPUT;
if (!/^\/tmp\/boss-db-test\.[^/]+\/socket$/.test(socket ?? '') || !/^https:\/\/localhost:\d+$/.test(origin ?? '') || !bin || !output) throw Error('Private disposable environment required');
const path = execFileSync(bin + '/psql', ['-X', '-qAt', '-h', socket, '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-c', "select public_path from public.fundraising_destinations where status='published' and kind='ministry' and campaign_id in(select id from public.fundraising_campaigns where name='Synthetic ministry native acceptance')"], { encoding: 'utf8' }).trim();
assert(/^[a-z0-9-]{6,100}$/.test(path));
const browser = await chromium.launch({ headless: true, executablePath: process.env.BOSS_TEST_BROWSER_EXECUTABLE });
const client = [], checks = [];let errors = 0;
try {
 const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1280, height: 1000 } });
 await context.route('**/*', route => ['localhost', '127.0.0.1', '[::1]'].includes(new URL(route.request().url()).hostname) ? route.continue() : route.abort());
 const page = await context.newPage();
 page.on('pageerror', () => errors++);
 page.on('console', message => { const record = parseFundraisingDiagnostic(message.text());if (record) client.push(record); });
 await page.goto(`${origin}/fundraise/${path}`, { waitUntil: 'networkidle' });await page.locator('.tile:not([disabled])').first().waitFor();
 const read = client.find(r => r.stage === 'client_rendered');assert(read);assert(client.some(r => r.operation === 'cart.open' && r.stage === 'response_accepted'));checks.push('server read/client render and canonical cart recovery correlations');
 await page.locator('[data-ordinal="1"]').click();await page.locator('.cart-total-row strong').filter({ hasText: '$1.00' }).waitFor();
 await page.locator('.cart-panel .primary').click();await page.locator('#reservation .primary').click();await page.locator('.hold').waitFor();
 await page.locator('input[name="display_name"]').fill('CONTROLLED_DIAGNOSTIC_PRIVATE');await page.locator('#reservation form .primary').click();await page.locator('#reservation .inline-note').filter({ hasText: 'Checkout prepared' }).waitFor();
 assert(client.some(r => r.operation === 'cart.reserve' && r.stage === 'response_accepted'));assert(client.some(r => r.operation === 'cart.prepare' && r.stage === 'response_accepted'));checks.push('native grouped reservation and unpaid checkout confirmation diagnostics');
 await page.locator('#reservation .close').click();await page.reload({ waitUntil: 'networkidle' });await page.locator('.cart-panel .primary').click();await page.locator('#reservation .hold').waitFor();
 await page.getByRole('button', { name: 'Release group and choose more tiles' }).click();await page.locator('.hold').waitFor({ state: 'detached' });await page.locator('#reservation .close').click();
 await page.getByRole('button', { name: 'Clear cart', exact: true }).click();await page.locator('.cart-total-row strong').filter({ hasText: '$0.00' }).waitFor();assert(client.some(r => r.operation === 'cart.cancel'));checks.push('explicit cancellation/clear cleanup and reload persistence');
 const denial = await page.evaluate(async header => { const response = await fetch(location.pathname + '/cart', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ action: 'mark_paid', request_id: crypto.randomUUID(), input: {} }) });return { status: response.status, correlation: response.headers.get(header) }; }, FUNDRAISING_CORRELATION_HEADER);
 assert.equal(denial.status, 422);assert(denial.correlation);checks.push('real protected forged-command denial with retrievable server correlation');
 assert.equal(errors, 0);assert(!JSON.stringify(client).includes('CONTROLLED_DIAGNOSTIC_PRIVATE'));assert(!JSON.stringify(client).includes(path));assert(!JSON.stringify(client).includes('session_capability'));checks.push('no client exceptions, donor payloads, path identities or checkout capability in diagnostics');
 writeFileSync(output + '/diagnostic-client.log', client.map(r => FUNDRAISING_DIAGNOSTIC_PREFIX + JSON.stringify(r)).join('\n') + '\n', { mode: 0o600 });
 writeFileSync(output + '/diagnostic-results.json', JSON.stringify({ classification: 'LOCAL APPLICATION VERIFIED', assertions: checks, client_records: client.length, read_correlation: read.correlation_id, denied_correlation: denial.correlation, client_errors: errors }, null, 2) + '\n', { mode: 0o600 });
 console.info(JSON.stringify({ passed: checks.length, client_records: client.length, client_errors: errors }));
} finally { await browser.close(); }
