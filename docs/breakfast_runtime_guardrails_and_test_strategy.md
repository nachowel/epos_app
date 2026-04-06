# Breakfast Runtime Guardrails And Test Strategy

## Authority Note

Follow `SYSTEM_OF_TRUTH.md` first.

This document does not define business rules.
It operationalizes the existing breakfast/menu-engine contract set into runtime guardrails and test hardening.

Authority chain for this document:

1. `SYSTEM_OF_TRUTH.md`
2. `docs/menu_product_role_contract.md`
3. `docs/set_breakfast_configuration_contract.md`
4. `docs/choice_group_mapping_contract.md`
5. `docs/menu_eligibility_enforcement_contract.md`
6. `docs/breakfast_domain_engine_contract.md`
7. `docs/breakfast_persistence_schema_hardening_contract.md`
8. `docs/breakfast_repository_service_integration_contract.md`
9. this document
10. `CLAUDE.md`
11. `schema.md`

## A. Runtime guardrails

### 1. Choice Pool Isolation

* name: Choice Pool Isolation
* layer: domain engine
* purpose: prevent choice-capable products from corrupting swap accounting
* exact rule: `product_modifiers(type='choice')` members and all classified choice rows must never enter or consume `pendingReplacementUnits`; required breakfast choice groups remain single-selection paths
* failure behavior: internal invariant failure; abort rebuild with a deterministic domain assertion failure
* where it should be enforced: `BreakfastRebuildEngine` during choice normalization and add-unit classification, plus domain tests

### 2. Requested State Purity

* name: Requested State Purity
* layer: service/domain boundary
* purpose: keep requested state as user intent only
* exact rule: requested state may contain only remove/add/choose intent fields; it must never contain or infer `free_swap`, `paid_swap`, `included_choice`, `extra_add`, or any persisted classification field
* failure behavior: internal invariant failure; reject edit before rebuild
* where it should be enforced: requested-state transformer, service preflight assertions, unit tests

### 3. Rebuild Engine Mandatory Write Path

* name: Rebuild Engine Mandatory Write Path
* layer: service
* purpose: ensure breakfast writes cannot bypass rebuild semantics
* exact rule: any breakfast edit that changes a breakfast line must call the rebuild engine with a valid requested state before any persistence write; repositories must never persist breakfast modifier changes directly from UI deltas or admin payloads
* failure behavior: repository assertion or service invariant failure; abort write safely
* where it should be enforced: `OrderService` edit entry points, service/integration tests

### 4. Repository Classification Immutability

* name: Repository Classification Immutability
* layer: repository
* purpose: prevent repositories from classifying modifiers
* exact rule: repositories must treat `action`, `charge_reason`, `item_product_id`, `quantity`, `unit_price_minor`, `price_effect_minor`, and `sort_key` as immutable rebuild-engine output; repositories must not derive, adjust, normalize, or reinterpret classification semantics
* failure behavior: repository assertion failure; rollback transaction
* where it should be enforced: breakfast snapshot repository, persistence mapper, repository tests

### 5. Single-Line Snapshot Scope

* name: Single-Line Snapshot Scope
* layer: repository
* purpose: prevent cross-line corruption during snapshot replacement
* exact rule: delete/insert replacement operations must target exactly one `transaction_line_id`; rows for sibling lines must remain untouched
* failure behavior: repository assertion failure; rollback transaction
* where it should be enforced: `replaceBreakfastLineSnapshot`, repository tests

### 6. Delete-Then-Insert Atomic Replace

* name: Delete-Then-Insert Atomic Replace
* layer: repository/transaction
* purpose: eliminate partial visibility and mixed snapshot states
* exact rule: replacement must execute as delete existing rows for the target line, then insert rebuilt rows, inside one DB transaction; no intermediate visible state may escape the transaction
* failure behavior: repository assertion failure or transactional rollback on write failure
* where it should be enforced: repository transaction wrapper, integration tests, rollback tests

### 7. Committed Snapshot Totals Recompute

* name: Committed Snapshot Totals Recompute
* layer: repository/service
* purpose: prevent stale or delta-based total drift
* exact rule: totals must be recomputed only from committed persisted snapshot rows; not from incremental deltas, not from stale cached totals, not from intermediate delete-before-insert state, and not from in-memory candidate rows that are not yet persisted
* failure behavior: repository assertion failure if recomputation source is invalid; rollback transaction if totals mismatch committed persisted state
* where it should be enforced: `transactionRepository.recalculateTotals`, post-write recomputation path, repository tests, service/integration tests

