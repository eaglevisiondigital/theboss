# Boss platform foundation

Independent Next.js App Router shell. Phase 1A adds authentication plumbing only;
no business schema or product module exists. Root website files and feature
branches are not moved or modified.

## Local setup

Use Node `24.20.0` and npm 11 from this package directory:

```sh
npm ci --ignore-scripts
cp .env.example .env.local
# Supply the canonical project's authorized publishable key in .env.local.
npm run check:env
npm run dev
```

The example key is a placeholder and intentionally fails validation. Do not
commit `.env.local`. Required configuration is
`NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`; no server
secret is required. The URL must identify the dedicated Boss project. Both
variables must be available for the build and server runtime, and changing
public values requires a rebuild. Never introduce privileged browser variables.

`dev` validates development configuration. `build`, `start` and `check:env`
validate production configuration; explicit test mode uses `.env.test`. A
working development file must not mask missing production configuration. The
validator loads Next.js environment files and prints safe configuration errors.

## Routes and behavior

| Route | Behavior |
| --- | --- |
| `/` | Public text-branded foundation landing. |
| `/login` | Password login entry; no signup/OAuth or provider setup. |
| `/app` | Authenticated Home shell. |
| `/app/account` | Authenticated account placeholder; no profile mutation or business permissions. |
| `/auth/login` | Same-origin POST password sign-in; safe local redirect. |
| `/auth/logout` | Same-origin POST local-browser sign-out. |
| `/health` | Local configuration readiness: 200 or 503, without upstream calls. |

Session refresh runs in `src/proxy.ts`. Protected layouts and pages independently
verify identity. Authentication returns only a subject; role, relationship and
entitlement authorization will follow approved architecture. Supabase clients
use publishable configuration, never privileged access.

## Validation

```sh
npm run typecheck
npm run lint
npm test
npm run build
# Or npm run validate with authorized configuration available.
```

ESLint 10 uses explicit supported TypeScript and Next.js plugins rather than
the current `eslint-config-next` dependency bundle, whose React/import plugins
are incompatible with ESLint 10. Tests use Node's built-in runner and tsx import
support; no test framework or fake product behavior is added. Exact packages and
transitive dependencies are recorded in `package-lock.json`.

Offline validation may use synthetic publishable-key fixtures; those establish
compilation/guard behavior only and must not be deployed as real configuration.
No test should submit real credentials, create users or mutate the backend.

## Deployment and assets

The `thebossplatform` site's base is `apps/platform`; its nested config builds
this package and publishes `.next`. Builds are held and previews disabled until
authorized configuration and preview/Auth settings are ready. Nothing is hosted
from this shell yet. See `../../docs/PHASE_1A_NETLIFY.md`.

Branding is plain text and fonts are system fonts because approved artwork/font
assets are absent from the selected main baseline. No logo or draft website
asset was copied. Security coverage and remaining requirements are documented
in `../../docs/SECURITY_MODEL.md`; current evidence is in
`../../docs/CURRENT_BUILD_STATE.md`. Private source handoffs remain outside this
public repository as described in `../../docs/SOURCE_PROVENANCE.md`.
