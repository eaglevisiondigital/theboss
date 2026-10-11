-- Exact unit/ministry/project destinations; preserve original board rows and UI.
alter table public.money_boards add column unit_id uuid references public.organization_units(id);
alter table public.money_boards drop constraint money_boards_campaign_id_fundraiser_id_team_id_key;
alter table public.money_boards add constraint money_boards_exact_destination_key unique nulls not distinct(campaign_id,fundraiser_id,team_id,unit_id);
alter table public.money_boards add constraint money_boards_unit_destination_check check(unit_id is null or num_nonnulls(fundraiser_id,team_id)=0);
create index money_boards_unit_campaign_idx on public.money_boards(unit_id,campaign_id);
create trigger money_boards_unit_identity before update on public.money_boards for each row execute function boss_private.preserve_row_identity('unit_id');
-- The organization page must not accidentally select a newly added ministry board.
do $$declare d text;needle text:='and fundraiser_id is null and team_id is null and status=';begin
 d:=pg_get_functiondef('boss_private.fundraising_public_context(text)'::regprocedure);
 if position(needle in d)=0 then raise exception'Public board checkpoint mismatch';end if;
 execute replace(d,needle,'and fundraiser_id is null and team_id is null and unit_id is null and status=');
end$$;
do $$declare d text;needle text:='cross join lateral(values(s.path),(b.public_path),(c.public_path))';begin
 d:=pg_get_functiondef('boss_private.money_board_cart_path(uuid)'::regprocedure);
 if position(needle in d)=0 then raise exception'Destination cart path checkpoint mismatch';end if;
 d:=replace(d,'cross join lateral(values(s.path)','left join public.fundraising_destinations fd on fd.id=(x.context->>''destination_id'')::uuid cross join lateral(values(fd.public_path),(s.path)');execute d;
end$$;
alter function boss_private.fundraising_public_context(text)rename to fundraising_public_context_before_destinations;
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.fundraising_public_context_before_destinations(text)'::regprocedure);
 execute replace(d,'fundraising_public_context.path','fundraising_public_context_before_destinations.path');
end$$;
create function boss_private.fundraising_public_context(path text)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare d public.fundraising_destinations;c public.fundraising_campaigns;f public.fundraising_fundraisers;
 b public.money_boards;s public.fundraising_shares;ctx jsonb;begin
 select *into d from public.fundraising_destinations where public_path=path;
 if d.id is null then
  ctx:=boss_private.fundraising_public_context_before_destinations(path);
  select *into b from public.money_boards where id=(ctx->>'board_id')::uuid;
  return jsonb_strip_nulls(ctx||jsonb_build_object('unit_id',b.unit_id));
 end if;
 select *into c from public.fundraising_campaigns where id=d.campaign_id;
 if d.status<>'published'or d.starts_at>clock_timestamp()or d.ends_at<=clock_timestamp()or not boss_private.fundraising_active(c)
 or d.team_id is not null and not exists(select 1 from public.teams where id=d.team_id and organization_id=d.organization_id and status='active')
 or d.unit_id is not null and not exists(select 1 from public.organization_units where id=d.unit_id and organization_id=d.organization_id and status='active')
 or d.referrer_person_id is not null and not exists(select 1 from public.organization_memberships m join public.people p on p.id=m.person_id and p.status='active'where m.person_id=d.referrer_person_id and m.organization_id=d.organization_id and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))
 then raise exception'Destination unavailable'using errcode='PT404';end if;
 if d.fundraiser_id is not null then
  select *into f from public.fundraising_fundraisers where id=d.fundraiser_id;
  select *into s from public.fundraising_shares where fundraiser_id=f.id and status='active';
  if not boss_private.fundraising_member(f)or s.id is null or not(boss_private.fundraising_guardian(s.authorized_by,f.person_id)or boss_private.fundraising_self(s.authorized_by,f.person_id,c))then raise exception'Destination unavailable'using errcode='PT404';end if;
 end if;
 select *into b from public.money_boards where id=d.board_id and status='published'and visibility='public';
 if b.id is not null and not boss_private.fundraising_module(d.organization_id,'money_board')then b:=null;end if;
 return jsonb_strip_nulls(jsonb_build_object('campaign_id',c.id,'board_id',b.id,'fundraiser_id',f.id,'share_id',s.id,'person_id',f.person_id,'authorized_by',s.authorized_by,
 'team_id',d.team_id,'unit_id',coalesce(f.unit_id,d.unit_id),'destination_id',d.id,'referrer_person_id',d.referrer_person_id));
