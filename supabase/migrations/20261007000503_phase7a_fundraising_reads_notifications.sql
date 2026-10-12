create function boss_private.fundraising_raised(campaign uuid,fundraiser uuid default null,team uuid default null,unit uuid default null)returns bigint language sql volatile security definer set search_path=''as $$
 select coalesce(sum(e.amount_minor),0)::bigint from public.fundraising_success_evidence e join public.fundraising_intents i on i.id=e.intent_id where i.campaign_id=campaign and(fundraiser is null or i.fundraiser_id=fundraiser)and(team is null or i.provenance->>'team_id'=team::text)and(unit is null or i.provenance->>'unit_id'=unit::text)
$$;
create function boss_private.fundraising_board_projection(board uuid,offset_ordinal integer default 0)returns jsonb language sql volatile security definer set search_path=''as $$
 select jsonb_build_object('title',b.title,'goal_minor',b.goal_minor,'start_minor',b.start_minor,'increment_minor',b.increment_minor,'tile_count',b.tile_count,'largest_minor',b.start_minor+(b.tile_count-1)::bigint*b.increment_minor,
 'all_claimed_minor',(b.tile_count::numeric*(2*b.start_minor::numeric+(b.tile_count-1)::numeric*b.increment_minor)/2)::bigint,'reservation_seconds',b.reservation_seconds,'status',b.status,'version',b.version,
 'generated_count',(select count(*)from public.money_board_tiles where board_id=b.id and generation_id=(select id from public.money_board_generations where board_id=b.id order by generation desc limit 1)),'raised_minor',(select coalesce(sum(e.amount_minor),0)::bigint from public.fundraising_success_evidence e join public.money_board_tiles t on t.id=e.tile_id where t.board_id=b.id),'claimed_count',(select count(*)from public.fundraising_success_evidence e join public.money_board_tiles t on t.id=e.tile_id where t.board_id=b.id),
 'tiles',coalesce((select jsonb_agg(jsonb_build_object('ordinal',t.ordinal,'amount_minor',t.amount_minor,'state',case when exists(select 1 from public.fundraising_success_evidence e where e.tile_id=t.id)then'claimed'when exists(select 1 from public.money_board_reservations r where r.tile_id=t.id and r.released_at is null and r.expires_at>clock_timestamp()and exists(select 1 from public.fundraising_intents i where i.reservation_id=r.id and not exists(select 1 from public.fundraising_intent_events ev where ev.intent_id=i.id and ev.state<>'awaiting_payment')))then'payment_pending'when exists(select 1 from public.money_board_reservations r where r.tile_id=t.id and r.released_at is null and r.expires_at>clock_timestamp())then'reserved'else'available'end)order by t.ordinal)
 from(select t.*from public.money_board_tiles t where t.board_id=b.id and t.generation_id=(select id from public.money_board_generations g where g.board_id=b.id order by generation desc limit 1)and t.ordinal>greatest(0,offset_ordinal)order by t.ordinal limit 100)t),'[]'::jsonb))from public.money_boards b where b.id=board
$$;
-- Opt-in, finite display projection. Public mode requires a current approved share.
create function boss_private.fundraising_leaderboard(campaign uuid,actor uuid default null,team uuid default null,unit uuid default null)returns jsonb language sql volatile security definer set search_path=''as $$
 select coalesce(jsonb_agg(jsonb_build_object('kind',x.kind,'name',x.name,'raised_minor',x.raised)order by x.raised desc,x.name),'[]')from(
 select 'participant'kind,f.public_display_name name,boss_private.fundraising_raised(c.id,f.id)raised
 from public.fundraising_campaigns c join public.fundraising_fundraisers f on f.campaign_id=c.id
 where c.id=campaign and c.leaderboard_visibility<>'disabled'and f.leaderboard_opt_in and f.public_display_name is not null and boss_private.fundraising_member(f)and(team is null or f.team_id=team)and(unit is null or f.unit_id=unit)
 and(case when actor is null then c.leaderboard_visibility='public'and exists(select 1 from public.fundraising_shares sh where sh.fundraiser_id=f.id and sh.status='active'and(boss_private.fundraising_guardian(sh.authorized_by,f.person_id)or boss_private.fundraising_self(sh.authorized_by,f.person_id,c)))else boss_private.fundraising_view(actor,f)end)
 union all select 'team',t.name,boss_private.fundraising_raised(c.id,null,t.id)
 from public.fundraising_campaigns c join public.fundraising_targets ft on ft.campaign_id=c.id join public.teams t on t.id=ft.team_id and t.status='active'
 where c.id=campaign and c.leaderboard_visibility<>'disabled'and(team is null or t.id=team)and(unit is null or t.parent_unit_id=unit)
 and(case when actor is null then c.leaderboard_visibility='public'else boss_private.fundraising_role(actor,'fundraising.view',c.organization_id,t.parent_unit_id,t.id)end)
 order by raised desc,name limit 20)x
