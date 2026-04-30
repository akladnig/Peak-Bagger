---
title: Single-track import keeps correlated peaks ticked
date: 2026-04-29
work_type: bugfix
tags: [flutter, riverpod, testing]
confidence: high
references: [lib/providers/map_provider.dart, test/providers/map_provider_import_test.dart, test/widget/tasmap_map_screen_test.dart, test/robot/gpx_tracks/single_track_import_journey_test.dart, ai_specs/single-track-import-ticked-peak-plan.md]
---

## Summary
We fixed a regression where importing one GPX track did not immediately tick correlated peaks on `MapScreen`.

The durable fix was to derive `correlatedPeakIds` from `state.tracks` instead of maintaining a separate cache, then refresh that derived state after import.

## Reusable Insights
- Prefer derivation over synchronization for UI state like correlated peak markers. A cached set can go stale after import unless every mutation path updates it.
- For Riverpod notifier tests, inject every late-initialized dependency the notifier touches. If `build()` falls back to `objectboxStore`, a widget test can fail before the real scenario runs.
- When a widget test starts pulling in ObjectBox, tile backends, or router shell state, consider a narrower regression that exercises the notifier directly. That kept this fix stable and fast.
- Use an in-memory repository for write-heavy regression tests when the behavior under test is state transition, not persistence.

## Pitfalls
- `pumpAndSettle()` can hide or amplify hangs in dialog-driven flows.
- ObjectBox/native-library setup is fragile in `flutter test` unless the test really needs persistence.
- Router shells can introduce unrelated provider failures; direct notifier assertions are often enough for a focused regression.

## Validation
- `HOME="$(mktemp -d)" flutter test test/robot/gpx_tracks/single_track_import_journey_test.dart`
- `flutter analyze`
- `HOME="$(mktemp -d)" flutter test`
