<goal>
Add a left-side track info panel to the map route. When a track becomes selected, the app should keep the current selected-track highlight behavior and also reveal readable track metadata and statistics without taking the user away from the map.

Who: users inspecting imported GPX tracks on the map, including route-entry flows that already preselect a track.

Why: the current selection state only changes line styling. Users need immediate context for what the highlighted track is and what its numbers mean.
</goal>

<background>
Desktop Flutter app using Riverpod, ObjectBox, and `flutter_map`.

Current track selection already exists through `selectedTrackId` in `./lib/providers/map_provider.dart` and primary-click handling in `./lib/screens/map_screen.dart`.

The map route already uses right-side `endDrawer` content for basemaps and peak lists via `./lib/widgets/map_basemaps_drawer.dart` and `./lib/widgets/map_peak_lists_drawer.dart`. The app shell already uses `Scaffold.drawer` for navigation, so this feature must not use `Scaffold.drawer`. Implement the track info UI as a custom left-side in-body sliding panel within the map screen stack.

This feature is desktop-only. Existing track selection is based on primary mouse click and existing programmatic `showTrack(...)` flows; touch-specific behavior is out of scope. This slice is explicitly scoped to `MapScreen` viewport widths at or above `RouterConstants.shellBreakpoint`: production code and tests must guard the panel behind that `MapScreen` width check, and below that width the app should preserve existing track selection/highlight behavior without rendering the panel.

The existing `GpxTrack` model stores track-level statistics and correlated peak names through `track.peaks`. It does not store per-peak distance-to/from values, so this slice must not invent correlated-peak distance rows.

Do not add ObjectBox fields, SharedPreferences persistence, or new peak-correlation schema for this feature.

Files to examine:
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/core/constants.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/widgets/map_action_rail.dart`
- `./lib/widgets/side_menu.dart`
- `./lib/widgets/peak_list_peak_dialog.dart`
- `./lib/models/gpx_track.dart`
- `./lib/widgets/map_basemaps_drawer.dart`
- `./lib/widgets/map_peak_lists_drawer.dart`
- `./lib/router.dart`
- `./pubspec.yaml`
- `./test/harness/test_map_notifier.dart`
- `./test/gpx_track_test.dart`
- `./test/widget/map_screen_keyboard_test.dart`
- `./test/widget/gpx_tracks_selection_test.dart`
- `./test/widget/map_screen_route_entry_test.dart`
- `./test/widget/tasmap_map_screen_test.dart`
- `./test/robot/gpx_tracks/selection_journey_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. Desktop user primary-clicks a visible GPX track on the map using the existing mouse selection interaction.
2. App selects that track, keeps the selected-track highlight, and slides a left-side track info panel into view.
3. Panel shows the selected track name, dates, summary metrics, correlated peak names, elevation stats, and time stats in human-readable form.
4. User presses the close button.
5. App clears the selected track, closes the panel, and returns the map to its non-selected track state while leaving any existing selected-location marker behavior unchanged.

Alternative flows:
- User selects a different track that is present in `MapState.tracks` while `showTracks == true`: selection changes immediately and the panel content updates to the new track without requiring a second close/open gesture.
- A route or action calls the existing `showTrack(trackId, selectedLocation: ...)`: the map still focuses the track and the same track info panel becomes visible because the track is now selected.
- User navigates away from the map route and later returns while `showTracks == true` and `selectedTrackId` still resolves inside `MapState.tracks`: the panel reappears because it is derived from current selected-track state.
- User clicks the same selected track again: keep the same selection and keep the panel open; do not toggle it closed on re-click.
- User primary-clicks empty map background while the panel is open: preserve current map behavior by updating `selectedLocation`, clearing `selectedTrackId`, and closing the panel.
- The selected track has no correlated peaks: show `None` in the Peaks Climbed section.

