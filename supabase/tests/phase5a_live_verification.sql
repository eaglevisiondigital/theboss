-- Phase 5A read-only canonical/local schema verification.
-- No fixtures, DDL, DML, role changes, Auth reads or credential/session values.
-- Run after all three Phase 5A migrations. Any failed invariant raises an error.
begin read only;
do $verify$
declare
 expected_tables text[]:=array['public.game_sports','public.games','public.game_roster_snapshots','public.game_operator_assignments','public.game_operations','public.game_finalizations','boss_private.game_operation_receipts'];
 game_keys text[]:=array['games.correct','games.create','games.finalize','games.manage','games.operate','games.publish','games.view'];
 table_name text;client text;role_key text;actual text[];expected text[];relation oid;fn record;passed integer:=0;unindexed text;
begin
 if (select count(*) from public.roles)<>21 or (select count(*) from public.modules)<>14
 or (select count(*) from public.permissions)<>59 or (select count(*) from public.role_permissions)<>446
 then raise exception 'Phase 5A catalog counts differ from reviewed foundation';end if;passed:=passed+1;
 if not exists(select 1 from pg_catalog.pg_attribute where attrelid='public.organization_modules'::regclass and attname='version' and atttypid='bigint'::regtype and attnotnull and not attisdropped) then raise exception 'Monotonic module revision metadata missing';end if;passed:=passed+1;
 if exists(select 1 from public.organization_modules where version<=0) then raise exception 'Invalid module revision';end if;passed:=passed+1;
 if not exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.organization_modules'::regclass and tgname='games_module_revision' and tgenabled<>'D' and tgfoid='boss_private.games_module_version()'::regprocedure) then raise exception 'Monotonic module revision trigger missing';end if;passed:=passed+1;
 if (select array_agg(key order by key) from public.permissions where key like 'games.%') is distinct from game_keys then raise exception 'Game permission catalog differs';end if;passed:=passed+1;
 if (select array_agg(key order by key) from public.game_sports where status='active') is distinct from array['baseball','basketball','football','soccer','softball','volleyball']::text[]
 or (select count(*) from public.game_sports)<>6 then raise exception 'Explicit six-sport catalog differs';end if;passed:=passed+1;
 for role_key in select key from public.roles order by key loop
 expected:=case
 when role_key in('super_administrator','platform_administrator','organization_owner','organization_administrator') then game_keys
 when role_key='athletic_director' then array['games.correct','games.create','games.finalize','games.manage','games.operate','games.view']
 when role_key in('program_administrator','sport_administrator') then array['games.create','games.finalize','games.manage','games.operate','games.view']
 when role_key in('team_administrator','head_coach') then array['games.manage','games.view']
 when role_key='scorekeeper' then array['games.operate','games.view']
 when role_key in('assistant_coach','team_staff','livestream_operator') then array['games.view']
 else array[]::text[] end;
 select coalesce(array_agg(permission.key order by permission.key),array[]::text[]) into actual
 from public.roles role join public.role_permissions mapping on mapping.role_id=role.id join public.permissions permission on permission.id=mapping.permission_id
 where role.key=role_key and permission.key like 'games.%';
 if actual is distinct from expected then raise exception 'Reviewed Game Center mapping differs for %',role_key;end if;passed:=passed+1;
 end loop;
 foreach table_name in array expected_tables loop
 relation:=to_regclass(table_name);
 if relation is null or not(select relrowsecurity from pg_catalog.pg_class where oid=relation) then raise exception 'Closed RLS table missing: %',table_name;end if;passed:=passed+1;
 if exists(select 1 from pg_catalog.pg_policy where polrelid=relation) then raise exception 'Raw Game Center table policy unexpectedly opened: %',table_name;end if;passed:=passed+1;
 if exists(select 1 from pg_catalog.pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl where c.oid=relation and acl.grantee=0) then raise exception 'PUBLIC raw grant opened: %',table_name;end if;passed:=passed+1;
 foreach client in array array['anon','authenticated','service_role'] loop
 if has_table_privilege(client,relation,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') then raise exception 'Raw client grant opened: % / %',table_name,client;end if;passed:=passed+1;
 end loop;
 if exists(select 1 from pg_catalog.pg_index where indrelid=relation and(not indisvalid or not indisready)) then raise exception 'Invalid or unfinished game index: %',table_name;end if;passed:=passed+1;
 if exists(select 1 from pg_catalog.pg_constraint where conrelid=relation and not convalidated) then raise exception 'Unvalidated game constraint: %',table_name;end if;passed:=passed+1;
 end loop;
 select string_agg(constraint_row.conrelid::regclass::text||':'||constraint_row.conname,', ' order by constraint_row.conrelid::regclass::text,constraint_row.conname) into unindexed
 from pg_catalog.pg_constraint constraint_row
 where constraint_row.contype='f' and constraint_row.conrelid in(select to_regclass(name) from unnest(expected_tables) name)
 and not exists(select 1 from pg_catalog.pg_index supporting where supporting.indrelid=constraint_row.conrelid and supporting.indisvalid and supporting.indpred is null and supporting.indexprs is null
 and supporting.indnkeyatts>=cardinality(constraint_row.conkey) and(supporting.indkey::smallint[])[0:cardinality(constraint_row.conkey)-1] @> constraint_row.conkey);
 if unindexed is not null then raise exception 'Unindexed Game Center foreign keys: %',unindexed;end if;passed:=passed+1;
 if (select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('boss_games_read','boss_games_mutate'))<>2 then raise exception 'Expected two Game Center entry RPCs';end if;passed:=passed+1;
 for fn in select p.*,n.nspname,p.oid::regprocedure signature from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='boss_private' and p.proname like 'games_%') or(n.nspname='public' and p.proname in('boss_games_read','boss_games_mutate')) loop
 if not coalesce('search_path=""'=any(fn.proconfig),false) then raise exception 'Game function search path differs: %',fn.signature;end if;passed:=passed+1;
 if exists(select 1 from aclexplode(coalesce(fn.proacl,acldefault('f',fn.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')
 or has_function_privilege('anon',fn.oid,'EXECUTE') or has_function_privilege('service_role',fn.oid,'EXECUTE') then raise exception 'Public/anonymous/service function grant opened: %',fn.signature;end if;passed:=passed+1;
 if fn.nspname='public' then
 if fn.prosecdef or not has_function_privilege('authenticated',fn.oid,'EXECUTE') then raise exception 'Invoker RPC authentication boundary differs: %',fn.signature;end if;
 elsif not fn.prosecdef or has_function_privilege('authenticated',fn.oid,'EXECUTE')<>(fn.proname in('games_read','games_mutate')) then
 -- Pure finite validation/state/lifecycle helpers may be invoker functions;
 -- they remain private and have no client EXECUTE grants.
 if fn.proname not in('games_validate','games_transition_valid','games_core_state') or fn.prosecdef or has_function_privilege('authenticated',fn.oid,'EXECUTE') then raise exception 'Private Game Center helper boundary differs: %',fn.signature;end if;
 end if;passed:=passed+1;
 end loop;
 if exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname in('calendar_command','calendar_command_phase4b','notification_source_visible','notification_source_visible_phase4b','notification_candidates','notification_candidates_phase4b','notification_contexts','notification_contexts_phase4b','notification_destination','notification_destination_phase4b')
 and(not p.prosecdef or not coalesce('search_path=""'=any(p.proconfig),false) or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE')
 or exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE'))) then raise exception 'Calendar/Notification wrapper boundary differs';end if;passed:=passed+1;
 if (select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private' and p.proname in('calendar_command','calendar_command_phase4b','notification_source_visible','notification_source_visible_phase4b','notification_candidates','notification_candidates_phase4b','notification_contexts','notification_contexts_phase4b','notification_destination','notification_destination_phase4b'))<>10 then raise exception 'Historical wrapper inventory differs';end if;passed:=passed+1;
 foreach table_name in array array['game_roster_snapshots','game_operations','game_finalizations'] loop
 if not exists(select 1 from pg_catalog.pg_trigger where tgrelid=('public.'||table_name)::regclass and tgname=table_name||'_immutable' and tgenabled<>'D' and tgfoid='boss_private.reject_audit_rewrite()'::regprocedure)
 or not exists(select 1 from pg_catalog.pg_trigger where tgrelid=('public.'||table_name)::regclass and tgname=table_name||'_no_truncate' and tgenabled<>'D' and tgfoid='boss_private.reject_audit_rewrite()'::regprocedure) then raise exception 'Immutable history triggers differ: %',table_name;end if;passed:=passed+1;
 end loop;
 if not exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.games'::regclass and tgname='games_identity' and tgenabled<>'D')
 or not exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.game_operator_assignments'::regclass and tgname='game_operator_identity' and tgenabled<>'D')
 or not exists(select 1 from pg_catalog.pg_trigger where tgrelid='public.game_operations'::regclass and tgname='game_notification_source' and tgenabled<>'D') then raise exception 'Identity/notification source triggers differ';end if;passed:=passed+1;
 if not exists(select 1 from pg_catalog.pg_index where indexrelid='public.games_single_event_idx'::regclass and indisunique and indpred is not null)
 or not exists(select 1 from pg_catalog.pg_index where indexrelid='public.game_operation_reversal_idx'::regclass and indisunique and indpred is not null) then raise exception 'Single-event/reversal uniqueness differs';end if;passed:=passed+1;
 if boss_private.games_configuration(null)-array['basketball_live_scoring','basketball_stats','basketball_play_by_play','basketball_lineups','soccer_live_scoring','soccer_stats','soccer_play_by_play','soccer_lineups','football_live_scoring','football_stats','football_play_by_play','football_lineups','volleyball_live_scoring','volleyball_stats','volleyball_play_by_play','volleyball_lineups','baseball_live_scoring','baseball_stats','baseball_play_by_play','baseball_lineups','softball_live_scoring','softball_stats','softball_play_by_play','softball_lineups'] is distinct from '{"game_center":false,"game_operations":false,"public_game_center":false,"team_game_management":false,"head_coach_game_management":false}'::jsonb
 or boss_private.games_feature(null,'livestream','{"game_center":true,"livestream":true}') then raise exception 'Finite default-off feature configuration differs';end if;passed:=passed+1;
 if (select array_agg(key order by key) from boss_private.notification_types where key like 'game.%' and key<>'game.halftime') is distinct from array['game.canceled','game.delayed','game.final','game.operator_assigned','game.started']::text[] then raise exception 'Low-volume historical game notification catalog differs';end if;passed:=passed+1;
 if not exists(select 1 from pg_catalog.pg_constraint where conrelid='public.notification_events'::regclass and conname='notification_events_source_module_check' and pg_get_constraintdef(oid) like '%sports%')
 or not exists(select 1 from pg_catalog.pg_constraint where conrelid='public.notification_events'::regclass and conname='notification_events_source_type_check' and pg_get_constraintdef(oid) like '%game_operation%') then raise exception 'Notification source extension differs';end if;passed:=passed+1;
 if (select count(*) from unnest(array['scheduled','pregame','live','paused','delayed','suspended','final','canceled','postponed','abandoned']) source cross join unnest(array['scheduled','pregame','live','paused','delayed','suspended','final','canceled','postponed','abandoned']) destination where boss_private.games_transition_valid(source,destination))<>27
 or boss_private.games_transition_valid('scheduled','live') or boss_private.games_transition_valid('final','live') or boss_private.games_transition_valid('canceled','live') or boss_private.games_transition_valid('unknown','live') then raise exception 'Finite lifecycle/explicit start/final reopen boundary differs';end if;passed:=passed+1;
 raise notice 'Phase 5A read-only schema assertions passed: %',passed;
end $verify$;

-- The DO block performs 96 fixed/role/table checks plus three checks per
-- inventoried Game Center function. Match the local harness summary contract.
select 96+3*count(*) as passed_assertions,'SCHEMA_READ_ONLY'::text as category
from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
where(n.nspname='boss_private' and p.proname like 'games_%') or(n.nspname='public' and p.proname in('boss_games_read','boss_games_mutate'));

-- Safe aggregate inventory only. No person, account, Auth, document or game IDs.
select jsonb_build_object(
 'status','PASS','read_only',current_setting('transaction_read_only')='on',
 'passed_assertions',(select 96+3*count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where(n.nspname='boss_private' and p.proname like 'games_%') or(n.nspname='public' and p.proname in('boss_games_read','boss_games_mutate'))),
 'catalog_counts',jsonb_build_object('roles',(select count(*) from public.roles),'permissions',(select count(*) from public.permissions),'role_permissions',(select count(*) from public.role_permissions),'modules',(select count(*) from public.modules)),
 'sports',(select jsonb_agg(jsonb_build_object('key',key,'status',status) order by key) from public.game_sports),
 'closed_tables',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,'rls',c.relrowsecurity,'policies',(select count(*) from pg_catalog.pg_policy where polrelid=c.oid),'indexes',(select count(*) from pg_catalog.pg_index where indrelid=c.oid),'foreign_keys',(select count(*) from pg_catalog.pg_constraint where conrelid=c.oid and contype='f')) order by n.nspname,c.relname) from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where (n.nspname='public' and c.relname in('game_sports','games','game_roster_snapshots','game_operator_assignments','game_operations','game_finalizations')) or(n.nspname='boss_private' and c.relname='game_operation_receipts')),
 'functions',(select jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'security_definer',p.prosecdef,'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE'),'anonymous_execute',has_function_privilege('anon',p.oid,'EXECUTE'),'service_execute',has_function_privilege('service_role',p.oid,'EXECUTE'),'configuration',p.proconfig) order by n.nspname,p.proname,p.oid) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where(n.nspname='boss_private' and p.proname like 'games_%') or(n.nspname='public' and p.proname in('boss_games_read','boss_games_mutate'))),
 'indexes',(select jsonb_agg(jsonb_build_object('table',relation.relname,'index',catalog.relname,'valid',index.indisvalid,'ready',index.indisready,'unique',index.indisunique,'definition',pg_get_indexdef(index.indexrelid)) order by relation.relname,catalog.relname) from pg_catalog.pg_index index join pg_catalog.pg_class relation on relation.oid=index.indrelid join pg_catalog.pg_namespace namespace on namespace.oid=relation.relnamespace join pg_catalog.pg_class catalog on catalog.oid=index.indexrelid where(namespace.nspname='public' and relation.relname in('game_sports','games','game_roster_snapshots','game_operator_assignments','game_operations','game_finalizations')) or(namespace.nspname='boss_private' and relation.relname='game_operation_receipts')),
 'lifecycle_transitions',(select jsonb_object_agg(source,destinations) from(select source,jsonb_agg(destination order by destination) destinations from unnest(array['scheduled','pregame','live','paused','delayed','suspended','final','canceled','postponed','abandoned']) source cross join unnest(array['scheduled','pregame','live','paused','delayed','suspended','final','canceled','postponed','abandoned']) destination where boss_private.games_transition_valid(source,destination) group by source) matrix),
 'game_status_counts',(select coalesce(jsonb_object_agg(status,total),'{}'::jsonb) from(select status,count(*) total from public.games group by status) totals),
 'operator_counts',jsonb_build_object('total',(select count(*) from public.game_operator_assignments),'active_in_window',(select count(*) from public.game_operator_assignments where status='active' and starts_at<=clock_timestamp() and ends_at>clock_timestamp())),
 'history_counts',jsonb_build_object('roster_rows',(select count(*) from public.game_roster_snapshots),'operations',(select count(*) from public.game_operations),'finalizations',(select count(*) from public.game_finalizations)),
 'notification_types',(select jsonb_agg(key order by key) from boss_private.notification_types where key like 'game.%')
) as phase5a_read_only_verification;
rollback;
