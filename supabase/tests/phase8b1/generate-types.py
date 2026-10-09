from pathlib import Path
import json,sys
m=json.load(sys.stdin)
def typ(t):
 if t.startswith('_'):return typ(t[1:])+'[]'
 return {'uuid':'string','text':'string','timestamptz':'string','bool':'boolean','int2':'number','int4':'number','int8':'number','jsonb':'Json','numeric':'number'}.get(t,'unknown')
lines=['// Supplemental schema probe generated from disposable PostgreSQL; application RPCs use canonical Database types.','import type { Json } from "../supabase/database.types";','export type PartnerFoundationTables = {']
for table in m['tables']:
 lines.append(' '+table['name']+': {')
 for c in table['columns']:lines.append('  '+c['name']+': '+typ(c['type'])+(' | null' if c['nullable']else'')+';')
 lines.append(' };')
lines+=['};','export type PartnerFoundationFunctions = {']
for f in m['functions']:
 args=', '.join(n+': Json'for n in f['args'])
 lines.append(' '+f['name']+': { Args: '+('{ '+args+' }'if args else'Record<string, never>')+'; Returns: Json };')
lines+=['};','']
p=Path(__file__).resolve().parents[3]/'apps/platform/src/lib/partners/database.types.ts'
generated='\n'.join(lines)
if '--write' in sys.argv:
 p.write_text(generated)
elif not p.exists() or p.read_text()!=generated:
 raise SystemExit('Local partner types differ from the disposable schema; explicitly regenerate before release.')
print('Verified local partner table/RPC types:',len(m['tables']),'tables;',len(m['functions']),'functions')
