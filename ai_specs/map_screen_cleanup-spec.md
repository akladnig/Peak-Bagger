<goal>
Refactor `./lib/screens/map_screen.dart` into smaller, cohesive screen-scoped files without changing route behavior, widget keys, or user-visible map interactions.

This cleanup matters because `MapScreen` currently mixes controller ownership, keyboard/pointer handling, layer construction, overlay UI, and small presentation helpers in one file. The result should be a thinner screen entry point that is easier to navigate while preserving current behavior.
</goal>

<background>
Tech stack: Flutter, Riverpod, `flutter_map`, `latlong2`, and existing widget/robot tests.

Constraints:
- Keep `./lib/screens/map_screen.dart` as the stable route-facing screen entry point.
- Do not change `mapProvider`, `MapState`, `MapNotifier`, or `gpx_importer.dart` as part of this task.
- Do not add packages.
- Preserve existing widget keys, focus behavior, keyboard shortcuts, overlay behavior, and layer ordering.
- Keep existing reusable widgets in `./lib/widgets/` where they are today.

Files to examine:
- @lib/screens/map_screen.dart
- @lib/widgets/map_action_rail.dart
- @lib/widgets/map_basemaps_drawer.dart
- @lib/widgets/tasmap_outline_layer.dart
- @lib/widgets/tasmap_polygon_label.dart
- @lib/providers/map_provider.dart
- @test/widget/tasmap_map_screen_test.dart
- @test/widget/gpx_tracks_selection_test.dart
- @test/widget/gpx_tracks_recovery_test.dart
- @test/robot/tasmap/tasmap_journey_test.dart
- @test/robot/gpx_tracks/gpx_tracks_journey_test.dart

Output paths:
- Keep `./lib/screens/map_screen.dart` as the route/screen shell.
- Create `./lib/screens/map_screen_interactions.dart` only if enough cohesive pure/support interaction logic remains after shell-owned callbacks are kept in `map_screen.dart`; otherwise keep those helpers in the shell.
- Create `./lib/screens/map_screen_layers.dart` for tile, marker, polygon, label, and polyline construction helpers.
- Create `./lib/screens/map_screen_panels.dart` for the peak-search panel, goto panel, info popup, and small overlay readouts such as the MGRS display.
- Add targeted widget regressions in `./test/widget/map_screen_keyboard_test.dart`.
- Add targeted widget regressions in `./test/widget/map_screen_peak_search_test.dart`.
</background>

<user_flows>
These are regression flows to preserve.

Primary flow:
1. User opens the map screen.
2. User pans/zooms the map, opens overlays, and interacts with visible map content.
3. The map responds exactly as it does today, with the same focus behavior, keys, and visible states.

Alternative flows:
- Goto flow: user opens the goto panel, types a query, sees suggestions or errors, and navigates to a selected result.
- Peak search flow: user opens peak search, filters results, and centers on a selected peak.
- Track interaction flow: user hovers or selects tracks and sees the same selection and info behavior.
- Tasmap flow: user toggles overlays or selects a Tasmap and sees the same outline and label behavior.

Error flows:
- Invalid goto input: the same inline error and recovery behavior remains intact.
- Track recovery state: the same warning/disabled interaction behavior remains intact.
- Empty peak search result: the same visible empty state remains intact.
</user_flows>

<discovery>
Before implementation, confirm:
- Which helpers inside `MapScreen` are pure enough to move unchanged versus which must stay in `_MapScreenState` because they require direct controller or `setState` access.
- Which widget keys and visible text are used by existing widget and robot tests.
- Which extracted pieces are screen-scoped helpers versus truly reusable widgets that should stay in `./lib/widgets/`.
- This refactor will not introduce `part` / `part of`; extracted files must use explicit inputs and callbacks.
</discovery>

<requirements>
**Functional:**
1. Reduce `./lib/screens/map_screen.dart` to screen composition, controller ownership, and the minimum glue that still requires direct `_MapScreenState` access.
2. Extract only screen-scoped pure interaction helpers and lightweight support logic into `./lib/screens/map_screen_interactions.dart` if enough cohesive logic remains after shell-owned callbacks stay in `map_screen.dart`; otherwise keep those helpers in the shell.
3. Extract layer-building helpers into `./lib/screens/map_screen_layers.dart`.
4. Extract overlay/panel UI into `./lib/screens/map_screen_panels.dart`.
5. Preserve the `MapScreen` class name, route behavior, and existing imports from outside the screen feature.
6. Preserve all existing widget keys used by tests, including map interaction, goto, Tasmap label, and peak-layer keys.
7. Preserve current layer ordering so markers, tracks, overlays, and labels render in the same order they do today.
8. Preserve current test-visible label and warning text, including Tasmap labels and recovery messaging such as `Some tracks need to be rebuilt.`.

