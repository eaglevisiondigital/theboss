// Exact finite fields shared with the locally validated database contract.
export const PARTNER_FIELDS = {
 "provider.create": [
  "key",
  "name",
  "legal_reference",
  "support_reference",
  "synthetic"
 ],
 "provider.state": [
  "provider_id",
  "expected_version",
  "state",
  "reason"
 ],
 "configuration.create": [
  "provider_id",
  "method",
  "capabilities",
  "credential_reference",
  "full_withdraw_missing",
  "max_stale_seconds",
  "starts_at",
  "ends_at"
 ],
 "contract.create": [
  "provider_id",
  "document_reference",
  "rights_holder_reference",
  "countries",
  "categories",
  "methods",
  "product_id",
  "minimum_tier",
  "display_rights",
  "caching_rights",
  "branding_rules",
  "attribution_rules",
  "sharing_fields",
  "retention_days",
  "refund_policy_reference",
  "starts_at",
  "ends_at"
 ],
 "contract.review": [
  "provider_id",
  "contract_id",
  "state",
  "approval_reference"
 ],
 "territory.create": [
  "provider_id",
  "contract_id",
  "country",
  "region",
  "market_id",
  "starts_at",
  "ends_at"
 ],
 "territory.end": [
  "provider_id",
  "territory_id"
 ],
 "catalog.snapshot.begin": [
  "provider_id",
  "expected_items"
 ],
 "catalog.review": [
  "provider_id",
  "revision_id",
  "state"
 ],
 "policy.create": [
  "provider_id",
  "contract_id",
  "currency",
  "basis",
  "fixed_minor",
  "rate_ppm",
  "recognition_condition",
  "starts_at",
  "ends_at"
 ],
 "transaction.create": [
  "provider_id",
  "external_id",
  "revision_id",
  "policy_id",
  "currency",
  "eligible_minor",
  "attributed_person_id",
  "native_sales_lead_id",
  "synthetic",
  "occurred_at",
  "evidence_reference"
 ],
 "transaction.event": [
  "provider_id",
  "transaction_id",
  "external_event_id",
  "kind",
  "adjustment_minor",
  "corrects_event_id",
  "evidence_reference"
 ],
 "catalog.import": [
  "provider_id",
  "feed_sequence",
  "kind",
  "synthetic",
  "items",
  "snapshot_id"
 ],
 "catalog.pause": [
  "provider_id",
  "source_id"
 ],
 "catalog.withdraw": [
  "provider_id",
  "source_id"
 ],
 "catalog.snapshot.complete": [
  "provider_id",
  "snapshot_id"
 ],
 "catalog.snapshot.abort": [
  "provider_id",
  "snapshot_id"
 ],
 "integration.activate": [
  "provider_id"
 ]
} as const;