Error flows:
- Selected track id no longer resolves after refresh, reset, rebuild, or visibility-off: clear stale selection and hide the panel.
- Nullable or blank rendered fields: apply the field-specific fallback rules defined below instead of rendering raw `null` or empty strings.
- A malformed track cannot be rendered or hit-tested: keep existing skip-and-continue behavior; the panel must never crash the map route.
</user_flows>

<requirements>
Stable requirement IDs for cross-references below:
- Functional requirements: `F1` to `F31`
- Error handling requirements: `E1` to `E8`
- Edge cases: `X1` to `X7`
- Validation requirements: `V1` to `V2`
Use the stable ids for cross-references below; the visible list numbers are presentational only.

**Functional:**
1. Add a left-side track info panel to `./lib/screens/map_screen.dart` that is visible only when `MediaQuery.sizeOf(context).width >= RouterConstants.shellBreakpoint`, `showTracks == true`, and `selectedTrackId` resolves to a matching `GpxTrack` within `MapState.tracks`.
2. Do not use `Scaffold.drawer` for this feature. Present the UI as a custom in-body sliding panel layered inside the map screen stack so the shell drawer and existing right-side end-drawers continue to work unchanged.
3. Keep entry points aligned with existing selection behavior: any path that sets `selectedTrackId` to a track present in `MapState.tracks` while `showTracks == true`, including direct map selection and existing `showTrack(...)` flows, must reveal the panel.
4. Track-info panel visibility is derived from displayed map state only: `showTracks == true` and `selectedTrackId` resolving within `MapState.tracks`. A selected track id that is not present in `MapState.tracks` while `showTracks == true` is invalid everywhere in this slice and must be reconciled before any selected-track focus logic runs.
5. The close control in the panel header must clear `selectedTrackId`, which closes the panel and removes selected-track emphasis in a single explicit state change. Closing the panel does not clear `selectedLocation`; amber marker behavior remains whatever the app's existing track-selection and `showTrack(...)` flows already do.
6. Empty-map clicks, track reset flows, track visibility-off flows, and other existing clear-selection paths must also hide the panel because no selected track remains.
7. When the panel is visible, hide the existing left-side MGRS and zoom readouts instead of shifting them or letting them overlap the panel.
8. Panel placement and z-order must match the current nested `Stack` structure in `MapScreen`: place the track info panel in the inner map stack so it sits above `FlutterMap` and the left readouts, remove or omit the MGRS and zoom readouts from that same inner stack while the panel is visible, and keep the action rail, search/goto surfaces, map info popup, and peak info popup in the outer stack above the panel.
9. Create a dedicated track info panel component with a concrete visual contract: use the route's normal surface color, similar elevation to existing map drawers, a 16 px horizontal padding rhythm, the specified width constraint, a pinned header, and a deterministic in-body slide animation. Do not assume there is an existing left-side panel component to reuse. Place this panel alongside the map-route screen code, either in `./lib/screens/map_screen_panels.dart` or in a dedicated nearby file such as `./lib/screens/map_track_info_panel.dart` if readability benefits.
10. The panel must be wrapped in `SafeArea`, use a pinned header, and keep the remaining content in a vertically scrollable body so all sections stay reachable on shorter viewports while the close button remains accessible.
11. The panel header must render the selected track name left-aligned and a close button right-aligned. Blank track names must display `Unnamed Track`. The close control must expose an accessible tooltip or semantic label such as `Close track info`.
12. Below the header, render the track date row and the `from ... to ...` time row using deterministic formatting. Partial cases must render exactly as follows:
- both start and end times present: `from 14:05 to 16:40`
- only start time present: `from 14:05 to Unknown`
- only end time present: `from Unknown to 16:40`
- neither time present: `from Unknown to Unknown`
- missing `trackDate`: render `Unknown` in the date row
13. Render a three-column summary block with `Distance`, `Ascent`, and `Total Time` labels and bold values beneath them. The `Distance` value in this summary uses `distance2d`.
14. `Total Time` appears intentionally both in the summary row and in the full Time section for scanability.
15. Render a `Peaks Climbed` section using correlated peaks from `track.peaks`.
16. If `peakCorrelationProcessed == false`, treat the `Peaks Climbed` section as unavailable for this slice: render `None` and omit the shared track-level highest-point distance block.
17. If `peakCorrelationProcessed == true` and one or more correlated peaks exist, first show one shared track-level highest-point distance block with the rows `Track distance to highest peak` and `Track distance from highest peak`, using the existing stored `distanceToPeak` and `distanceFromPeak` values once for the whole track. Then list the correlated peak names once each.
18. Peak display-name normalization must be deterministic: trim the raw peak name, apply the `Unknown Peak` fallback for blank results, sort case-insensitively by the displayed name, and de-duplicate correlated peaks by raw `osmId` only, including `osmId <= 0` values.
19. If `peakCorrelationProcessed == true` and there are no correlated peaks after normalization and `osmId`-based de-duplication, render `None` and omit the shared track-level highest-point distance block.
20. Do not invent new correlated-peak distance calculations or persisted fields in this slice. Use the existing stored `distanceToPeak` and `distanceFromPeak` values only in the shared track-level highest-point distance block.
21. Render an `Elevation` section that uses the stored track-level fields with correct semantics:
- `Total Ascent` uses `ascent`
- `Start Elevation` uses `startElevation`
- `End Elevation` uses `endElevation`
- `Max Elevation` uses `highestElevation`
- `Min Elevation` uses `lowestElevation`
22. Render a `Time` section that shows `Total Time`, `Moving Time`, `Resting Time`, and `Paused Time`.
23. Human-readable formatting rules must be explicit and deterministic:
- `trackDate` is a calendar date and must be formatted without timezone shifting
- `trackDate` display must use the stored calendar fields directly and must not call `.toLocal()`
- `startDateTime` and `endDateTime` must be converted to local device time before formatting for display
- `trackDate` renders like `Wed, 7 January 2026` using fixed English short weekday names (`Mon` ... `Sun`) and full English month names (`January` ... `December`) via a small local formatter; do not add `intl` for this feature
- `startDateTime` and `endDateTime` display time only like `14:05`; the time row must not repeat the date
- distance values under `1000 m` render as whole meters such as `840 m`
- distance values at or above `1000 m` render as kilometers with one decimal place such as `12.4 km`
- elevation values render as whole meters with `m`
- duration values render from milliseconds as `Hh Mm` when one hour or more, `Mm` when under one hour, and `0m` when zero
- fallback precedence by rendered field is explicit:
- track name blank -> `Unnamed Track`
- peak name blank after trim -> `Unknown Peak`
- missing `trackDate`, `startDateTime`, `endDateTime`, `totalTimeMillis`, `movingTime`, `restingTime`, `pausedTime`, or nullable `ascent` -> `Unknown`
- non-null numeric fields that currently default to `0` must render their stored numeric value
24. Prefer a small local formatter or presentation seam if needed for testability, but keep the architecture minimal. Do not add a new persistence layer or global UI state layer for this feature.
25. The panel width must remain usable on desktop window sizes and must not consume the full map. Reuse `UiConstants.preferredLeftWidth` for this slice.
26. The track info panel is non-modal. Existing map keyboard shortcuts remain available while it is open, and closing the panel must return focus to the map root. `Escape` is the primary keyboard dismissal path for the panel; the close button remains tabbable and operable for users who manually move focus into the panel.
27. Focus and keyboard policy must be explicit: the panel does not auto-steal focus on open, the close button is tabbable, and route-level keyboard ownership above both `Scaffold.endDrawer` and the map-body overlays must enforce this `Escape` behavior, preferably via a `Shortcuts` / `Actions` or equivalent wrapper around the `Scaffold`. `Escape` resolves overlapping surfaces in this order: close the end drawer first if it is open using the scaffold-level dismiss path, then close peak info popup if present, then close map info popup if present, and finally clear the selected track to close the track info panel. On each `Escape` key-down, close only the highest-priority visible surface and then return `handled`. Existing map shortcuts remain active unless a text input has focus, closing the panel must explicitly re-request `_mapFocusNode`, and the existing non-`Escape` popup keyboard behavior is preserved: peak info continues to dismiss on keydown with existing passthrough behavior, while map info continues to dismiss on non-`I` keydown and consume that key event.
28. Keep this slice limited to the panel. Do not broaden it into a transient-overlay cleanup refactor. Preserve existing popup-dismiss behavior and existing peak search / goto visibility semantics rather than adding new cleanup requirements for those surfaces.
29. Preserve current right-side drawer behavior for basemaps and peak lists while allowing them to coexist with a visible selected track and track info panel. This feature must not change how `EndDrawerMode` works and does not require refactoring the existing basemaps or peak-lists open flows.
30. Preserve current track-selection interaction semantics: selecting a track must still consume the click and must not introduce any new selected-location behavior beyond the app's existing direct map selection and `showTrack(...)` flows.
31. Direct mouse track selection must preserve the current behavior where a primary click also updates `selectedLocation` exactly as it does today.