$$;
revoke all on function boss_private.fundraising_leaderboard(uuid,uuid,uuid,uuid)from public,anon,authenticated,service_role;
create function boss_private.fundraising_public_read(path text,offset_ordinal integer default 0)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare ctx jsonb;c public.fundraising_campaigns;f public.fundraising_fundraisers;result jsonb;
begin
 ctx:=boss_private.fundraising_public_context(path);select *into c from public.fundraising_campaigns where id=(ctx->>'campaign_id')::uuid;
 select *into f from public.fundraising_fundraisers where id=(ctx->>'fundraiser_id')::uuid;
 result:=jsonb_build_object('campaign',jsonb_build_object('name',c.name,'description',c.description,'organization_name',(select name from public.organizations where id=c.organization_id),'currency',c.currency,'goal_minor',c.goal_minor,'raised_minor',boss_private.fundraising_raised(c.id),'starts_at',c.starts_at,'ends_at',c.ends_at,'branding',c.branding,'indexable',c.indexable and f.id is null,'allow_anonymous',c.allow_anonymous,'allow_recurring',c.allow_recurring,'allow_fee_cover',c.allow_fee_cover,'direct_support',('direct_support'=any(c.channels)),'reward_policy',c.reward_policy),
 'fundraiser',case when f.id is not null then jsonb_build_object('display_name',f.public_display_name,'goal_minor',f.goal_minor,'raised_minor',boss_private.fundraising_raised(c.id,f.id),'team_name',(select name from public.teams where id=f.team_id))else null end,
 'board',boss_private.fundraising_board_projection((ctx->>'board_id')::uuid,offset_ordinal),'payment_available',false,'leaderboard',boss_private.fundraising_leaderboard(c.id),
 'supporters',coalesce((select jsonb_agg(jsonb_build_object('display_name',case when i.anonymous then'Anonymous'else d.display_name end,'amount_minor',e.amount_minor,'date',e.settled_at)order by e.settled_at desc)from(select *from public.fundraising_success_evidence e where e.intent_id in(select id from public.fundraising_intents where campaign_id=c.id and(f.id is null or fundraiser_id=f.id))order by settled_at desc limit 20)e join public.fundraising_intents i on i.id=e.intent_id join public.fundraising_donors d on d.id=i.donor_id),'[]'::jsonb));
 return result;
end$$;
create function boss_fundraising_public.read(path text,offset_ordinal integer default 0)returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.fundraising_public_read(path,offset_ordinal)$$;
create function public.boss_fundraising_public(path text,offset_ordinal integer default 0)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_fundraising_public.read(path,offset_ordinal)$$;

