---
type: Work Item
title: Coordinate Coverage Bootstrap and Settings Refresh
parent: ../spec.md
---

## What to build

Implement an app-owned coordinator that serializes multi-coverage bootstrap and Refresh Route Graph batches, imports Tasmania before Northeast Alps, and exposes injectable per-coverage state and completion events through Riverpod. Update manifest-resolved import, store, bootstrap, readiness, and Settings refresh contracts to retain independent serving readiness and return tagged batch results.

Deliver Settings refresh behavior and dialogs for all-success, partial, all-failed, and configuration-error outcomes without allowing a failed or loading coverage to disable another coverage's ready graph.

## Required context

- Preserve Riverpod patterns in `lib/providers/route_graph_readiness_provider.dart`, startup wiring in `lib/app.dart` and `lib/main.dart`, and Settings keys and confirmation flow in `lib/screens/settings_screen.dart`.
- Extend the existing injected `RouteGraphImportService`, `RouteGraphStore`, and `RouteGraphRefreshService` boundaries rather than adding unowned controllers, streams, or timers.
- Existing widget and robot seams use provider overrides, fakes, and completers. Preserve Settings keys in `test/robot/settings/route_graph_refresh_robot.dart` and `test/widget/route_graph_refresh_settings_test.dart`.

## Acceptance criteria

- [x] The schema version is exactly `route-graph-v5`. After successful definition resolution, bootstrap and refresh process coverage definitions sequentially in declared order, attempt every coverage after a coverage-scoped load, decode, validation, preparation, or persistence failure, and return the same ordered per-coverage outcome list.
- [x] A successful hash/schema match returns `refreshed`, reports the active generation element count, and creates no generation. A candidate with no prepared chunks or no accepted route-graph ways fails before activation.
- [x] A manifest-resolution failure is a typed tagged batch configuration failure with one sanitized message: it starts no imports, returns no per-coverage outcomes, and leaves active generations, serving readiness, import states, and unavailable footprints unchanged. Bootstrap records/exposes it without a modal.
- [x] Each coverage's import state is exactly `queued`, `importing`, `ready`, or `failed`, separate from active-generation serving readiness. After definitions resolve, create or retain unavailable footprints and mark only coverages without an active generation `queued`; transition imports in definition order. A coverage with an active generation remains usable while queued, importing, or failed.
- [x] All callers join one queued or running app-owned batch. A confirmed Settings refresh during bootstrap joins that exact bootstrap result without a post-bootstrap refresh; a cancelled confirmation creates no request; a batch continues after Settings disposal; only its still-mounted initiating Settings screen shows one completion dialog.
- [x] Completed outcomes contain `routingCoverageKey`, canonical `displayName`, `refreshed` or `failed` status, successful element counts, and sanitized failure diagnostics. Outcome and `<names>` ordering is definition order, with names joined by `, `.
- [x] Settings renders exactly `Route Graph Refreshed` with body `Refreshed: <names>.` for all success; exactly `Route Graph Refresh Partially Completed` with `Refreshed: <names>.` and `Failed: <names>.` body lines for mixed results; exactly `Route Graph Refresh Failed` with body `Failed: <names>.` for all failure; and exactly `Route Graph Configuration Error` with body `Route graph configuration is invalid. Refresh did not start.` for a configuration failure. Per-coverage error details never render in result dialogs.
- [x] Test first with deterministic, injectable holds/completions for an individual coverage import, covering sequential non-overlap, continued batches after individual failures, reuse, configuration failures, bootstrap/refresh joining, cancellation, disposed Settings initiators, coverage-order name joining, independent readiness, retained valid generations, and all exact dialog text.

## Covers

- User Stories: 3-5
- Requirements: 3, 4, 8
- Contract Clarifications: 1-3, 7
- Technical Decisions: 3, 5, 6
- Testing Strategy: 1, 2, 4-7
- Interview Ledger: L3, L5, L8, L9, L10

## Blocked by

01-routing-coverage-manifest-and-import-inputs.md
02-coverage-graph-persistence-and-selection.md
