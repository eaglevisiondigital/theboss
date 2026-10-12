# Minor communication safeguards

Participant messaging and minor group communication default disabled. Explicitly
enabling participant messaging still requires known age meeting the configured
minimum, default 18. Enabling a minimum below 18 requires minor-group and guardian-
visibility policy together. Unknown age fails closed. Private direct messaging with
any known minor or unknown-age recipient is always prohibited, including staff,
organization administrators and platform administrators.

A permitted minor group needs a current explicitly authorized guardian included in
that group. Guardian visibility is current relationship authority, not a historical
member snapshot. Turning off policy, ending the guardian relationship, clearing its
receive capability or removing its copied group membership closes protected access
on subsequent reads, sends, retries and downloads. Participant policy cannot be
bypassed by assigning a role. Organization staff authority never silently makes an
adult a child's guardian.

The two new guardian capabilities are `can_receive_communications` and
`can_send_communications`, both false by default. Existing registration, profile,
waiver, document and payment flags confer neither. Guardian-authorized team reads
require explicit receive capability and the child's actual current roster relation.
Sending additionally needs explicit send capability. A receive-only guardian cannot
send through a team membership fallback. Minor-group staff send requires scoped
send authority; a guardian sender requires their own current send capability.
A participant's own allowed group send remains subject to policy and copied guardian.

Only an explicitly authorized platform person-profile/communications administrator
can configure these capabilities on an existing verified guardian relationship.
That command neither verifies a relationship nor changes its identity, status or
lifecycle window, and records safe changed-field audit evidence. No guardian or
child receives a role or capability automatically from registration or module
activation. Live test relationship changes require their own controlled authorization.

Household membership alone grants no guardian communication authority. Tenant-owned
family groups additionally require current household participation, relevant current
tenant context and explicit guardian links. They create no organization-wide power
for managing global households. Ending household participation revokes that family
thread's historical access. Global person/household discovery is not available.

Names-only discovery and conversation projections omit DOB, email, phone, private
medical information and raw document paths. Private attachments retain the exact
thread/message authorization boundary and actor/session leases. Notification
payloads must use safe generic source/status information; sender and source context
can be shown without unnecessary private body or contact disclosure.

These defaults implement conservative technical protection. They do not claim
legal consent, compliance certification, guardian identity verification sufficiency,
malware scanning or permission to enable minors at a particular age. Relaxed policy,
legal rules and production consent/retention procedures require product direction.
