-- A completed touchdown try enters kickoff phase. The try-only scoring-side
-- marker must be cleared so the canonical field state remains readable.
do $migration$
declare
  definition text;
  prior_fragment constant text :=
    $fragment$jsonb_build_object('phase','kickoff','points',points,'score_side',score_side,'first_down_side',null,'end_reason',null)$fragment$;
  fixed_fragment constant text :=
    $fragment$jsonb_build_object('phase','kickoff','scoring_side',null,'points',points,'score_side',score_side,'first_down_side',null,'end_reason',null)$fragment$;
begin
  definition := pg_get_functiondef(
    'boss_private.football_transition(jsonb,text,text,jsonb)'::regprocedure
  );

  if strpos(definition, prior_fragment) > 0 then
    execute replace(definition, prior_fragment, fixed_fragment);
  elsif strpos(definition, fixed_fragment) = 0 then
    raise exception 'Unexpected Football transition definition';
  end if;
end
$migration$;

update public.game_football_states
set field_state = jsonb_set(
  field_state,
  array['scoring_side'],
  'null'::jsonb,
  true
)
where field_state->>'phase' = 'kickoff'
  and field_state->>'scoring_side' is not null;
