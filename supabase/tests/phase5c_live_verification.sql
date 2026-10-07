-- Canonical-compatible READ ONLY verifier. No fixture, DDL, DML or Auth read.
begin read only;
do $verify$
declare tables text[]:=array['game_soccer_states','game_soccer_events','game_soccer_lineups','game_soccer_finalizations','game_soccer_final_stats'];
 name text;client text;relation oid;fn record;passed integer:=0;unindexed text;flags jsonb;
begin
 if (select count(*) from public.roles where key<>'competition_manager')<>21 or(select count(*) from public.permissions where key not in('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage'))<>59 or(select count(*) from public.role_permissions where permission_id not in(select id from public.permissions where key in('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage')))<>446 or(select count(*) from public.modules)<>14 then raise exception 'Soccer broadened approved catalogs';end if;passed:=passed+1;
 if (select array_agg(c.relname::text order by c.relname)from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relkind='r'and c.relname like 'game_soccer_%')is distinct from(select array_agg(t order by t)from unnest(tables)t)then raise exception 'Exact five Soccer raw tables differ';end if;passed:=passed+1;
 flags:=boss_private.games_configuration(null);
 if flags-array['football_live_scoring','football_stats','football_play_by_play','football_lineups','volleyball_live_scoring','volleyball_stats','volleyball_play_by_play','volleyball_lineups','baseball_live_scoring','baseball_stats','baseball_play_by_play','baseball_lineups','softball_live_scoring','softball_stats','softball_play_by_play','softball_lineups'] is distinct from '{"game_center":false,"game_operations":false,"public_game_center":false,"team_game_management":false,"head_coach_game_management":false,"basketball_live_scoring":false,"basketball_stats":false,"basketball_play_by_play":false,"basketball_lineups":false,"soccer_live_scoring":false,"soccer_stats":false,"soccer_play_by_play":false,"soccer_lineups":false}'::jsonb then raise exception 'Finite Soccer features do not default off';end if;passed:=passed+1;
 if boss_private.games_feature(null,'soccer_live_scoring','{"game_center":true,"soccer_live_scoring":true}') or boss_private.games_feature(null,'soccer_stats','{"game_center":true,"soccer_stats":true}') then raise exception 'Absent live Sports module grants Soccer';end if;passed:=passed+1;
 foreach name in array tables loop
  relation:=to_regclass('public.'||name);
  if relation is null or not(select relrowsecurity from pg_class where oid=relation) then raise exception 'Soccer RLS table missing: %',name;end if;passed:=passed+1;
  if exists(select 1 from pg_policy where polrelid=relation) then raise exception 'Soccer raw policy opened: %',name;end if;passed:=passed+1;
  if exists(select 1 from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner)))a where c.oid=relation and a.grantee=0) then raise exception 'Soccer PUBLIC raw grant: %',name;end if;passed:=passed+1;
  foreach client in array array['anon','authenticated','service_role'] loop
   if has_table_privilege(client,relation,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') then raise exception 'Soccer raw role grant: % / %',name,client;end if;passed:=passed+1;
  end loop;
  if exists(select 1 from pg_index where indrelid=relation and(not indisvalid or not indisready)) then raise exception 'Soccer index incomplete: %',name;end if;passed:=passed+1;
  if exists(select 1 from pg_constraint where conrelid=relation and not convalidated) then raise exception 'Soccer constraint unvalidated: %',name;end if;passed:=passed+1;
 end loop;
 if not exists(select 1 from pg_constraint c join pg_index ix on ix.indexrelid=c.conindid join pg_attribute a on a.attrelid=c.conrelid and c.conkey=array[a.attnum]::smallint[]
 where c.conrelid='public.game_soccer_final_stats'::regclass and c.contype='p' and c.convalidated and ix.indisprimary and ix.indisvalid and ix.indisready
 and a.attname='id' and a.atttypid='uuid'::regtype and a.attnotnull and not a.attisdropped) then raise exception 'Soccer final stats lack a stable UUID primary key';end if;passed:=passed+1;
 select string_agg(c.conrelid::regclass::text||':'||c.conname,', ') into unindexed from pg_constraint c
 where c.contype='f' and c.conrelid in(select to_regclass('public.'||t) from unnest(tables)t)
 and not exists(select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and i.indpred is null and i.indexprs is null and i.indnkeyatts>=cardinality(c.conkey) and(i.indkey::smallint[])[0:cardinality(c.conkey)-1] @> c.conkey);
 if unindexed is not null then raise exception 'Unindexed Soccer foreign keys: %',unindexed;end if;passed:=passed+1;
 for fn in select p.*,p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'soccer_%' loop
  if not coalesce('search_path=""'=any(fn.proconfig),false) then raise exception 'Soccer helper search path differs: %',fn.signature;end if;passed:=passed+1;
  if exists(select 1 from aclexplode(coalesce(fn.proacl,acldefault('f',fn.proowner)))a where a.grantee=0 and a.privilege_type='EXECUTE') then raise exception 'Soccer PUBLIC helper grant: %',fn.signature;end if;passed:=passed+1;
  foreach client in array array['anon','authenticated','service_role'] loop
   if has_function_privilege(client,fn.oid,'EXECUTE') then raise exception 'Soccer helper client grant: % / %',fn.signature,client;end if;passed:=passed+1;
  end loop;
 end loop;
 foreach name in array array['game_soccer_events','game_soccer_finalizations','game_soccer_final_stats'] loop
  if not exists(select 1 from pg_trigger where tgrelid=('public.'||name)::regclass and tgfoid='boss_private.reject_audit_rewrite()'::regprocedure and tgenabled<>'D' and not tgisinternal and(tgtype & 8)<>0 and(tgtype & 16)<>0) then raise exception 'Soccer immutable row evidence missing: %',name;end if;passed:=passed+1;
  if not exists(select 1 from pg_trigger where tgrelid=('public.'||name)::regclass and tgfoid='boss_private.reject_audit_rewrite()'::regprocedure and tgenabled<>'D' and not tgisinternal and(tgtype & 32)<>0) then raise exception 'Soccer truncate guard missing: %',name;end if;passed:=passed+1;
 end loop;
 if exists(select 1 from public.game_soccer_states s join public.games g on g.id=s.game_id where g.sport_key<>'soccer' or s.organization_id<>g.organization_id or s.roster_revision<>g.roster_revision) then raise exception 'Soccer state identity/sport/snapshot mismatch';end if;passed:=passed+1;
 if exists(select 1 from public.game_soccer_events e join public.game_operations o on o.id=e.operation_id where e.game_id<>o.game_id or e.organization_id<>o.organization_id or e.sequence<>o.sequence or o.operation not like 'soccer.%') then raise exception 'Soccer typed evidence does not use canonical ledger';end if;passed:=passed+1;
 if exists(select 1 from public.game_soccer_finalizations b join public.game_finalizations seal on seal.id=b.finalization_id where b.game_id<>seal.game_id or b.epoch<>seal.epoch or b.organization_id<>seal.organization_id or b.roster_revision<>seal.roster_revision) then raise exception 'Soccer final seal identity mismatch';end if;passed:=passed+1;
 perform set_config('boss.phase5c_assertions',passed::text,true);
 raise notice 'Phase 5C read-only schema assertions passed: %',passed;
end $verify$;
select current_setting('boss.phase5c_assertions')::int as passed_assertions,'SCHEMA_READ_ONLY'::text as category;
select jsonb_build_object('status','PASS','read_only',current_setting('transaction_read_only')='on','passed_assertions',current_setting('boss.phase5c_assertions')::int,
 'soccer_tables',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relname like 'game_soccer_%'),
 'soccer_helpers',(select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname like 'soccer_%'),
 'engine_states',(select count(*) from public.game_soccer_states),'typed_events',(select count(*) from public.game_soccer_events),'final_epochs',(select count(*) from public.game_soccer_finalizations))as phase5c_read_only_verification;
rollback;
