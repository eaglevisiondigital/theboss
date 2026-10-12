-- Volleyball owns only matches whose canonical sport is volleyball.
-- No new identity, schedule, operator or public mutation surface.
create table public.game_volleyball_states (
 game_id uuid primary key, organization_id uuid not null,
 roster_revision bigint not null check(roster_revision>0),
 engine_version text not null default 'volleyball-v1' check(engine_version='volleyball-v1'),
 configuration jsonb not null,
 state jsonb not null,
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 check(jsonb_typeof(configuration)='object' and octet_length(configuration::text)<=4096),
 check(jsonb_typeof(state)='object' and octet_length(state::text)<=65536)
);
create index volleyball_state_context_idx on public.game_volleyball_states(organization_id,game_id);
create table public.game_volleyball_events (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null,
 game_id uuid not null, operation_id uuid not null,
 sequence bigint not null check(sequence>0),
 origin_sequence bigint not null check(origin_sequence>0 and origin_sequence<=sequence),
 event_type text not null check(event_type in('configure','set_start','lineup_set','substitution','rally','attack_attempt','assist','dig','reception','blocking_error','reversal')),
 side text check(side in('primary','opponent')),
 payload jsonb not null, correction_of uuid,
 actor_person_id uuid not null references public.people(id), request_id uuid not null,
 reason text, created_at timestamptz not null default clock_timestamp(),
 unique(organization_id,game_id,id),unique(game_id,sequence),unique(operation_id),
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,game_id,operation_id) references public.game_operations(organization_id,game_id,id),
 foreign key(organization_id,game_id,correction_of) references public.game_volleyball_events(organization_id,game_id,id),
 check(correction_of is null or correction_of<>id),
 check(event_type<>'reversal' or correction_of is not null),
 check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=8192),
 check(reason is null or(length(btrim(reason)) between 1 and 500 and reason!~'[[:cntrl:]]'))
);
create unique index volleyball_event_supersession_idx on public.game_volleyball_events(game_id,correction_of) where correction_of is not null;
create index volleyball_event_origin_idx on public.game_volleyball_events(game_id,origin_sequence,sequence);
create index volleyball_event_context_idx on public.game_volleyball_events(organization_id,game_id,operation_id);
create index volleyball_event_correction_idx on public.game_volleyball_events(organization_id,game_id,correction_of);
create index volleyball_event_actor_idx on public.game_volleyball_events(actor_person_id);
create table public.game_volleyball_finalizations (
 finalization_id uuid primary key,organization_id uuid not null,game_id uuid not null,
 epoch bigint not null check(epoch>0),engine_version text not null check(engine_version='volleyball-v1'),
 roster_revision bigint not null check(roster_revision>0),event_sequence bigint not null check(event_sequence>0),
 state jsonb not null,
 unique(organization_id,game_id,finalization_id),unique(game_id,epoch),
 foreign key(organization_id,game_id,finalization_id) references public.game_finalizations(organization_id,game_id,id),
 check(jsonb_typeof(state)='object' and octet_length(state::text)<=65536)
);
create index volleyball_finalization_context_idx on public.game_volleyball_finalizations(organization_id,game_id,finalization_id);
create table public.game_volleyball_final_stats (
 id uuid primary key default gen_random_uuid(),finalization_id uuid not null,
 organization_id uuid not null,game_id uuid not null,
 side text not null check(side in('primary','opponent')),roster_id uuid,stats jsonb not null,
 foreign key(organization_id,game_id,finalization_id) references public.game_volleyball_finalizations(organization_id,game_id,finalization_id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 check(jsonb_typeof(stats)='object' and octet_length(stats::text)<=8192)
);
create unique index volleyball_final_stats_subject_idx on public.game_volleyball_final_stats(finalization_id,side,coalesce(roster_id,'00000000-0000-0000-0000-000000000000'::uuid));
create index volleyball_final_stats_context_idx on public.game_volleyball_final_stats(organization_id,game_id,finalization_id);
create index volleyball_final_stats_roster_idx on public.game_volleyball_final_stats(organization_id,game_id,roster_id);
do $$declare t text;begin
 foreach t in array array['game_volleyball_states','game_volleyball_events','game_volleyball_finalizations','game_volleyball_final_stats']loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;
 foreach t in array array['game_volleyball_events','game_volleyball_finalizations','game_volleyball_final_stats']loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end$$;
create trigger volleyball_state_identity before update on public.game_volleyball_states for each row execute function boss_private.preserve_row_identity('game_id','organization_id','roster_revision','engine_version','configuration');

create function boss_private.volleyball_configuration_validate(c jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare k text;begin
 perform boss_private.games_validate(c,array['best_of','normal_target','deciding_target','win_by_two','score_cap','court_size','strict_rotation','enforce_lineup','substitution_limit','allow_reentry','libero_enabled','libero_can_serve'],array['best_of','normal_target','deciding_target','win_by_two','court_size','strict_rotation','enforce_lineup','allow_reentry','libero_enabled','libero_can_serve']);
 foreach k in array array['best_of','normal_target','deciding_target','court_size']loop
 if jsonb_typeof(c->k)<>'number' or c->>k!~'^[0-9]{1,3}$' then raise exception 'Invalid Volleyball format' using errcode='PT422';end if;end loop;
 if(c->>'best_of')::integer not in(3,5) or(c->>'normal_target')::integer not between 2 and 99 or(c->>'deciding_target')::integer not between 2 and 99 or(c->>'court_size')::integer not between 1 and 6 then raise exception 'Invalid Volleyball format' using errcode='PT422';end if;
 foreach k in array array['win_by_two','strict_rotation','enforce_lineup','allow_reentry','libero_enabled','libero_can_serve']loop
 if jsonb_typeof(c->k)<>'boolean' then raise exception 'Invalid Volleyball policy' using errcode='PT422';end if;end loop;
 if(c->>'strict_rotation')::boolean and not(c->>'enforce_lineup')::boolean then raise exception 'Strict rotation requires court tracking' using errcode='PT422';end if;
 if(c->>'libero_can_serve')::boolean and not(c->>'libero_enabled')::boolean then raise exception 'Libero policy requires designation' using errcode='PT422';end if;
 foreach k in array array['score_cap','substitution_limit']loop
 if c?k and(jsonb_typeof(c->k)<>'number' or c->>k!~'^[0-9]{1,3}$' or(c->>k)::integer not between 1 and 999)then raise exception 'Invalid Volleyball limit' using errcode='PT422';end if;end loop;
 if c?'score_cap' and(c->>'score_cap')::integer<greatest((c->>'normal_target')::integer,(c->>'deciding_target')::integer)then raise exception 'Score cap precedes target' using errcode='PT422';end if;
end$$;

create function boss_private.volleyball_initial(c jsonb)returns jsonb language plpgsql immutable set search_path='' as $$
begin perform boss_private.volleyball_configuration_validate(c);
 return jsonb_build_object('set_number',0,'set_status','pending','primary_points',0,'opponent_points',0,'primary_sets',0,'opponent_sets',0,'serving_side',null,'service_sequence',0,'sets','[]'::jsonb,
 'lineups',jsonb_build_object('primary','[]'::jsonb,'opponent','[]'::jsonb),'liberos',jsonb_build_object('primary',null,'opponent',null),'substitutions',jsonb_build_object('primary',0,'opponent',0),'used',jsonb_build_object('primary','[]'::jsonb,'opponent','[]'::jsonb));
end$$;

-- Pure transition used both for ordinary append and independent full replay.
-- No game/profile/authorization reads are hidden inside the reducer.
create function boss_private.volleyball_transition(c jsonb,s jsonb,kind text,side text,p jsonb)returns jsonb
language plpgsql immutable set search_path='' as $$
declare n jsonb:=s;other text:=case side when'primary'then'opponent'else'primary'end;
 winner text;line jsonb;used jsonb;slot integer;incoming text;outgoing text;rid text;
 primary_points integer:=(s->>'primary_points')::integer;opponent_points integer:=(s->>'opponent_points')::integer;
 primary_sets integer:=(s->>'primary_sets')::integer;opponent_sets integer:=(s->>'opponent_sets')::integer;
 set_number integer:=(s->>'set_number')::integer;target integer;size integer:=(c->>'court_size')::integer;outcome text:=p->>'outcome';
begin
 if kind is null or side is null or kind not in('set_start','lineup_set','substitution','rally','attack_attempt','assist','dig','reception','blocking_error')or side not in('primary','opponent')or jsonb_typeof(p)is distinct from'object'then raise exception 'Invalid Volleyball fact' using errcode='PT422';end if;
 if kind='set_start'then
 if s->>'set_status'not in('pending','completed')or greatest(primary_sets,opponent_sets)>=(c->>'best_of')::integer/2+1 or set_number>=(c->>'best_of')::integer then raise exception 'No next set is available' using errcode='PT409';end if;
 if(c->>'enforce_lineup')::boolean and(jsonb_array_length(s->'lineups'->'primary')<>size or jsonb_array_length(s->'lineups'->'opponent')<>size)then raise exception 'Complete both court lineups before starting' using errcode='PT409';end if;
 return n||jsonb_build_object('set_number',set_number+1,'set_status','active','primary_points',0,'opponent_points',0,'serving_side',side,'substitutions',jsonb_build_object('primary',0,'opponent',0),'used',s->'lineups');
 end if;
 if kind='lineup_set'then
 if s->>'set_status'='active'or s->>'set_status'='match_complete'then raise exception 'Set lineup is locked; use substitution' using errcode='PT409';end if;
 line:=p->'roster_ids';
 if jsonb_typeof(line)<>'array'or jsonb_array_length(line)<>size or(select count(distinct x)from jsonb_array_elements_text(line)x)<>size then raise exception 'Invalid court lineup' using errcode='PT422';end if;
 if p?'libero_roster_id'and(not(c->>'libero_enabled')::boolean or not(line ?(p->>'libero_roster_id')))then raise exception 'Invalid libero designation' using errcode='PT422';end if;
 n:=jsonb_set(n,array['lineups',side],line);
 return jsonb_set(n,array['liberos',side],coalesce(p->'libero_roster_id','null'::jsonb));
 end if;
 if s->>'set_status'<>'active'and kind<>'assist'then raise exception 'An active set is required' using errcode='PT409';end if;
 if kind='substitution'then
 line:=s->'lineups'->side;used:=s->'used'->side;incoming:=p->>'in_roster_id';outgoing:=p->>'out_roster_id';
 select ordinality::integer-1 into slot from jsonb_array_elements_text(line)with ordinality x(value,ordinality)where value=outgoing;
 if slot is null or incoming is null or outgoing is null or incoming=outgoing or line?incoming then raise exception 'Invalid same-side substitution' using errcode='PT409';end if;
 if c?'substitution_limit'and(s->'substitutions'->>side)::integer>=(c->>'substitution_limit')::integer then raise exception 'Configured substitution limit reached' using errcode='PT409';end if;
 if not(c->>'allow_reentry')::boolean and used?incoming then raise exception 'Re-entry is disabled' using errcode='PT409';end if;
 -- Designation cannot silently transfer to the incoming athlete.
 if s->'liberos'->>side=outgoing then raise exception 'Libero replacement requires a reviewed lineup boundary' using errcode='PT409';end if;
 n:=jsonb_set(n,array['lineups',side,slot::text],to_jsonb(incoming));
 n:=jsonb_set(n,array['substitutions',side],to_jsonb((s->'substitutions'->>side)::integer+1));
 return jsonb_set(n,array['used',side],case when used?incoming then used else used||to_jsonb(incoming)end);
 end if;
 if(c->>'enforce_lineup')::boolean then
 foreach rid in array array[p->>'roster_id',p->>'assist_roster_id']loop
 if rid is not null and not(s->'lineups'->side?rid)then raise exception 'Athlete is not on court at this fact' using errcode='PT409';end if;end loop;
 for rid in select jsonb_array_elements_text(coalesce(p->'blocker_roster_ids','[]'))loop
 if not(s->'lineups'->side?rid)then raise exception 'Blocker is not on court' using errcode='PT409';end if;end loop;
 if p?'receiver_roster_id'and not(s->'lineups'->other?(p->>'receiver_roster_id'))then raise exception 'Receiver is not on court' using errcode='PT409';end if;
 end if;
 if s->'liberos'->>side=p->>'roster_id'and(kind='attack_attempt'or kind='rally'and outcome in('kill','attack_error','solo_block','assisted_block'))then raise exception 'Libero cannot receive attack/block credit' using errcode='PT409';end if;
 for rid in select jsonb_array_elements_text(coalesce(p->'blocker_roster_ids','[]'))loop
 if s->'liberos'->>side=rid then raise exception 'Libero cannot block' using errcode='PT409';end if;end loop;
 if kind<>'rally'then return n;end if;
 if outcome is null or outcome not in('kill','attack_error','ace','service_error','solo_block','assisted_block','reception_error','team_point')then raise exception 'Invalid rally outcome' using errcode='PT422';end if;
 if outcome in('ace','service_error')and side is distinct from s->>'serving_side'then raise exception 'Service changed; reload before saving' using errcode='PT409';end if;
 if outcome='reception_error'and side=s->>'serving_side'then raise exception 'Serving side cannot receive its own serve' using errcode='PT409';end if;
 if(c->>'strict_rotation')::boolean and outcome in('ace','service_error')and p?'roster_id'and p->>'roster_id'is distinct from s->'lineups'->side->>0 then raise exception 'Recorded server does not match rotation' using errcode='PT409';end if;
 if outcome in('ace','service_error')and s->'liberos'->>side=(case when(c->>'strict_rotation')::boolean then s->'lineups'->side->>0 else p->>'roster_id'end)and not(c->>'libero_can_serve')::boolean then raise exception 'Configured libero cannot serve' using errcode='PT409';end if;
 winner:=case when outcome in('attack_error','service_error','reception_error')then other else side end;
 if winner='primary'then primary_points:=primary_points+1;else opponent_points:=opponent_points+1;end if;
 if winner is distinct from s->>'serving_side'then
 line:=s->'lineups'->winner;
 if jsonb_array_length(line)>1 then
 select jsonb_agg(x.value order by case when x.ordinality=1 then jsonb_array_length(line)+1 else x.ordinality end)into line from jsonb_array_elements(line)with ordinality x(value,ordinality);
 n:=jsonb_set(n,array['lineups',winner],line);end if;end if;
 n:=n||jsonb_build_object('primary_points',primary_points,'opponent_points',opponent_points,'serving_side',winner,'service_sequence',(s->>'service_sequence')::bigint+1);
 target:=case when set_number=(c->>'best_of')::integer then(c->>'deciding_target')::integer else(c->>'normal_target')::integer end;
 if greatest(primary_points,opponent_points)>=target and(abs(primary_points-opponent_points)>=case when(c->>'win_by_two')::boolean then 2 else 1 end or c?'score_cap'and greatest(primary_points,opponent_points)>=(c->>'score_cap')::integer)then
 if winner='primary'then primary_sets:=primary_sets+1;else opponent_sets:=opponent_sets+1;end if;
 n:=n||jsonb_build_object('primary_sets',primary_sets,'opponent_sets',opponent_sets,'set_status',case when greatest(primary_sets,opponent_sets)>=(c->>'best_of')::integer/2+1 then'match_complete'else'completed'end,
 'sets',(s->'sets')||jsonb_build_array(jsonb_build_object('number',set_number,'primary_points',primary_points,'opponent_points',opponent_points,'winner',winner,'deciding',set_number=(c->>'best_of')::integer)));
 end if;
 return n;
end$$;

create function boss_private.volleyball_active_events(p_game uuid)returns setof public.game_volleyball_events
language sql stable security definer set search_path='' as $$
 select e.*from public.game_volleyball_events e where e.game_id=p_game and e.event_type<>'reversal'
 and not exists(select 1 from public.game_volleyball_events c where c.game_id=e.game_id and c.correction_of=e.id)
$$;

create function boss_private.volleyball_rebuild(p_game uuid,p_candidate jsonb default null,p_skip uuid default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare cfg jsonb;state jsonb;fact record;assists bigint[]:='{}';kills jsonb:='{}';kill jsonb;origin bigint;begin
 select configuration into cfg from public.game_volleyball_states where game_id=p_game;
 if cfg is null then raise exception 'Volleyball is not configured' using errcode='PT409';end if;
 state:=boss_private.volleyball_initial(cfg);
 for fact in
 select e.*from(
 select to_jsonb(v) j from boss_private.volleyball_active_events(p_game)v where v.id is distinct from p_skip
 union all select p_candidate where p_candidate is not null and p_candidate->>'event_type'<>'reversal'
 )source cross join lateral jsonb_to_record(source.j)as e(id uuid,origin_sequence bigint,event_type text,side text,payload jsonb)
 order by e.origin_sequence,e.id
 loop
 if fact.event_type='configure'then continue;end if;
 if fact.event_type='assist'then
 -- References retain the immutable origin while replacement leaves replay at
 -- that origin. Reversal or a non-kill replacement invalidates dependent assists.
 select v.origin_sequence into origin from public.game_volleyball_events v where v.game_id=p_game and v.id=(fact.payload->>'kill_event_id')::uuid and v.origin_sequence<fact.origin_sequence;
 kill:=kills->origin::text;
 if kill is null or kill->>'side'is distinct from fact.side or kill->'payload'->>'roster_id'=fact.payload->>'roster_id'or origin=any(assists)or kill->>'set_number'is distinct from state->>'set_number'then raise exception 'Assist requires one distinct same-side active kill' using errcode='PT409';end if;
 assists:=array_append(assists,origin);end if;
 if fact.event_type='rally'and fact.payload->>'outcome'='kill'then kills:=kills||jsonb_build_object(fact.origin_sequence::text,jsonb_build_object('side',fact.side,'payload',fact.payload,'set_number',state->'set_number'));end if;
 state:=boss_private.volleyball_transition(cfg,state,fact.event_type,fact.side,fact.payload);
 end loop;
 return state;
end$$;

create function boss_private.volleyball_stat_keys()returns text[]language sql immutable set search_path=''as $$
 select array['points','kills','attack_attempts','attack_errors','assists','digs','service_attempts','service_aces','service_errors','solo_blocks','block_assists','blocks','blocking_errors','receptions','reception_errors','set_wins']::text[]
$$;
create function boss_private.volleyball_stat_projection(s jsonb)returns jsonb language sql immutable set search_path=''as $$
 select coalesce(jsonb_object_agg(k,case when jsonb_typeof(s->k)='number'then s->k else '0'::jsonb end),'{}')||
 jsonb_build_object('hitting_percentage',case when coalesce((s->>'attack_attempts')::numeric,0)=0 then null else round(((s->>'kills')::numeric-(s->>'attack_errors')::numeric)/(s->>'attack_attempts')::numeric,6)end)
 from unnest(boss_private.volleyball_stat_keys())k
$$;

-- Emit independent count credits; a block-assist array awards one team block.
create function boss_private.volleyball_credits(p_game uuid)returns table(side text,roster_id uuid,key text,amount bigint)
language plpgsql stable security definer set search_path=''as $$
declare e public.game_volleyball_events;rid uuid;outcome text;other text;winner text;k text;cfg jsonb;replay_state jsonb;server uuid;begin
 select configuration into cfg from public.game_volleyball_states where game_id=p_game;
 replay_state:=boss_private.volleyball_initial(cfg);
 for e in select *from boss_private.volleyball_active_events(p_game)order by origin_sequence,id loop
 other:=case e.side when'primary'then'opponent'else'primary'end;rid:=(e.payload->>'roster_id')::uuid;outcome:=e.payload->>'outcome';
 if e.event_type='configure'then continue;end if;
 if e.event_type='rally'then
 -- Each canonical rally includes one service attempt for its pre-rally server.
 -- The tracked court order can identify that server without fabricating one.
 side:=replay_state->>'serving_side';key:='service_attempts';amount:=1;roster_id:=null;return next;
 server:=case when(cfg->>'strict_rotation')::boolean then(replay_state->'lineups'->side->>0)::uuid when outcome in('ace','service_error')then rid else null end;
 if server is not null then roster_id:=server;return next;end if;
 winner:=case when outcome in('attack_error','service_error','reception_error')then other else e.side end;
 side:=winner;roster_id:=null;key:='points';amount:=1;return next;
 if outcome in('kill','attack_error')then
 foreach k in array case outcome when'kill'then array['kills','attack_attempts']else array['attack_errors','attack_attempts']end loop
 side:=e.side;key:=k;amount:=1;roster_id:=null;return next;if rid is not null then roster_id:=rid;return next;end if;end loop;
 elsif outcome in('ace','service_error')then
 foreach k in array case outcome when'ace'then array['service_aces']else array['service_errors']end loop
 side:=e.side;key:=k;amount:=1;roster_id:=null;return next;if rid is not null then roster_id:=rid;return next;end if;end loop;
 elsif outcome='solo_block'then
 foreach k in array array['solo_blocks','blocks']loop
 side:=e.side;key:=k;amount:=1;roster_id:=null;return next;if rid is not null then roster_id:=rid;return next;end if;end loop;
 elsif outcome='assisted_block'then
 side:=e.side;key:='blocks';amount:=1;roster_id:=null;return next;
 for rid in select value::uuid from jsonb_array_elements_text(e.payload->'blocker_roster_ids')loop
 side:=e.side;key:='block_assists';amount:=1;roster_id:=rid;return next;roster_id:=null;return next;end loop;
 elsif outcome='reception_error'then
 foreach k in array array['receptions','reception_errors']loop
 side:=e.side;key:=k;amount:=1;roster_id:=null;return next;if rid is not null then roster_id:=rid;return next;end if;end loop;
 end if;
 if outcome='ace'and e.payload?'receiver_roster_id'then
 foreach k in array array['receptions','reception_errors']loop
 side:=other;key:=k;amount:=1;roster_id:=null;return next;roster_id:=(e.payload->>'receiver_roster_id')::uuid;return next;end loop;end if;
 elsif e.event_type in('attack_attempt','assist','dig','reception','blocking_error')then
 side:=e.side;key:=case e.event_type when'attack_attempt'then'attack_attempts'when'assist'then'assists'when'dig'then'digs'when'reception'then'receptions'else'blocking_errors'end;
 amount:=1;roster_id:=null;return next;if rid is not null then roster_id:=rid;return next;end if;
 end if;
 replay_state:=boss_private.volleyball_transition(cfg,replay_state,e.event_type,e.side,e.payload);
 end loop;
end$$;
create function boss_private.volleyball_totals(p_game uuid)returns table(side text,roster_id uuid,stats jsonb)
language sql stable security definer set search_path=''as $$
 with subjects as(
 select 'primary'::text side,null::uuid roster_id union all select'opponent',null::uuid
 union all select case r.team_id when g.primary_team_id then'primary'else'opponent'end,r.id from public.game_roster_snapshots r join public.games g on g.id=r.game_id where g.id=p_game and r.revision=g.roster_revision
 ),credits as(select *from boss_private.volleyball_credits(p_game)),counts as(
 select s.side,s.roster_id,k.key,coalesce(sum(c.amount),0)amount from subjects s cross join unnest(boss_private.volleyball_stat_keys())k(key)
 left join credits c on c.side=s.side and c.roster_id is not distinct from s.roster_id and c.key=k.key group by s.side,s.roster_id,k.key
 ),rows as(select side,roster_id,jsonb_object_agg(key,amount)stats from counts group by side,roster_id)
 select r.side,r.roster_id,boss_private.volleyball_stat_projection(r.stats||case when r.roster_id is null then jsonb_build_object('set_wins',s.state->(r.side||'_sets'))else'{}'::jsonb end)
 from rows r join public.game_volleyball_states s on s.game_id=p_game
$$;
do $$declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'volleyball_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;end$$;
