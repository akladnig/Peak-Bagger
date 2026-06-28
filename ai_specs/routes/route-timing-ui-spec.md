<goal>
Add a richer route timing section to the saved-route info panel so users can compare Naismith and Scarf estimates, inspect how each value is derived, and save a per-route walking speed without overwriting verified timing already captured in the route.

This feature is for route planners working with imported and manually edited routes. The result should make route timing easier to understand and tune while preserving the current distinction between verified timing and geometry-derived timing.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, `flutter_map`, and the existing route timing helpers in `route_timing_service.dart`.

Current architecture and constraints:
- `./lib/screens/map_screen_panels.dart` currently renders the saved-route info panel and shows a single `Estimated Time` row plus inline explanation text.
- `./lib/services/route_timing_service.dart` already owns Naismith and Scarf helper formulas, timing-profile encode/decode helpers, and the current explanation text generation.
- `./lib/models/route.dart` currently stores `estimatedTime`, `routeTimingSource`, and `routeTimingProfileJson`, but it does not store a per-route walking speed or any persisted segment-level provenance that distinguishes preserved timing from manually estimated timing.
- `./lib/providers/map_provider.dart` and `./lib/services/gpx_importer.dart` currently populate route timing on import and route-save flows.
- `./lib/services/route_admin_editor.dart` rebuilds `Route` objects directly, so any new timing fields must be preserved there as well instead of being dropped silently.
- `./lib/screens/map_screen.dart` currently injects callbacks into `MapTrackInfoPanel`, and `MapTrackInfoPanel` is currently mounted directly in widget tests without a provider wrapper. The spec should preserve that test-friendly seam unless a broader panel refactor is explicitly intended.
- Peak-style popup visuals already exist in `./lib/screens/map_screen_panels.dart` via `PeakInfoPopupCard` / `PeakInfoPopupSurface`, and those styling patterns should be reused instead of inventing a second visual language.
- Changing the walking speed for display must not corrupt verified/import-derived timing, must not rewrite exported GPX timing data, and must not change track timing UI.

Files to examine:
- @lib/models/route.dart
- @lib/objectbox.g.dart
- @lib/providers/map_provider.dart
- @lib/screens/map_screen.dart
- @lib/screens/map_screen_panels.dart
- @lib/services/gpx_importer.dart
- @lib/services/route_admin_editor.dart
- @lib/services/objectbox_admin_repository.dart
- @lib/services/route_timing_service.dart
- @lib/services/route_repository.dart
- @lib/services/objectbox_schema_guard.dart
- @test/services/objectbox_admin_repository_test.dart
- @test/services/objectbox_schema_guard_test.dart
- @test/services/route_timing_service_test.dart
- @test/services/route_repository_test.dart
- @test/services/route_admin_editor_test.dart
- @test/widget/map_route_info_panel_test.dart
- @test/widget/map_screen_route_info_test.dart
- @test/robot/gpx_tracks/gpx_tracks_journey_test.dart
- @test/robot/map/route_info_robot.dart
- @test/robot/map/route_info_journey_test.dart

Output paths:
- Modify `./lib/models/route.dart`
- Modify regenerated ObjectBox artifacts under `./lib/objectbox.g.dart`
- Modify `./lib/providers/map_provider.dart`
- Modify `./lib/screens/map_screen.dart`
- Modify `./lib/screens/map_screen_panels.dart`
- Modify `./lib/services/gpx_importer.dart`
- Modify `./lib/services/route_admin_editor.dart`
- Modify `./lib/services/objectbox_admin_repository.dart`
- Modify `./lib/services/route_timing_service.dart`
- Modify `./lib/services/objectbox_schema_guard.dart`
- Modify `./test/services/objectbox_admin_repository_test.dart`
- Modify `./test/services/objectbox_schema_guard_test.dart`
- Modify focused tests under `./test/services/`, `./test/widget/`, and `./test/robot/map/`
</background>

<user_flows>
Primary flow:
1. User opens a saved route in the route info panel.
2. User sees an `Estimated Time` section with `Estimated Time (Naismith)` and `Estimated Time (Scarf)` rows.
3. User opens either row's info icon and reads a popup explaining that model and how preserved versus manual route segments contribute.
4. User adjusts `Walking Speed` with the stepper, keyboard shortcuts, or direct entry.
5. The panel recalculates the displayed times immediately for manual-estimated segments while keeping preserved verified timing unchanged.
6. The chosen walking speed persists to that route, so reopening the same route restores the last saved speed.

