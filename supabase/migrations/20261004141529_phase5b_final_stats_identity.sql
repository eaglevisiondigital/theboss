-- Stable row identity for immutable sealed totals. Existing per-epoch/side/roster
-- uniqueness, closed grants, RLS and rewrite guards remain authoritative.
alter table public.game_basketball_final_stats
 add column id uuid not null default gen_random_uuid() primary key;