create function boss_private.fundraising_read(query jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;org uuid;team uuid;unit uuid;child uuid;campaign uuid;mode text;financial boolean;result jsonb;
begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.athlete_input(query,array['organization_id','team_id','unit_id','child_id','campaign_id','mode','financial','after','fundraiser_after','limit','scopes_only']);
 org:=boss_private.athlete_uuid(query,'organization_id');team:=boss_private.athlete_uuid(query,'team_id');unit:=boss_private.athlete_uuid(query,'unit_id');if team is not null then if unit is not null and unit is distinct from(select parent_unit_id from public.teams where id=team and organization_id=org)then raise exception'Invalid exact context'using errcode='PT403';end if;select parent_unit_id into unit from public.teams where id=team and organization_id=org;end if;child:=boss_private.athlete_uuid(query,'child_id');campaign:=boss_private.athlete_uuid(query,'campaign_id');mode:=coalesce(query->>'mode','organization');financial:=coalesce((query->>'financial')::boolean,false);
 if mode not in('organization','family')then raise exception'Invalid fundraising view'using errcode='PT422';end if;
 if coalesce((query->>'scopes_only')::boolean,false)and mode='organization'and org is not null and team is null and unit is null and boss_private.fundraising_module(org,'fundraising')and not boss_private.fundraising_role(actor,'fundraising.view',org)and(jsonb_array_length(boss_private.fundraising_catalog(actor,org)->'teams')>0 or jsonb_array_length(boss_private.fundraising_catalog(actor,org)->'units')>0)then return jsonb_build_object('campaigns','[]'::jsonb,'mode',mode,'can_create',false,'money_board_available',false,'catalog',boss_private.fundraising_catalog(actor,org));end if;
 if mode='organization'and(org is null or not boss_private.fundraising_module(org,'fundraising')or not boss_private.fundraising_role(actor,'fundraising.view',org,unit,team))then raise exception'Access denied'using errcode='PT403';end if;
 if child is not null and mode='family'and not boss_private.fundraising_guardian(actor,child)and child<>actor then raise exception'Access denied'using errcode='PT403';end if;
 if financial and(mode<>'organization'or not boss_private.fundraising_role(actor,'fundraising.financial_view',org,unit,team))then raise exception'Financial access denied'using errcode='PT403';end if;
 with eligible as(select c.*from public.fundraising_campaigns c where(org is null or c.organization_id=org)and(campaign is null or c.id=campaign)and boss_private.fundraising_module(c.organization_id,'fundraising')and(
 mode='organization'and(c.scope='organization'or team is null and unit is null or exists(select 1 from public.fundraising_targets where campaign_id=c.id and(team is not null and team_id=team or team is null and unit is not null and unit_id=unit)))
 or mode='family'and exists(select 1 from public.fundraising_fundraisers f where f.campaign_id=c.id and(child is null or f.person_id=child)and boss_private.fundraising_related(actor,f)))and(query->>'after'is null or c.id>(query->>'after')::uuid)order by c.id limit least(50,greatest(1,coalesce((query->>'limit')::int,30))))
 select jsonb_build_object('campaigns',coalesce(jsonb_agg(jsonb_build_object('id',c.id,'organization_id',c.organization_id,'organization_name',(select name from public.organizations where id=c.organization_id),'name',c.name,'description',c.description,'status',c.status,'version',c.version,'currency',c.currency,'goal_minor',c.goal_minor,'raised_minor',boss_private.fundraising_raised(c.id,null,team,unit),'ends_at',c.ends_at,'starts_at',c.starts_at,
 'public_path',case when c.public_visible and mode='organization'then c.public_path end,'allow_recurring',c.allow_recurring,'allow_fee_cover',c.allow_fee_cover,'allow_anonymous',c.allow_anonymous,'can_manage',boss_private.fundraising_role(actor,'fundraising.manage',c.organization_id),'can_publish',boss_private.fundraising_role(actor,'fundraising.publish',c.organization_id),'can_manage_boards',boss_private.fundraising_role(actor,'money_board.manage',c.organization_id),
 'targets',(select coalesce(jsonb_agg(jsonb_build_object('team_id',t.team_id,'unit_id',t.unit_id,'goal_minor',t.goal_minor,'name',coalesce(tm.name,u.name),'raised_minor',boss_private.fundraising_raised(c.id,null,t.team_id,t.unit_id))),'[]')from public.fundraising_targets t left join public.teams tm on tm.id=t.team_id left join public.organization_units u on u.id=t.unit_id where t.campaign_id=c.id and(team is null or t.team_id=team)and(unit is null or t.unit_id=unit or t.team_id in(select id from public.teams where parent_unit_id=unit))),
 'fundraisers',(select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'participant_id',f.participant_id,'person_id',f.person_id,'name',coalesce(f.public_display_name,p.display_name),'team_name',tm.name,'status',f.status,'goal_minor',f.goal_minor,'raised_minor',boss_private.fundraising_raised(c.id,f.id),'can_share',boss_private.fundraising_related(actor,f)or c.allow_team_sharing and boss_private.fundraising_role(actor,'fundraising.view',f.organization_id,f.unit_id,f.team_id),'can_accept',boss_private.fundraising_related(actor,f),'leaderboard_opt_in',f.leaderboard_opt_in,'supporters',coalesce((select jsonb_agg(jsonb_build_object('display_name',case when i.anonymous then'Anonymous'else d.display_name end,'amount_minor',e.amount_minor,'date',e.settled_at))from(select *from public.fundraising_success_evidence e where e.intent_id in(select id from public.fundraising_intents where fundraiser_id=f.id)order by settled_at desc limit 10)e join public.fundraising_intents i on i.id=e.intent_id join public.fundraising_donors d on d.id=i.donor_id),'[]'),'path',case when boss_private.fundraising_related(actor,f)or c.allow_team_sharing and boss_private.fundraising_role(actor,'fundraising.view',f.organization_id,f.unit_id,f.team_id)then(select s.path from public.fundraising_shares s where s.fundraiser_id=f.id and s.status='active')end,'board',(select boss_private.fundraising_board_projection(b.id)||jsonb_build_object('id',b.id,'visibility',b.visibility)from public.money_boards b where b.fundraiser_id=f.id))),'[]'::jsonb)from(select f.*from public.fundraising_fundraisers f where f.campaign_id=c.id and(team is null or f.team_id=team)and(unit is null or f.unit_id=unit)and(query->>'fundraiser_after'is null or f.id>(query->>'fundraiser_after')::uuid)and(child is null or mode<>'family'or f.person_id=child)and(mode='organization'and boss_private.fundraising_view(actor,f)or mode='family'and boss_private.fundraising_related(actor,f))order by f.id limit 200)f join public.people p on p.id=f.person_id left join public.teams tm on tm.id=f.team_id),
 'boards',(select coalesce(jsonb_agg(boss_private.fundraising_board_projection(b.id)||jsonb_build_object('id',b.id,'public_path',b.public_path,'visibility',b.visibility)),'[]')from public.money_boards b where b.campaign_id=c.id and b.fundraiser_id is null and mode='organization'and(team is null or b.team_id=team)and(unit is null or b.team_id in(select id from public.teams where parent_unit_id=unit))),
 'contribution_count',(select count(*)from public.fundraising_success_evidence e join public.fundraising_intents i on i.id=e.intent_id where i.campaign_id=c.id and(team is null or i.provenance->>'team_id'=team::text)and(unit is null or i.provenance->>'unit_id'=unit::text)),
 'leaderboard',boss_private.fundraising_leaderboard(c.id,actor,team,unit),'report',jsonb_build_object('participant_count',(select count(*)from public.fundraising_fundraisers ff where ff.campaign_id=c.id and(team is null or ff.team_id=team)and(unit is null or ff.unit_id=unit)and(mode='organization'or boss_private.fundraising_related(actor,ff))),'settled_supporter_count',(select count(distinct i.donor_id)from public.fundraising_intents i join public.fundraising_success_evidence e on e.intent_id=i.id where i.campaign_id=c.id and(team is null or i.provenance->>'team_id'=team::text)and(unit is null or i.provenance->>'unit_id'=unit::text)),'anonymous_count',(select count(*)from public.fundraising_intents i join public.fundraising_success_evidence e on e.intent_id=i.id where i.campaign_id=c.id and i.anonymous and(team is null or i.provenance->>'team_id'=team::text)and(unit is null or i.provenance->>'unit_id'=unit::text)),'recurring_count',(select count(*)from public.fundraising_recurring_commitments rc join public.fundraising_intents i on i.id=rc.intent_id where i.campaign_id=c.id and rc.status='planned'and(team is null or i.provenance->>'team_id'=team::text)and(unit is null or i.provenance->>'unit_id'=unit::text))),
 'financial_contributions',case when financial then(select coalesce(jsonb_agg(jsonb_build_object('evidence_id',e.id,'amount_minor',e.amount_minor,'currency',e.currency,'source_system',e.source_system,'source_reference',e.source_reference,'settled_at',e.settled_at,'donor_display',d.display_name,'email',d.email,'mobile',d.mobile,'anonymous',i.anonymous)),'[]')from(select e.*from public.fundraising_success_evidence e join public.fundraising_intents i on i.id=e.intent_id where i.campaign_id=c.id and(team is null or i.provenance->>'team_id'=team::text)and(unit is null or i.provenance->>'unit_id'=unit::text)order by e.settled_at desc limit 100)e join public.fundraising_intents i on i.id=e.intent_id join public.fundraising_donors d on d.id=i.donor_id)else'[]'::jsonb end
 )order by c.id),'[]'::jsonb))into result from eligible c;
 if financial then insert into public.audit_events(organization_id,actor_person_id,actor_auth_user_id,action,resource_type,resource_id,scope_type,scope_id,after_data)values(org,actor,auth.uid(),'fundraising.financial_report.read','organization',org,'organization',org,jsonb_build_object('campaign_filtered',campaign is not null,'team_filtered',team is not null,'unit_filtered',unit is not null));end if;
 return result||jsonb_build_object('mode',mode,'payment_available',false,'can_create',org is not null and boss_private.fundraising_role(actor,'fundraising.create',org),'money_board_available',org is not null and boss_private.fundraising_module(org,'money_board'));
