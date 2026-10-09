export const merchantFields = {
 "category.configure": ["key", "name", "status"],
  "market.create": [
    "country",
    "region",
    "market"
  ],
  "merchant.create": [
    "name",
    "legal_name",
    "description",
    "category",
    "market_id",
    "website",
    "public_phone",
    "controlled"
  ],
  "claim.submit": [
    "merchant_id",
    "statement"
  ],
  "claim.review": [
    "merchant_id",
    "claim_id",
    "state",
    "reason",
    "ends_at"
  ],
  "merchant.review": [
    "merchant_id",
    "state",
    "reason"
  ],
  "merchant.configure": [
    "merchant_id",
    "status",
    "portal",
    "offers",
    "redemption",
    "ends_at"
  ],
  "merchant.edit": [
    "merchant_id",
    "expected_version",
    "name",
    "description",
    "website",
    "public_phone"
  ],
  "access.grant": [
    "merchant_id",
    "location_id",
    "person_id",
    "role",
    "ends_at"
  ],
  "access.end": [
    "merchant_id",
    "assignment_id"
  ],
  "staff.grant": [
    "merchant_id",
    "person_id",
    "role",
    "ends_at"
  ],
  "staff.end": [
    "merchant_id",
    "assignment_id"
  ],
  "location.create": [
    "merchant_id",
    "market_id",
    "name",
    "address",
    "city",
    "postal_code",
    "timezone",
    "phone",
    "website",
    "hours_note"
  ],
  "location.edit": [
    "merchant_id",
    "location_id",
    "expected_version",
    "name",
    "hours_note",
    "status"
  ],
  "family.create": [
    "merchant_id",
    "location_id",
    "usage_limit",
    "reset_period",
    "usage_timezone",
    "period_start",
    "period_end"
  ],
  "family.status": [
    "merchant_id",
    "family_id",
    "status"
  ],
  "offer.create": [
    "merchant_id",
    "family_id",
    "title",
    "description",
    "offer_type",
    "discount_bps",
    "currency",
    "amount_minor",
    "buy_quantity",
    "benefit_quantity",
    "purchase_description",
    "benefit_description",
    "qualification",
    "minimum_minor",
    "qualifying_description",
    "exclusions",
    "stacking",
    "stacking_policy",
    "starts_at",
    "ends_at",
    "weekdays",
    "local_start",
    "local_end",
    "weekly_special",
    "location_policy",
    "location_ids",
    "include_future",
    "allow_local_pause"
  ],
  "offer.status": [
    "merchant_id",
    "location_id",
    "revision_id",
    "state",
    "reason"
  ],
  "offer.local": [
    "merchant_id",
    "family_id",
    "location_id",
    "paused",
    "presentation_note"
  ],
  "intent.create": [
    "merchant_id",
    "location_id",
    "revision_id",
    "capability"
  ],
  "token.verify": [
    "merchant_id",
    "location_id",
    "capability"
  ],
  "token.redeem": [
    "merchant_id",
    "location_id",
    "capability"
  ],
  "redemption.correct": [
    "merchant_id",
    "redemption_id",
    "reason",
    "restore_allowance"
  ],
  "sales.grant": [
    "person_id",
    "role",
    "market_id",
    "manager_id",
    "ends_at"
  ],
  "sales.end": [
    "assignment_id"
  ],
  "lead.create": [
    "market_id",
    "name",
    "category",
    "source",
    "rep_id",
    "manager_id"
  ],
  "lead.activity": [
    "lead_id",
    "kind",
    "note",
    "due_at"
  ],
  "lead.state": [
    "lead_id",
    "expected_version",
    "state"
  ],
  "lead.reassign": [
    "lead_id",
    "expected_version",
    "rep_id",
    "manager_id"
  ],
  "lead.convert": [
    "lead_id",
    "expected_version",
    "controlled"
  ],
  "favorite.set": [
    "merchant_id",
    "favorite"
  ]
} as const;
export type MerchantAction = keyof typeof merchantFields;

export const merchantRequired = {"category.configure": ["key", "name", "status"], "market.create": ["country", "region", "market"], "merchant.create": ["name", "category", "market_id"], "claim.submit": ["merchant_id", "statement"], "claim.review": ["merchant_id", "claim_id", "state", "reason"], "merchant.review": ["merchant_id", "state", "reason"], "merchant.configure": ["merchant_id", "status"], "merchant.edit": ["merchant_id", "expected_version"], "access.grant": ["merchant_id", "person_id", "role"], "access.end": ["merchant_id", "assignment_id"], "staff.grant": ["merchant_id", "person_id", "role"], "staff.end": ["merchant_id", "assignment_id"], "location.create": ["merchant_id", "market_id", "name", "address", "city", "postal_code", "timezone"], "location.edit": ["merchant_id", "location_id", "expected_version"], "family.create": ["merchant_id", "reset_period", "usage_timezone"], "family.status": ["merchant_id", "family_id", "status"], "offer.create": ["merchant_id", "family_id", "title", "offer_type", "qualification", "stacking", "starts_at", "ends_at", "location_policy"], "offer.status": ["merchant_id", "revision_id", "state"], "offer.local": ["merchant_id", "family_id", "location_id", "paused"], "intent.create": ["merchant_id", "location_id", "revision_id", "capability"], "token.verify": ["merchant_id", "location_id", "capability"], "token.redeem": ["merchant_id", "location_id", "capability"], "redemption.correct": ["merchant_id", "redemption_id", "reason"], "sales.grant": ["person_id", "role", "market_id"], "sales.end": ["assignment_id"], "lead.create": ["market_id", "name", "category", "source"], "lead.activity": ["lead_id", "kind", "note"], "lead.state": ["lead_id", "expected_version", "state"], "lead.reassign": ["lead_id", "expected_version", "rep_id"], "lead.convert": ["lead_id", "expected_version"], "favorite.set": ["merchant_id", "favorite"]} as const;
