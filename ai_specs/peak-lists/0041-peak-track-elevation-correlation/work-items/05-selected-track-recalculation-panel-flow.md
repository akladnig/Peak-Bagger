---
type: Work Item
title: Selected-Track Recalculation Panel Flow
parent: ../spec.md
---

## What to build

Wire the selected-Track notifier operation into `MapTrackInfoPanel`. Place a filled `Recalculate Track Statistics` button immediately above the existing `Hide this track on the map` / `Show this track on the map` switch for a selected Track only, never a Route.

Use the existing danger-confirmation dialog helper for the exact confirmation contract and the existing single-action dialog helper for result contracts. Keep the panel open during busy, success, and failure states, and refresh it from the updated selected Track after success.

## Required context

- `lib/screens/map_screen_panels.dart` contains `MapTrackInfoPanel`, its Track visibility row, and route-only body; `lib/screens/map_screen.dart` supplies panel callbacks and selected state.
- `lib/widgets/dialog_helpers.dart` provides `showDangerConfirmDialog()` and `showSingleActionDialog()`; follow the Settings screen's existing recalculation dialog pattern.
- `test/widget/map_track_info_panel_test.dart`, `test/widget/map_screen_track_info_test.dart`, and `test/widget/map_route_info_panel_test.dart` establish panel and route-exclusion coverage.
- Depend on the selected-Track notifier API and busy state from `04-atomic-single-track-recalculation.md`.

## Acceptance criteria

- [x] For a selected Track, a filled `Recalculate Track Statistics` button appears immediately above the existing `Hide this track on the map` / `Show this track on the map` switch; no such control appears for a Route.
- [x] Tapping the button uses the existing danger-confirmation dialog helper with title `Recalculate Track Statistics?`, message `This will rebuild statistics and peak correlation for this track from stored GPX XML. Do you wish to proceed?`, and `Cancel` and `Recalculate` actions.
- [x] Cancel makes no changes.
- [x] While global or selected-Track recalculation is active, the selected Track button is disabled, shows inline progress with `Recalculating...`, and the panel remains open.
- [x] After successful selected-Track recalculation, the open panel refreshes its statistics and correlated peaks, remains open behind a single-action dialog, and that dialog has title `Track Statistics Recalculated` and message `Track statistics and peak correlation were refreshed.`.
- [x] On selected-Track recalculation failure, prior persisted data remains restored, the button re-enables, the panel remains open behind a single-action dialog, and the dialog has title `Track Statistics Recalculation Failed` with actionable error text.
- [x] Stable widget keys exist for the individual-recalculation button, confirmation action, busy indicator, and success/error result surfaces.
- [x] Widget coverage verifies track-only placement, confirmation and cancel behavior, busy state, success refresh and message, failure recovery, use of the existing confirmation and single-action dialog helpers, and panel-open behavior.

## Covers

- User Stories: 3
- Requirements: 10-15
- Technical Decisions: 4-5
- Testing Strategy: 5
- Interview Ledger: L7, L8, L9

## Blocked by

04-atomic-single-track-recalculation.md
