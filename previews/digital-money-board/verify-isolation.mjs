import assert from 'node:assert/strict';
import {readdir,readFile} from 'node:fs/promises';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
const root = new URL('./public/',import.meta.url);
async function walk(path) {
  const paths=[];
  for(const item of await readdir(path,{withFileTypes:true})) {
    const child=join(path,item.name);
    assert(!item.name.startsWith('.env') && !['functions','.netlify','node_modules'].includes(item.name),'Unexpected runtime/environment material in static artifact');
    if(item.isDirectory()) paths.push(...await walk(child)); else paths.push(child);
  }
  return paths;
}
const files=await walk(fileURLToPath(root));
for(const file of files.filter(path=>/\.(mjs|html|css)$/.test(path))) {
  const source=await readFile(file,'utf8');
  for(const forbidden of ['fetch(','XMLHttpRequest','WebSocket','localStorage','sessionStorage','document.cookie','supabase.co','thebossplatform.netlify.app','process.env','import.meta.env']) assert(!source.includes(forbidden),`Unexpected backend/persistence interface: ${file}`);
}
const headers=await readFile(new URL('_headers',root),'utf8');
for(const required of ["connect-src 'none'","form-action 'none'","frame-ancestors 'none'",'noindex','payment=()']) assert(headers.includes(required));
const page=await readFile(new URL('index.html',root),'utf8');
assert(page.includes('DEMO / PREVIEW')); assert(page.includes('noindex, nofollow, noarchive'));
assert(!page.includes('data-netlify')); assert(!page.includes('<form'));
assert.equal(files.length,13,'Only reviewed static files may ship');
console.log('PASS: reviewed static artifact, no backend/persistence/environment/function material, enforced isolation and noindex.');
