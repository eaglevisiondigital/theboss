# Merchant Platform, Phase 8A

Implementation checkpoint; live release and acceptance are not yet complete.

Merchants are canonical business resources, separate from organizations, people,
teams and households. The existing `commerce` catalog supplies availability;
merchant module configuration references that catalog without creating a fake
organization. All initial merchant functionality is free. Approved active
listing-only merchants are valid with zero offers. There are no merchant billing,
subscription, invoice, trial or sponsored placement gates.

Canonical people and verified live Boss Auth sessions own explicit merchant or
location assignments. Merchant roles share the permission catalog but use their
own resource assignment table. Platform review and sales assignments are separate.
Role mappings describe potential capability; an active exact assignment, current
person, actual merchant/location and module configuration still authorize each
operation. Location grants never imply sibling access. Owners can grant finite
operational roles; ownership requires reviewed claim approval. Administrators
cannot transfer ownership. Existing merchant-network staff acquire no authority
without explicit assignments. Original platform administrators retain bounded
platform review/recovery capability. Family, sports and membership rights remain
independent.

Claims are reviewed requests by the actual signed person; name/domain/email/phone
matches never establish ownership. A reviewer records a bounded verification
reason and approves exactly one pending claim transactionally. Claim creation
does not approve a listing. Consequential operations are audited without private
proofs or consumer contacts. Raw tables are RLS enabled and application writes
are closed; caller-bound transactional RPCs expose finite projections.

The minimum market catalog identifies exact Phase 7E country/region/market text;
only platform review can approve market entries. Locations reference approved
markets and IANA timezones. Public projection contains approved listing/contact
information and active public locations, never offer economics or redemption
mechanics. The public website is unchanged. Member discovery begins with an
explicit market; state/nationwide exploration uses the existing membership tiers
and never promises availability where no merchant exists. No precise location
history is retained.

Public directory, consumer deals, merchant portal and sales workspace have
separate routes and bounded paging. Merchant analytics are aggregate. Operational
redemption confirmation omits consumer email, phone, family and sports data.
Controlled media references use inert internal image references; arbitrary HTML,
remote active content and public redemption codes are rejected.
