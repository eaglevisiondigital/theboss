-- Catalog metadata and deterministic TypeScript projection, read-only.
with columns as (
 select c.relname table_name,a.attname column_name,a.attnum position,t.typname pg_type,
 not a.attnotnull nullable,
 case t.typname when 'uuid' then 'string' when 'text' then 'string' when 'timestamptz' then 'string'
 when 'bool' then 'boolean' when 'int2' then 'number' when 'int4' then 'number' when 'int8' then 'number'
 when 'numeric' then 'number' when 'jsonb' then 'Json' when '_text' then 'string[]' else 'unknown' end ts_type
 from pg_class c join pg_attribute a on a.attrelid=c.oid join pg_type t on t.oid=a.atttypid
 where c.relnamespace='public'::regnamespace and c.relkind='r' and c.relname like 'partner_%'
 and a.attnum>0 and not a.attisdropped
), tables as (
 select table_name,jsonb_agg(jsonb_build_object('name',column_name,'type',pg_type,'nullable',nullable) order by position) metadata,
 ' '||table_name||E': {\n'||string_agg('  '||column_name||': '||ts_type||case when nullable then ' | null' else '' end||';',E'\n' order by position)||E'\n };' ts
 from columns group by table_name
), functions as (
 select p.proname name,coalesce(p.proargnames,'{}') names,
 jsonb_build_object('name',p.proname,'argument_names',coalesce(p.proargnames,'{}'),
 'argument_types',coalesce((select jsonb_agg(format_type(arg,null) order by ord) from unnest(p.proargtypes::oid[]) with ordinality a(arg,ord)),'[]'::jsonb),
 'argument_modes',coalesce(p.proargmodes,'{}'),'default_arguments',p.pronargdefaults,
 'return_type',format_type(p.prorettype,null),'returns_set',p.proretset,'kind',p.prokind) metadata,
 ' '||p.proname||': { Args: '||case when cardinality(p.proargnames)>0 then '{ '||
 (select string_agg(n||': '||case format_type(typ,null) when 'jsonb' then 'Json' else 'unknown' end,', ' order by ord)
 from unnest(p.proargnames,p.proargtypes::oid[]) with ordinality a(n,typ,ord))||' }' else 'Record<string, never>' end||
 '; Returns: '||case format_type(p.prorettype,null) when 'jsonb' then 'Json' else 'unknown' end||' };' ts
 from pg_proc p where p.pronamespace='public'::regnamespace and p.proname like 'boss_partners_%'
)
select jsonb_build_object('tables',(select jsonb_agg(jsonb_build_object('name',table_name,'columns',metadata) order by table_name) from tables),
 'functions',(select jsonb_agg(metadata order by name) from functions))::text||E'\n-- TYPESCRIPT CONTRACT --\n'||
 E'// Supplemental schema probe generated from disposable PostgreSQL; application RPCs use canonical Database types.\nimport type { Json } from "../supabase/database.types";\nexport type PartnerFoundationTables = {\n'||
 (select string_agg(ts,E'\n' order by table_name) from tables)||E'\n};\nexport type PartnerFoundationFunctions = {\n'||
 (select string_agg(ts,E'\n' order by name) from functions)||E'\n};';
