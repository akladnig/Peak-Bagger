## Overview

CSV-driven PeakBagger sync tool. Read rows, fetch PeakBagger data, correlate/update `Peak`, write CSV + `import.log` + sync report.

**Spec**: `ai_specs/peakbagger-workbook-latlong-sync-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first service/tool; `lib/services/` + `tool/`
- **State management**: none for the sync tool; app side remains Riverpod/ObjectBox
- **Reference implementations**: `lib/services/peak_list_import_service.dart`, `lib/services/peak_repository.dart`, `lib/services/objectbox_admin_repository.dart`, `lib/services/objectbox_schema_guard.dart`, `lib/services/gpx_importer.dart`, `lib/services/peak_csv_export_service.dart`
- **Assumptions/Gaps**: sync tool takes explicit CLI flag for unmatched-peak creation; `uvx peakbagger ...` default command injectable; CSV already carries `Url`, `State/Prov`, `osmId`, `note`

## Plan

### Phase 1: Model + admin plumbing

- **Goal**: Peak schema + admin/schema exposure for PeakBagger fields
- [ ] `lib/models/peak.dart` - add `peakbaggerPid`, `prominence`, `country`, `county`, `range`; keep `sourceOfTruth` contract `peakbagger.com`
- [ ] `lib/objectbox.g.dart` - regenerate ObjectBox bindings after Peak schema changes
- [ ] `lib/objectbox-model.json` - regenerate ObjectBox model after Peak schema changes
- [ ] `lib/services/objectbox_admin_repository.dart` - expose PeakBagger fields, `osmId`, `region`, `sourceOfTruth`; keep PeakBagger admin read-only
- [ ] `lib/services/objectbox_schema_guard.dart` - add Peak fields to schema signature
- [ ] `lib/screens/objectbox_admin_screen_details.dart` - render PeakBagger fields read-only in admin details
- [ ] `test/services/peak_model_test.dart` - `TDD:` Peak defaults/copyWith for PeakBagger fields and `sourceOfTruth`
- [ ] `test/services/objectbox_admin_repository_test.dart` - `TDD:` admin row/field mapping for new Peak fields
- [ ] `test/services/objectbox_schema_guard_test.dart` - `TDD:` schema signature changes when Peak fields change
- [ ] `test/widget/objectbox_admin_shell_test.dart` - `TDD:` PeakBagger fields display read-only in admin details
- [ ] Verify: `dart run build_runner build --delete-conflicting-outputs` && `flutter analyze` && `flutter test test/services/peak_model_test.dart test/services/objectbox_admin_repository_test.dart test/services/objectbox_schema_guard_test.dart test/widget/objectbox_admin_shell_test.dart`

### Phase 2: Correlation + identity rules

- **Goal**: deterministic match/update rules + permanent synthetic identity map
- [ ] `lib/services/peakbagger_peak_correlation_service.dart` - 50m/10m, closest-location tie-break, strong-name fallback on `name` + `altName`
- [ ] `lib/services/peak_repository.dart` - reuse `saveDetailed()` for genuine OSM id promotion; keep peak-list rewrite path intact
- [ ] `test/services/peakbagger_peak_correlation_service_test.dart` - `TDD:` exact match, multi-match, tie, strong-name fallback, unresolved no-match
- [ ] `test/services/peak_repository_test.dart` - `TDD:` `saveDetailed()` rewrites `PeakList`/`PeaksBagged` on `osmId` change
- [ ] Verify: `flutter analyze` && `flutter test test/services/peakbagger_peak_correlation_service_test.dart test/services/peak_repository_test.dart`

### Phase 3: CSV sync service + CLI adapter

- **Goal**: read/write CSV, fetch PeakBagger, write notes/logs/report, optional unmatched creation flag
- [ ] `lib/services/peakbagger_scraper.dart` - command seam; `uvx peakbagger peak show <pid> --format json` default
- [ ] `lib/services/peakbagger_csv_import_service.dart` - parse CSV, PID extraction, row normalization, update rows in place
- [ ] `lib/services/peakbagger_csv_sync_service.dart` - full sync orchestrator; `note`, `import.log`, report, unmatched-creation CLI flag
- [ ] `tool/sync_peakbagger_csv.dart` - CLI entrypoint + flag wiring
- [ ] `test/services/peakbagger_csv_import_service_test.dart` - `TDD:` URL/pid parsing, header handling, note overwrite/clear
- [ ] `test/services/peakbagger_csv_sync_service_test.dart` - `TDD:` fetch failure, missing command, unresolved logging, CSV `osmId` permanence
- [ ] `test/tool/sync_peakbagger_csv_test.dart` - `TDD:` CLI flag path and end-to-end sync command wiring
- [ ] Verify: `flutter analyze` && `flutter test test/services/peakbagger_csv_import_service_test.dart test/services/peakbagger_csv_sync_service_test.dart test/tool/sync_peakbagger_csv_test.dart`

### Phase 4: Integration hardening

- **Goal**: app-facing persistence alignment + regression coverage
- [ ] `lib/services/objectbox_admin_repository.dart` - verify persisted PeakBagger fields round-trip through admin layer
- [ ] `lib/services/objectbox_schema_guard.dart` - verify guard remains stable with new schema
- [ ] `test/services/objectbox_admin_repository_test.dart` - expand for PeakBagger row mapping edge cases
- [ ] `test/services/objectbox_schema_guard_test.dart` - confirm schema guard signature includes PeakBagger fields
- [ ] `test/services/peak_model_test.dart` - lock source-of-truth + copy behavior
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: CSV drift vs existing app admin validation; external `uvx peakbagger` dependency availability; ambiguous matches forcing manual review
- **Out of scope**: runtime UI for sync; redesign of admin peak editing; background automation/scheduling