end$$;
create function public.boss_fundraising_read(query jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.fundraising_read(query)$$;
revoke all on function boss_private.fundraising_raised(uuid,uuid,uuid,uuid),boss_private.fundraising_board_projection(uuid,integer),boss_private.fundraising_public_read(text,integer),public.boss_fundraising_public(text,integer),boss_private.fundraising_read(jsonb),public.boss_fundraising_read(jsonb)from public,anon,authenticated,service_role;
revoke all on function boss_fundraising_public.read(text,integer)from public,anon,authenticated,service_role;
grant execute on function boss_fundraising_public.read(text,integer),public.boss_fundraising_public(text,integer)to anon,authenticated;
grant execute on function boss_private.fundraising_read(jsonb),public.boss_fundraising_read(jsonb)to authenticated;
alter table public.notification_events drop constraint notification_events_source_module_check;
alter table public.notification_events add constraint notification_events_source_module_check check(source_module in('calendar','registration','messaging','volunteers','sports','fundraising'));
-- Existing Communications/Notifications receives low-frequency domain events.
create table boss_private.fundraising_milestones(campaign_id uuid not null references public.fundraising_campaigns(id),kind text not null,scope_id uuid not null,history_id uuid not null references public.fundraising_history(id),primary key(campaign_id,kind,scope_id));
revoke all on boss_private.fundraising_milestones from public,anon,authenticated,service_role;
alter table public.notification_events drop constraint notification_events_source_type_check;
alter table public.notification_events add constraint notification_events_source_type_check check(source_type in('event','registration','registration_document','charge','payment','message','attendance_request','volunteer_shift','volunteer_assignment','volunteer_event','game_operation','tournament_advancement','achievement_history','fundraising_history'));
insert into boss_private.notification_types(key,category,source_module,title,body)values
 ('fundraising.launch','events','fundraising','Fundraiser launched','A campaign is available in Boss Fundraising.'),
 ('fundraising.enrollment','events','fundraising','Fundraiser invitation','A fundraising invitation is available in Family Hub.'),
 ('fundraising.success','fees','fundraising','Support confirmed','Authoritative support was recorded for your fundraiser.'),
 ('fundraising.goal','events','fundraising','Fundraising milestone','A fundraising goal or full board was reached.');
create function boss_private.fundraising_notification_visible(e public.notification_events,actor uuid)returns boolean language sql volatile security definer set search_path=''as $$
 select e.source_type='fundraising_history'and e.source_module='fundraising'and boss_private.notification_person_active(actor)and exists(select 1 from public.fundraising_history h join public.fundraising_campaigns c on c.id=h.campaign_id where h.id=e.source_id and c.organization_id=e.organization_id and boss_private.fundraising_module(c.organization_id,'fundraising')and c.status not in('canceled','archived')and(
 boss_private.fundraising_role(actor,'fundraising.view',c.organization_id)
 or exists(select 1 from public.fundraising_fundraisers f where f.campaign_id=c.id and(h.fundraiser_id is null or f.id=h.fundraiser_id)and(boss_private.fundraising_role(actor,'fundraising.view',f.organization_id,f.unit_id,f.team_id)or boss_private.fundraising_related(actor,f)and(boss_private.fundraising_self(actor,f.person_id,c)or exists(select 1 from public.guardian_relationships g where g.guardian_person_id=actor and g.dependent_person_id=f.person_id and g.can_receive_communications and g.can_manage_fundraising and g.authority_status='active'and g.verified_at<=clock_timestamp()and g.starts_at<=clock_timestamp()and(g.ends_at is null or g.ends_at>clock_timestamp())))))))
$$;
alter function boss_private.notification_source_visible(public.notification_events,uuid)rename to notification_source_visible_phase6e;
create function boss_private.notification_source_visible(p_event public.notification_events,p_person uuid)returns boolean language plpgsql volatile security definer set search_path=''as $$begin if p_event.source_type='fundraising_history'then return boss_private.fundraising_notification_visible(p_event,p_person);end if;return boss_private.notification_source_visible_phase6e(p_event,p_person);end$$;
alter function boss_private.notification_candidates(public.notification_events,uuid,integer)rename to notification_candidates_phase6e;
create function boss_private.notification_candidates(p_event public.notification_events,p_after uuid,p_limit integer)returns table(person_id uuid)language plpgsql volatile security definer set search_path=''as $$begin
 if p_event.source_type<>'fundraising_history'then return query select *from boss_private.notification_candidates_phase6e(p_event,p_after,p_limit);return;end if;
 return query select candidate.person_id from(
 select f.person_id from public.fundraising_history h join public.fundraising_fundraisers f on f.campaign_id=h.campaign_id where h.id=p_event.source_id and(h.fundraiser_id is null or f.id=h.fundraiser_id)
 union select g.guardian_person_id from public.fundraising_history h join public.fundraising_fundraisers f on f.campaign_id=h.campaign_id join public.guardian_relationships g on g.dependent_person_id=f.person_id where h.id=p_event.source_id and(h.fundraiser_id is null or f.id=h.fundraiser_id)and g.can_receive_communications and g.authority_status='active'and g.starts_at<=clock_timestamp()and(g.ends_at is null or g.ends_at>clock_timestamp())
 union select a.person_id from public.role_assignments a where a.organization_id=p_event.organization_id and a.scope_type in('organization','organization_unit','team')and a.status='active'and a.starts_at<=clock_timestamp()and(a.ends_at is null or a.ends_at>clock_timestamp())
 union select c.created_by from public.fundraising_history h join public.fundraising_campaigns c on c.id=h.campaign_id where h.id=p_event.source_id
 )candidate where(p_after is null or candidate.person_id>p_after)and boss_private.fundraising_notification_visible(p_event,candidate.person_id)order by candidate.person_id limit p_limit;
end$$;
alter function boss_private.notification_contexts(public.notification_events,uuid)rename to notification_contexts_phase6e;
create function boss_private.notification_contexts(p_event public.notification_events,p_person uuid)returns jsonb language plpgsql volatile security definer set search_path=''as $$begin if p_event.source_type='fundraising_history'then return jsonb_build_array(jsonb_build_object('kind','fundraising','source_id',p_event.source_id));end if;return boss_private.notification_contexts_phase6e(p_event,p_person);end$$;
alter function boss_private.notification_destination(public.notification_events)rename to notification_destination_phase6e;
create function boss_private.notification_destination(p_event public.notification_events)returns text language plpgsql stable security definer set search_path=''as $$begin if p_event.source_type='fundraising_history'then return'/app/fundraising';end if;return boss_private.notification_destination_phase6e(p_event);end$$;
create function boss_private.fundraising_notification_ingest()returns trigger language plpgsql volatile security definer set search_path=''as $$declare k text;org uuid;begin
 k:=case new.action when'campaign.publish'then'fundraising.launch'when'fundraiser.enroll'then'fundraising.enrollment'when'contribution.trusted_success'then'fundraising.success'when'goal.reached'then'fundraising.goal'when'board.full'then'fundraising.goal'end;
 if k is null then return new;end if;select organization_id into org from public.fundraising_campaigns where id=new.campaign_id;
 perform boss_private.notification_enqueue('fundraising','fundraising_history',new.id,org,k,'1','{}'::jsonb);return new;
end$$;
create trigger fundraising_notification_source after insert on public.fundraising_history for each row execute function boss_private.fundraising_notification_ingest();
create function boss_private.fundraising_milestone_ingest()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare x public.fundraising_intents;c public.fundraising_campaigns;f public.fundraising_fundraisers;scope record;h uuid;begin
 select *into x from public.fundraising_intents where id=new.intent_id;select *into c from public.fundraising_campaigns where id=x.campaign_id;select *into f from public.fundraising_fundraisers where id=x.fundraiser_id;
 for scope in select c.id id,'campaign'kind,c.goal_minor goal,boss_private.fundraising_raised(c.id)raised
 union all select f.id,'fundraiser',f.goal_minor,boss_private.fundraising_raised(c.id,f.id)where f.id is not null and f.goal_minor is not null
 union all select t.id,case when t.team_id is null then'unit'else'team'end,t.goal_minor,boss_private.fundraising_raised(c.id,null,t.team_id,t.unit_id)from public.fundraising_targets t where t.campaign_id=c.id and t.goal_minor is not null
 loop
 if scope.raised>=scope.goal and not exists(select 1 from boss_private.fundraising_milestones where campaign_id=c.id and kind=scope.kind and scope_id=scope.id)then
 insert into public.fundraising_history(campaign_id,fundraiser_id,action,details)values(c.id,case when scope.kind='fundraiser'then f.id end,'goal.reached',jsonb_build_object('scope_kind',scope.kind,'scope_id',scope.id))returning id into h;
 insert into boss_private.fundraising_milestones values(c.id,scope.kind,scope.id,h);
 end if;end loop;
 if x.board_id is not null and(select count(*)from public.fundraising_success_evidence e join public.money_board_tiles t on t.id=e.tile_id where t.board_id=x.board_id)=(select tile_count from public.money_boards where id=x.board_id)and not exists(select 1 from boss_private.fundraising_milestones where campaign_id=c.id and kind='board'and scope_id=x.board_id)then
 insert into public.fundraising_history(campaign_id,fundraiser_id,action,details)values(c.id,f.id,'board.full',jsonb_build_object('board_id',x.board_id))returning id into h;
 insert into boss_private.fundraising_milestones values(c.id,'board',x.board_id,h);end if;return new;
end$$;
create trigger fundraising_success_milestones after insert on public.fundraising_success_evidence for each row execute function boss_private.fundraising_milestone_ingest();
revoke all on function boss_private.fundraising_notification_visible(public.notification_events,uuid),boss_private.notification_source_visible_phase6e(public.notification_events,uuid),boss_private.notification_source_visible(public.notification_events,uuid),boss_private.notification_candidates_phase6e(public.notification_events,uuid,integer),boss_private.notification_candidates(public.notification_events,uuid,integer),boss_private.notification_contexts_phase6e(public.notification_events,uuid),boss_private.notification_contexts(public.notification_events,uuid),boss_private.notification_destination_phase6e(public.notification_events),boss_private.notification_destination(public.notification_events),boss_private.fundraising_notification_ingest(),boss_private.fundraising_milestone_ingest()from public,anon,authenticated,service_role;
-- Extend only two existing operational-core fields; preserve the reviewed
-- INVOKER projection and guardian mutation permission/receipt machinery.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.admin_mutate_command(text,jsonb,uuid,uuid,boolean,uuid)'::regprocedure);
 if position('can_respond_attendance=case' in d)=0 then raise exception'Unexpected guardian mutation checkpoint';end if;
 d:=replace(d,'''can_respond_attendance'']','''can_respond_attendance'',''can_manage_fundraising'']');
 d:=replace(d,'can_manage_profile,can_respond_attendance)','can_manage_profile,can_respond_attendance,can_manage_fundraising)');
 d:=replace(d,'coalesce((i->>''can_respond_attendance'')::boolean,false));','coalesce((i->>''can_respond_attendance'')::boolean,false),coalesce((i->>''can_manage_fundraising'')::boolean,false));');
 d:=replace(d,'else r.can_respond_attendance end where id=v_id','else r.can_respond_attendance end,can_manage_fundraising=case when i?''can_manage_fundraising''then(i->>''can_manage_fundraising'')::boolean else r.can_manage_fundraising end where id=v_id');
 if position('can_manage_fundraising=case' in d)=0 then raise exception'Guardian capability extension not applied';end if;execute d;
 d:=pg_get_functiondef('public.boss_admin_read(text,uuid,text)'::regprocedure);
 if position('''can_respond_attendance'',g.can_respond_attendance' in d)=0 then raise exception'Unexpected guardian projection checkpoint';end if;
 d:=replace(d,'''can_respond_attendance'',g.can_respond_attendance','''can_respond_attendance'',g.can_respond_attendance,''can_manage_fundraising'',g.can_manage_fundraising');
 d:=replace(d,'else ''Future / not implemented'' end','when m.key=''fundraising''then''Implemented: Fundraising core''when m.key=''money_board''then''Implemented: Digital Money Board''else ''Future / not implemented'' end');execute d;
end$$;

-- Bounded, authorized roster choices. No athlete profile or sports dependency.
create function boss_private.fundraising_catalog(actor uuid,org uuid)returns jsonb language sql volatile security definer set search_path=''as $$
 select jsonb_build_object(
 'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name))from(select id,name from public.organization_units where organization_id=org and status='active'and boss_private.fundraising_role(actor,'fundraising.view',org,id)order by name,id limit 200)u),'[]'),
 'teams',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'name',t.name))from(select id,name from public.teams where organization_id=org and status='active'and boss_private.fundraising_role(actor,'fundraising.view',org,parent_unit_id,id)order by name,id limit 200)t),'[]'),
 'participants',case when boss_private.fundraising_role(actor,'fundraising.manage',org)then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.display_name,'team_id',p.team_id))from(select distinct a.id,coalesce(person.display_name,'Participant')display_name,m.team_id from public.participants a join public.people person on person.id=a.person_id and person.status='active'join public.organization_memberships om on om.person_id=a.person_id and om.organization_id=org and om.status='active'and om.starts_at<=clock_timestamp()and(om.ends_at is null or om.ends_at>clock_timestamp())left join public.team_memberships m on m.participant_id=a.id and m.person_id=a.person_id and m.organization_id=org and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp())where a.status='active'order by a.id,m.team_id limit 200)p),'[]')else'[]'::jsonb end)
