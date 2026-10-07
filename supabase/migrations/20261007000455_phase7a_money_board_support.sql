create schema boss_fundraising_public;
revoke all on schema boss_fundraising_public from public,anon,authenticated,service_role;
grant usage on schema boss_fundraising_public to anon,authenticated;
create function boss_private.fundraising_public_context(path text)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare c public.fundraising_campaigns;f public.fundraising_fundraisers;s public.fundraising_shares;b public.money_boards;
begin
 if path!~'^[a-f0-9]{48}$'then raise exception'Fundraiser unavailable'using errcode='PT404';end if;
 select *into s from public.fundraising_shares where fundraising_shares.path=fundraising_public_context.path and status='active';
 if s.id is not null then
 select *into f from public.fundraising_fundraisers where id=s.fundraiser_id;select *into c from public.fundraising_campaigns where id=f.campaign_id;
 if not boss_private.fundraising_member(f)or not(boss_private.fundraising_guardian(s.authorized_by,f.person_id)or boss_private.fundraising_self(s.authorized_by,f.person_id,c))then raise exception'Fundraiser unavailable'using errcode='PT404';end if;
 select *into b from public.money_boards where fundraiser_id=f.id and status='published'and visibility='public';
 else
 select *into b from public.money_boards where public_path=path and fundraiser_id is null and status='published'and visibility='public';
 if b.id is not null then select *into c from public.fundraising_campaigns where id=b.campaign_id;
 else select *into c from public.fundraising_campaigns where public_path=path;select *into b from public.money_boards where campaign_id=c.id and fundraiser_id is null and team_id is null and status='published'and visibility='public';end if;
 end if;
 if b.team_id is not null and not exists(select 1 from public.teams where id=b.team_id and organization_id=c.organization_id and status='active')then raise exception'Fundraiser unavailable'using errcode='PT404';end if;
 if c.id is null or not boss_private.fundraising_active(c)then raise exception'Fundraiser unavailable'using errcode='PT404';end if;
 if b.id is not null and not boss_private.fundraising_module(c.organization_id,'money_board')then b:=null;end if;
 return jsonb_strip_nulls(jsonb_build_object('campaign_id',c.id,'fundraiser_id',f.id,'share_id',s.id,'board_id',b.id,'team_id',coalesce(f.team_id,b.team_id),'authorized_by',s.authorized_by,'person_id',f.person_id));