**Error Handling:**
32. (`E1`) Selected-track mutations follow one authoritative notifier-owned contract: `selectTrack(trackId)` is only valid for IDs already present in `MapState.tracks` while `showTracks == true`; invalid `selectTrack(trackId)` calls are a no-op and leave the existing selection unchanged; `showTrack(trackId, ...)` is the only programmatic path allowed to materialize a selected track into `MapState.tracks` when needed; a selected track id that is not present in `MapState.tracks` while `showTracks == true` is invalid everywhere in this slice; and one concrete notifier-owned reconciliation API named `reconcileSelectedTrackState()` must cover the known stale-state holes in this slice without requiring a broad refactor of already-safe flows.
33. (`E2`) If `showTrack(trackId, ...)` cannot resolve the track from the repository, it must not leave a stale selection behind: clear `selectedTrackId`, keep the panel hidden, and skip camera refocus.
34. (`E3`) Forced selected-track clearing on replacement is limited to explicit reset/reload flows that intentionally discard current selection, such as reset, import/rebuild, recovery, or statistics-recalculation paths that already reset track state. Benign same-id rehydration cases should rely on membership-based normalization instead.
35. (`E4`) If `selectedTrackId` is set but no matching track exists in `MapState.tracks` while `showTracks == true`, render no panel immediately and clear the stale selected-track id for state consistency.
36. (`E5`) Notifier-owned reconciliation is the only selected-track cleanup owner in this slice. UI rendering remains pure and must not mutate provider state during build.
37. (`E6`) Rendered fields with fallbacks are limited to track name, peak name, date/time fields, and nullable `ascent`; they must show the field-specific fallbacks defined above instead of throwing or rendering raw `null` or empty strings.
38. (`E7`) If the correlated peak list is unavailable or empty, render `None` and continue rendering the rest of the panel.
39. (`E8`) Any existing malformed-track skip behavior in rendering or hit-testing must remain non-fatal; the new panel must not introduce route crashes.