Alternative flows:
- Pure verified route: if every segment is preserved verified timing, both rows show the same total and speed changes do not alter the totals.
- Pure geometry-derived route: if every segment is manual-estimated, both rows recalculate the whole route from geometry using the selected speed.
- Mixed route with provenance: preserved segments stay fixed while only manual segments change, so Naismith and Scarf differ only on the manual portion.
- Reopen route: closing and reopening the panel restores the saved speed and the same displayed totals.

Error flows:
- Invalid direct-entry speed: keep the last valid persisted/displayed value active, show inline validation, and do not crash the panel.
- Legacy mixed route without persisted segment provenance: do not invent a false preserved/manual split; show the stored timing safely in a read-only fallback state and explain that adjustable timing is unavailable for that legacy mixed route because provenance was never stored.
</user_flows>

<discovery>
Before implementation, confirm the smallest persisted metadata shape that can safely reconstruct preserved versus manual timing contributions on reopen.

Answer these through code inspection:
- Whether a segment-aligned JSON field is cleaner than a point-aligned field for reconstructing preserved/manual timing splits alongside `routeTimingProfileJson`.
- Whether the route panel can reuse an extracted popup surface shared with peak/ETA popups, or whether a minimal route-timing-specific dialog shell is cleaner.
- Which existing `Route` copy/rebuild paths besides `map_provider.dart` and `route_admin_editor.dart` need to preserve any new timing fields.
</discovery>

<requirements>
**Functional:**
1. Change the saved-route timing section heading from `Time` to `Estimated Time`.
2. Replace the single saved-route `Estimated Time` row with two rows in this order:
   - `Estimated Time (Naismith)`
   - `Estimated Time (Scarf)`
3. Each timing row must render its label, an immediately adjacent info icon, and a right-aligned formatted duration value using the app's existing duration formatting conventions.
4. Remove the current inline explanation text block from under the heading. Explanation copy must move into the row-specific info popups.
5. Tapping or clicking a timing-row info icon must open a route-timing explanation popup styled with the same visual language as the peak info popup: card-like surface, matching background treatment, matching border/shape feel, and an explicit close affordance.
6. The Naismith and Scarf rows must have separate info triggers and separate explanation content. They may share layout infrastructure, but they must not open indistinguishable copy.
7. Add a `Walking Speed` control below the timing rows that includes:
   - a numeric value shown in `km/h`
   - a decrement button
   - an increment button
   - direct keyboard text entry
8. The speed control must allow values from `0.5` through `9.9` km/h inclusive in `0.1` increments.
9. Routes without a stored walking speed must default to `4.0` km/h the first time the new UI reads them. This is a read-time fallback only and must not persist automatically until the user makes a valid change.
10. The decrement and increment buttons must adjust the value by exactly `0.1` km/h per activation and clamp at the defined bounds.
11. Add keyboard shortcuts `-` and `_` for decrement and `+` and `=` for increment only when the walking-speed field itself or one of its stepper controls has focus. These shortcuts must not be active for the whole route panel and must not interfere with unrelated global map shortcuts.
12. Direct text entry must support normal typing/editing, but only valid values inside the allowed range may become the active persisted speed. Invalid or incomplete text must not overwrite the last valid active value.
13. Persistence timing for speed changes must be explicit:
   - stepper-button changes persist immediately
   - keyboard shortcut changes persist immediately
   - direct typed edits update local field state immediately but persist only when the field is submitted or loses focus with a valid final value
14. Persist the selected walking speed per route so closing and reopening that route restores the last saved valid value.
15. Changing the walking speed must update both displayed timing rows immediately after each valid change.
16. Walking-speed changes must affect only manual-estimated route segments. Preserved verified/import-derived timing must remain unchanged.
17. Add persisted route timing provenance metadata that distinguishes preserved timing from manual-estimated timing at segment granularity. An implementation such as `routeTimingSegmentKindsJson` or an equivalent persisted segment-aligned field is required; the metadata must be reconstructable after app restart.
18. The displayed Naismith total must be calculated as:
   - preserved segments: reuse stored per-segment durations derived from `routeTimingProfileJson`
   - manual-estimated segments: recalculate with the selected walking speed plus the existing Naismith ascent/descent penalties
19. The displayed Scarf total must be calculated as:
   - preserved segments: reuse the same stored per-segment durations as above
   - manual-estimated segments: recalculate with the selected walking speed plus the existing Scarf ascent weighting helper
