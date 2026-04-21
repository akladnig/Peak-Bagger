## Overview

Peak Lists: split summary/details UI, delete flow, resilient CSV import, climbed metrics.
Approach: layer-first; thin shell first; then import/model contract; then details/map; then journeys/regression.

**Spec**: `ai_specs/011-peak-lists-enhancements-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/screens`, `lib/services`, `lib/models`, `lib/widgets`, `lib/providers`
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/objectbox_admin_screen.dart`, `lib/widgets/peak_list_import_dialog.dart`, `lib/screens/map_screen_layers.dart`
- **Assumptions/Gaps**: spec committed at `da2336b`; no open requirement gaps

## Plan

### Phase 1: Shell Slice

- **Goal**: load lists; empty state; selection; import handoff seam
- [x] `lib/screens/peak_lists_screen.dart` - replace empty scaffold with summary/details shell; responsive outer split; local selection state; empty state copy; import completion handoff
- [x] `lib/widgets/peak_list_import_dialog.dart` - return imported/updated list identity after result dialog closes
- [x] `lib/services/peak_list_repository.dart` - add `getById` and `delete`; keep repo data-only
- [x] `test/widget/peak_lists_screen_test.dart` - empty state; first-list auto-select; row selection; responsive stack fallback; import completion selects returned list
- [x] TDD: render empty state copy and shell chrome -> implement minimal screen
- [x] TDD: when lists exist, first row auto-selects and details title updates on row tap -> implement local selection
- [x] TDD: import dialog completion returns list identity and screen selects it after close -> implement handoff contract
- [x] Robot journey tests + selectors/seams for critical flows: add stable keys for rows, panes, selected title, import controls; keep DI seams for repositories/file picker
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Import Contract

- **Goal**: CSV/model contract; repair rules; persistence
- [ ] `lib/models/peak_list.dart` - change `PeakListItem.points` `String -> int`; update encode/decode
- [ ] `lib/services/peak_mgrs_converter.dart` - add direct raw-UTM-to-`LatLng` helper
- [ ] `lib/services/peak_list_import_service.dart` - required headers incl `Ht` alias; blank/default handling; invalid `Points` warn/log -> `0`; partial-coordinate repair; dedupe by resolved `peakOsmId`; unsupported legacy policy; file-level failures throw
- [ ] `test/services/peak_list_import_service_test.dart` - cover points int parsing/defaults, `Ht` alias, partial-coordinate repair, dedupe, file-level failures, warning/log behavior
- [ ] TDD: parse valid row with one coordinate system missing -> derive other system -> persist normalized item
- [ ] TDD: blank `Name`/`Points`/`Height` normalize to `Unknown`/`0`/`0`; invalid non-blank `Points` warns/logs and becomes `0`
- [ ] TDD: duplicate resolved peaks keep first occurrence only
- [ ] TDD: empty CSV/missing headers throw and hit failure path, not success dialog path
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Metrics And Map

- **Goal**: climbed metrics; details table; mini-map; legacy row fallback
- [ ] `lib/screens/peak_lists_screen.dart` - add `PeaksBaggedRepository` provider; compute summary metrics; unsupported legacy row fallback (`-` metrics, unsupported-state details, deletable row); deterministic sorts incl unsupported rows after supported for derived metrics
- [ ] `lib/services/peaks_bagged_repository.dart` - expose read pattern needed for per-peak latest-date aggregation if helper warranted
- [ ] `lib/screens/map_screen_layers.dart` - reuse marker sizing/SVG conventions without zoom<9 suppression for mini-map helper if extracted
- [ ] `test/widget/peak_lists_screen_test.dart` - summary metrics; most-recent sentence; wrapped text; unsupported legacy row visible by name with `-` metrics and delete; sort indicator behavior; legacy rows sort after supported rows
- [ ] TDD: climbed/unclimbed/percentage derive from unique peak IDs and latest ascent dates
- [ ] TDD: most-recent sentence lists all peaks on latest date ordered by peak ID ascending; wraps without overflow
- [ ] TDD: legacy unsupported row stays visible, selectable, deletable; details fall back to unsupported-state message
- [ ] TDD: mini-map shows list peaks with ticked/unticked markers; empty/unsupported paths use Tasmania bounds
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Delete And Journeys

- **Goal**: destructive flow; full journeys; regression pass
- [ ] `lib/screens/peak_lists_screen.dart` - wire row delete action; confirm dialog; targeted-row deletion; post-delete selection rules
- [ ] `test/services/peak_list_repository_test.dart` - `getById`; `delete`; no accidental cross-row effects
- [ ] `test/robot/peaks/peak_lists_robot.dart` - key-first robot helpers for open/select/delete/import/result-close assertions
- [ ] `test/robot/peaks/peak_lists_journey_test.dart` - critical journeys: open/select/delete; open/import/repair/select imported list
- [ ] `test/widget/peak_lists_screen_test.dart` - delete confirm/cancel; non-selected row delete preserves selection; last-row/next-row selection rules
- [ ] TDD: delete acts on invoked row, not current selection; cancel leaves data unchanged
- [ ] TDD: after delete, selection moves next/previous/empty per edge rules
- [ ] Robot journey tests + selectors/seams for critical flows: stable keys for rows, delete action, confirm/cancel, result close; fake repositories/file picker/log writer/clock
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: unsupported legacy rows need graceful UI without payload decode; import/model change touches persisted JSON shape; mini-map fit/marker density on narrow layouts
- **Out of scope**: list editing; reordering; multi-file import; bagging state editing; full-screen map navigation
