## Overview

Peak name in dialog title tappable; navigates to map centered on peak at zoom 15.

**Spec**: None (quick plan from task description)

## Context

- **Structure**: Feature-first; widgets in `lib/widgets/`
- **State management**: Riverpod; `mapProvider.notifier.updatePosition`
- **Reference implementations**: `lib/widgets/peak_list_peak_dialog.dart`, `lib/providers/map_provider.dart`
- **Assumptions/Gaps**: None

## Plan

### Phase 1: Peak name tap → map navigation [x]

- **Goal**: Tap peak name; navigate to map centered on peak at zoom 15.
- [x] `lib/widgets/peak_list_peak_dialog.dart` - wrap title `Text` with `GestureDetector` (view mode only); add `_navigateToPeakOnMap()` calling `updatePosition(LatLng(peak), 15.0)` then `_closeDialogAndGoMap()`; add key `peak-list-peak-name`
- [x] TDD: tapping peak name updates map center to peak coords + zoom 15; dialog closes
- [x] Verify: `flutter analyze` && `flutter test test/widget/peak_list_peak_dialog_test.dart` (note: pre-existing drag test failure unrelated to this change)

## Risks / Out of scope

- **Risks**: Dialog must close before map branch activates (handled by existing `_closeDialogAndGoMap` post-frame callback)
- **Out of scope**: Peak info popup on map; other dialog text tappable