20. For routes whose timing is entirely geometry-derived, all segments are manual-estimated and the entire displayed route total recalculates for both models.
21. For routes whose timing is entirely verified/import-derived, all segments are preserved and both displayed totals remain equal to the stored verified total.
22. For routes with mixed preserved/manual provenance, Naismith and Scarf may differ only on the manual portion. Preserved segments must contribute the same fixed duration to both totals.
23. Changing the walking speed must not rewrite or reinterpret the route's canonical persisted timing fields used by current import/export behavior:
   - `estimatedTime`
   - `routeTimingSource`
   - `routeTimingProfileJson`
24. Do not change GPX export timing semantics in this slice. Walking-speed adjustments are a route-info display feature plus per-route preference, not a GPX timing rewrite.
25. Populate timing provenance consistently for newly created or updated routes:
   - timestamped imports mark imported segments as preserved
   - untimed / Naismith-only imports mark all segments as manual-estimated
   - route edits preserve unchanged source segments where possible and mark inserted/replaced segments as manual-estimated
26. Preserve any new route timing fields anywhere a `Route` object is rebuilt or copied, including admin-editor flows, so the route timing UI does not silently reset after unrelated edits.
27. Keep `MapTrackInfoPanel` provider-agnostic and directly widget-testable. Route timing setting writes must flow through explicit injected callback(s) from `map_screen.dart` or an equivalent UI-owned seam rather than making the panel implicitly depend on Riverpod.
28. The write seam for route timing settings must also define how the selected route refreshes after save, such as updating the selected in-memory route plus bumping the existing route revision / invalidation seam so the panel rerenders with persisted values.
29. The panel must keep existing edit, export, close, and visibility interactions unchanged outside the timing section.
30. Add stable app-owned keys for the new timing rows, both info buttons, both popup roots, the popup close button, the walking-speed field, decrement button, increment button, and any legacy-provenance helper state that needs assertions.

**Error Handling:**
31. Invalid typed values such as empty input, non-numeric input, values below `0.5`, or values above `9.9` must show inline validation or equivalent field-level feedback without crashing the panel.
32. Until the input becomes valid again, the displayed route times must continue using the last valid active speed.
33. Legacy routes that lack both stored speed and segment provenance must still render safely.
34. Legacy routes with `routeTimingSource == naismith` may be treated as fully manual-estimated.
35. Legacy routes with `routeTimingSource == verifiedWalk` may be treated as fully preserved.
36. Legacy routes with mixed timing sources such as `verifiedWalkPlusNaismith` or `extendedRoute` but no persisted provenance must not guess at which segments were manual. For these routes specifically:
   - show the stored canonical time in the Naismith row, but treat it as the pre-existing stored mixed total rather than a recalculated pure Naismith estimate
   - show `—` in the Scarf row
   - disable the walking-speed control
   - show a concise inline limitation message explaining that adjustable timing is unavailable for this legacy mixed route because segment provenance was never stored
   - mention the same limitation in the timing info popups so the lack of adjustable timing is explained both inline and at the point of model explanation
   - require the Naismith popup copy in this fallback state to explain that the displayed value is the route's stored mixed timing total, not a fresh Naismith recalculation

**Edge Cases:**
37. If a route has no usable timing data, both timing rows must render `—` and the control must not crash. Disable recalculation interactions when they cannot produce a meaningful value.
38. A fully preserved route may show no visible time change when the speed changes; the popup copy must make that behavior understandable rather than looking broken.
39. Switching between selected routes must refresh the control to each route's own saved speed and provenance-derived totals.
40. Closing and reopening the same route panel during the same session must not reset unsafely to `4.0` if a valid per-route speed was already saved.
41. Speed stepper actions and keyboard shortcuts must honor one-decimal precision and must not accumulate floating-point display artifacts such as `4.3000000001`.

**Validation:**
42. Route timing calculation logic for preserved/manual mixes must live behind a deterministic service/helper boundary instead of being embedded ad hoc in the widget tree.
43. Popup explanation content must be testable through stable keys and deterministic copy inputs rather than timing-sensitive overlay behavior.
44. The feature must add baseline automated coverage for logic, widget behavior, and at least one robot-driven route info journey.
</requirements>

<boundaries>
Edge cases:
- This slice applies only to saved-route timing UI, not track timing UI.
- The feature is allowed to add new persisted route metadata, but it must not reinterpret old verified timing as synthetic geometry timing.
- Fully verified routes may legitimately show unchanged totals when the walking speed changes.
- Legacy mixed routes without provenance are a compatibility constraint, not a reason to fabricate incorrect recalculations.

