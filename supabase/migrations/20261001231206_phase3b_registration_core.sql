-- Phase 3B reusable registration foundation. No processor, wallet or later module.
-- Private data is available only through finite caller-bound projections/RPCs.
create table public.registration_offerings (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict,
 title text not null, description text, scope_type text not null, scope_id uuid not null,
 unit_id uuid generated always as (case when scope_type='unit' then scope_id end) stored,
 team_id uuid generated always as (case when scope_type='team' then scope_id end) stored,
 season_id uuid, event_id uuid, registration_type text not null default 'program', participant_type text not null default 'participant',
 opens_at timestamptz, closes_at timestamptz, capacity integer, waitlist_enabled boolean not null default false,
 approval_required boolean not null default true, visibility text not null default 'authenticated', status text not null default 'draft',
 age_min integer, age_max integer, grade_min integer, grade_max integer, returning_behavior text not null default 'confirm_existing',
 team_assignment_policy jsonb not null default '{"mode":"manual","require_approval":true}',
 created_by_person_id uuid not null references public.people(id) on delete restrict,
 updated_by_person_id uuid not null references public.people(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), version bigint not null default 1,
 unique(organization_id,id), foreign key(organization_id,unit_id) references public.organization_units(organization_id,id) on delete restrict,
 foreign key(organization_id,team_id) references public.teams(organization_id,id) on delete restrict,
 foreign key(organization_id,season_id) references public.seasons(organization_id,id) on delete restrict,
 foreign key(organization_id,event_id) references public.events(organization_id,id) on delete restrict,
 check(scope_type in ('organization','unit','team')),check(scope_type<>'organization' or scope_id=organization_id),
 check(length(btrim(title)) between 1 and 200),check(length(coalesce(description,''))<=4000),
 check(length(btrim(registration_type)) between 1 and 60),check(length(btrim(participant_type)) between 1 and 60),
 check(status in ('draft','published','closed','archived')),check(visibility in ('authenticated','member','restricted')),
 check(opens_at is null or isfinite(opens_at)),check(closes_at is null or isfinite(closes_at)),check(opens_at is null or closes_at is null or closes_at>opens_at),
 check(capacity is null or capacity between 1 and 1000000),check(version>0),
 check(age_min is null or age_min between 0 and 125),check(age_max is null or age_max between 0 and 125),check(age_min is null or age_max is null or age_max>=age_min),
 check(grade_min is null or grade_min between 0 and 20),check(grade_max is null or grade_max between 0 and 20),check(grade_min is null or grade_max is null or grade_max>=grade_min),
 check(returning_behavior='confirm_existing'),check(jsonb_typeof(team_assignment_policy)='object')
);
create table public.registration_form_versions (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 form_key text not null,title text not null,version_number integer not null,definition jsonb not null,sensitivity text not null default 'ordinary',
 published_by_person_id uuid not null references public.people(id) on delete restrict,published_at timestamptz not null default now(),
 unique(organization_id,id),unique(organization_id,form_key,version_number),check(form_key ~ '^[a-z][a-z0-9_]{0,59}$'),
 check(length(btrim(title)) between 1 and 200),check(version_number>0),check(sensitivity in ('ordinary','medical')),check(jsonb_typeof(definition)='object')
);
create table public.registration_waiver_versions (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 waiver_key text not null,title text not null,version_number integer not null,body text not null,signer_type text not null default 'guardian',
 effective_from timestamptz not null default now(),effective_until timestamptz,
 published_by_person_id uuid not null references public.people(id) on delete restrict,published_at timestamptz not null default now(),
 unique(organization_id,id),unique(organization_id,waiver_key,version_number),check(waiver_key ~ '^[a-z][a-z0-9_]{0,59}$'),
 check(length(btrim(title)) between 1 and 200),check(length(btrim(body)) between 1 and 60000),check(version_number>0),
 check(signer_type in ('guardian','participant','either')),check(isfinite(effective_from)),check(effective_until is null or (isfinite(effective_until) and effective_until>effective_from))
);
create table public.document_requirements (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 key text not null,title text not null,version_number integer not null,classification text not null default 'standard',required boolean not null default true,
 emergency_access boolean not null default false,allowed_mime_types text[] not null default array['application/pdf','image/jpeg','image/png'],
 max_bytes bigint not null default 10485760,validity_days integer,
 created_by_person_id uuid not null references public.people(id) on delete restrict,created_at timestamptz not null default now(),
 unique(organization_id,id),unique(organization_id,key,version_number),check(key ~ '^[a-z][a-z0-9_]{0,59}$'),
 check(length(btrim(title)) between 1 and 200),check(version_number>0),check(classification in ('standard','identity','medical')),
 check(not emergency_access or classification='medical'),check(cardinality(allowed_mime_types) between 1 and 3 and array_position(allowed_mime_types,null) is null and allowed_mime_types <@ array['application/pdf','image/jpeg','image/png']),
 check(max_bytes between 1 and 10485760),check(validity_days is null or validity_days between 1 and 3650)
);
create table public.registration_offering_forms (
 organization_id uuid not null,offering_id uuid not null,form_version_id uuid not null,required boolean not null default true,sort_order integer not null default 0,
 primary key(offering_id,form_version_id),foreign key(organization_id,offering_id) references public.registration_offerings(organization_id,id) on delete restrict,
 foreign key(organization_id,form_version_id) references public.registration_form_versions(organization_id,id) on delete restrict,check(sort_order between 0 and 1000)
);
create table public.registration_offering_waivers (
 organization_id uuid not null,offering_id uuid not null,waiver_version_id uuid not null,required boolean not null default true,sort_order integer not null default 0,
 primary key(offering_id,waiver_version_id),foreign key(organization_id,offering_id) references public.registration_offerings(organization_id,id) on delete restrict,
 foreign key(organization_id,waiver_version_id) references public.registration_waiver_versions(organization_id,id) on delete restrict,check(sort_order between 0 and 1000)
);
create table public.registration_offering_documents (
 organization_id uuid not null,offering_id uuid not null,document_requirement_id uuid not null,required boolean not null default true,sort_order integer not null default 0,
 primary key(offering_id,document_requirement_id),foreign key(organization_id,offering_id) references public.registration_offerings(organization_id,id) on delete restrict,
 foreign key(organization_id,document_requirement_id) references public.document_requirements(organization_id,id) on delete restrict,check(sort_order between 0 and 1000)
);
create table public.registration_fee_rules (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,offering_id uuid not null,title text not null,charge_type text not null default 'registration',
 amount_minor bigint not null,currency text not null,due_on date,required boolean not null default true,status text not null default 'active',version bigint not null default 1,
 unique(organization_id,id),foreign key(organization_id,offering_id) references public.registration_offerings(organization_id,id) on delete restrict,
 check(length(btrim(title)) between 1 and 200),check(length(btrim(charge_type)) between 1 and 60),check(amount_minor between 0 and 1000000000),
 check(currency ~ '^[A-Z]{3}$'),check(status in ('active','inactive','archived')),check(version>0)
);
create table public.registration_coupons (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,offering_id uuid not null,code text not null,title text not null,
 adjustment_type text not null,amount_minor bigint,percent_bps integer,max_uses integer,used_count integer not null default 0,
 opens_at timestamptz,closes_at timestamptz,status text not null default 'active',
 created_by_person_id uuid not null references public.people(id) on delete restrict,created_at timestamptz not null default now(),version bigint not null default 1,
 unique(organization_id,id),unique(offering_id,code),foreign key(organization_id,offering_id) references public.registration_offerings(organization_id,id) on delete restrict,
 check(code ~ '^[A-Z0-9_-]{1,40}$'),check(length(btrim(title)) between 1 and 200),check(adjustment_type in ('fixed','percent')),
 check((adjustment_type='fixed' and amount_minor between 1 and 1000000000 and percent_bps is null) or (adjustment_type='percent' and percent_bps between 1 and 10000 and amount_minor is null)),
 check(max_uses is null or max_uses between 1 and 1000000),check(used_count>=0 and (max_uses is null or used_count<=max_uses)),
 check(opens_at is null or closes_at is null or closes_at>opens_at),check(status in ('active','inactive','archived')),check(version>0)
);
create table public.registrations (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,offering_id uuid not null,
 participant_id uuid not null references public.participants(id) on delete restrict,household_id uuid references public.households(id) on delete restrict,
 submitted_by_person_id uuid not null references public.people(id) on delete restrict,
 status text not null default 'draft',form_status text not null default 'not_started',waiver_status text not null default 'missing',document_status text not null default 'missing',
 eligibility_status text not null default 'pending',approval_status text not null default 'pending',roster_status text not null default 'not_assigned',
 assigned_team_id uuid,waitlist_position bigint,offering_snapshot jsonb not null,participant_snapshot jsonb not null,family_snapshot jsonb not null default '{}',context jsonb not null default '{}',
 submitted_at timestamptz,reviewed_by_person_id uuid references public.people(id) on delete restrict,reviewed_at timestamptz,review_reason text,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),version bigint not null default 1,
 unique(organization_id,id),unique(organization_id,id,participant_id),
 foreign key(organization_id,offering_id) references public.registration_offerings(organization_id,id) on delete restrict,
 foreign key(organization_id,assigned_team_id) references public.teams(organization_id,id) on delete restrict,
 check(status in ('draft','submitted','under_review','approved','denied','waitlisted','withdrawn','canceled','archived')),
 check(form_status in ('not_started','draft','submitted','not_required')),check(waiver_status in ('missing','partially_signed','signed','not_required')),
 check(document_status in ('missing','submitted','under_review','approved','rejected','expired','waived','not_required')),
 check(eligibility_status in ('pending','eligible','ineligible','waived')),check(approval_status in ('pending','approved','denied','not_required')),
 check(roster_status in ('not_assigned','assigned','removed')),check((roster_status='assigned')=(assigned_team_id is not null)),
 check(waitlist_position is null or waitlist_position>0),check(version>0),check(length(coalesce(review_reason,''))<=2000),
 check(jsonb_typeof(offering_snapshot)='object' and jsonb_typeof(participant_snapshot)='object' and jsonb_typeof(family_snapshot)='object' and jsonb_typeof(context)='object')
);
create unique index registrations_one_current_participant_idx on public.registrations(offering_id,participant_id) where status not in ('withdrawn','canceled','archived','denied');
create unique index registrations_waitlist_position_idx on public.registrations(offering_id,waitlist_position) where waitlist_position is not null;
create table public.registration_form_answers (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,registration_id uuid not null,form_version_id uuid not null,
 answers jsonb not null default '{}',status text not null default 'draft',respondent_person_id uuid not null references public.people(id) on delete restrict,
 completed_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),version bigint not null default 1,
 unique(registration_id,form_version_id),foreign key(organization_id,registration_id) references public.registrations(organization_id,id) on delete restrict,
 foreign key(organization_id,form_version_id) references public.registration_form_versions(organization_id,id) on delete restrict,
 check(jsonb_typeof(answers)='object'),check(status in ('draft','submitted')),check((status='submitted')=(completed_at is not null)),check(version>0)
);
create table public.waiver_signatures (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,registration_id uuid not null,waiver_version_id uuid not null,participant_id uuid not null,
 signer_person_id uuid not null references public.people(id) on delete restrict,signer_name text not null,consent boolean not null,
 signed_at timestamptz not null default now(),version_snapshot jsonb not null,request_context jsonb not null default '{}',status text not null default 'signed',
 unique(registration_id,waiver_version_id,signer_person_id),foreign key(organization_id,registration_id,participant_id) references public.registrations(organization_id,id,participant_id) on delete restrict,
 foreign key(organization_id,waiver_version_id) references public.registration_waiver_versions(organization_id,id) on delete restrict,
 check(consent),check(length(btrim(signer_name)) between 1 and 200),check(status='signed'),check(jsonb_typeof(version_snapshot)='object' and jsonb_typeof(request_context)='object')
);
create table public.registration_documents (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,registration_id uuid not null,participant_id uuid not null,requirement_id uuid not null,
 status text not null default 'missing',snapshot jsonb not null,object_name text,upload_mime_type text,upload_size_bytes bigint,upload_sha256 text,
 uploaded_by_person_id uuid references public.people(id) on delete restrict,uploaded_at timestamptz,
 reviewed_by_person_id uuid references public.people(id) on delete restrict,reviewed_at timestamptz,review_reason text,expires_on date,renewal_due_on date,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),version bigint not null default 1,
 unique(organization_id,id),unique(registration_id,requirement_id),unique(object_name),
 foreign key(organization_id,registration_id,participant_id) references public.registrations(organization_id,id,participant_id) on delete restrict,
 foreign key(organization_id,requirement_id) references public.document_requirements(organization_id,id) on delete restrict,
 check(status in ('missing','upload_pending','submitted','under_review','approved','rejected','expired','waived')),
 check(jsonb_typeof(snapshot)='object'),check(upload_mime_type is null or upload_mime_type in ('application/pdf','image/jpeg','image/png')),
 check(upload_size_bytes is null or upload_size_bytes between 1 and 10485760),check(upload_sha256 is null or upload_sha256 ~ '^[a-f0-9]{64}$'),
 check(length(coalesce(review_reason,''))<=2000),check(renewal_due_on is null or expires_on is null or renewal_due_on<=expires_on),check(version>0)
);
create table public.document_upload_intents (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,document_id uuid not null,
 actor_person_id uuid not null references public.people(id) on delete restrict,auth_session_id uuid not null,
 object_name text not null unique,mime_type text not null,size_bytes bigint not null,sha256 text,
 expires_at timestamptz not null,consumed_at timestamptz,created_at timestamptz not null default now(),
 foreign key(organization_id,document_id) references public.registration_documents(organization_id,id) on delete restrict,
 check(mime_type in ('application/pdf','image/jpeg','image/png')),check(size_bytes between 1 and 10485760),check(sha256 is null or sha256 ~ '^[a-f0-9]{64}$'),
 check(expires_at>created_at and expires_at<=created_at+interval '30 minutes')
);
create table boss_private.document_access_leases (
 id uuid primary key default gen_random_uuid(),document_id uuid not null references public.registration_documents(id) on delete restrict,
 actor_person_id uuid not null references public.people(id) on delete restrict,auth_session_id uuid not null,purpose text not null,team_id uuid references public.teams(id) on delete restrict,
 expires_at timestamptz not null,created_at timestamptz not null default now(),check(purpose in ('ordinary','emergency')),
 check((purpose='emergency')=(team_id is not null)),check(expires_at>created_at and expires_at<=created_at+interval '2 minutes')
);
create table public.participant_emergency_records (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,registration_id uuid not null unique,participant_id uuid not null,
 contacts jsonb not null default '[]',medical jsonb not null default '{}',physician jsonb not null default '{}',insurance jsonb not null default '{}',
 updated_by_person_id uuid not null references public.people(id) on delete restrict,updated_at timestamptz not null default now(),version bigint not null default 1,
 foreign key(organization_id,registration_id,participant_id) references public.registrations(organization_id,id,participant_id) on delete restrict,
 check(jsonb_typeof(contacts)='array' and jsonb_array_length(contacts)<=10),check(jsonb_typeof(medical)='object' and jsonb_typeof(physician)='object' and jsonb_typeof(insurance)='object'),
 check(octet_length(contacts::text)+octet_length(medical::text)+octet_length(physician::text)+octet_length(insurance::text)<=32000),check(version>0)
);
create table public.charges (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,registration_id uuid not null,participant_id uuid not null,
 household_id uuid references public.households(id) on delete restrict,event_id uuid,fee_rule_id uuid,title text not null,charge_type text not null,
 original_amount_minor bigint not null,currency text not null,due_on date,status text not null default 'active',
 created_by_person_id uuid not null references public.people(id) on delete restrict,created_at timestamptz not null default now(),
 unique(organization_id,id),foreign key(organization_id,registration_id,participant_id) references public.registrations(organization_id,id,participant_id) on delete restrict,
 foreign key(organization_id,event_id) references public.events(organization_id,id) on delete restrict,
 foreign key(organization_id,fee_rule_id) references public.registration_fee_rules(organization_id,id) on delete restrict,
 check(length(btrim(title)) between 1 and 200),check(length(btrim(charge_type)) between 1 and 60),check(original_amount_minor between 0 and 1000000000),
 check(currency ~ '^[A-Z]{3}$'),check(status in ('active','canceled'))
);
create unique index charges_registration_fee_idx on public.charges(registration_id,fee_rule_id) where fee_rule_id is not null;
create table public.charge_adjustments (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,charge_id uuid not null,amount_minor bigint not null,
 adjustment_type text not null,reason text not null,source_coupon_id uuid,recorded_by_person_id uuid not null references public.people(id) on delete restrict,created_at timestamptz not null default now(),
 foreign key(organization_id,charge_id) references public.charges(organization_id,id) on delete restrict,
 foreign key(organization_id,source_coupon_id) references public.registration_coupons(organization_id,id) on delete restrict,
 check(amount_minor between -1000000000 and 1000000000 and amount_minor<>0),check(adjustment_type in ('discount','coupon','scholarship','credit','surcharge')),
 check((adjustment_type='surcharge' and amount_minor>0) or (adjustment_type<>'surcharge' and amount_minor<0)),check(length(btrim(reason)) between 1 and 2000)
);
create table public.payments (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 method text not null,amount_minor bigint not null,currency text not null,payer_person_id uuid not null references public.people(id) on delete restrict,
 received_at timestamptz not null,reference text,note text,source_reference text,
 recorded_by_person_id uuid not null references public.people(id) on delete restrict,status text not null default 'recorded',reversal_of_id uuid,
 created_at timestamptz not null default now(),unique(organization_id,id),
 foreign key(organization_id,reversal_of_id) references public.payments(organization_id,id) on delete restrict,
 check(method in ('cash','check')),check(amount_minor between 1 and 1000000000),check(currency ~ '^[A-Z]{3}$'),
 check(isfinite(received_at)),check(length(coalesce(reference,''))<=200),check(length(coalesce(note,''))<=2000),check(length(coalesce(source_reference,''))<=200),
 check(status in ('recorded','reversed')),check((status='reversed')=(reversal_of_id is not null)),check(reversal_of_id is null or reversal_of_id<>id)
);
create table public.payment_allocations (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,payment_id uuid not null,charge_id uuid not null,amount_minor bigint not null,
 status text not null default 'applied',reversal_of_id uuid,created_at timestamptz not null default now(),unique(organization_id,id),
 foreign key(organization_id,payment_id) references public.payments(organization_id,id) on delete restrict,
 foreign key(organization_id,charge_id) references public.charges(organization_id,id) on delete restrict,
 foreign key(organization_id,reversal_of_id) references public.payment_allocations(organization_id,id) on delete restrict,
 check(amount_minor between 1 and 1000000000),check(status in ('applied','reversed')),check((status='reversed')=(reversal_of_id is not null)),check(reversal_of_id is null or reversal_of_id<>id)
);
create table public.payment_plans (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,registration_id uuid not null,charge_id uuid not null,title text not null,status text not null default 'active',
 created_by_person_id uuid not null references public.people(id) on delete restrict,created_at timestamptz not null default now(),unique(organization_id,id),
 foreign key(organization_id,registration_id) references public.registrations(organization_id,id) on delete restrict,
 foreign key(organization_id,charge_id) references public.charges(organization_id,id) on delete restrict,check(length(btrim(title)) between 1 and 200),check(status in ('active','canceled'))
);
create unique index payment_plans_active_charge_idx on public.payment_plans(charge_id) where status='active';
create table public.payment_installments (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,payment_plan_id uuid not null,charge_id uuid not null,
 sequence_number integer not null,amount_minor bigint not null,due_on date not null,created_at timestamptz not null default now(),
 unique(payment_plan_id,sequence_number),foreign key(organization_id,payment_plan_id) references public.payment_plans(organization_id,id) on delete restrict,
 foreign key(organization_id,charge_id) references public.charges(organization_id,id) on delete restrict,
 check(sequence_number between 1 and 60),check(amount_minor between 1 and 1000000000)
);

