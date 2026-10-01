-- Disposable-only guard parity. No objects or files are deleted. The runner's
-- local compatibility layer must reject even zero-row direct SQL DELETE before
-- row filtering, matching the observed managed Storage protection.
BEGIN;
DO $$DECLARE failed boolean:=false;BEGIN
 SET LOCAL ROLE authenticated;
 BEGIN DELETE FROM storage.objects WHERE bucket_id='boss-registration-documents' AND name='synthetic-managed-guard-missing-fixture' AND false;
 EXCEPTION WHEN SQLSTATE 'P0001' THEN failed:=true;END;
 IF NOT failed THEN RAISE EXCEPTION 'Managed Storage direct SQL delete guard missing';END IF;
 RESET ROLE;
END $$;
SELECT 1 AS passed_assertions;
ROLLBACK;