### 8. No Incremental Breakfast Patching

* name: No Incremental Breakfast Patching
* layer: service/repository
* purpose: preserve determinism and avoid inferred diff logic
* exact rule: breakfast edits must rebuild the full affected line from current requested state and replace the full persisted snapshot; patching individual classified rows in place is forbidden
* failure behavior: internal invariant failure; abort write
* where it should be enforced: service orchestration guard, repository API design, integration tests

### 9. Line Identity Before Merge

* name: Line Identity Before Merge
* layer: service/repository
* purpose: prevent accidental merge of non-identical breakfast lines
* exact rule: lines may merge only if all identity fields match: root product id, `pricing_mode`, full classified modifier snapshot (`action`, `charge_reason`, `item_product_id`, `quantity`, `unit_price_minor`, `price_effect_minor`, `sort_key`), and `line_total_minor`
* failure behavior: internal invariant failure or forced line split; stale merge attempt must not commit
* where it should be enforced: line merge/combine logic, service tests, regression tests

### 10. Sort Key Stability

* name: Sort Key Stability
* layer: domain/repository
* purpose: preserve rebuild ordering exactly
* exact rule: persisted `sort_key` values must match rebuild-engine output exactly and must round-trip unchanged through persistence mapping
* failure behavior: repository assertion failure; rollback transaction or fail test
* where it should be enforced: rebuild result serializer, snapshot repository, repository tests

### 11. Runtime Config Preflight

* name: Runtime Config Preflight
* layer: service/domain preflight
* purpose: block invalid or corrupted config that reaches rebuild time
* exact rule: rebuild input must use a config snapshot where set roots, set items, modifier groups, and choice members satisfy contract constraints; runtime preflight must still run even if admin/config validation is strong
* failure behavior: structured domain/config validation failure before classification
* where it should be enforced: config loader validation, service preflight, domain preflight tests

### 12. Compatibility Residue Isolation

* name: Compatibility Residue Isolation
* layer: repository/domain boundary
* purpose: prevent stale schema residue from becoming active behavior
* exact rule: `extra_price_minor` and broader schema-compatible allowances such as `removal_discount` must not drive active breakfast classification; runtime breakfast writes must explicitly populate semantic fields instead
* failure behavior: repository assertion failure or internal invariant failure; reject write
* where it should be enforced: serializer/deserializer assertions, repository tests, migration tests

### 13. Concurrent Edit Stale Snapshot Guard

* name: Concurrent Edit Stale Snapshot Guard
* layer: service/repository
* purpose: prevent two overlapping breakfast edits from committing against the same pre-edit snapshot
* exact rule: the later write must verify that the line snapshot it loaded is still current at commit time; optimistic lock, version check, row fingerprint, or equivalent stale-snapshot guard is acceptable, but both overlapping edits must not commit against the same pre-edit state
* failure behavior: stale edit attempt fails safely with a structured edit-conflict rejection or repository concurrency assertion; later/stale write must abort with no partial persistence
* where it should be enforced: service transaction boundary plus repository write precondition check, service/integration tests, regression tests

### 14. Serializer/Deserializer Semantic Round-Trip Safety

* name: Serializer/Deserializer Semantic Round-Trip Safety
* layer: repository
* purpose: ensure semantic breakfast fields survive persistence mapping without mutation
* exact rule: rebuild-engine output fields `action`, `charge_reason`, `item_product_id`, `quantity`, `unit_price_minor`, `price_effect_minor`, and `sort_key` must round-trip through persistence mapping exactly, byte-for-byte in meaning
* failure behavior: repository assertion failure; reject read/write path as semantically unsafe
* where it should be enforced: persistence mappers, repository tests, regression tests

## B. Repository assertions