-- Every public table is closed by default; a raw SELECT grant is deliberately
-- absent because independent columns have materially different privacy rules.
do $$ declare t text; begin foreach t in array array['registration_offerings','registration_form_versions','registration_waiver_versions','document_requirements',
 'registration_offering_forms','registration_offering_waivers','registration_offering_documents','registration_fee_rules','registration_coupons','registrations',
 'registration_form_answers','waiver_signatures','registration_documents','document_upload_intents','participant_emergency_records','charges','charge_adjustments','payments',
 'payment_allocations','payment_plans','payment_installments'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;end $$;
alter table boss_private.document_access_leases enable row level security;
revoke all on boss_private.document_access_leases from public,anon,authenticated,service_role;

-- Each document transition preserves the prior private evidence, including
-- historical reviewer comments and immutable object references for renewal.
create table boss_private.registration_document_history (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,document_id uuid not null,version bigint not null,
 snapshot jsonb not null,changed_by_person_id uuid references public.people(id) on delete restrict,recorded_at timestamptz not null default now(),
 unique(document_id,version),foreign key(organization_id,document_id) references public.registration_documents(organization_id,id) on delete restrict,
 check(version>0),check(jsonb_typeof(snapshot)='object')
);
alter table boss_private.registration_document_history enable row level security;
revoke all on boss_private.registration_document_history from public,anon,authenticated,service_role;
create index document_history_document_idx on boss_private.registration_document_history(organization_id,document_id);
create index document_history_actor_idx on boss_private.registration_document_history(changed_by_person_id);

-- Cover every FK and high-frequency organization/participant/status lookup.
create index registration_offerings_scope_idx on public.registration_offerings(organization_id,scope_type,scope_id,status);
create index registration_offerings_unit_idx on public.registration_offerings(organization_id,unit_id);
create index registration_offerings_team_idx on public.registration_offerings(organization_id,team_id);
create index registration_offerings_season_idx on public.registration_offerings(organization_id,season_id);
create index registration_offerings_event_idx on public.registration_offerings(organization_id,event_id);
create index registration_offerings_creator_idx on public.registration_offerings(created_by_person_id);
create index registration_offerings_updater_idx on public.registration_offerings(updated_by_person_id);
create index registration_forms_publisher_idx on public.registration_form_versions(published_by_person_id);
create index registration_waivers_publisher_idx on public.registration_waiver_versions(published_by_person_id);
create index document_requirements_creator_idx on public.document_requirements(created_by_person_id);
create index registration_offering_forms_offering_idx on public.registration_offering_forms(organization_id,offering_id);
create index registration_offering_forms_definition_idx on public.registration_offering_forms(organization_id,form_version_id);
create index registration_offering_waivers_offering_idx on public.registration_offering_waivers(organization_id,offering_id);
create index registration_offering_waivers_definition_idx on public.registration_offering_waivers(organization_id,waiver_version_id);
create index registration_offering_documents_offering_idx on public.registration_offering_documents(organization_id,offering_id);
create index registration_offering_documents_definition_idx on public.registration_offering_documents(organization_id,document_requirement_id);
create index registration_fee_rules_offering_idx on public.registration_fee_rules(organization_id,offering_id);
create index registration_coupons_offering_idx on public.registration_coupons(organization_id,offering_id);
create index registration_coupons_creator_idx on public.registration_coupons(created_by_person_id);
create index registrations_offering_capacity_idx on public.registrations(organization_id,offering_id,status);
create index registrations_participant_idx on public.registrations(participant_id,organization_id,created_at);
create index registrations_household_idx on public.registrations(household_id);
create index registrations_submitter_idx on public.registrations(submitted_by_person_id);
create index registrations_reviewer_idx on public.registrations(reviewed_by_person_id);
create index registrations_team_idx on public.registrations(organization_id,assigned_team_id);
create index registration_answers_registration_idx on public.registration_form_answers(organization_id,registration_id);
create index registration_answers_definition_idx on public.registration_form_answers(organization_id,form_version_id);
create index registration_answers_respondent_idx on public.registration_form_answers(respondent_person_id);
create index waiver_signatures_registration_idx on public.waiver_signatures(organization_id,registration_id,participant_id);
create index waiver_signatures_definition_idx on public.waiver_signatures(organization_id,waiver_version_id);
create index waiver_signatures_signer_idx on public.waiver_signatures(signer_person_id);
create index registration_documents_registration_idx on public.registration_documents(organization_id,registration_id,participant_id);
create index registration_documents_requirement_idx on public.registration_documents(organization_id,requirement_id);
create index registration_documents_uploader_idx on public.registration_documents(uploaded_by_person_id);
create index registration_documents_reviewer_idx on public.registration_documents(reviewed_by_person_id);
create index document_intents_document_idx on public.document_upload_intents(organization_id,document_id);
create index document_intents_actor_idx on public.document_upload_intents(actor_person_id,auth_session_id,expires_at);
create index document_leases_document_actor_idx on boss_private.document_access_leases(document_id,actor_person_id,auth_session_id,expires_at);
create index document_leases_actor_idx on boss_private.document_access_leases(actor_person_id);
create index document_leases_team_idx on boss_private.document_access_leases(team_id);
create index emergency_records_registration_idx on public.participant_emergency_records(organization_id,registration_id,participant_id);
create index emergency_records_updater_idx on public.participant_emergency_records(updated_by_person_id);
create index charges_registration_idx on public.charges(organization_id,registration_id,participant_id);
create index charges_household_idx on public.charges(household_id);
create index charges_event_idx on public.charges(organization_id,event_id);
create index charges_fee_idx on public.charges(organization_id,fee_rule_id);
create index charges_creator_idx on public.charges(created_by_person_id);
create index charge_adjustments_charge_idx on public.charge_adjustments(organization_id,charge_id);
create index charge_adjustments_coupon_idx on public.charge_adjustments(organization_id,source_coupon_id);
create index charge_adjustments_recorder_idx on public.charge_adjustments(recorded_by_person_id);
create index payments_payer_idx on public.payments(payer_person_id);
create index payments_recorder_idx on public.payments(recorded_by_person_id);
create index payments_reversal_idx on public.payments(organization_id,reversal_of_id);
create index payment_allocations_payment_idx on public.payment_allocations(organization_id,payment_id);
create index payment_allocations_charge_idx on public.payment_allocations(organization_id,charge_id);
create index payment_allocations_reversal_idx on public.payment_allocations(organization_id,reversal_of_id);
create index payment_plans_registration_idx on public.payment_plans(organization_id,registration_id);
create index payment_plans_charge_idx on public.payment_plans(organization_id,charge_id);
create index payment_plans_creator_idx on public.payment_plans(created_by_person_id);
create index payment_installments_plan_idx on public.payment_installments(organization_id,payment_plan_id);
create index payment_installments_charge_idx on public.payment_installments(organization_id,charge_id);

insert into public.permissions(key,name) values
 ('registration.view','View scoped registration summaries'),('registration.create','Create scoped registrations'),('registration.manage','Manage scoped registration workflows'),
 ('registration.review','Review scoped registrations'),('forms.manage','Publish scoped form versions'),('documents.view','Read scoped private documents'),
 ('documents.review','Review scoped documents'),('documents.emergency_view','Read minimum emergency information for exact-team participants'),
 ('fees.view','View scoped obligations and allocations'),('fees.manage','Manage scoped fees and explicit adjustments'),('payments.record_offline','Record scoped cash and check payments'),('waivers.manage','Publish scoped waiver versions');
insert into public.roles(key,name,allowed_scope_types) values
 ('registrar','Registrar',array['organization','organization_unit','team']),('organization_finance','Organization finance',array['organization','organization_unit','team']);
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p where p.key=any(array['registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','documents.emergency_view','fees.view','fees.manage','payments.record_offline','waivers.manage']) and (
 r.key in ('super_administrator','platform_administrator','organization_owner','organization_administrator')
 or (r.key in ('registrar','program_administrator','sport_administrator','athletic_director') and p.key=any(array['registration.view','registration.create','registration.manage','registration.review','forms.manage','documents.view','documents.review','waivers.manage']))
 or (r.key in ('finance','organization_finance') and p.key=any(array['fees.view','fees.manage','payments.record_offline']))
 or (r.key in ('head_coach','assistant_coach','team_staff') and p.key=any(array['registration.view','documents.emergency_view'])));

create function boss_private.registration_module_enabled(p_org uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organizations o join public.organization_modules om on om.organization_id=o.id join public.modules m on m.id=om.module_id
 where o.id=p_org and o.status='active' and m.key='registration' and m.status='active' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()))
