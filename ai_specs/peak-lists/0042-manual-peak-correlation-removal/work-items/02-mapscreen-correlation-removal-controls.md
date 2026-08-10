---
type: Work Item
title: MapScreen Correlation-Removal Controls
parent: ../spec.md
---

## What to build

Add the correlation-removal flow to `MapTrackInfoPanel` and the MapScreen `PeakInfoPopupCard`. MapScreen owns confirmation presentation for both hosts and delegates the confirmed pair to the notifier mutation. The initiating panel or card owns its asynchronous saving, error, and retry state while MapScreen preserves existing popup entry, close, and back behavior.

Render compact trailing trash-icon controls after each displayed peak/elevation or ascent row. Use `map-track-correlation-remove-$trackId-$peakOsmId` in `MapTrackInfoPanel` and `peak-info-correlation-remove-$trackId-$peakOsmId` in the MapScreen peak popup. The controls have tooltip and accessible label `Remove peak correlation`. MapScreen ascent labels remain non-interactive.

## Required context

- `lib/screens/map_screen_panels.dart` contains the stateless `MapTrackInfoPanel`, shared stateful `PeakInfoPopupCard`, existing ascent-row rendering, popup lifecycle management, and existing accessible controls.
- `lib/screens/map_screen.dart` supplies selected-track panel callbacks, builds the MapScreen peak popup through `PeakInfoPopupSurface`, and owns MapScreen dialog presentation.
- `lib/widgets/dialog_helpers.dart` and nearby MapScreen flows establish dialog lifecycle and styling conventions; preserve the exact confirmation title and actions required below.
- `test/widget/map_track_info_panel_test.dart`, `test/widget/map_screen_track_info_test.dart`, `test/widget/map_screen_peak_info_test.dart`, and `test/robot/peaks/peak_info_robot.dart` contain existing panel/popup seams and MapScreen robot conventions. Depend on the mutation and refresh contract from `01-atomic-peak-correlation-removal.md`.

## Acceptance criteria

- [x] Each non-empty `Peaks Climbed` row in `MapTrackInfoPanel` has a compact trailing trash-icon control after its existing peak name and elevation with key `map-track-correlation-remove-$trackId-$peakOsmId`.
- [x] Each `My Ascents` row in the MapScreen peak popup has a compact trailing trash-icon control with key `peak-info-correlation-remove-$trackId-$peakOsmId`. MapScreen ascent labels remain non-interactive, and the trash control does not introduce track navigation.
- [x] Activating either control opens a MapScreen-owned confirmation dialog titled exactly `Remove Peak Correlation?`, names the affected peak and track, and provides exactly `Cancel` and `Remove` actions.
- [x] Cancelling or dismissing the dialog leaves all persisted records and visible content unchanged. Confirming `Remove` shows no undo affordance, success dialog, toast, or completion dialog.
- [x] While a confirmed removal is saving, disable the initiating control with a stable busy-state selector. After success, keep the initiating panel or popup open and remove its row in place. On failure, keep it open, retain the row, restore a retryable control, and show an inline error beginning exactly `Failed to remove peak correlation: ` followed by actionable detail with a stable failure-surface selector.
- [x] The panel and popup retain current sizing and styling. At text scaling through 200% within the existing 360 px track-panel and 320 px peak-popup widths, controls remain keyboard-operable, expose `Remove peak correlation`, and do not obscure or overlap the peak name, elevation, ascent date, or existing popup controls.
- [x] Widget and robot coverage uses deterministic notifier/repository fakes and stable confirmation-action, busy-state, and failure-surface selectors to prove tooltip/semantics, confirmation/cancel/dismiss behavior, saving state, retryable failure, success refresh, MapScreen non-navigation, and 200% layout behavior. It makes no external calls.

## Covers

- User Stories: 1-3
- Requirements: 2, 4-5, 8, 10-11, 13-14
- Technical Decisions: 5
- Testing Strategy: 4-5
- Interview Ledger: L1, L3, L4, L5, L6

## Blocked by

01-atomic-peak-correlation-removal.md
