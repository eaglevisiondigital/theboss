# Native offers and redemption, Phase 8A

Implementation checkpoint; tests and live acceptance remain outstanding.

Offer families retain identity across immutable revisions. Structured percentage
basis points, fixed currency/minor units, BOGO quantities and free-item benefits
have explicit qualifying purchase, exclusions and reviewed stacking policy.
Every revision, including presentation edits, uses the conservative review path;
there is no economic review bypass. Review events are append-only. Corporate
pause overrides local state. Local managers may pause only explicitly assigned
locations. Local presentation overrides are bounded and cannot alter economics.
Selected/all-current locations are frozen revision targets; future inclusion is
an explicit reviewed flag. No franchise hierarchy implies access.

Usage policy belongs to the stable family: positive custom limit or unlimited,
lifetime/promotion/weekly/monthly window and explicit IANA usage timezone. Edits
do not reset allowances. Promotion windows are explicit immutable family dates;
new allowance policy requires a new family, never an unnoticed revision reset.
Availability uses each location's wall clock, configured weekdays and optional
hours. Fall-back repeated hours evaluate one recurrence, not duplicate offers.

The consumer supplies a cryptographically random one-time business capability
for a five-minute intent. Only its SHA-256 digest is persisted. Intent binds the
signed person, exact existing membership/source, merchant, location, family,
revision, window and expiry. It contains no Auth credential or database authority.
The merchant code-entry fallback handles this short-lived business proof; no
permanent membership QR is used. Normal reads cannot recover a proof.

Redemption locks merchant state, current assignment/person, membership/source
and family allowance, then rechecks live eligibility at commit. Geography,
merchant/module/location state, review/publication, local schedule, exact token
scope and immutable use evidence must all pass. Two clerks cannot consume the
same token or final use. Same request/actor id returns a safe current-authorized
receipt; a new request with a consumed token is denied. Revoked authority cannot
retrieve a prior mutation receipt. Immutable redemptions plus explicit reviewed
corrections rebuild usage; correction only restores allowance when explicitly
requested, once, by an authorized Boss reviewer. No history deletion.

Redemption verifies discount eligibility only. It creates no payment transaction,
Wallet spend, processor charge, cash value or merchant POS purchase. Membership,
coverage, expiry and revocation always use Phase 7E canonical evidence. Public
directory never exposes member-only terms. Favorites never grant eligibility.
