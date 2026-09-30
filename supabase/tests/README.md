# Phase 2A database tests

Run from the repository root with PostgreSQL 17 binaries installed:

```sh
PG_BINDIR=/opt/homebrew/opt/postgresql@17/bin bash supabase/tests/run-local.sh
```

On Linux, set `PG_BINDIR` to the PostgreSQL 17 bin directory, for example
`/usr/lib/postgresql/17/bin`. If unset, the runner uses `pg_config --bindir`.
Run as an unprivileged operating-system user. No database URL, password,
Supabase key, Docker daemon or network service is required.

The runner initializes a fresh cluster under a private temporary directory,
binds only a Unix socket with permissions `0700`, rejects host connections,
applies every canonical migration in order and runs the Phase 2A SQL tests.
It then runs the hierarchy concurrency helper against that same disposable
cluster. The helper coordinates two independent sessions and removes its local
synthetic hierarchy records after the checks.
It fails on the first SQL error, stops PostgreSQL and removes the cluster on
completion or interruption. If shutdown fails, it preserves the temporary
directory and reports failure instead of removing an active data directory.
Transactional fixtures roll back; the runner never connects to
the canonical hosted project. No fixtures belong in production migrations.

Repetitive assertion output is captured in the private temporary directory.
The runner displays the assertion count, category totals and fixture cleanup
result produced by SQL; SQL errors remain visible on stderr. It does not hard-code
a passing count. The final fresh-cluster run passed 911 SQL assertions: 642
across categories A–P and 269 in `phase2a_live_verification.sql`. Its three
coordinated hierarchy checks also passed:
READ COMMITTED rejected the unsafe edit with `23514`; REPEATABLE READ and
SERIALIZABLE rejected it with `40001`. No cycle formed. The run verified
transactional fixture rollback and cluster removal; the concurrency helper also
verified removal of its committed local fixtures. Hosted and CI evidence is
recorded separately in
[CURRENT_BUILD_STATE.md](../../docs/CURRENT_BUILD_STATE.md).

The live-verification SQL creates no schema objects. Its synthetic DML fixtures,
Data API role assertions and request claims are transactional, and it verifies
fixture removal after rollback. After authorized canonical migration application,
it separately passed 269 assertions against the Boss project and verified zero
remaining synthetic fixtures. The local runner still never connects remotely;
remote execution belongs to the separately authorized canonical verification
workflow.

`local-bootstrap.sql` supplies the minimal managed Supabase surfaces used by
the migrations and fixtures: the `auth.users` UUID primary key, non-secret
fixture fields, `auth.uid()`/`auth.jwt()` request-claim lookup, `anon`/`authenticated` roles
without RLS bypass, and the explicitly privileged `service_role` role. It also
reproduces the previously audited broad public defaults so grant hardening is
tested against an unsafe starting ACL. Bootstrap execution uses a separate local
cluster administrator. Migration and fixture execution use a `postgres` role
with RLS bypass and role creation privileges, but without superuser access,
matching the relevant managed-project privilege boundary. Authorization
assertions switch to actual Data API roles.

This is a PostgreSQL constraint, privilege and RLS test environment. It does not
emulate hosted Auth, JWT signature verification, PostgREST routing, session
cookies, Storage or managed extensions. Canonical project migration verification,
advisors and separately documented hosted checks complement these tests.
Never apply the local bootstrap to a managed project.

`auth.uid()` semantics and relevant Auth columns/role attributes were verified
read-only against the canonical project before implementation. Official references:

- [Supabase database testing](https://supabase.com/docs/guides/local-development/testing/overview)
- [Auth uid claim lookup](https://github.com/supabase/auth/blob/master/migrations/20211202183645_update_auth_uid.up.sql)
- [Supabase database roles](https://supabase.com/docs/guides/database/postgres/roles)

Canonical migration files were created with the checksum-verified official
Supabase CLI `2.118.0` using `supabase migration new <name>`.
The MCP migration API assigned server-side versions during canonical application.
The uncommitted CLI-created files were renamed to those observed versions so
repository and live migration history agree. SQL bodies remained byte-identical;
no remote history repair or duplicate migration was used.

| Applied version | Migration name |
| --- | --- |
| `20260930212353` | `phase2a_grant_hardening` |
| `20260930212410` | `phase2a_identity_organizations` |
| `20260930212417` | `phase2a_relationships_access_governance` |
| `20260930212421` | `phase2a_integrity` |
| `20260930212426` | `phase2a_authorization_rls` |
| `20260930212430` | `phase2a_catalog_seeds` |

The CLI is not a runtime dependency and no CLI access token is required to
create migration files or run these local SQL tests.
