-- Table-specific records must be dispatched before resolving NEW/OLD fields.
create or replace function boss_private.bucks_identity_lock()returns trigger language plpgsql set search_path=''as $$begin
 if tg_table_name='boss_bucks_wallets'then
  if new.id<>old.id or new.household_id<>old.household_id or new.currency<>old.currency or new.created_at<>old.created_at then raise exception'Wallet identity is immutable'using errcode='23514';end if;
 elsif tg_table_name='boss_bucks_access'then
  if new.wallet_id<>old.wallet_id or new.person_id<>old.person_id or new.guardian_relationship_id<>old.guardian_relationship_id or new.organization_id<>old.organization_id or new.access_kind<>old.access_kind then raise exception'Wallet access context is immutable'using errcode='23514';end if;
 else raise exception'Unexpected wallet identity relation'using errcode='23514';end if;return new;
end$$;
revoke all on function boss_private.bucks_identity_lock()from public,anon,authenticated,service_role;
