## Overview

Inline peak-popup editing; keep ObjectBox Admin for full edits.
Thin slice first: hover->pinned popup, name/height save, popup refresh.

**Spec**: `ai_specs/peaks/peak-edit-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/models`, `providers`, `services`, `screens`, `widgets`
- **State management**: Riverpod `NotifierProvider`; popup/admin state in `lib/providers/map_provider.dart`, `lib/providers/objectbox_admin_provider.dart`
- **Reference implementations**: `lib/screens/map_screen_panels.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/robot/peaks/peak_info_robot.dart`
- **Assumptions/Gaps**: none material; follow existing provider + shell-nav patterns over new deep-link abstractions

## Plan

### Phase 1: Popup Edit Slice

- **Goal**: pinned popup -> inline form -> save -> refresh
- [x] `lib/screens/map_screen_panels.dart` - split read-only/edit popup UI; add name/height fields, save/cancel, saving/error state, stable keys
- [x] `lib/screens/map_screen.dart` - replace edit navigation with inline-edit callbacks; repin hovered popup via provider flow before edit mode; enforce close/drop-marker disable rules while saving/editing
- [x] `lib/providers/map_provider.dart` - expose any small helper needed for authoritative popup repin/current peak refresh; keep provider popup mode source-of-truth
- [x] `test/widget/map_screen_peak_info_test.dart` - cover hover edit repin, edit entry, save/cancel, saving feedback, read-only drop-marker unavailable in edit mode
- [x] `test/robot/peaks/peak_info_robot.dart` - add popup edit selectors/helpers for form, save/cancel, error, saving state
- [x] `test/robot/peaks/peak_info_journey_test.dart` - cover open -> edit -> save happy path
- [x] TDD: hover popup edit -> provider popup mode becomes pinned -> inline form appears
- [x] TDD: name/height save -> repository write succeeds -> `sourceOfTruth` HWC + `verified` true -> popup refreshes in place
- [x] TDD: invalid name/height or save failure -> inline error, draft preserved, saving state clears
- [x] Robot journey tests + selectors/seams for critical flows: popup edit happy path; keys `peak-info-popup-edit-form`, `peak-info-popup-name`, `peak-info-popup-elevation`, `peak-info-popup-save`, `peak-info-popup-cancel`, `peak-info-popup-error`; fake repo seam for save outcomes
- [x] Verify: `flutter analyze && flutter test`

### Phase 2: Marker Relocation Slice

- **Goal**: persisted-marker relocate; draft coord refresh; safe validation
- [x] `lib/providers/map_provider.dart` - add/expose persisted-current-marker lookup; keep `selectedLocation` out of relocate source-of-truth
- [x] `lib/services/peak_admin_editor.dart` - extract/reuse narrow coord conversion/validation helpers only if needed; do not reuse `validateAndBuild()` for popup save assembly
- [x] `lib/screens/map_screen_panels.dart` - add edit-mode-only move-to-marker row, disabled state, inline error path, draft MGRS refresh
- [x] `test/services/peak_admin_editor_test.dart` - cover marker-driven coord recalc, Tasmania rejection, conversion failure, same-coordinate no-op if helper lives here
- [x] `test/widget/map_screen_peak_info_test.dart` - cover no persisted marker, valid relocate draft update, invalid relocate error, cancel rollback after relocate
- [x] `test/robot/peaks/peak_info_journey_test.dart` - extend happy path with marker-present relocate flow
- [x] TDD: persisted marker relocate -> draft lat/lng + MGRS update before save
- [x] TDD: no persisted marker / invalid marker -> disabled or inline error; draft unchanged
- [x] TDD: cancel after relocate -> original coordinates restored
- [x] Robot journey tests + selectors/seams for critical flows: relocate flow; key `peak-info-popup-move-to-marker`; seam via `TestMapNotifier` / fake waypoints storage
- [x] Verify: `flutter analyze && flutter test`

### Phase 3: Admin Handoff Slice

- **Goal**: Peak-admin deep link; first-load + mounted re-entry
- [x] `lib/providers/objectbox_admin_provider.dart` - expand pending handoff to peak id + search text; consume once from build and re-entry refresh
- [x] `lib/screens/objectbox_admin_screen.dart` - apply pending handoff on visible-entry refresh path; preserve existing branch-refresh behavior
- [x] `lib/screens/objectbox_admin_screen_controls.dart` - add stable search-field key; keep controller/state sync intact
- [x] `lib/screens/map_screen.dart` - send read-only popup admin handoff with peak id + search text
- [x] `lib/screens/map_screen_panels.dart` - add read-only `Edit in Peak Admin` button and hide it during inline editing
- [x] `test/robot/objectbox_admin/objectbox_admin_robot.dart` - add helpers/assertions for search field, selected entity, selected row
- [x] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - cover popup -> admin handoff on first admin load and already-mounted admin branch
- [x] `test/widget/map_screen_peak_info_test.dart` - cover read-only `Edit in Peak Admin` presence and edit-mode disable/block behavior
- [x] TDD: pending handoff on first admin build -> Peak entity + filtered rows + selected row + prefilled search
- [x] TDD: pending handoff on mounted admin re-entry -> refresh consumes pending state once + same visible result
- [x] TDD: inline edit dirty state -> admin handoff hidden/disabled; no silent draft loss
- [x] Robot journey tests + selectors/seams for critical flows: first-load + re-entry admin handoff; key `objectbox-admin-search-field`; seam via fake admin repository + reset-on-consume pending state
- [x] Verify: `flutter analyze && flutter test`

## Risks / Out of scope

- **Risks**: local popup edit state drifting from provider popup state; shell-nav re-entry timing in ObjectBox Admin; coord helper extraction broadening beyond popup needs
- **Out of scope**: raw coordinate editing in popup; admin auto-enter edit mode; popup display rows for `sourceOfTruth` or `verified`