end$$;
create function boss_private.fundraising_guest(command jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare action text;i jsonb;request uuid;h text;cap text;ctx jsonb;c public.fundraising_campaigns;f public.fundraising_fundraisers;b public.money_boards;t public.money_board_tiles;r public.money_board_reservations;
 receipt boss_private.fundraising_guest_receipts;result jsonb;donor uuid;intent uuid;commitment uuid;amount bigint;months integer;state text;attribution text;org uuid;attempts integer;
begin
 perform boss_private.athlete_input(command,array['action','request_id','input'],array['action','request_id','input']);i:=command->'input';action:=command->>'action';request:=boss_private.athlete_uuid(command,'request_id');
 perform boss_private.athlete_input(i,case action when'intent'then array['path','ordinal','capability','display_name','email','mobile','anonymous','fee_cover','months','amount_minor','source']when'reserve'then array['path','ordinal','capability']when'release'then array['path','capability']else array[]::text[]end,array['path','capability']);
 if i->>'capability'!~'^[a-f0-9]{64}$'or action not in('reserve','intent','release')then raise exception'Invalid supporter request'using errcode='PT422';end if;
 cap:=encode(sha256(convert_to(i->>'capability','UTF8')),'hex');h:=encode(sha256(convert_to(command::text,'UTF8')),'hex');
 ctx:=boss_private.fundraising_public_context(i->>'path');
 select *into c from public.fundraising_campaigns where id=(ctx->>'campaign_id')::uuid for update;
 if ctx?'fundraiser_id'then select *into f from public.fundraising_fundraisers where id=(ctx->>'fundraiser_id')::uuid for update;end if;
 perform boss_private.fundraising_fence(c.organization_id,(ctx->>'authorized_by')::uuid,f.person_id);
 ctx:=boss_private.fundraising_public_context(i->>'path'); -- Fresh post-lock policy/relationship clock.
 org:=c.organization_id;
 if ctx?'board_id'then select *into b from public.money_boards where id=(ctx->>'board_id')::uuid for update;end if;
 perform pg_advisory_xact_lock(hashtextextended('boss-fundraising-guest:'||request,0));
 select *into receipt from boss_private.fundraising_guest_receipts where request_id=request;
 if receipt.request_id is not null then if receipt.input_hash<>h or receipt.capability_digest<>cap then raise exception'Request conflict'using errcode='PT409';end if;return receipt.result||'{"replayed":true}'::jsonb;end if;
 -- Rate limiting is canonical and cannot be bypassed by calling Data API RPCs.
 insert into boss_private.fundraising_rate_windows(context,window_at,attempts)values('campaign:'||c.id,date_trunc('minute',clock_timestamp()),1)
 on conflict(context,window_at)do update set attempts=fundraising_rate_windows.attempts+1 returning fundraising_rate_windows.attempts into attempts;
 if attempts>240 then raise exception'Please try again shortly'using errcode='PT429';end if;
 if action='reserve'then
 if b.id is null then raise exception'Board unavailable'using errcode='PT404';end if;
 select *into t from public.money_board_tiles where board_id=b.id and generation_id=(select id from public.money_board_generations where board_id=b.id order by generation desc limit 1)and ordinal=(i->>'ordinal')::int for update;
 if t.id is null then raise exception'Amount unavailable'using errcode='PT404';end if;
 if exists(select 1 from public.fundraising_success_evidence where tile_id=t.id)or exists(select 1 from public.money_board_reservations where tile_id=t.id and released_at is null and expires_at>clock_timestamp())then raise exception'Amount is already reserved or claimed'using errcode='PT409';end if;
 insert into public.money_board_reservations(tile_id,capability_digest,expires_at,request_id)values(t.id,cap,clock_timestamp()+make_interval(secs=>b.reservation_seconds),request)returning *into r;
 result:=jsonb_build_object('action',action,'ordinal',t.ordinal,'amount_minor',t.amount_minor,'expires_at',r.expires_at,'state','reserved');
 elsif action='release'then
 select *into r from public.money_board_reservations where capability_digest=cap and tile_id in(select id from public.money_board_tiles where board_id=b.id)for update;
 if r.id is null then raise exception'Reservation unavailable'using errcode='PT404';end if;
 if exists(select 1 from public.fundraising_success_evidence where tile_id=r.tile_id)then raise exception'Claimed amount is permanent'using errcode='PT409';end if;
 update public.money_board_reservations set released_at=clock_timestamp(),release_reason='supporter_cancel'where id=r.id and released_at is null;
 insert into public.fundraising_intent_events(intent_id,state)select x.id,'canceled'from public.fundraising_intents x where x.reservation_id=r.id and not exists(select 1 from public.fundraising_intent_events e where e.intent_id=x.id and e.state<>'awaiting_payment');
 update public.fundraising_recurring_commitments set status='canceled'where intent_id in(select x.id from public.fundraising_intents x where x.reservation_id=r.id)and status='planned';
 result:=jsonb_build_object('action',action,'state','released');
 else
 if i?'ordinal'then
 if b.id is null then raise exception'Board unavailable'using errcode='PT404';end if;
 select *into t from public.money_board_tiles where board_id=b.id and generation_id=(select id from public.money_board_generations where board_id=b.id order by generation desc limit 1)and ordinal=(i->>'ordinal')::int for update;
 select *into r from public.money_board_reservations where tile_id=t.id and capability_digest=cap and released_at is null for update;
 if r.id is null or r.expires_at<=clock_timestamp()or exists(select 1 from public.fundraising_success_evidence where tile_id=t.id)then raise exception'Reservation expired or unavailable'using errcode='PT409';end if;amount:=t.amount_minor;
 else
 if not('direct_support'=any(c.channels))then raise exception'Direct support unavailable'using errcode='PT403';end if;amount:=(i->>'amount_minor')::bigint;
 end if;
 if amount is null or amount not between 1 and 1000000000000 then raise exception'Invalid support amount'using errcode='PT422';end if;
 if coalesce((i->>'anonymous')::boolean,false)and not c.allow_anonymous or coalesce((i->>'fee_cover')::boolean,false)and not c.allow_fee_cover then raise exception'Campaign preference unavailable'using errcode='PT422';end if;
 months:=(i->>'months')::int;if months is not null and(not c.allow_recurring or months not between 6 and 12)then raise exception'Recurring preference unavailable'using errcode='PT422';end if;
 attribution:=case when ctx?'share_id'then case when i->>'source'='qr'then'qr'else'participant_share'end when ctx?'team_id'then'team_campaign'else'organization_campaign'end;
 insert into public.fundraising_donors(display_name,email,mobile)values(btrim(i->>'display_name'),nullif(btrim(i->>'email'),''),nullif(btrim(i->>'mobile'),''))returning id into donor;
 insert into public.fundraising_intents(campaign_id,fundraiser_id,donor_id,board_id,tile_id,reservation_id,share_id,amount_minor,currency,anonymous,fee_cover,source_kind,provenance,reward_policy,capability_digest,expires_at,request_id)
 values(c.id,f.id,donor,case when t.id is not null then b.id end,t.id,r.id,(ctx->>'share_id')::uuid,amount,c.currency,coalesce((i->>'anonymous')::boolean,false),coalesce((i->>'fee_cover')::boolean,false),attribution,
 jsonb_strip_nulls(jsonb_build_object('organization_id',org,'restricted_use_organization_id',org,'campaign_id',c.id,'fundraiser_id',f.id,'participant_id',f.participant_id,'person_id',f.person_id,'unit_id',f.unit_id,'team_id',coalesce(f.team_id,b.team_id),'household_id',f.household_id,'channel',case when t.id is null then'direct_support'else'money_board'end,'share_id',ctx->>'share_id','source_kind',attribution,'board_id',case when t.id is not null then b.id end,'tile_id',t.id,'donor_id',donor,'amount_minor',amount,'currency',c.currency,'fee_cover_preference',coalesce((i->>'fee_cover')::boolean,false))),c.reward_policy,cap,coalesce(r.expires_at,clock_timestamp()+interval'10 minutes'),request)returning id into intent;
 insert into public.fundraising_intent_events(intent_id,state)values(intent,'awaiting_payment');
 if months is not null then
 insert into public.fundraising_recurring_commitments(intent_id,months,amount_minor,starts_on)values(intent,months,amount,current_date)returning id into commitment;
 insert into public.fundraising_recurring_occurrences(commitment_id,ordinal,due_on,amount_minor)select commitment,n,(current_date+(n-1)*interval'1 month')::date,amount from generate_series(1,months)n;
 end if;
 result:=jsonb_build_object('action',action,'state','awaiting_payment','amount_minor',amount,'currency',c.currency,'months',months,'expires_at',coalesce(r.expires_at,clock_timestamp()+interval'10 minutes'),'payment_available',false,'trial_days',c.reward_policy->'trial_days');
 end if;
 insert into boss_private.fundraising_guest_receipts(request_id,input_hash,capability_digest,result)values(request,h,cap,result);
 perform boss_private.fundraising_audit(null,c.id,f.id,'supporter.'||action,request,jsonb_build_object('state',result->>'state'));
 return result||'{"replayed":false}'::jsonb;
 exception when invalid_text_representation or numeric_value_out_of_range or check_violation or not_null_violation then raise exception'Invalid supporter input'using errcode='PT422';when unique_violation then raise exception'Supporter request conflict'using errcode='PT409';
end$$;
create function boss_fundraising_public.support(command jsonb)returns jsonb language sql volatile security definer set search_path=''as $$select boss_private.fundraising_guest(command)$$;
create function public.boss_fundraising_support(command jsonb)returns jsonb language sql volatile security invoker set search_path=''as $$select boss_fundraising_public.support(command)$$;
revoke all on function boss_private.fundraising_public_context(text),boss_private.fundraising_guest(jsonb),public.boss_fundraising_support(jsonb)from public,anon,authenticated,service_role;
revoke all on function boss_fundraising_public.support(jsonb)from public,anon,authenticated,service_role;
grant execute on function boss_fundraising_public.support(jsonb),public.boss_fundraising_support(jsonb)to anon,authenticated;

-- Closed integration contract. No PUBLIC/anon/authenticated/service_role execution.
-- A future reviewed adapter must verify external evidence before being authorized.
create function boss_private.fundraising_ingest_success(intent uuid,source_system text,source_reference text,amount bigint,currency text,settled_at timestamptz)returns uuid language plpgsql volatile security definer set search_path=''as $$
declare x public.fundraising_intents;f public.fundraising_fundraisers;c public.fundraising_campaigns;b public.money_boards;t public.money_board_tiles;r public.money_board_reservations;e public.fundraising_success_evidence;qualified boolean;
begin
 select *into x from public.fundraising_intents where id=intent;if x.id is null then raise exception'Intent unavailable'using errcode='PT404';end if;
 select *into c from public.fundraising_campaigns where id=x.campaign_id for update;
 if x.fundraiser_id is not null then select *into f from public.fundraising_fundraisers where id=x.fundraiser_id for update;end if;
 perform boss_private.fundraising_fence(c.organization_id,null,f.person_id);
 if x.board_id is not null then select *into b from public.money_boards where id=x.board_id for update;select *into t from public.money_board_tiles where id=x.tile_id for update;select *into r from public.money_board_reservations where id=x.reservation_id for update;end if;
 perform 1 from public.fundraising_intents where id=x.id for update;
 select *into e from public.fundraising_success_evidence where intent_id=x.id;
 if e.id is not null then if e.source_system<>source_system or e.source_reference<>source_reference or e.amount_minor<>amount or e.currency<>currency or e.settled_at<>settled_at then raise exception'Source replay conflict'using errcode='PT409';end if;return e.id;end if;
 if amount<>x.amount_minor or currency<>x.currency or length(btrim(source_system))not between 1 and 60 or length(btrim(source_reference))not between 1 and 200 or settled_at is null or settled_at>clock_timestamp()or settled_at<x.created_at or x.expires_at<=clock_timestamp()or exists(select 1 from public.fundraising_intent_events where intent_id=x.id and state<>'awaiting_payment')then raise exception'Invalid trusted evidence'using errcode='PT422';end if;
 if not boss_private.fundraising_active(c)or f.id is not null and not boss_private.fundraising_member(f)or x.tile_id is not null and(r.released_at is not null or r.expires_at<=clock_timestamp()or b.status<>'published'or not boss_private.fundraising_module(c.organization_id,'money_board')or exists(select 1 from public.fundraising_success_evidence where tile_id=x.tile_id))then raise exception'Contribution context ended'using errcode='PT409';end if;
 insert into public.fundraising_success_evidence(intent_id,tile_id,source_system,source_reference,amount_minor,currency,provenance,settled_at)values(x.id,x.tile_id,source_system,source_reference,amount,currency,x.provenance||jsonb_build_object('intent_id',x.id,'reward_policy',x.reward_policy),settled_at)returning *into e;
 insert into public.fundraising_intent_events(intent_id,state,source_reference,amount_minor)values(x.id,'succeeded',source_reference,amount);
 if x.reward_policy<>'{}'::jsonb then
 qualified:=x.reward_policy->>'currency'=currency and x.reward_policy->>'comparison'='gt'and amount>(x.reward_policy->>'threshold_minor')::bigint;
 insert into public.fundraising_reward_qualifications(evidence_id,policy,qualified,trial_days,status,provenance)values(e.id,x.reward_policy,qualified,(x.reward_policy->>'trial_days')::int,case when qualified then'gift_pending'else'not_qualified'end,e.provenance||jsonb_build_object('evidence_id',e.id));
 end if;
 perform boss_private.fundraising_audit(null,c.id,x.fundraiser_id,'contribution.trusted_success',x.request_id,jsonb_build_object('evidence_id',e.id));return e.id;
end$$;
revoke all on function boss_private.fundraising_ingest_success(uuid,text,text,bigint,text,timestamptz)from public,anon,authenticated,service_role;
