## Overview

Import P100 prominence into ObjectBox `Peak.prominence` from `./assets/all-peaks-sorted-p100.csv`.
CLI + services only; parse, correlate, log, dry-run preview, best-effort persist.

**Spec**: `ai_specs/peak-prominence-tool.md` (read this file for full requirements)

## Context

- **Structure**: layer-first service/tool
- **State management**: none; CLI + repository/services only
- **Reference implementations**: `lib/services/peakbagger_csv_sync_service.dart`, `lib/services/peakbagger_peak_correlation_service.dart`, `lib/services/peak_csv_export_service.dart`, `tool/sync_peakbagger_csv.dart`
- **Assumptions/Gaps**: unmatched ObjectBox peaks are informational `not-found-in-dataset`; write failures best-effort, non-zero exit if any fail; dry-run preview path fixed at `./tool/peak-prominence-objectbox-preview.csv`

## Plan

### Phase 1: Parse + validate

- **Goal**: headerless P100 parse; strict contract; deterministic validation
- [x] `lib/services/peak_prominence_csv_service.dart` - record model, headerless parse, sort validation, sentinel handling, CSV row normalization
- [x] `test/services/peak_prominence_csv_service_test.dart` - TDD: happy path parse, 0,0 sentinel, sort order, malformed row, non-numeric field, headerless contract
- [x] Verify: `flutter analyze` && `flutter test test/services/peak_prominence_csv_service_test.dart`

### Phase 2: Correlate + persist + preview export

- **Goal**: deterministic match, best-effort writes, id-sorted preview CSV
- [ ] `lib/services/peak_prominence_correlation_service.dart` - 30m/10m match, smallest `Peak.id` tie resolution, lat/lon-only fallback, duplicate-candidate logging
- [ ] `lib/services/peak_prominence_import_service.dart` - orchestrate CSV -> match -> persist, unresolved CSV logs, unmatched-peak logs, counts, best-effort continue on write failure
- [ ] `lib/services/peak_prominence_preview_export_service.dart` - export all ObjectBox peaks sorted by `id` to `./tool/peak-prominence-objectbox-preview.csv`
- [ ] `test/services/peak_prominence_correlation_service_test.dart` - TDD: happy match, missing elevation fallback, duplicate candidate ordering, unresolved row handling
- [ ] `test/services/peak_prominence_import_service_test.dart` - TDD: best-effort write failure, log lines, counts, unmatched `not-found-in-dataset`
- [ ] `test/services/peak_prominence_preview_export_service_test.dart` - TDD: all peaks exported, sorted by id, prominence blank/null preservation
- [ ] Verify: `flutter analyze` && `flutter test test/services/peak_prominence_correlation_service_test.dart test/services/peak_prominence_import_service_test.dart test/services/peak_prominence_preview_export_service_test.dart`

### Phase 3: CLI wiring + docs

- **Goal**: `validate` / `import` / `--dry-run` entrypoint, paths, exit codes
- [ ] `tool/peak_prominence_csv.dart` - arg parse, default paths, dry-run preview write, import write, non-zero exit on any write failure
- [ ] `README.md` or CLI help text - usage, preview path, log path, output semantics
- [ ] `test/tool/peak_prominence_csv_test.dart` - TDD: validate mode, dry-run path, import path, exit codes, preview path, log path
- [ ] Verify: `flutter analyze` && `flutter test test/tool/peak_prominence_csv_test.dart`

## Risks / Out of scope

- **Risks**: full CSV scan may be memory-heavy if lookup/index is naive; unmatched-peak reporting may be noisy if eligibility assumptions are wrong; best-effort writes can leave partial DB state
- **Out of scope**: UI, network fetch, new peak creation, raw CSV rewrite, robot tests