$$;
revoke all on function boss_private.fundraising_catalog(uuid,uuid)from public,anon,authenticated,service_role;
-- Recompile the existing read with catalog metadata; no extra Data API endpoint.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.fundraising_read(jsonb)'::regprocedure);
 d:=replace(d,'return result||jsonb_build_object(', 'return result||jsonb_build_object(''catalog'',boss_private.fundraising_catalog(actor,org),');execute d;
end$$;
-- FK and origin lookup indexes; transaction locks stay at campaign -> fundraiser
-- -> board -> tile/reservation -> intent. All supporter responses remain bounded.
create index fundraising_targets_org_campaign_idx on public.fundraising_targets(organization_id,campaign_id);
create index fundraising_fundraisers_org_campaign_idx on public.fundraising_fundraisers(organization_id,campaign_id);
create index fundraising_fundraisers_participant_idx on public.fundraising_fundraisers(participant_id,person_id);
create index fundraising_fundraisers_unit_idx on public.fundraising_fundraisers(organization_id,unit_id);
create index fundraising_fundraisers_team_idx on public.fundraising_fundraisers(organization_id,team_id);
create index fundraising_fundraisers_household_idx on public.fundraising_fundraisers(household_id);
create index fundraising_intents_donor_idx on public.fundraising_intents(donor_id);
create index fundraising_intents_tile_idx on public.fundraising_intents(tile_id);
create index fundraising_intents_board_idx on public.fundraising_intents(board_id);
create index fundraising_intents_share_idx on public.fundraising_intents(share_id);
create index fundraising_success_evidence_tile_idx on public.fundraising_success_evidence(tile_id);
create index fundraising_intent_events_lineage_idx on public.fundraising_intent_events(source_event_id);
create index fundraising_campaigns_creator_idx on public.fundraising_campaigns(created_by);
create index fundraising_history_actor_idx on public.fundraising_history(actor_person_id);
create function boss_private.fundraising_navigation()returns boolean language plpgsql volatile security definer set search_path=''as $$declare actor uuid;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 return exists(select 1 from public.organization_modules m join public.modules c on c.id=m.module_id and c.key='fundraising'where boss_private.fundraising_module(m.organization_id,'fundraising')and boss_private.fundraising_role(actor,'fundraising.view',m.organization_id))
 or exists(select 1 from public.fundraising_fundraisers f where boss_private.fundraising_module(f.organization_id,'fundraising')and boss_private.fundraising_related(actor,f))
 or exists(select 1 from public.role_assignments a join public.teams t on t.id=a.scope_id and a.scope_type='team'where a.person_id=actor and boss_private.fundraising_module(t.organization_id,'fundraising')and boss_private.fundraising_role(actor,'fundraising.view',t.organization_id,t.parent_unit_id,t.id));
