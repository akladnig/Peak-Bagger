<goal>
Detect when the mouse cursor is close to a visible GPX track on the map, switch the cursor from open hand to pointing finger, and expose hovered-track state for future UI behavior.

Who benefits: users browsing tracks on the macOS map.
Why it matters: hover affordance makes tracks feel interactive and creates a reliable foundation for later track-specific UI without changing current tap, pan, or popup behavior.
</goal>

<background>
Tech stack: Flutter, flutter_map, Riverpod, latlong2, ObjectBox.
Platform focus: macOS desktop hover interaction. Touch-only behavior is out of scope.

Current state:
- `./lib/screens/map_screen.dart` owns map mouse/pointer handling and currently uses `MouseRegion` only to switch between `grab` and `grabbing`.
- `./lib/screens/map_screen.dart` already uses `MapOptions.onPointerHover` to publish cursor MGRS updates, so track hover detection must share that callback without regressing the existing MGRS overlay behavior.
- `./lib/screens/map_screen.dart` renders tracks by iterating `mapState.tracks` in order and calling `track.getSegmentsForZoom(mapState.zoom.round().clamp(6, 18))`.
- `./lib/providers/map_provider.dart` owns map interaction state and already stores track visibility and loaded `GpxTrack` rows.
- `./lib/models/gpx_track.dart` exposes zoom-selected display geometry through `getSegmentsForZoom()`.
- `./lib/services/track_display_cache_builder.dart` already guarantees zoom-specific simplified geometry for rendering.

This feature is a hover-only interaction enhancement on top of:
- `./ai_specs/005-gpx-tracks-spec.md`
- `./ai_specs/005-track-optimization-spec.md`

Preserve unless explicitly changed here:
- track import/storage/recovery behavior
- current tap-to-select-location behavior
- current drag/pan cursor behavior
- current track rendering, colors, and toggle rules
- current info popup behavior

Resolved decisions:
- Measure proximity in Flutter logical pixels on screen, not metres.
- Use the nearest visible segment when multiple tracks are within range.
- Detection result is cursor change plus hovered-track state.
- Use a fixed hover radius of `8.0` logical pixels.