**Edge Cases:**
40. (`X1`) Selecting a different track while the panel is open replaces the content immediately.
41. (`X2`) Closing the panel with the close button clears selection even if the selected track remains visible on the map.
42. (`X3`) Toggling tracks off clears selection and hides the panel.
43. (`X4`) Refresh, import, reset, recovery, or statistic-rebuild flows that replace tracks must not leave a stale panel visible for a removed track id.
44. (`X5`) If multiple correlated peaks exist after normalization and `osmId`-based de-duplication, list all displayed names alphabetically by display name. Treat this ordering as a presentation rule only; it does not imply along-track or climbed order.
45. (`X6`) If a track name, peak name, or formatted field overflows, truncate gracefully rather than expanding the panel past its intended width.
46. (`X7`) If the user navigates away and later returns while `showTracks == true` and `selectedTrackId` still resolves inside `MapState.tracks`, the panel should reappear.

**Validation:**
47. (`V1`) Add stable app-owned selectors for robot and widget coverage. `Key('track-info-panel')` and `Key('track-info-panel-close')` are required for the new panel. `Key('basemaps-drawer')` on `MapBasemapsDrawer` and `Key('show-basemaps-fab')` on the basemaps FAB are required regression-protection hooks so existing keyboard coverage in `./test/widget/map_screen_keyboard_test.dart` can migrate off `find.text('Basemaps')` and remain stable once a second left-side surface exists.
48. (`V2`) Keep validation split explicit: unit tests for pure formatting or presentation logic, widget tests for panel visibility, layout, and state reactions, and robot-driven widget-journey coverage for click-select, open, and close flows.
</requirements>