$$;
create function boss_private.registration_feature(p_org uuid,p_key text) returns boolean
language sql stable security definer set search_path='' as $$
 select p_key=any(array['registration','forms','waivers','documents','fees','payment_plans','coupons','waitlists','offline_payments','emergency_access','coach_registration_view']) and
 coalesce((select case when jsonb_typeof(om.configuration->p_key)='boolean' then (om.configuration->>p_key)::boolean when om.configuration ? p_key then false
 else p_key=any(array['registration','forms','waivers']) end from public.organization_modules om join public.modules m on m.id=om.module_id join public.organizations o on o.id=om.organization_id
 where om.organization_id=p_org and o.status='active' and m.key='registration' and m.status='active' and om.status='active' and om.starts_at<=now() and (om.ends_at is null or om.ends_at>now()) order by om.starts_at desc limit 1),false)
$$;
create function boss_private.registration_can_scope(p_permission text,p_org uuid,p_type text,p_id uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$ declare v_unit uuid;v_result boolean;begin
 if boss_private.current_person_id() is null or not boss_private.registration_feature(p_org,'registration') then return false;end if;
 if p_permission like 'documents.%' and not boss_private.registration_feature(p_org,'documents') then return false;end if;
 if p_permission like 'fees.%' and not boss_private.registration_feature(p_org,'fees') then return false;end if;
 if p_permission='payments.record_offline' and (not boss_private.registration_feature(p_org,'fees') or not boss_private.registration_feature(p_org,'offline_payments')) then return false;end if;
 if p_permission='forms.manage' and not boss_private.registration_feature(p_org,'forms') then return false;end if;
 if p_permission='waivers.manage' and not boss_private.registration_feature(p_org,'waivers') then return false;end if;
 if p_type='organization' then v_result:=p_id=p_org and boss_private.has_permission(p_permission,p_org);
 elsif p_type='unit' then v_result:=boss_private.has_permission(p_permission,p_org,p_id);
 elsif p_type='team' then select parent_unit_id into v_unit from public.teams where organization_id=p_org and id=p_id and status='active';if not found then return false;end if;
 v_result:=boss_private.has_permission(p_permission,p_org,v_unit,p_id);
 else return false;end if;
 if not coalesce(v_result,false) then return false;end if;
 -- Ordinary coaches only see registration summaries when the tenant opts in.
 if p_permission='registration.view' and not boss_private.registration_feature(p_org,'coach_registration_view') and not exists(
  select 1 from public.role_assignments a join public.roles r on r.id=a.role_id join public.role_permissions rp on rp.role_id=r.id join public.permissions p on p.id=rp.permission_id
  where a.person_id=boss_private.current_person_id() and a.status='active' and r.status='active' and p.status='active' and p.key=p_permission
  and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now()) and r.key not in ('head_coach','assistant_coach','team_staff')
  and ((a.scope_type='platform' and a.organization_id is null and a.scope_id is null) or (a.organization_id=p_org and
   ((a.scope_type='organization' and a.scope_id=p_org) or (a.scope_type='organization_unit' and a.scope_id=case when p_type='unit' then p_id else v_unit end)
   or (a.scope_type='team' and p_type='team' and a.scope_id=p_id))))) then return false;end if;
 return true;end $$;
