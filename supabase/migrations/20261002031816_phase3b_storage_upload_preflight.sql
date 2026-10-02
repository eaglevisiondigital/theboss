-- The managed Storage upload preflight performs a rolled-back INSERT using
-- {mimetype, contentLength}; persisted backend metadata uses {mimetype, size}.
-- Validate either exact intent-bound size, and reject conflicting values when
-- both are supplied. Document completion still independently validates the
-- persisted backend MIME and size before consuming the intent.
-- Only the authenticated upload route may pass this check. Signed-upload URL
-- creation must not mint a bearer capability that survives intent expiry or
-- guardian/session revocation.
-- Primary source: https://github.com/supabase/storage/blob/master/src/storage/uploader.ts
create or replace function boss_private.registration_storage_insert(p_bucket text,p_name text,p_metadata jsonb) returns boolean
language plpgsql stable security definer set search_path='' as $$begin
 perform boss_private.require_live_auth();
 return storage.allow_only_operation('object.upload') and p_bucket='boss-registration-documents' and jsonb_typeof(p_metadata)='object'
 and exists(select 1 from public.document_upload_intents i join public.registration_documents d on d.id=i.document_id and d.organization_id=i.organization_id
 where i.object_name=p_name and d.object_name=p_name
 and i.actor_person_id=boss_private.current_person_id() and i.auth_session_id=(auth.jwt()->>'session_id')::uuid and i.expires_at>now() and i.consumed_at is null
 and boss_private.registration_feature(d.organization_id,'registration') and boss_private.registration_feature(d.organization_id,'documents')
 and boss_private.registration_guardian(d.participant_id,'can_register') and boss_private.registration_guardian(d.participant_id,'can_view_documents')
 and d.status='upload_pending' and d.snapshot->'allowed_mime_types' @> jsonb_build_array(i.mime_type)
 and i.size_bytes<=coalesce((d.snapshot->>'max_bytes')::bigint,10485760)
 and p_metadata->>'mimetype'=i.mime_type
 and (p_metadata->>'size' is not null or p_metadata->>'contentLength' is not null)
 and (p_metadata->>'size' is null or (p_metadata->>'size' ~ '^[0-9]{1,10}$' and (p_metadata->>'size')::bigint=i.size_bytes))
 and (p_metadata->>'contentLength' is null or (p_metadata->>'contentLength' ~ '^[0-9]{1,10}$' and (p_metadata->>'contentLength')::bigint=i.size_bytes))
 and not exists(select 1 from storage.objects o where o.bucket_id=p_bucket and o.name=p_name));
 exception when sqlstate 'PT401' or invalid_text_representation or numeric_value_out_of_range then return false;
end $$;

-- Some managed Storage adapters use INSERT RETURNING during permission checks.
-- Its SELECT policy may see the newly inserted row, so duplicate prevention
-- belongs in the INSERT policy and Storage's unique object key, not this read
-- predicate. The server-established exact upload operation admits no download,
-- list, info, signing, copying, update, or operation-less SELECT through this
-- branch. Actual file access continues to require the existing audited lease.
-- Primary sources:
-- https://supabase.com/docs/guides/storage/schema/helper-functions
-- https://github.com/supabase/storage/blob/master/src/http/routes/operations.ts
create function boss_private.registration_storage_upload_select(p_bucket text,p_name text) returns boolean
language plpgsql stable security definer set search_path='' as $$begin
 perform boss_private.require_live_auth();
 return storage.allow_only_operation('object.upload') and p_bucket='boss-registration-documents'
 and exists(select 1 from public.document_upload_intents i join public.registration_documents d on d.id=i.document_id and d.organization_id=i.organization_id
 where i.object_name=p_name and d.object_name=p_name
 and i.actor_person_id=boss_private.current_person_id() and i.auth_session_id=(auth.jwt()->>'session_id')::uuid and i.expires_at>now() and i.consumed_at is null
 and boss_private.registration_feature(d.organization_id,'registration') and boss_private.registration_feature(d.organization_id,'documents')
 and boss_private.registration_guardian(d.participant_id,'can_register') and boss_private.registration_guardian(d.participant_id,'can_view_documents')
 and d.status='upload_pending' and d.snapshot->'allowed_mime_types' @> jsonb_build_array(i.mime_type)
 and i.size_bytes<=coalesce((d.snapshot->>'max_bytes')::bigint,10485760));
 exception when sqlstate 'PT401' or invalid_text_representation or numeric_value_out_of_range then return false;
end $$;
revoke all on function boss_private.registration_storage_upload_select(text,text) from public,anon,authenticated,service_role;
grant execute on function boss_private.registration_storage_upload_select(text,text) to authenticated;
create policy boss_registration_document_upload_returning on storage.objects for select to authenticated
 using(boss_private.registration_storage_upload_select(bucket_id,name));

-- A leased SELECT must authorize authenticated byte delivery only. Storage's
-- signing routes use SELECT to mint bearer URLs and subsequently read objects
-- as an internal superuser, bypassing later lease expiry or role revocation.
-- The platform delivers attachments through authenticated .download GET;
-- reusable signed URLs, listing, copying, and info endpoints are not supported.
-- Primary sources:
-- https://github.com/supabase/storage/blob/master/src/storage/object.ts
-- https://github.com/supabase/storage/blob/master/src/http/routes/object/getSignedObject.ts
create or replace function boss_private.registration_storage_select(p_bucket text,p_name text) returns boolean
language plpgsql stable security definer set search_path='' as $$begin
 perform boss_private.require_live_auth();
 return storage.allow_only_operation('object.get_authenticated') and p_bucket='boss-registration-documents'
 and exists(select 1 from public.registration_documents d join boss_private.document_access_leases l on l.document_id=d.id
 where d.object_name=p_name and l.actor_person_id=boss_private.current_person_id() and l.auth_session_id=(auth.jwt()->>'session_id')::uuid and l.expires_at>now()
 and ((l.purpose='ordinary' and boss_private.registration_can_document(d.id)) or (l.purpose='emergency' and d.snapshot->>'classification'='medical' and d.snapshot->'emergency_access'='true'::jsonb
 and d.status='approved' and (d.expires_on is null or d.expires_on>=current_date) and boss_private.registration_emergency_authorized(d.participant_id,d.organization_id,l.team_id))));
 exception when sqlstate 'PT401' or invalid_text_representation then return false;
end $$;
