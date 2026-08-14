---
type: Spec
title: Map Track and Route Info Popup Icons
---

## Problem

The map screen's shared track and route information popup presents the entity name without a visual type cue. Its track peak-correlation removal control uses a less explicit, non-destructive-styled delete icon.

## Proposed Outcome

Make the map track/route info popup immediately distinguish a completed Track from a planned Route and make its in-scope destructive correlation-removal action visually clear, without changing behavior or other UI surfaces.

## User Stories

1. As a map user viewing a Track or Route, I can identify its type from the icon next to its name in the info popup.
2. As a map user removing a Track's peak correlation, I can recognize the action as destructive from the red permanent-delete icon.

## Requirements

1. In `MapTrackInfoPanel`, show `Icons.hiking` immediately before the displayed name when presenting a Track. [L1] [L2]
2. In `MapTrackInfoPanel`, show `Icons.route` immediately before the displayed name when presenting a Route. [L1] [L2]
3. Preserve the existing display-name fallbacks: `Unnamed Track` and `Unnamed Route`. The type icon must still be present for either fallback. [L2]
4. Replace the track-info popup peak-correlation removal control's idle `Icons.delete_outline` with `Icons.delete_forever` colored red. [L3]
5. Preserve the removal control's existing key, semantics label, tooltip, confirmation flow, disabled/busy indicator, callback, and inline error behavior. [L3]
6. Do not add a delete action to route info. [L3]
7. Do not change search, ObjectBox Admin, peak-info popup, peak-ascent rows, dialogs, the track/route chooser, or any other UI surface. [L1]

## Technical Decisions

1. Implement the change solely in `lib/screens/map_screen_panels.dart` within `MapTrackInfoPanel` and its existing track correlation row, using the panel's existing `isRoute` branch as the source of truth. [L1] [L2] [L3]
2. Do not introduce state, persistence, service, navigation, async, or external-service changes. The panel's existing callback and local busy/error state remain authoritative. [L3]

## Testing Strategy

1. Extend the existing `MapTrackInfoPanel` widget tests in `test/widget/map_screen_track_info_test.dart` and `test/widget/map_screen_route_info_test.dart` to assert the appropriate header `Icon` for a Track and a Route, including the existing unnamed-name fallback cases when covered.
2. Extend the existing track-info correlation-removal widget test to assert that its idle icon is `Icons.delete_forever` with red color, while retaining the existing verification of its key and behavior.
3. No robot coverage, external service fake, new Test Seam, network verification, or accessibility-navigation change is required: this is a synchronous visual-only update within the existing widget test seam.
4. Verify with `flutter test test/widget/map_screen_track_info_test.dart test/widget/map_screen_route_info_test.dart test/widget/map_track_info_panel_test.dart` and `flutter analyze`.

## Out of Scope

1. Icons or delete styling outside the map screen's track/route information popup. [L1]
2. Changing the popup's navigation, close, edit, export, confirmation, loading, error, or persistence behavior. [L3]
