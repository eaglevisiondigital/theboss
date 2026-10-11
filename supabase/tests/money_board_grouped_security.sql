\set ON_ERROR_STOP on
begin;set local statement_timeout='8s';
\ir phase7a/fixture.sql
\ir grouped/cart-helpers.sql
set local role anon;
select pg_temp.cart('open',repeat('a',64));
select pg_temp.cart('add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(1)));
select pg_temp.denied('wrong share path denied',format('select public.boss_money_board_cart(%L::jsonb,%L)',jsonb_build_object('action','read','request_id',gen_random_uuid(),'input',jsonb_build_object('path',repeat('c',48))),repeat('a',64)),'PT404');
select pg_temp.denied('forged tile denied',format('select pg_temp.cart(%L,%L,%L::jsonb)','add',repeat('a',64),jsonb_build_object('tile_id',gen_random_uuid())),'PT404');
select pg_temp.denied('caller cannot set canonical price',format('select pg_temp.cart(%L,%L,%L::jsonb)','add',repeat('a',64),jsonb_build_object('tile_id',pg_temp.tile(1),'amount_minor',1)),'PT422');
select pg_temp.denied('caller cannot set tenant or currency',format('select pg_temp.cart(%L,%L,%L::jsonb)','reserve',repeat('a',64),jsonb_build_object('currency','CAD','organization_id',pg_temp.f('other-org'))),'PT422');
select pg_temp.cart('reserve',repeat('a',64),'{}',pg_temp.f('fixed-cart-request'));
select pg_temp.denied('request payload conflict denied',format('select pg_temp.cart(%L,%L,%L::jsonb,%L::uuid)','cancel',repeat('a',64),'{}',pg_temp.f('fixed-cart-request')),'PT409');
select pg_temp.cart('cancel',repeat('a',64));
select pg_temp.check('cancel preserves selection and clears hold','CANCEL',pg_temp.cart('recover',repeat('a',64))->>'state'='canceled');
reset role;
select pg_temp.check('cancellation releases all lines','CANCEL',boss_private.money_board_tile_available(pg_temp.tile(1)));
select pg_temp.check('private full provenance','PROVENANCE',(select provenance->>'participant_id'=pg_temp.f('participant-child1')::text and provenance->>'person_id'=pg_temp.f('child1')::text and provenance->>'team_id'=pg_temp.f('falcons')::text from public.money_board_cart_items));
update public.guardian_relationships set can_manage_fundraising=false where guardian_person_id=pg_temp.f('parent');
set local role anon;
select pg_temp.denied('revoked guardian share invalidates cart','select pg_temp.cart(''recover'',repeat(''a'',64))','PT404');
reset role;
update public.guardian_relationships set can_manage_fundraising=true where guardian_person_id=pg_temp.f('parent');
set local role authenticated;select pg_temp.actor('parent');select pg_temp.cart('open',repeat('b',64));
select pg_temp.actor('household-only');
select pg_temp.denied('household-only cannot recover actor-bound cart','select pg_temp.cart(''recover'',repeat(''b'',64))','PT403');
select pg_temp.denied('non-platform cannot configure cart policy','select public.boss_money_board_policy(''{"action":"policy.configure","input":{"max_tiles":100,"max_total_minor":1000000000,"session_seconds":1800}}'')','PT403');
reset role;
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.denied('organization administrator potential is not platform policy authority','select public.boss_money_board_policy(''{"action":"policy.configure","input":{"max_tiles":100,"max_total_minor":1000000000,"session_seconds":1800}}'')','PT403');
reset role;
insert into public.role_assignments(person_id,role_id,scope_type,scope_id,organization_id,starts_at)select pg_temp.f('admin'),id,'platform',null,null,clock_timestamp()-interval'1 day'from public.roles where key='platform_administrator';
set local role authenticated;select pg_temp.actor('admin');
select pg_temp.check('platform policy configurable without rebuild','POLICY',public.boss_money_board_policy('{"action":"policy.configure","input":{"max_tiles":2,"max_total_minor":200,"session_seconds":1800}}')->>'max_tiles'='2');
reset role;
set local role anon;select pg_temp.cart('open',repeat('c',64));select pg_temp.cart('add',repeat('c',64),jsonb_build_object('tile_id',pg_temp.tile(1)));
select pg_temp.denied('aggregate amount cap enforced','select pg_temp.cart(''add'',repeat(''c'',64),jsonb_build_object(''tile_id'',pg_temp.tile(3)))','PT422');
select pg_temp.cart('add',repeat('c',64),jsonb_build_object('tile_id',pg_temp.tile(1)));
select pg_temp.check('repeated add count unchanged','LIMIT',jsonb_array_length(pg_temp.cart('recover',repeat('c',64))->'items')=1);
select pg_temp.denied('no browser paid command','select pg_temp.cart(''mark_paid'',repeat(''c'',64))','PT422');
reset role;
-- Fixed session deadline is enforced by SQL, independent of cookie/browser time.
insert into public.money_board_carts(organization_id,campaign_id,board_id,generation_id,fundraiser_id,path_digest,capability_digest,actor_person_id,currency,context,policy_revision,created_at,expires_at)
select organization_id,campaign_id,board_id,generation_id,fundraiser_id,path_digest,encode(sha256(convert_to(repeat('e',64),'UTF8')),'hex'),actor_person_id,currency,context,policy_revision,clock_timestamp()-interval'31 minutes',clock_timestamp()-interval'1 minute'from public.money_board_carts where capability_digest=encode(sha256(convert_to(repeat('a',64),'UTF8')),'hex');
set local role anon;
select pg_temp.denied('fixed expired cart cannot recover','select pg_temp.cart(''recover'',repeat(''e'',64))','PT404');
reset role;
select pg_temp.actor('admin');
select pg_temp.fm('board.configure',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board')),'title','Synthetic generation change','reservation_seconds',600,'visibility','public','start_minor',101,'increment_minor',100,'tile_count',50,'goal_minor',5000));
select pg_temp.fm('board.publish',jsonb_build_object('campaign_id',pg_temp.fid('campaign'),'board_id',pg_temp.fid('board'),'expected_version',(select version from public.money_boards where id=pg_temp.fid('board'))));
set local role anon;
select pg_temp.denied('old generation cart cannot recover','select pg_temp.cart(''recover'',repeat(''a'',64))','PT409');
reset role;
do $$declare t record;r text;begin for t in select oid,relname from pg_class where relnamespace='public'::regnamespace and relkind='r'and relname in('money_board_cart_policies','money_board_carts','money_board_cart_items','money_board_groups','money_board_group_items','money_board_checkout_preparations','money_board_group_commits','money_board_tile_claims','money_board_correction_plans','money_board_tile_corrections','money_board_cart_history')loop
 foreach r in array array['anon','authenticated','service_role','boss_payment_worker']loop perform pg_temp.check('raw closed '||t.relname||r,'ACL',not has_table_privilege(r,t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'));end loop;end loop;end$$;
select pg_temp.check('policy identity sequence is closed','ACL',not has_sequence_privilege('anon','public.money_board_cart_policies_revision_seq','USAGE,SELECT,UPDATE')and not has_sequence_privilege('authenticated','public.money_board_cart_policies_revision_seq','USAGE,SELECT,UPDATE'));
select pg_temp.check('public shims are invokers','ACL',not exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname like'boss_money_board_%'and prosecdef));
select pg_temp.check('empty search paths','ACL',not exists(select 1 from pg_proc where proname like'money_board_%'and not coalesce('search_path=""'=any(proconfig),false)));
set constraints all immediate;
select count(*)passed_assertions,'Grouped scope, actor, provenance and closed raw ACLs' suite from pg_temp.phase5a_assertions;
rollback;