**Error Handling:**
9. Preserve the current invalid goto-input error behavior and close/submit flows.
10. Preserve current behavior when hover state, selection state, or info popup state is cleared during map interaction.
11. Preserve current focus recovery behavior when goto and search fields are opened or closed.

**Edge Cases:**
12. Preserve keyboard shortcut behavior for zooming, movement, goto, info, basemap drawer, centering, overlay toggle, and track toggle.
13. Preserve pointer behavior for click-versus-drag handling, pointer cancel, pointer exit, and info-popup dismissal on movement/click.
14. Preserve zoom-based visibility rules for peaks and Tasmap labels.
15. Keep screen-scoped extracted files cohesive; do not create one-method files or duplicate existing `./lib/widgets/` components.

**Validation:**
16. Keep existing widget and robot regressions green for Tasmap labels, goto interactions, peak-layer visibility, and map interaction state.
17. If extraction exposes an untested public-visible behavior, add the smallest regression test needed before or during the split.
18. Add targeted widget regressions in `./test/widget/map_screen_keyboard_test.dart` covering keyboard shortcuts and focus recovery.
19. Add targeted widget regressions in `./test/widget/map_screen_peak_search_test.dart` covering peak-search open/close, empty-result state, and selecting a peak result.
20. Do not rewrite tests merely to match a new internal file layout.
</requirements>

<boundaries>
Edge cases:
- Some helpers may need to remain in `map_screen.dart` if they depend tightly on `_MapScreenState`, `MapController`, focus nodes, or `setState`.
- Existing reusable widgets such as `MapActionRail`, `MapBasemapsDrawer`, `TasmapOutlineLayer`, and `TasmapPolygonLabelLayer` are not targets for relocation in this task.

Error scenarios:
- If an extraction breaks a stable widget key or robot interaction path, restore compatibility rather than changing the test journey.
- If a helper cannot move without introducing awkward public API just for the refactor, leave it in `map_screen.dart` for this pass.
- If cleanup exposes tempting key or text normalization, preserve the current test-visible behavior rather than renaming keys or revising copy during this refactor.
- Preserve current finder-visible Tasmap key behavior, including the existing `tasmap-layer` and `tasmap-label-layer` usage patterns, unless the spec is later updated to authorize test-surface changes.

Limits:
- No provider refactor.
- No importer refactor.
- No UX redesign.
- No dependency changes.
</boundaries>

<implementation>
Do not introduce `part` / `part of` files for this refactor. Keep the extraction screen-scoped using top-level helpers with explicit inputs, small widgets with explicit constructor arguments, or shell-owned callbacks passed into extracted widgets.

Any logic that directly calls `setState`, mutates `MapController`, mutates `TextEditingController` or `FocusNode`, or schedules post-frame callbacks stays in `./lib/screens/map_screen.dart` unless it is invoked through a shell-owned callback.

`./lib/screens/map_screen_interactions.dart` should contain only screen-scoped pure helpers and lightweight support logic for interaction behavior, and should be introduced only if enough cohesive helper logic remains after shell-owned callbacks stay in `./lib/screens/map_screen.dart`. The `Focus.onKeyEvent` implementation, `MapOptions` pointer callbacks, and any interaction code that directly mutates widget state, `MapController`, focus/controllers, or provider state remain in `./lib/screens/map_screen.dart`.

Implementation expectations:
- `./lib/screens/map_screen.dart` should remain the only externally imported screen file for the map route.
- `./lib/screens/map_screen_interactions.dart`, if created, may use screen-scoped helpers that operate on explicit controller/focus-node/state inputs passed from `_MapScreenState`.
- `./lib/screens/map_screen_layers.dart` should own only map-layer construction and related display helpers.
- `./lib/screens/map_screen_panels.dart` should own the goto/search/info popup UI and the MGRS display formatting or overlay-readout widget logic.
- Keep `./lib/widgets/` components in place and compose them from `MapScreen` rather than moving them.
- `./lib/screens/map_screen.dart` remains the shell owner for controller-driven callbacks such as goto submission, map camera movement, map-extent zooming, and provider synchronization triggered by camera updates.
- Extracted panels and interaction helpers may invoke shell-owned callbacks, but they must not take ownership of map-camera mutation or route/navigation coordination.
- Add app-owned keys only if current selectors are insufficient for deterministic keyboard, focus, peak-search, or related screen regressions; otherwise prefer existing stable selectors and avoid icon-only or copy-only finders when a stable key is practical.

