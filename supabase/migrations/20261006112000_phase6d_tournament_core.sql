-- Phase 6D Tournament + Bracket Management. Canonical teams, entries, events and games only.
create table public.tournament_stages(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),
 name text not null check(length(btrim(name))between 1 and 200),stage_type text not null check(stage_type in('pool','group','play_in','round_32','round_16','quarterfinal','semifinal','championship','third_place')),
 stage_order integer not null check(stage_order between 1 and 100),status text not null default'active'check(status in('active','complete','archived')),
 configuration jsonb not null default'{}'check(jsonb_typeof(configuration)='object'),version bigint not null default 1 check(version>0),created_by_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(edition_id,id),unique(edition_id,name,stage_order));
create table public.tournament_brackets(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null references public.competition_editions(id),name text not null check(length(btrim(name))between 1 and 200),
 bracket_type text not null default'single_elimination'check(bracket_type='single_elimination'),bracket_size integer not null check(bracket_size in(2,4,8,16,32,64)),
	 include_third_place boolean not null default false,status text not null default'draft'check(status in('draft','seeded','scheduled','active','complete','archived')),
	 configuration jsonb not null default'{"rest_policy":"disabled","minimum_rest_minutes":0}'check(jsonb_typeof(configuration)='object'and configuration - array['rest_policy','minimum_rest_minutes']='{}'::jsonb and configuration->>'rest_policy'in('disabled','warn','block')and jsonb_typeof(configuration->'minimum_rest_minutes')='number'and(configuration->>'minimum_rest_minutes')::int between 0 and 1440 and((configuration->>'rest_policy'='disabled')=((configuration->>'minimum_rest_minutes')::int=0))),
	 current_revision integer not null default 0 check(current_revision>=0),champion_entry_id uuid,version bigint not null default 1 check(version>0),
 created_by_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 unique(edition_id,id),foreign key(edition_id,champion_entry_id)references public.competition_entries(edition_id,id));
create table public.tournament_bracket_revisions(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null,bracket_id uuid not null,revision integer not null check(revision>0),
 source_kind text not null check(source_kind in('manual','standings_snapshot','group_finish_snapshot')),source_manifest jsonb not null check(jsonb_typeof(source_manifest)='object'),
 structure_digest text not null check(length(structure_digest)=32),reason text not null check(length(btrim(reason))between 1 and 500),actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(bracket_id,revision),unique(bracket_id,id),foreign key(edition_id,bracket_id)references public.tournament_brackets(edition_id,id));
create table public.tournament_seeds(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null,bracket_id uuid not null,revision_id uuid not null,seed integer not null check(seed between 1 and 64),entry_id uuid not null,
 source_rank integer,source_scope_id uuid references public.ranking_scopes(id),source_generation bigint,override_reason text,
 created_at timestamptz not null default clock_timestamp(),unique(revision_id,seed),unique(revision_id,entry_id),
 foreign key(edition_id,bracket_id)references public.tournament_brackets(edition_id,id),foreign key(bracket_id,revision_id)references public.tournament_bracket_revisions(bracket_id,id),foreign key(edition_id,entry_id)references public.competition_entries(edition_id,id),
 check(source_rank is null or source_rank>0),check(source_generation is null or source_generation>=0),check(override_reason is null or length(btrim(override_reason))between 1 and 500));
create table public.tournament_matches(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null,bracket_id uuid not null,revision_id uuid not null,stage_id uuid not null,
 round_number integer not null check(round_number between 1 and 10),match_number integer not null check(match_number between 1 and 64),label text not null check(length(btrim(label))between 1 and 200),
 primary_source_kind text not null check(primary_source_kind in('fixed_entry','prior_winner','prior_loser','qualifier','bye')),
 opponent_source_kind text not null check(opponent_source_kind in('fixed_entry','prior_winner','prior_loser','qualifier','bye')),
 primary_source_match_id uuid,opponent_source_match_id uuid,primary_entry_id uuid,opponent_entry_id uuid,
 source_organization_id uuid,game_id uuid,status text not null default'unresolved'check(status in('unresolved','ready','scheduled','live','final','bye_complete','ruling_required','canceled')),
 finalization_count integer,version bigint not null default 1 check(version>0),created_at timestamptz not null default clock_timestamp(),
 unique(bracket_id,revision_id,round_number,match_number),unique(bracket_id,id),
 foreign key(edition_id,bracket_id)references public.tournament_brackets(edition_id,id),foreign key(bracket_id,revision_id)references public.tournament_bracket_revisions(bracket_id,id),
 foreign key(edition_id,stage_id)references public.tournament_stages(edition_id,id),foreign key(bracket_id,primary_source_match_id)references public.tournament_matches(bracket_id,id),foreign key(bracket_id,opponent_source_match_id)references public.tournament_matches(bracket_id,id),
 foreign key(edition_id,primary_entry_id)references public.competition_entries(edition_id,id),foreign key(edition_id,opponent_entry_id)references public.competition_entries(edition_id,id),
 foreign key(source_organization_id,game_id)references public.games(organization_id,id),check(primary_entry_id is null or opponent_entry_id is null or primary_entry_id<>opponent_entry_id),check((source_organization_id is null)=(game_id is null)),check(finalization_count is null or finalization_count>0));
