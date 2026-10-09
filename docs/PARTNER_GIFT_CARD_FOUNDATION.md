# Gift-card contract foundation

**PHASE 8B1 LOCAL IMPLEMENTATION COMPLETE / PRODUCTION RELEASE PENDING EXPLICIT APPROVAL**

GiftCard represents exact provider/external identity, brand, denomination/face/purchase minor amounts, currency, country, digital/physical delivery, expiry/withdrawal, refund terms and optional commercial policy. Synthetic validation requires valid bounded integer amounts, matching denomination/face value, purchase not above face value, valid delivery/country/currency and current nonwithdrawn evidence. Member discount is an evidence-derived difference, not earned revenue.

These are typed data/adapter contracts over the general immutable catalog/revision foundation, not live inventory or a provider SKU integration. Invalid data fails closed. IssuanceEnabled is always false. No code, card secret, inventory purchase, fulfillment, cash-out, payment or Wallet credit exists. Gift-card face value never becomes Boss Bucks Wallet value. Future catalog-specific persistence, provider fulfillment references and lawful return/activation policies require separate approved integration work.

No canonical migration, deployment, commit/push, PR update, production test authority or live provider execution is authorized by this checkpoint. Phase 8A remains COMPLETE with its prior evidence limitations; Phase 8B2 has not started.
