# Phase 7B performance

Disposable fixture: 5,000 trusted synthetic source contributions/ledger grants and
5,000 unrelated household wallets. Final focused measurements: family read
65.583 ms, organization report 143.148 ms, reconstruction 10.640 ms, family JSON
29,573 bytes. Earlier controlled run: 103.339/132.953/9.410 ms. These are local
measurements, not a national-load or production latency guarantee.

Family selects an indexed explicit-access cohort (maximum 20 currency wallets),
then current guardian/household/module fences. Activity is 50-row tuple cursor
paging; organization family slices use 100-wallet cursors. Child/campaign/source
choice breakdowns are bounded. Totals derive from indexed immutable postings and
current availability/expiry, never a mutable authoritative cache. Organization
reports query only their tenant. Reconstruction uses the wallet fence and equals
fresh balances. Eight-second limits, JIT configuration and provider infrastructure
are unchanged. Historical timeout/remediation records remain intact.
