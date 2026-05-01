## Overview

Add `Peak.altName` + `Peak.verified` across ObjectBox, admin UI, popup.
TDD vertical slices; preserve user-owned metadata through replacements.

**Spec**: `ai_specs/peaks/alt-name-verified-fields-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `models/`, `services/`, `providers/`, `screens/`, `widgets/`
- **State management**: Riverpod `NotifierProvider`; repository providers overridden in tests
- **Reference implementations**: `lib/services/peak_admin_editor.dart`, `lib/services/objectbox_admin_repository.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `test/robot/objectbox_admin/objectbox_admin_robot.dart`
- **Assumptions/Gaps**: legacy ObjectBox row defaults accepted risk; no binary old-store fixture

## Plan

### Phase 1: Entity + Minimal Admin Save

- **Goal**: thin admin edit/save path persists both fields
- [x] `lib/models/peak.dart` - add `altName`, `verified`; update constructor/copy/fromOverpass defaults
- [x] `lib/objectbox.g.dart` / `lib/objectbox-model.json` - regenerate with `dart run build_runner build`
- [x] `lib/services/objectbox_schema_guard.dart` - include new Peak schema markers
- [x] `lib/services/objectbox_admin_repository.dart` - add row values; add `peakFromAdminRow`; add initial table/details order helpers
- [x] `lib/services/peak_admin_editor.dart` - extend form state, normalize, validate, build
- [x] `lib/screens/objectbox_admin_screen.dart` - use shared row-to-Peak helper
- [x] `lib/screens/objectbox_admin_screen_details.dart` - add controllers/state/form fields; use shared row helper
- [x] TDD: model defaults/copy preserve `altName`/`verified` → implement
- [x] TDD: admin editor trims `altName`, rejects same-name, round-trips `verified` → implement
- [x] TDD: admin row projection + row-to-Peak preserve fields → implement
- [x] TDD: schema signature/model metadata includes fields → implement
- [x] Verify: `flutter analyze && flutter test`

### Phase 2: Admin Ordering, Search, Details Rendering

- **Goal**: full ObjectBox Admin display/search/edit behavior
- [x] `lib/services/objectbox_admin_repository.dart` - Peak-specific search helper; fake search parity; finalized order helpers
- [x] `lib/screens/objectbox_admin_screen_table.dart` - table data-field order; keep Delete action appended
- [x] `lib/screens/objectbox_admin_screen_details.dart` - details field order; shared bool details renderer; accessible disabled checkbox
- [x] `test/harness/test_objectbox_admin_repository.dart` - schema-like fake descriptors; rows include new fields
- [x] `test/widget/objectbox_admin_shell_test.dart` - admin edit/create/order/details/search validation coverage
- [x] `test/robot/objectbox_admin/objectbox_admin_robot.dart` - `altName` field helper; `verified` checkbox helper
- [x] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - edit/save `Alt Name` + `Verified` journey
- [x] TDD: admin search matches name/altName trimmed case-insensitive, sorted by id → implement
- [x] TDD: table order/name pin/delete column behavior → implement
- [x] TDD: details bool checkbox semantics, no duplicate text → implement
- [x] Robot journey tests + selectors/seams: `objectbox-admin-peak-alt-name`, `objectbox-admin-peak-verified`, fake repository/state
- [x] Verify: `flutter analyze && flutter test`

### Phase 3: Popup + Marker Reload

- **Goal**: clicked peak popup shows fresh `altName`
- [x] `lib/screens/map_screen_panels.dart` - render optional `Alt Name: <trimmed altName>` after title
- [x] `lib/providers/map_provider.dart` - shared helper for `reloadPeakMarkers` and `refreshPeaks`; refresh `content.peak` only
- [x] `test/widget/map_screen_peak_info_test.dart` - popup line order, empty collapse, stale popup refresh
- [x] TDD: popup omits empty `altName`; shows non-empty trimmed value in required order → implement
- [x] TDD: marker reload/refresh updates open `content.peak`; preserves `mapName`/`listNames` → implement
- [x] Verify: `flutter analyze && flutter test`

### Phase 4: Replacement Preservation

- **Goal**: no metadata loss through refresh/import/backfill
- [x] `lib/services/peak_repository.dart` - preserve fields through in-memory copy/save/replace helpers
- [x] `lib/services/peak_refresh_service.dart` - preserve/clear fields for OSM refresh, synthetic HWC upgrade, startup backfill, renumber clone
- [x] `lib/services/peak_list_import_service.dart` - preserve fields through CSV correction/save paths
- [x] `test/services/peak_repository_test.dart` - save/copy/replace preservation
- [x] `test/services/peak_refresh_service_test.dart` - OSM match, HWC upgrade, startup backfill, duplicate-name clearing
- [x] `test/services/peak_list_import_service_test.dart` - CSV correction preserves fields
- [x] TDD: refresh/import/backfill preserve user-owned fields → implement per path
- [x] TDD: preserved `altName` equals resulting canonical name clears to `''` → implement
- [x] Verify: `flutter analyze && flutter test`

### Phase 5: Final Verification

- **Goal**: generated files, notes, full suite
- [ ] `ai_specs/peaks/alt-name-verified-fields-plan.md` - keep plan aligned if scope changes
- [ ] implementation notes/final response - state legacy persisted-row defaulting accepted risk; no old-store fixture
- [ ] Verify: `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verify: `flutter analyze && flutter test`

## Risks / Out of scope

- **Risks**: ObjectBox legacy read defaults unverified; generated schema UID churn; widget semantics assertions may need stable finder strategy
- **Out of scope**: app-wide peak search, Peak Lists display/search, separate naming system, runtime backfill script
