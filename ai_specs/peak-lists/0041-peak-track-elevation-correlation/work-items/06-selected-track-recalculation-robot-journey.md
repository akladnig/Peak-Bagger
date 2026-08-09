---
type: Work Item
title: Selected-Track Recalculation Robot Journey
parent: ../spec.md
---

## What to build

Extend the existing GPX-track robot helpers and a selected-Track journey test to select a Track, confirm individual recalculation, and verify the panel remains open with refreshed peak-correlation output. Use the stable keys and deterministic seams added by the panel and notifier slices.

## Required context

- `test/robot/gpx_tracks/gpx_tracks_robot.dart` contains current GPX-track panel and global-recalculation helpers.
- `test/robot/gpx_tracks/selection_journey_test.dart` contains the selected-Track and open-panel journey; `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` covers global recalculation.
- `test/harness/test_map_notifier.dart` and the existing in-memory repositories are the deterministic provider/repository fakes for robot tests.
- Depend on stable UI selectors from `05-selected-track-recalculation-panel-flow.md`; do not add independent test infrastructure.

## Acceptance criteria

- [x] Robot helpers expose stable selectors and actions for the selected-Track recalculation button, confirmation action, inline busy indicator, and success/error result surfaces.
- [x] A deterministic robot journey selects a Track, confirms `Recalculate Track Statistics`, and verifies the panel remains open with refreshed correlation output.
- [x] The journey uses deterministic fixtures and existing provider/repository fakes, with no real GPX files, ObjectBox databases, network services, or SharedPreferences outside established mocks.

## Covers

- User Stories: 3
- Requirements: 10-15
- Testing Strategy: 6
- Interview Ledger: L7, L9

## Blocked by

05-selected-track-recalculation-panel-flow.md
