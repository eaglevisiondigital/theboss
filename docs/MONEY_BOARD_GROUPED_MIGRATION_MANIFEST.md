# Digital Money Board grouped checkout — local proposal manifest

Owner assignment: local implementation only, payment execution disabled. Starting branch `build/boss-platform-v1`; unchanged HEAD `4b20ba6fec9b0491c3bbcb57d1d56ca3787495b4`. Approved visual source: `dd18a443d22f35c64efb33ed481e9ac0e6207aff`.

Canonical Boss project `ilykgwgmxtrrikreacrz` remains at **119** migrations. These four files are **UNAPPLIED proposals**. An independently authorized exact release would make **123**. No historical migration is edited. No deployment, commit, push, PR change or processor activation is authorized by this manifest.

| Proposed source | SHA-256 |
| --- | --- |
| `20261009230001_money_board_grouped_core.sql` | `a4c7746c8fd29a1c43eb76a5e056afdbaf330de43428e19d34598d47e4f7a66f` |
| `20261009230002_money_board_cart_commands.sql` | `65d130ef36e8945f467eca36748020619c7ddcb0ea1ddf5bbfc60dff0bc70f2e` |
| `20261009230003_money_board_financial_lineage.sql` | `428c9d5d50b8d2a850cb08007e43e0eb47de9e048fedef2a8706409cd27960f5` |
| `20261009230004_money_board_projections.sql` | `2f8a30cc4aa114606fe0c7d497b4948697f01422ca530a2c69831b804499bab9` |

1. Core: closed cart/group/claim/correction/history tables, immutable provenance, policy revisions, unique claims, existing reservation protection and finite platform-only policy gateway.
2. Commands: exact current context, opaque hashed guest verifier, fixed sessions, authoritative items, atomic holds, replay receipts and one unpaid root intent/preparation.
3. Financial lineage: extend existing trusted Phase 7D/7E dispatch/success/correction contracts, freeze eligibility, protect unknown/ACH holds, claim all lines exactly once and preserve gift/Wallet recovery.
4. Projections: finite v2 board/progress/Spin reads; additive historical projection compatibility; no reinterpretation of historical gross.

The four proposal sources must be rehashed against this manifest before any release. The source inventory/checkpoint and validation report accompany this proposal. Production application requires a fresh Main Boss Chat instruction approving these exact tested bytes and the release/acceptance plan.

Payment execution is OFF. There is no payment collection, browser mark-paid command, actual provider submission, credential binding, real entitlement issuance or payout activation. Disposable trusted success/correction tests are financial contract validation, not live money movement.
