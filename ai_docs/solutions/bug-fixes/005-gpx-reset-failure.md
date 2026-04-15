---
title: Fix GPX reset failures from stale ObjectBox metadata
date: 2026-04-14
work_type: bugfix
tags: [objectbox, gpx, reset]
confidence: high
references: [lib/models/gpx_track.dart, lib/objectbox-model.json, lib/objectbox.g.dart, lib/providers/map_provider.dart, lib/screens/settings_screen.dart, lib/services/gpx_importer.dart]
---

## Summary
Reset Track Data was failing because `GpxTrack` changed to `@Id(assignable: true)` but the generated ObjectBox model was stale. The runtime model still treated `gpxTrackId` as a normal auto ID, so reset/import could fail during persistence and the UI would only show a partial import count or no dialog at all.

## Reusable Insights
- When changing ObjectBox entity annotations, regenerate both `lib/objectbox-model.json` and `lib/objectbox.g.dart`; tests can pass while the real app still fails with stale metadata.
- If a reset flow returns `null` on failure, surface an explicit error dialog in the UI instead of relying on a status summary that may never render.
- Use the actual operation result for success dialogs. If the notifier swallows exceptions, add a separate failure path that reads `trackImportError`.
- For destructive rebuilds, validate the generated model first if the app imports only a few rows or never reaches the completion dialog.

## Validation
- Regenerated ObjectBox with `flutter pub run build_runner build --delete-conflicting-outputs`.
- Confirmed `gpxTrackId` is flagged as assignable in the generated model.
- Ran:
  - `flutter test test/gpx_track_test.dart`
  - `flutter test test/widget/gpx_tracks_shell_test.dart`
  - `flutter test test/robot/gpx_tracks/recovery_journey_test.dart`

## Pitfalls
- The reset issue looked like an import filtering problem, but the actual break was at the persistence layer.
- A visible dialog bug can be secondary to a hidden exception path. Check the notifier return value and the generated model before changing importer logic.
