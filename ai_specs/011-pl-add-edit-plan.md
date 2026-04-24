## Overview

Selected-list peak detail/edit/add/delete retrofit.
Keep peak catalog immutable; only list membership mutates.

**Spec**: `ai_specs/011-pl-add-edit-spec.md`

## Context

- **Structure**: layer-first (`lib/screens`, `lib/services`, `lib/widgets`, `lib/providers`)
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/widgets/peak_list_import_dialog.dart`, `lib/services/peaks_bagged_repository.dart`, `lib/screens/map_screen_layers.dart`
- **Assumptions/Gaps**: `lib/widgets/peak_list_peak_dialog.dart` already exists; expand it. `GpxTrackRepository.findById()` already exists. Reuse existing failure-dialog patterns; add seams only if tests force them.

## Plan

### Phase 1: Selected peak view

- **Goal**: inspect peak, counts, history, pinned headers
- [x] `lib/services/peaks_bagged_repository.dart` - add ascent count/history helpers keyed by `Peak.osmId`
- [x] `lib/screens/peak_lists_screen.dart` - add `Ascents` column, blank-last sort, row tap -> modal, keep `selectedPeakListId` stable
- [x] `lib/widgets/peak_list_peak_dialog.dart` - show metadata, ascent history table, edit/delete actions, map fallback label
- [x] `lib/screens/peak_lists_screen.dart` or `lib/screens/map_screen_layers.dart` - keep blue selection circle above peak markers
- [x] TDD: `Ascents` blank/count/sort; modal open/close leaves list selection intact
- [x] TDD: scrollable tables keep header pinned in viewport
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Add / edit / delete

- **Goal**: mutate membership only, preserve peak entity
- [x] `lib/widgets/peak_list_peak_dialog.dart` - add/search mode UI, 0-10 points selector, duplicate filtering, delete confirm
- [x] `lib/services/peak_list_repository.dart` - add item-level add/update/remove helpers on JSON payload
- [x] `lib/screens/peak_lists_screen.dart` - post-save reselection; clear selection only when deleted row was selected
- [x] TDD: add saves missing peak, auto-selects new row, rejects duplicates
- [x] TDD: edit updates points only; delete removes row and moves selection
- [x] TDD: cancel leaves list unchanged; out-of-range points blocked; no-results state matches map search panel
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: GPX link navigation

- **Goal**: open map with matching track selected, visible, and marked at the peak
- [x] `lib/widgets/peak_list_peak_dialog.dart` - GPX link tap -> track lookup, recoverable missing-track error
- [x] `lib/providers/map_provider.dart` - drive GPX navigation through `showTrack(...)`, preserve the peak marker, and apply fallback track focus before opening Map Screen
- [x] `lib/screens/map_screen.dart` - reuse fallback fit shape and honor pending selected-track focus when the map branch becomes active again
- [x] TDD: track lookup failure keeps dialog open; successful link selects track and retargets on repeated clicks
- [ ] Robot: key-first journey for select list -> open peak -> GPX link -> map track selected
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Regression pass

- **Goal**: lock unchanged list/import/delete behavior
- [x] `lib/widgets/peak_list_peak_dialog.dart` - bottom-right dialog placement and drag handle behavior
- [x] `lib/screens/peak_lists_screen.dart` - launch the dialog without a centered pop-in so it opens bottom-right immediately
- [x] `lib/widgets/peak_list_peak_dialog.dart` / `lib/screens/map_screen_panels.dart` - add-peak autofocus and `Map: MapName` result text
- [x] `test/widget/peak_lists_screen_test.dart` - summary, import, delete, sticky-header, reselection regressions
- [x] `test/widget/peak_list_peak_dialog_test.dart` - add/edit/delete/error-state coverage
- [x] `test/services/peaks_bagged_repository_test.dart` - count/history helpers
- [ ] `test/robot/peaks/peak_lists_journey_test.dart` - full add/edit/delete/GPX flow
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: dialog/reselection edge cases; blank-last sort correctness; GPX fit/select-track seam drift
- **Out of scope**: bulk edit/delete, reorder, new peak schema, free-form points, alternate import flow
