## Overview

Settings-driven per-list CSV export. Dedicated service/provider; reuse existing settings status + export seams.

**Spec**: `ai_specs/settings/csv-export-lists-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/services`, `lib/providers`, `lib/screens`, tests split by `services` / `widget` / `robot`
- **State management**: Riverpod `Provider`; runner typedef pattern
- **Reference implementations**: `lib/services/peak_csv_export_service.dart`, `lib/providers/peak_csv_export_provider.dart`, `lib/screens/settings_screen.dart`, `test/widget/peak_csv_export_settings_test.dart`, `test/robot/peaks/peak_refresh_robot.dart`
- **Assumptions/Gaps**: No blocking gaps. Follow spec comparator/reservation rules over older case-sensitive rewrite-port sort for consistency with current UI lowercased sorts.

## Plan

### Phase 1: Thin Slice

- **Goal**: happy-path end-to-end; service -> provider -> settings status
- [x] `lib/services/peak_list_csv_export_service.dart` - add result model, writer seam, root resolver seam, happy-path export for decodable eligible lists
- [x] `lib/providers/peak_list_csv_export_provider.dart` - add service provider + runner typedef/provider; mirror peak export pattern
- [x] `lib/screens/settings_screen.dart` - add `Export Peak Lists` tile, status key, runner call, minimal shared busy-gate plumbing for four actions
- [x] `test/services/peak_list_csv_export_service_test.dart` - add happy-path CSV content + header-order coverage
- [x] `test/widget/peak_list_csv_export_settings_test.dart` - add tap/loading/success flow with provider override
- [x] `test/widget/peak_csv_export_settings_test.dart` - adjust existing offstage tile assertions so shared-gate validation stays green after adding the new settings action
- [x] TDD: service exports multiple lists in deterministic order with exact headers/row mapping; then implement
- [x] TDD: settings tile shows in-progress status, disables four shared-gate actions, then success summary; then implement
- [x] Verify: `flutter analyze && flutter test test/services/peak_list_csv_export_service_test.dart test/widget/peak_list_csv_export_settings_test.dart && flutter test`

### Phase 2: Service Hardening

- **Goal**: edge rules; counts; fatal failures
- [x] `lib/services/peak_list_csv_export_service.dart` - add zero-stored-lists success, empty-list export, missing-peak row skipping, malformed-list skip, blank-name skip, zero-resolved-row skip, structured warnings, exact `skippedListCount`
- [x] `lib/services/peak_list_csv_export_service.dart` - add filename normalization: lowercase, whitespace collapse, slash/backslash/colon replace, leading/trailing dot stripping, collision suffixing, skipped-collider slot reservation, overwrite behavior
- [x] `test/services/peak_list_csv_export_service_test.dart` - add zero-output success, warning aggregation, missing directory failure, file-write failure, all-lists-skipped success, stale-file preservation semantics
- [x] `test/services/peak_list_csv_export_service_test.dart` - seed raw `PeakList.peakList` payloads for duplicate-row export coverage
- [x] TDD: zero stored lists returns success with zero files/zero warnings; then implement
- [x] TDD: malformed / blank-name / zero-resolved lists increment exact skip buckets and `skippedListCount`; then implement
- [x] TDD: colliding skipped list reserves filename slot; exported sibling gets next suffix; then implement
- [x] TDD: missing directory and write failure surface path-aware fatal errors; then implement
- [x] Verify: `flutter analyze && flutter test test/services/peak_list_csv_export_service_test.dart && flutter test`

### Phase 3: Settings Completion

- **Goal**: production messaging; gate regressions; widget lane depth
- [x] `lib/screens/settings_screen.dart` - finalize success/warning/failure copy, older-files-may-remain note, re-enable flow, shared inline status key usage
- [x] `test/widget/peak_list_csv_export_settings_test.dart` - add warning-bearing success, zero-output success, fatal failure with path details, four-way gate regression coverage across refresh/reset/export/export-lists
- [x] `test/widget/peak_csv_export_settings_test.dart` - update existing peak-export test expectations for four-way shared busy gate if needed
- [x] TDD: settings failure shows `Export failed: ...` with path/recovery detail and restores shared-gate actions; then implement
- [x] TDD: successful warning run shows exported/skipped counts plus older-files-may-remain note; then implement
- [x] Verify: `flutter analyze && flutter test test/widget/peak_list_csv_export_settings_test.dart test/widget/peak_csv_export_settings_test.dart && flutter test`

### Phase 4: Robot Journeys

- **Goal**: critical user journeys; stable selectors; deterministic seams
- [ ] `test/robot/peaks/peak_list_export_robot.dart` - add robot around settings export tile, status, final assertions
- [ ] `test/robot/peaks/peak_list_export_journey_test.dart` - add happy-path journey with fake runner/result
- [ ] `test/robot/peaks/peak_list_export_journey_test.dart` - add warning-bearing journey with deterministic fake result
- [ ] `lib/screens/settings_screen.dart` - add only selectors/seams still missing for robot stability
- [ ] TDD: robot happy path opens settings, runs export, sees final success summary; then implement
- [ ] TDD: robot warning path sees warning-bearing success without real filesystem IO; then implement
- [ ] Robot journey tests + selectors/seams for critical flows: `export-peak-lists-tile`, `peak-list-export-status`, provider-overridable runner, deterministic fake results
- [ ] Verify: `flutter analyze && flutter test test/robot/peaks/peak_list_export_journey_test.dart && flutter test`

## Risks / Out of scope

- **Risks**: filename-slot reservation easy to misimplement; four-way settings gate may regress existing export/refresh tests; status copy can drift from structured result counts
- **Out of scope**: folder picker/share sheet/save dialog; Windows semantics; peak-list import/create behavior changes; merging into existing `PeakCsvExportService`
