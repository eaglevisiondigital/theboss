# Phase 7E performance

Status: LOCAL RUNTIME VERIFIED; canonical post-release checks pending.

Six 1,000-card batches produce 6,000 unique serials, private activation digests and
creation records. Each write operation is bounded at 1,000; reads return at most
100 cards/50 batches with UUID continuation. Serial and digest equality lookups use
unique indexes; the exact organization inventory uses an index at this scale.
Over-limit batch creation fails. Historical request statement_timeout remains 8s.

Membership views return at most 50 memberships, 20 linked physical credentials and
30 source facts each. Product catalog limits 50; organizations use bounded
revision, order, fulfillment and financial views. Current authority is rechecked
before receipt replay; exact subject/source/card locks serialize competing writes.
Foreign keys on new public/private discount relations have full supporting indexes.
No unrelated index is removed and no historical performance/incident evidence is
rewritten. Actual canonical advisor findings are recorded after migration.

Canonical post-migration verifier passes all supporting new foreign-key indexes,
validated constraints and raw table/function ACLs. Performance advisors retain the
existing unused-index and absolute Auth-connection-allocation information. No new
error or timeout change; no unrelated index removed.
