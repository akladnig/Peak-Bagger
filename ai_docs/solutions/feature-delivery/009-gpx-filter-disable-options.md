---
title: GPX filter disable options
date: 2026-04-24
work_type: feature
tags: [flutter, riverpod, testing]
confidence: medium
references:
  - ai_specs/009-add-filter-options-spec.md
  - ai_specs/009-add-filter-options-plan.md
  - lib/providers/gpx_filter_settings_provider.dart
  - lib/screens/settings_screen.dart
  - lib/services/gpx_track_filter.dart
  - test/services/gpx_filter_settings_provider_test.dart
  - test/services/gpx_track_filter_test.dart
  - test/services/gpx_importer_filter_test.dart
  - test/widget/gpx_filter_settings_test.dart
  - test/robot/gpx_tracks/gpx_tracks_robot.dart
  - test/robot/gpx_tracks/gpx_tracks_journey_test.dart
---

## Summary

Added a new `Outlier Filter` control and `None` choices for elevation/position smoothing, while keeping the Hampel window unchanged. Disabled stages now preserve their saved values and re-enable cleanly.

## Reusable Insights

- Explicit enum states were simpler than nullable/sentinel windows. They kept `copyWith`, persistence, and UI labels predictable.
- When a parent selector disables a child control, keep the stored value and disable the widget. Re-enable should restore the previous value, not reset it.
- For long settings screens, robot helpers need stable `Key` selectors plus real scrolling. Off-screen taps are a common source of flaky journey tests.
- If a widget test only needs persistence, direct provider mutation is often more stable than trying to drive a dropdown menu through every overlay step.
- Add a focused test slice first: provider round-trip, service gating, importer integration, widget labels/disabled state, then robot persistence.

## Decisions

- Kept the Hampel window options unchanged.
- Used a new `GpxTrackOutlierFilter` enum plus `none` enum values on the existing smoother enums.
- Disabled child windows visually instead of hiding them.

## Pitfalls

- `DropdownButtonFormField` plus repeated `None` labels can make finders ambiguous; use stable keys and avoid broad text-only assertions.
- Full `flutter test` still exposed unrelated baseline failures in existing GPX selection tests; validate the changed slice separately when needed.

## Validation

- `flutter analyze` passed.
- Targeted tests passed: `test/services/gpx_filter_settings_provider_test.dart`, `test/services/gpx_track_filter_test.dart`, `test/services/gpx_importer_filter_test.dart`, `test/widget/gpx_filter_settings_test.dart`, `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`.
