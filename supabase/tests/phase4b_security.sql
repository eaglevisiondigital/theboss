-- Independent Phase 4B potential-capability matrix and raw API boundary.
BEGIN;
CREATE TEMP TABLE phase4b_security_assertions(label text PRIMARY KEY) ON COMMIT DROP;
CREATE FUNCTION pg_temp.check(label text,ok boolean) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL Phase4B security %',label;END IF;
 INSERT INTO pg_temp.phase4b_security_assertions VALUES(label);
END $$;
DO $$
DECLARE role_key text;expected text[];actual text[];tab record;fn record;client_role text;
 keys text[]:=ARRAY['attendance.checkin','attendance.manage','attendance.respond','attendance.view','volunteers.assign','volunteers.manage','volunteers.signup','volunteers.view'];
BEGIN
 PERFORM pg_temp.check('exact evolved catalogs',
  (SELECT count(*)=21 FROM public.roles WHERE key <> 'competition_manager') AND (SELECT count(*)=52 FROM public.permissions WHERE key NOT LIKE 'games.%' AND key NOT IN ('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage'))
  AND (SELECT count(*)=393 FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT LIKE 'games.%' AND p.key NOT IN ('competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage','boss_bucks.view','boss_bucks.manage','boss_bucks.financial_view','boss_bucks.policy_manage'))
  AND (SELECT count(*)=73 FROM pg_catalog.pg_tables WHERE schemaname='public' AND tablename NOT IN ('boss_bucks_wallets','boss_bucks_access','boss_bucks_policy_revisions','boss_bucks_fundraiser_bindings','boss_bucks_source_snapshots','boss_bucks_owner_resolutions','boss_bucks_accounts','boss_bucks_grants','boss_bucks_journals','boss_bucks_postings','boss_bucks_history','fundraising_campaigns','fundraising_targets','fundraising_fundraisers','fundraising_shares','money_boards','money_board_generations','money_board_tiles','fundraising_donors','money_board_reservations','fundraising_intents','fundraising_intent_events','fundraising_success_evidence','fundraising_recurring_commitments','fundraising_recurring_occurrences','fundraising_reward_qualifications','fundraising_history') AND tablename NOT IN ('competitions','competition_editions','competition_groups','competition_entries','competition_entry_groups','competition_access_assignments','standings_policy_revisions','competition_game_assignments','competition_game_assignment_groups','competition_rulings','ranking_definitions','ranking_scopes','standings_rows','ranking_candidates','record_events','record_current_holders','ranking_refresh_work','tournament_stages','tournament_brackets','tournament_bracket_revisions','tournament_seeds','tournament_matches','tournament_advancements','tournament_rulings') AND tablename NOT IN ('game_sports','games','game_roster_snapshots','game_operator_assignments','game_operations','game_finalizations') AND tablename NOT IN ('game_basketball_states','game_basketball_events','game_basketball_lineups','game_basketball_lineup_history','game_basketball_finalizations','game_basketball_final_stats') AND tablename NOT IN ('game_soccer_states','game_soccer_events','game_soccer_lineups','game_soccer_finalizations','game_soccer_final_stats') AND tablename NOT IN ('game_football_states','game_football_events','game_football_lineups','game_football_finalizations','game_football_final_stats') AND tablename NOT IN ('game_diamond_states','game_diamond_events','game_diamond_plate_appearances','game_diamond_finalizations','game_diamond_final_stats') AND tablename NOT IN ('stat_competition_classifications','stat_game_selections','stat_game_contributions','stat_origin_summaries','stat_refresh_work') AND tablename NOT IN ('game_stat_catalog_versions','game_stat_catalog_items','game_tracking_profiles','game_tracking_profile_revisions','game_tracking_snapshots','game_stat_coverage_intervals','game_finalization_tracking_seals','game_volleyball_states','game_volleyball_events','game_volleyball_finalizations','game_volleyball_final_stats') AND tablename NOT IN ('athlete_profiles','athlete_profile_revisions','athlete_measurables','athlete_achievements','athlete_profile_verifications','athlete_media_links','recruiting_showcases','recruiting_showcase_revisions','recruiting_consents','recruiting_share_links','achievement_definitions','achievement_definition_revisions','entity_achievements','achievement_recognitions','achievement_history','achievement_display_choices','award_nominations','award_decisions','achievement_competition_closures','achievement_refresh_work'))
  AND (SELECT count(*)=14 FROM public.modules));
 PERFORM pg_temp.check('exact Phase4B finite permission set',(SELECT array_agg(key ORDER BY key)=keys FROM public.permissions WHERE key=ANY(keys)));
 FOR role_key IN SELECT key FROM public.roles ORDER BY key LOOP
  expected:=CASE
   WHEN role_key IN('super_administrator','platform_administrator','organization_owner','organization_administrator','athletic_director','program_administrator','sport_administrator','team_administrator') THEN keys
   WHEN role_key='head_coach' THEN ARRAY['attendance.checkin','attendance.manage','attendance.respond','attendance.view','volunteers.manage','volunteers.signup','volunteers.view']
   WHEN role_key='assistant_coach' THEN ARRAY['attendance.checkin','attendance.manage','attendance.respond','attendance.view','volunteers.signup','volunteers.view']
   WHEN role_key='team_staff' THEN ARRAY['attendance.respond','attendance.view','volunteers.signup','volunteers.view']
   WHEN role_key='volunteer_coordinator' THEN ARRAY['attendance.respond','attendance.view','volunteers.assign','volunteers.manage','volunteers.signup','volunteers.view']
   ELSE ARRAY[]::text[] END;
  SELECT coalesce(array_agg(p.key ORDER BY p.key),ARRAY[]::text[]) INTO actual
   FROM public.roles r JOIN public.role_permissions rp ON rp.role_id=r.id JOIN public.permissions p ON p.id=rp.permission_id
   WHERE r.key=role_key AND p.key=ANY(keys);
  PERFORM pg_temp.check('potential capability only: '||role_key,actual=expected);
 END LOOP;
 PERFORM pg_temp.check('coordinator scope not broadened',(SELECT allowed_scope_types=ARRAY['team'] FROM public.roles WHERE key='volunteer_coordinator'));
 FOR tab IN SELECT n.nspname schema_name,c.relname name,c.oid,c.relrowsecurity
  FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE c.relkind='r' AND n.nspname IN('public','boss_private')
   AND(c.relname LIKE 'attendance_%' OR c.relname LIKE 'volunteer_%' OR c.relname='event_attendance_settings') LOOP
  PERFORM pg_temp.check(tab.schema_name||'.'||tab.name||' RLS',tab.relrowsecurity);
  FOREACH client_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
   PERFORM pg_temp.check(tab.schema_name||'.'||tab.name||' raw privileges closed to '||client_role,
    NOT has_table_privilege(client_role,tab.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'));
  END LOOP;
 END LOOP;
 FOR fn IN SELECT p.oid,p.oid::regprocedure signature,p.prosecdef,p.proconfig,p.proacl,p.proowner,n.nspname schema_name,p.proname
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
  WHERE(n.nspname='public' AND p.proname IN('boss_attendance_read','boss_attendance_mutate','boss_volunteers_read','boss_volunteers_mutate'))
  OR(n.nspname='boss_private' AND(p.proname LIKE 'attendance_%' OR p.proname LIKE 'volunteer_%' OR p.proname LIKE '%_phase4a' OR p.proname='coordination_configuration')) LOOP
  PERFORM pg_temp.check(fn.signature||' empty search_path',coalesce('search_path=""'=ANY(fn.proconfig),false));
  PERFORM pg_temp.check(fn.signature||' no PUBLIC execute',NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(fn.proacl,acldefault('f',fn.proowner)))a WHERE a.grantee=0 AND a.privilege_type='EXECUTE'));
  PERFORM pg_temp.check(fn.signature||' no anon/service execute',NOT has_function_privilege('anon',fn.oid,'EXECUTE') AND NOT has_function_privilege('service_role',fn.oid,'EXECUTE'));
  IF fn.schema_name='public' THEN
   PERFORM pg_temp.check(fn.signature||' invoker entry',NOT fn.prosecdef AND has_function_privilege('authenticated',fn.oid,'EXECUTE'));
  ELSIF fn.proname NOT IN('attendance_read','attendance_mutate','volunteer_read','volunteer_mutate') THEN
   PERFORM pg_temp.check(fn.signature||' private helper closed',NOT has_function_privilege('authenticated',fn.oid,'EXECUTE'));
  END IF;
 END LOOP;
 PERFORM pg_temp.check('dedicated guardian flag defaults false',(SELECT a.attnotnull AND pg_get_expr(d.adbin,d.adrelid)='false' FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid='public.guardian_relationships'::regclass AND a.attname='can_respond_attendance'));
 PERFORM pg_temp.check('attendance reminder generic template has no private RSVP fields',(SELECT count(*)=4 AND bool_and(category='attendance' AND source_module='calendar') FROM boss_private.notification_types WHERE key LIKE 'attendance.%'));
 PERFORM pg_temp.check('volunteer types use shared delivery engine',(SELECT count(*)=5 AND bool_and(category='volunteers' AND source_module='volunteers') FROM boss_private.notification_types WHERE key LIKE 'volunteer.%'));
