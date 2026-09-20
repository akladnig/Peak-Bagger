---
type: Work Item
title: Decouple Map Metadata Filtering
parent: ../spec.md
---

## What to build

Move `Map metadata filter` ownership out of `MapState` into a dedicated app-scoped, non-persistent Riverpod Peak List details provider. The provider owns popup visibility and the existing `Rating`, `Difficulty`, and `Duration` selections, including the active-filter count that labels the control `Filter`, `1 Filter`, `2 Filters`, or `3 Filters`.

Remove the Map app-bar `Filter` trigger, its trailing divider, the Map-owned `MapMetadataFilterPopup`, and metadata filtering of map markers. Preserve the separate Map `Search popup` behavior. Reuse the existing filter enums, matching rules, option builder, popup widget, and active-filter-count contract; do not duplicate metadata rules, persist selections across app restarts, or add a network, service, persistence, credential, or API boundary.

## Required context

- `lib/providers/map_provider.dart` currently owns metadata popup visibility and all three selections; remove only this metadata-filter responsibility without disturbing map and `Search popup` state.
- `lib/providers/peak_list_selection_provider.dart` currently exposes `filteredPeaksProvider` and `mapDifficultyFilterOptionsProvider`; map marker rendering must no longer consume Peak List details metadata criteria.
- `lib/router.dart` contains `_AppBarMapFilterTrigger` and Map app-bar composition; remove the trigger and its trailing divider while retaining `app-bar-search-trigger` and the independent `Search popup`.
- `lib/screens/map_screen.dart` contains Map popup presentation and Escape/Ctrl+C dismissal; remove the metadata-filter path without changing unrelated map surfaces.
- Follow the deterministic `TestMapNotifier`, `ProviderScope` override, and in-memory repository conventions in `test/widget/map_screen_metadata_filter_test.dart` and related map/provider tests.

## Acceptance criteria

- [x] A dedicated app-scoped, non-persistent Riverpod Peak List details provider owns metadata popup visibility and the existing `Rating`, `Difficulty`, and `Duration` selections; it resets only on app restart.
- [x] The provider reuses `PeakRatingFilterOption`, `PeakDifficultyFilterOption`, `PeakDurationFilterOption`, `peakMatchesRatingFilter`, `peakMatchesDifficultyFilter`, `peakMatchesDurationFilter`, `buildPeakDifficultyFilterOptions`, `MapMetadataFilterPopup`, and the existing active-filter count semantics rather than duplicating metadata rules.
- [x] `MapState`, `MapNotifier`, `filteredPeaksProvider`, and Map marker rendering no longer expose, synchronize, or apply Peak List details metadata selections.
- [x] The Map app bar exposes no `Filter` trigger and no trailing divider, while the separate Map `Search popup` remains available and unchanged.
- [x] The Map screen no longer presents `MapMetadataFilterPopup` or any metadata-filter backdrop, and Map marker results do not react to Peak List details metadata criteria.
- [x] Deterministic widget and provider coverage replaces the previous Map metadata-filter tests to prove the removed trigger, divider, popup, and marker filtering, while preserving the independent Map `Search popup`; use no live map service, network request, API key, or secret.

## Covers

- User Stories: 2
- Requirements: 1-2, 7
- Technical Decisions: 1
- Testing Strategy: 4, 6
- Interview Ledger: L1, L3, L4, L7

## Blocked by

None - ready to start