create function boss_private.registration_guardian(p_participant uuid,p_flag text) returns boolean
language sql stable security definer set search_path='' as $$
 select p_flag=any(array['can_register','can_sign_waivers','can_view_documents','can_manage_payments']) and exists(
 select 1 from public.participants a join public.people p on p.id=a.person_id where a.id=p_participant and a.status='active' and p.status='active' and (
  p.id=boss_private.current_person_id() or exists(
  select 1 from public.guardian_relationships g where g.dependent_person_id=p.id and g.guardian_person_id=boss_private.current_person_id()
   and g.authority_status='active' and g.verified_at is not null and g.verified_at<=now() and g.starts_at<=now() and (g.ends_at is null or g.ends_at>now())
   and case p_flag when 'can_register' then g.can_register when 'can_sign_waivers' then g.can_sign_waivers when 'can_view_documents' then g.can_view_documents when 'can_manage_payments' then g.can_manage_payments else false end)))
$$;
create function boss_private.registration_can_record(p_permission text,p_registration uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.registration_can_scope(p_permission,r.organization_id,o.scope_type,o.scope_id) from public.registrations r
 join public.registration_offerings o on o.id=r.offering_id and o.organization_id=r.organization_id where r.id=p_registration),false)
$$;
create function boss_private.registration_can_document(p_document uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.registration_feature(d.organization_id,'registration') and boss_private.registration_feature(d.organization_id,'documents') and
  (boss_private.registration_guardian(d.participant_id,'can_view_documents') or boss_private.registration_can_record('documents.view',d.registration_id))
 from public.registration_documents d where d.id=p_document),false)
