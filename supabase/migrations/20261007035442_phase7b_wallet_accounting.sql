create function boss_private.bucks_validate_journal()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare j public.boss_bucks_journals;g public.boss_bucks_grants;original public.boss_bucks_journals;n integer;total numeric;begin
 select *into j from public.boss_bucks_journals where id=coalesce((to_jsonb(new)->>'journal_id')::uuid,new.id);
 select *into g from public.boss_bucks_grants where id=j.grant_id;
 select count(*),sum(p.amount_minor)into n,total from public.boss_bucks_postings p where journal_id=j.id;
 if n<>2 or total<>0 or j.currency<>g.currency or exists(select 1 from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where p.journal_id=j.id and(
 p.currency<>j.currency or a.currency<>j.currency or a.organization_id<>g.organization_id
 or a.kind='household'and(a.id<>g.account_id or a.wallet_id<>g.wallet_id or a.household_id<>g.household_id)
 or p.amount_minor<>(case when a.kind='household'then 1 else -1 end)*(case when j.kind='issuance'then 1 else -1 end)*g.amount_minor))
 or(select count(*)from public.boss_bucks_postings p join public.boss_bucks_accounts a on a.id=p.account_id where p.journal_id=j.id and a.kind='household')<>1 then
 raise exception'Invalid balanced wallet journal'using errcode='23514';end if;
 if j.kind<>'issuance'then
 select *into original from public.boss_bucks_journals where id=j.original_journal_id;
 if original.grant_id<>j.grant_id or original.kind<>'issuance'or original.currency<>j.currency or original.created_at>j.created_at then raise exception'Invalid dependent termination'using errcode='23514';end if;
 if j.kind='expiration'and(g.expires_at is null or g.expires_at>j.created_at)then raise exception'Premature expiration'using errcode='23514';end if;
 end if;return new;
end$$;
create constraint trigger boss_bucks_journal_balanced after insert on public.boss_bucks_journals deferrable initially deferred for each row execute function boss_private.bucks_validate_journal();
create constraint trigger boss_bucks_posting_balanced after insert on public.boss_bucks_postings deferrable initially deferred for each row execute function boss_private.bucks_validate_journal();
create function boss_private.bucks_validate_grant()returns trigger language plpgsql volatile security definer set search_path=''as $$declare x public.fundraising_intents;e public.fundraising_success_evidence;s public.boss_bucks_source_snapshots;p public.boss_bucks_policy_revisions;a public.boss_bucks_accounts;f public.fundraising_fundraisers;begin
 select *into e from public.fundraising_success_evidence where id=new.evidence_id;select *into x from public.fundraising_intents where id=e.intent_id;
 select *into s from public.boss_bucks_source_snapshots where intent_id=x.id;select *into p from public.boss_bucks_policy_revisions where id=s.policy_revision_id;
 s.household_id:=coalesce(s.household_id,(select household_id from public.boss_bucks_owner_resolutions where intent_id=x.id));
 select *into a from public.boss_bucks_accounts where id=new.account_id;select *into f from public.fundraising_fundraisers where id=x.fundraiser_id;
 if s.household_id is distinct from new.household_id or s.policy_revision_id is distinct from new.policy_revision_id or s.intent_id<>new.intent_id or s.organization_id<>new.organization_id
 or a.kind<>'household'or a.wallet_id<>new.wallet_id or a.household_id<>new.household_id or a.currency<>new.currency or a.organization_id<>new.organization_id
 or x.campaign_id<>new.campaign_id or x.fundraiser_id<>new.fundraiser_id or f.participant_id<>new.participant_id or f.person_id<>new.person_id
 or f.team_id is distinct from new.team_id or f.unit_id is distinct from new.unit_id or p.organization_id<>new.organization_id or p.campaign_id<>new.campaign_id
 or p.mode<>'percentage'or p.currency<>new.currency or e.currency<>new.currency or new.amount_minor<>floor(e.amount_minor::numeric*p.basis_points/10000)::bigint
 or new.provenance is distinct from e.provenance||jsonb_build_object('evidence_id',e.id,'wallet_policy_revision_id',p.id,'household_id',s.household_id)
 then raise exception'Wallet source lineage mismatch'using errcode='23514';end if;
 if not exists(select 1 from public.boss_bucks_journals where grant_id=new.id and kind='issuance')then raise exception'Grant requires issuance journal'using errcode='23514';end if;return new;
