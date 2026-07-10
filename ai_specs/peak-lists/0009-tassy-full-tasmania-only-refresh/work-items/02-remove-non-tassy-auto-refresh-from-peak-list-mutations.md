---
type: Work Item
title: Remove Non-Tassy Auto-Refresh From Peak List Mutations
parent: ../spec.md
---

## What to build

Remove the best-effort automatic `Tassy Full` refresh that currently runs as a side effect of non-`Tassy Full` peak-list mutations. This includes add, update, import, save, and delete flows for source lists. Those source-list mutations must still complete successfully without mutating `Tassy Full`, and removing the auto-refresh must not remove the existing peak-list revision invalidation or active-selection reconciliation required for the source-list UI to reflect successful mutations. Keep the explicit Settings action as the only repository-driven refresh entry point for `Tassy Full`.

## Required context

- `lib/providers/peak_list_provider.dart` currently wraps the repository with `_AutoRefreshingPeakListRepository`; that wrapper is the main behavior to remove or collapse while preserving the surrounding Riverpod update pattern.
- `peakListImportServiceProvider` and `peakListImportRunnerProvider` in the same file show the existing revision/selection update conventions that still need to happen after successful source-list mutations.
- Current regression coverage for the auto-refresh side effect is in `test/providers/peak_list_mutation_provider_test.dart`; at least one replacement test should prove that a source mutation still updates provider-facing UI state even though `Tassy Full` is no longer refreshed.
- Align with the existing repository and provider boundaries instead of introducing a second opt-out path or a new peak-list state model.

## Acceptance criteria

- [ ] Non-`Tassy Full` peak-list mutation paths no longer trigger a best-effort `Tassy Full` refresh as a side effect, including add, update, import, save, and delete flows.
- [ ] Those source-list mutation paths still complete successfully without mutating `Tassy Full`.
- [ ] Removing the auto-refresh does not remove the existing peak-list revision invalidation or active-selection reconciliation needed for the source-list UI to reflect successful mutations.
- [ ] The explicit Settings action remains the only repository-driven refresh entry point for `Tassy Full`.
- [ ] Provider-level regression coverage proves that non-`Tassy Full` list mutations no longer refresh `Tassy Full`, while the source mutation itself still succeeds and still performs the required revision or selection updates for that source flow.
- [ ] Provider-level regression coverage includes at least one flow that previously depended on the auto-refresh wrapper for list invalidation rather than only for `Tassy Full` mutation.

## Covers

- User Stories: 3
- Requirements: 1-2
- Technical Decisions: 2, 4
- Testing Strategy: 1, 3
- Interview Ledger: L1

## Blocked by

None - ready to start