$$;
create function boss_private.registration_emergency_authorized(p_participant uuid,p_org uuid,p_team uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select boss_private.registration_feature(p_org,'registration') and boss_private.registration_feature(p_org,'documents') and boss_private.registration_feature(p_org,'emergency_access')
 and exists(select 1 from public.teams t join public.team_memberships staff on staff.team_id=t.id and staff.organization_id=t.organization_id
 join public.team_memberships athlete on athlete.team_id=t.id and athlete.organization_id=t.organization_id
 join public.participants p on p.id=athlete.participant_id and p.person_id=athlete.person_id join public.people child on child.id=p.person_id
 where t.id=p_team and t.organization_id=p_org and t.status='active' and p.id=p_participant and p.status='active' and child.status='active'
 and staff.person_id=boss_private.current_person_id() and staff.membership_type in ('coach','head_coach','assistant_coach','staff','team_staff')
 and staff.status='active' and staff.starts_at<=now() and (staff.ends_at is null or staff.ends_at>now())
 and athlete.status='active' and athlete.starts_at<=now() and (athlete.ends_at is null or athlete.ends_at>now())
 and exists(select 1 from public.role_assignments ra join public.roles role on role.id=ra.role_id join public.role_permissions rp on rp.role_id=role.id join public.permissions perm on perm.id=rp.permission_id
 where ra.person_id=boss_private.current_person_id() and ra.scope_type='team' and ra.scope_id=t.id and ra.organization_id=p_org
 and ra.status='active' and role.status='active' and perm.status='active' and perm.key='documents.emergency_view' and ra.starts_at<=now() and (ra.ends_at is null or ra.ends_at>now())))
$$;
create function boss_private.registration_can_view(p_registration uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select boss_private.registration_feature(r.organization_id,'registration') and
 (boss_private.registration_guardian(r.participant_id,'can_register') or boss_private.registration_guardian(r.participant_id,'can_sign_waivers')
 or boss_private.registration_guardian(r.participant_id,'can_view_documents') or boss_private.registration_guardian(r.participant_id,'can_manage_payments')
 or boss_private.registration_can_record('registration.view',r.id) or boss_private.registration_can_record('fees.view',r.id)
 or exists(select 1 from public.team_memberships tm where tm.participant_id=r.participant_id and tm.organization_id=r.organization_id and boss_private.registration_emergency_authorized(r.participant_id,r.organization_id,tm.team_id)))
 from public.registrations r where r.id=p_registration),false)