Avoid:
- Moving map-domain logic out of `mapProvider` into screen files.
- Creating new providers or state containers for this cleanup.
- Renaming widget keys, route-visible types, or existing reusable widget files.
</implementation>

<stages>
Phase 1: Identify stable test-visible surfaces.
- Confirm keys, visible text, overlay behaviors, keyboard shortcuts, focus transitions, and layer-order expectations that must remain unchanged.
- Decide whether any new stable keys are required for deterministic keyboard or peak-search tests.

Phase 2: Extract screen interactions.
- Move only pure/support interaction helpers into `map_screen_interactions.dart` if enough cohesive helper logic remains; otherwise keep those helpers in `map_screen.dart`. Keep shell-owned key and pointer callbacks in `map_screen.dart`.
- Verify interaction-related widget and robot coverage, including keyboard/focus regressions if coverage is missing.

Phase 3: Extract layer helpers.
- Move tile, marker, polygon, label, and polyline construction into `map_screen_layers.dart`.
- Verify layer visibility and ordering coverage.

Phase 4: Extract panels.
- Move goto/search/info popup UI into `map_screen_panels.dart`.
- Verify goto, Tasmap, and peak-search regression coverage.

Phase 5: Final cleanup.
- Remove dead imports.
- Confirm `map_screen.dart` is now a thin composition shell.
- Run analysis and tests.
</stages>

<validation>
Baseline automated coverage outcomes:
- UI behavior: widget tests continue to cover Tasmap labels, peak-layer visibility, layer ordering, and map interaction surfaces.
- Critical user journeys: robot tests continue to cover goto/Tasmap flow and GPX-track-related map journeys that touch `MapScreen`.
- Logic/business rules: if a newly extracted pure helper encodes non-trivial display rules such as layer ordering, zoom gating, or selected-track styling, cover it with a focused unit or widget regression rather than relying only on broad widget or robot coverage.
- Compatibility: current test-visible key names, warning text, and label text remain stable across the refactor.

TDD expectations:
- Treat pure file moves as refactor work under existing green coverage.
- If an extraction changes behavior-sensitive code, add one focused failing regression test first, make the smallest change to pass it, then continue.

Selector policy:
- Prefer existing app-owned `Key` selectors.
- If newly required keyboard, focus, peak-search, or related screen regressions lack deterministic selectors, add the smallest set of new stable keys needed to cover those flows.
- Avoid relying on icon-only or copy-only selectors when a stable key is practical.

Minimum keyboard/focus coverage floor:
- At minimum, cover one zoom shortcut path.
- At minimum, cover one directional movement shortcut path.
- At minimum, cover `g` opening the goto input.
- At minimum, cover one focus-return path after closing goto or peak search.
- At minimum, cover one info-popup keyboard path, either open or dismiss.

Recommended regression targets:
- `flutter test test/widget/tasmap_map_screen_test.dart`
- `flutter test test/widget/gpx_tracks_selection_test.dart`
- `flutter test test/widget/gpx_tracks_recovery_test.dart`
- `flutter test test/widget/map_screen_keyboard_test.dart`
- `flutter test test/widget/map_screen_peak_search_test.dart`
- `flutter test test/widget/tasmap_map_screen_test.dart --plain-name "selected map label renders on one Tasmap layer"`
- `flutter test test/widget/gpx_tracks_recovery_test.dart --plain-name "hovering a visible track sets hover state and clears on exit"`
- `flutter test test/robot/tasmap/tasmap_journey_test.dart`
- `flutter test test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- `./lib/screens/map_screen.dart` is reduced to a clearer screen shell with cohesive helper code moved into adjacent screen-scoped files.
- Existing route behavior, widget keys, focus behavior, keyboard shortcuts, overlay behavior, and layer ordering are preserved.
- Existing reusable widgets under `./lib/widgets/` remain in place.
- `flutter analyze` and `flutter test` pass.
- New keyboard/focus and peak-search regressions live in their dedicated widget test files rather than being scattered across unrelated tests.
</done_when>
