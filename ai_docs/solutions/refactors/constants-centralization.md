---
title: Centralize shared app constants
date: 2026-05-04
work_type: refactor
tags: [flutter, constants, refactor]
confidence: high
references: [lib/core/constants.dart, lib/providers/map_provider.dart, lib/providers/gpx_filter_settings_provider.dart, lib/providers/peak_correlation_settings_provider.dart, lib/models/gpx_track.dart, lib/screens/map_screen.dart, lib/screens/peak_lists_screen.dart, ai_specs/constants-refactor-plan.md]
---

## Summary

Moved shared constants out of feature files into `lib/core/constants.dart` and updated call sites across providers, services, models, screens, and widgets.
Kept shared preference keys local to their owning providers and preserved behavior with focused test updates.

## Reusable Insights

- Group constants by domain, not by file that happened to define them first: map defaults, geo bounds, GPX defaults, correlation settings, router layout, and UI layout all had clear homes.
- Keep persistence keys local unless there is a real cross-feature reuse need; extracting values should not force a key-namespace abstraction.
- When a refactor changes defaults, update the provider test first so the new behavior is explicit and the persistence round-trip stays honest.
- Centralized UI constants are easiest to adopt when they are pure dimensions or durations with no hidden behavior.
- If multiple files share the same zoom limits, define them once and reuse them in both data helpers and screen clamps to avoid drift.

## Decisions

- `GpxFilterConfig.defaults` now uses `hampelWindow: 5` and `none` filters/smoothers.
- `MapConstants.peakMinZoom` and `MapConstants.peakMaxZoom` are the single zoom bounds used by track display and map UI.
- `peakCorrelationDistanceKey` stayed local in `peak_correlation_settings_provider.dart`.
- `UiConstants` absorbed the scattered layout values used by map, peak list, dialog, rail, and admin table UI.

## Validation

- `flutter analyze`
- `flutter test`

## Pitfalls

- Refactors that touch defaults can silently change persisted behavior unless provider tests assert both the new defaults and the restore path.
- UI constant moves can ripple into widget tests even when behavior is unchanged, so update only the assertions that encode layout specifics.