$$;
create function boss_private.registration_charge_balance(p_charge uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('original_amount_minor',c.original_amount_minor,'adjustment_amount_minor',coalesce(a.amount,0),'adjusted_amount_minor',c.original_amount_minor+coalesce(a.amount,0),
 'applied_amount_minor',coalesce(p.amount,0),'balance_due_minor',c.original_amount_minor+coalesce(a.amount,0)-coalesce(p.amount,0),'currency',c.currency,
 'payment_status',case when c.status='canceled' then 'canceled' when c.original_amount_minor+coalesce(a.amount,0)=0 then 'waived'
 when c.original_amount_minor+coalesce(a.amount,0)=coalesce(p.amount,0) then 'paid' when c.due_on<current_date then 'overdue' when coalesce(p.amount,0)>0 then 'partially_paid' else 'unpaid' end)
 from public.charges c left join lateral(select sum(amount_minor) amount from public.charge_adjustments where charge_id=c.id) a on true
 left join lateral(select sum(case when status='applied' then amount_minor else -amount_minor end) amount from public.payment_allocations where charge_id=c.id) p on true where c.id=p_charge
$$;

-- Legal/version evidence and financial entries are append-only.
create function boss_private.registration_reject_rewrite() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Historical evidence cannot be rewritten.' using errcode='PT409';end $$;
do $$ declare t text;begin foreach t in array array['registration_form_versions','registration_waiver_versions','document_requirements','waiver_signatures','charge_adjustments','payments','payment_allocations','payment_installments'] loop
 execute format('create trigger %I before update or delete on public.%I for each row execute function boss_private.registration_reject_rewrite()',t||'_immutable',t);end loop;end $$;
create trigger registration_offerings_identity before update on public.registration_offerings for each row execute function boss_private.preserve_row_identity('id','organization_id','scope_type','scope_id','created_by_person_id','created_at');
create trigger registrations_identity before update on public.registrations for each row execute function boss_private.preserve_row_identity('id','organization_id','offering_id','participant_id','household_id','submitted_by_person_id','offering_snapshot','participant_snapshot','family_snapshot','created_at');
create trigger charges_identity before update on public.charges for each row execute function boss_private.preserve_row_identity('id','organization_id','registration_id','participant_id','household_id','event_id','fee_rule_id','title','charge_type','original_amount_minor','currency','due_on','created_by_person_id','created_at');
create function boss_private.registration_answers_immutable() returns trigger language plpgsql set search_path='' as $$
begin if tg_op='DELETE' or old.status='submitted' then raise exception 'Historical evidence cannot be rewritten.' using errcode='PT409';end if;return new;end $$;
create trigger registration_answers_evidence before update or delete on public.registration_form_answers for each row execute function boss_private.registration_answers_immutable();
create trigger registration_answers_identity before update on public.registration_form_answers for each row execute function boss_private.preserve_row_identity('id','organization_id','registration_id','form_version_id','created_at');
create trigger registration_documents_identity before update on public.registration_documents for each row execute function boss_private.preserve_row_identity('id','organization_id','registration_id','participant_id','requirement_id','snapshot','created_at');
create trigger emergency_records_identity before update on public.participant_emergency_records for each row execute function boss_private.preserve_row_identity('id','organization_id','registration_id','participant_id');
create function boss_private.registration_preserve_document_history() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new is not distinct from old then return new;end if;
 if new.version<>old.version+1 then raise exception 'Document changes require a new version.' using errcode='PT409';end if;
 insert into boss_private.registration_document_history(organization_id,document_id,version,snapshot,changed_by_person_id)
 values(old.organization_id,old.id,old.version,to_jsonb(old),boss_private.current_person_id());return new;
end $$;
create trigger registration_document_history before update on public.registration_documents for each row execute function boss_private.registration_preserve_document_history();
create trigger registration_document_history_immutable before update or delete on boss_private.registration_document_history for each row execute function boss_private.registration_reject_rewrite();
do $$ declare t text;begin foreach t in array array['registration_offerings','registration_fee_rules','registration_coupons','registrations','registration_documents','document_upload_intents','participant_emergency_records','charges','payment_plans'] loop
 execute format('create trigger %I before delete on public.%I for each row execute function boss_private.registration_reject_rewrite()',t||'_retain_history',t);end loop;end $$;

revoke all on function boss_private.registration_module_enabled(uuid),boss_private.registration_feature(uuid,text),boss_private.registration_can_scope(text,uuid,text,uuid),
 boss_private.registration_guardian(uuid,text),boss_private.registration_can_record(text,uuid),boss_private.registration_can_view(uuid),boss_private.registration_can_document(uuid),
 boss_private.registration_emergency_authorized(uuid,uuid,uuid),boss_private.registration_charge_balance(uuid),boss_private.registration_reject_rewrite(),boss_private.registration_answers_immutable(),boss_private.registration_preserve_document_history()
 from public,anon,authenticated,service_role;

-- Bounded declarative form DSL. No expressions, scripts, regex execution,
-- recursive conditions or frontend-only requiredness.
create function boss_private.registration_validate_form_definition(p_definition jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare f jsonb;c jsonb;r jsonb;k text;seen text[]:='{}';typ text;opts jsonb;begin
 if jsonb_typeof(p_definition) is distinct from 'object' or octet_length(p_definition::text)>64000
 or exists(select 1 from jsonb_object_keys(p_definition) x where x not in ('fields'))
 or jsonb_typeof(p_definition->'fields') is distinct from 'array' or jsonb_array_length(p_definition->'fields') not between 1 and 100 then raise exception 'Invalid form definition.' using errcode='PT422';end if;
 for f in select value from jsonb_array_elements(p_definition->'fields') loop
  if jsonb_typeof(f)<>'object' or exists(select 1 from jsonb_object_keys(f) x where x not in ('key','type','label','required','section','help','options','show_if','required_if','min','max','max_length','content'))
  or jsonb_typeof(f->'key') is distinct from 'string' or f->>'key' !~ '^[a-z][a-z0-9_]{0,59}$' or f->>'key'=any(seen)
  or jsonb_typeof(f->'type') is distinct from 'string' or jsonb_typeof(f->'label') is distinct from 'string' or length(btrim(f->>'label')) not between 1 and 200 then raise exception 'Invalid form definition.' using errcode='PT422';end if;
  typ:=f->>'type';if typ not in ('short_text','long_text','email','phone','number','date','dropdown','radio','checkbox','multi_select','yes_no','address','file_upload','acknowledgment','signature','emergency_contact','content') then raise exception 'Invalid form definition.' using errcode='PT422';end if;
  if f?'required' and jsonb_typeof(f->'required')<>'boolean' then raise exception 'Invalid form definition.' using errcode='PT422';end if;
  foreach k in array array['section','help','content'] loop if f?k and (jsonb_typeof(f->k)<>'string' or length(f->>k)>case when k='section' then 200 else 4000 end) then raise exception 'Invalid form definition.' using errcode='PT422';end if;end loop;
  if f?'max_length' and (jsonb_typeof(f->'max_length')<>'number' or f->>'max_length' !~ '^[0-9]{1,5}$' or (f->>'max_length')::integer not between 1 and 4000) then raise exception 'Invalid form definition.' using errcode='PT422';end if;
  foreach k in array array['min','max'] loop if f?k and (typ<>'number' or jsonb_typeof(f->k)<>'number' or abs((f->>k)::numeric)>1000000000) then raise exception 'Invalid form definition.' using errcode='PT422';end if;end loop;
  if f?'min' and f?'max' and (f->>'min')::numeric>(f->>'max')::numeric then raise exception 'Invalid form definition.' using errcode='PT422';end if;
  if typ in ('dropdown','radio','multi_select') then
   opts:=f->'options';if jsonb_typeof(opts) is distinct from 'array' or jsonb_array_length(opts) not between 1 and 50 or exists(select 1 from jsonb_array_elements(opts) o where jsonb_typeof(o)<>'string' or length(o#>>'{}') not between 1 and 200)
    or (select count(*) from jsonb_array_elements(opts))<>(select count(distinct value) from jsonb_array_elements(opts)) then raise exception 'Invalid form definition.' using errcode='PT422';end if;
  elsif f?'options' then raise exception 'Invalid form definition.' using errcode='PT422';end if;
  foreach k in array array['show_if','required_if'] loop if f?k then
   c:=f->k;if jsonb_typeof(c)<>'array' or jsonb_array_length(c) not between 1 and 5 then raise exception 'Invalid form definition.' using errcode='PT422';end if;
   for r in select value from jsonb_array_elements(c) loop
    if jsonb_typeof(r)<>'object' or exists(select 1 from jsonb_object_keys(r) x where x not in ('source','field','op','value'))
    or jsonb_typeof(r->'source') is distinct from 'string' or jsonb_typeof(r->'op') is distinct from 'string'
    or r->>'source' not in ('answer','participant_age','context') or r->>'op' not in ('equals','not_equals','includes','lt','gte')
    or not r?'value' or jsonb_typeof(r->'value') not in ('string','number','boolean') or length(r->>'value')>200 then raise exception 'Invalid form definition.' using errcode='PT422';end if;
    if r->>'source'='answer' and not coalesce(r->>'field'=any(seen),false) then raise exception 'Invalid form definition.' using errcode='PT422';end if;
    if r->>'source'='participant_age' and (r?'field' or r->>'op' not in ('lt','gte') or jsonb_typeof(r->'value')<>'number' or (r->>'value')::numeric not between 0 and 125) then raise exception 'Invalid form definition.' using errcode='PT422';end if;
    if r->>'source'='context' and (jsonb_typeof(r->'field') is distinct from 'string' or r->>'field' not in ('grade','payment_plan_selected','travel_team_selected')) then raise exception 'Invalid form definition.' using errcode='PT422';end if;
    if r->>'op' in ('lt','gte') and jsonb_typeof(r->'value')<>'number' then raise exception 'Invalid form definition.' using errcode='PT422';end if;
   end loop;
  end if;end loop;
  seen:=array_append(seen,f->>'key');
 end loop;
end $$;
create function boss_private.registration_form_condition(p_rules jsonb,p_answers jsonb,p_participant uuid,p_context jsonb) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare r jsonb;v jsonb;dob date;ok boolean;begin
 if p_rules is null then return true;end if;
 for r in select value from jsonb_array_elements(p_rules) loop
  if r->>'source'='answer' then v:=p_answers->(r->>'field');
  elsif r->>'source'='context' then v:=p_context->(r->>'field');
  elsif r->>'source'='participant_age' then select p.date_of_birth into dob from public.participants a join public.people p on p.id=a.person_id where a.id=p_participant;
   if dob is null then raise exception 'Participant date of birth is required for this form.' using errcode='PT422';end if;v:=to_jsonb(extract(year from age(current_date,dob))::integer);
  else raise exception 'Invalid condition.' using errcode='PT422';end if;
  ok:=case r->>'op' when 'equals' then v=r->'value' when 'not_equals' then v is not null and v<>r->'value'
   when 'includes' then jsonb_typeof(v)='array' and v @> jsonb_build_array(r->'value')
   when 'lt' then case when jsonb_typeof(v)='number' then (v#>>'{}')::numeric<(r->>'value')::numeric else false end
   when 'gte' then case when jsonb_typeof(v)='number' then (v#>>'{}')::numeric>=(r->>'value')::numeric else false end else false end;
  if not coalesce(ok,false) then return false;end if;
 end loop;return true;
end $$;
create function boss_private.registration_validate_form_answers(p_definition jsonb,p_answers jsonb,p_participant uuid,p_context jsonb,p_complete boolean) returns void
language plpgsql stable security definer set search_path='' as $$
declare f jsonb;v jsonb;k text;typ text;txt text;required boolean;visible boolean;maxlength integer;begin
 perform boss_private.registration_validate_form_definition(p_definition);
 if jsonb_typeof(p_answers) is distinct from 'object' or octet_length(p_answers::text)>64000 or jsonb_typeof(p_context) is distinct from 'object'
 or exists(select 1 from jsonb_object_keys(p_context) x where x not in ('grade','payment_plan_selected','travel_team_selected')) then raise exception 'Invalid form answers.' using errcode='PT422';end if;
 if p_context?'grade' and (jsonb_typeof(p_context->'grade')<>'number' or p_context->>'grade' !~ '^[0-9]{1,2}$' or (p_context->>'grade')::integer not between 0 and 20) then raise exception 'Invalid form answers.' using errcode='PT422';end if;
 foreach k in array array['payment_plan_selected','travel_team_selected'] loop if p_context?k and jsonb_typeof(p_context->k)<>'boolean' then raise exception 'Invalid form answers.' using errcode='PT422';end if;end loop;
 if exists(select 1 from jsonb_object_keys(p_answers) answer_key where not exists(select 1 from jsonb_array_elements(p_definition->'fields') defined_field where defined_field->>'key'=answer_key)) then raise exception 'Invalid form answers.' using errcode='PT422';end if;
 for f in select value from jsonb_array_elements(p_definition->'fields') loop
  k:=f->>'key';typ:=f->>'type';v:=p_answers->k;visible:=boss_private.registration_form_condition(f->'show_if',p_answers,p_participant,p_context);
  required:=coalesce((f->>'required')::boolean,false) or (f?'required_if' and boss_private.registration_form_condition(f->'required_if',p_answers,p_participant,p_context));
  if not visible or typ='content' then if p_answers?k then raise exception 'Hidden or content field cannot be answered.' using errcode='PT422';end if;continue;end if;
  if v is null or v='null'::jsonb or v='""'::jsonb or v='[]'::jsonb then if required and p_complete then raise exception 'Required form answer is missing.' using errcode='PT422';end if;continue;end if;
  txt:=v#>>'{}';maxlength:=coalesce((f->>'max_length')::integer,case when typ='long_text' then 4000 else 200 end);
  if typ in ('short_text','long_text','email','phone','date') then
   if jsonb_typeof(v)<>'string' or length(txt)>maxlength or regexp_replace(txt,E'[\t\n\r]','','g') ~ '[[:cntrl:]]' then raise exception 'Invalid form answer.' using errcode='PT422';end if;
   if typ='email' and txt !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Invalid email answer.' using errcode='PT422';end if;
   if typ='phone' and (length(txt)>40 or txt !~ '^[+0-9() .-]{3,40}$') then raise exception 'Invalid phone answer.' using errcode='PT422';end if;
   if typ='date' then if txt !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception 'Invalid date answer.' using errcode='PT422';end if;perform txt::date;end if;
  elsif typ='number' then if jsonb_typeof(v)<>'number' or abs(txt::numeric)>1000000000 or (f?'min' and txt::numeric<(f->>'min')::numeric) or (f?'max' and txt::numeric>(f->>'max')::numeric) then raise exception 'Invalid numeric answer.' using errcode='PT422';end if;
  elsif typ in ('dropdown','radio') then if jsonb_typeof(v)<>'string' or not (f->'options') @> jsonb_build_array(v) then raise exception 'Invalid choice answer.' using errcode='PT422';end if;
  elsif typ='multi_select' then if jsonb_typeof(v)<>'array' or jsonb_array_length(v)>50 or exists(select 1 from jsonb_array_elements(v) item where jsonb_typeof(item)<>'string' or not (f->'options') @> jsonb_build_array(item))
   or (select count(*) from jsonb_array_elements(v))<>(select count(distinct value) from jsonb_array_elements(v)) then raise exception 'Invalid choice answer.' using errcode='PT422';end if;
  elsif typ in ('checkbox','yes_no','acknowledgment') then if jsonb_typeof(v)<>'boolean' or (typ='acknowledgment' and required and p_complete and v<>'true'::jsonb) then raise exception 'Explicit acknowledgment is required.' using errcode='PT422';end if;
  elsif typ='address' then if jsonb_typeof(v)<>'object' or exists(select 1 from jsonb_each(v) a where a.key not in ('line1','line2','city','region','postal_code','country') or jsonb_typeof(a.value)<>'string' or length(a.value#>>'{}')>200) or (required and p_complete and coalesce(length(btrim(v->>'line1')),0)=0) then raise exception 'Invalid address answer.' using errcode='PT422';end if;
  elsif typ='signature' then if jsonb_typeof(v)<>'object' or exists(select 1 from jsonb_object_keys(v) x where x not in ('name','consent')) or jsonb_typeof(v->'name') is distinct from 'string' or length(btrim(v->>'name')) not between 1 and 200 or v->'consent' is distinct from 'true'::jsonb then raise exception 'Signature consent is required.' using errcode='PT422';end if;
   if p_complete and not boss_private.registration_guardian(p_participant,'can_sign_waivers') then raise exception 'Signer authority is required.' using errcode='PT403';end if;
  elsif typ in ('file_upload','emergency_contact') then if jsonb_typeof(v)<>'string' or txt !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then raise exception 'Invalid reference answer.' using errcode='PT422';end if;
   if typ='file_upload' and not exists(select 1 from public.registration_documents d where d.id=txt::uuid and d.participant_id=p_participant and d.status in ('submitted','under_review','approved')) then raise exception 'Invalid document reference.' using errcode='PT422';end if;
   if typ='emergency_contact' and not exists(select 1 from public.participant_emergency_records e where e.id=txt::uuid and e.participant_id=p_participant) then raise exception 'Invalid emergency reference.' using errcode='PT422';end if;
  end if;
 end loop;
 exception when invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then raise exception 'Invalid form answer.' using errcode='PT422';
end $$;
create function boss_private.registration_form_definition_integrity() returns trigger language plpgsql set search_path='' as $$
begin perform boss_private.registration_validate_form_definition(new.definition);return new;end $$;
create trigger registration_forms_definition_integrity before insert on public.registration_form_versions for each row execute function boss_private.registration_form_definition_integrity();
revoke all on function boss_private.registration_validate_form_definition(jsonb),boss_private.registration_form_condition(jsonb,jsonb,uuid,jsonb),
 boss_private.registration_validate_form_answers(jsonb,jsonb,uuid,jsonb,boolean),boss_private.registration_form_definition_integrity() from public,anon,authenticated,service_role;