<boundaries>
Edge cases:
- This slice is about presenting existing selected-track data, not redesigning track selection from scratch.
- Correlated peak entries may show one shared track-level highest-point distance block, but the feature must not invent new per-peak calculations because the current data model does not store per-peak distances or timings.
- The panel should match the app's drawer surface, spacing, and typography scale, but it is not required to reuse `Drawer` itself.

Error scenarios:
- Missing track after refresh, reset, or rebuild: clear selection and hide panel.
- Only rendered fallback fields in this slice are track name, peak name, date/time fields, and nullable `ascent`; they must follow the field-specific fallback precedence above and keep surrounding sections visible.
- Malformed track geometry: keep current skip behavior and prevent panel-related crashes.

Limits:
- No ObjectBox schema changes.
- No SharedPreferences or file-backed persistence for drawer visibility or selection.
- No new left-side global shell navigation changes.
- No touch selection path is required or expected in this slice; desktop mouse interaction and existing programmatic `showTrack(...)` flows are the supported entry points.
- Below `RouterConstants.shellBreakpoint`, preserve existing track selection/highlight behavior but do not render the track info panel. This gate is based on the `MapScreen` viewport width available to the route itself, not on a separate shell mode.
- Avoid adding `intl` or other formatting packages unless a concrete implementation need appears that cannot be met with small local helpers.
</boundaries>

