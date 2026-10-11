// Additional native public destination integration; synthetic local data only.
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url),{chromium}=require(process.env.BOSS_TEST_PLAYWRIGHT_MODULE??'playwright');
const socket=process.env.BOSS_GROUP_TEST_SOCKET,pgbin=process.env.PG_BINDIR,origin=process.env.BOSS_LOCAL_UI_ORIGIN,output=process.env.BOSS_TEST_OUTPUT;
if(!/^\/tmp\/boss-db-test\.[^/]+\/socket$/.test(socket??'')||!pgbin||!/^https:\/\/localhost:\d+$/.test(origin??'')||!output)throw Error('Private disposable environment required');
const query=sql=>execFileSync(pgbin+'/psql',['-X','-qAt','-h',socket,'-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-c',sql],{encoding:'utf8'}).trim();
const destinations=JSON.parse(query("select json_agg(json_build_object('kind',kind,'path',public_path))from public.fundraising_destinations where status='published'and campaign_id in(select id from public.fundraising_campaigns where name='Synthetic ministry native acceptance')"));
const ministry=destinations.find(d=>d.kind==='ministry'),organization=destinations.find(d=>d.kind==='organization');
assert(ministry&&organization);
const browser=await chromium.launch({headless:true,executablePath:process.env.BOSS_TEST_BROWSER_EXECUTABLE}),results={scope:'LOCAL APPLICATION VERIFIED; native organization/ministry destinations without Sports/Wallet',assertions:[],viewports:[],client_errors:0};
const passed=label=>results.assertions.push(label);
try{
 const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1280,height:1000}}),page=await context.newPage();
 await context.route('**/*',route=>{const host=new URL(route.request().url()).hostname;return ['localhost','127.0.0.1','[::1]'].includes(host)?route.continue():route.abort();});
 page.on('pageerror',()=>results.client_errors++);
 await page.goto(`${origin}/fundraise/${ministry.path}`,{waitUntil:'networkidle'});await page.locator('.tile:not([disabled])').first().waitFor();assert.equal(await page.locator('.tiles .tile').count(),50);passed('native ministry server/client rendering without Sports or Wallet');
 await page.locator('[data-ordinal="1"]').click();await page.locator('.cart-total-row strong').filter({hasText:'$1.00'}).waitFor();await page.reload({waitUntil:'networkidle'});await page.locator('.cart-total-row strong').filter({hasText:'$1.00'}).waitFor();passed('ministry canonical selection survives full reload');
 const body=await page.locator('body').textContent();assert(body.includes('$7,000'));assert(!body.includes(query("select md5('boss-phase7a-test:admin')::uuid")));passed('ministry goal and privacy projection render safely');
 for(const width of [1440,1280,768,390,320]){await page.setViewportSize({width,height:1000});const metrics=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));assert.equal(metrics.width,width);assert(metrics.scroll<=width);results.viewports.push(metrics);await page.screenshot({path:`${output}/ministry-${width}.png`,fullPage:true});}passed('five measured ministry viewports without horizontal overflow');
 await page.setViewportSize({width:1280,height:1000});await page.getByRole('button',{name:'Clear cart',exact:true}).click();await page.locator('.cart-total-row strong').filter({hasText:'$0.00'}).waitFor();
 await page.goto(`${origin}/fundraise/${organization.path}`,{waitUntil:'networkidle'});await page.getByRole('heading',{name:'Synthetic ministry native acceptance',exact:true}).waitFor();assert.equal(await page.locator('.tiles .tile').count(),0);await page.reload({waitUntil:'networkidle'});await page.getByRole('heading',{name:'Synthetic ministry native acceptance',exact:true}).waitFor();passed('organization-only native page and reload do not inherit ministry board');
 assert.equal(results.client_errors,0);passed('no organization/ministry hydration or client exceptions');
 writeFileSync(output+'/destination-results.json',JSON.stringify(results,null,2),{mode:0o600});console.log(JSON.stringify({additional_native_checks:results.assertions.length,viewports:results.viewports.map(v=>v.width),client_errors:results.client_errors}));
}finally{await browser.close();}
