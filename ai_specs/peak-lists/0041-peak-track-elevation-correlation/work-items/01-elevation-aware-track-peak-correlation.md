---
type: Work Item
title: Elevation-Aware Track Peak Correlation
parent: ../spec.md
---

## What to build

Extend the GPX geometry consumed by `TrackPeakCorrelationService` so each `trkpt` and supported `rtept` retains its optional `<ele>` value with latitude and longitude. Change peak correlation to require both the configured horizontal `Distance threshold` and the configured vertical `Elevation threshold`, each inclusively, without retaining a horizontal-only fallback.

At the closest position on a closest finite GPX segment, interpolate elevation linearly from the two valid endpoint elevations using the horizontal closest-point projection fraction. A one-point segment uses its point elevation. When multiple positions tie for minimum measured horizontal distance, correlate when any tied closest position meets the elevation threshold; a farther vertically valid position must not override a nearer vertically invalid position. Preserve finite-segment behavior, supported track and route geometry, and one correlated occurrence of each peak per track.

Use TDD: add one focused failing unit test before each behavior change, then make the smallest passing implementation change.

## Required context

- `lib/services/track_peak_correlation_service.dart` and `lib/services/gpx_track_geometry.dart` contain the current horizontal-only correlation and geometry parser.
- `lib/services/geo.dart` contains finite-segment closest-point handling; interpolation must use the same clamped projection rather than a line extension.
- `test/services/track_peak_correlation_service_test.dart` is the focused service suite and existing test seam.
- Use the project meanings of Track, Route, Peak elevation, and Peak correlation from `GLOSSARY.md`.

## Acceptance criteria

- [x] A peak correlates only when its closest horizontal position is within `Distance threshold` and the absolute difference between `Peak.elevation` and track elevation at that position is within `Elevation threshold`; equality at either threshold correlates.
- [x] The geometry retains optional `<ele>` values for supported `trkpt` and `rtept` correlation points, accepting only finite numeric metre values and treating absent, blank, non-numeric, `NaN`, and infinite values as unavailable.
- [x] A missing `Peak.elevation`, a missing or invalid one-point elevation, or a multi-point segment with either missing or invalid endpoint elevation does not correlate the peak; there is no horizontal-only fallback.
- [x] A multi-point segment uses linear endpoint-elevation interpolation at the finite-segment horizontal closest-point projection; a one-point segment uses its point elevation.
- [x] The closest-point search never matches a line extension beyond a segment. A nearer vertical rejection is not overridden by a farther valid segment, while equal closest positions correlate when any tied position satisfies the elevation threshold.
- [x] Track points and route points remain supported, and each matching peak is included at most once per Track.
- [x] Focused unit tests are added test-first, one failing test per behavior change, covering: a vertical match within 10 m; vertical rejection despite horizontal proximity; inclusive boundaries; missing peak elevation; missing, blank, non-numeric, `NaN`, and infinite one-point elevation; missing endpoint elevation; interior interpolation; nearer rejection versus farther valid segment; equal-distance valid tie; finite-segment behavior; and duplicate suppression.

## Covers

- User Stories: 1
- Requirements: 1-4
- Technical Decisions: 1
- Testing Strategy: 1-2
- Interview Ledger: L1, L3, L6

## Blocked by

None - ready to start
