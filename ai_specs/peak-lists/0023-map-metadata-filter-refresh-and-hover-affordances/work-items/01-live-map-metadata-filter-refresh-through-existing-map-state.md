---
type: Work Item
title: Live Map Metadata Filter Refresh Through Existing Map State
parent: ../spec.md
---

## What to build

Wire the `Map metadata filter` refresh bugfix as one vertical Flutter slice through the existing import/admin mutation seams, map-owned peak state, derived filter options, filtered map results, and deterministic provider/widget coverage. Any peak-list import or update path that changes peak membership in the current map scope or peak metadata used by `Rating`, `Difficulty`, or `Duration`, and any `ObjectBox Admin` peak save that changes `Rating`, `Difficulty`, or `Duration`, must immediately reload the map-owned peaks from current local storage so `MapScreen` refreshes the live option set and filtered results without requiring the user to close and reopen the popup.

## Required context

- `lib/providers/map_provider.dart` already owns the map session state and the primary refresh seam in `MapNotifier.reloadPeakMarkers()`. Reuse that map-owned refresh path or an equivalent reload from current local peak storage instead of adding a second persistence or synchronization path.
- `lib/providers/peak_list_provider.dart`, `lib/screens/peak_lists_screen.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `lib/widgets/map_action_rail.dart`, and `lib/screens/settings_screen.dart` already contain peak-list import or update flows that currently coordinate `peakListRevisionProvider` and `MapNotifier.reconcileSelectedPeakList()`. This item should preserve those coordination seams while ensuring relevant mutations also refresh current map-owned peak metadata.
- `lib/screens/objectbox_admin_screen.dart` and `lib/screens/map_screen.dart` already save peaks and call `MapNotifier.reloadPeakMarkers()` in some paths. Keep the existing `ObjectBox Admin` navigation and success/failure presentation unchanged while tightening refresh timing for `Rating`, `Difficulty`, and `Duration` changes.
- `lib/providers/peak_list_selection_provider.dart` derives `mapMetadataFilterScopePeaksProvider`, `filteredPeaksProvider`, and `mapDifficultyFilterOptionsProvider` from current map-owned peaks and current peak-list selection mode. Preserve that provider-driven rebuild contract so an already-open popup refreshes in place from live derived state rather than stale popup-local state.
- Preserve the existing map metadata-filter contract from `ai_specs/peak-lists/0020-peak-rating-difficulty-duration-sorting-and-filters/spec.md`, especially existing dismiss behavior and same-session filter persistence across map route revisits and peak-list or visible-region changes.
- Extend deterministic coverage in existing seams such as `test/providers/map_peak_list_selection_state_test.dart`, `test/providers/map_peak_list_selection_persistence_test.dart`, `test/widget/map_screen_metadata_filter_test.dart`, and related map/provider tests. Keep fake repositories, provider overrides, in-memory data, and stable selectors only.

## Acceptance criteria

- [x] Use `Map metadata filter` as the canonical term for this slice and keep it scoped to the `MapScreen` `Rating`, `Difficulty`, and `Duration` controls.
- [x] Any peak-list import or update path that changes either peak membership in the current map scope or peak metadata used by `Rating`, `Difficulty`, or `Duration` immediately reloads map-owned peaks from current local storage so the `Map metadata filter` option set and filtered map results refresh from current data.
- [x] The same immediate refresh behavior applies in both `All Peaks` mode and specific peak-list selection mode.
- [x] Any `ObjectBox Admin` peak save that changes `Rating`, `Difficulty`, or `Duration` immediately reloads map-owned peaks from current local storage so the `Map metadata filter` option set and filtered map results refresh on `MapScreen`.
- [x] The implementation reuses `MapNotifier.reloadPeakMarkers()` or an equivalent map-state refresh from current local peak storage, and does not treat `MapNotifier.reconcileSelectedPeakList()`, `peakListRevisionProvider`, or `peakListsLoadProvider` as a substitute for refreshing current peak metadata into map-owned state.
- [x] If the `Map metadata filter` popup is already open when a relevant peak-list or `ObjectBox Admin` change occurs, the popup refreshes in place immediately and remains open.
- [x] When a refresh causes an active metadata-filter selection to fall out of the newly available option set, the selected value remains visible and active until the user changes or clears it.
- [x] Refreshing metadata-filter state after peak-list import, peak-list update, or `ObjectBox Admin` save does not show extra toasts, dialogs, or auto-reset behavior solely because the popup option set changed.
- [x] Existing dismiss behavior and same-session filter persistence across map route revisits and peak-list or visible-region changes remain unchanged except where this Spec explicitly tightens refresh behavior.
- [x] Deterministic provider or notifier coverage proves peak-list import/update and `ObjectBox Admin` driven reloads immediately refresh the derived filter option set and filtered peak results from current local peak data in both `All Peaks` mode and specific peak-list selection mode.
- [x] Deterministic widget coverage proves an already-open metadata-filter popup refreshes in place after relevant data changes, keeps stale active selections visible, does not require reopen, and does not emit extra UI.
- [x] Automated coverage remains local and deterministic with in-memory repositories, provider overrides, and existing widget seams only, with no live network calls, live map services, or secrets.

## Covers

- User Stories: 1-2
- Requirements: 1-6, 11
- Technical Decisions: 1-2
- Testing Strategy: 1-2, 4-5
- Interview Ledger: L1-L4

## Blocked by
None - ready to start
