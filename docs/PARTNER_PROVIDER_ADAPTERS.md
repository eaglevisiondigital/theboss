# Provider adapter contracts

**PHASE 8B1 LOCAL IMPLEMENTATION COMPLETE / PRODUCTION RELEASE PENDING EXPLICIT APPROVAL**

The TypeScript PartnerAdapter is provider-neutral and capability-specific. Methods: rest, scheduled_feed, secure_file, hosted_redirect, sso, reservation_flow, mock. Fourteen capabilities: catalog_read, benefit_search, benefit_detail, eligibility_check, external_redirect, coupon_retrieval, reservation_quote, price_recheck, booking_request, booking_status, cancellation, refund_status, commission_report, commission_reconciliation.

Each capability has a typed input/output pair. A disabled adapter has no transport, endpoint, credential loader, network fetch or operational secret path. Supported capabilities return activation_disabled; unsupported ones return capability_unsupported. The synthetic adapter requires an explicit fixture: identity and local supplied values; application server code does not construct one or expose its results to consumers.

Finite failures are activation_disabled, provider_unavailable, contract_inactive, capability_unsupported, territory_unsupported, stale_catalog, invalid_source_record, quote_expired, malformed_response, unknown_outcome and rate_limited. An unknown outcome cannot be reported as a successful booking or financial event. These are extension contracts, not live retry/scheduling workers.

Credential readiness is distinct from method/capability configuration. The only ordinary-table credential field is an optional constrained partner-vault/reference, never a value or arbitrary URL. All readiness stays false; browser/admin reads omit the reference. No provider secret or production environment variable is added. Future activation requires separately reviewed server-only secret storage and readiness evidence.

Future redirects/SSO require approved issuer/audience/protocol, short-lived assertions, scoped attributes, explicit contractual/consent authority, nonce/replay protection, revocation and independent logout. Allowed future attribute names are subject_pseudonym, country and membership_tier; default is none. No child, medical, family, sports or precise-location attribute exists. No assertion or redirect is generated now.

No canonical migration, deployment, commit/push, PR update, production test authority or live provider execution is authorized by this checkpoint. Phase 8A remains COMPLETE with its prior evidence limitations; Phase 8B2 has not started.
