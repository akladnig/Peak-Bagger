## Overview

Rename `Peak.area` to `Peak.region`; hard-set `tasmania` for current peaks.
Keep ObjectBox, admin UI, export/import, and tests aligned.

**Spec**: `task: rename area field in peaks to region; set all peaks region=tasmania` (quick plan)

## Context

- **Structure**: layer-first (`lib/screens`, `lib/services`, `lib/widgets`, `lib/providers`)
- **State management**: Riverpod
- **Reference implementations**: `lib/models/peak.dart`, `lib/services/peak_admin_editor.dart`, `lib/services/objectbox_admin_repository.dart`, `lib/services/peak_refresh_service.dart`, `lib/services/peak_csv_export_service.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `test/services/peak_admin_editor_test.dart`
- **Assumptions/Gaps**: one global value only (`tasmania`); ObjectBox rename must preserve existing stored values; no per-peak region taxonomy yet

## Plan

### Phase 1: Schema/runtime rename

- **Goal**: rename field everywhere; no behavior drift
- [x] `lib/models/peak.dart` - rename `area` -> `region`; keep copyWith/defaults consistent; seed `tasmania` for new peaks
- [x] `lib/services/peak_admin_editor.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/services/objectbox_admin_repository.dart` - swap form state, validation, admin mapping, label/key to region
- [x] `lib/services/peak_refresh_service.dart`, `lib/services/peak_list_import_service.dart`, `lib/services/peak_csv_export_service.dart`, `lib/services/peak_repository.dart` - preserve/populate region through refresh/import/save/export; CSV header -> Region
- [x] `lib/objectbox-model.json`, `lib/objectbox.g.dart` - regenerate schema/code with renamed property id preserved
- [x] `test/services/peak_admin_editor_test.dart`, `test/services/objectbox_admin_repository_test.dart`, `test/services/peak_csv_export_service_test.dart`, `test/widget/objectbox_admin_shell_test.dart`, `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - TDD: normalize/save/read/export region; UI key/label rename; robot editor flow
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Backfill current peaks

- **Goal**: every stored/seed peak resolves `region == 'tasmania'`
- [x] `lib/services/peak_repository.dart` - idempotent backfill for legacy rows with blank/null region; keep writes region-safe
- [x] `test/services/peak_model_test.dart`, `test/services/peak_repository_test.dart`, `test/services/peak_refresh_service_test.dart` - TDD: legacy rows migrate, fresh imports default to tasmania, refresh/save never emit null region
- [x] `test/**` peak fixture builders - replace `area:` samples with `region: 'tasmania'`
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: ObjectBox rename/migration can drop historical values if property ids drift; broad test churn from `area` -> `region`
- **Out of scope**: any non-Tasmania taxonomy, UI redesign, behavior changes unrelated to the field rename
