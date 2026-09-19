---
type: Work Item
title: Track and Saved Route Panel Summaries and Controls
parent: ../spec.md
---

## What to build

Update the Track and saved Route information panel summaries and Track highest-elevation rows to display the exact compact, profile-derived values required by the Spec. Apply pointing-cursor behavior only to enabled pointer-selectable controls in these panels, preserving existing control behavior, accessibility, and the disabled recalculation state.

## Required context

- `lib/screens/map_screen_panels.dart` contains `MapTrackInfoPanel`, the 3:2 `_LabeledValueRow`, Track highest-elevation derivation, and Track/saved Route controls. Use `ElevationProfileSeriesBuilder.fromTrackProfileJson` from Work Item 01 rather than persisted `distanceToPeak` or `distanceFromPeak` fields.
- `UiConstants.preferredLeftWidth` is 360.0 in `lib/core/constants.dart`; the highest-elevation rows must remain single unclipped lines at this width.
- Preserve existing control keys and semantic labels used by `test/widget/map_track_info_panel_test.dart`, `test/widget/map_route_info_panel_test.dart`, `test/widget/map_screen_track_info_test.dart`, and `test/widget/map_screen_route_info_test.dart` as stable selectors.
- Follow the repository's existing widget-test style. No robot coverage, new test seams, fakes beyond in-memory model fixtures, API keys, or live network calls are required.

## Acceptance criteria

- [x] Track and saved Route summary values for `Distance (2d/3d)` render as unitless one-decimal kilometre values in the exact form `xx.x / yy.y`; the existing label remains unchanged.
- [x] Every Track with processed peak-correlation statistics and a valid Track highest-elevation profile position shows `To highest elevation` and `From highest elevation`, regardless of correlated `Peak` count. Both values target the first maximum recorded elevation sample, derive `To` from its `distanceMeters`, and derive `From` from the final sample's `distanceMeters` minus that value; no persisted `distanceToPeak` or `distanceFromPeak` values are used.
- [x] When the complete timestamp contract is usable, each highest-elevation value renders as `XX.X km / HH:MM`: elapsed recorded time includes pauses, is calculated only from the first, first maximum-elevation, and final profile timestamps, rounds to the nearest minute, and has zero-padded total hours that do not wrap at 24. When timestamps are unusable, each applicable row retains only its distance and never substitutes unknown, zero, estimated, or moving time.
- [x] At `UiConstants.preferredLeftWidth`, the complete highest-elevation labels and values share one non-overlapping, unclipped line through the existing 3:2 label-to-value `_LabeledValueRow` allocation.
- [x] Every enabled pointer-selectable control in the Track and saved Route panels has `SystemMouseCursors.click`, while disabled controls retain the default cursor. Covered controls are Export; Recalculate Track Statistics; Route edit and close; peak-correlation removal; visibility; route timing info and recalculation; and walking-speed decrement, text-input, and increment controls. Do not change cursor behavior elsewhere in the app.
- [x] Touch interaction, keyboard accessibility, existing semantic labels, existing enabled states, and the disabled-in-progress behavior of Recalculate Track Statistics remain unchanged.
- [x] Update panel and map-host widget tests with deterministic inline `GpxTrack.elevationProfile` fixtures covering compact distances; processed Tracks without correlated Peaks; profile-derived to/from distance; profile-only timestamp calculation; nearest-minute rounding; elapsed times over 24 hours; missing and non-chronological timestamps; and the preferred-width non-overlapping rows.
- [x] Add widget assertions for click/default cursors on all covered enabled/disabled panel controls, preserving their touch behavior, keyboard operation, and existing semantic labels and keys.
- [ ] Run `flutter analyze`, then run `flutter test test/services/elevation_profile_series_builder_test.dart test/widget/elevation_profile_chart_test.dart test/widget/map_track_info_panel_test.dart test/widget/map_route_info_panel_test.dart test/widget/map_screen_track_info_test.dart test/widget/map_screen_route_sheet_test.dart`, followed by `flutter test`.

## Verification Note

- `flutter analyze` reports five pre-existing info-level lint suggestions in route-graph services and no findings in this work item's files.
- The required focused test command passes.
- `flutter test` was attempted three times but stalled in unrelated widget and robot tests before the runner timeout terminated Flutter subprocesses. No product test assertion failed before termination.

## Covers

- User Stories: 1, 3
- Requirements: 1-4; 9-10 (Track and saved Route panel portions)
- Technical Decisions: 2, 4
- Testing Strategy: 1, 3-4
- Interview Ledger: L1, L2, L3, L6

## Blocked by

01-shared-elevation-profile-timestamp-and-hover-ui.md
