# NMI adapter: local contract checkpoint

Status: LOCAL CONTRACT TESTED, sandbox account/secrets/worker unconfigured.
No provider sandbox or production request has been executed.

The adapter implements documented sandbox v5 token/profile sale, authorization,
capture, void, bounded card/ACH refund, customer-vault creation and transaction
retrieval requests. It sends payment tokens or account-bound vault references,
never PAN/CVV/bank fields. ACH acceptance remains pending. Provider receipt
generation is disabled so later Boss receipts derive from canonical accounting.
Unknown/error results remain reconcilable rather than triggering another sale.

The current public API reference supplies the sandbox host. Production stays
closed until the exact approved merchant endpoint and account contract are
certified. The duplicate-check duration is a heuristic, not durable idempotency.
Remote customer-wide deletion is disabled because it could revoke other methods;
future signed local method revocation must remain exact. Recurring CIT/MIT and
initial-transaction consent context require the separate execution integration;
no automated recurring payment is operational.

Webhooks verify HMAC SHA-256 over the documented nonce plus raw body. A nonce is
not assumed to be a Unix timestamp. Safe event/transaction/type/digest hints
require persistent account/event replay protection and authoritative retrieval.
No raw body or free-form provider response text is retained.

NMI recommends its Payment Component. The public documentation currently exposes
package placeholders; the named React package was unavailable in the public
registry during review. No guessed dependency was installed. The documented
Collect.js token contract is also compatible with v5 and can provide provider-owned
secure fields after account verification. Browser collection is not installed yet.
No PCI compliance certification is claimed.

Primary references: [sale](https://docs.nmi.com/reference/create-sale-v5),
[capture](https://docs.nmi.com/reference/capture-payment-v5),
[refund](https://docs.nmi.com/reference/refund-payment-v5),
[retrieval](https://docs.nmi.com/reference/get-payment-v5),
[token examples](https://docs.nmi.com/docs/payment-code-examples),
[Payment Component](https://docs.nmi.com/docs/payment-component),
[vault lifecycle](https://docs.nmi.com/docs/full-transaction-lifecycle-example),
[webhook overview](https://docs.nmi.com/reference/overview).


## Validated dependent continuation

Bounded classic Query API uses exact `order_id` recovery and date/page-limited reporting; matching transaction details are retrieved through the certified sandbox v5 boundary. DTD/entity declarations and ambiguous references are rejected. Missing query results never prove no charge. Only finite references/status hints leave XML parsing; customer/bank fields are not materialized into canonical records. Actual processor cost is not inferred from surcharge/convenience fee. Production v5 activation still awaits endpoint/account certification. See official [Query API](https://docs.nmi.com/reference/query).
