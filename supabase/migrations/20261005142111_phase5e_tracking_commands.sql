-- Exact-scope profile management is distinct from exact-game score operation.
create function boss_private.tracking_scope_allowed(actor uuid,p public.game_tracking_profiles)returns boolean
language plpgsql volatile security definer set search_path=''as $$
declare g public.games;t public.teams;begin
 if actor is distinct from boss_private.current_person_id()or not exists(select 1 from public.people where id=actor and status='active')then return false;end if;
 if p.scope_type='platform'then
 return exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions x on x.id=rp.permission_id and x.key='games.manage'and x.status='active'
 where a.person_id=actor and a.scope_type='platform'and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp()));end if;
 if not boss_private.games_feature(p.organization_id,'game_center')then return false;end if;
 if p.scope_type in('team','season')then
 select *into t from public.teams where organization_id=p.organization_id and id=p.team_id and status='active';
 return t.id is not null and(p.scope_type<>'season'or t.season_id=p.season_id and exists(select 1 from public.seasons where id=p.season_id and organization_id=p.organization_id and status='active'))and boss_private.games_role_permission(actor,'games.manage',p.organization_id,t.id);
 elsif p.scope_type='game'then
 select *into g from public.games where id=p.game_id and organization_id=p.organization_id and sport_key=p.sport_key;
 if g.id is null or p.side not in('primary','opponent')then return false;end if;
 return case when p.side='opponent'and g.opponent_team_id is null then boss_private.games_permission(actor,'games.manage',g,true)
 else boss_private.games_role_permission(actor,'games.manage',g.organization_id,case p.side when'primary'then g.primary_team_id else g.opponent_team_id end)end;
 elsif p.scope_type='organization'then return boss_private.games_role_permission(actor,'games.manage',p.organization_id);
 elsif p.scope_type='organization_unit'then
 if not exists(select 1 from public.organization_units where id=p.unit_id and organization_id=p.organization_id and status='active')then return false;end if;
 -- Same role catalog/capability, exact unit only. No synthetic game/team.
 return boss_private.games_role_permission(actor,'games.manage',p.organization_id)or exists(
 select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.status='active'
 join public.role_permissions rp on rp.role_id=r.id join public.permissions x on x.id=rp.permission_id and x.status='active'and x.key='games.manage'
 where a.person_id=actor and a.organization_id=p.organization_id and a.scope_type='organization_unit'and a.scope_id=p.unit_id and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())
 and exists(select 1 from public.organization_memberships m where m.person_id=actor and m.organization_id=p.organization_id and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())));
 end if;return false;
end$$;

create function boss_private.tracking_locks(p public.game_tracking_profiles)returns void
language plpgsql volatile security definer set search_path=''as $$begin
 -- Global defaults serialize with default resolution; tenant settings use a
 -- separate tenant lock. Ordinary rallies rely only on their frozen game state.
 if p.scope_type='platform'then perform pg_advisory_xact_lock(hashtextextended('tracking-default:'||p.sport_key,0));
 else perform pg_advisory_xact_lock_shared(hashtextextended('tracking-default:'||p.sport_key,0));
 perform pg_advisory_xact_lock(hashtextextended('tracking-org:'||p.sport_key||':'||p.organization_id::text,0));end if;
end$$;
create function boss_private.tracking_resolution_locks(g public.games)returns void
language plpgsql volatile security definer set search_path=''as $$begin
 perform pg_advisory_xact_lock_shared(hashtextextended('tracking-default:'||g.sport_key,0));
 perform pg_advisory_xact_lock_shared(hashtextextended('tracking-org:'||g.sport_key||':'||g.organization_id::text,0));
end$$;

