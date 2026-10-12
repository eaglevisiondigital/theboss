create function boss_private.bucks_net_use(grant_uuid uuid)returns bigint language sql volatile security definer set search_path=''as $$
 select coalesce((select sum(c.amount_minor-coalesce((select sum(r.amount_minor)from public.boss_bucks_restorations r where r.consumption_id=c.id),0))from public.boss_bucks_consumptions c where c.grant_id=grant_uuid),0)::bigint
 +coalesce((select sum(case when kind='apply'then amount_minor else -amount_minor end)from public.boss_bucks_recovery_movements where replacement_grant_id=grant_uuid),0)::bigint
$$;
create function boss_private.bucks_recover_grant(grant_uuid uuid)returns integer language plpgsql volatile security definer set search_path=''as $$
declare g public.boss_bucks_grants;c record;remaining bigint;take bigint;j uuid;n integer:=0;begin
 select *into g from public.boss_bucks_grants where id=grant_uuid;
 perform boss_private.bucks_wallet_lock(g.wallet_id);perform 1 from public.boss_bucks_grants where id=g.id for update;
 if g.expires_at<=clock_timestamp()or boss_private.bucks_entitlement(g.id)=0 then return 0;end if;
 remaining:=boss_private.bucks_grant_book(g.id);
 for c in select rc.id,boss_private.bucks_claim_balance(rc.id)due from public.boss_bucks_recovery_claims rc
 join public.boss_bucks_grants source on source.id=rc.grant_id where source.wallet_id=g.wallet_id and source.organization_id=g.organization_id and source.currency=g.currency
 and rc.created_at<g.created_at and boss_private.bucks_claim_balance(rc.id)>0 order by rc.created_at,rc.id limit 200 loop
 exit when remaining=0;take:=least(remaining,c.due);
 j:=boss_private.bucks_pair(g.id,'recovery_apply',take,'Same-organization earning applied to internal recovery');
 insert into public.boss_bucks_recovery_movements(claim_id,kind,amount_minor,replacement_grant_id,journal_id)values(c.id,'apply',take,g.id,j);
 remaining:=remaining-take;n:=n+1;
 perform boss_private.bucks_audit(null,'boss_bucks.recovery.apply',g.organization_id,g.wallet_id,g.id,null,jsonb_build_object('journal_id',j,'claim_id',c.id,'amount_minor',take));end loop;
 if remaining>0 and exists(select 1 from public.boss_bucks_recovery_claims rc join public.boss_bucks_grants source on source.id=rc.grant_id
 where source.wallet_id=g.wallet_id and source.organization_id=g.organization_id and source.currency=g.currency and rc.created_at<g.created_at and boss_private.bucks_claim_balance(rc.id)>0)then
 raise exception'Recovery batch exceeded'using errcode='PT409';end if;return n;
end$$;

