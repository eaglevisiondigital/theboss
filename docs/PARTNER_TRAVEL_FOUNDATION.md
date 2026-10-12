# Travel contract foundation

**PHASE 8B1 LOCAL IMPLEMENTATION COMPLETE / PRODUCTION RELEASE PENDING EXPLICIT APPROVAL**

TravelQuote models exact provider/source revision, property/rate plan, destination, travel dates, bounded travelers, country/tier, integer price/tax/fee amounts, currency, availability, cancellation terms, expiry and provider references. Availability, evidence-backed discount and contracted commissionability are independent facts. A rate alone is not savings; comparison policy/evidence is required to assert a discount. Commercial policy/contract evidence is required for commissionability. No 8%–18% business projection is hard-coded as a contracted rate.

Synthetic inspection covers the four discount/commission combinations, unavailable travel, expired quote, wrong country/tier, malformed dates/currency/amounts and provider-unavailable classification. Price recheck requires current availability/expiry, matching provider/property/rate/dates/travelers/currency and unchanged price/taxes/fees/cancellation terms; a changed quote fails safely and must receive a separately approved customer decision. A historical quote is never guaranteed checkout pricing.

Future quote, request, provider acceptance, confirmation, modification, cancellation, fulfillment, refund, dispute, recognition and settlement states are architecture contracts. The evidence stream in this phase represents synthetic provenance only. There is no travel API, live booking worker, payment, reservation or consumer booking control. Live provider-specific consent, comparison rules, cancellation/refund economics and certification remain product/commercial decisions.

No canonical migration, deployment, commit/push, PR update, production test authority or live provider execution is authorized by this checkpoint. Phase 8A remains COMPLETE with its prior evidence limitations; Phase 8B2 has not started.
