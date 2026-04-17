---
title: Display Track-Correlated Peaks on the Map
date: 2026-04-17
work_type: feature
tags: [map, peaks, flutter_map]
confidence: high
references: [lib/models/gpx_track.dart, lib/screens/map_screen.dart, lib/providers/map_provider.dart, assets/peak_marker_ticked.svg, test/widget/tasmap_map_screen_test.dart]
---

<goal>
Show the peaks stored in `GpxTrack.peaks` on the map so users can see which peaks were correlated to imported GPX tracks.
This is a presentation feature only: it must make the existing persisted track-to-peak relationship visible without changing the correlation algorithm or the ObjectBox schema.
</goal>

<background>
The app already persists track correlation in `GpxTrack` via `peakCorrelationProcessed` and `ToMany<Peak> peaks`.
The map already renders all imported peaks and track polylines in `lib/screens/map_screen.dart`, and the app already uses `flutter_svg` plus SVG marker assets for peak markers.
`assets/peak_marker_ticked.svg` exists in the repo, but it must be registered in `pubspec.yaml` before it can be rendered.


Files to examine:
- `assets/peak_marker_ticked.svg`

Files to examine and extend:
- `lib/models/gpx_track.dart`
- `lib/providers/map_provider.dart`
- `lib/screens/map_screen.dart`
- `test/widget/tasmap_map_screen_test.dart`
- `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. User loads tracks and enables the track layer on the map.
2. User enables the peak layer with a dedicated `Show Peaks` control.
3. The app renders all visible peaks with a single renderer that chooses the ticked or unticked SVG style per peak based on whether that peak appears in any processed `GpxTrack.peaks` relation.
4. The user can visually distinguish correlated peaks from the general peak catalogue markers because matched peaks are shown with the ticked styling.
5. `Show Peaks` defaults to on and remains enabled even when no tracks are loaded.

Alternative flows:
- Peaks are hidden via `Show Peaks`: do not render peak markers, even if tracks are loaded.
- Multiple visible tracks reference the same peak: render one marker for that peak, not duplicates.
- A track has `peakCorrelationProcessed == false`: do not invent overlay markers for that track.

Error flows:
- A track has an empty `peaks` relation: render nothing for that track and keep the map usable.
- A single malformed peak or track entry should be skipped without hiding the rest of the overlay.
</user_flows>

<requirements>
**Functional:**
1. Register `assets/peak_marker_ticked.svg` in `pubspec.yaml` so the ticked peak asset can be loaded by Flutter.
2. Add a dedicated `Show Peaks` FAB below `Show Tracks` in `MapActionRail`, using `Icons.landscape`, to toggle the peak marker layer on/off.
3. Render all visible peaks with one combined renderer that chooses the ticked or unticked SVG style per peak based on track correlation.
4. Use `assets/peak_marker_ticked.svg` for correlated peaks so matched peaks are visually distinct from uncorrelated catalog peaks.
5. Deduplicate correlated peaks across all visible tracks using persisted peak identity (`osmId`) rather than by list position.
6. Apply the same `zoom >= 12` visibility threshold used by the current peak marker layer.

**Error Handling:**
7. If a track’s correlation has not been processed, exclude that track from the correlated peak set.
8. If a peak cannot be rendered, skip that peak only and continue rendering the rest of the peak layer.

**Edge Cases:**
9. Empty track list, hidden peak layer, and empty `peaks` relations must all produce a valid empty result with no ticked peak markers.
10. If the same peak belongs to multiple visible tracks, display only one marker for that peak.

**Validation:**
11. The peak layer must be driven by persisted data already stored on `GpxTrack`, not by re-running peak correlation during render.
</requirements>

<boundaries>
Edge cases:
- No tracks loaded: no ticked peak markers.
- `showPeaks == true`: the peak layer remains available even when no tracks are loaded.
- `showPeaks == false`: hide all peak markers, even if tracks are present.
- `peakCorrelationProcessed == false`: do not render stale or partial relation data.

Error scenarios:
- Missing or malformed peak coordinates: skip that marker and keep rendering the rest of the track peaks.
- A track with an empty `peaks` relation: render nothing and do not show an error.

Limits:
- Do not change ObjectBox schema, peak correlation logic, or refresh/recalculate behavior as part of this task.
- Do not add a new track-details screen; this feature is map-only.
</boundaries>

<implementation>
Add a `showPeaks` boolean to `MapState` and expose a `togglePeaks()` action on `MapNotifier`.
Add a computed `Set<int> correlatedPeakIds` to `MapNotifier` as the source of truth, rebuilt whenever tracks are loaded, refreshed, or recalculated.
Each `correlatedPeakIds` rebuild must happen alongside a `MapState` update that triggers the map widget to rebuild.
Update `lib/screens/map_screen.dart` to use one combined peak renderer that reads from `mapState.peaks` and `MapNotifier.correlatedPeakIds` directly at build time.
Render the ticked SVG for any peak whose `osmId` appears in `correlatedPeakIds`, and the unticked SVG for all other visible peaks.

Use the existing SVG marker asset approach (`flutter_svg` + `assets/peak_marker.svg` and `assets/peak_marker_ticked.svg`) for the combined renderer.
Add a stable key for the peak layer toggle and the peak marker layer so robot tests can target them reliably.

Avoid deriving display state from search selection (`selectedPeaks`) because that is a separate flow and would conflate track correlation with peak search.
</implementation>

<stages>
Phase 1: Add a small helper that collects and deduplicates correlated peaks from processed tracks.
Verify with a unit/widget test that duplicate peaks across tracks collapse to one rendered item.

Phase 2: Render the correlated-peak overlay in `MapScreen`.
Verify with a widget test that the combined renderer switches between ticked and unticked SVGs and only appears when peaks are visible.

Phase 3: Add a robot journey for the tracks screen/map flow.
Verify that a track with correlated peaks shows the overlay after the user enables tracks.
</stages>

<validation>
Use vertical-slice TDD: one failing test at a time, implement the smallest change, then refactor only after green.

Baseline automated coverage must include:
- Logic/business rules: dedupe correlated peaks by `osmId`, filter by `peakCorrelationProcessed`, and ignore empty relations.
- UI behavior: the map shows the peak layer when `showPeaks` is on and hides it when `showPeaks` is off.
- UI behavior: the map shows the combined peak renderer when peaks are visible and hides it when peaks are hidden.
- Critical user journey: loading tracks, enabling the track layer, and seeing correlated peaks on the map.

Test split:
- Unit/widget tests for the dedupe/filter helper and renderer selection rules.
- Robot journey test for the end-to-end map flow that shows correlated peaks after the user enables tracks and peaks.

Testability seams:
- Keep the renderer data derivation in a testable helper so tests can feed deterministic `GpxTrack` fixtures.
- Use stable keys for the peak toggle and peak marker layer.
- Prefer fakes or in-memory fixtures over live ObjectBox/network dependencies for the overlay tests.
</validation>

<done_when>
The map can show track-correlated peaks from `GpxTrack.peaks` through a combined ticked/unticked renderer, duplicate peaks are deduped by `osmId`, hidden tracks or peaks do not render, and the behavior is covered by widget and robot tests.
</done_when>
