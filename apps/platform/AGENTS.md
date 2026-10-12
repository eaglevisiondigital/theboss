# Boss platform shell

Read `../../docs/SOURCE_PROVENANCE.md` and `../../docs/CURRENT_BUILD_STATE.md`
before major work. Source handoffs remain private in the implementation workspace;
do not copy them into this public repository. Main Boss Chat owns product/data
architecture, permissions and financial business rules.

Phase 1A authorizes only this independent Next.js/Supabase technical shell.
Preserve public website branches, PRs and deployments. Do not add business
tables, real users, privileged credentials, modules or production settings
without the corresponding approved assignment. Authentication does not grant
business authorization. No user-editable metadata may authorize operations.

Use strict TypeScript, exact dependency pins and the package lockfile. Run
typecheck, noninteractive lint, tests and build for relevant changes. Public
environment variables contain only the Supabase URL and publishable key. Never
introduce browser privileged credentials. Boss-facing text uses text branding
until approved assets are supplied and contains no em dashes.

For Next.js APIs, read the version-matched bundled documentation in
`node_modules/next/dist/docs/` after installing dependencies. In Next.js 16,
request APIs are asynchronous and session refresh uses `src/proxy.ts`.

End major work with a concise report for main Boss Chat, distinguishing verified,
implemented, planned and unresolved decisions. Stop at the assigned phase.
