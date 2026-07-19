---
type: Work Item
title: Map Peak List Selection Refresh Pipeline
parent: ../spec.md
---

## What to build

Refactor the `Map` peak-list selection path into a vertical Flutter slice that updates accepted control state immediately while moving membership-derived recomputation off the immediate tap path. `All Peaks` and specific peak-list drawer interactions must acknowledge the latest accepted selection first, then settle deferred peak filtering, `peak ownership ring` derivation, chip visibility, and related peak-list-dependent map content through a supersedable refresh pipeline that preserves the current settled selection, visibility, and labeling contract.

## Required context

- `lib/providers/map_provider.dart` already owns accepted `Map` peak-list selection state through `selectPeakList`, `togglePeakListSelection`, and `setAllPeaksSelected`. Keep immediate control-state updates inside that existing map-owned seam rather than introducing a second selection source of truth.
- `lib/providers/peak_list_selection_provider.dart` currently performs synchronous `PeakListRepository.getPeakListItemsForList(...)` reads inside `peakListSelectionSummaryProvider`, `mapMetadataFilterScopePeaksProvider`, `_activePeakListOwnersByPeakIdProvider`, and `_filterSpecificListPeaks`. Those are the primary hot-path consumers that need staged or cached refresh behavior.
- `lib/widgets/map_peak_lists_drawer.dart` already owns the `Map` `Peak Lists` drawer rows, `All Peaks` control, and pin interactions. Preserve current labels, row structure, and pin behavior while removing synchronous membership work from the immediate selection interaction path.
- `lib/services/peak_list_visibility.dart` already defines visible-region and `mixed-region peak list` applicability rules. Reuse that seam instead of redefining visibility semantics for deferred refreshes.
- Existing deterministic seams and coverage live in `test/widget/map_peak_list_selection_test.dart`, `test/widget/map_screen_rebuild_test.dart`, and related provider tests. Reuse in-memory repositories, provider overrides, and test-controlled completion seams rather than wall-clock assertions or live datasets.

## Acceptance criteria

- [x] Tapping `All Peaks` or a specific `Map` `Peak Lists` drawer row updates the newly accepted control state immediately without synchronously waiting for full membership-derived recomputation.
- [x] The immediate interaction path preserves current labels, selection rules, chip behavior, pin behavior, and visibility rules for the `Map` peak-list surfaces.
- [x] Membership-derived peak filtering, chip visibility reconciliation, `peak ownership ring` derivation, and related peak-list-dependent map content refresh after the immediate selection acknowledgment through an app-owned deferred pipeline.
- [x] Rapid consecutive `Map` peak-list selection changes follow `latest interaction wins`, and stale queued or in-flight membership-derived completions cannot overwrite a newer accepted selection state.
- [x] The implementation does not add new spinner copy, progress copy, or disabled-control contracts for `Map` peak-list selection unless a temporary correctness guard is proven strictly necessary.
- [x] Settled `Map` content after deferred refresh matches the latest accepted selection, including rendered peaks, app-bar chips, and any visible peak-list-dependent styling derived from the selection.
- [x] Deterministic provider or widget coverage proves rapid `All Peaks` and specific-list changes keep controls responsive and supersede stale deferred completions without relying on wall-clock latency assertions.
- [x] Automated coverage remains local and deterministic with fake repositories, provider overrides, and test seams only.

## Covers

- User Stories: 2, 4
- Requirements: 2-4, 6, 9-11
- Technical Decisions: 1-3, 5-6
- Testing Strategy: 2-5
- Interview Ledger: L1-L3, L6-L8

## Blocked by

None - ready to start