Files to examine:
- `./lib/screens/map_screen.dart`
- `./lib/providers/map_provider.dart`
- `./lib/models/gpx_track.dart`
- `./lib/services/track_display_cache_builder.dart`
- `./test/gpx_track_test.dart`
- `./test/widget/gpx_tracks_recovery_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. User has tracks visible on the map.
2. User moves the mouse across the map without pressing a mouse button.
3. The app projects the currently rendered zoom-selected track geometry into screen space.
4. If the pointer is within `8.0` logical pixels of a visible track segment, the nearest track becomes hovered.
5. The map cursor changes from open hand to pointing finger.
6. `MapState` publishes the hovered track ID for future use.

Alternative flows:
- No visible tracks: keep open-hand cursor and clear hovered-track state.
- Multiple tracks within range: choose the nearest visible segment; if distances are equal within floating-point tolerance, prefer the first nearest track encountered in current render order.
- User moves away from all tracks: restore open-hand cursor and clear hovered-track state.
- Map camera changes because of zoom, keyboard pan, or programmatic recentering before another hover event arrives: clear hovered-track state and use the non-hover cursor until the next hover evaluation.

Error flows:
- Corrupt or missing display geometry on a track: ignore that track for hover detection and continue evaluating the rest.
- Pointer leaves the map region: clear hovered-track state immediately.
- User starts dragging: stop hover detection for that drag cycle and keep the current drag cursor behavior.
- Map widget or camera projection is unavailable for a hover event: skip detection for that event, clear hovered-track state, and keep the non-hover cursor.
</user_flows>

<requirements>
**Functional:**
1. Add hover-based track hit testing to `./lib/screens/map_screen.dart` for the map interaction region.
2. Run track detection only during hover movement with no active pointer drag.
3. Restrict detection to tracks that are currently visible on the map, meaning `showTracks == true` and the track has non-empty rendered geometry for the active zoom.
4. Use the same zoom-selected geometry used for rendering via `GpxTrack.getSegmentsForZoom()`; do not reparse GPX XML or use hidden/off-zoom geometry for hover detection.
5. Measure proximity in Flutter logical pixels after projecting track vertices into the current map widget coordinate space.
6. Use a fixed hover threshold of `8.0` logical pixels from the pointer to the nearest line segment.
7. When multiple tracks are within threshold, choose the track whose nearest visible segment is closest to the pointer.
8. If two candidate tracks are effectively tied at the same minimum distance, keep the first nearest track encountered in the current render iteration to avoid oscillation.
9. While a track is detected, change the map cursor to `SystemMouseCursors.click`.
10. When no track is detected and no drag is active, keep the current open-hand cursor behavior.
11. While the pointer is down or the map is being dragged, preserve the existing `grabbing` cursor behavior and suspend hover-track detection updates.
12. Add hovered-track state to `MapState` as `hoveredTrackId` (`int?`), not as a duplicated `GpxTrack` object.
13. Add `MapNotifier` methods to set and clear hovered-track state.
14. Hovered-track state must clear when the pointer leaves detection range, leaves the map region, tracks are hidden, or a drag begins.
15. Hovered-track state must also clear when map position/zoom changes and there is no fresh hover evaluation yet for the new camera state.
16. Hovered-track state must not change `selectedLocation`, toggle `showInfoPopup`, toggle `showTracks`, or mutate persisted track data.
17. Hovered-track state is runtime UI state only. Do not store it in ObjectBox or `SharedPreferences`.

**Error Handling:**
18. If a track has malformed display geometry or cannot be projected for hit testing, skip that track and continue evaluating the remaining visible tracks.
19. Do not show snackbars, dialogs, or error banners for hover-detection failures.
20. If the map camera or widget size is temporarily unavailable during a frame, skip hover detection for that event, clear hovered-track state, and keep the non-hover cursor state.

**Edge Cases:**
21. One-point segments must never count as hover targets because they are not line segments.
22. Two-point and multi-point segments are valid hover targets.
23. Multi-segment tracks must evaluate every visible segment and use the minimum segment distance for that track.
24. Hover detection must use the active rounded/clamped zoom geometry, matching current rendering behavior.
25. When `hasTrackRecoveryIssue == true`, treat tracks as non-interactive for hover detection and clear hovered-track state.
26. Hover detection must not run against hidden tracks when `showTracks == false`.
27. Hover detection must not interfere with existing hover MGRS updates; both behaviors should coexist.
28. If a track remains hovered and the user toggles tracks off, enters recovery mode, or changes camera state, the app must not leave a stale `click` cursor or stale `hoveredTrackId` behind.

**Validation:**
29. All hover-detection behavior must be covered by automated tests across pure hit-testing logic, widget cursor/state behavior, and critical mouse-hover journeys.
30. Implementation must follow vertical-slice TDD: one failing test at a time, minimal code to green, then refactor.
31. Prefer pure fakes and deterministic provider overrides; mock only true external boundaries if a fake is not practical.
</requirements>

<boundaries>
Edge cases:
- Hovering near a track changes only cursor and hovered-track state; it does not select the track.
- Hovering while the map is panned, zoomed, or otherwise re-rendered must recompute against the latest camera state.
- Hovered-track state is ephemeral and clears immediately when interaction context no longer supports it.

Error scenarios:
- Missing/corrupt geometry on one track: ignore that track, continue scanning others, no user-facing error.
- Map not yet fully laid out for projection on a given event: skip that event, no crash, and clear any previously hovered track so stale hover state is not retained.
- Concurrent UI states like search or info popup: hover detection may continue, but it must not alter those UI states.

Limits:
- macOS/desktop hover only; touch-only interactions are out of scope.
- Fixed threshold: `8.0` logical pixels.
- No hover popup, tooltip, or visual highlight in this slice.
- No database schema changes.
</boundaries>

<implementation>
Create or modify these paths:
- `./lib/screens/map_screen.dart`
  - add hover hit-testing over rendered track geometry
  - switch cursor among `grab`, `grabbing`, and `click`
  - clear hover state on pointer exit and drag start
  - add a stable key on the map interaction region for tests if one does not already exist
- `./lib/providers/map_provider.dart`
  - add `hoveredTrackId` to `MapState`
  - add setter/clearer methods for hovered-track state
  - ensure hover state clears when tracks become hidden or recovery mode is active
- `./lib/models/gpx_track.dart`
  - add only small helpers if they simplify safe access to zoom-selected segments for hit testing
- `./lib/services/track_hover_detector.dart`
  - add a pure helper/service that takes pointer position plus visible track geometry and returns the nearest hovered track ID within threshold

Detector contract:
- Input should be screen-space pointer position plus an ordered list of visible candidate tracks, where each candidate carries `gpxTrackId` and already-selected zoom segments.
- Output should be a deterministic result object or tuple containing `hoveredTrackId` (`int?`) and nearest distance in logical pixels when a match exists.
- The detector must not depend on Riverpod, Flutter widget lifecycle, ObjectBox, or GPX XML parsing.

Implementation rules:
- Keep the distance calculation pure and screen-space based.
- Prefer a small dedicated helper for hit-testing math instead of embedding segment-distance math directly into widget build logic.
- Use `hoveredTrackId` and derive the hovered `GpxTrack` from `state.tracks` when needed later; avoid synchronizing duplicate object state.
- Reuse the current track render iteration order so nearest-track tie handling stays deterministic.
- Reuse the same rounded/clamped zoom selection already used by `_buildTrackPolylines()` so rendered geometry and hover geometry cannot diverge.
- Keep cursor selection derived from current interaction state: `grabbing` while dragging, `click` only while a hovered track exists and dragging is false, otherwise `grab`.
- Add the map interaction-region key using the repo's existing dash-separated key style, for example `map-interaction-region`, unless a suitable stable key already exists.
- Do not add speculative UI behavior beyond cursor change and hovered state.
</implementation>

<stages>
Stage 1: Pure hit-testing
- Add a pure track hover detector that computes nearest-segment distance in logical pixels.
- Verify threshold, nearest-track choice, one-point exclusion, and tie handling.

Stage 2: State and map wiring
- Add `hoveredTrackId` state and wire `MapScreen` hover/exit/drag events to it.
- Verify cursor transitions and state clearing behavior without changing existing tap/pan behavior.
- Verify camera updates clear stale hover state until the next hover event recomputes against the new camera.

Stage 3: Journey hardening
- Add deterministic widget/robot coverage for the critical hover flow on visible tracks.
- Verify hidden tracks, recovery mode, and pointer-exit clearing.
</stages>

<illustrations>
Desired behavior:
- User moves the mouse near a visible purple track; cursor becomes pointing finger and `hoveredTrackId` points to that track.
- User moves 20 logical pixels away from every visible track; cursor returns to open hand and `hoveredTrackId` becomes null.
- Two nearby tracks overlap visually; the closer segment wins consistently.

Avoid:
- Measuring hover distance in metres.
- Using original GPX XML or off-screen geometry for hit testing.
- Changing selected marker, info popup, or track visibility because of hover alone.
- Persisting hovered state between launches.
</illustrations>

<validation>
Baseline automated coverage required:
- Unit tests for segment-distance math, threshold behavior, one-point exclusion, nearest-track choice, and tie handling.
- Widget tests for cursor switching, hovered-track state updates, pointer-exit clearing, and drag suppression.
- Robot-driven journey coverage for the critical visible-track hover path.

Behavior-first TDD slices:
1. RED: nearest-segment hit testing returns no match when every segment is outside `8.0` logical pixels.
2. GREEN: nearest-segment hit testing returns the correct track when one visible segment is inside threshold.
3. RED: one-point segments are ignored while two-point segments still match.
4. RED: multiple candidate tracks choose the nearest visible segment deterministically.
5. RED: `MapNotifier` stores and clears `hoveredTrackId` without affecting selection or popup state.
6. RED: `MapScreen` switches cursor to pointing finger only while a hovered track exists and no drag is active.
7. RED: pointer exit, hidden tracks, recovery mode, and camera changes clear hovered-track state.

Required seams for deterministic tests:
- Keep `track_hover_detector.dart` pure and independent of widget lifecycle.
- Keep cursor-choice logic callable/observable without requiring real GPX imports.
- Use provider overrides or deterministic `TestMapNotifier` seams for widget and robot tests.

Robot-driven coverage:
- Critical journey: load map with visible track state, move a mouse pointer near the rendered track, assert pointing-finger hover state, then move away and assert open-hand state restored.

Default test split:
- Robot: visible-track happy-path hover journey.
- Widget: pointer exit, drag suppression, recovery-mode disablement, hidden-track disablement, camera-change clearing.
- Unit: hit-testing math and nearest-track resolution.

Stable selectors/seams required:
- Add a stable key for the map interaction region used by hover tests.
- Reuse existing app-owned keys for track visibility controls when needed by journey setup.
- Keep test setup deterministic by injecting visible tracks directly through provider/test notifier seams rather than filesystem import.

Known testing risk to report if not fully covered:
- Desktop cursor assertions can be less direct than state assertions in widget tests, so report any residual gap between tested hover state and platform cursor fidelity.
- `flutter_map` projection/camera seams in widget tests may require a narrower assertion on provider state than on exact platform cursor repaint timing; report that gap explicitly if it remains.
</validation>

<done_when>
- Moving the mouse within `8.0` logical pixels of a visible track changes the cursor to pointing finger.
- The nearest visible segment wins when multiple tracks are within range.
- `hoveredTrackId` is published while hovering and clears on exit, drag start, hidden tracks, and recovery mode.
- Camera changes do not leave stale hover state or stale `click` cursor behind before the next hover event.
- Existing pan, tap, info popup, and track visibility behavior remain unchanged.
- Automated unit, widget, and robot coverage exists for the behaviors named above.
- The implementation can proceed from this spec without further decisions about threshold, state ownership, tie handling, or scope.
</done_when>