END $$;

-- Four independent opt-in combinations, plus collision/default fail-closed checks.
INSERT INTO public.organizations(id,name,slug)
 SELECT md5('boss-phase4b-feature:'||label)::uuid,'Synthetic feature '||label,'synthetic-phase4b-feature-'||label
 FROM unnest(ARRAY['a','b','c','d'])label;
INSERT INTO public.organization_modules(organization_id,module_id,status,configuration,starts_at)
 SELECT md5('boss-phase4b-feature:'||label)::uuid,m.id,'active',
 CASE WHEN m.key='calendar' THEN jsonb_build_object('attendance',label IN('b','d'),'attendance_rsvp',true,'head_coach_management',true)
 ELSE jsonb_build_object('volunteers',true,'self_signup',true) END,now()-interval '1 day'
 FROM unnest(ARRAY['a','b','c','d'])label CROSS JOIN public.modules m WHERE m.key='calendar' OR(m.key='volunteers' AND label IN('c','d'));
SELECT pg_temp.check('calendar only',boss_private.calendar_module_enabled(md5('boss-phase4b-feature:a')::uuid)
 AND NOT boss_private.attendance_feature(md5('boss-phase4b-feature:a')::uuid,'attendance') AND NOT boss_private.volunteer_feature(md5('boss-phase4b-feature:a')::uuid,'volunteers'));