end$$;
create constraint trigger boss_bucks_grant_lineage after insert on public.boss_bucks_grants deferrable initially deferred for each row execute function boss_private.bucks_validate_grant();

create function boss_private.bucks_snapshot_source()returns trigger language plpgsql volatile security definer set search_path=''as $$declare policy uuid;household uuid;org uuid;begin
 select organization_id into org from public.fundraising_campaigns where id=new.campaign_id for update;
 select id into policy from public.boss_bucks_policy_revisions where campaign_id=new.campaign_id and created_at<=new.created_at order by revision desc limit 1;
 select b.household_id into household from public.boss_bucks_fundraiser_bindings b join public.fundraising_fundraisers f on f.id=b.fundraiser_id
 where f.id=new.fundraiser_id and f.household_id=b.household_id and boss_private.bucks_guardian(b.authorized_by,f.person_id,b.household_id);
 insert into public.boss_bucks_source_snapshots(intent_id,policy_revision_id,household_id,organization_id)values(new.id,policy,household,org);return new;
end$$;
create trigger boss_bucks_intent_snapshot after insert on public.fundraising_intents for each row execute function boss_private.bucks_snapshot_source();
create function boss_private.bucks_source_fence()returns trigger language plpgsql volatile security definer set search_path=''as $$declare x public.fundraising_intents;begin
 select *into x from public.fundraising_intents where id=new.intent_id;
 perform 1 from public.fundraising_campaigns where id=x.campaign_id for update;
 perform 1 from public.fundraising_fundraisers where id=x.fundraiser_id for update;
 perform 1 from public.fundraising_intents where id=new.intent_id for update;return new;
end$$;
create trigger boss_bucks_source_state_fence before insert on public.fundraising_intent_events for each row execute function boss_private.bucks_source_fence();

create function boss_private.bucks_post(grant_uuid uuid,p_kind text,p_reason text)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare g public.boss_bucks_grants;j uuid;original uuid;clearing uuid;sign integer;begin
 select *into g from public.boss_bucks_grants where id=grant_uuid;
 perform 1 from public.boss_bucks_wallets where id=g.wallet_id for update;
 select *into g from public.boss_bucks_grants where id=grant_uuid for update;if g.id is null or p_kind not in('issuance','reversal','expiration')then raise exception'Grant unavailable'using errcode='PT404';end if;
 select id into j from public.boss_bucks_journals where grant_id=g.id and(case when p_kind='issuance'then boss_bucks_journals.kind='issuance'else boss_bucks_journals.kind<>'issuance'end);
 if j is not null then return j;end if;
 if p_kind<>'issuance'then select id into original from public.boss_bucks_journals where grant_id=g.id and boss_bucks_journals.kind='issuance';
 if original is null or p_kind='expiration'and(g.expires_at is null or g.expires_at>clock_timestamp())then raise exception'Termination unavailable'using errcode='PT409';end if;end if;
 insert into public.boss_bucks_accounts(kind,organization_id,currency)values('clearing',g.organization_id,g.currency)on conflict(organization_id,currency)where kind='clearing'do nothing;
 select id into clearing from public.boss_bucks_accounts where boss_bucks_accounts.kind='clearing'and organization_id=g.organization_id and currency=g.currency;
 insert into public.boss_bucks_journals(grant_id,kind,currency,original_journal_id,reason)values(g.id,p_kind,g.currency,original,p_reason)returning id into j;
 sign:=case when p_kind='issuance'then 1 else -1 end;
 insert into public.boss_bucks_postings(journal_id,account_id,currency,amount_minor)values(j,g.account_id,g.currency,sign*g.amount_minor),(j,clearing,g.currency,-sign*g.amount_minor);
 perform boss_private.bucks_audit(null,'boss_bucks.'||p_kind,g.organization_id,g.wallet_id,g.id,null,jsonb_build_object('journal_id',j));return j;
