## Overview

Standardize reviewed user-visible counts and percentages on `number_formatters.dart`.
Thin slice first: peak-list summary path; then settings/import/status strings and warnings.

**Spec**: ad hoc cleanup request

## Context

- **Structure**: layer-first; `core/`, `services/`, `providers/`, `widgets/`, `screens/`
- **State management**: Riverpod + local widget state
- **Reference implementations**: `lib/core/number_formatters.dart`, `lib/screens/peak_lists_screen.dart`, `lib/screens/settings_screen.dart`, `test/widget/peak_refresh_settings_test.dart`, `test/widget/peak_lists_screen_test.dart`
- **Assumptions/Gaps**: user-visible strings only; leave chart ticks, editable fields, CSV/GPX serialization untouched; prefer existing `formatCount(...)` / `formatPercentage(...)`; add a tiny ratio-to-percent helper only if callsites become worse than current duplication

## Plan

### Phase 1: Peak-list summary path

- **Goal**: prove helper adoption on one end-to-end list flow
- [x] `lib/services/peak_list_summary_service.dart` - replace raw `%` label with helper-backed formatting
- [x] `lib/screens/peak_lists_screen.dart` - format counts, points, ascent count, and summary sentence via shared helpers; keep unsupported rows unchanged
- [x] `lib/widgets/map_peak_lists_drawer.dart` - pluralize with `formatCount(count)`
- [x] `lib/widgets/peak_list_peak_dialog.dart` - format read-only points text with shared count helper
- [x] TDD: `test/services/peak_list_summary_service_test.dart` - percentage labels stay whole-number percent text for `0%`, `67%`, `100%`
- [x] TDD: `test/widget/peak_lists_screen_test.dart` - peak-list metrics and import-result text render formatted counts
- [x] TDD: `test/widget/peak_list_peak_dialog_test.dart` - points row renders formatted count text
- [x] Verify: `flutter analyze` && `flutter test test/services/peak_list_summary_service_test.dart test/widget/peak_lists_screen_test.dart test/widget/peak_list_peak_dialog_test.dart`

### Phase 2: Settings, imports, provider status

- **Goal**: remove remaining reviewed raw count strings from dialogs, status copy, warnings
- [x] `lib/screens/settings_screen.dart` - format reviewed counts in peak refresh, route-graph refresh, peak export, peak-list export, track reset, track recalc, Tassy Full result copy
- [x] `lib/providers/map_provider.dart` - format import and recalc status summaries with shared helpers
- [x] `lib/services/peak_refresh_service.dart` - format skipped warning count
- [x] `lib/services/peak_repository.dart` - format malformed `PeakList` warning count
- [x] `lib/widgets/gpx_import_dialog.dart` - format added/unchanged/unsupported/error counts
- [x] `lib/widgets/peak_list_import_dialog.dart` - format imported/skipped/warning counts
- [x] `lib/screens/map_screen_panels.dart` - format `tracks available` count
- [x] `test/harness/test_map_notifier.dart` - update canned status strings to formatted text
- [x] TDD: `test/widget/peak_refresh_settings_test.dart` - peak refresh dialog/status keeps formatted count text and warning text
- [x] TDD: `test/widget/route_graph_refresh_settings_test.dart` - route-graph element counts use shared formatting
- [x] TDD: `test/widget/peak_csv_export_settings_test.dart` - peak export success status uses formatted count text
- [x] TDD: `test/widget/peak_list_csv_export_settings_test.dart` - export summary uses formatted exported/skipped/warning counts
- [x] TDD: `test/widget/gpx_import_dialog_test.dart` - import-result dialog uses formatted counts
- [x] TDD: `test/widget/gpx_tracks_summary_test.dart` - settings summary mirrors formatted provider status strings
- [x] TDD: `test/widget/gpx_tracks_shell_test.dart` - snackbar/detail mirrors formatted provider status strings where asserted
- [x] TDD: `test/widget/tassy_full_peak_list_settings_test.dart` - Tassy Full result dialog uses formatted added/updated counts
- [x] Robot journey tests + selectors/seams: `test/robot/peaks/peak_refresh_journey_test.dart`, `test/robot/peaks/peak_list_export_journey_test.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart` - update assertions only; reuse existing keys unless a missing stable selector blocks coverage
- [x] Verify: `flutter analyze` && `flutter test test/widget/peak_refresh_settings_test.dart test/widget/route_graph_refresh_settings_test.dart test/widget/peak_csv_export_settings_test.dart test/widget/peak_list_csv_export_settings_test.dart test/widget/gpx_import_dialog_test.dart test/widget/gpx_tracks_summary_test.dart test/widget/gpx_tracks_shell_test.dart test/widget/tassy_full_peak_list_settings_test.dart test/robot/peaks/peak_refresh_journey_test.dart test/robot/peaks/peak_list_export_journey_test.dart`

## Risks / Out of scope

- **Risks**: ratio-vs-percent helper semantics; brittle long-string assertions; existing singular/plural grammar oddities may become more obvious once counts are reformatted
- **Out of scope**: chart axis/input formatting; CSV/GPX/export serialization formats; broad i18n/localization pass; redesigning helper API beyond the minimal gap needed for reviewed callsites
