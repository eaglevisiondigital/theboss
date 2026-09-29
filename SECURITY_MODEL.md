# Security Model

The initial marketing site is public and contains no authentication.

## Form rules
- Never place private API/service keys in browser code.
- Validate and sanitize submissions server-side.
- Add abuse/rate limiting before production.
- Capture only data needed for the declared lead workflow.
- Do not expose internal sales routing or allocation logic publicly.

## Future authenticated expansion
Use Supabase Auth and RLS with strict organization/user isolation. Sensitive uploaded documents must never be public-bucket assets.
