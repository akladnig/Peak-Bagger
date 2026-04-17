---
title: Recalculate Track Statistics ObjectBox Write Path
date: 2026-04-17
work_type: bugfix
tags: [objectbox, recalc, relations]
confidence: high
references: [ai_specs/010-peak-track-correlation-spec.md, ai_specs/010-peak-track-correlation-plan.md, lib/providers/map_provider.dart, lib/services/gpx_track_repository.dart, lib/screens/settings_screen.dart, test/widget/gpx_tracks_shell_test.dart]
---

## Summary

Recalculate Track Statistics was failing with an ObjectBox storage 404 after peak-correlation work introduced a `ToMany<Peak>` relation on `GpxTrack`. The failure was not in the matching logic; it came from the persistence strategy. Deleting every track and reinserting mutated relation-bearing entities was brittle, so recalc was changed to clone each track and replace it in place with the original ObjectBox id.

## Reusable Insights

- When an ObjectBox entity gains relations, avoid bulk `deleteAll()` + reinsert flows unless you are intentionally rebuilding the store.
- For maintenance jobs that rewrite every row, prefer:
  - load rows
  - clone each row into a fresh entity instance
  - recompute derived fields and relations on the clone
  - call a `replaceTrack(existing:, replacement:)` style API that copies the original id before `put()`
- This keeps updates atomic per entity and avoids relation-table churn that can surface as native ObjectBox storage errors.
- A 404 `OBX_ERROR` during recalc is a symptom to inspect the write path first, not the correlation math. In this session, the correlation service was already correct; the crash came from how results were persisted.
- When a maintenance action also refreshes derived state like peak correlation, make that explicit in the UI copy and spec so tests assert the intended behavior rather than an implied side effect.

## Decisions

- Recalc now uses `GpxTrackRepository.replaceTrack(existing:, replacement:)` instead of delete-and-reinsert.
- The clone path uses `GpxTrack.fromMap(track.toMap())` plus copied relations so the replacement starts from a clean entity snapshot.
- Spec/plan text was updated to state that Recalculate Track Statistics refreshes both statistics and peak correlation.

## Pitfalls

- `GpxTrack.peaks` plus `peakCorrelationProcessed` means old tests and admin views can look stale if they still assume flat entities.
- Bulk replace logic that worked before relations were introduced may start failing once ObjectBox needs to maintain link rows.
- UI labels like “Recalculate Track Statistics” can hide a derived-state refresh; write tests against the actual result text and the persisted state.

## Validation

- `flutter test test/widget/gpx_tracks_shell_test.dart test/widget/gpx_tracks_summary_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart test/services/track_peak_correlation_service_test.dart test/services/objectbox_admin_repository_test.dart`
- `flutter analyze`

## Follow-ups

- If additional batch maintenance flows are added for relation-bearing entities, default to in-place replacement instead of wholesale deletion.
- Keep admin/debug views aligned with generated ObjectBox schema so missing fields do not get mistaken for stale data.