1. Assert that every breakfast snapshot replace call targets one and only one `transaction_line_id`.
2. Assert that delete count and inserted rows belong only to the target line.
3. Assert that repositories never compute or rewrite `charge_reason`.
4. Assert that repositories never convert a choice row into swap semantics.
5. Assert that persisted breakfast writes include `unit_price_minor`, `price_effect_minor`, and `sort_key`.
6. Assert that repositories do not derive semantic totals from `extra_price_minor` for breakfast rows.
7. Assert that totals recomputation reads only committed persisted rows from storage.
8. Assert that totals recomputation does not use incremental deltas, stale cached totals, intermediate delete-before-insert state, or uncommitted candidate rows.
9. Assert that replace operations occur inside one DB transaction and rollback on any failure.
10. Assert that repositories do not merge lines unless full line identity matches.
11. Assert that no breakfast write path bypasses rebuild-engine-produced snapshot payloads.
12. Assert that `order_modifiers` rows for other lines remain unchanged after a single-line replace.
13. Assert that stale concurrent edit attempts fail before snapshot replacement.
14. Assert that persistence mapping round-trips `action`, `charge_reason`, `item_product_id`, `quantity`, `unit_price_minor`, `price_effect_minor`, and `sort_key` without mutation.

## C. Domain assertions

1. Choice-capable products never consume pending replacement units.
2. Swap matching uses only removed `set_items` units.
3. First `free_swap_limit` eligible matched replacements classify as `free_swap`; all later matched replacements classify as `paid_swap`.
4. Required breakfast groups reject explicit none and over-limit quantities.
5. Choice rows always use `action='choice'` and `charge_reason='included_choice'`.
6. Added choice-capable products never classify as `free_swap` or `paid_swap`.
7. Rebuild output is deterministic: identical input produces identical row ordering, quantities, totals, and metadata.
8. Remove-only state remains valid and reportable with zero price effect.
9. Fold/aggregation never merges rows across different `charge_reason` values.
10. Requested state contains only intent fields and never pre-classified semantics.
11. Mixed `toast/bread` split remains invalid.
12. Negative quantities and remove-over-default quantities remain invalid.
13. Root product matches a valid set-root config.
14. Classified output ordering remains stable by contract order and tie-breakers.
15. Domain engine rejects invalid config snapshots that reach runtime preflight.

## D. Admin/config validation

1. Reject any set-root that is not a normal sellable product in `Set Breakfast`.
2. Reject any set-root configured as its own `set_item`.
3. Reject any set-root configured as a choice member.
4. Reject any choice-capable product inserted into `set_items`.
5. Reject any `product_modifiers` choice member with missing `group_id`.
6. Reject any `product_modifiers` choice member with missing `item_product_id`.
7. Reject any choice member whose `item_product_id` does not resolve to a valid `products.id`.
8. Reject any choice group with zero valid members.
9. Reject any choice group where `min_select > max_select`.
10. Reject any choice group where `included_quantity > max_select`.
11. Reject any breakfast set root missing required `Tea or Coffee` and `Toast or Bread` groups.
12. Reject `Tea or Coffee` groups containing anything other than `tea` and `coffee`.
13. Reject `Toast or Bread` groups containing anything other than `toast` and `bread`.
14. Reject mixed component products inside choice groups.
15. Reject choice-capable products configured as swap-replacement candidates.
16. Reject cloned breakfast-only variants such as `Tea for set`.
17. Reject any config attempting to encode pricing semantics in `modifier_groups` or `product_modifiers(type='choice')`.
18. Reject duplicate `(product_id, item_product_id)` set-item mappings.
19. Reject non-`Set Breakfast` products configured with mandatory breakfast groups unless contract-expanded explicitly.
20. Reject inactive or missing real products referenced by choice mappings.
21. Reject invalid configuration before save/publish in admin/config flows.
22. Runtime preflight must still block invalid or corrupted config that somehow reaches rebuild time, even if admin/config validation is strong.

## E. Test strategy

### Unit tests

* purpose: prove pure domain behavior, requested-state purity, config preflight, and deterministic classification without persistence noise
* top-priority test cases:
  * identical rebuild input => identical output
  * remove-only state stays valid and reportable
  * required breakfast choices stay one-of-one and never become swap
  * third replacement = `paid_swap`
  * choice product never enters swap pool
  * choice-capable direct add remains `extra_add` after removals
  * `free_swap_limit` boundary is exact
  * requested state transform remains classification-free
  * invalid config snapshot is rejected at runtime preflight
  * `sort_key` generation remains stable for identical input

### Repository tests

