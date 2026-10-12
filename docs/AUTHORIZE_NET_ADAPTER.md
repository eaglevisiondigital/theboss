# Authorize.Net adapter: local contract checkpoint

Status: LOCAL CONTRACT TESTED, operational account/secrets/worker unconfigured.
No provider sandbox or production request has been executed.

The adapter maps finite sale, authorization, capture, void, card refund and
transaction retrieval operations. Amounts use integer minor units converted to
decimal strings. Refunds require the original provider transaction and permitted
masked last four, never a new credit to an arbitrary instrument. ACH submission
is pending; its remote refund contract is deliberately unimplemented pending
provider/account certification. Profile creation uses a prior transaction.

Sandbox and production have fixed distinct endpoints. Production execution is
disabled by default and separately requires approved account/secret context and
explicit money-movement authorization. Generic errors, duplicate errors and
timeouts remain unknown. Correlation references and the duplicate window are not
permanent idempotency. Durable dispatch/reconciliation must prevent another sale.

Only transaction/status/amount/correlation, safe AVS/CVV **result codes**, masked
last four and profile references leave normalization. No full response, free-form
error, billing address or raw card data is persisted. Signed webhook input is
checked with HMAC SHA-512 and a hex-decoded signature key; the result is a hint,
requiring transaction retrieval and persistent account/event deduplication.

Browser collection is planned through provider-hosted AcceptUI; Boss raw-card
fields are prohibited. The collection component is not installed at this checkpoint.
PCI/SAQ eligibility depends on the final integration and merchant validation;
this checkpoint is not a compliance certification.

Primary references: [transactions](https://developer.authorize.net/api/reference/features/payment-transactions.html),
[Accept.js/AcceptUI](https://developer.authorize.net/api/reference/features/acceptjs.html),
[profiles](https://developer.authorize.net/api/reference/features/customer-profiles.html),
[webhooks](https://developer.authorize.net/api/reference/features/webhooks.html),
[API reference](https://developer.authorize.net/api/reference/index.html).


## Validated dependent continuation

Bounded unknown-reference recovery queries the original invoice reference, then exact transaction details. Missing/ambiguous reporting results remain unknown, never definitive not-found. Date-limited batch discovery and paginated transaction hints omit raw customer fields. Processor fees are not inferred from settlement gross or net; missing actual fee evidence holds attribution. Refund execution retrieves the verified original settled card last four transiently, then uses the original tender reference. The private worker persists normalized evidence, not that transient method data. See official [transaction reporting](https://developer.authorize.net/api/reference/features/transaction-reporting.html).