create table public.tournament_advancements(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null,bracket_id uuid not null,revision_id uuid not null,source_match_id uuid not null,
 winner_entry_id uuid not null,loser_entry_id uuid,source_game_id uuid,source_finalization_count integer,
 destination_match_id uuid,destination_side text check(destination_side in('primary','opponent')),advancement_kind text not null check(advancement_kind in('official_result','bye','ruling','reconciliation','reversal')),
 generation integer not null check(generation>0),supersedes_id uuid,status text not null default'active'check(status in('active','superseded')),
 reason text not null check(length(btrim(reason))between 1 and 500),actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(source_match_id,generation),unique(bracket_id,id),foreign key(edition_id,bracket_id)references public.tournament_brackets(edition_id,id),foreign key(bracket_id,revision_id)references public.tournament_bracket_revisions(bracket_id,id),
 foreign key(bracket_id,source_match_id)references public.tournament_matches(bracket_id,id),foreign key(bracket_id,destination_match_id)references public.tournament_matches(bracket_id,id),
 foreign key(edition_id,winner_entry_id)references public.competition_entries(edition_id,id),foreign key(edition_id,loser_entry_id)references public.competition_entries(edition_id,id),foreign key(bracket_id,supersedes_id)references public.tournament_advancements(bracket_id,id),
 check((destination_match_id is null)=(destination_side is null)),check(winner_entry_id is distinct from loser_entry_id),check((source_game_id is null)=(source_finalization_count is null)));
create table public.tournament_rulings(
 id uuid primary key default gen_random_uuid(),edition_id uuid not null,bracket_id uuid not null,match_id uuid not null,
 kind text not null check(kind in('withdrawal','disqualification','forfeit','no_contest','manual_advance','correction_resolution','reversal')),
 winner_entry_id uuid,loser_entry_id uuid,reversal_of_id uuid,reason text not null check(length(btrim(reason))between 1 and 500),actor_person_id uuid not null references public.people(id),created_at timestamptz not null default clock_timestamp(),
 unique(bracket_id,id),foreign key(edition_id,bracket_id)references public.tournament_brackets(edition_id,id),foreign key(bracket_id,match_id)references public.tournament_matches(bracket_id,id),
 foreign key(edition_id,winner_entry_id)references public.competition_entries(edition_id,id),foreign key(edition_id,loser_entry_id)references public.competition_entries(edition_id,id),foreign key(bracket_id,reversal_of_id)references public.tournament_rulings(bracket_id,id),
 check(winner_entry_id is null or loser_entry_id is null or winner_entry_id<>loser_entry_id),check((kind='reversal')=(reversal_of_id is not null)));
create unique index tournament_ruling_reversal_idx on public.tournament_rulings(reversal_of_id)where reversal_of_id is not null;
create table boss_private.tournament_operation_receipts(actor_person_id uuid not null references public.people(id),request_id uuid not null,input_hash text not null,result jsonb not null,created_at timestamptz not null default clock_timestamp(),primary key(actor_person_id,request_id));
alter table boss_private.tournament_operation_receipts enable row level security;revoke all on table boss_private.tournament_operation_receipts from public,anon,authenticated,service_role;
do $$declare t text;c record;begin
 foreach t in array array['tournament_stages','tournament_brackets','tournament_bracket_revisions','tournament_seeds','tournament_matches','tournament_advancements','tournament_rulings']loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on table public.%I from public,anon,authenticated,service_role',t);
  for c in select conname,string_agg(quote_ident(a.attname),','order by k.n)cols from pg_constraint fk cross join lateral unnest(fk.conkey)with ordinality k(attnum,n)join pg_attribute a on a.attrelid=fk.conrelid and a.attnum=k.attnum where fk.contype='f'and fk.conrelid=format('public.%I',t)::regclass group by conname loop execute format('create index %I on public.%I(%s)',left(t,34)||'_fk_'||substr(md5(c.conname),1,12),t,c.cols);end loop;
 end loop;
 foreach t in array array['tournament_bracket_revisions','tournament_seeds','tournament_advancements','tournament_rulings']loop execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.reject_audit_rewrite()',t||'_immutable',t);execute format('create trigger %I before truncate on public.%I execute function boss_private.reject_audit_rewrite()',t||'_no_truncate',t);end loop;
end$$;
create index tournament_matches_round_idx on public.tournament_matches(bracket_id,revision_id,round_number,match_number);
create index tournament_matches_game_idx on public.tournament_matches(source_organization_id,game_id)where game_id is not null;
create index tournament_advancements_active_idx on public.tournament_advancements(source_match_id,generation desc)where status='active';
create trigger tournament_stage_identity before update on public.tournament_stages for each row execute function boss_private.preserve_row_identity('id','edition_id','stage_type','stage_order','created_by_person_id','created_at');
create trigger tournament_bracket_identity before update on public.tournament_brackets for each row execute function boss_private.preserve_row_identity('id','edition_id','bracket_type','bracket_size','created_by_person_id','created_at');
create trigger tournament_match_identity before update on public.tournament_matches for each row execute function boss_private.preserve_row_identity('id','edition_id','bracket_id','revision_id','stage_id','round_number','match_number','primary_source_kind','opponent_source_kind','primary_source_match_id','opponent_source_match_id','created_at');
