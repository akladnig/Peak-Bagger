## Overview

Tasmap polygon import width -> 10/12 points end to end.
Model/parser first, then schema + CSV fixture, then regression pass.

**Spec**: `ai_specs/map-import-polygon-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `models/`, `services/`, `assets/`, `test/`
- **State management**: none touched; Riverpod not in scope
- **Reference implementations**: `lib/services/csv_importer.dart`, `lib/models/tasmap50k.dart`, `test/csv_importer_test.dart`
- **Assumptions/Gaps**: `lib/objectbox.g.dart` regenerated from updated entity; no UI flow changes

## Plan

### Phase 1: 12-point core slice

- **Goal**: accept 12 vertices in model/parser; keep 4/6/8 intact
- [x] `test/tasmap50k_test.dart` - TDD: 10/12-point `polygonPoints` / valid-count round trip; old 4-point behavior unchanged
- [x] `test/csv_importer_test.dart` - TDD: `parseRow` accepts `p1..p12`, accepts 10-point rows, rejects gap-after-blank, preserves shorter rows
- [x] `lib/models/tasmap50k.dart` - add `p9..p12`, extend `polygonPoints`, update valid-count guard
- [x] `lib/services/csv_importer.dart` - parse `p1..p12`, keep sequential validation and row-local failures
- [x] Verify: `flutter analyze && flutter test test/tasmap50k_test.dart test/csv_importer_test.dart`

### Phase 2: Schema + source

- **Goal**: persist/export 12-point rows; keep admin metadata aligned
- [x] `test/services/objectbox_admin_repository_test.dart` - TDD: Tasmap schema exposes `p9..p12`
- [x] `lib/services/objectbox_admin_repository.dart` - map `p9..p12` into admin rows
- [x] `assets/tasmap50k.csv` - expand header/sample rows to `p12`; keep shorter rows sparse
- [x] regenerate `lib/objectbox.g.dart` via `dart run build_runner build --delete-conflicting-outputs`
- [x] Verify: `flutter analyze && flutter test test/services/objectbox_admin_repository_test.dart`

### Phase 3: Regression pass

- **Goal**: prove bundled import still works with updated schema
- [x] `test/csv_importer_test.dart` - bundled CSV import path still covered; expanded header / 10-12 parsing locked
- [x] `test/tasmap50k_test.dart` - lock `hasValidPolygonPointCount` for 10 and 12
- [ ] Run full suite; fix generator/data mismatches (blocked: `flutter test` hits pre-existing `side_menu.dart` overflow and robot `RootUnavailable` failures unrelated to Tasmap import)
- [ ] Verify: `flutter analyze && flutter test` (blocked by the same unrelated failures)

## Risks / Out of scope

- **Risks**: ObjectBox regen churn; CSV fixture may need real 12-point data updates; hidden consumers may still assume 8-point max
- **Out of scope**: map rendering, label placement, UI/provider changes, new CSV format
