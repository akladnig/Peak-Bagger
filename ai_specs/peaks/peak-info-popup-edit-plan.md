## Overview

Add a peak-edit action to the map peak popup; keep yellow-marker behavior unchanged.
Popup edit click should jump to ObjectBox Admin for the same peak row.

**Spec**: `ai_specs/peaks/peak-info-popup.md`

## Context

- **Structure**: feature-first Flutter screens + shared popup widget
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/map_screen_panels.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/screens/objectbox_admin_screen.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/widget/objectbox_admin_shell_test.dart`
- **Assumptions/Gaps**: popup is shared with peak-lists screen; keep edit button map-only via optional callback. Target = open Peak row in admin, not route-only jump.

## Plan

### Phase 1: Popup action + route target

- **Goal**: add edit icon left of drop-marker icon; wire click to admin target
- [ ] `lib/screens/map_screen_panels.dart` - add optional `onEdit` to `PeakInfoPopupCard`/`PeakInfoPopupSurface`; render `Icons.edit` button before `peak-info-popup-drop-marker`; stable key + tooltip
- [ ] `lib/screens/map_screen.dart` - pass edit callback from peak popup; navigate to ObjectBox Admin with peak id payload
- [ ] `lib/screens/objectbox_admin_screen.dart` - accept peak target payload; select Peak entity + matching row on entry; preserve existing row selection refresh behavior
- [ ] `lib/router.dart` - thread target payload into `/objectbox-admin` route builder
- [ ] TDD: popup shows edit button only when callback supplied; button order stays edit then drop-marker; navigation request carries peak id
- [ ] Robot: map popup edit path lands on admin screen with Peak entity/row selected; stable keys for popup action and admin row
- [ ] Verify: `flutter analyze` && `flutter test test/widget/map_screen_peak_info_test.dart test/widget/objectbox_admin_shell_test.dart test/robot/objectbox_admin/objectbox_admin_journey_test.dart`

## Risks / Out of scope

- **Risks**: shared popup reuse with peak-lists screen; admin auto-selection needs a clean entry payload
- **Out of scope**: auto-entering peak edit mode unless the admin screen already supports it cheaply