* purpose: prove persistence semantics, serializer/deserializer safety, line scope, atomic replace behavior, and totals recomputation from committed persisted rows only
* top-priority test cases:
  * snapshot replacement is scoped to one line only
  * snapshot replacement rolls back on insert failure
  * delete-then-insert occurs in one transaction
  * totals recomputation uses committed persisted rows only
  * totals recomputation rejects incremental deltas, stale caches, intermediate delete state, and uncommitted candidate rows
  * serializer/deserializer round-trips `action`
  * serializer/deserializer round-trips `charge_reason`
  * serializer/deserializer round-trips `item_product_id`, `quantity`, `unit_price_minor`, `price_effect_minor`, and `sort_key`
  * repository does not use `extra_price_minor` for breakfast semantics
  * sibling line rows remain unchanged after target-line replacement

### Service/integration tests

* purpose: prove orchestration boundary, rebuild-from-scratch flow, rollback safety, stale-edit protection, and non-editable status handling
* top-priority test cases:
  * `OrderService` is the only breakfast edit entry point
  * every successful edit rebuilds from current requested state
  * invalid edit leaves no partial persisted state
  * `draft` editable, `sent/paid/cancelled` rejected
  * requested state is not inferred from classified snapshot rows without explicit reverse-mapping contract
  * required toast/bread persists as a single `included_choice` row
  * choice product never persists as swap
  * third replacement persists as `paid_swap`
  * overlapping breakfast edits detect stale snapshot and abort the later edit safely
  * persistence failure rolls back rows and totals

### Migration tests

* purpose: prove schema hardening safety, legacy compatibility, and semantic field availability after migration
* top-priority test cases:
  * migration adds `unit_price_minor`, `price_effect_minor`, and `sort_key`
  * legacy rows copy `extra_price_minor` into compatibility defaults without semantic reinterpretation
  * `charge_reason` enum keeps `removal_discount` but breakfast runtime subset stays strict
  * migrated rows remain readable by legacy paths
  * semantic breakfast writes after migration require explicit fields
  * rollback mapping preserves legacy behavior
  * migration does not touch unrelated lines or tables
  * semantic field round-trip remains stable after migration

### Regression tests

* purpose: catch silent-break patterns most likely to recur after refactors
* top-priority test cases:
  * repository shortcut cannot bypass rebuild engine
  * UI/request payload cannot preclassify breakfast modifiers
  * choice group misconfig is rejected before save/publish
  * corrupted config still fails runtime preflight if it reaches rebuild time
  * `extra_price_minor` misuse does not change breakfast totals
  * `sort_key` stability survives persistence round-trip
  * identical rebuild inputs produce identical snapshot rows and totals
  * merge denied when any semantic identity field differs
  * concurrent stale edit attempt fails without partial persistence
  * serializer/deserializer round-trip preserves all semantic breakfast fields

## F. Anti-regression priorities

1. Bug: choice product accidentally consumes replacement pool
   How to catch it: domain unit test for choice pool isolation plus runtime domain assertion on pending replacement consumption
2. Bug: repository derives `free_swap` or `paid_swap` from raw rows
   How to catch it: repository immutability assertions and repository test that classification fields cannot be rewritten
3. Bug: breakfast edit patches one modifier row instead of rebuilding whole line
   How to catch it: service integration test verifying full snapshot replacement and guard against incremental breakfast patching
4. Bug: snapshot replace deletes modifiers for other lines
   How to catch it: repository test on single-line scope plus sibling-row integrity assertions
5. Bug: totals recomputed from stale cache, delta math, or pre-commit state
   How to catch it: repository test that totals recompute from committed persisted rows only and rejects intermediate state sources
6. Bug: `extra_price_minor` leaks into active breakfast semantics
   How to catch it: repository and migration tests comparing semantic totals against `price_effect_minor`, not compatibility residue
7. Bug: required breakfast choice allows `None` or over-limit quantities
   How to catch it: domain, POS, and integration tests that reject required-group explicit none and quantity above `max_select`
8. Bug: third eligible replacement still classified as `free_swap`
   How to catch it: domain boundary test around `free_swap_limit` and persisted integration verification
9. Bug: merge logic collapses two non-identical breakfast lines
   How to catch it: repository/service tests asserting full line identity invariant across all semantic fields
10. Bug: overlapping stale breakfast edits both commit
    How to catch it: service/integration and regression tests with concurrent edit collision scenarios plus stale-snapshot guard assertion
