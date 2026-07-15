---
type: Work Item
title: Map Metadata Filter State And Popup UI
parent: ../spec.md
---

## What to build

Add the map metadata-filter experience as one vertical slice through app-bar UI, map-owned in-memory state, live peak filtering, and deterministic test coverage. The map app bar must move the search control from the centered app-bar position to the left side of the app bar, place one visible `Filter` control immediately to the right of search using the standard filter icon followed by the text label, and add a vertical divider immediately after the `Filter` control. Tapping that control must open one popup or modal filter surface with exactly three fixed rows in this order: `Rating`, `Difficulty`, `Duration`. The filter panel must apply changes immediately, keep selections on normal dismiss paths, keep `Clear filters` in-place, preserve stale selected difficulty visibility when scope changes, and keep the current `Rating`, `Difficulty`, and `Duration` selections alive in existing map-owned Flutter state for the rest of the app session.

## Required context

- `lib/router.dart` currently owns the shared map app-bar layout and the centered `app-bar-search-trigger`. This slice must update that existing shell layout rather than introducing a second app-bar path for `Map`.
- `lib/providers/map_provider.dart` already owns map session state that survives route revisits and peak-list or visible-region changes within the same app session. Keep metadata-filter selection state there instead of adding disk persistence.
- `lib/providers/peak_list_selection_provider.dart` currently exposes `filteredPeaksProvider`, and `lib/screens/map_screen.dart` consumes that data. Extend the filtering pipeline cleanly so map metadata filters apply live to visible peaks without changing the parent Spec contract.
- `lib/widgets/map_search_popup.dart`, `lib/core/widgets/popup_shell.dart`, `lib/widgets/peak_list_control_visual_style.dart`, and the existing app-bar search styling provide the nearest UI patterns for popup structure and selected-versus-unselected control states.
- `test/providers/map_peak_list_selection_persistence_test.dart`, `test/providers/map_provider_search_selection_test.dart`, `test/widget/map_screen_persistence_test.dart`, and related map widget tests already cover map-owned same-session persistence patterns. Reuse those deterministic seams.
- Add stable selectors for the filter trigger, popup root, each fixed row, and `Clear filters` if existing keys are insufficient. Keep robot or widget selectors deterministic and feature-prefixed.

## Acceptance criteria

- [ ] `Map` remains filter-only for this feature and does not add new sort controls for `Rating`, `Difficulty`, or `Duration`.
- [ ] The map app bar moves the search control from the centered position to the left side of the app bar.
- [ ] One visible control with the standard filter icon followed by a text label appears immediately to the right of the search control.
- [ ] A vertical divider appears immediately after the `Filter` control.
- [ ] When no map metadata filters are active, the control text is exactly `Filter` and uses the unselected visual state.
- [ ] When one or more filters are active, the control text is exactly `1 Filter`, `2 Filters`, or `3 Filters` based on the number of non-`Any` selections, and uses the selected visual state.
- [ ] Tapping the map `Filter` control opens one popup or modal filter surface that contains exactly three fixed filter rows in this order: `Rating`, `Difficulty`, `Duration`.
- [ ] The popup uses the provided mockup only as a styling reference, with dark rounded row containers and a trailing dropdown styled like the mockup's rightmost control, while keeping out of scope `Saved filters`, boolean operators, nested filters, per-row delete icons, and dynamic add/remove rows.
- [ ] The map `Rating` filter is single-select with exactly `Any`, `3.0`, `3.5`, `4.0`, and `4.5`, presented with star-based visuals rather than plain decimal text.
- [ ] `Rating` accessibility semantics announce the numeric value, for example `4.5 out of 5 stars`.
- [ ] The map `Difficulty` filter is single-select with `Any` plus region-specific difficulty values drawn from the current visible or selected peak scope before applying map metadata filters.
- [ ] When multiple grading systems are present, `Difficulty` options are grouped by region and selecting one option matches one exact `(region, difficulty)` pair at a time.
- [ ] When needed for clarity, the selected `Difficulty` value shows region context such as `T4 (Slovenia)`.
- [ ] If the currently selected `(region, difficulty)` pair falls out of the current visible or selected scope, that selected value remains visible in the filter row so the user can still see and clear it while the normal option list reflects the current scope.
- [ ] The map `Duration` filter is single-select with exactly these visible options: `Any`, `4h`, `8h`, `12h`, `2d`, `5d`, `10d`, `2d+`.
- [ ] `4h`, `8h`, `12h`, `2d`, `5d`, and `10d` match peaks where `durationMinutes <= threshold`, while `2d+` matches peaks where `durationMinutes >= 2880`.
- [ ] Option changes apply immediately and the map updates live so only matching peaks remain visible.
- [ ] Closing the panel by outside tap, Escape, Back, or equivalent dismiss behavior keeps the current selection.
- [ ] `Clear filters` resets all three rows to `Any` and keeps the panel open.
- [ ] Peaks with missing ratings, missing `Peak difficulty`, or missing duration are excluded whenever the corresponding filter selection is not `Any`.
- [ ] Changing peak-list selection, changing visible regions, or leaving and returning to `Map` during the same app session preserves the current `Rating`, `Difficulty`, and `Duration` selections.
- [ ] Active map metadata filters are not silently cleared just because the current visible peaks no longer offer matching values; in that case the filter remains active and the map shows zero matches until the user changes or clears it.
- [ ] Deterministic widget coverage, likely in `test/widget/tasmap_map_screen_test.dart`, map app-bar tests, and related map selection or persistence tests, verifies the visible `Filter` control, moved search placement, trailing vertical divider, `Filter` / `1 Filter` / `2 Filters` / `3 Filters` label transitions, selected-versus-unselected state, popup open and close behavior, immediate apply behavior, `Clear filters`, zero-match persistence, stale selected difficulty visibility, same-session persistence across map route revisits and peak-list or visible-region changes, the exact duration option list, and stable selectors for the trigger, popup root, rows, and `Clear filters` when needed.
- [ ] Automated coverage remains deterministic and uses fake repositories, provider overrides, and in-memory map data only, with no live network calls, live map services, or secrets.

## Covers

- User Stories: 2-3
- Requirements: 11-19
- Technical Decisions: 3-5
- Testing Strategy: 1, 4-6
- Interview Ledger: L1, L3, L5-L6, L8-L11

## Blocked by

- `01-peak-duration-persistence-and-shared-metadata-rules.md`
