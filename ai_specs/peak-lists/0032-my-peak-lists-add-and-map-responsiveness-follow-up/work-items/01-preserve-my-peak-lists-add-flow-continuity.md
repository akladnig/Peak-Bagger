---
type: Work Item
title: Preserve My Peak Lists Add-Flow Continuity
parent: ../spec.md
---

## What to build

Update the `My Peak Lists` `Add New Peak` flow so a successful in-place save keeps the same selected existing `PeakList` identity and selected title, closes the dialog immediately after save succeeds, refreshes through the existing deferred `My Peak Lists` summary path instead of forcing a synchronous full recompute, and automatically selects one of the newly added peaks by case-insensitive alphabetical stored `Peak.name`, then smaller `Peak.osmId` when names tie. Preserve the existing `0029` repository or persistence failure safety contract, keep peak-list import and export unchanged, and ensure this refresh-path rework does not reintroduce blocking `My Peak Lists` `Region FAB` behavior or stale deferred summary wins.

## Required context

- `lib/screens/peak_lists_screen.dart` already owns selected-list continuity, deferred summary scheduling, stale-work supersession, and the add-dialog success handoff. Keep this slice vertical through that existing screen seam unless a very small reusable seam is clearly justified.
- `lib/widgets/peak_list_peak_dialog.dart` already returns the successful add selection in deterministic save order and already sorts selected peaks by case-insensitive `name`, then smaller `osmId`. Preserve that exact ordering contract and keep `refreshPeakListSelectionOnAddSuccess: false` aligned with the screen-owned deferred refresh path.
- `lib/services/peak_list_repository.dart` and `test/services/peak_list_repository_test.dart` already carry the in-place membership-preservation and rollback-safety contract from `0029`. Extend that seam only where this follow-up changes behavior.
- Existing deterministic coverage and fake scheduler seams already live in `test/widget/peak_lists_screen_test.dart` and `lib/screens/peak_lists_screen.dart` through `peakListsSummaryRefreshSchedulerProvider`. Reuse those seams instead of adding wall-clock assertions or a second refresh mechanism.
- Preserve current `Region FAB` semantics from `lib/providers/peak_list_region_filter_provider.dart` and current `Peak list mini-map` behavior; this slice repairs add-flow continuity and refresh sequencing, not region-filter or mini-map redesign.

## Acceptance criteria

- [x] A successful `My Peak Lists` `Add New Peak` save keeps the selected existing `PeakList` identity and selected title, then closes the dialog immediately after the in-place save succeeds.
- [x] After a successful add, `My Peak Lists` refreshes through the existing deferred summary path rather than forcing a synchronous full recompute before dialog close, and the implementation does not add new loading copy, spinner copy, or disabled-control UI for this refresh.
- [x] After a successful add, `My Peak Lists` automatically switches peak selection to one of the newly added peaks using case-insensitive alphabetical stored `Peak.name`, then smaller `Peak.osmId` when names tie.
- [x] The newly selected peak row may appear when the deferred summary refresh settles, and the fix does not restore synchronous heavy recomputation only to make that row appear before the dialog closes.
- [x] Repository or persistence failure during `Add New Peak` leaves the selected list unchanged, preserves the current selected list identity, keeps the add dialog session open, preserves the in-progress selected peaks and entered points, and allows retry or cancel without rebuilding the current selection.
- [x] The add-flow rework preserves the repository-side in-place membership-preservation and rollback-safety fix from `0029`, does not restore name-based replacement behavior, and does not regress immediate accepted-state `Region FAB` feedback or stale deferred summary supersession on `PeakListsScreen`.
- [x] Deterministic repository and widget regression coverage proves add success, add failure, deferred refresh continuity, deterministic post-save peak selection, and stale-work supersession without relying on fragile wall-clock latency assertions.
- [ ] Final manual verification is performed against the existing real migrated local post-`0024` data that previously reproduced the slowdown, rechecking `My Peak Lists` `Add New Peak` success and failure behavior, automatic post-save selection of the first newly added peak by the agreed ordering rule, and `My Peak Lists` `Region FAB` responsiveness.

## Covers

- User Stories: 1-2
- Requirements: 1, 3-9
- Technical Decisions: 1-3, 5
- Testing Strategy: 1-4, 6-8
- Interview Ledger: L1-L7

## Blocked by

None - ready to start