Error scenarios:
- Invalid speed input: show inline validation and keep the last valid totals active.
- Missing timing data: show safe placeholders rather than crashing.
- Legacy mixed route without provenance: use the defined read-only fallback, avoid false recalculation, and explain that the visible left-hand row is a stored mixed total rather than a fresh Naismith recomputation.

Limits:
- Do not add a global walking-speed preference in this slice.
- Do not change GPX export/import semantics beyond adding the provenance metadata needed for future recalculation.
- Do not replace the existing canonical timing storage fields with display-only values.
- Do not broaden this into a full route-timing editor, track-timing UI refresh, or route statistics redesign.
</boundaries>

<implementation>
Files to create or modify:
- `./lib/models/route.dart`
- `./lib/objectbox.g.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/services/route_admin_editor.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/services/route_timing_service.dart`
- `./lib/services/objectbox_schema_guard.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/services/objectbox_schema_guard_test.dart`
- `./test/services/route_timing_service_test.dart`
- `./test/services/route_repository_test.dart`
- `./test/services/route_admin_editor_test.dart`
- `./test/widget/map_route_info_panel_test.dart`
- `./test/widget/map_screen_route_info_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- `./test/robot/map/route_info_robot.dart`
- `./test/robot/map/route_info_journey_test.dart`

Implementation expectations:
- Add a persisted `walkingSpeedKmh` field on `Route` with a default behavioral value of `4.0` km/h for legacy rows that do not yet store it.
- Treat that `4.0` value as a read-time fallback only; do not write it back merely because the panel opened.
- Add a persisted segment-provenance field on `Route`, preferably segment-aligned JSON, that records whether each segment is `preserved` or `manualEstimated`.
- Keep the new timing display calculation in `route_timing_service.dart` as a pure, testable API that accepts route geometry, elevations, canonical timing profile, provenance metadata, and walking speed, then returns both displayed totals and popup explanation details.
- Reuse the existing `scarfTime` / `scarfDistance` and Naismith constants rather than duplicating formulas in widgets.
- If the current helpers are too rigid because they hardcode the flat speed constant, extend them with explicit speed parameters for display calculations while preserving existing import/export callers that still rely on current defaults.
- Derive preserved segment durations from `routeTimingProfileJson` by diffing adjacent cumulative values rather than storing duplicate preserved durations elsewhere.
- Populate provenance metadata when importing timestamped routes, importing untimed routes, and saving edited routes.
- Preserve new timing fields whenever a `Route` instance is reconstructed, especially in `route_admin_editor.dart`.
- Keep `MapTrackInfoPanel` standalone and directly widget-testable. Local widget state may own editing/validation, but route persistence must flow through explicit injected callbacks wired from `map_screen.dart` into `mapProvider` / repository logic.
- Persist stepper-button and shortcut changes immediately, but keep typed text local until submit or focus loss confirms a valid final value.
- After a successful timing-settings write, trigger the existing route refresh/invalidation path so the selected route panel rerenders from the persisted data.
- When rendering the legacy mixed-route fallback, make the popup and helper copy explicitly distinguish `stored mixed total` from `recalculated Naismith total` so the UI does not mislabel the value.
- Reuse the existing route info panel structure and keep the change local to the route body instead of redesigning the full shared panel shell.
- Reuse peak-popup visual styling tokens/components where practical for the timing info dialogs, but avoid forcing anchored map-popup behavior onto a route-panel dialog if that adds complexity.
- Prefer stable `Key` selectors over text-only assertions for the new controls and popups.
- Implement the defined read-only legacy mixed-route fallback exactly rather than leaving that state to implementer judgment.

Avoid:
- Avoid recalculating canonical export timing from walking-speed changes.
- Avoid embedding formula logic directly in `MapTrackInfoPanel`.
- Avoid guessing manual versus preserved segments for legacy mixed routes.
- Avoid a new app-wide settings dependency for walking speed.
- Avoid making `MapTrackInfoPanel` provider-owned unless a larger panel-architecture change is intentionally approved.
</implementation>

<stages>
Phase 1: Model the new timing inputs and provenance.
- Add the new route persistence fields and any supporting enum/value helpers.
- Verify with failing service/repository/admin/schema tests for field round-trip, legacy defaults, provenance decoding, admin-row exposure, and schema-signature coverage.

Phase 2: Build the display-timing calculator.
- Add a pure service/helper API that computes Naismith and Scarf display totals from canonical timing plus provenance plus walking speed.
- Verify with failing service tests for fully preserved, fully manual, mixed, legacy-naismith, legacy-verified, and legacy-mixed-without-provenance cases.

Phase 3: Wire the route info panel.
- Replace the inline explanation block with the new rows, popups, speed control, validation, and per-route persistence.
- Verify with failing widget tests for row rendering, popup content, stepper updates, control-scoped keyboard shortcuts, direct-entry validation, legacy mixed read-only fallback, and reopen persistence.

Phase 4: Add end-to-end route-info journey coverage.
- Extend the route info robot and journey test to open a route, adjust walking speed, verify both totals, reopen the route, and confirm the saved speed remains in effect.
- Verify selector stability and deterministic route-repository behavior.
</stages>

<validation>
Follow strict vertical-slice TDD: one failing test at a time, minimal production change to green, then refactor only after that slice passes.

Behavior-first TDD slices:
1. Add a failing repository/model test for `walkingSpeedKmh` and provenance metadata round-tripping through `Route` persistence.
2. Add a failing service test for a fully manual route recalculating both Naismith and Scarf totals from the selected speed.
3. Add a failing service test for a fully preserved route keeping both totals fixed when the selected speed changes.
4. Add a failing service test for a mixed route where only manual segments change and preserved segments remain fixed.
5. Add a failing service test for the legacy mixed-without-provenance fallback so implementation does not fabricate a false segment split.
6. Add a failing admin-repository test for the new route timing fields appearing in route admin rows.
7. Add a failing schema-guard test for the new persisted route timing fields appearing in the schema signature.
8. Add a failing widget test for rendering the two timing rows and removing the old inline explanation block.
9. Add a failing widget test for opening each info popup and showing distinct Naismith versus Scarf explanation content, including the legacy limitation copy when that fallback state is active.
10. Add a failing widget test for stepper-based speed updates changing both displayed values and persisting the valid speed.
11. Add a failing widget test for direct-entry validation, local editing state, and persist-on-submit-or-blur behavior.
12. Add a failing widget test for keyboard shortcuts `-`, `_`, `+`, and `=` updating the speed control only when the field/stepper controls are focused.
13. Add a failing widget test for the legacy mixed-route read-only fallback.
14. Add a failing robot journey test for route open -> speed adjust -> totals update -> close/reopen -> saved speed restored.

Baseline automated coverage outcomes:
- Logic/business rules: speed-bound validation, provenance decoding, preserved/manual split behavior, Naismith display calculation, Scarf display calculation, legacy fallback behavior, and persistence round-trip.
- UI behavior: two-row timing layout, popup open/close, inline validation, stepper behavior, control-scoped keyboard shortcuts, disabled/limitation states, and reopen persistence.
- Critical user journey: open saved route, inspect timing details, adjust speed, and confirm the route remembers that speed on reopen.

Required deterministic seams:
- Keep timing calculations in a pure service/helper callable from unit tests without widget harnesses.
- Use repository-backed or fake route persistence in widget/robot tests so saved-speed behavior is deterministic, and keep the route panel mountable without a ProviderScope by injecting callbacks in panel-only widget tests.
- Add stable keys for timing rows, info buttons, popup roots, popup close buttons, speed field, decrement button, increment button, and any legacy limitation state.
- Keep popup presentation testable with `pump` / `pumpAndSettle`; avoid timer-heavy custom overlay behavior that requires `runAsync`.

Robot coverage expectations:
- Extend `./test/robot/map/route_info_robot.dart` rather than creating a second route-info robot.
- Keep selectors key-first.
- Put the critical journey in `./test/robot/map/route_info_journey_test.dart`.
- Cover at least one keyboard or stepper adjustment path plus reopen persistence in the robot lane.
- Update any existing robot journey assertions that still depend on the old single `route-estimated-time-row` contract, including `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`.

Known testing risk to report explicitly if it remains:
- Legacy mixed routes without provenance have an intentional compatibility limitation. Tests must assert the documented fallback so future changes do not silently guess incorrect recalculations.
</validation>

<done_when>
- The saved-route info panel shows `Estimated Time (Naismith)` and `Estimated Time (Scarf)` rows with separate info popups.
- The old inline timing explanation text is gone from the route panel body.
- Users can adjust `Walking Speed` between `0.5` and `9.9` km/h through buttons, keyboard shortcuts, and direct entry.
- Valid speed changes update displayed totals immediately and persist per route.
- Preserved timing remains fixed while manual-estimated timing recalculates.
- New routes save enough provenance metadata to support that split on reopen.
- Legacy pure verified and pure manual routes behave safely, and legacy mixed routes use the documented read-only non-guessing fallback.
- Automated tests cover the calculation logic, widget behavior, and the critical route-info journey.
</done_when>
