---
type: Spec
title: Map Metadata Filter Refresh And Hover Affordances
---

## Problem

`MapScreen` already has a `Map metadata filter` popup for `Rating`, `Difficulty`, and `Duration`, but the current behavior is stale and inconsistent after local data changes. When peak-list import or update changes the scoped peaks or their metadata, the map metadata-filter options do not always refresh immediately. The same stale behavior can appear after `ObjectBox Admin` peak saves. On macOS, the filter controls also lack consistent pointing-finger hover affordance, and the current `Clear filters` action does not match the desired visual emphasis or alignment. The bugfix must preserve the existing metadata-filter contract while making refresh and hover behavior immediate and predictable. [L1] [L2] [L3] [L4] [L5] [L6]

## Proposed Outcome

`MapScreen` keeps using the existing `Map metadata filter` terminology and three-row popup, but the popup, option lists, and filtered map results refresh immediately after relevant peak-list import/update or `ObjectBox Admin` peak edits. If the popup is open, it stays open and refreshes in place without clearing active selections. On macOS, every interactive metadata-filter control uses the pointing-finger cursor, and `Clear filters` becomes a right-aligned filled high-emphasis action that matches the existing `Create Route` cancel-control styling while preserving its current behavior. [L1] [L2] [L3] [L4] [L5] [L6]

## User Stories

1. As a map user, I can trust the `Map metadata filter` to refresh immediately after peak-list import or update so the visible options and filtered peaks reflect the latest local data without reopening the popup. [L1] [L2] [L4]
2. As a power user editing peaks in `ObjectBox Admin`, I can save rating, difficulty, or duration changes and see the map metadata-filter popup and map results update immediately from the live store. [L3] [L4]
3. As a macOS user, I get consistent interactive hover affordance and a clearly emphasized `Clear filters` action across the metadata-filter flow. [L5] [L6]

## Requirements

1. Use `Map metadata filter` as the canonical term for this bugfix. It refers specifically to the `MapScreen` `Rating`, `Difficulty`, and `Duration` controls and must remain distinct from peak-list selection controls. [L1]
2. Any peak-list import or update path that changes either peak membership in the current map scope or peak metadata used by `Rating`, `Difficulty`, or `Duration` must immediately reload the map-owned peak state from current local storage so the map metadata-filter option set and filtered map results refresh from current data. Apply the same behavior in both `All Peaks` mode and specific peak-list selection mode. [L2]
3. Any `ObjectBox Admin` peak save that changes `Rating`, `Difficulty`, or `Duration` metadata must immediately reload the map-owned peak state from current local storage so the map metadata-filter option set and filtered map results refresh on `MapScreen`. [L3]
4. If the map metadata-filter popup is already open when a relevant peak-list or `ObjectBox Admin` change occurs, the popup must refresh in place immediately and remain open. The app must not require the user to close and reopen the popup to see the latest option set or filtered map results. [L4]
5. When a refresh causes an active metadata-filter selection to fall out of the newly available option set, the selected value must remain visible and active until the user changes or clears it. The refresh must not silently clear active selections. [L2] [L4]
6. Refreshing metadata-filter state after peak-list import, peak-list update, or `ObjectBox Admin` save must not show extra toasts, dialogs, or auto-reset behavior solely because the popup option set changed. [L4]
7. On macOS, the pointing-finger cursor must appear for these interactive map metadata-filter controls: the app-bar `Filter` trigger, the `Rating` dropdown trigger, the `Difficulty` dropdown trigger, the `Duration` dropdown trigger, and the `Clear filters` action. [L5]
8. This hover bugfix must not change cursor behavior for non-interactive metadata-filter labels, row containers, or the popup backdrop. [L5]
9. The `Clear filters` control must keep the visible label `Clear filters`, remain right-aligned within the popup, and use the same filled, high-emphasis visual treatment as the existing `Create Route` cancel control. [L6]
10. `Clear filters` must stay enabled while the popup is open and must preserve the existing interaction contract of resetting `Rating`, `Difficulty`, and `Duration` to `Any` while keeping the popup open. [L4] [L6]
11. This bugfix must preserve the existing map metadata-filter contract from `ai_specs/peak-lists/0020-peak-rating-difficulty-duration-sorting-and-filters/spec.md` unless this Spec explicitly tightens it. In particular, existing dismiss behavior and same-session filter persistence across map route revisits and peak-list or visible-region changes must remain unchanged. [L4]

## Technical Decisions

1. Reuse the existing map-owned Flutter state and refresh seams rather than adding a second persistence or synchronization path for this bugfix. The primary refresh seam for peak-metadata changes is reloading map-owned peaks through `MapNotifier.reloadPeakMarkers()` or an equivalent map-state refresh from current local peak storage. Treat `MapNotifier.reconcileSelectedPeakList()`, `peakListRevisionProvider`, and `peakListsLoadProvider` as peak-list membership and selection coordination seams, not as a substitute for reloading current peak metadata into map-owned state. Continue relying on provider-driven `MapScreen` rebuilds after the map-owned peak state refreshes. [L2] [L3] [L4]
2. Treat metadata-filter options as live derived UI state that must rebuild from the current map scope after local peak-list and peak-metadata changes, instead of relying on stale popup-local state that only updates on reopen. [L2] [L3] [L4]
3. Reuse an existing app control as the style anchor for the `Clear filters` action. For this bugfix, the visual source of truth is the current `Create Route` cancel control treatment, not the lower-emphasis default `TextButtonTheme` styling. [L6]

## Testing Strategy

1. Extend deterministic provider or notifier coverage around map metadata-filter state so peak-list import/update and `ObjectBox Admin`-driven peak reloads immediately refresh the derived filter option set and filtered peak results from current local peak data. Cover both `All Peaks` mode and specific peak-list selection mode. [L2] [L3] [L4]
2. Extend map widget coverage, likely in `test/widget/map_screen_metadata_filter_test.dart` and related map widget tests, to prove that an already-open metadata-filter popup refreshes in place after relevant data changes, keeps stale active selections visible, and does not require reopen or emit extra UI. [L4]
3. Add deterministic widget assertions for macOS hover affordance and button presentation: the app-bar filter trigger, each dropdown trigger, and `Clear filters` button expose the pointing-finger cursor; `Clear filters` is right-aligned and uses the intended filled high-emphasis treatment. [L5] [L6]
4. Prefer existing in-memory repositories, provider overrides, and local widget seams. Automated coverage for this bugfix must not require live network calls, live map services, or secrets. [L2] [L3]
5. Add non-regression coverage proving this bugfix preserves the existing map metadata-filter contract from Spec 0020 where this Spec does not explicitly change it, especially existing dismiss behavior and same-session filter persistence across map route revisits and peak-list or visible-region changes. [L4]

## Out of Scope

1. Renaming or changing the peak-list selection feature on `MapScreen`. [L1]
2. Adding new metadata-filter rows, saved-filter features, or app-restart persistence changes beyond the existing metadata-filter contract. [L4]
3. Changing cursor behavior outside the map metadata-filter controls named in this Spec. [L5]

## Notes

1. This Spec tightens the existing `Map metadata filter` contract introduced by `ai_specs/peak-lists/0020-peak-rating-difficulty-duration-sorting-and-filters/spec.md`, with the main focus on immediate refresh after local data mutation plus macOS hover and action-affordance polish.
2. Relevant implementation surfaces include `lib/widgets/map_metadata_filter_popup.dart`, `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `lib/providers/peak_list_provider.dart`, `lib/providers/peak_list_selection_provider.dart`, `lib/screens/objectbox_admin_screen.dart`, and existing map metadata-filter tests.
