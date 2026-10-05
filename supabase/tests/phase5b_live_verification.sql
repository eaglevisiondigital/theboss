-- Canonical-compatible READ ONLY verifier. No fixture, DDL, DML or Auth read.
begin read only;
do $verify$
declare tables text[]:=array['game_basketball_states','game_basketball_events','game_basketball_lineups','game_basketball_lineup_history','game_basketball_finalizations','game_basketball_final_stats'];
 name text;client text;relation oid;fn record;passed integer:=0;unindexed text;flags jsonb;
begin
 if (select count(*) from public.roles)<>21 or(select count(*) from public.permissions)<>59 or(select count(*) from public.role_permissions)<>446 or(select count(*) from public.modules)<>14 then raise exception 'Basketball broadened approved catalogs';end if;passed:=passed+1;
 flags:=boss_private.games_configuration(null);
 if (select count(*) from jsonb_object_keys(flags-array['soccer_live_scoring','soccer_stats','soccer_play_by_play','soccer_lineups','football_live_scoring','football_stats','football_play_by_play','football_lineups','volleyball_live_scoring','volleyball_stats','volleyball_play_by_play','volleyball_lineups','baseball_live_scoring','baseball_stats','baseball_play_by_play','baseball_lineups','softball_live_scoring','softball_stats','softball_play_by_play','softball_lineups']))<>9 or flags->>'basketball_live_scoring'<>'false' or flags->>'basketball_stats'<>'false' or flags->>'basketball_play_by_play'<>'false' or flags->>'basketball_lineups'<>'false' then raise exception 'Finite Basketball features do not default off';end if;passed:=passed+1;
 if boss_private.games_feature(null,'basketball_live_scoring','{"game_center":true,"basketball_live_scoring":true}') or boss_private.games_feature(null,'basketball_stats','{"game_center":true,"basketball_stats":true}') then raise exception 'Absent live Sports module grants Basketball';end if;passed:=passed+1;
 foreach name in array tables loop
  relation:=to_regclass('public.'||name);
  if relation is null or not(select relrowsecurity from pg_class where oid=relation) then raise exception 'Basketball RLS table missing: %',name;end if;passed:=passed+1;
  if exists(select 1 from pg_policy where polrelid=relation) then raise exception 'Basketball raw policy opened: %',name;end if;passed:=passed+1;
  if exists(select 1 from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner)))a where c.oid=relation and a.grantee=0) then raise exception 'Basketball PUBLIC raw grant: %',name;end if;passed:=passed+1;
  foreach client in array array['anon','authenticated','service_role'] loop
   if has_table_privilege(client,relation,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') then raise exception 'Basketball raw role grant: % / %',name,client;end if;passed:=passed+1;
  end loop;
  if exists(select 1 from pg_index where indrelid=relation and(not indisvalid or not indisready)) then raise exception 'Basketball index incomplete: %',name;end if;passed:=passed+1;
  if exists(select 1 from pg_constraint where conrelid=relation and not convalidated) then raise exception 'Basketball constraint unvalidated: %',name;end if;passed:=passed+1;
 end loop;
 if not exists(select 1 from pg_constraint c join pg_index ix on ix.indexrelid=c.conindid join pg_attribute a on a.attrelid=c.conrelid and c.conkey=array[a.attnum]::smallint[]
 where c.conrelid='public.game_basketball_final_stats'::regclass and c.contype='p' and c.convalidated and ix.indisprimary and ix.indisvalid and ix.indisready
 and a.attname='id' and a.atttypid='uuid'::regtype and a.attnotnull and not a.attisdropped) then raise exception 'Basketball final stats lack a stable UUID primary key';end if;passed:=passed+1;
 select string_agg(c.conrelid::regclass::text||':'||c.conname,', ') into unindexed from pg_constraint c
 where c.contype='f' and c.conrelid in(select to_regclass('public.'||t) from unnest(tables)t)
 and not exists(select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and i.indpred is null and i.indexprs is null and i.indnkeyatts>=cardinality(c.conkey) and(i.indkey::smallint[])[0:cardinality(c.conkey)-1] @> c.conkey);
 if unindexed is not null then raise exception 'Unindexed Basketball foreign keys: %',unindexed;end if;passed:=passed+1;
 for fn in select p.*,p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'basketball_%' loop
  if not coalesce('search_path=""'=any(fn.proconfig),false) then raise exception 'Basketball helper search path differs: %',fn.signature;end if;passed:=passed+1;
  if exists(select 1 from aclexplode(coalesce(fn.proacl,acldefault('f',fn.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE') then raise exception 'Basketball PUBLIC helper grant: %',fn.signature;end if;passed:=passed+1;
  foreach client in array array['anon','authenticated','service_role'] loop
   if has_function_privilege(client,fn.oid,'EXECUTE') then raise exception 'Basketball helper client grant: % / %',fn.signature,client;end if;passed:=passed+1;
  end loop;
 end loop;
 foreach name in array array['game_basketball_events','game_basketball_lineup_history','game_basketball_finalizations','game_basketball_final_stats'] loop
  if not exists(select 1 from pg_trigger where tgrelid=('public.'||name)::regclass and tgfoid='boss_private.reject_audit_rewrite()'::regprocedure and tgenabled<>'D' and not tgisinternal and(tgtype & 8)<>0 and(tgtype & 16)<>0) then raise exception 'Basketball immutable row evidence missing: %',name;end if;passed:=passed+1;
  if not exists(select 1 from pg_trigger where tgrelid=('public.'||name)::regclass and tgfoid='boss_private.reject_audit_rewrite()'::regprocedure and tgenabled<>'D' and not tgisinternal and(tgtype & 32)<>0) then raise exception 'Basketball truncate guard missing: %',name;end if;passed:=passed+1;
 end loop;
 if exists(select 1 from public.game_basketball_states s join public.games g on g.id=s.game_id where g.sport_key<>'basketball' or s.organization_id<>g.organization_id or s.roster_revision<>g.roster_revision) then raise exception 'Basketball state identity/sport/snapshot mismatch';end if;passed:=passed+1;
 if exists(select 1 from public.game_basketball_events e join public.game_operations o on o.id=e.operation_id where e.game_id<>o.game_id or e.organization_id<>o.organization_id or e.sequence<>o.sequence or o.operation not like 'basketball.%') then raise exception 'Basketball typed evidence does not use canonical ledger';end if;passed:=passed+1;
 if exists(select 1 from public.game_basketball_finalizations b join public.game_finalizations seal on seal.id=b.finalization_id where b.game_id<>seal.game_id or b.epoch<>seal.epoch or b.organization_id<>seal.organization_id or b.roster_revision<>seal.roster_revision) then raise exception 'Basketball final seal identity mismatch';end if;passed:=passed+1;
 perform set_config('boss.phase5b_assertions',passed::text,true);
 raise notice 'Phase 5B read-only schema assertions passed: %',passed;
end $verify$;
select current_setting('boss.phase5b_assertions')::int as passed_assertions,'SCHEMA_READ_ONLY'::text as category;
select jsonb_build_object('status','PASS','read_only',current_setting('transaction_read_only')='on','passed_assertions',current_setting('boss.phase5b_assertions')::int,
 'basketball_tables',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname like 'game_basketball_%'),
 'basketball_helpers',(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'basketball_%'),
 'engine_states',(select count(*) from public.game_basketball_states),'typed_events',(select count(*) from public.game_basketball_events),'final_epochs',(select count(*) from public.game_basketball_finalizations))as phase5b_read_only_verification;
rollback;