end$$;
create function public.boss_fundraising_navigation()returns boolean language sql volatile security invoker set search_path=''as $$select boss_private.fundraising_navigation()$$;
revoke all on function boss_private.fundraising_navigation(),public.boss_fundraising_navigation()from public,anon,authenticated,service_role;
grant execute on function boss_private.fundraising_navigation(),public.boss_fundraising_navigation()to authenticated;

create index fundraising_targets_org_team_idx on public.fundraising_targets(organization_id,team_id);
create index fundraising_targets_org_unit_idx on public.fundraising_targets(organization_id,unit_id);
create index fundraising_shares_fundraiser_idx on public.fundraising_shares(fundraiser_id);
create index money_board_tiles_generation_idx on public.money_board_tiles(generation_id);
create index fundraising_receipts_campaign_idx on boss_private.fundraising_receipts(campaign_id);
create index fundraising_milestones_history_idx on boss_private.fundraising_milestones(history_id);
alter table boss_private.fundraising_receipts enable row level security;
alter table boss_private.fundraising_guest_receipts enable row level security;
alter table boss_private.fundraising_rate_windows enable row level security;
alter table boss_private.fundraising_milestones enable row level security;

create index fundraising_targets_campaign_idx on public.fundraising_targets(campaign_id);
create index fundraising_intents_reservation_full_idx on public.fundraising_intents(reservation_id);
