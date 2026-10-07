-- Included only by phase2b_bootstrap.sh after the verbatim trusted DO source.
-- No passwords/tokens/session credentials exist in these synthetic fixtures.
CREATE TEMP TABLE phase2b_bootstrap_assertions (assertion text PRIMARY KEY) ON COMMIT DROP;
CREATE FUNCTION pg_temp.bootstrap_id(label text) RETURNS uuid
LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog
AS $$ SELECT md5('boss-phase2b-bootstrap-fixture:' || label)::uuid $$;
CREATE FUNCTION pg_temp.bootstrap_assert(label text,actual boolean) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF actual IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL bootstrap: %',label;END IF;
 INSERT INTO pg_temp.phase2b_bootstrap_assertions VALUES(label);
END;
$$;
CREATE FUNCTION pg_temp.run_actual_bootstrap(email text,person uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE statement text;
BEGIN
 PERFORM pg_catalog.set_config('boss.bootstrap_email',email,true);
 PERFORM pg_catalog.set_config('boss.bootstrap_person_id',coalesce(person::text,''),true);
 SELECT s.statement INTO statement FROM pg_temp.phase2b_bootstrap_source s;
 EXECUTE statement;
END;
$$;
CREATE FUNCTION pg_temp.bootstrap_denied(label text,email text,person uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE denied boolean:=false;
BEGIN
 BEGIN PERFORM pg_temp.run_actual_bootstrap(email,person);
 EXCEPTION WHEN raise_exception THEN denied:=true;
 END;
 PERFORM pg_temp.bootstrap_assert(label,denied);
END;
$$;
REVOKE ALL ON FUNCTION pg_temp.bootstrap_id(text),pg_temp.bootstrap_assert(text,boolean),
 pg_temp.run_actual_bootstrap(text,uuid),pg_temp.bootstrap_denied(text,text,uuid) FROM PUBLIC;

INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous,banned_until,deleted_at)
SELECT pg_temp.bootstrap_id('auth-' || label),label || '@bootstrap.phase2b.example.invalid',
 CASE WHEN label='unconfirmed' THEN NULL ELSE now()-interval '1 day' END,label='anonymous',
 CASE WHEN label='banned' THEN now()+interval '1 day' END,CASE WHEN label='deleted' THEN now()-interval '1 day' END
FROM unnest(ARRAY['verified','unconfirmed','anonymous','banned','deleted','review','explicit','occupied','other-account','scheduled']) label;
INSERT INTO auth.users(id,email,email_confirmed_at) VALUES
 (pg_temp.bootstrap_id('auth-ambiguous-1'),'ambiguous@bootstrap.phase2b.example.invalid',now()-interval '1 day'),
 (pg_temp.bootstrap_id('auth-ambiguous-2'),'ambiguous@bootstrap.phase2b.example.invalid',now()-interval '1 day');
INSERT INTO public.people(id,display_name,primary_email) VALUES
 (pg_temp.bootstrap_id('review-person'),'Synthetic Phase 2B Bootstrap Review','review@bootstrap.phase2b.example.invalid'),
 (pg_temp.bootstrap_id('explicit-person'),'Synthetic Phase 2B Bootstrap Explicit',NULL),
 (pg_temp.bootstrap_id('occupied-person'),'Synthetic Phase 2B Bootstrap Occupied',NULL),
 (pg_temp.bootstrap_id('scheduled-person'),'Synthetic Phase 2B Bootstrap Scheduled',NULL);
INSERT INTO public.user_accounts(auth_user_id,person_id,account_status)
 VALUES(pg_temp.bootstrap_id('auth-other-account'),pg_temp.bootstrap_id('occupied-person'),'active'),
 (pg_temp.bootstrap_id('auth-scheduled'),pg_temp.bootstrap_id('scheduled-person'),'active');
INSERT INTO public.role_assignments(person_id,role_id,scope_type,starts_at)
 SELECT pg_temp.bootstrap_id('scheduled-person'),id,'platform',now()+interval '1 day'
 FROM public.roles WHERE key='platform_administrator';

SELECT pg_temp.run_actual_bootstrap('verified@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_assert('one canonical identity and active Auth mapping created',
 (SELECT count(*)=1 FROM public.user_accounts a JOIN public.people p ON p.id=a.person_id
  WHERE a.auth_user_id=pg_temp.bootstrap_id('auth-verified') AND a.account_status='active' AND p.status='active'));
SELECT pg_temp.bootstrap_assert('minimum approved platform administrator assigned once',
 (SELECT count(*)=1 FROM public.role_assignments a JOIN public.roles r ON r.id=a.role_id
  WHERE a.person_id=(SELECT person_id FROM public.user_accounts WHERE auth_user_id=pg_temp.bootstrap_id('auth-verified'))
   AND r.key='platform_administrator' AND a.scope_type='platform' AND a.scope_id IS NULL AND a.organization_id IS NULL AND a.status='active'));
SELECT pg_temp.bootstrap_assert('bootstrap did not grant super administrator',
 NOT EXISTS(SELECT 1 FROM public.role_assignments a JOIN public.roles r ON r.id=a.role_id WHERE r.key='super_administrator'));
SELECT pg_temp.bootstrap_assert('first bootstrap emitted exactly three significant safe audits',
 (SELECT count(*)=3 AND count(DISTINCT request_id)=1 FROM public.audit_events WHERE actor_auth_user_id=pg_temp.bootstrap_id('auth-verified')));
SELECT pg_temp.bootstrap_assert('audits include identity link and approved role grant',
 (SELECT array_agg(action ORDER BY action)=ARRAY['account.link','identity.bootstrap','role_assignment.add']
  FROM public.audit_events WHERE actor_auth_user_id=pg_temp.bootstrap_id('auth-verified')));
SELECT pg_temp.bootstrap_assert('bootstrap audit payloads contain approved procedure metadata only',
 NOT EXISTS(SELECT 1 FROM public.audit_events WHERE actor_auth_user_id=pg_temp.bootstrap_id('auth-verified')
  AND (before_data IS NOT NULL OR after_data IS NULL OR NOT after_data ? 'procedure'
    OR after_data::text ~* '(email|password|token|session|example.invalid|display_name|primary_phone|date_of_birth)')));

SELECT pg_temp.run_actual_bootstrap('verified@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_assert('retry preserves one active mapping',
 (SELECT count(*)=1 FROM public.user_accounts WHERE auth_user_id=pg_temp.bootstrap_id('auth-verified')));
SELECT pg_temp.bootstrap_assert('retry preserves one platform assignment',
 (SELECT count(*)=1 FROM public.role_assignments WHERE person_id=(SELECT person_id FROM public.user_accounts
  WHERE auth_user_id=pg_temp.bootstrap_id('auth-verified'))));
SELECT pg_temp.bootstrap_assert('retry does not duplicate significant audits',
 (SELECT count(*)=3 FROM public.audit_events WHERE actor_auth_user_id=pg_temp.bootstrap_id('auth-verified')));

SELECT pg_temp.bootstrap_denied('unconfirmed Auth rejected','unconfirmed@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_denied('anonymous Auth rejected','anonymous@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_denied('banned Auth rejected','banned@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_denied('deleted Auth rejected','deleted@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_denied('missing Auth rejected','missing@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_denied('ambiguous verified Auth identities rejected','ambiguous@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_denied('matching canonical email requires explicit review','review@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_denied('occupied explicit canonical identity rejected','occupied@bootstrap.phase2b.example.invalid',pg_temp.bootstrap_id('occupied-person'));
SELECT pg_temp.bootstrap_denied('existing mapping cannot be rebound','verified@bootstrap.phase2b.example.invalid',pg_temp.bootstrap_id('explicit-person'));
SELECT pg_temp.bootstrap_denied('scheduled platform grant requires reviewed remediation','scheduled@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_assert('bootstrap does not supersede scheduled role history',
 (SELECT count(*)=1 AND bool_and(starts_at>now()) FROM public.role_assignments WHERE person_id=pg_temp.bootstrap_id('scheduled-person')));
SELECT pg_temp.bootstrap_assert('denied scheduled role bootstrap has no audit side effect',
 NOT EXISTS(SELECT 1 FROM public.audit_events WHERE actor_auth_user_id=pg_temp.bootstrap_id('auth-scheduled')));
SELECT pg_temp.bootstrap_assert('rejected bootstrap creates no Auth mappings',
 NOT EXISTS(SELECT 1 FROM public.user_accounts WHERE auth_user_id IN (
  SELECT id FROM auth.users WHERE email IN('unconfirmed@bootstrap.phase2b.example.invalid','anonymous@bootstrap.phase2b.example.invalid',
   'banned@bootstrap.phase2b.example.invalid','deleted@bootstrap.phase2b.example.invalid','ambiguous@bootstrap.phase2b.example.invalid',
   'review@bootstrap.phase2b.example.invalid','occupied@bootstrap.phase2b.example.invalid'))));
SELECT pg_temp.bootstrap_assert('rejected bootstrap leaves no orphan auto-created person',
 (SELECT count(*)=1 FROM public.people WHERE display_name='Boss controlled administrator'));

SELECT pg_temp.run_actual_bootstrap('explicit@bootstrap.phase2b.example.invalid',pg_temp.bootstrap_id('explicit-person'));
SELECT pg_temp.bootstrap_assert('reviewed explicit canonical linkage preserves existing person',
 (SELECT count(*)=1 FROM public.user_accounts WHERE auth_user_id=pg_temp.bootstrap_id('auth-explicit')
  AND person_id=pg_temp.bootstrap_id('explicit-person') AND account_status='active'));
SELECT pg_temp.bootstrap_assert('existing-person bootstrap audits link and role without new identity',
 (SELECT count(*)=2 AND count(*) FILTER(WHERE action='identity.bootstrap')=0
  FROM public.audit_events WHERE actor_auth_user_id=pg_temp.bootstrap_id('auth-explicit')));
UPDATE public.user_accounts SET account_status='inactive' WHERE auth_user_id=pg_temp.bootstrap_id('auth-explicit');
SELECT pg_temp.bootstrap_denied('inactive mapping requires reviewed remediation','explicit@bootstrap.phase2b.example.invalid');
SELECT pg_temp.bootstrap_assert('bootstrap does not silently reactivate account history',
 EXISTS(SELECT 1 FROM public.user_accounts WHERE auth_user_id=pg_temp.bootstrap_id('auth-explicit') AND account_status='inactive'));
SELECT pg_temp.bootstrap_assert('approved role and permission catalogs preserved',
 (SELECT count(*)=19 FROM public.roles WHERE key NOT IN ('registrar','organization_finance','competition_manager')) AND (SELECT count(*)=17 FROM public.permissions WHERE key NOT IN ('events.view','events.create','events.manage','events.publish','events.override_conflict','registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage') AND key NOT LIKE 'games.%') AND (SELECT count(*)=112 FROM public.role_permissions rp JOIN public.permissions p ON p.id=rp.permission_id WHERE p.key NOT IN ('events.view','events.create','events.manage','events.publish','events.override_conflict','registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage','announcements.send','communications.manage','communications.send','communications.view','delivery_history.view','moderation.manage','notifications.manage','notifications.view','team_chat.send','team_chat.view','attendance.view','attendance.respond','attendance.manage','attendance.checkin','volunteers.view','volunteers.signup','volunteers.manage','volunteers.assign','competition.view','competition.manage','competition.policy_manage','standings.view','standings.manage','standings.rebuild','leaderboard.view','leaderboard.manage','leaderboard.rebuild','records.view','records.manage','records.rebuild','athlete_profiles.view','athlete_profiles.manage','athlete_profiles.verify','recruiting_showcases.view','recruiting_showcases.manage','recruiting_showcases.publish','achievement_definitions.manage','awards.issue','awards.approve','fundraising.view','fundraising.create','fundraising.manage','fundraising.publish','fundraising.financial_view','money_board.view','money_board.manage') AND p.key NOT LIKE 'games.%'));

SELECT count(*) AS passed_assertions FROM pg_temp.phase2b_bootstrap_assertions;
ROLLBACK;
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM auth.users WHERE email LIKE '%@bootstrap.phase2b.example.invalid')
  OR EXISTS(SELECT 1 FROM public.people WHERE display_name LIKE 'Synthetic Phase 2B Bootstrap%' OR display_name='Boss controlled administrator')
  OR EXISTS(SELECT 1 FROM public.audit_events WHERE actor_auth_user_id=md5('boss-phase2b-bootstrap-fixture:auth-verified')::uuid) THEN
  RAISE EXCEPTION 'FAIL bootstrap cleanup: transactional fixture survived rollback';
 END IF;
END $$;
SELECT 'actual trusted bootstrap source validated; transactional fixtures rolled back' AS cleanup_result;
