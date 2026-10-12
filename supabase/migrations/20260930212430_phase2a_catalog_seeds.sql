-- Stable foundation definitions only. No identities, tenants, households,
-- relationships, role assignments, product activations or customers are seeded.
insert into public.roles (key, name, allowed_scope_types) values
  ('super_administrator', 'Super administrator', array['platform']),
  ('platform_administrator', 'Platform administrator', array['platform']),
  ('support', 'Support', array['platform']),
  ('finance', 'Finance', array['platform']),
  ('sales', 'Sales', array['platform']),
  ('merchant_network_staff', 'Merchant network staff', array['platform']),
  ('compliance', 'Compliance', array['platform']),
  ('organization_owner', 'Organization owner', array['organization']),
  ('organization_administrator', 'Organization administrator', array['organization']),
  ('athletic_director', 'Athletic director', array['organization']),
  ('program_administrator', 'Program administrator', array['organization_unit']),
  ('sport_administrator', 'Sport administrator', array['organization_unit']),
  ('head_coach', 'Head coach', array['team']),
  ('assistant_coach', 'Assistant coach', array['team']),
  ('team_administrator', 'Team administrator', array['team']),
  ('team_staff', 'Team staff', array['team']),
  ('volunteer_coordinator', 'Volunteer coordinator', array['team']),
  ('scorekeeper', 'Scorekeeper', array['team']),
  ('livestream_operator', 'Livestream operator', array['team']);

-- Canonical person privacy is deliberately separate from participant metadata.
-- A scoped participant.profile.view grant cannot reveal unrelated DOB/contact.
insert into public.permissions (key, name) values
  ('person.profile.view', 'View canonical person profile'),
  ('person.profile.manage', 'Manage canonical person profile'),
  ('organization.view', 'View organization'),
  ('organization.manage', 'Manage organization'),
  ('organization.members.view', 'View organization memberships'),
  ('organization.members.manage', 'Manage organization memberships'),
  ('team.view', 'View team'),
  ('team.manage', 'Manage team'),
  ('team.roster.view', 'View team roster'),
  ('team.roster.manage', 'Manage team roster'),
  ('participant.profile.view', 'View participant metadata'),
  ('participant.profile.manage', 'Manage participant metadata'),
  ('household.view', 'View household'),
  ('household.manage', 'Manage household'),
  ('roles.view', 'View role assignments'),
  ('roles.assign', 'Assign scoped roles'),
  ('audit.view', 'View audit events');

insert into public.modules (key, name) values
  ('fundraising', 'Fundraising'), ('boss_bucks', 'Boss Bucks'),
  ('sports', 'Sports'), ('engage', 'Engage'),
  ('registration', 'Registration'), ('documents', 'Documents'),
  ('messaging', 'Messaging'), ('volunteers', 'Volunteers'),
  ('money_board', 'Money Board'), ('commerce', 'Commerce'),
  ('livestream', 'Livestream'), ('fan', 'Fan'), ('reporting', 'Reporting');

-- Approved foundational potential capabilities. A mapping never bypasses the
-- assignment scope, actual resource context, lifecycle or row policy. Management
-- keys do not open client write paths; trusted mutation APIs are a later phase.
-- Global household/person data has no inferred organization authority.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.key in ('super_administrator', 'platform_administrator');

with approved (role_key, permission_keys) as (values
  ('support', array['organization.view']),
  ('sales', array['organization.view']),
  ('compliance', array['organization.view']),
  ('organization_owner', array[
    'organization.view', 'organization.manage',
    'organization.members.view', 'organization.members.manage',
    'team.view', 'team.manage', 'team.roster.view', 'team.roster.manage',
    'participant.profile.view', 'participant.profile.manage',
    'household.view', 'household.manage', 'roles.view', 'roles.assign', 'audit.view']),
  ('organization_administrator', array[
    'organization.view', 'organization.manage',
    'organization.members.view', 'organization.members.manage',
    'team.view', 'team.manage', 'team.roster.view', 'team.roster.manage',
    'participant.profile.view', 'participant.profile.manage',
    'household.view', 'household.manage', 'roles.view', 'roles.assign', 'audit.view']),
  ('athletic_director', array[
    'organization.view', 'organization.members.view', 'team.view', 'team.manage',
    'team.roster.view', 'team.roster.manage',
    'participant.profile.view', 'participant.profile.manage',
    'household.view', 'roles.view']),
  ('program_administrator', array[
    'organization.view', 'organization.manage', 'team.view', 'team.manage',
    'team.roster.view', 'team.roster.manage',
    'participant.profile.view', 'participant.profile.manage', 'roles.view']),
  ('sport_administrator', array[
    'organization.view', 'organization.manage', 'team.view', 'team.manage',
    'team.roster.view', 'team.roster.manage',
    'participant.profile.view', 'participant.profile.manage', 'roles.view']),
  ('head_coach', array[
    'team.view', 'team.manage', 'team.roster.view', 'team.roster.manage',
    'participant.profile.view']),
  ('assistant_coach', array['team.view', 'team.roster.view', 'participant.profile.view']),
  ('team_administrator', array['team.view', 'team.manage', 'team.roster.view', 'team.roster.manage']),
  ('team_staff', array['team.view', 'team.roster.view']),
  ('volunteer_coordinator', array['team.view']),
  ('scorekeeper', array['team.view']),
  ('livestream_operator', array['team.view'])
)
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from approved a
join public.roles r on r.key = a.role_key
join public.permissions p on p.key = any(a.permission_keys);

-- Finance and merchant staff have no current foundational need for private
-- operational permissions. Their future module permissions are not invented.
-- Feature flag definitions remain empty until a concrete rollout is approved.
