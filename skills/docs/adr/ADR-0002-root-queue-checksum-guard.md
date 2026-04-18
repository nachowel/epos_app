# ADR-0002 Root Queue Checksum Guard

## Status

Accepted

## Context

The sync queue is intentionally root-only. Each queue row represents a transaction root event, and the worker rebuilds child rows from local Drift state at execution time.

That keeps queue cardinality low, but it introduces one sharp edge: if the local terminal graph mutates after enqueue and before retry, replaying the old root event can silently mirror the wrong graph.

## Decision

Store a checksum snapshot for each queued root transaction event in a sidecar table:
- table: `sync_queue_root_graph_snapshots`
- key: `queue_id`
- value: deterministic SHA-256 checksum of the canonical transaction graph

Worker behavior:
- rebuild the current terminal graph from Drift
- recompute the checksum
- compare it with the original root snapshot
- if the checksum differs, fail the queue item as `localGraphDrift` before any remote write

## Checksum scope

Included:
- transaction root payload
- transaction lines payloads
- order modifiers payloads
- payment payload
- canonical record order
- root transaction idempotency key

Excluded:
- local integer primary keys that never leave the local DB as remote identity
- queue metadata such as attempt count, timestamps, status
- transient runtime metadata such as last attempt time or generated-at timestamps

## Consequences

Benefits:
- corrupted or mutated retries stop before remote write
- operator sees an explicit non-retryable drift failure instead of a misleading remote error
- legitimate retry of the same terminal graph stays valid

Tradeoffs:
- legitimate post-terminal mutation requires a fresh root queue event
- old failed root rows may be superseded by a newer queued root snapshot for the same transaction
- this does not remove the need for live Supabase operational verification

## What this does not solve

- live Edge Function deployment drift
- RLS/auth misconfiguration in the target Supabase project
- device/network behavior under long offline windows
