-- Managed authenticated download authorization uses the documented exact pair:
-- object.get_authenticated_info preflight and object.get_authenticated delivery.
-- Primary source:
-- https://supabase.com/docs/guides/storage/security/access-control
-- https://supabase.com/docs/guides/storage/schema/helper-functions
-- https://raw.githubusercontent.com/supabase/storage/v1.77.5/src/http/routes/object/getObjectInfo.ts
--
-- Observed hosted SDK byte-download and anonymous public-byte requests produced
-- the info operation label in managed backend logs. That observation does not
-- establish the implementation of managed ingress or CDN preflight; no such
-- infrastructure behavior is assumed for authorization. Both exact operations
-- still require the same live identity, current authority, exact document path,
-- actor/session-bound two-minute audited lease, and purpose/status checks below.
-- Signing, listing, public, copy, HEAD, and operation-less requests gain no access.
-- CREATE OR REPLACE preserves the existing private function ACL; no policy,
-- upload helper, bucket, grant, lease duration, or authorization predicate changes.
create or replace function boss_private.registration_storage_select(p_bucket text,p_name text) returns boolean
language plpgsql stable security definer set search_path='' as $$begin
 perform boss_private.require_live_auth();
 return (storage.allow_only_operation('object.get_authenticated') or storage.allow_only_operation('object.get_authenticated_info')) and p_bucket='boss-registration-documents'
 and exists(select 1 from public.registration_documents d join boss_private.document_access_leases l on l.document_id=d.id
 where d.object_name=p_name and l.actor_person_id=boss_private.current_person_id() and l.auth_session_id=(auth.jwt()->>'session_id')::uuid and l.expires_at>now()
 and ((l.purpose='ordinary' and boss_private.registration_can_document(d.id)) or (l.purpose='emergency' and d.snapshot->>'classification'='medical' and d.snapshot->'emergency_access'='true'::jsonb
 and d.status='approved' and (d.expires_on is null or d.expires_on>=current_date) and boss_private.registration_emergency_authorized(d.participant_id,d.organization_id,l.team_id))));
 exception when sqlstate 'PT401' or invalid_text_representation then return false;
end $$;
