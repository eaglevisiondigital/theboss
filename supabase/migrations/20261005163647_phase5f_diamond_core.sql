-- One Diamond engine for Baseball and Fastpitch Softball. Raw records are private.
create table public.game_diamond_states (
 game_id uuid primary key, organization_id uuid not null, sport_key text not null check(sport_key in('baseball','softball')),
 roster_revision bigint not null check(roster_revision>0), engine_version text not null default 'diamond-v1' check(engine_version='diamond-v1'),
 configuration jsonb not null, state jsonb not null,
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 check(jsonb_typeof(configuration)='object' and octet_length(configuration::text)<=8192),
 check(jsonb_typeof(state)='object' and octet_length(state::text)<=262144)
);
create index diamond_state_context_idx on public.game_diamond_states(organization_id,game_id);
create table public.game_diamond_events (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,game_id uuid not null,operation_id uuid not null,
 sequence bigint not null check(sequence>0),origin_sequence bigint not null check(origin_sequence>0 and origin_sequence<=sequence),
 event_type text not null check(event_type in('configure','lineup_set','half_start','pa_start','pitch','play','advance','substitution','pitcher_change','fielding','reversal')),
 payload jsonb not null,correction_of uuid,actor_person_id uuid not null references public.people(id),request_id uuid not null,
 reason text,created_at timestamptz not null default clock_timestamp(),
 unique(organization_id,game_id,id),unique(game_id,sequence),unique(operation_id),
 foreign key(organization_id,game_id) references public.games(organization_id,id),
 foreign key(organization_id,game_id,operation_id) references public.game_operations(organization_id,game_id,id),
 foreign key(organization_id,game_id,correction_of) references public.game_diamond_events(organization_id,game_id,id),
 check(correction_of is null or correction_of<>id),check(event_type<>'reversal' or correction_of is not null),
 check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=16384),
 check(reason is null or length(btrim(reason)) between 1 and 500 and reason!~'[[:cntrl:]]')
);
create unique index diamond_supersession_idx on public.game_diamond_events(game_id,correction_of) where correction_of is not null;
create index diamond_origin_idx on public.game_diamond_events(game_id,origin_sequence,sequence);
create index diamond_context_idx on public.game_diamond_events(organization_id,game_id,operation_id);
create index diamond_correction_idx on public.game_diamond_events(organization_id,game_id,correction_of);
create index diamond_actor_idx on public.game_diamond_events(actor_person_id);
-- PA identity outlives corrections and projections. Immutable starting evidence;
-- active terminal/pitch history is obtained from the ordered fact leaves.
create table public.game_diamond_plate_appearances (
 id uuid primary key,organization_id uuid not null,game_id uuid not null,start_event_id uuid not null,
 side text not null check(side in('primary','opponent')),batter_roster_id uuid,pitcher_roster_id uuid,
 start_sequence bigint not null check(start_sequence>0),start_state jsonb not null,
 unique(organization_id,game_id,id),unique(start_event_id),
 foreign key(organization_id,game_id,start_event_id) references public.game_diamond_events(organization_id,game_id,id),
 foreign key(organization_id,game_id,batter_roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 foreign key(organization_id,game_id,pitcher_roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 check(jsonb_typeof(start_state)='object' and octet_length(start_state::text)<=262144)
);
create index diamond_pa_start_context_idx on public.game_diamond_plate_appearances(organization_id,game_id,start_event_id);
create index diamond_pa_batter_idx on public.game_diamond_plate_appearances(organization_id,game_id,batter_roster_id);
create index diamond_pa_pitcher_idx on public.game_diamond_plate_appearances(organization_id,game_id,pitcher_roster_id);
create table public.game_diamond_finalizations (
 finalization_id uuid primary key,organization_id uuid not null,game_id uuid not null,epoch bigint not null check(epoch>0),
 sport_key text not null check(sport_key in('baseball','softball')),engine_version text not null check(engine_version='diamond-v1'),
 roster_revision bigint not null check(roster_revision>0),event_sequence bigint not null check(event_sequence>0),state jsonb not null,
 unique(organization_id,game_id,finalization_id),unique(game_id,epoch),
 foreign key(organization_id,game_id,finalization_id) references public.game_finalizations(organization_id,game_id,id),
 check(jsonb_typeof(state)='object' and octet_length(state::text)<=262144)
);
create index diamond_final_context_idx on public.game_diamond_finalizations(organization_id,game_id,finalization_id);
create table public.game_diamond_final_stats (
 id uuid primary key default gen_random_uuid(),finalization_id uuid not null,organization_id uuid not null,game_id uuid not null,
 side text not null check(side in('primary','opponent')),roster_id uuid,stats jsonb not null,
 foreign key(organization_id,game_id,finalization_id) references public.game_diamond_finalizations(organization_id,game_id,finalization_id),
 foreign key(organization_id,game_id,roster_id) references public.game_roster_snapshots(organization_id,game_id,id),
 check(jsonb_typeof(stats)='object' and octet_length(stats::text)<=16384)
);
create unique index diamond_stat_subject_idx on public.game_diamond_final_stats(finalization_id,side,coalesce(roster_id,'00000000-0000-0000-0000-000000000000'::uuid));
create index diamond_stat_context_idx on public.game_diamond_final_stats(organization_id,game_id,finalization_id);
create index diamond_stat_roster_idx on public.game_diamond_final_stats(organization_id,game_id,roster_id);
do $$declare t text;begin
 foreach t in array array['game_diamond_states','game_diamond_events','game_diamond_plate_appearances','game_diamond_finalizations','game_diamond_final_stats']loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 if t<>'game_diamond_states'then
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);
 execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end if;end loop;
end$$;
create trigger diamond_state_identity before update on public.game_diamond_states for each row execute function boss_private.preserve_row_identity('game_id','organization_id','sport_key','roster_revision','engine_version','configuration');

-- Nullable unknown athlete/limit fields are explicit Diamond vocabulary. The
-- existing Game Center validator still rejects null and is not weakened.
create function boss_private.diamond_validate(i jsonb,allowed text[],required text[])returns void
language plpgsql immutable set search_path=''as $$begin
 if i is null or jsonb_typeof(i)<>'object' or octet_length(i::text)>16384 or not(i?&required)
 or exists(select 1 from jsonb_object_keys(i)k where not k=any(allowed))then raise exception 'Invalid Diamond fact'using errcode='PT422';end if;
end$$;

create function boss_private.diamond_configuration_validate(c jsonb)returns void language plpgsql immutable set search_path=''as $$
declare fields text[]:=array['version','sport','home_side','regulation_innings','lineup_size','continuous_batting','allow_reentry','stealing','dropped_third_strike','foul_bunt_third_strike','run_cap','tiebreak_from','dh','dp_flex','courtesy_runner','mercy_margin','time_limit_minutes','pitch_limit','era_innings'];k text;begin
 perform boss_private.diamond_validate(c,fields,fields);
 if c->>'version'is distinct from'diamond-rules-v1'or c->>'sport'not in('baseball','softball')or c->>'sport'is null or c->>'home_side'not in('primary','opponent')or c->>'home_side'is null then raise exception 'Invalid Diamond rules'using errcode='PT422';end if;
 foreach k in array array['regulation_innings','lineup_size','era_innings']loop
 if jsonb_typeof(c->k)<>'number'or c->>k!~'^[0-9]{1,2}$'or(c->>k)::integer not between 1 and (case k when'lineup_size'then 30 else 20 end) then raise exception 'Invalid Diamond format'using errcode='PT422';end if;end loop;
 foreach k in array array['continuous_batting','allow_reentry','stealing','foul_bunt_third_strike']loop if jsonb_typeof(c->k)<>'boolean'then raise exception 'Invalid Diamond policy'using errcode='PT422';end if;end loop;
 if c->>'dropped_third_strike'not in('disabled','first_unoccupied_or_two_outs')or c->>'dropped_third_strike'is null then raise exception 'Invalid dropped-third-strike policy'using errcode='PT422';end if;
 foreach k in array array['run_cap','tiebreak_from','mercy_margin','time_limit_minutes','pitch_limit']loop
 if c->k<>'null'::jsonb and(jsonb_typeof(c->k)<>'number'or c->>k!~'^[0-9]{1,3}$'or(c->>k)::integer not between 1 and (case when k in('time_limit_minutes','pitch_limit')then 600 else 100 end))then raise exception 'Invalid Diamond limit'using errcode='PT422';end if;end loop;
 foreach k in array array['dh','dp_flex','courtesy_runner']loop if c->>k not in('none','foundation_only')or c->>k is null then raise exception 'Unsupported association policy'using errcode='PT422';end if;end loop;
 if(c->>'tiebreak_from')::integer<=(c->>'regulation_innings')::integer or c->>'sport'='baseball'and c->>'dp_flex'<>'none'or c->>'sport'='softball'and c->>'dh'<>'none'then raise exception 'Wrong-sport or tiebreak policy'using errcode='PT422';end if;
end$$;
create function boss_private.diamond_other(side text)returns text language sql immutable set search_path=''as $$select case side when'primary'then'opponent'when'opponent'then'primary'end$$;
create function boss_private.diamond_initial(c jsonb)returns jsonb language plpgsql immutable set search_path=''as $$begin
 perform boss_private.diamond_configuration_validate(c);
 return jsonb_build_object('inning',1,'half','top','status','pregame','outs',0,'primary_score',0,'opponent_score',0,'half_runs',0,'batting_side',boss_private.diamond_other(c->>'home_side'),'defensive_side',c->>'home_side','bases','[null,null,null]'::jsonb,
 'orders',jsonb_build_object('primary',(select jsonb_agg(null::text)from generate_series(1,(c->>'lineup_size')::int)),'opponent',(select jsonb_agg(null::text)from generate_series(1,(c->>'lineup_size')::int))),'positions','{"primary":{},"opponent":{}}'::jsonb,'used','{"primary":[],"opponent":[]}'::jsonb,'cursors','{"primary":0,"opponent":0}'::jsonb,'pitchers','{"primary":null,"opponent":null}'::jsonb,'lineup_revision',0,'pa',null,'appearances','[]'::jsonb,'completed_halves','[]'::jsonb);
end$$;
create function boss_private.diamond_appearance(s jsonb,key text)returns jsonb language plpgsql immutable set search_path=''as $$
declare a jsonb:=s->'appearances';v jsonb;i int;side text:=s->>'defensive_side';pitcher jsonb:=s->'pitchers'->side;inherited jsonb;boundary jsonb;begin
 boundary:=jsonb_build_object('inning',s->'inning','half',s->'half','outs',s->'outs','primary_score',s->'primary_score','opponent_score',s->'opponent_score');
 for i in reverse jsonb_array_length(a)-1..0 loop
 v:=a->i;if v->>'side'=side and not(v->>'ended')::boolean then
 if v->'pitcher'=pitcher then return s;end if;
 a:=jsonb_set(a,array[i::text,'ended'],'true');a:=jsonb_set(a,array[i::text,'exit'],boundary);exit;end if;end loop;
 select coalesce(jsonb_agg(r),'[]')into inherited from jsonb_array_elements(s->'bases')r where r<>'null'::jsonb;
 a:=a||jsonb_build_array(jsonb_build_object('key',key,'side',side,'pitcher',pitcher,'entry_inning',s->'inning','entry_half',s->'half','inherited',inherited,'ended',false,'entry',boundary,'exit',null,'outs_recorded',0,'batters_faced',0));
 return jsonb_set(s,array['appearances'],a);
end$$;
create function boss_private.diamond_moves(s jsonb,list jsonb,batter jsonb,result text)returns jsonb language plpgsql immutable set search_path=''as $$
declare n jsonb:=s;bases jsonb:=s->'bases';nextbases jsonb:=s->'bases';m jsonb;r jsonb;bm jsonb;seen int[]:='{}';f int;t int;outs int:=(s->>'outs')::int;runs int:=0;third boolean:=false;cancel boolean:=false;hitbase int;i int;j int;a jsonb;b jsonb;ai int;bi int;atarget int;btarget int;begin
 if jsonb_typeof(list)is distinct from'array'or jsonb_array_length(list)not between 1 and 4 then raise exception 'Bounded movement sequence required'using errcode='PT422';end if;
 for m in select value from jsonb_array_elements(list)loop
 perform boss_private.diamond_validate(m,array['from','to','out','cause','force','batter_before_first','earned','rbi'],array['from','to','out','cause','force','batter_before_first']);
 if jsonb_typeof(m->'from')<>'number'or m->>'from'!~'^[0-3]$'or jsonb_typeof(m->'out')<>'boolean'or jsonb_typeof(m->'force')<>'boolean'or jsonb_typeof(m->'batter_before_first')<>'boolean'or m?'earned'and jsonb_typeof(m->'earned')<>'boolean'or m?'rbi'and jsonb_typeof(m->'rbi')<>'boolean'
 or m->>'cause'not in('hit','walk','hit_by_pitch','error','fielders_choice','sacrifice','stolen_base','caught_stealing','pickoff','wild_pitch','passed_ball','balk','defensive_indifference','advance_on_play','interference','dropped_third_strike','tiebreak')or m->>'cause'is null then raise exception 'Invalid runner movement'using errcode='PT422';end if;
 f:=(m->>'from')::int;t:=(m->>'to')::int;
 if f=any(seen)then raise exception 'Runner origin consumed twice'using errcode='PT409';end if;seen:=array_append(seen,f);
 r:=case when f=0 then batter else bases->(f-1)end;
 if r is null or r='null'::jsonb then raise exception 'Runner origin empty'using errcode='PT409';end if;
 if third then raise exception 'Movement after third out'using errcode='PT409';end if;
 if(m->>'out')::boolean then
 if m->'to'<>'null'::jsonb or coalesce((m->>'earned')::boolean,false)or coalesce((m->>'rbi')::boolean,false)or(m->>'batter_before_first')::boolean and f<>0 then raise exception 'Invalid out attribution'using errcode='PT422';end if;
 outs:=outs+1;if outs>3 then raise exception 'Too many outs'using errcode='PT409';end if;
 if outs=3 then third:=true;cancel:=(m->>'force')::boolean or(m->>'batter_before_first')::boolean;end if;
 else
 if jsonb_typeof(m->'to')<>'number'or m->>'to'!~'^[1-4]$'or t<=f or(m->>'force')::boolean or(m->>'batter_before_first')::boolean or t<>4 and(m?'earned'or m?'rbi')then raise exception 'Invalid safe advance'using errcode='PT422';end if;
 if t=4 then runs:=runs+1;end if;
 end if;
 if f>0 then nextbases:=jsonb_set(nextbases,array[(f-1)::text],'null');end if;
 end loop;
 for m in select value from jsonb_array_elements(list)where not(value->>'out')::boolean and(value->>'to')::int<>4 loop
 f:=(m->>'from')::int;t:=(m->>'to')::int;r:=case when f=0 then batter else bases->(f-1)end;
 if nextbases->(t-1)<>'null'::jsonb then raise exception 'Duplicate base occupancy'using errcode='PT409';end if;
 nextbases:=jsonb_set(nextbases,array[(t-1)::text],r);end loop;
 for i in 0..2 loop
 if(case when i=0 then batter is null or batter='null'::jsonb else bases->(i-1)='null'::jsonb end)then continue;end if;
 select value,ordinality::int into a,ai from jsonb_array_elements(list)with ordinality where(value->>'from')::int=i;
 if coalesce((a->>'out')::boolean,false)then continue;end if;atarget:=coalesce((a->>'to')::int,i);
 for j in i+1..3 loop
 if bases->(j-1)='null'::jsonb then continue;end if;
 select value,ordinality::int into b,bi from jsonb_array_elements(list)with ordinality where(value->>'from')::int=j;
 if coalesce((b->>'out')::boolean,false)then continue;end if;btarget:=coalesce((b->>'to')::int,j);
 if atarget>btarget or atarget=4 and btarget=4 and ai<bi then raise exception 'Runner cannot pass a lead runner'using errcode='PT409';end if;
 end loop;end loop;
 if result is not null and not 0=any(seen)or result is null and 0=any(seen)then raise exception 'Batter-runner resolution inconsistent'using errcode='PT409';end if;
 select value into bm from jsonb_array_elements(list)where(value->>'from')::int=0;
 if result in('walk','intentional_walk','hit_by_pitch','catcher_interference')then
 if(bm->>'out')::boolean or bm->>'to'<>'1'then raise exception 'Awarded batter must reach first'using errcode='PT409';end if;
 for i in 1..3 loop exit when bases->(i-1)='null'::jsonb;
 if not exists(select 1 from jsonb_array_elements(list)v where(v->>'from')::int=i and not(v->>'out')::boolean and(v->>'to')::int=i+1)then raise exception 'Forced advance unresolved'using errcode='PT409';end if;end loop;end if;
 hitbase:=case result when'single'then 1 when'double'then 2 when'triple'then 3 when'home_run'then 4 else 0 end;
 if hitbase>0 and((bm->>'out')::boolean or(bm->>'to')::int<hitbase)then raise exception 'Hit contradicts batter advance'using errcode='PT409';end if;
 if result='home_run'and(exists(select 1 from jsonb_array_elements(list)v where(v->>'out')::boolean or v->>'to'<>'4')or exists(select 1 from generate_series(1,3)gs(i) where bases->(gs.i-1)<>'null'::jsonb and not gs.i=any(seen)))then raise exception 'Home run must score all runners'using errcode='PT409';end if;
 if result in('strikeout','other_out','sacrifice_fly','sacrifice_bunt')and not(bm->>'out')::boolean then raise exception 'Out requires batter retired'using errcode='PT409';end if;
 if(select count(*)<>count(distinct br.r->>'key')from jsonb_array_elements(nextbases)br(r) where br.r<>'null'::jsonb)then raise exception 'Duplicate runner identity'using errcode='PT409';end if;
 if cancel then runs:=0;end if;
 n:=n||jsonb_build_object('bases',nextbases,'outs',outs,'half_runs',(s->>'half_runs')::int+runs);
 return jsonb_set(n,array[(s->>'batting_side')||'_score'],to_jsonb((s->>((s->>'batting_side')||'_score'))::int+runs));
end$$;

-- Ordinary ending eligibility, confirmed only by the canonical finalize command.
create function boss_private.diamond_final_ready(c jsonb,s jsonb)returns boolean
language sql immutable set search_path=''as $$select
 (s->>'inning')::int>=(c->>'regulation_innings')::int and s->'pa'='null'::jsonb and(
 s->>'status'='half_complete'and s->>'half'='bottom'and s->>'primary_score'<>s->>'opponent_score'
 or (s->>(c->>'home_side'||'_score'))::int>(s->>((case c->>'home_side'when'primary'then'opponent'else'primary'end)||'_score'))::int
 and(s->>'status'='half_complete'and s->>'half'='top'or s->>'status'='active'and s->>'half'='bottom'))$$;

create function boss_private.diamond_transition(c jsonb,s jsonb,fact jsonb)returns jsonb language plpgsql immutable set search_path=''as $$
declare n jsonb:=s;kind text:=fact->>'kind';side text:=fact->>'side';fields text[];pa jsonb:=s->'pa';p jsonb;line jsonb;pos jsonb;runner jsonb;list jsonb;advance_item jsonb;key text;outcome text:=fact->>'outcome';result text:=fact->>'result';pitcher jsonb;slot int;i int;innings int:=(s->>'inning')::int;half text:=s->>'half';bat text:=s->>'batting_side';def text:=s->>'defensive_side';outs int;strikes int;balls int;placed boolean;origin text;begin
 perform boss_private.diamond_configuration_validate(c);
 case kind
 when'lineup_set'then fields:=array['kind','side','order','positions','pitcher'];
 when'half_start'then fields:=array['kind','placed_runner'];
 when'pa_start'then fields:=array['kind','key','batter','pitch_tracking'];
 when'pitch'then fields:=array['kind','outcome','pitch_tracking','pitch_gap'];
 when'play'then fields:=array['kind','result','moves','pitch_gap'];
 when'advance'then fields:=array['kind','moves'];
 when'fielding'then fields:=array['kind','side','roster_id','position','stat','play_event_id'];
 when'pitcher_change'then fields:=array['kind','side','pitcher','key'];
 when'substitution'then fields:=array['kind','side','out_roster_id','in_roster_id','mode','position'];
 else raise exception 'Invalid Diamond fact'using errcode='PT422';end case;
 perform boss_private.diamond_validate(fact,fields,array(select x from unnest(fields)x where x not in('placed_runner','position','pitch_gap')));
 if side is not null and side not in('primary','opponent')then raise exception 'Invalid Diamond side'using errcode='PT422';end if;
 if kind='lineup_set'then
 line:=fact->'order';pos:=fact->'positions';pitcher:=fact->'pitcher';
 if side is null or s->>'status'<>'pregame'or jsonb_typeof(line)<>'array'or jsonb_array_length(line)<>(c->>'lineup_size')::int
 or exists(select 1 from jsonb_array_elements(line)v where jsonb_typeof(v)not in('string','null')or v='""'::jsonb)
 or(select count(*)<>count(distinct v)from jsonb_array_elements(line)v where v<>'null'::jsonb)then raise exception 'Invalid initial batting order'using errcode='PT409';end if;
 if jsonb_typeof(pos)<>'object'or exists(select 1 from jsonb_each(pos)x(k,v)where k!~'^[1-9]$'or v<>'null'::jsonb and not line@>jsonb_build_array(v))
 or pitcher<>'null'::jsonb and not line@>jsonb_build_array(pitcher)
 or(select count(*)<>count(distinct v)from jsonb_each(pos)x(k,v)where v<>'null'::jsonb)
 or pos?'1'and pos->'1'<>pitcher then raise exception 'Invalid defensive alignment'using errcode='PT409';end if;
 n:=jsonb_set(n,array['orders',side],line);n:=jsonb_set(n,array['positions',side],pos);n:=jsonb_set(n,array['pitchers',side],pitcher);
 select coalesce(jsonb_agg(v),'[]')into list from jsonb_array_elements(line)v where v<>'null'::jsonb;n:=jsonb_set(n,array['used',side],list);
 return n||jsonb_build_object('lineup_revision',(s->>'lineup_revision')::int+1);
 end if;
 if kind='half_start'then
 if boss_private.diamond_final_ready(c,s)then raise exception 'Ordinary game ending reached; finalize or correct'using errcode='PT409';end if;
 if s->>'status'not in('pregame','half_complete')or jsonb_array_length(s->'orders'->'primary')<>(c->>'lineup_size')::int or jsonb_array_length(s->'orders'->'opponent')<>(c->>'lineup_size')::int then raise exception 'Half cannot start'using errcode='PT409';end if;
 if s->>'status'='half_complete'then if half='bottom'then innings:=innings+1;half:='top';else half:='bottom';end if;end if;
 if innings>99 then raise exception 'Inning bound exceeded'using errcode='PT409';end if;
 bat:=case half when'bottom'then c->>'home_side'else boss_private.diamond_other(c->>'home_side')end;def:=boss_private.diamond_other(bat);
 n:=n||jsonb_build_object('inning',innings,'half',half,'batting_side',bat,'defensive_side',def,'outs',0,'half_runs',0,'status','active','bases','[null,null,null]'::jsonb);
 placed:=coalesce(innings>=(c->>'tiebreak_from')::int,false);
 if placed is distinct from(fact?'placed_runner')then raise exception 'Configured extra-inning runner required'using errcode='PT409';end if;
 if placed then p:=fact->'placed_runner';perform boss_private.diamond_validate(p,array['roster_id','key'],array['roster_id','key']);
 if jsonb_typeof(p->'key')<>'string'or length(p->>'key')not between 1 and 80 or p->'roster_id'<>'null'::jsonb and not n->'orders'->bat@>jsonb_build_array(p->'roster_id')then raise exception 'Invalid placed runner'using errcode='PT422';end if;
 runner:=jsonb_build_object('key',p->'key','roster_id',p->'roster_id','responsible_pitcher',n->'pitchers'->def,'origin','tiebreak','placed',true);
 n:=jsonb_set(n,array['bases','1'],runner);end if;
 return boss_private.diamond_appearance(n,'half:'||innings||':'||half);
 end if;
 if kind='fielding'then
 if side is null or fact->>'stat'not in('putouts','assists','errors','double_plays')or fact->>'stat'is null
 or jsonb_typeof(fact->'play_event_id')<>'string'or fact->>'play_event_id'!~'^[0-9a-fA-F-]{36}$'
 or fact->'position'<>'null'::jsonb and(jsonb_typeof(fact->'position')<>'string'or fact->>'position'!~'^[1-9]$')then raise exception 'Invalid fielding attribution'using errcode='PT422';end if;
 return n;end if;
 if s->>'status'<>'active'then raise exception 'Active half required'using errcode='PT409';end if;
 if kind='pa_start'then
 if pa<>'null'::jsonb or jsonb_typeof(fact->'pitch_tracking')<>'boolean'or jsonb_typeof(fact->'key')<>'string'or length(fact->>'key')not between 1 and 80
 or fact->'batter'is distinct from(s->'orders'->bat->((s->'cursors'->>bat)::int))
 or fact->'batter'<>'null'::jsonb and exists(select 1 from jsonb_array_elements(s->'bases')r where r->'roster_id'=fact->'batter')then raise exception 'Batter order or PA inconsistent'using errcode='PT409';end if;
 return jsonb_set(n,array['pa'],jsonb_build_object('key',fact->'key','side',bat,'batter',fact->'batter','pitcher',s->'pitchers'->def,'inning',s->'inning','half',s->'half','balls',0,'strikes',0,'pitches',0,'strike_pitches',0,'pitch_coverage',case when(fact->>'pitch_tracking')::boolean then'tracked'else'not_tracked'end,'awaiting',null));end if;
 if kind in('pitch','play')and fact?'pitch_gap'then
 if jsonb_typeof(fact->'pitch_gap')<>'boolean'then raise exception 'Invalid pitch coverage gap'using errcode='PT422';end if;
 if(fact->>'pitch_gap')::boolean and pa<>'null'::jsonb and pa->>'pitch_coverage'<>'not_tracked'then pa:=pa||'{"pitch_coverage":"partially_tracked"}';n:=jsonb_set(n,array['pa'],pa);end if;end if;
 if kind='pitch'then
 if pa='null'::jsonb or pa->'awaiting'<>'null'::jsonb or fact->'pitch_tracking'is distinct from'true'::jsonb or outcome is null or outcome not in('ball','called_strike','swinging_strike','foul','foul_bunt','in_play')then raise exception 'Tracked active PA required'using errcode='PT409';end if;
 if pa->>'pitch_coverage'='not_tracked'then pa:=pa||'{"pitch_coverage":"partially_tracked"}';end if;
 pa:=jsonb_set(pa,array['pitches'],to_jsonb((pa->>'pitches')::int+1));balls:=(pa->>'balls')::int;strikes:=(pa->>'strikes')::int;
 if outcome='ball'then balls:=balls+1;pa:=jsonb_set(pa,array['balls'],to_jsonb(balls));if balls=4 then pa:=pa||'{"awaiting":"walk"}';end if;
 else pa:=jsonb_set(pa,array['strike_pitches'],to_jsonb((pa->>'strike_pitches')::int+1));
 if outcome='in_play'then pa:=pa||'{"awaiting":"in_play"}';
 else if outcome<>'foul'and(outcome<>'foul_bunt'or(c->>'foul_bunt_third_strike')::boolean)or strikes<2 then strikes:=strikes+1;end if;
 pa:=jsonb_set(pa,array['strikes'],to_jsonb(strikes));if strikes=3 then pa:=pa||'{"awaiting":"strikeout"}';end if;end if;end if;
 return jsonb_set(n,array['pa'],pa);end if;
 if kind='pitcher_change'then
 if side is null or side<>def or pa<>'null'::jsonb or jsonb_typeof(fact->'key')<>'string'or length(fact->>'key')not between 1 and 80 or fact->'pitcher'=s->'pitchers'->side or fact->'pitcher'<>'null'::jsonb and not s->'orders'->side@>jsonb_build_array(fact->'pitcher')then raise exception 'Pitcher change requires eligible boundary'using errcode='PT409';end if;
 n:=jsonb_set(n,array['pitchers',side],fact->'pitcher');pos:=n->'positions'->side;
 for key in select k from jsonb_each(pos)x(k,v)where v=fact->'pitcher'and v<>'null'::jsonb loop pos:=pos-key;end loop;
 pos:=pos||jsonb_build_object('1',fact->'pitcher');n:=jsonb_set(n,array['positions',side],pos);
 return boss_private.diamond_appearance(n||jsonb_build_object('lineup_revision',(s->>'lineup_revision')::int+1),fact->>'key');end if;
 if kind='substitution'then
 if side is null or pa<>'null'::jsonb or fact->>'mode'not in('offensive','defensive','pinch_hitter','pinch_runner')or fact->>'mode'is null or jsonb_typeof(fact->'in_roster_id')<>'string'or fact->>'in_roster_id'=''or fact->'in_roster_id'=fact->'out_roster_id'or s->'orders'->side@>jsonb_build_array(fact->'in_roster_id')or not(c->>'allow_reentry')::boolean and s->'used'->side@>jsonb_build_array(fact->'in_roster_id')then raise exception 'Invalid substitution'using errcode='PT409';end if;
 select ordinality::int-1 into slot from jsonb_array_elements(s->'orders'->side)with ordinality x(v,ordinality)where v=fact->'out_roster_id';
 if slot is null or s->'pitchers'->side=fact->'out_roster_id'then raise exception 'Eligible non-pitcher slot required'using errcode='PT409';end if;
 select r into runner from jsonb_array_elements(s->'bases')r where r->'roster_id'=fact->'out_roster_id';
 if fact->>'mode'='pinch_runner'and(side<>bat or runner is null)or fact->>'mode'<>'pinch_runner'and runner is not null then raise exception 'Runner substitution requires pinch-runner workflow'using errcode='PT409';end if;
 n:=jsonb_set(n,array['orders',side,slot::text],fact->'in_roster_id');n:=jsonb_set(n,array['used',side],s->'used'->side||jsonb_build_array(fact->'in_roster_id'));pos:=s->'positions'->side;
 for key in select k from jsonb_each(pos)x(k,v)where v=fact->'out_roster_id'loop pos:=jsonb_set(pos,array[key],fact->'in_roster_id');end loop;
 if fact?'position'then if fact->>'position'!~'^[2-9]$'then raise exception 'Invalid defensive position'using errcode='PT422';end if;
 for key in select k from jsonb_each(pos)x(k,v)where v=fact->'in_roster_id'loop pos:=pos-key;end loop;
 pos:=pos||jsonb_build_object(fact->>'position',fact->'in_roster_id');end if;n:=jsonb_set(n,array['positions',side],pos);
 if runner is not null then for i in 0..2 loop if n->'bases'->i->'roster_id'=fact->'out_roster_id'then n:=jsonb_set(n,array['bases',i::text,'roster_id'],fact->'in_roster_id');end if;end loop;end if;
 return n||jsonb_build_object('lineup_revision',(s->>'lineup_revision')::int+1);end if;
 if kind='play'then
 if pa='null'::jsonb or result is null or result not in('single','double','triple','home_run','walk','intentional_walk','hit_by_pitch','strikeout','reached_on_error','fielders_choice','sacrifice_bunt','sacrifice_fly','catcher_interference','dropped_third_strike','other_out')then raise exception 'Terminal PA required'using errcode='PT409';end if;
 if pa->>'awaiting'='walk'and result<>'walk'or pa->>'awaiting'='strikeout'and result not in('strikeout','dropped_third_strike')or pa->>'awaiting'='in_play'and result in('walk','intentional_walk','strikeout')
 or pa->>'pitch_coverage'='tracked'and pa->'awaiting'='null'::jsonb and result not in('intentional_walk','hit_by_pitch','catcher_interference')then raise exception 'Result contradicts pitch evidence'using errcode='PT409';end if;
 if result='dropped_third_strike'and(c->>'dropped_third_strike'='disabled'or(s->>'outs')::int<2 and s->'bases'->0<>'null'::jsonb)then raise exception 'Dropped third strike unavailable'using errcode='PT409';end if;
 origin:=case result when'reached_on_error'then'error'when'hit_by_pitch'then'hit_by_pitch'when'catcher_interference'then'interference'when'dropped_third_strike'then'dropped_third_strike'when'walk'then'walk'when'intentional_walk'then'walk'else'hit'end;
 runner:=jsonb_build_object('key',pa->'key','roster_id',pa->'batter','responsible_pitcher',pa->'pitcher','origin',origin,'placed',false);
 n:=boss_private.diamond_moves(n,fact->'moves',runner,result);
 n:=jsonb_set(n,array['cursors',bat],to_jsonb(((s->'cursors'->>bat)::int+1)%(c->>'lineup_size')::int));n:=n||'{"pa":null}';
 else
 if pa->'awaiting'is not null and pa->'awaiting'<>'null'::jsonb then raise exception 'Resolve terminal PA first'using errcode='PT409';end if;
 for advance_item in select value from jsonb_array_elements(fact->'moves')loop
 if advance_item->>'cause'not in('stolen_base','caught_stealing','pickoff','wild_pitch','passed_ball','balk','defensive_indifference','advance_on_play')or not(c->>'stealing')::boolean and advance_item->>'cause'in('stolen_base','caught_stealing')or advance_item->>'cause'='stolen_base'and(advance_item->>'out')::boolean or advance_item->>'cause'in('caught_stealing','pickoff')and not(advance_item->>'out')::boolean then raise exception 'Invalid standalone advance'using errcode='PT409';end if;end loop;
 n:=boss_private.diamond_moves(n,fact->'moves',null,null);end if;
 outs:=(n->>'outs')::int;
 for i in reverse jsonb_array_length(n->'appearances')-1..0 loop
 if n->'appearances'->i->>'side'=def and not(n->'appearances'->i->>'ended')::boolean then
 n:=jsonb_set(n,array['appearances',i::text,'outs_recorded'],to_jsonb((n->'appearances'->i->>'outs_recorded')::int+outs-(s->>'outs')::int));
 if kind='play'then n:=jsonb_set(n,array['appearances',i::text,'batters_faced'],to_jsonb((n->'appearances'->i->>'batters_faced')::int+1));end if;exit;end if;end loop;
 if outs=3 or(c->>'run_cap')::int<=(n->>'half_runs')::int then
 n:=n||jsonb_build_object('status','half_complete','pa',null,'bases','[null,null,null]'::jsonb,'completed_halves',n->'completed_halves'||jsonb_build_array(jsonb_build_object('inning',n->'inning','half',n->'half','side',bat,'runs',n->'half_runs','outs',outs,'reason',case outs when 3 then'third_out'else'run_cap'end)));end if;
 return n;
end$$;
-- No publicly callable reducer or raw state path.
do $$declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='boss_private'and p.proname like'diamond_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);end loop;end$$;
