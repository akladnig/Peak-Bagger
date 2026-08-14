---
type: Spec
title: SVG Asset Location Updates
---

## Problem

`peak_marker.svg`, `peak_marker_ticked.svg`, and `route.svg` have moved from the root `assets/` directory to `assets/svg/`. `MapActionRail` still loads the route icon through the deleted root-level path, so the Create Route FAB cannot resolve its icon at runtime.

## Proposed Outcome

All in-scope SVG references use the `assets/svg/` asset directory, preserving existing peak-marker runtime-removal boundaries and all Create Route behavior.

## User Stories

1. As a map user, I can see the Create Route FAB icon after the SVG assets are reorganized.

## Requirements

1. Update `MapActionRail` to load the Create Route icon from `assets/svg/route.svg`. [L1]
2. Treat `assets/svg/peak_marker.svg`, `assets/svg/peak_marker_ticked.svg`, and `assets/svg/route.svg` as the canonical locations for the moved SVG assets. [L1]
3. Do not reintroduce runtime references to either peak-marker SVG: the current peak-marker rendering path remains intentionally removed. [L1]
4. Preserve the Create Route FAB's key (`create-route-fab`), tooltip, disabled state, callback behavior, navigation, and SVG dimensions and color filter. [L1]

## Technical Decisions

1. Retain `assets/svg/` as the Flutter asset-directory registration in `pubspec.yaml`; it already bundles the canonical SVG locations. Do not add individual root-level SVG registrations. [L1]
2. The asset relocation changes no state, persistence, navigation, async handling, external service, secret, accessibility, responsive-layout, or text-scale behavior. [L1]

## Testing Strategy

1. Extend `test/widget/map_action_rail_grouping_test.dart` to assert that the `SvgPicture` beneath `create-route-fab` uses `assets/svg/route.svg` while preserving the existing route-FAB grouping and disabled-state checks. [L1]
2. Preserve `test/widget/peak_runtime_asset_removal_test.dart` as the static regression boundary that prevents root-level peak-marker paths from being restored to runtime code or `pubspec.yaml`. [L1]
3. No robot coverage, fake, new Test Seam, network call, or API key is required: the change is a synchronous packaged-asset path update covered by the existing widget test seam. [L1]
4. Verify with `flutter test test/widget/map_action_rail_grouping_test.dart test/widget/peak_runtime_asset_removal_test.dart` and `flutter analyze`.

## Out of Scope

1. Changing peak-marker rendering, clustering, route creation, or any other map action behavior. [L1]
2. Moving unrelated SVGs or changing the contents of the three moved SVG files. [L1]
