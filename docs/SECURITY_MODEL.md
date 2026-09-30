# Platform shell security

Technical foundation through Phase 1B hosted validation. This document is not a final authorization
matrix or a production-readiness certification. No business table, policy,
privileged credential was added. One owner-supplied controlled Auth identity was
used for hosted acceptance; no customer or business record was created.

## Implemented

- Public configuration accepts the canonical Boss HTTPS Supabase endpoint and
  a modern publishable-key format, rejecting missing, placeholder, legacy JWT
  and privileged-key input. Diagnostics identify configuration names without
  printing supplied values. Format checks cannot prove a key's project pairing.
- Server-only environment, session and server/route client modules use the
  `server-only` boundary. Browser code reads only the explicit public URL/key.
  No server secret is required or implemented in this phase.
- Supabase `getClaims()` verifies the session; additional checks validate subject,
  canonical issuer, role, expiry and non-anonymous identity. Only a subject is
  returned. User metadata grants no access. Proxy plus protected layouts/pages
  each enforce authentication, failing closed to the login route.
- SSR adapters propagate refreshed cookies through redirects and forbid shared
  caching using private/no-store and CDN-specific response headers. Cookies use
  SameSite Lax and Secure on HTTPS. Browser-readable cookies follow Supabase's
  browser/SSR design; they are not presented as HttpOnly cookies.
- Password login and local-browser logout use POST only, require an explicit
  matching server-approved Origin and non-forwarded Host, check fetch-site metadata
  when provided, and return generic
  errors. Login input is bounded and duplicate credentials rejected. Redirect
  targets stay within local `/app` paths. No signup, OAuth, recovery or callback
  workflow is enabled by this shell.
- Production requires server-only, non-secret `BOSS_PLATFORM_ORIGIN`. It fixes
  the observed hosted POST rejection while controlling redirect destinations and
  Secure cookies. Arbitrary forwarding headers do not determine these decisions.
  A shared header policy is applied directly to early proxy responses because
  hosted redirects otherwise bypassed the framework's configured headers.
- All surfaces are noindex. Security headers enforce frame denial, CSP
  frame-ancestors/base/form/object restrictions, MIME sniffing prevention,
  referrer policy, limited browser capabilities and HTTPS HSTS. A stricter
  script CSP is report-only because Next hydration uses inline scripts; an
  enforced nonce/hash design requires later hosted validation. No report
  collector or telemetry backend is invented here.
- `/health` reports local configuration readiness only. It returns no keys,
  settings or user details and makes no upstream service request. UI errors
  disclose no provider messages, stack traces or configuration values.

## Known limits and required operational checks

Supabase claim verification does not guarantee immediate server-side session
revocation detection. Sensitive future operations require current session/user
checks, relationship and entitlement checks and reviewed database policies.
Logout affects the current browser only; cross-device policy is not settled.
No business action is authorized merely by reaching this shell.

Required public configuration is provisioned for the dedicated platform's
production context, builds are active and previews remain disabled. The canonical
publishable key successfully retrieves public Auth settings; no privileged key
was fetched. Hosted public routes and unauthenticated guards were tested. Initial
POST-origin and redirect-header defects are fixed and all 25 hosted HTTP retests
passed. Invalid-session cookie cleanup was observed with Secure/SameSite Lax and
no Domain, and anonymous auth responses had private/CDN no-store instructions.
The subsequent controlled-account test passed valid login, authenticated SSR
Home/Account, navigation/reload/fresh server requests, natural-expiry server
refresh with rotation and persistent renewed-session state, authenticated POST
logout and post-logout guards. Anonymous-after-auth requests did not receive
protected content. Password entry stayed with the human, and no token/session
value was captured. Private Auth settings were reviewed without changes.

Direct valid-session cookie attributes and authenticated response cache/CDN
headers remain unverified because the browser tools expose no inspection API.
Functional session persistence and prior invalid-session cookie/cache observations
are not a substitute. No debug endpoint or security-policy weakening was used.
No staging backend or custom platform domain was created. Server credentials must
never be put in `NEXT_PUBLIC_` variables or untrusted preview contexts. Auth email
redirect/SMTP/account-security defaults and public build-log policy still need
operational review before launch. The current account-security advisor finding
was left unchanged pending that review.

This shell does not add custom abuse/rate-limiting infrastructure or account
enumeration telemetry. Review upstream Auth rate limits and operational abuse
controls before enabling authentication. It does not certify recovery, backup,
incident response, access logging or production availability.

## Future requirements, not implemented

Approved data-model work must establish RLS and explicit least-privilege grants,
deny-by-default organization/team/household/merchant isolation, minor privacy,
private Storage policies, scoped roles, verified relationships and entitlements.
Authentication and hidden UI controls cannot replace those protections. Review
default grants before creating any exposed table or privileged function.
The Phase 1B read-only audit found broad default public privileges but no business
relations. Those defaults do not establish deny-by-default security for future tables.

Audit logs, webhook signature verification, financial idempotency, ledger
integrity, reversal behavior and transactional unique Money Board claims require
their approved module assignments and meaningful concurrency/authorization tests.
No policy SQL, canonical schema or business behavior is implemented here.

Implementation references: [Supabase SSR](https://supabase.com/docs/guides/auth/server-side/creating-a-client),
[Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys),
[Next.js CSP](https://nextjs.org/docs/app/guides/content-security-policy).
