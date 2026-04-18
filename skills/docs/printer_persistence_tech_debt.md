# Printer Persistence Tech Debt

Follow `SYSTEM_OF_TRUTH.md` first.

This note tracks the printer persistence compatibility parser after the
first-class transport migration landed in schema v32.

## Current State

1. `printer_settings` now stores first-class transport columns:
   - `connection_type`
   - `ip_address`
   - `port`

2. Runtime write-path no longer writes `printercfg:v2:` metadata into
   `device_name`.

3. `device_name` is now user-visible text only.

4. The compatibility parser is still present for one reason only:
   deterministic recovery of pre-v32 rows or partially migrated/corrupted rows
   that may still be encountered in the field.

## Target Schema State

1. `printer_settings` stores transport data in first-class columns:
   - `connection_type`
   - `ip_address`
   - `port`
   - `device_name` remains user-visible text only

2. `device_name` must never carry structured transport metadata after the
   migration lands.

3. Runtime reads must resolve transport directly from DB columns, not from
   compatibility parsing heuristics.

## `device_address` Semantics After v32

1. For bluetooth rows, `device_address` remains the bluetooth MAC/address.

2. For ethernet rows created or rewritten by the v32 migration, `device_address`
   stores the host value that should also be mirrored in `ip_address`.

3. Ethernet runtime code must use `connection_type` plus
   `ip_address ?? device_address` and must not assume `device_address` is always
   a bluetooth identifier.

## Migration / Backfill Strategy

1. Add nullable transport columns in a forward-only schema migration.

2. Backfill existing rows in deterministic order:
   - valid `printercfg:v2:` envelope rows
   - legacy `ethernet|host|port` rows
   - legacy plain bluetooth rows
   - corrupted compatibility rows using the current parser heuristics as a
     one-time migration salvage path

3. After backfill, write-path must stop emitting the compatibility envelope and
   write only first-class columns.

4. Post-migration verification is not "telemetry".
   Use these concrete checks instead:
   - schema v32 migration history success entry visible in the Admin system
     migration history screen
   - migration/backfill test coverage passing in CI
   - manual verification query showing no active rows with null
     `connection_type`
   - manual verification query showing no rows whose `device_name` still starts
     with `printercfg:v2:`

## When The Compatibility Parser Can Be Deleted

1. No earlier than the first release after v32 has shipped to all supported
   runtime installs.

2. Before deletion, verification must show no remaining rows that depend on:
   - `device_name` compatibility envelopes
   - `ethernet|host|port` fallback reads
   - corrupted-envelope salvage heuristics

3. Required verification evidence:
   - Admin migration history shows the v32 migration completed successfully on
     the target install
   - `SELECT COUNT(*) FROM printer_settings WHERE connection_type IS NULL;`
     returns `0`
   - `SELECT COUNT(*) FROM printer_settings WHERE device_name LIKE 'printercfg:v2:%';`
     returns `0`

4. The repository read path resolves transport from schema columns only.

## Done Criteria

1. New installs create `printer_settings` with first-class transport columns.

2. Existing installs migrate without losing:
   - printer name
   - transport type
   - ethernet host
   - ethernet port

3. `device_name` stays plain user-editable text in all persisted rows.

4. Compatibility parser classes and tests can be deleted without losing any
   supported runtime behavior.

## Second-Stage Cleanup

1. Remove compatibility-envelope read fallback from repository/runtime paths
   after the post-v32 verification queries above return zero on supported
   installs and the Admin migration history shows successful v32 migration.

2. Delete compatibility parser tests that only exist for:
   - `printercfg:v2:` envelope decoding
   - `ethernet|host|port` legacy fallback parsing
   - corrupted-envelope salvage heuristics

3. Keep only first-class transport persistence tests that validate the migrated
   schema contract.

4. Tests to delete in that cleanup stage:
   - `test/domain/models/printer_settings_test.dart` cases that exist only for
     compatibility-envelope parsing and salvage behavior
   - `test/data/repositories/settings_repository_printer_test.dart` cases that
     assert legacy-envelope or corrupted-envelope fallback reads
