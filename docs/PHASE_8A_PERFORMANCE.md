# Phase 8A performance evidence

LOCAL/DISPOSABLE RUNTIME VERIFIED. Canonical/hosted merchant measurements pending.
Synthetic scale: 10,000 merchants, 40,000 locations, 10,000 reviewed offers and
10,000 CRM leads. Each request has the existing eight-second SQL limit. Ten
bounded-output/geography/index assertions pass.

| Projection | Milliseconds | Response bytes |
| --- | ---: | ---: |
| Public directory, 30 listings | 18.065 | 17,029 |
| Consumer, 30 offer/location pairs | 126.540 | 43,136 |
| Outside-country offer denial, safe public listings remain | 7.502 | 26,750 |
| Unassigned sales view, zero leads | 42.358 | 381 |
| Owner portal home, one assigned merchant | 5.336 | 844 |
| Platform sales page, 30 leads | 3.319 | 10,775 |
| Exact merchant portal | 22.973 | 4,394 |

These are individual fresh disposable measurements, not a production SLA. Public
listing geography and member-only economic eligibility remain separate. No
national unbounded CRM/feed. Indexed exact geography, person/merchant assignments,
lead territory, revision targets, immutable allowance and private intent digest
support scoped queries. Every new merchant FK receives a leading index when an
existing nonpartial index does not already cover it.

Early scale validation found repeated full PostgreSQL timezone enumeration and
membership checks per candidate. The final implementation caches authoritative
IANA names at migration time, computes current market coverage once, prefilters
indexed active commerce/location/review targets and checks current eligibility
again before emitting final offers. No security check or request timeout was
removed. All relevant historical and new authorization/race tests pass.


## Hosted refresh observation

The single hosted window stopped after native offer submission committed and the
subsequent refreshed page displayed the error boundary. Narrow safe upstream
endpoint/status aggregates show HTTP 200 for the mutation, merchant read and the
other layout reads; they do not establish end-to-end browser timing or root cause.
No hosted performance PASS, production SLA or timeout diagnosis is inferred from
these aggregates. Local synthetic mutation-refresh/reload passes, and the restored
read-only archived merchant page loads. The failure remains unresolved; no timeout
increase, infrastructure mutation or second hosted window was used.