create function boss_private.bucks_correct_source(grant_uuid uuid,remaining_source bigint,source_key text,source_event uuid default null)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare g public.boss_bucks_grants;e public.fundraising_success_evidence;p public.boss_bucks_policy_revisions;prior public.boss_bucks_source_corrections;
 entitlement bigint;previous bigint;loss bigint;unspent bigint;j uuid;correction uuid;claim uuid;required_claim bigint;claimed bigint;begin
 select *into g from public.boss_bucks_grants where id=grant_uuid;if g.id is null then return null;end if;
 perform boss_private.bucks_wallet_lock(g.wallet_id);select *into g from public.boss_bucks_grants where id=grant_uuid for update;
 select *into e from public.fundraising_success_evidence where id=g.evidence_id;select *into p from public.boss_bucks_policy_revisions where id=g.policy_revision_id;
 select sc.*into prior from public.boss_bucks_source_corrections sc where sc.grant_id=g.id and sc.source_key=bucks_correct_source.source_key;
 if prior.id is not null then if prior.remaining_source_minor<>remaining_source or prior.source_event_id is distinct from source_event then raise exception'Source correction conflict'using errcode='PT409';end if;return prior.id;end if;
 if remaining_source is null or remaining_source<0 or remaining_source>e.amount_minor or length(source_key)not between 1 and 200
 or source_event is not null and not exists(select 1 from public.fundraising_intent_events where id=source_event and intent_id=g.intent_id)
 or remaining_source>coalesce((select sc.remaining_source_minor from public.boss_bucks_source_corrections sc where sc.grant_id=g.id order by sc.created_at desc,sc.id desc limit 1),e.amount_minor)then
 raise exception'Invalid authoritative remaining source'using errcode='PT422';end if;
 previous:=boss_private.bucks_entitlement(g.id);entitlement:=floor(remaining_source::numeric*p.basis_points/10000)::bigint;loss:=previous-entitlement;
 if loss<0 then raise exception'Source entitlement cannot increase'using errcode='PT409';end if;
 insert into public.boss_bucks_source_corrections(grant_id,source_event_id,source_key,remaining_source_minor,entitlement_minor)
 values(g.id,source_event,source_key,remaining_source,entitlement)returning id into correction;
 unspent:=least(boss_private.bucks_grant_book(g.id),loss);
 if unspent>0 then j:=boss_private.bucks_pair(g.id,'reversal',unspent,'Cumulative authoritative source correction');
 perform boss_private.bucks_audit(null,'boss_bucks.reversal',g.organization_id,g.wallet_id,g.id,null,jsonb_build_object('journal_id',j,'correction_id',correction,'amount_minor',unspent));end if;
 required_claim:=greatest(boss_private.bucks_net_use(g.id)-entitlement,0);
 select id into claim from public.boss_bucks_recovery_claims where grant_id=g.id;
 select coalesce(sum(case kind when'open'then amount_minor when'cancel'then -amount_minor else 0 end),0)into claimed from public.boss_bucks_recovery_movements where claim_id=claim;
 if required_claim>claimed then
 insert into public.boss_bucks_recovery_claims(grant_id)values(g.id)on conflict(grant_id)do nothing;
 select id into claim from public.boss_bucks_recovery_claims where grant_id=g.id;
 j:=boss_private.bucks_pair(g.id,'recovery_open',required_claim-claimed,'Invalidated previously used internal value');
 insert into public.boss_bucks_recovery_movements(claim_id,kind,amount_minor,journal_id)values(claim,'open',required_claim-claimed,j);
 perform boss_private.bucks_audit(null,'boss_bucks.recovery.open',g.organization_id,g.wallet_id,g.id,null,jsonb_build_object('journal_id',j,'correction_id',correction,'claim_id',claim,'amount_minor',required_claim-claimed));end if;
 perform boss_private.bucks_audit(null,'boss_bucks.source.correct',g.organization_id,g.wallet_id,g.id,null,jsonb_build_object('correction_id',correction,'entitlement_minor',entitlement));
 return correction;
end$$;

-- Retain trusted source lock order and original earning policy. Newly issued
-- valid earnings satisfy older same-org claims before the residual is spendable.
alter function boss_private.bucks_post(uuid,text,text)rename to bucks_post_phase7b;
create function boss_private.bucks_post(grant_uuid uuid,p_kind text,p_reason text)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare g public.boss_bucks_grants;j uuid;amount bigint;begin
 select *into g from public.boss_bucks_grants where id=grant_uuid;if g.id is null then raise exception'Grant unavailable'using errcode='PT404';end if;
 perform boss_private.bucks_wallet_lock(g.wallet_id);perform 1 from public.boss_bucks_grants where id=g.id for update;
 if p_kind='issuance'then
 select id into j from public.boss_bucks_journals where grant_id=g.id and kind='issuance';if j is not null then return j;end if;
 j:=boss_private.bucks_pair(g.id,p_kind,g.amount_minor,p_reason);
 perform boss_private.bucks_audit(null,'boss_bucks.issuance',g.organization_id,g.wallet_id,g.id,null,jsonb_build_object('journal_id',j));
 perform boss_private.bucks_recover_grant(g.id);return j;
 elsif p_kind='reversal'then
 perform boss_private.bucks_correct_source(g.id,0,'trusted-full-source-reversal');
 select id into j from public.boss_bucks_journals where grant_id=g.id and kind in('reversal','recovery_open')order by created_at,id limit 1;return j;
 elsif p_kind='expiration'then
 if g.expires_at is null or g.expires_at>clock_timestamp()then raise exception'Expiration unavailable'using errcode='PT409';end if;
 amount:=boss_private.bucks_grant_book(g.id);if amount=0 then select id into j from public.boss_bucks_journals where grant_id=g.id and kind='expiration'order by created_at desc,id desc limit 1;return j;end if;
 j:=boss_private.bucks_pair(g.id,'expiration',amount,p_reason);perform boss_private.bucks_audit(null,'boss_bucks.expiration',g.organization_id,g.wallet_id,g.id,null,jsonb_build_object('journal_id',j));return j;
 end if;raise exception'Unsupported grant operation'using errcode='PT422';
