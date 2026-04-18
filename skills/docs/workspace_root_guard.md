# Workspace Root Guard

- Authoritative Flutter app root: `C:\Users\nacho\Desktop\EPOS\epos_app`
- The parent workspace root `C:\Users\nacho\Desktop\EPOS` is non-authoritative for app changes.
- Future code changes, tests, analysis, database migrations, and Supabase/schema work must target `epos_app` only.
- If another Flutter root is detected in this workspace, treat it as stale or duplicate unless explicit approval is given to work there.
