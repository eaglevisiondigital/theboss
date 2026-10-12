create function boss_private.fundraising_mutate(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare actor uuid;request uuid;i jsonb;action text;h text;receipt boss_private.fundraising_receipts;c public.fundraising_campaigns;f public.fundraising_fundraisers;b public.money_boards;
 org uuid;resource uuid;subject uuid;team uuid;unit uuid;p public.participants;target jsonb;result jsonb;gen uuid;targets jsonb;entries jsonb;entry jsonb;counted integer:=0;v_generation bigint;generated integer;share public.fundraising_shares;
begin
 perform boss_private.games_require_live_auth();actor:=boss_private.current_person_id();
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);action:=command->>'action';request:=boss_private.athlete_uuid(command,'request_id');i:=command->'input';h:=encode(sha256(convert_to(command::text,'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-request:'||actor||':'||request,0));
 if action='campaign.create'then
 perform boss_private.athlete_input(i,array['organization_id','name','description','currency','goal_minor','starts_at','ends_at','launch_at','scope','targets','channels','allow_anonymous','allow_recurring','allow_fee_cover','allow_team_sharing','allow_adult_self_sharing','leaderboard_visibility','indexable','branding','reward_policy'],array['organization_id','name','currency','goal_minor','starts_at','ends_at','scope']);
 org:=boss_private.athlete_uuid(i,'organization_id');perform boss_private.fundraising_fence(org,actor);perform boss_private.games_require_live_auth();
 if not boss_private.fundraising_module(org,'fundraising')or not boss_private.fundraising_role(actor,'fundraising.create',org)then raise exception'Access denied'using errcode='PT403';end if;
 select *into receipt from boss_private.fundraising_receipts where actor_person_id=actor and request_id=request;
 if receipt.actor_person_id is not null then if receipt.input_hash<>h then raise exception'Request conflict'using errcode='PT409';end if;return receipt.result||'{"replayed":true}'::jsonb;end if;
 targets:=coalesce(i->'targets','[]');if jsonb_typeof(targets)<>'array'or jsonb_array_length(targets)>200 or(i->>'scope'='selected'and jsonb_array_length(targets)=0)then raise exception'Explicit targets required'using errcode='PT422';end if;
 if not boss_private.fundraising_reward_valid(coalesce(i->'reward_policy','{}'),i->>'currency')or exists(select 1 from jsonb_object_keys(coalesce(i->'branding','{}'))k where k<>all(array['headline','logo_url']))or coalesce(i->'branding'->>'logo_url','')!~'^(|https://[^[:space:]<>]+)$'or length(coalesce(i->'branding'->>'headline',''))>180 then raise exception'Invalid campaign policy'using errcode='PT422';end if;
 insert into public.fundraising_campaigns(organization_id,name,description,currency,goal_minor,starts_at,ends_at,launch_at,scope,channels,allow_anonymous,allow_recurring,allow_fee_cover,allow_team_sharing,allow_adult_self_sharing,leaderboard_visibility,indexable,branding,reward_policy,created_by)
 values(org,btrim(i->>'name'),coalesce(i->>'description',''),i->>'currency',(i->>'goal_minor')::bigint,(i->>'starts_at')::timestamptz,(i->>'ends_at')::timestamptz,(i->>'launch_at')::timestamptz,i->>'scope',case when i?'channels'then array(select jsonb_array_elements_text(i->'channels'))else array['direct_support']end,coalesce((i->>'allow_anonymous')::boolean,true),coalesce((i->>'allow_recurring')::boolean,false),coalesce((i->>'allow_fee_cover')::boolean,false),coalesce((i->>'allow_team_sharing')::boolean,false),coalesce((i->>'allow_adult_self_sharing')::boolean,false),coalesce(i->>'leaderboard_visibility','disabled'),coalesce((i->>'indexable')::boolean,false),coalesce(i->'branding','{}'),coalesce(i->'reward_policy','{}'),actor)returning *into c;
 for target in select value from jsonb_array_elements(targets)loop
 perform boss_private.athlete_input(target,array['team_id','unit_id','goal_minor']);team:=boss_private.athlete_uuid(target,'team_id');unit:=boss_private.athlete_uuid(target,'unit_id');
 if num_nonnulls(team,unit)<>1 or team is not null and not exists(select 1 from public.teams where id=team and organization_id=org and status='active')or unit is not null and not exists(select 1 from public.organization_units where id=unit and organization_id=org and status='active')then raise exception'Invalid exact target'using errcode='PT422';end if;
 insert into public.fundraising_targets(campaign_id,organization_id,team_id,unit_id,goal_minor)values(c.id,org,team,unit,(target->>'goal_minor')::bigint);
 end loop;result:=jsonb_build_object('campaign_id',c.id,'version',c.version);
 else
 perform boss_private.athlete_input(i,case action
 when 'campaign.publish'then array['campaign_id','expected_version'] when 'campaign.status'then array['campaign_id','expected_version','status']
 when 'fundraiser.enroll'then array['campaign_id','entries'] when 'fundraiser.accept'then array['campaign_id','fundraiser_id','display_name','leaderboard_opt_in']
 when 'fundraiser.end'then array['campaign_id','fundraiser_id'] when 'share.create'then array['campaign_id','fundraiser_id'] when 'share.reset'then array['campaign_id','fundraiser_id']
 when 'board.create'then array['campaign_id','fundraiser_id','team_id','title','goal_minor','start_minor','increment_minor','tile_count','reservation_seconds','visibility']
 when 'board.configure'then array['campaign_id','board_id','expected_version','title','goal_minor','start_minor','increment_minor','tile_count','reservation_seconds','visibility']
 when 'board.generate'then array['campaign_id','board_id','expected_version'] when 'board.publish'then array['campaign_id','board_id','expected_version'] when 'board.archive'then array['campaign_id','board_id','expected_version']
 else array[]::text[] end,array['campaign_id']);
 select *into c from public.fundraising_campaigns where id=boss_private.athlete_uuid(i,'campaign_id')for update;
 if c.id is null then raise exception'Resource unavailable'using errcode='PT404';end if;org:=c.organization_id;
 if i?'fundraiser_id'then select *into f from public.fundraising_fundraisers where id=boss_private.athlete_uuid(i,'fundraiser_id')and campaign_id=c.id for update;if f.id is null then raise exception'Resource unavailable'using errcode='PT404';end if;end if;
 perform boss_private.fundraising_fence(org,actor,f.person_id);perform boss_private.games_require_live_auth();
 if not boss_private.fundraising_module(org,'fundraising')then raise exception'Module unavailable'using errcode='PT403';end if;
 if action in('share.create','share.reset','fundraiser.accept')then
 if f.id is null or not(boss_private.fundraising_guardian(actor,f.person_id)or boss_private.fundraising_self(actor,f.person_id,c))then raise exception'Access denied'using errcode='PT403';end if;
 elsif not boss_private.fundraising_role(actor,case when action like'board.%'then'money_board.manage'when action='campaign.publish'then'fundraising.publish'else'fundraising.manage'end,org)then raise exception'Access denied'using errcode='PT403';end if;
 select *into receipt from boss_private.fundraising_receipts where actor_person_id=actor and request_id=request;
 if receipt.actor_person_id is not null then if receipt.input_hash<>h then raise exception'Request conflict'using errcode='PT409';end if;return receipt.result||'{"replayed":true}'::jsonb;end if;
 if c.status in('completed','canceled','archived')and action<>'campaign.status'then raise exception'Campaign ended'using errcode='PT409';end if;
 if action in('campaign.status','campaign.publish')then
 if(i->>'expected_version')::bigint is distinct from c.version then raise exception'Stale campaign version'using errcode='PT409';end if;
 if action='campaign.publish'then
 if not(c.channels&&array['direct_support','money_board'])or c.ends_at<=clock_timestamp()or c.status not in('draft','scheduled','paused')then raise exception'Campaign cannot launch'using errcode='PT409';end if;
 update public.fundraising_campaigns set status=case when starts_at>clock_timestamp()then'scheduled'else'active'end,public_visible=true,launch_at=coalesce(launch_at,clock_timestamp()),version=version+1,updated_at=clock_timestamp()where id=c.id returning *into c;
 else
 if i->>'status'not in('active','paused','completed','canceled','archived')or c.status='archived'or i->>'status'='active'and(c.status not in('paused','scheduled')or c.ends_at<=clock_timestamp())then raise exception'Invalid lifecycle transition'using errcode='PT422';end if;
 update public.fundraising_campaigns set status=i->>'status',public_visible=case when i->>'status'='active'then public_visible else false end,version=version+1,updated_at=clock_timestamp()where id=c.id returning *into c;
 if c.status='archived'then
 update public.fundraising_fundraisers set status='archived',ends_at=greatest(clock_timestamp(),starts_at+interval'1 microsecond'),version=version+1 where campaign_id=c.id and status<>'archived';
 update public.fundraising_shares set status='revoked',revoked_at=clock_timestamp()where fundraiser_id in(select id from public.fundraising_fundraisers where campaign_id=c.id)and status='active';
 update public.money_boards set status='archived',version=version+1 where campaign_id=c.id and status<>'archived';
 update public.money_board_reservations set released_at=clock_timestamp(),release_reason='archived'where tile_id in(select t.id from public.money_board_tiles t join public.money_boards mb on mb.id=t.board_id where mb.campaign_id=c.id)and released_at is null;
 insert into public.fundraising_intent_events(intent_id,state)select x.id,'canceled'from public.fundraising_intents x where x.campaign_id=c.id and not exists(select 1 from public.fundraising_intent_events e where e.intent_id=x.id and e.state<>'awaiting_payment');
 update public.fundraising_recurring_commitments set status='canceled'where intent_id in(select id from public.fundraising_intents where campaign_id=c.id)and status='planned';
 end if;end if;result:=jsonb_build_object('campaign_id',c.id,'version',c.version,'status',c.status);
 elsif action='fundraiser.enroll'then
 entries:=i->'entries';if jsonb_typeof(entries)is distinct from'array'or jsonb_array_length(entries)not between 1 and 200 then raise exception'Enrollment batch must contain 1 to 200 participants'using errcode='PT422';end if;
 for entry in select value from jsonb_array_elements(entries)loop
 perform boss_private.athlete_input(entry,array['participant_id','team_id','unit_id','goal_minor'],array['participant_id']);
 select *into p from public.participants where id=boss_private.athlete_uuid(entry,'participant_id')and status='active'for share;
 team:=boss_private.athlete_uuid(entry,'team_id');unit:=boss_private.athlete_uuid(entry,'unit_id');
 if team is not null then select parent_unit_id into unit from public.teams where id=team and organization_id=org and status='active';if not found then raise exception'Invalid team context'using errcode='PT422';end if;end if;
 perform boss_private.fundraising_fence(org,actor,p.person_id);
 if p.id is null or not exists(select 1 from public.organization_memberships m where m.organization_id=org and m.person_id=p.person_id and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))or team is not null and not exists(select 1 from public.team_memberships m where m.team_id=team and m.participant_id=p.id and m.person_id=p.person_id and m.status='active'and m.starts_at<=clock_timestamp()and(m.ends_at is null or m.ends_at>clock_timestamp()))or c.scope='selected'and not exists(select 1 from public.fundraising_targets t where t.campaign_id=c.id and(t.team_id=team or team is null and t.unit_id=unit))then raise exception'Participant is outside campaign scope'using errcode='PT403';end if;
 if unit is not null and not exists(select 1 from public.organization_units where id=unit and organization_id=org and status='active')then raise exception'Invalid program context'using errcode='PT422';end if;
 insert into public.fundraising_fundraisers(organization_id,campaign_id,participant_id,person_id,unit_id,team_id,goal_minor)values(org,c.id,p.id,p.person_id,unit,team,(entry->>'goal_minor')::bigint)on conflict(campaign_id,participant_id)do nothing;counted:=counted+1;
 end loop;result:=jsonb_build_object('campaign_id',c.id,'processed',counted);
 elsif action='fundraiser.accept'then
 if f.status not in('pending','active')or f.ends_at is not null and f.ends_at<=clock_timestamp()then raise exception'Participation ended'using errcode='PT409';end if;
 update public.fundraising_fundraisers set status='active',public_display_name=btrim(i->>'display_name'),leaderboard_opt_in=coalesce((i->>'leaderboard_opt_in')::boolean,false),version=version+1 where id=f.id returning *into f;
 if f.public_display_name is null or not boss_private.fundraising_member(f)then raise exception'Eligible participation required'using errcode='PT403';end if;
 result:=jsonb_build_object('campaign_id',c.id,'fundraiser_id',f.id,'version',f.version);
 elsif action='fundraiser.end'then
 if f.id is null then raise exception'Resource unavailable'using errcode='PT404';end if;
 update public.fundraising_fundraisers set status='ended',ends_at=greatest(clock_timestamp(),starts_at+interval'1 microsecond'),version=version+1 where id=f.id;
 update public.fundraising_shares set status='revoked',revoked_at=clock_timestamp()where fundraiser_id=f.id and status='active';result:=jsonb_build_object('campaign_id',c.id,'fundraiser_id',f.id);
 elsif action in('share.create','share.reset')then
 if not boss_private.fundraising_member(f)or f.public_display_name is null then raise exception'Participation unavailable'using errcode='PT403';end if;
 if action='share.reset'then update public.fundraising_shares set status='revoked',revoked_at=clock_timestamp()where fundraiser_id=f.id and status='active';end if;
 select *into share from public.fundraising_shares where fundraiser_id=f.id and status='active';
 if share.id is null then insert into public.fundraising_shares(fundraiser_id,authorized_by)values(f.id,actor)returning *into share;end if;
 result:=jsonb_build_object('campaign_id',c.id,'fundraiser_id',f.id,'path',share.path);
 elsif action='board.create'then
 if not boss_private.fundraising_module(org,'money_board')or not('money_board'=any(c.channels))then raise exception'Money Board unavailable'using errcode='PT403';end if;
 team:=boss_private.athlete_uuid(i,'team_id');if team is not null and(not exists(select 1 from public.teams where id=team and organization_id=org and status='active')or c.scope='selected'and not exists(select 1 from public.fundraising_targets where campaign_id=c.id and team_id=team))then raise exception'Invalid board team'using errcode='PT403';end if;
 insert into public.money_boards(campaign_id,fundraiser_id,team_id,title,goal_minor,start_minor,increment_minor,tile_count,reservation_seconds,visibility)values(c.id,f.id,team,i->>'title',(i->>'goal_minor')::bigint,(i->>'start_minor')::bigint,(i->>'increment_minor')::bigint,(i->>'tile_count')::int,coalesce((i->>'reservation_seconds')::int,600),coalesce(i->>'visibility','private'))returning *into b;
 result:=jsonb_build_object('campaign_id',c.id,'board_id',b.id,'version',b.version);
 elsif action in('board.configure','board.generate','board.publish','board.archive')then
 select *into b from public.money_boards where id=boss_private.athlete_uuid(i,'board_id')and campaign_id=c.id for update;
 if b.id is null then raise exception'Resource unavailable'using errcode='PT404';end if;
 if not boss_private.fundraising_module(org,'money_board')then raise exception'Money Board unavailable'using errcode='PT403';end if;
 if(i->>'expected_version')::bigint is distinct from b.version then raise exception'Stale board version'using errcode='PT409';end if;
 if action in('board.configure','board.generate')then
 if exists(select 1 from public.fundraising_success_evidence e join public.money_board_tiles t on t.id=e.tile_id where t.board_id=b.id)or exists(select 1 from public.money_board_reservations r join public.money_board_tiles t on t.id=r.tile_id where t.board_id=b.id and r.released_at is null and r.expires_at>clock_timestamp())then raise exception'Claimed or reserved board cannot regenerate'using errcode='PT409';end if;
 if b.status='archived'then raise exception'Board ended'using errcode='PT409';end if;
 if action='board.configure'then
 update public.money_boards set title=i->>'title',goal_minor=(i->>'goal_minor')::bigint,start_minor=(i->>'start_minor')::bigint,increment_minor=(i->>'increment_minor')::bigint,tile_count=(i->>'tile_count')::int,reservation_seconds=(i->>'reservation_seconds')::int,visibility=i->>'visibility'where id=b.id returning *into b;
 end if;
 select id,g.generation into gen,v_generation from public.money_board_generations g where g.board_id=b.id order by g.generation desc limit 1;
 generated:=coalesce((select max(ordinal)from public.money_board_tiles where generation_id=gen),0);
 if gen is null or generated=b.tile_count or action='board.configure'then
 v_generation:=coalesce(v_generation,0)+1;generated:=0;
 insert into public.money_board_generations(board_id,generation,start_minor,increment_minor,tile_count)values(b.id,v_generation,b.start_minor,b.increment_minor,b.tile_count)returning id into gen;
 end if;
 insert into public.money_board_tiles(board_id,generation_id,ordinal,amount_minor)select b.id,gen,n,b.start_minor+(n-1)::bigint*b.increment_minor from generate_series(generated+1,least(b.tile_count::bigint,generated::bigint+10000)::integer)n;
 generated:=least(b.tile_count::bigint,generated::bigint+10000)::integer;
 elsif action='board.publish'then
 if (select count(*)from public.money_board_tiles where board_id=b.id and generation_id=(select gg.id from public.money_board_generations gg where gg.board_id=b.id order by gg.generation desc limit 1))<>b.tile_count then raise exception'Generate board before publication'using errcode='PT409';end if;
 end if;
 update public.money_boards set status=case action when'board.publish'then'published'when'board.archive'then'archived'else'draft'end,version=version+1 where id=b.id returning *into b;
 result:=jsonb_build_object('campaign_id',c.id,'board_id',b.id,'version',b.version,'status',b.status,'generated_count',generated);
 else raise exception'Unsupported fundraising action'using errcode='PT422';end if;
 end if;
 perform boss_private.fundraising_audit(actor,c.id,f.id,action,request,jsonb_strip_nulls(result-'path'));
 result:=result||jsonb_build_object('action',action,'request_id',request);
 insert into boss_private.fundraising_receipts(actor_person_id,request_id,input_hash,campaign_id,result)values(actor,request,h,c.id,result);
 return result||jsonb_build_object('action',action,'request_id',request,'replayed',false);
 exception when invalid_text_representation or numeric_value_out_of_range or check_violation then raise exception'Invalid fundraising input'using errcode='PT422';when unique_violation then raise exception'Duplicate fundraising resource'using errcode='PT409';
end$$;
create function public.boss_fundraising_mutate(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_private.fundraising_mutate(command)$$;
revoke all on function boss_private.fundraising_mutate(jsonb),public.boss_fundraising_mutate(jsonb)from public,anon,authenticated,service_role;
grant execute on function boss_private.fundraising_mutate(jsonb),public.boss_fundraising_mutate(jsonb)to authenticated;
