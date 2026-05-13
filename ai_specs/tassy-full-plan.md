## Overview

Sync `Tassy Full` as a best-effort derived super-set of other peak lists, with a manual Settings refresh path.
Keep sync logic isolated; provider layer handles revision bumps and selection reconciliation.

**Spec**: `ai_specs/tassy-full-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-by-feature; settings UI in `lib/screens/settings_screen.dart`, peak-list flows in `lib/screens/peak_lists_screen.dart` + `lib/widgets/peak_list_peak_dialog.dart`, data in `lib/services/peak_list_repository.dart`
- **State management**: Riverpod; `peakListRevisionProvider` + `mapProvider.reconcileSelectedPeakList()` already drive consumer invalidation
- **Reference implementations**: `lib/screens/settings_screen.dart`, `lib/providers/peak_list_provider.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `lib/services/peak_list_import_service.dart`, `test/robot/peaks/peak_refresh_robot.dart`, `test/robot/peaks/peak_lists_journey_test.dart`
- **Assumptions/Gaps**: sync helper returns result only; provider/orchestrator performs revision bump + selection reconcile; direct `Tassy Full` deletions stay temporary

## Plan

### Phase 1: Sync contract

- **Goal**: derive/rebuild `Tassy Full` from source lists; no recursion
- [x] `lib/services/tassy_full_peak_list_sync_service.dart` - add helper + result model; union source lists, dedupe by `peakOsmId`, keep highest `points`, deterministic order
- [x] `lib/services/peak_list_repository.dart` - add internal write path for `Tassy Full`; bypass normal mutation hooks; no sync recursion
- [x] `lib/services/peak_list_repository.dart` - expose refresh entrypoint returning added/updated counts; preserve temporary direct-delete behavior
- [x] `test/services/...` - TDD: union/dedupe/highest-points/order/missing-target/malformed-source/result-shape/internal-write-path
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Automatic refresh wiring

- **Goal**: best-effort refresh after non-`Tassy Full` mutations
- [x] `lib/providers/peak_list_provider.dart` - orchestrate refresh result; increment `peakListRevisionProvider` + reconcile active selection after successful automatic refresh
- [x] `lib/services/peak_list_import_service.dart` - return refresh result to provider layer; preserve best-effort import behavior
- [x] `lib/widgets/peak_list_peak_dialog.dart` - keep peak-item add/edit/delete flows routed through same refresh orchestration
- [x] `lib/screens/peak_lists_screen.dart` - ensure create/save/delete paths trigger the same provider-layer refresh/revision path
- [x] `test/providers/...` - TDD: automatic refresh bumps revision on success; source edit stays committed on refresh failure; stale selection reconciles
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Settings rebuild

- **Goal**: explicit all-or-nothing rebuild + user feedback
- [x] `lib/screens/settings_screen.dart` - add `Update Tassy Full Peak List` tile, confirm dialog, completion/failure dialogs using existing dialog helper pattern
- [x] `lib/screens/settings_screen.dart` - on success, invalidate peak-list consumers and reconcile selection after rebuild
- [x] `lib/screens/settings_screen.dart` - result copy: added + updated counts only; keep copy clear and deterministic
- [x] `test/widget/...settings...` - TDD: tile visible, confirm/cancel flow, success/failure dialogs, result text, busy state parity with existing settings actions
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Journeys + regressions

- **Goal**: prove end-to-end behavior through robot/widget journeys
- [x] `test/robot/peaks/peak_refresh_robot.dart` - add Settings journey for Tassy Full refresh
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - extend source-list add/update/import coverage for best-effort refresh behavior
- [x] `test/widget/gpx_tracks_shell_test.dart` - add/adjust settings regression coverage if shared status/selector behavior changes
- [x] `test/widget/peak_lists_screen_test.dart` - add focused regression for Tassy Full visibility/current-state after refresh
- [x] TDD: successful refresh invalidates peak-list consumers; active selection reconciles; direct deletions remain temporary
- [x] Robot: open Settings → confirm refresh → observe result dialog; add/update/import source list and observe Tassy Full refresh
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: sync recursion; stale peak-list consumers; ambiguous direct-delete semantics; all-or-nothing Settings rebuild vs best-effort automatic refresh
- **Out of scope**: new persistence/schema, auto-delete from source removals, docs/UI warning badge for derived state