create function boss_private.tracking_profile_command(actor uuid,i jsonb,request uuid,replay boolean default false)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare p public.game_tracking_profiles;old public.game_tracking_profiles;g public.games;e public.events;
 selection jsonb;before_state jsonb;rid uuid;opid uuid;reason text;begin
 perform boss_private.games_validate(i,array['sport_key','scope_type','organization_id','unit_id','team_id','season_id','game_id','side','expected_profile_version','expected_game_version','preset','enabled','quick','status','ends_at','reason'],array['sport_key','scope_type','expected_profile_version','preset','reason']);
 if i->>'sport_key'not in('basketball','soccer','football','volleyball')or i->>'scope_type'not in('platform','organization','organization_unit','team','season','game')or jsonb_typeof(i->'expected_profile_version')<>'number'or i->>'expected_profile_version'!~'^[0-9]{1,15}$'then raise exception 'Invalid tracking scope/version'using errcode='PT422';end if;
 p.sport_key:=i->>'sport_key';p.scope_type:=i->>'scope_type';p.organization_id:=(i->>'organization_id')::uuid;p.unit_id:=(i->>'unit_id')::uuid;p.team_id:=(i->>'team_id')::uuid;p.season_id:=(i->>'season_id')::uuid;p.game_id:=(i->>'game_id')::uuid;p.side:=i->>'side';
 if not((p.scope_type='platform'and p.organization_id is null and p.unit_id is null and p.team_id is null and p.season_id is null and p.game_id is null and p.side is null)
 or(p.scope_type='organization'and p.organization_id is not null and p.unit_id is null and p.team_id is null and p.season_id is null and p.game_id is null and p.side is null)
 or(p.scope_type='organization_unit'and p.organization_id is not null and p.unit_id is not null and p.team_id is null and p.season_id is null and p.game_id is null and p.side is null)
 or(p.scope_type='team'and p.organization_id is not null and p.unit_id is null and p.team_id is not null and p.season_id is null and p.game_id is null and p.side is null)
 or(p.scope_type='season'and p.organization_id is not null and p.unit_id is null and p.team_id is not null and p.season_id is not null and p.game_id is null and p.side is null)
 or(p.scope_type='game'and p.organization_id is not null and p.unit_id is null and p.team_id is null and p.season_id is null and p.game_id is not null and p.side in('primary','opponent')))then raise exception 'Invalid tracking scope'using errcode='PT422';end if;
 reason:=i->>'reason';if length(btrim(reason))not between 1 and 500 or reason~'[[:cntrl:]]'then raise exception 'Tracking change reason is required'using errcode='PT422';end if;
 selection:=boss_private.tracking_selection(p.sport_key,i->>'preset',coalesce(i->'enabled','[]'),i->'quick');
 p.status:=coalesce(i->>'status','active');p.ends_at:=(i->>'ends_at')::timestamptz;
 if p.status not in('active','inactive')or p.ends_at is not null and(not isfinite(p.ends_at)or p.ends_at<=clock_timestamp())then raise exception 'Invalid tracking lifecycle'using errcode='PT422';end if;
 -- Fast denial before locks; repeat after all waits and before commit.
 perform boss_private.games_require_live_auth();
 if not boss_private.tracking_scope_allowed(actor,p)then raise exception 'Access denied'using errcode='PT403';end if;
 perform boss_private.tracking_locks(p);
 if p.scope_type='game'then
 select event_id into e.id from public.games where id=p.game_id;
 select *into e from public.events where id=e.id for update;
 select *into g from public.games where id=p.game_id for update;
 perform boss_private.games_lock_authority(actor,g);
 if g.status in('final','canceled','abandoned','postponed')then raise exception 'Game tracking is locked'using errcode='PT409';end if;
 if not i?'expected_game_version'or i->>'expected_game_version'!~'^[0-9]{1,15}$'then raise exception 'Game version is required'using errcode='PT422';end if;
 else
 perform 1 from public.role_assignments where person_id=actor and(organization_id=p.organization_id or scope_type='platform')order by id for share;
 perform 1 from public.organization_memberships where person_id=actor and organization_id=p.organization_id order by id for share;
 perform 1 from public.team_memberships where person_id=actor and organization_id=p.organization_id and team_id=p.team_id order by id for share;
 perform 1 from public.organization_modules where organization_id=p.organization_id order by id for share;
 end if;
 perform boss_private.games_require_live_auth();if not boss_private.tracking_scope_allowed(actor,p)then raise exception 'Access denied'using errcode='PT403';end if;
 select *into old from public.game_tracking_profiles x where x.sport_key=p.sport_key and x.scope_type=p.scope_type and x.organization_id is not distinct from p.organization_id and x.unit_id is not distinct from p.unit_id and x.team_id is not distinct from p.team_id and x.season_id is not distinct from p.season_id and x.game_id is not distinct from p.game_id and x.side is not distinct from p.side for update;
 if replay then return jsonb_build_object('profile_id',old.id,'profile_version',old.version,'game_id',g.id,'organization_id',old.organization_id,'version',coalesce(g.version,old.version),'message','Saved.');end if;
 if coalesce(old.version,0)<>(i->>'expected_profile_version')::bigint or g.id is not null and g.version<>(i->>'expected_game_version')::bigint then raise exception 'Tracking profile changed; reload before saving'using errcode='PT409';end if;
 before_state:=to_jsonb(old);
 if old.id is null then
 insert into public.game_tracking_profiles(sport_key,organization_id,scope_type,unit_id,team_id,season_id,game_id,side,version,status,ends_at)
 values(p.sport_key,p.organization_id,p.scope_type,p.unit_id,p.team_id,p.season_id,p.game_id,p.side,1,p.status,p.ends_at)returning *into p;
 else
 update public.game_tracking_profiles set version=old.version+1,status=p.status,ends_at=coalesce(p.ends_at,old.ends_at)where id=old.id returning *into p;end if;
 insert into public.game_tracking_profile_revisions(profile_id,sport_key,version,catalog_version,selection,actor_person_id,request_id)
 values(p.id,p.sport_key,p.version,'boss-tracking-v1',selection,actor,request)returning id into rid;
 if g.id is not null and exists(select 1 from public.game_tracking_snapshots where game_id=g.id)then
 update public.games set version=g.version+1 where id=g.id returning *into g;
 perform boss_private.tracking_snapshot(g,p.side,g.last_sequence+1);
 opid:=boss_private.games_append(g.id,actor,'tracking.profile.set',request,boss_private.games_core_state(g)||jsonb_build_object('tracking_profile',before_state),jsonb_build_object('tracking_profile_id',p.id,'tracking_revision_id',rid,'reason',reason));
 else
 insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,request_id,before_data,after_data)
 values(p.organization_id,actor,auth.uid(),'tracking.profile.set','game_tracking_profile',p.id,case p.scope_type when'season'then'team'when'game'then'organization'else p.scope_type end,case p.scope_type when'platform'then null when'organization_unit'then p.unit_id when'team'then p.team_id when'season'then p.team_id else p.organization_id end,request,before_state,to_jsonb(p)||jsonb_build_object('revision_id',rid,'selection',selection,'reason',reason));end if;
 perform boss_private.games_require_live_auth();if not boss_private.tracking_scope_allowed(actor,p)then raise exception 'Access denied'using errcode='PT403';end if;
 return jsonb_build_object('profile_id',p.id,'profile_version',p.version,'game_id',g.id,'organization_id',p.organization_id,'version',coalesce(g.version,p.version),'message','Tracking profile saved.');
end$$;

-- Freeze setting resolution consistently with concurrent profile edits.
alter function boss_private.tracking_snapshot(public.games,text,bigint)rename to tracking_snapshot_unlocked;
create function boss_private.tracking_snapshot(g public.games,p_side text,p_sequence bigint)returns uuid
language plpgsql volatile security definer set search_path=''as $$begin
 perform boss_private.tracking_resolution_locks(g);
 return boss_private.tracking_snapshot_unlocked(g,p_side,p_sequence);end$$;

do $$declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'tracking_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;end$$;
