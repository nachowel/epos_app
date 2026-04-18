# Supabase Sync Verification Evidence Template

Use this checklist together with `docs/ops/supabase_sync_production_verification.md`.

## Verification Run

- Date/time:
- Operator:
- App build/version:
- Environment:
- Mirror write mode:
- Device:

## Test Transaction

- Root transaction UUID:
- Transaction status tested: `paid` / `cancelled`
- Expected line count:
- Expected modifier count:
- Expected payment count:

## Expected Remote Result

- `transactions`:
- `transaction_lines`:
- `order_modifiers`:
- `payments`:

## Observed Local State

- Queue status:
- Attempt count:
- Last attempt at:
- Last synced at:
- Error message:
- Failed table, if any:
- Failure type, if any:

## Observed Supabase Evidence

- Edge Function log reference:
- Table rows verified:
- Notes:

## Outcome

- Pass / Fail:
- Follow-up action owner:
- Follow-up action:
