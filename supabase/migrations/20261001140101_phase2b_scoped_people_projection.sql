-- Preserve Phase 2B names-only discovery and affordances while bounding scoped
-- work to caller-authorized relationship candidates. No grants/policies change.
create or replace function boss_private.admin_people(p_organization_id uuid default null,p_query text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  actor uuid; result jsonb;
  global_view boolean; global_person_manage boolean; global_participant_manage boolean;
  org_members_view boolean; org_participant_manage boolean;
begin
  actor:=boss_private.require_admin_actor();
  global_view:=boss_private.has_permission('person.profile.view');
  global_person_manage:=boss_private.has_permission('person.profile.manage');
  global_participant_manage:=boss_private.has_permission('participant.profile.manage');
  org_members_view:=p_organization_id is not null and boss_private.has_permission('organization.members.view',p_organization_id);
  org_participant_manage:=p_organization_id is not null and boss_private.has_permission('participant.profile.manage',p_organization_id);
  if p_query is not null and p_organization_id is null and not global_view then
    raise exception 'Request not permitted.' using errcode='PT403';
  end if;

  with guardian_people as materialized (
    select distinct g.dependent_person_id person_id
    from public.guardian_relationships g join public.people p on p.id=g.dependent_person_id and p.status='active'
    where g.guardian_person_id=actor and g.authority_status='active' and g.can_manage_profile
      and g.verified_at<=now() and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())
  ), team_capabilities as materialized (
    select t.id,
      (boss_private.has_permission('team.roster.view',t.organization_id,t.parent_unit_id,t.id)
        or boss_private.has_permission('participant.profile.view',t.organization_id,t.parent_unit_id,t.id)) can_view,
      boss_private.has_permission('participant.profile.manage',t.organization_id,t.parent_unit_id,t.id) can_manage
    from public.teams t where p_organization_id is not null and t.organization_id=p_organization_id
  ), org_relationships as materialized (
    select distinct m.person_id from public.organization_memberships m
    where p_organization_id is not null and m.organization_id=p_organization_id
      and m.status='active' and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
      and (org_members_view or org_participant_manage)
  ), team_relationships as materialized (
    select m.person_id,c.can_view,c.can_manage
    from public.team_memberships m join team_capabilities c on c.id=m.team_id
    where m.organization_id=p_organization_id and m.status='active'
      and m.starts_at<=now() and (m.ends_at is null or m.ends_at>now())
      and (c.can_view or c.can_manage)
  ), candidate_ids as materialized (
    select actor person_id
    union select g.person_id from guardian_people g
    union select m.person_id from org_relationships m where org_members_view
    union select m.person_id from team_relationships m where m.can_view
  ), participant_manage_ids as materialized (
    select m.person_id from org_relationships m where org_participant_manage
    union select m.person_id from team_relationships m where m.can_manage
  ), eligible_people as (
    -- A one-time filter skips the directory branch for a scoped caller. The
    -- scoped branch starts with small authorized IDs and looks up canonical PKs.
    select p.id,p.first_name,p.middle_name,p.last_name,p.preferred_name,p.display_name,p.status
    from public.people p where global_view
    union all
    select p.id,p.first_name,p.middle_name,p.last_name,p.preferred_name,p.display_name,p.status
    from candidate_ids c join public.people p on p.id=c.person_id where not global_view
  )
  select coalesce(jsonb_agg(item order by label,id),'[]'::jsonb) into result from (
    select p.id,coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),''),'Unnamed person') label,
      boss_private.admin_record(p.id,coalesce(p.display_name,p.preferred_name,nullif(concat_ws(' ',p.first_name,p.last_name),'')),p.status,
        jsonb_build_object('first_name',p.first_name,'middle_name',p.middle_name,'last_name',p.last_name,'preferred_name',p.preferred_name,'display_name',p.display_name),
        array_remove(array[
          case when global_person_manage or p.id in (select g.person_id from guardian_people g) then 'person.update' end,
          case when p.status='active' and (global_participant_manage or p.id in (select m.person_id from participant_manage_ids m)) then 'participant.create' end
        ],null)) item
    from eligible_people p
    where p_query is null or concat_ws(' ',p.first_name,p.last_name,p.preferred_name,p.display_name) ilike '%'||p_query||'%'
    order by label,p.id limit 50
  ) s;
  return result;
end $$;
revoke all on function boss_private.admin_people(uuid,text) from public,anon,authenticated,service_role;
grant execute on function boss_private.admin_people(uuid,text) to authenticated;
