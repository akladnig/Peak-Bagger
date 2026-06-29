## Overview

Unify popup shell, tokens, dismiss paths. Keep special layouts intact.

**Spec**: `./ai_specs/popup-consistency-spec.md` (read this file for full requirements)

## Context

- **Structure**: mixed; shared primitives in `lib/core/`, UI in `lib/screens/` + `lib/widgets/`
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/map_screen_panels.dart`, `lib/widgets/gpx_import_dialog.dart`, `test/widget/gpx_import_dialog_test.dart`, `test/robot/map/route_info_journey_test.dart`
- **Assumptions/Gaps**: macOS `Ctrl+C` intentionally mapped to dismiss; `GpxImportDialog` keeps custom outer `Dialog` + measurement logic

## Plan

### Phase 1: Core Shell Slice

- **Goal**: prove shared shell + keyboard dismiss end-to-end
- [x] `lib/core/constants.dart` - add `PopupUIConstants`; radius/padding/close-icon/spacing tokens
- [x] `lib/core/widgets/popup_shell.dart` - reusable full shell for transient overlays; header/body/actions slots; explicit close affordance
- [x] `lib/core/widgets/popup_keyboard_dismiss.dart` - shared `Escape` / `Ctrl+C` dismiss wrapper
- [x] `lib/screens/map_screen_panels.dart` - migrate one representative transient overlay; prefer `MapInfoPopupCard` or `TrackRouteChooserPopup`
- [x] `lib/screens/map_screen.dart` - preserve existing close callbacks after shell adoption
- [x] `test/widget/` - add first shell/widget regression around header padding + close + keyboard dismiss
- [x] `test/robot/map/` - add one popup robot journey; open overlay, dismiss via close, dismiss via keyboard
- [x] TDD: shell renders shared header/body/actions contract; then implement minimal shell
- [x] TDD: `Escape` closes representative overlay via existing callback; then add keyboard wrapper
- [x] TDD: `Ctrl+C` on macOS mirrors `Escape`; then wire shortcut mapping
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Overlay Family + GPX Dialog

- **Goal**: migrate remaining transient overlays; align custom GPX dialog
- [x] `lib/screens/map_screen_panels.dart` - migrate `RouteTimingInfoDialog`, `MapTapActionPopupCard`, `FavouritesPopupCard`, `PeakInfoPopupCard`, `DriveEtaPopupCard`, `RouteDraftMarkerDeletePopupCard`, `TrackRouteChooserPopup`
- [x] `lib/screens/map_screen.dart` - pass any new close callbacks / keys; keep placement logic unchanged
- [x] `lib/widgets/gpx_import_dialog.dart` - adopt shared shell chrome for visible header/body/actions; keep outer `Dialog`, measurement, growth/scroll behavior
- [x] `test/widget/gpx_import_dialog_test.dart` - update layout assertions to tokenized shell values; add keyboard dismiss coverage
- [x] `test/widget/` - add representative overlay regressions for explicit close affordance on formerly dismiss-only surfaces
- [x] `test/robot/map/` - extend popup robot journeys for one formerly dismiss-only overlay
- [x] TDD: each migrated overlay preserves existing dismiss callback + gains explicit close affordance
- [x] TDD: `GpxImportDialog` keeps measured scrolling/layout behavior while adopting shell chrome
- [x] TDD: `GpxImportDialog` closes on `Escape` and `Ctrl+C`; then implement wrapper usage
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Dialog Helpers + Peak List Panel

- **Goal**: normalize modal dialogs; align bespoke peak-list panel
- [ ] `lib/widgets/dialog_helpers.dart` - normalize action hierarchy; remove `showExportConflictDialog` hover-primary swap; add shared keyboard dismiss where dialog is dismissible
- [ ] `lib/screens/settings_screen.dart` - route ad-hoc dialogs through shared dialog action/keyboard pattern where in scope
- [ ] `lib/widgets/peak_list_create_dialog.dart` - keep `AlertDialog`; adopt shared keyboard dismiss + shared action pattern
- [ ] `lib/widgets/peak_list_import_dialog.dart` - keep `AlertDialog`; adopt shared keyboard dismiss + shared action pattern
- [ ] `lib/widgets/peak_list_peak_dialog.dart` - adopt `PopupUIConstants` tokens + keyboard dismiss; keep drag behavior/layout structure
- [ ] `test/widget/` - add helper-dialog regressions for action ordering + keyboard dismiss
- [ ] `test/robot/` - add one modal dialog journey; open, cancel, confirm, dismiss by keyboard
- [ ] TDD: confirm dialogs preserve return values while action emphasis/order normalize
- [ ] TDD: `PeakListPeakDialog` visual tokens align without regressing drag/save/delete flows
- [ ] TDD: keyboard dismiss disabled while save/import work blocks exit
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: keyboard shortcut conflicts in focused popups; shell adoption breaking `GpxImportDialog` measurement math; broad popup churn across map screen keys/tests
- **Out of scope**: global theme redesign; business logic/result payload changes; non-popup admin/detail panes
