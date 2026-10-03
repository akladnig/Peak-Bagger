---
type: Work Item
title: Coordinate Mapping Failures and Ready Bootstrap
parent: ../spec.md
---

## What to build

Implement the reusable typed Mapping-store operation failure coordinator and dialog host, plus the single ready-scope bootstrap coordinator. It owns single-flight execution, FIFO failure queueing, retry dispatch, and per-ObjectBox-table write serialization for all post-ready Mapping operations.

## Required context

- Extend Riverpod patterns in `lib/providers/route_graph_readiness_provider.dart` and `lib/providers/map_provider.dart`; do not add unowned global controllers, timers, or fallback state.
- The failure model carries immutable operation identity/key, affected store-relative paths, canonical original parameters, and retry action. It must revalidate a path immediately before every external open.

## Acceptance criteria

- [x] Support exactly peak seed, manual peak update, TasMap bootstrap, TasMap update, Natural Features bootstrap, Natural Features refresh, route-graph bootstrap, route-graph refresh, DEM read, and polygon display operation kinds with the specified canonical operation parameters.
- [x] Expose one app-level dialog with `mapping-store-failure-dialog`, `mapping-store-failure-operation`, `mapping-store-failure-path-list`, `mapping-store-failure-retry`, and `mapping-store-failure-dismiss`. Distinct failures queue FIFO; equal active/queued keys coalesce; dismiss or successful retry immediately advances the queue; a failed retry updates one active entry.
- [x] A duplicate pending operation returns the original future, schedules no second read/transaction/failure entry, and a retry while pending joins it. Peak regions and routing coverages may proceed independently; writers to the same ObjectBox table never overlap.
- [x] Start peak seeding, TasMap bootstrap, Natural Features bootstrap, and per-coverage route-graph bootstrap only after ready scope and router exist, once per conditional operation. A no-op bootstrap must not read source content.
- [x] A mid-session failure preserves all loaded UI/ObjectBox state and leaves the initiating feature unavailable, never silently empty. Each later feature Work Item supplies its exact stable unavailable keys and retry behavior through this coordinator.
- [x] Provider/service tests cover typed context, FIFO/coalescing, retry parameters, single-flight behavior, concurrent independent operations, serialized writers, retained prior state, and ready-scope one-time bootstrap scheduling.

## Covers

- User Stories: 1, 2
- Requirements: 11, 24-26, 30
- Technical Decisions: 4, 7, 9-11, 16
- Testing Strategy: 3, 6-7, 10-11, 15
- Interview Ledger: L5

## Blocked by
03-macos-startup-shell-and-ready-scope.md