SELECT pg_temp.check('calendar plus attendance',boss_private.attendance_feature(md5('boss-phase4b-feature:b')::uuid,'attendance') AND NOT boss_private.volunteer_feature(md5('boss-phase4b-feature:b')::uuid,'volunteers'));
SELECT pg_temp.check('calendar plus volunteers',boss_private.volunteer_feature(md5('boss-phase4b-feature:c')::uuid,'volunteers') AND NOT boss_private.attendance_feature(md5('boss-phase4b-feature:c')::uuid,'attendance'));
SELECT pg_temp.check('calendar plus both',boss_private.attendance_feature(md5('boss-phase4b-feature:d')::uuid,'attendance') AND boss_private.volunteer_feature(md5('boss-phase4b-feature:d')::uuid,'volunteers'));
SELECT pg_temp.check('Calendar coach flag cannot enable attendance management',NOT boss_private.attendance_feature(md5('boss-phase4b-feature:b')::uuid,'head_coach_management'));
SELECT pg_temp.check('unknown feature fails closed',NOT boss_private.attendance_feature(md5('boss-phase4b-feature:b')::uuid,'unknown') AND NOT boss_private.volunteer_feature(md5('boss-phase4b-feature:d')::uuid,'unknown'));
UPDATE public.organization_modules SET configuration=configuration||'{"attendance_minimum_self_response_age":17}' WHERE organization_id=md5('boss-phase4b-feature:b')::uuid;
SELECT pg_temp.check('invalid participant age policy fails closed',boss_private.attendance_configuration(md5('boss-phase4b-feature:b')::uuid)->'minimum_self_response_age'='null'::jsonb);
UPDATE public.organization_modules SET configuration=configuration||'{"minimum_signup_age":17}' WHERE organization_id=md5('boss-phase4b-feature:d')::uuid AND module_id=(SELECT id FROM public.modules WHERE key='volunteers');
SELECT pg_temp.check('invalid volunteer age policy fails closed',boss_private.volunteer_minimum_age(md5('boss-phase4b-feature:d')::uuid) IS NULL);
SELECT count(*) AS passed_assertions FROM pg_temp.phase4b_security_assertions;
ROLLBACK;