<implementation>
1. Modify `./lib/screens/map_screen.dart` to derive the selected `GpxTrack` from `selectedTrackId` and `tracks`, where panel visibility means `MediaQuery.sizeOf(context).width >= RouterConstants.shellBreakpoint` plus `showTracks == true` and membership in `MapState.tracks`, then overlay a dedicated track info panel component in the inner map stack using `AnimatedSlide`, `AnimatedPositioned`, or an equivalent deterministic animation widget so it sits above the map/readouts but below the action rail and outer-stack popups. Selected-track focus must use reconciled visible-track state rather than an independent repository-only fallback. Hide the left-side MGRS and zoom readouts while the panel is visible instead of shifting them.
2. Keep `endDrawer` logic intact for right-side drawers. The new left-side panel must be independent of `endDrawerMode`.
3. Add the rendering component alongside existing map-route panel code, either in `./lib/screens/map_screen_panels.dart` or in `./lib/screens/map_track_info_panel.dart` if a dedicated file improves readability. It should accept the selected track data and an `onClose` callback rather than pulling additional global state on its own unless there is a clear testability reason to do otherwise.
4. Structure the panel with `SafeArea`, a pinned header, and a vertically scrollable body.
5. If formatting logic becomes non-trivial, extract a tiny pure helper or presentation file near the widget and unit-test it. Avoid creating broad new service layers.
6. Keep this slice limited to the panel. Preserve existing overlay and popup visibility semantics rather than adding new peak search or goto cleanup behavior. Existing basemaps and peak-lists drawer flows may remain as they are as long as they continue to coexist with the selected track and panel.
7. Centralize selected-track normalization in notifier-owned state logic and enforce the authoritative mutation contract from `E1`, but keep the scope narrow to the actual stale-state holes in current code: `selectTrack(...)` accepting arbitrary ids, `showTrack(...)` leaving stale selection on repository miss, and selected-track focus in `MapScreen` using repository fallback instead of visible `state.tracks`. Existing flows that already clear selection correctly do not need refactoring solely to route through a new helper.
8. Use existing `MapNotifier.clearSelectedTrack()` and `showTrack()` flows as the main state contract. `MapNotifier` owns selected-track normalization and miss-handling for `showTrack(...)`; `MapScreen` rendering remains pure and derives panel visibility from current state only. Introduce one concrete notifier API named `reconcileSelectedTrackState()` and run it at these call sites for this slice: after `selectTrack()`, inside `showTrack()`, after explicit reset/reload replacement flows that can invalidate selection, and once from `MapScreen.initState` via a safe non-build trigger before post-frame selected-track focus work can act on pre-seeded state. Selected-track focus queuing must also gate immediately on visible `MapState.tracks` membership so a stale id cannot trigger a first-frame repository fallback before reconciliation completes. Implement `Escape` ownership so it satisfies the precedence from `F27`, closes only one highest-priority visible surface per keypress, and then returns `handled`. Do not add a separate persisted panel-open flag.
9. Reuse `selectedTrackId` and `showTracks` as the visibility contract for the panel. Do not add duplicate boolean state unless a specific interaction proves impossible without it.
10. Ensure the selected track lookup occurs from current visible tracks so stale ids cannot render orphaned content.
11. For the Peaks Climbed section, render one shared track-level highest-point distance block and then the correlated peak names as plain text or compact rows. Do not add nested expansion, navigation, or per-peak drilldown in this slice.
12. Keep formatting helpers deterministic and local:
- distance formatter: stable unit rule and fixed precision
- elevation formatter: whole-meter style
- duration formatter: human-readable conversion from milliseconds
- timezone rule: keep `trackDate` as a calendar date without timezone shifting, and convert `startDateTime` / `endDateTime` to local device time before display
- date formatter output: `Wed, 7 January 2026` with fixed English short weekday names and full English month names
- time formatter output: `14:05` without repeating the date in the `from ... to ...` row
13. Sort Peaks Climbed names alphabetically in the presentation layer; do not reinterpret the stored relation order as route order.
14. Keep `./test/widget/map_screen_route_entry_test.dart` as the canonical hidden-branch and route-entry coverage for real `MapNotifier` `showTrack()` repository-resolution and miss-handling behavior. Only add a GPX-repository seam to `TestMapNotifier.showTrack()` if panel-specific widget coverage cannot stay deterministic without it.
15. Direct panel coverage files:
- add a dedicated notifier-contract test file, for example `./test/providers/map_provider_selected_track_test.dart`, as the primary home for selected-track contract coverage (`selectTrack(...)` valid/no-op cases, `showTrack(...)` miss handling, targeted normalization, and pre-seeded stale-state normalization)
- add a focused panel behavior file, for example `./test/widget/map_screen_track_info_test.dart` or `./test/widget/map_track_info_panel_test.dart`, as the primary home for panel visibility, close behavior, width-gate behavior, and keyboard interactions
- `./test/widget/map_screen_route_entry_test.dart`
- `./test/widget/map_screen_keyboard_test.dart`
16. Regression entry-point files:
- `./test/widget/peak_list_peak_dialog_test.dart` because it can trigger `showTrack(...)`
- `./test/widget/tasmap_map_screen_test.dart` only where Tasmap-specific selected-track focus overlaps with this feature
- `./test/robot/gpx_tracks/selection_journey_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
17. If a pure formatting helper is extracted, put its tests in a dedicated formatter test file, for example `./test/widget/map_track_info_formatting_test.dart`, rather than mixing formatter assertions into notifier-contract tests or unrelated legacy test files.
18. Do not change `./lib/models/gpx_track.dart` or `./lib/services/track_peak_correlation_service.dart` in this slice unless a small read-only helper is required. No new persisted fields should be introduced.
</implementation>

<stages>
Phase 1: Define the visibility and close contract using existing selected-track state. Verify selected track -> panel visible, clear selection -> panel hidden, and right-side drawers unaffected.

Phase 2: Build the panel UI and deterministic formatting helpers. Verify header, summary, peaks, elevation, and time sections render expected text and fallbacks.

Phase 3: Add click-select and route-entry journey coverage. Verify selecting from the map opens the panel, selecting another track replaces content, and close, visibility-off, and reset flows hide it.
</stages>

<validation>
1. TDD order: write one failing test at a time and keep each red-green-refactor cycle vertical. Start with visibility and close behavior, then formatting and section rendering, then the full interaction journey.
2. Suggested behavior-first slices:
- Slice 1: a primary mouse-click-selected visible track or programmatic `showTrack(...)` selection shows the panel, and pressing the close button clears selection and hides it
- Slice 2: the panel renders summary, peaks, elevation, and time sections with correct field mapping, intentional `Total Time` repetition, and readable fallbacks
- Slice 3: selecting a different track replaces panel content without breaking right-side drawers, left-side readout hiding, or existing route-entry flows
3. Isolate rendered date/time formatting behind a tiny pure formatter or presentation seam and unit-test it there. Unit tests must cover any extracted pure formatter or presentation seam:
- milliseconds to readable duration text
- numeric distance and elevation formatting with units
- date and time formatting tests must stay deterministic across machine timezones:
  use exact-string assertions in pure formatter tests and in widget tests only when fixtures are already local and timezone-safe; use UTC fixtures only for conversion-behavior assertions in pure formatter tests without hardcoding one host-specific wall-clock output
- `trackDate` remains a calendar date without timezone shifting while `startDateTime` and `endDateTime` convert to local device time
- peaks section presentation as one shared track-level highest-point distance block plus peak names, or `None`
4. Widget tests must cover:
- panel-visible widget tests must explicitly set a surface width at or above `RouterConstants.shellBreakpoint`
- at least one narrow-width regression test must explicitly set a surface width below `RouterConstants.shellBreakpoint` and assert that panel selectors are absent while existing track selection/highlight behavior remains unchanged
- shared widget-test pump helpers that exercise `App()` or `MapScreen()` for panel behavior must accept an explicit surface-width seam and default panel-visible coverage to a width at or above `RouterConstants.shellBreakpoint`
- when `showTracks == true` and `selectedTrackId` resolves to a track in `MapState.tracks`, `Key('track-info-panel')` is present and the track name renders
- below `RouterConstants.shellBreakpoint`, panel selectors are absent while existing track selection/highlight behavior remains unchanged
- pressing `Key('track-info-panel-close')` clears selection and removes the panel
- selecting a different track updates the rendered content
- primary-clicking empty map background while the panel is open preserves current map behavior by updating `selectedLocation`, clearing `selectedTrackId`, and closing the panel
- direct primary-mouse track selection preserves the current `selectedLocation` update behavior, and this coverage belongs in robot tests or explicit mouse-gesture widget tests rather than ordinary tap-based widget tests
- `showTracks == false` or an unresolved selected id hides the panel and unresolved ids are cleared deterministically
- pre-seeded stale selected-track state is reconciled through notifier-owned normalization without mutating during build
- elevation fields map correctly: `highestElevation` -> Max and `lowestElevation` -> Min
- partial date/time cases render exactly as specified above when the widget fixtures are already local and timezone-safe
- when correlated peaks exist, the section includes one shared `Track distance to highest peak` / `Track distance from highest peak` block followed by the peak-name list
- while the panel is open, the left-side MGRS and zoom readouts are hidden
- the panel header remains accessible while long body content scrolls
- adding the panel does not change existing peak search or goto visibility semantics
- opening basemaps or peak-list drawers from any supported entry point leaves the selected track and visible track info panel intact
- existing right-side basemap and peak-list drawers still open after the panel is added
- `Escape` closes overlapping surfaces in the defined order: end drawer, peak info popup, map info popup, then track info panel, with one highest-priority visible surface closed per keypress
- returning to the map route with a still-valid `selectedTrackId` shows the panel again
- closing the panel clears only selected-track state and does not introduce any new marker-clearing behavior
5. Robot-driven widget journey tests must cover the critical flow using stable app-owned keys and the existing map harness:
- robot panel-visible tests must explicitly set a surface width at or above `RouterConstants.shellBreakpoint`
- shared robot harness pump helpers must accept an explicit surface-width seam and use it for panel-visible coverage
- hover or otherwise target a visible track through the existing map interaction seam
- primary-click to select the track
- observe selected state and the appearance of `Key('track-info-panel')`
- close the panel through `Key('track-info-panel-close')`
- verify selection clears and the panel disappears
6. Add route-entry or programmatic-selection coverage so an existing `showTrack(...)` path also reveals the panel when the map route opens. Keep `./test/widget/map_screen_route_entry_test.dart` as the canonical hidden-branch route-entry file, and update `./test/widget/tasmap_map_screen_test.dart` only where Tasmap-specific behavior overlaps with this feature.
7. Testability adjustments and seams:
- reuse `./test/harness/test_map_notifier.dart` for deterministic selected-track state
- keep production `showTrack()` hidden-branch coverage canonical in `./test/widget/map_screen_route_entry_test.dart`
- use real `MapNotifier` tests as the source of truth for `showTrack()` repository-resolution and miss-handling behavior; only extend `TestMapNotifier.showTrack()` with a GPX-repository seam if panel-specific widget tests require it
- keep the panel widget constructor easy to drive from widget tests with direct `GpxTrack` inputs and `onClose`
- use stable keys instead of visible text as the primary robot selectors
- add `Key('basemaps-drawer')` to `./lib/widgets/map_basemaps_drawer.dart`
- add `Key('show-basemaps-fab')` to the action-rail basemaps FAB in `./lib/widgets/map_action_rail.dart`
- update `./test/widget/map_screen_keyboard_test.dart` to migrate off `find.text('Basemaps')` and instead use `Key('show-basemaps-fab')` and `Key('basemaps-drawer')`, while covering keyboard `B` opening basemaps, first `Escape` closing the drawer, second `Escape` closing the track info panel, and non-`Escape` shortcut passthrough after popup dismissal
- the current `find.text('Basemaps')` assertion in `./test/widget/map_screen_keyboard_test.dart` is the brittle regression point that must be replaced by the stable basemap selectors above
- treat `PeakListPeakDialog` programmatic `showTrack(...)` entry as a concrete regression target for panel visibility and selected-track reconciliation
- require the panel close control to expose an accessible tooltip or semantic label such as `Close track info`
- avoid brittle animation timing by choosing deterministic animation behavior and using `pumpAndSettle()` where appropriate
8. Baseline automated coverage outcome:
- logic or presentation rules: unit tests
- UI behavior and state reactions: widget tests
- critical user journey: robot-driven widget journey test
</validation>

<done_when>
1. Selecting a track or showing a track reveals a left-side info panel with readable metadata and statistics.
2. Closing the panel clears the selected track and removes selected-track emphasis.
3. Peaks Climbed lists correlated peak names or `None`, and when peaks exist the section includes one shared `Track distance to highest peak` / `Track distance from highest peak` block using the existing stored track-level values.
4. Existing basemap and peak-list drawers still open correctly while the selected track and visible track info panel remain intact.
5. Automated tests cover presentation logic, panel UI behavior, and the critical selection-to-panel journey.
</done_when>