end$$;
create function boss_private.bucks_issue(evidence uuid)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare e public.fundraising_success_evidence;x public.fundraising_intents;f public.fundraising_fundraisers;c public.fundraising_campaigns;s public.boss_bucks_source_snapshots;p public.boss_bucks_policy_revisions;b public.boss_bucks_fundraiser_bindings;w uuid;a uuid;g uuid;amount bigint;begin
 select *into e from public.fundraising_success_evidence where id=evidence;if e.id is null then raise exception'Trusted success required'using errcode='PT409';end if;
 select *into x from public.fundraising_intents where id=e.intent_id;select *into c from public.fundraising_campaigns where id=x.campaign_id for update;
 select *into f from public.fundraising_fundraisers where id=x.fundraiser_id for update;
 perform boss_private.fundraising_fence(c.organization_id,null,f.person_id);
 perform 1 from public.organization_modules where organization_id=c.organization_id and module_id in(select id from public.modules where key='boss_bucks')order by id for share;
 perform 1 from public.fundraising_intents where id=x.id for update;
 select id into g from public.boss_bucks_grants where evidence_id=e.id;if g is not null then return g;end if;
 if(select state from public.fundraising_intent_events where intent_id=x.id order by created_at desc,id desc limit 1)is distinct from 'succeeded'then raise exception'Source no longer valid'using errcode='PT409';end if;
 select *into s from public.boss_bucks_source_snapshots where intent_id=x.id;select *into p from public.boss_bucks_policy_revisions where id=s.policy_revision_id;
 s.household_id:=coalesce(s.household_id,(select household_id from public.boss_bucks_owner_resolutions where intent_id=x.id));
 if p.id is null or p.mode='none'or p.basis_points=0 then return null;end if;
 if not boss_private.bucks_feature(c.organization_id,'fundraising_issuance')or not boss_private.fundraising_module(c.organization_id,'fundraising')then return null;end if;
 if p.currency<>e.currency or not(case when x.board_id is null then'direct_support'else'money_board'end=any(p.channels))then return null;end if;
 select *into b from public.boss_bucks_fundraiser_bindings where fundraiser_id=f.id;
 if s.household_id is null or b.household_id is distinct from s.household_id or f.household_id is distinct from s.household_id then return null;end if;
 perform boss_private.bucks_fence(b.authorized_by,c.organization_id,null,s.household_id);
 if not boss_private.bucks_guardian(b.authorized_by,f.person_id,s.household_id)then return null;end if;
 amount:=floor(e.amount_minor::numeric*p.basis_points/10000)::bigint;if amount<1 then return null;end if;
 insert into public.boss_bucks_wallets(household_id,currency)values(s.household_id,e.currency)on conflict(household_id,currency)do nothing;
 select id into w from public.boss_bucks_wallets where household_id=s.household_id and currency=e.currency and status='active'for update;
 if w is null then return null;end if;
 insert into public.boss_bucks_accounts(kind,wallet_id,household_id,organization_id,currency)values('household',w,s.household_id,c.organization_id,e.currency)
 on conflict(wallet_id,organization_id,currency)where kind='household'do nothing;
 select id into a from public.boss_bucks_accounts where wallet_id=w and organization_id=c.organization_id and currency=e.currency and kind='household';
 insert into public.boss_bucks_grants(wallet_id,household_id,currency,organization_id,account_id,evidence_id,intent_id,policy_revision_id,campaign_id,fundraiser_id,participant_id,person_id,unit_id,team_id,amount_minor,available_at,expires_at,provenance)
 values(w,s.household_id,e.currency,c.organization_id,a,e.id,x.id,p.id,c.id,f.id,f.participant_id,f.person_id,f.unit_id,f.team_id,amount,
 e.settled_at+make_interval(secs=>p.availability_seconds),case when p.expiry_seconds is not null then e.settled_at+make_interval(secs=>p.expiry_seconds)end,
 e.provenance||jsonb_build_object('evidence_id',e.id,'wallet_policy_revision_id',p.id,'household_id',s.household_id))returning id into g;
 perform boss_private.bucks_post(g,'issuance','Verified fundraising earning');return g;
