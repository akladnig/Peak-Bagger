---
type: Work Item
title: Add Map Track/Route Info Popup Icons
parent: ../spec.md
---

## What to build

Update `MapTrackInfoPanel` and its existing track peak-correlation row in `lib/screens/map_screen_panels.dart` only. Display `Icons.hiking` immediately before the Track display name and `Icons.route` immediately before the Route display name, retaining the `Unnamed Track` and `Unnamed Route` fallbacks with their type icon. Replace only the track-info popup peak-correlation removal control's idle `Icons.delete_outline` with red `Icons.delete_forever`.

Do not change the removal control's key, semantics label, tooltip, confirmation flow, disabled/busy indicator, callback, or inline error behavior. Do not add a delete action to route info. Do not change search, ObjectBox Admin, peak-info popup, peak-ascent rows, dialogs, the track/route chooser, navigation, state, persistence, services, async behavior, or any other UI surface.

## Required context

- `lib/screens/map_screen_panels.dart`: Use `MapTrackInfoPanel`'s existing `isRoute` branch as the source of truth; preserve its local peak-correlation removal state and callback behavior.
- `test/widget/map_screen_track_info_test.dart`, `test/widget/map_screen_route_info_test.dart`, and `test/widget/map_track_info_panel_test.dart`: Extend the established widget-test seams and retain the existing control key and behavior assertions.
- `GLOSSARY.md`: A Track is a completed recorded walk; a Route is a planned future path; a peak correlation associates a Peak with a completed Track.

## Acceptance criteria

- [x] `MapTrackInfoPanel` displays `Icons.hiking` immediately before every Track display name, including `Unnamed Track`.
- [x] `MapTrackInfoPanel` displays `Icons.route` immediately before every Route display name, including `Unnamed Route`.
- [x] The track peak-correlation removal control displays an idle red `Icons.delete_forever` icon.
- [x] The removal control retains its existing `map-track-correlation-remove-<trackId>-<peakOsmId>` key, `Remove peak correlation` semantics label and tooltip, confirmation flow, disabled/busy indicator, callback, and inline error behavior.
- [x] Route info does not gain a delete action.
- [x] No UI surface outside the map screen Track/Route info popup changes.
- [x] Widget tests assert the Track and Route header icons, including the covered unnamed-name fallbacks, and assert the idle red `Icons.delete_forever` icon while retaining existing key and behavior coverage.
- [x] `flutter test test/widget/map_screen_track_info_test.dart test/widget/map_screen_route_info_test.dart test/widget/map_track_info_panel_test.dart` passes.
- [x] `flutter analyze` passes.

## Covers

- User Stories: 1-2
- Requirements: 1-7
- Technical Decisions: 1-2
- Testing Strategy: 1-4
- Interview Ledger: L1-L3

## Blocked by

None - ready to start
