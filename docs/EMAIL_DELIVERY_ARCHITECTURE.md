# Boss email delivery foundation

No application email provider has been approved or provisioned. Supabase Auth's
historical SMTP configuration serves identity flows and is not this transport.
Phase 4A adds no provider credentials, production environment values, SMTP change
or real email send. `configuredEmailProvider()` returns null. Hosted email work is
truthfully `suppressed` with `not_configured`; SMS/push remain future channels.

The provider-neutral `EmailProvider` interface receives a rendered template,
internally resolved recipient and stable delivery key. It returns provider
acceptance/reference or a safe transient, permanent or ambiguous failure category.
It never exposes raw provider exceptions through user views. A production adapter
and durable repository binding remain explicit operational decisions; the adapter
contract does not imply a configured worker.

The template renderer provides Boss branding, safe organization name, subject,
preheader, escaped HTML, plain-text fallback and one fixed-format Boss CTA. Text is
bounded, subject header injection is rejected and destination paths allow only
canonical Calendar/Registration/Messages source IDs on the approved server origin.
The notification contains no document contents, medical data, contact details or
payment reference. A destination link conveys no access grant.

Delivery state is separate from canonical content: queued, processing, sent,
delivered, failed, bounced, suppressed and canceled. `sent` means accepted by the
provider. Delivered/bounced require authenticated provider evidence; no signed
client command can forge those states. Provider references remain private and are
not returned in the safe delivery history.

A future production repository must atomically claim due work with a lease and
fencing generation, resolve current source authority/preferences, and conditionally
finish only that generation. `dispatchEmailDelivery` exercises this contract.
Optional email preferences suppress the send. A fixed server mandatory policy
bypasses preference only, never source authorization. A missing provider suppresses
truthfully without an infinite retry loop.

The stable key is `boss-notification:<delivery UUID>` and survives every retry.
Transient/idempotent ambiguous failures use bounded backoff at 60 seconds,
five minutes, 30 minutes and two hours, with five maximum attempts. Permanent
failures stop immediately. An expired worker cannot overwrite its successor.

Local exactly-once constraints cannot alone guarantee exactly-once external email
when the process crashes after provider acceptance but before database commit.
A production provider must support idempotency and/or reconciliation. Retrying an
expired/ambiguous accepted request without that support is prohibited and records
terminal ambiguous failure for reconciliation. The synthetic adapter demonstrates
same-key acceptance returning the same reference after a crash; it refuses every
destination outside the reserved `.invalid` namespace and performs no network I/O.

The application tests cover simultaneous claims, accepted-provider crash/retry,
bounded failures/backoff, lost authority, preferences, internal mandatory policy,
invalid references, safe templates/CTA and unconfigured availability. Database tests
cover durable source/delivery deduplication and actual two-connection source,
SKIP-LOCKED expansion and request-receipt races. Live sender/domain/provider choice,
verified account destination resolution, worker credentials and signed webhook
verification require a separate approved provisioning step before email is enabled.