end$$;
create function boss_private.bucks_reverse_source(evidence uuid,reason text)returns uuid language plpgsql volatile security definer set search_path=''as $$declare g uuid;x uuid;c uuid;f uuid;begin
 select i.id,i.campaign_id,i.fundraiser_id into x,c,f from public.fundraising_success_evidence e join public.fundraising_intents i on i.id=e.intent_id where e.id=evidence;
 perform 1 from public.fundraising_campaigns where id=c for update;perform 1 from public.fundraising_fundraisers where id=f for update;perform 1 from public.fundraising_intents where id=x for update;
 select id into g from public.boss_bucks_grants where evidence_id=evidence;if g is null then return null;end if;return boss_private.bucks_post(g,'reversal',reason);
end$$;
-- Exact-source ownership resolution is trusted-only, never an ordinary credit
-- endpoint. It appends ownership evidence without rewriting the source snapshot
-- or changing its original earning policy. No policy backfill occurs.
create function boss_private.bucks_resolve_owner(evidence uuid,household uuid,actor uuid)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare x public.fundraising_intents;f public.fundraising_fundraisers;g public.guardian_relationships;s public.boss_bucks_source_snapshots;begin
 select i.*into x from public.fundraising_intents i join public.fundraising_success_evidence e on e.intent_id=i.id where e.id=evidence;
 perform 1 from public.fundraising_campaigns where id=x.campaign_id for update;select *into f from public.fundraising_fundraisers where id=x.fundraiser_id for update;
 perform boss_private.bucks_fence(actor,f.organization_id,null,household);perform 1 from public.fundraising_intents where id=x.id for update;
 select *into s from public.boss_bucks_source_snapshots where intent_id=x.id;
 if f.id is null or not boss_private.bucks_guardian(actor,f.person_id,household)or not exists(select 1 from public.boss_bucks_fundraiser_bindings b where b.fundraiser_id=f.id and b.household_id=household and b.authorized_by=actor)
 or s.household_id is not null and s.household_id<>household or exists(select 1 from public.boss_bucks_owner_resolutions r where r.intent_id=x.id and r.household_id<>household)then raise exception'Ownership unavailable'using errcode='PT403';end if;
 if(select state from public.fundraising_intent_events where intent_id=x.id order by created_at desc,id desc limit 1)is distinct from'succeeded'then raise exception'Source no longer valid'using errcode='PT409';end if;
 select *into g from public.guardian_relationships where guardian_person_id=actor and dependent_person_id=f.person_id and can_manage_boss_bucks and authority_status='active'and verified_at<=clock_timestamp()and starts_at<=clock_timestamp()and(ends_at is null or ends_at>clock_timestamp())order by id limit 1;
 insert into public.boss_bucks_owner_resolutions(intent_id,household_id,authorized_by,guardian_relationship_id)values(x.id,household,actor,g.id)on conflict(intent_id)do nothing;
 perform boss_private.bucks_audit(actor,'boss_bucks.owner.resolve',f.organization_id,null,null,null,jsonb_build_object('intent_id',x.id,'household_id',household));return boss_private.bucks_issue(evidence);
end$$;
create function boss_private.bucks_expire(batch integer default 100)returns integer language plpgsql volatile security definer set search_path=''as $$declare g record;n integer:=0;begin
 for g in select id from public.boss_bucks_grants where expires_at<=clock_timestamp()and not exists(select 1 from public.boss_bucks_journals where grant_id=boss_bucks_grants.id and kind<>'issuance')order by wallet_id,expires_at,id limit least(greatest(batch,1),100) loop
 perform boss_private.bucks_post(g.id,'expiration','Explicit earning policy expiration');n:=n+1;end loop;return n;
end$$;
create function boss_private.bucks_source_ingest()returns trigger language plpgsql volatile security definer set search_path=''as $$declare evidence uuid;begin
 select id into evidence from public.fundraising_success_evidence where intent_id=new.intent_id;
 if evidence is not null then if new.state='succeeded'then perform boss_private.bucks_issue(evidence);
 elsif new.state in('failed','canceled','refunded','partially_refunded','chargeback')then perform boss_private.bucks_reverse_source(evidence,'Trusted source state changed');end if;end if;return new;
end$$;
create trigger boss_bucks_success_dependency after insert on public.fundraising_intent_events for each row execute function boss_private.bucks_source_ingest();
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'bucks_%'loop execute format('revoke all on function %s from public,anon,authenticated,service_role',p.signature);end loop;end$$;
