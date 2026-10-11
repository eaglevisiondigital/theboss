// Test-only transport. Never imported by production code or a deployment.
// Enforce a private disposable socket and block all non-loopback networking.
import {execFileSync} from 'node:child_process';
if(!/^\/tmp\/boss-db-test\.[^/]+\/socket$/.test(process.env.BOSS_GROUP_TEST_SOCKET??''))throw new Error('Disposable socket required');
const nativeFetch=globalThis.fetch;
const rules={boss_fundraising_public:['path','offset_ordinal'],boss_discounts_catalog:['path'],boss_money_board_public:['path','after_ordinal'],boss_money_board_cart:['command','session_capability'],boss_money_board_candidate:['path','excluded']};
const quote=value=>"'"+String(value).replaceAll("'","''")+"'";
globalThis.fetch=async(input,init)=>{
 const url=new URL(typeof input==='string'?input:input instanceof URL?input.href:input.url);
 if(['localhost','127.0.0.1','[::1]'].includes(url.hostname))return nativeFetch(input,init);
 const name=url.pathname.split('/').at(-1);
 if(url.origin!=='https://ilykgwgmxtrrikreacrz.supabase.co'||!url.pathname.startsWith('/rest/v1/rpc/')||!Object.hasOwn(rules,name))throw new Error('Network blocked by disposable test transport');
 try{
  const args=JSON.parse(init?.body??await input.text());
  if(Object.keys(args).some(k=>!rules[name].includes(k)))throw new Error('Finite RPC arguments required');
  const named=Object.entries(args).map(([key,value])=>`${key}=>${Array.isArray(value)?`ARRAY[${value.map(quote).join(',')}]::uuid[]`:typeof value==='number'?String(value):typeof value==='object'?quote(JSON.stringify(value))+'::jsonb':quote(value)}`).join(',');
  const sql=`begin;set local role anon;set local request.jwt.claims='{}';select public.${name}(${named})::text;commit;`;
  const output=execFileSync(process.env.PG_BINDIR+'/psql',['-X','-qAt','-h',process.env.BOSS_GROUP_TEST_SOCKET,'-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose'],{input:sql,encoding:'utf8',stdio:['pipe','pipe','pipe']});
  return new Response(output.trim(),{status:200,headers:{'content-type':'application/json','cache-control':'private,no-store'}});
 }catch(error){const code=/ERROR:\s+([A-Z0-9]{5})/.exec(String(error.stderr??''))?.[1]??'TEST_FAILURE';return Response.json({code,message:'Local request unavailable'},{status:Number(code.slice(2))>=400&&Number(code.slice(2))<=599?Number(code.slice(2)):503});}
};