end$$;
-- Enrich only server-created provenance; browser input remains finite and unchanged.
do $$declare d text;begin
 d:=pg_get_functiondef('boss_private.money_board_context(text)'::regprocedure);
 execute replace(d,'''unit_id'',f.unit_id','''unit_id'',coalesce(f.unit_id,(ctx->>''unit_id'')::uuid)');
 d:=pg_get_functiondef('boss_private.money_board_provenance(uuid)'::regprocedure);
 execute replace(d,'''unit_id'',f.unit_id','''unit_id'',coalesce(f.unit_id,b.unit_id)');
 d:=pg_get_functiondef('boss_private.fundraising_guest(jsonb)'::regprocedure);
 if position('''unit_id'',f.unit_id'in d)=0 then raise exception'Guest destination checkpoint mismatch';end if;
 d:=replace(d,'''team_id'',coalesce(f.team_id,b.team_id)', '''team_id'',coalesce(f.team_id,b.team_id,(ctx->>''team_id'')::uuid)');
 d:=replace(d,'''unit_id'',f.unit_id','''unit_id'',coalesce(f.unit_id,(ctx->>''unit_id'')::uuid)');
 d:=replace(d,'''source_kind'',attribution,''board_id''','''destination_id'',ctx->>''destination_id'',''referrer_person_id'',ctx->>''referrer_person_id'',''source_kind'',attribution,''board_id''');
 execute d;
end$$;
create function boss_private.fundraising_destination_command(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_column
declare actor uuid;action text;i jsonb;c public.fundraising_campaigns;team uuid;unit uuid;f public.fundraising_fundraisers;
 b public.money_boards;d public.fundraising_destinations;request uuid;id uuid;prior boss_private.fundraising_allocation_requests;result jsonb;begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);
 action:=command->>'action';i:=command->'input';request:=boss_private.athlete_uuid(command,'request_id');
 if action not in('destination.create','destination.publish','destination.archive','unit_board.create')then raise exception'Unknown destination action'using errcode='PT422';end if;
 select *into c from public.fundraising_campaigns where id=(i->>'campaign_id')::uuid for update;
 team:=(i->>'team_id')::uuid;unit:=(i->>'unit_id')::uuid;
 if action in('destination.publish','destination.archive')then
  select *into d from public.fundraising_destinations where fundraising_destinations.id=(i->>'destination_id')::uuid and campaign_id=c.id for update;
  team:=d.team_id;unit:=d.unit_id;if d.id is null then raise exception'Exact destination required'using errcode='PT403';end if;
 end if;
 perform boss_private.fundraising_fence(c.organization_id,actor);
 if not boss_private.fundraising_allocation_manage(actor,c.id,team,unit)or action='destination.publish'and not boss_private.fundraising_role(actor,'fundraising.publish',c.organization_id)
 then raise exception'Exact destination authority required'using errcode='PT403';end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-allocation-request:'||request,0));
 select *into prior from boss_private.fundraising_allocation_requests where request_id=request;
 if prior.request_id is not null then if prior.actor_id<>actor or prior.command<>command then raise exception'Destination replay conflict'using errcode='PT409';end if;return prior.result||'{"replayed":true}';end if;
 if action='unit_board.create'then
  perform boss_private.athlete_input(i,array['campaign_id','unit_id','title','goal_minor','start_minor','increment_minor','tile_count','reservation_seconds','visibility'],array['campaign_id','unit_id','title','goal_minor','start_minor','increment_minor','tile_count']);
  if not boss_private.fundraising_role(actor,'money_board.manage',c.organization_id)or not boss_private.fundraising_module(c.organization_id,'money_board')or not('money_board'=any(c.channels))then raise exception'Board configuration authority required'using errcode='PT403';end if;
  insert into public.money_boards(campaign_id,unit_id,title,goal_minor,start_minor,increment_minor,tile_count,reservation_seconds,visibility)
  values(c.id,unit,i->>'title',(i->>'goal_minor')::bigint,(i->>'start_minor')::bigint,(i->>'increment_minor')::bigint,(i->>'tile_count')::int,coalesce((i->>'reservation_seconds')::int,600),coalesce(i->>'visibility','private'))returning *into b;id:=b.id;
 elsif action='destination.create'then
  perform boss_private.athlete_input(i,array['campaign_id','kind','team_id','unit_id','board_id','fundraiser_id','referrer_person_id','goal_minor','starts_at','ends_at'],array['campaign_id','kind','goal_minor']);
  select *into f from public.fundraising_fundraisers where fundraising_fundraisers.id=(i->>'fundraiser_id')::uuid;
  if i->>'fundraiser_id'is not null and(f.id is null or f.campaign_id<>c.id or f.team_id is distinct from team or f.unit_id is distinct from case when team is null then unit else(select parent_unit_id from public.teams where id=team)end)then raise exception'Exact participant designation required'using errcode='PT403';end if;
  select *into b from public.money_boards where money_boards.id=(i->>'board_id')::uuid;
  if i->>'board_id'is not null and(b.id is null or b.campaign_id<>c.id or b.fundraiser_id is distinct from f.id or b.team_id is distinct from case when f.id is null then team end or b.unit_id is distinct from case when f.id is null then unit end)then raise exception'Exact board destination required'using errcode='PT403';end if;
  if i->>'referrer_person_id'is not null and not exists(select 1 from public.organization_memberships m join public.people p on p.id=m.person_id and p.status='active'where m.organization_id=c.organization_id and m.person_id=(i->>'referrer_person_id')::uuid and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))then raise exception'Exact referrer membership required'using errcode='PT403';end if;
  insert into public.fundraising_destinations(organization_id,campaign_id,kind,team_id,unit_id,board_id,fundraiser_id,referrer_person_id,goal_minor,starts_at,ends_at,created_by)
  values(c.organization_id,c.id,i->>'kind',team,unit,b.id,f.id,(i->>'referrer_person_id')::uuid,(i->>'goal_minor')::bigint,coalesce((i->>'starts_at')::timestamptz,clock_timestamp()),(i->>'ends_at')::timestamptz,actor)returning *into d;id:=d.id;
 else
  perform boss_private.athlete_input(i,array['campaign_id','destination_id'],array['campaign_id','destination_id']);
  if d.status='archived'then raise exception'Destination already archived'using errcode='PT409';end if;
  update public.fundraising_destinations set status=case action when'destination.publish'then'published'else'archived'end where fundraising_destinations.id=d.id;id:=d.id;
 end if;
 result:=jsonb_strip_nulls(jsonb_build_object('id',id,'path',d.public_path,'version',b.version,'action',action,'replayed',false));
 insert into boss_private.fundraising_allocation_requests(request_id,actor_id,command,result)values(request,actor,command,result);
 perform boss_private.fundraising_audit(actor,c.id,f.id,'fundraising.'||action,request,result-'path');return result;
exception when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation then raise exception'Invalid destination input'using errcode='PT422';when unique_violation then raise exception'Destination conflict'using errcode='PT409';end$$;
do $$declare d text;needle text:='action:=command->>''action'';i:=command->''input'';request:=boss_private.athlete_uuid(command,''request_id'');';begin
 d:=pg_get_functiondef('boss_private.fundraising_allocation_command(jsonb)'::regprocedure);
 if position(needle in d)=0 then raise exception'Allocation command destination checkpoint mismatch';end if;
 execute replace(d,needle,needle||'if action in(''destination.create'',''destination.publish'',''destination.archive'',''unit_board.create'')then return boss_private.fundraising_destination_command(command);end if;');
end$$;
-- Public scope projection contains no private referrer/person identifiers.
alter function boss_private.fundraising_public_read(text,integer)rename to fundraising_public_read_before_destinations;
create function boss_private.fundraising_public_read(path text,offset_ordinal integer default 0)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare r jsonb;d public.fundraising_destinations;ctx jsonb;begin
 r:=boss_private.fundraising_public_read_before_destinations(path,offset_ordinal);
 ctx:=boss_private.fundraising_public_context(path);select *into d from public.fundraising_destinations where id=(ctx->>'destination_id')::uuid;
 if d.id is null then return r;end if;
 r:=jsonb_set(r,'{campaign,goal_minor}',to_jsonb(d.goal_minor));
 r:=jsonb_set(r,'{campaign,raised_minor}',to_jsonb(boss_private.fundraising_raised(d.campaign_id,d.fundraiser_id,d.team_id,d.unit_id)));
 return r||jsonb_build_object('leaderboard','[]'::jsonb,'supporters',coalesce((select jsonb_agg(jsonb_build_object('display_name',case when i.anonymous then'Anonymous'else donor.display_name end,'amount_minor',e.amount_minor,'date',e.settled_at)order by e.settled_at)
 from(select *from public.fundraising_success_evidence where intent_id in(select id from public.fundraising_intents where campaign_id=d.campaign_id and provenance->>'destination_id'=d.id::text)order by settled_at desc limit 20)e
 join public.fundraising_intents i on i.id=e.intent_id join public.fundraising_donors donor on donor.id=i.donor_id),'[]'::jsonb));
end$$;
do $$declare p record;begin for p in select oid::regprocedure sig from pg_proc where pronamespace='boss_private'::regnamespace and(proname like'fundraising_%'or proname in('money_board_context','money_board_provenance'))loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role,boss_payment_worker',p.sig);end loop;end$$;
grant execute on function boss_private.fundraising_allocation_command(jsonb),boss_private.fundraising_read(jsonb),boss_private.fundraising_mutate(jsonb),boss_private.fundraising_navigation()to authenticated;
