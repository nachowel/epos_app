# Supabase Sync Production Verification

This playbook verifies the deployed EPOS sync path against live Supabase infrastructure.

Scope split:
- Safe local/integration coverage: Flutter smoke tests under `test/data/sync/`
- Operational/manual coverage: deployed Supabase project, Edge Function, auth config, RLS, network path

Capture each live verification run in
`docs/ops/supabase_sync_verification_evidence_template.md`.

Before running the sync smoke below, make sure the latest secure function
revisions are deployed by following
`docs/ops/supabase_edge_function_deploy.md`.

## Preconditions

- Use a non-customer shift, cashier/admin user, and disposable validation order.
- Root `.env` exists and is loaded at startup
- `FEATURE_SYNC_ENABLED=true`
- `SYNC_MIRROR_WRITE_MODE=trusted_sync_boundary`
- `SUPABASE_URL` points at the target project over HTTPS
- `SUPABASE_ANON_KEY` is the publishable/anon key, not a service-role key
- `EPOS_INTERNAL_API_KEY` matches the deployed edge function secret
- The Edge Function `mirror-transaction-graph` is deployed in the same Supabase project
- The remote mirror tables exist and are reachable:
  - `transactions`
  - `transaction_lines`
  - `order_modifiers`
  - `payments`
- Debug logging is enabled on the app build used for verification:
  - `FEATURE_DEBUG_LOGGING=true`

## Safe verification flow

1. Open a fresh test shift with a known admin or cashier account.
2. Create one PAID order from the app:
   - at least one line
   - optionally one modifier
   - exactly one payment
3. Open the Admin Sync screen.
4. Confirm one root queue row appears first as `pending` or `processing`.
5. Wait for the worker to run or trigger `Retry all failed` if the item already failed.
6. Confirm the root queue row moves to `synced`.
7. Capture the root transaction UUID from the Admin Sync screen.

## Edge Function Deploy Verification

After deploying `mirror-transaction-graph` and
`owner-revenue-analytics`:

1. Open Admin Sync and confirm the latest runtime error is not
   `Invalid Token or Protected Header formatting`.
2. Create one new paid order and confirm sync can progress beyond the previous
   auth formatting failure.
3. Open Admin Analytics and confirm the revenue screen returns data or a clean
   empty-state instead of a function auth formatting failure.
4. If analytics is still denied, confirm the signed-in Supabase user has an
   active row in `public.analytics_access_map`. The publishable `apikey` alone
   is not sufficient for owner analytics access.

## Expected live result

For the same root transaction UUID:
- `transactions`: 1 row with the mirrored terminal status (`paid` or `cancelled`)
- `transaction_lines`: one row per local line with `transaction_uuid` pointing to the remote transaction UUID
- `order_modifiers`: one row per local modifier, or no row if the order had none
- `payments`: 1 row for `paid`, no row for `cancelled`

Expected write dependency order:
1. `transactions`
2. `transaction_lines`
3. `order_modifiers`
4. `payments`

## What to inspect on failure

In the app Admin Sync screen:
- root UUID
- failed table
- failure type
- retryable or non-retryable
- attempt count
- last attempt time
- human-readable message

In the local queue table:
- `sync_queue.status`
- `sync_queue.attempt_count`
- `sync_queue.last_attempt_at`
- `sync_queue.error_message`

In local logs:
- `sync_graph_failed`
- `sync_graph_max_retry_hit`
- `sync_graph_succeeded`

In Supabase:
- Edge Function logs for `mirror-transaction-graph`
- project logs for auth or permission rejection
- row state in the 4 mirror tables above

## Operational failure interpretation

- `failure_type=networkUnreachable`
  - App could not reach Supabase. Retry is usually safe.
- `failure_type=remoteServerError`
  - The trusted boundary or remote sink rejected the write at runtime. Check function logs and table constraints.
- `failure_type=validationFailure`
  - Payload/schema mismatch. Fix code or remote contract before retrying.
- `failure_type=authOrConfigFailure`
  - Build config, auth token, or function wiring is wrong.
- `failure_type=localGraphDrift`
  - The queued root snapshot no longer matches the current local terminal graph. Re-queue from the current local snapshot instead of forcing retry.

## Recommended live smoke cases

- PAID order with one line and one payment
- PAID order with two lines, one modifier subset, one payment
- CANCELLED order with no payment row expected
- Retry a transient failure once after connectivity is restored

## What this playbook does not prove

- It does not replace automated local smoke tests.
- It does not prove every RLS policy branch; it proves the deployed path used by the app build under the current environment.
- It does not prove long-running retry behavior under real packet loss or device sleep. That remains an operational soak exercise.
