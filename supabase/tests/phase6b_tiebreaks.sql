begin;
set local statement_timeout='8s';
create temp table rb_assertions(label text primary key);
create function pg_temp.ok(label text,condition boolean)returns void language plpgsql as $$begin if condition is distinct from true then raise exception 'FAIL Phase6B %',label;end if;insert into rb_assertions values(label);end$$;
create function pg_temp.result(a text,b text,p int,o int)returns jsonb language sql immutable as $$select jsonb_build_object('primary_entry_id',a,'opponent_entry_id',b,'outcome',case when p>o then'primary'when p<o then'opponent'else'tie'end,'pf',p,'pa',o,'group_ids','[]'::jsonb)$$;
create function pg_temp.policy(rules jsonb)returns jsonb language sql immutable as $$select jsonb_build_object('template','soccer','order_by','points','win_points',3,'tie_points',1,'loss_points',0,'tie_weight',0.5,'allow_ties',true,'mini_table_restart',true,'tiebreaks',rules)$$;
create function pg_temp.rankings(entries text[],results jsonb,rules jsonb)returns jsonb language sql immutable as $$select boss_private.ranking_resolve_cohort((select jsonb_agg(jsonb_build_object('entry_id',id,'metrics','{}'::jsonb))from unnest(entries)id),results,pg_temp.policy(rules),0,1)$$;
create function pg_temp.ranks(result jsonb)returns jsonb language sql immutable as $$select jsonb_object_agg(r->>'entry_id',r->'rank')from jsonb_array_elements(result)r$$;
select pg_temp.ok('no hidden ordering without rules',pg_temp.ranks(pg_temp.rankings(array['A','B','C'],'[]','[]'))='{"A":1,"B":1,"C":1}');
select pg_temp.ok('two team head-to-head resolves',pg_temp.ranks(pg_temp.rankings(array['A','B'],jsonb_build_array(pg_temp.result('A','B',3,1)),'[{"type":"head_to_head"}]'))='{"A":1,"B":2}');
select pg_temp.ok('head-to-head draw remains tied',pg_temp.ranks(pg_temp.rankings(array['A','B'],jsonb_build_array(pg_temp.result('A','B',1,1)),'[{"type":"head_to_head"}]'))='{"A":1,"B":1}');
select pg_temp.ok('missing pair remains inapplicable',pg_temp.ranks(pg_temp.rankings(array['A','B','C'],jsonb_build_array(pg_temp.result('A','B',3,1)),'[{"type":"mini_table"}]'))='{"A":1,"B":1,"C":1}');
select pg_temp.ok('circular three-team tie is not pairwise sorted',pg_temp.ranks(pg_temp.rankings(array['A','B','C'],jsonb_build_array(pg_temp.result('A','B',10,5),pg_temp.result('B','C',7,5),pg_temp.result('C','A',8,7)),'[{"type":"mini_table"}]'))='{"A":1,"B":1,"C":1}');
select pg_temp.ok('configured differential resolves frozen oracle',pg_temp.ranks(pg_temp.rankings(array['A','B','C'],jsonb_build_array(pg_temp.result('A','B',10,5),pg_temp.result('B','C',7,5),pg_temp.result('C','A',8,7)),'[{"type":"mini_table"},{"type":"differential"}]'))='{"A":1,"B":3,"C":2}');
select pg_temp.ok('score cap is applied per game',pg_temp.ranks(pg_temp.rankings(array['A','B','C'],jsonb_build_array(pg_temp.result('A','B',10,5),pg_temp.result('B','C',7,5),pg_temp.result('C','A',8,7)),'[{"type":"capped_differential","cap":2}]'))='{"A":1,"B":2,"C":3}');
select pg_temp.ok('unbalanced meetings remain tied',pg_temp.ranks(pg_temp.rankings(array['A','B','C'],jsonb_build_array(pg_temp.result('A','B',10,5),pg_temp.result('A','B',10,5),pg_temp.result('B','C',7,5),pg_temp.result('C','A',8,7)),'[{"type":"mini_table"}]'))='{"A":1,"B":1,"C":1}');
select pg_temp.ok('common opponents whole-cohort intersection',pg_temp.ranks(pg_temp.rankings(array['A','B'],jsonb_build_array(pg_temp.result('A','X',3,1),pg_temp.result('B','X',0,1),pg_temp.result('A','Y',20,1)),'[{"type":"common_opponents"}]'))='{"A":1,"B":2}');
select pg_temp.ok('SOS foundation invents no ordering',pg_temp.ranks(pg_temp.rankings(array['A','B'],jsonb_build_array(pg_temp.result('A','B',3,1)),'[{"type":"strength_of_schedule"}]'))='{"A":1,"B":1}');
select pg_temp.ok('undefined score does not become zero differential',pg_temp.ranks(pg_temp.rankings(array['A','B'],jsonb_build_array(pg_temp.result('A','B',3,1)-array['pf','pa']),'[{"type":"differential"}]'))='{"A":1,"B":1}');
select pg_temp.ok('explanation includes compared values',pg_temp.rankings(array['A','B'],jsonb_build_array(pg_temp.result('A','B',3,1)),'[{"type":"head_to_head"}]')->0->'explanation'->'steps'->0->'values' @>'[{"entry_id":"A","value":1},{"entry_id":"B","value":0}]');
select pg_temp.ok('unresolved explanation explicit',pg_temp.rankings(array['A','B'],'[]','[]')->0->'explanation'->>'state'='unresolved_tie');
-- Permutations change neither numeric ranks nor the frozen value oracle.
select pg_temp.ok('permutation-independent whole-cohort result:'||i,
 pg_temp.ranks(pg_temp.rankings(ids,jsonb_build_array(pg_temp.result('A','B',10,5),pg_temp.result('B','C',7,5),pg_temp.result('C','A',8,7)),'[{"type":"mini_table"},{"type":"differential"}]'))='{"A":1,"B":3,"C":2}')from(values(1,array['A','B','C']),(2,array['A','C','B']),(3,array['B','A','C']),(4,array['B','C','A']),(5,array['C','A','B']),(6,array['C','B','A']))p(i,ids);
select count(*)passed_assertions from rb_assertions;
rollback;