end$$;
create or replace function boss_private.bucks_expire(batch integer default 100)returns integer language plpgsql volatile security definer set search_path=''as $$declare g record;n integer:=0;begin
 for g in select gr.id from public.boss_bucks_grants gr where gr.expires_at<=clock_timestamp()and boss_private.bucks_grant_book(gr.id)>0
 order by gr.wallet_id,gr.expires_at,gr.id limit least(greatest(batch,1),100)loop
 if boss_private.bucks_post(g.id,'expiration','Explicit earning policy expiration')is not null then n:=n+1;end if;end loop;return n;
end$$;
create or replace function boss_private.bucks_source_ingest()returns trigger language plpgsql volatile security definer set search_path=''as $$declare evidence uuid;grant_uuid uuid;remaining bigint;begin
 select id into evidence from public.fundraising_success_evidence where intent_id=new.intent_id;
 if evidence is null then return new;end if;
 if new.state='succeeded'then perform boss_private.bucks_issue(evidence);
 elsif new.state in('failed','canceled','refunded','partially_refunded','chargeback')then
 select id into grant_uuid from public.boss_bucks_grants where evidence_id=evidence;
 remaining:=case when new.state='partially_refunded'then new.remaining_valid_amount_minor else 0 end;
 if remaining is null then raise exception'Partial source correction requires authoritative remaining amount'using errcode='PT422';end if;
 perform boss_private.bucks_correct_source(grant_uuid,remaining,new.id::text,new.id);end if;return new;
end$$;
create or replace function boss_private.bucks_grant_state(g public.boss_bucks_grants)returns text language sql volatile security definer set search_path=''as $$
 select case when boss_private.bucks_entitlement(g.id)=0 then'reversed'when g.expires_at<=clock_timestamp()then'expired'
 when g.available_at>clock_timestamp()then'held'when boss_private.bucks_grant_book(g.id)=0 then'used'else'available'end
$$;

create function boss_private.bucks_validate_recovery()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare m public.boss_bucks_recovery_movements;g public.boss_bucks_grants;j public.boss_bucks_journals;replacement public.boss_bucks_grants;original public.boss_bucks_recovery_movements;cause public.boss_bucks_recovery_movements;invalid_j public.boss_bucks_journals;begin
 m:=new;select gr.*into g from public.boss_bucks_grants gr join public.boss_bucks_recovery_claims c on c.grant_id=gr.id where c.id=m.claim_id;
 select *into j from public.boss_bucks_journals where id=m.journal_id;
 if j.amount_minor<>m.amount_minor or j.kind<>(case m.kind when'open'then'recovery_open'when'apply'then'recovery_apply'when'cancel'then case when m.cause_release_id is null then'recovery_cancel'else'recovery_cancel_source'end else'recovery_release'end)
 or boss_private.bucks_claim_balance(m.claim_id)<0 then raise exception'Invalid internal recovery movement'using errcode='23514';end if;
 if(select coalesce(sum(case when kind='open'then amount_minor when kind='cancel'then -amount_minor else 0 end),0)from public.boss_bucks_recovery_movements where claim_id=m.claim_id)
 <>greatest(boss_private.bucks_net_use(g.id)-boss_private.bucks_entitlement(g.id),0)then raise exception'Recovery claim must equal invalidated net use'using errcode='23514';end if;
 if m.kind in('open','cancel')and j.grant_id<>g.id then raise exception'Recovery source mismatch'using errcode='23514';end if;
 if m.payment_reversal_id is not null and not exists(select 1 from public.boss_bucks_tenders t join public.payments p on p.id=t.payment_id
 where t.payment_id=m.payment_reversal_id and t.wallet_id=g.wallet_id and t.organization_id=g.organization_id and t.currency=g.currency and p.status='reversed')then raise exception'Recovery cancellation requires canonical payment reversal'using errcode='23514';end if;
 if m.replacement_grant_id is not null then select *into replacement from public.boss_bucks_grants where id=m.replacement_grant_id;
 if replacement.id=g.id or replacement.wallet_id<>g.wallet_id or replacement.organization_id<>g.organization_id or replacement.currency<>g.currency
 or j.grant_id<>replacement.id then raise exception'Recovery replacement scope mismatch'using errcode='23514';end if;
 if m.kind='apply'and not exists(select 1 from public.boss_bucks_recovery_claims c where c.id=m.claim_id and c.created_at<replacement.created_at)then raise exception'Recovery dependencies must be chronological'using errcode='23514';end if;
 if boss_private.bucks_grant_book(replacement.id)>greatest(boss_private.bucks_entitlement(replacement.id)-boss_private.bucks_net_use(replacement.id),0)then raise exception'Recovery release cannot manufacture source value'using errcode='23514';end if;end if;
 if m.kind='release'then select *into original from public.boss_bucks_recovery_movements where id=m.original_movement_id;
 if original.kind<>'apply'or original.claim_id<>m.claim_id or original.replacement_grant_id<>m.replacement_grant_id
 or original.amount_minor<(select sum(amount_minor)from public.boss_bucks_recovery_movements where original_movement_id=original.id)then raise exception'Recovery release exceeded'using errcode='23514';end if;
 if(select sum(amount_minor)from public.boss_bucks_recovery_movements where claim_id=m.claim_id and payment_reversal_id=m.payment_reversal_id and kind='release')
 >coalesce((select sum(amount_minor)from public.boss_bucks_recovery_movements where claim_id=m.claim_id and payment_reversal_id=m.payment_reversal_id and kind='cancel'),0)then raise exception'Recovery release requires matching exposure cancellation'using errcode='23514';end if;end if;
 if m.kind='cancel'and m.cause_release_id is null and not exists(select 1 from public.boss_bucks_restorations r join public.payment_allocations a on a.id=r.allocation_id
 join public.boss_bucks_consumptions c on c.id=r.consumption_id where r.journal_id=j.id and r.amount_minor=m.amount_minor and a.payment_id=m.payment_reversal_id and c.grant_id=g.id)then raise exception'Recovery cancellation lacks original payment return'using errcode='23514';end if;
 if m.cause_release_id is not null then
 select *into cause from public.boss_bucks_recovery_movements where id=m.cause_release_id;
 select *into invalid_j from public.boss_bucks_journals where id=m.invalid_release_journal_id;
 if cause.kind is distinct from'release'or cause.replacement_grant_id is distinct from g.id or cause.payment_reversal_id is distinct from m.payment_reversal_id
 or invalid_j.kind is distinct from'reversal'or invalid_j.grant_id is distinct from g.id or invalid_j.amount_minor is distinct from m.amount_minor
 or(select sum(amount_minor)from public.boss_bucks_recovery_movements where cause_release_id=cause.id)>cause.amount_minor then raise exception'Invalid dependent recovery cancellation'using errcode='23514';end if;
 end if;
 return new;
