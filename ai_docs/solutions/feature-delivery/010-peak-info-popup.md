---
title: Peak Info Popup Delivery
date: 2026-04-30
work_type: feature
tags: [flutter, map-interactions, testing]
confidence: high
references: [ai_specs/010-peak-info-spec.md, ai_specs/010-peak-info-plan.md, lib/screens/map_screen.dart, lib/providers/map_provider.dart, test/widget/map_screen_peak_info_test.dart, test/robot/peaks/peak_info_journey_test.dart]
---

## Summary

Delivered peak hover and click interactions on the Flutter map: central screen-space peak hit testing, hover cursor/halo, anchored peak info popup, content rows for height/map/list memberships, deterministic placement, lifecycle cleanup, and robot journey coverage.

The most important design choice was keeping peak popup state separate from the existing center-based map info popup. Peak clicks now resolve centrally in the map pointer path before track or background map behavior, which prevents double handling and preserves existing non-peak selection behavior.

## Reusable Insights

- Prefer central map hit testing over marker-child gestures when an interaction must suppress downstream map behavior. In this feature, peak hit testing in `MapScreen.onPointerUp` cleanly prevented selected-location and track selection side effects.
- Keep transient UI state independent when two popups represent different concepts. `showInfoPopup` remained center-based, while `PeakInfoContent? peakInfo` modeled peak-specific state.
- Match hit-test candidate order to render order. The detector keeps exact-distance ties deterministic by preserving the first candidate, so candidates must follow `buildPeakMarkers` ordering.
- Put placement math behind a pure helper. `resolvePeakInfoPopupPlacement` made right placement, left flip, vertical clamp, and unanchorable behavior easy to cover without fragile widget geometry tests.
- Close popups from every lifecycle path that can invalidate the anchor: background click, zoom below marker threshold, hiding peaks, removed peak data, offscreen placement, keyboard shortcuts, action rail transient UI cleanup, and shell navigation.
- Shared provider definitions are safer than importing screen-local providers into unrelated features. Moving peak-list providers out of `peak_lists_screen.dart` made popup membership resolution reusable.
- Robot tests need stable selectors at the visual target and hitbox levels. `peak-marker-$osmId`, `peak-marker-hitbox-$osmId`, `peak-info-popup`, and `peak-info-popup-close` gave the journey tests durable handles.

## Decisions

- Peak popup content resolves map names from complete peak MGRS first, falls back to lat/lng-derived MGRS, then displays `Unknown`.
- Malformed peak-list payloads are skipped during membership lookup so one bad list cannot break popup rendering.
- Hover highlight is a ring overlay that preserves existing ticked/unticked SVG assets.
- Opening a peak popup closes the center info popup, and opening the center info popup closes any peak popup.

## Pitfalls

- Wrapping marker assets in `KeyedSubtree` for stable selectors changed test assumptions that `Marker.child` was directly an `SvgPicture`. Existing asset assertions and robots needed to unwrap keyed children.
- Full app tests produce noisy `RootUnavailable` and `flutter_map` tile warnings; rely on final analyzer/test status rather than the noise.
- Navigating to routes with unrelated provider requirements can make route-cleanup tests fail for the wrong reason. Use the simplest route that exercises shell cleanup.

## Validation

- `flutter analyze`
- `flutter test`
- Focused coverage included `test/services/peak_hover_detector_test.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/widget/peak_info_popup_placement_test.dart`, `test/widget/map_screen_keyboard_test.dart`, and `test/robot/peaks/peak_info_journey_test.dart`.

Confidence is high because the feature has unit, widget, and robot coverage across hit testing, popup content, placement, cleanup, and core user journeys.
