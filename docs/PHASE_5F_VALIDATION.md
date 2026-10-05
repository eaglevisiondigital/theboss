# Phase 5F validation

Status: full local validation and canonical migrations verified; deployment/hosted gates pending.
Starting SHA `8749f2df4bce553e7ca2a386532ef813655c4a86`.

Fresh disposable PostgreSQL 17 runs use a private Unix socket, synthetic fixtures
and automatic cluster removal. No production data or credentials are used.

| Diamond suite | Assertions |
|---|---:|
| Commands, immutable seals, transfer/history privacy | 17 |
| Coverage and corrections | 10 |
| Structural/ACL verification | 49 |
| Realistic bounded performance | 3 |
| Pure reducer equivalents | 14 |
| Versioned rule profiles | 13 |
| Scope, wrong sport, receipts, protected tables | 22 |
| Total | 128 |

15 genuine coordinated two-connection races passed: simultaneous pitches,
pitch/PA, simultaneous PA, PA/runner, third out/half transition, play/final,
final/late play, pitcher/new pitch, substitution, correction/play, duplicate
receipt, profile/pitch, operator revocation, operator expiry, feature disable.
Actual lock waits synchronize participants; expiry and post-wait authorization
are tested. The full historical run passed 13,428 SQL/bootstrap assertions and 153 genuine races.
Totals are summed from the final per-suite assertion tables, including category
rows; new closed tables also expand earlier whole-schema privilege checks. Historical subset inventories
exclude the five new closed tables and eight new sport flags; former unsupported
Baseball fixtures now use unsupported Tennis. No earlier migration body changed.

Typecheck, zero-warning lint, 372/372 application tests and production build
passed with synthetic public build-format values. Canonical types regenerated from the validated 56-migration schema; final
application rerun uses those types. Actual local rendered 1280/768/390/320 console
widths equal page scroll widths; Quick Actions are at least 64px tall. This is
LOCAL evidence, not hosted viewport proof.

All four migrations applied to canonical Boss Supabase. Live read-only structural
verification passed 49 checks; history has 56 entries. Filenames align to canonical
application timestamps with contents unchanged. Security advisors: intentional
closed RLS INFO 96 and existing leaked-password-protection WARN 1. Performance:
unused-index INFO 177, existing Auth absolute-allocation INFO 1; no new missing
FK index finding. No Auth setting or timeout changed. Deployment, temporary
acceptance authority and hosted Diamond results are pending at this checkpoint. The fixed hosted plan and
independent literal score/stat oracle are prepared separately.