end$$;
create constraint trigger boss_bucks_recovery_proof after insert on public.boss_bucks_recovery_movements deferrable initially deferred for each row execute function boss_private.bucks_validate_recovery();
create function boss_private.bucks_validate_correction()returns trigger language plpgsql volatile security definer set search_path=''as $$
declare g public.boss_bucks_grants;e public.fundraising_success_evidence;p public.boss_bucks_policy_revisions;begin
 select *into g from public.boss_bucks_grants where id=new.grant_id;select *into e from public.fundraising_success_evidence where id=g.evidence_id;
 select *into p from public.boss_bucks_policy_revisions where id=g.policy_revision_id;
 if new.remaining_source_minor>e.amount_minor or new.entitlement_minor<>floor(new.remaining_source_minor::numeric*p.basis_points/10000)::bigint
 or exists(select 1 from public.boss_bucks_source_corrections sc where sc.grant_id=g.id and(sc.created_at,sc.id)<(new.created_at,new.id)and sc.remaining_source_minor<new.remaining_source_minor)
 or new.source_event_id is not null and not exists(select 1 from public.fundraising_intent_events se where se.id=new.source_event_id and se.intent_id=g.intent_id
 and(se.state='partially_refunded'and se.remaining_valid_amount_minor=new.remaining_source_minor or se.state in('failed','canceled','refunded','chargeback')and new.remaining_source_minor=0))
 or boss_private.bucks_grant_book(g.id)>greatest(boss_private.bucks_entitlement(g.id)-boss_private.bucks_net_use(g.id),0)then raise exception'Invalid cumulative source correction'using errcode='23514';end if;
 return new;
end$$;
create constraint trigger boss_bucks_correction_proof after insert on public.boss_bucks_source_corrections deferrable initially deferred for each row execute function boss_private.bucks_validate_correction();
do $$declare p record;begin for p in select oid::regprocedure signature from pg_proc where pronamespace='boss_private'::regnamespace and proname like'bucks_%'loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',p.signature);end loop;end$$;
grant execute on function boss_private.bucks_read(jsonb),boss_private.bucks_mutate(jsonb),boss_private.bucks_admin_feature(uuid,text)to authenticated;
