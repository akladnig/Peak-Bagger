<goal>
Group the map screen action rail into clearer functional sections so the existing map controls are easier to scan and use without changing their behavior.
This matters because the current rail is visually dense; grouping should improve discoverability for desktop and mobile users while preserving the current map interaction model.
</goal>

<background>
`./lib/widgets/map_action_rail.dart` currently renders a single vertical stack of map FABs at the top-right of the map screen. `./lib/screens/map_screen.dart` hosts that widget, and existing widget and robot coverage already depends on stable keys such as `show-basemaps-fab`, `grid-map-fab`, `show-tracks-fab`, `show-peaks-fab`, `search-peaks-fab`, `goto-map-fab`, `import-tracks-fab`, and `map-info-fab`.
This is a UI-only refactor: keep the current actions, providers, and drawer behavior intact.
Files to examine: `./lib/widgets/map_action_rail.dart`, `./lib/widgets/left_tooltip_fab.dart`, `./lib/screens/map_screen.dart`, `./test/widget/tasmap_display_mode_test.dart`, `./test/widget/map_screen_keyboard_test.dart`, `./test/widget/map_screen_peak_info_test.dart`, `./test/robot/tasmap/tasmap_journey_test.dart`, `./test/robot/tasmap/tasmap_robot.dart`, `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
</background>

<discovery>
1. Confirm the smallest layout change that preserves all existing FAB actions and selector keys while introducing grouped containers.
2. Confirm whether the grouped rail needs an internal vertical scroll container on short screens to avoid clipping after adding section headers and the placeholder control.
3. Confirm the info FAB should remain visually separate at the bottom-right of the screen, not inside the grouped rail stack.
</discovery>

<user_flows>
Primary flow:
1. User opens the map screen.
2. User sees three labeled sections in the action rail: Tools, View, and Loc.
3. User chooses an action from the appropriate section.
4. The existing action behaves exactly as it does today.
5. The Info FAB remains separately anchored at the bottom-right.

Alternative flows:
1. User uses keyboard or robot-driven tests to open map actions by stable keys; the grouping must not break those selectors.
2. User taps the new Create Route placeholder; it remains inert and does not change map state.
3. User returns to the map after opening a drawer or popup; the grouped rail remains in the same place and the existing controls still work.

Error flows:
1. If the grouped layout exceeds the available height, the controls should remain usable by scrolling instead of clipping or overlapping the map.
2. If the placeholder is accidentally enabled during implementation, it must still not mutate map state or open any drawer.
</user_flows>

<requirements>
**Functional:**
1. Replace the flat top-right action stack with three labeled containers: `Tools`, `View`, and `Loc`.
2. Render the `Tools` container with `Import Track` first and `Create Route` second.
3. Add a disabled `Create Route` placeholder FAB with `SvgPicture.asset('assets/route.svg')`, `Key('create-route-fab')`, and no side effects.
4. Render the `View` container with `Select Basemaps`, `Show Map Grid`, `Select Peak List`, and `Show tracks` in that order.
5. Keep the existing peaks drawer behavior for the renamed `Select Peak List` button; only the user-facing label changes.
6. Render the `Loc` container with `Search Peaks`, `Goto Location`, `Center on marker`, and `My location` in that order.
7. Keep the Info FAB separate from the grouped rail and anchor it at the bottom-right without a container.
8. Preserve the current action behavior, hero tags, and provider interactions for all existing controls.
9. Keep every action icon-only, and make each control's tooltip message and semantics label match the wording used in this spec.
10. Change the `Select Peak List` control's tooltip message and semantics label to `Select Peak List`.
11. Give the three grouped containers stable keys so tests can target them without relying on visible text.
12. Use `UiConstants.groupSpacing` between section containers and `UiConstants.railSpacing` within each section.

**Error Handling:**
13. If the grouped rail would overflow the screen height, the layout must remain usable through vertical scrolling rather than clipping or obscuring controls.
14. The `Create Route` placeholder must remain inert even if it is rendered in an enabled state by mistake.

**Edge Cases:**
15. The grouped layout must work on both desktop and compact mobile sizes without covering the map interaction region.
16. Existing stable keys must remain attached to the real action buttons so current tests can survive the layout change.
17. The new group containers must not change the visible ordering of the existing buttons within each group.
18. Keyboard focus and semantics order must follow the visual top-to-bottom order of the grouped rail, with Info last, using explicit traversal or sort keys if needed.

**Validation:**
19. Require baseline automated coverage for UI behavior and the critical map-action journey.
20. Preserve the existing `MapRebuildDebugCounters.actionRailBuilds` assertion path by keeping the rail's provider-watching build boundary at the top-level widget and making grouped sections pure children.
</requirements>

<boundaries>
Edge cases:
1. Compact-height screens may need scrolling, but the rail must not clip or hide actions.
2. The renamed `Select Peak List` label must still open the existing peak lists drawer.
3. The info action must stay separate from the grouped rail and keep its existing popup behavior.
4. The bottom-right Info FAB must respect safe-area / view-padding insets so it is not obscured on mobile devices.
5. Section headers should be plain text labels, styled to match `./screenshot.png`; use the current FAB background color and keep the screenshot as the visual source of truth.

Error scenarios:
1. A disabled placeholder must never trigger map state changes.
2. Any new wrapper widgets must not swallow taps or hover tooltips for the existing FABs.

Limits:
1. Do not change map provider state, drawer logic, or route navigation.
2. Do not rename or remove existing keys unless this spec explicitly adds a new one.
3. Do not implement real route creation here; the new control is a placeholder only.
4. Bundle `assets/route.svg` in `pubspec.yaml` so the placeholder icon resolves at runtime.
</boundaries>

<implementation>
Modify `./lib/widgets/map_action_rail.dart` in place to split the current rail into grouped sections and to move the Info FAB to a bottom-right position.
Keep `MapActionRail` as the single build-counted, provider-watching boundary; the grouped sections should be pure/presentational children so `MapRebuildDebugCounters.actionRailBuilds` stays stable.
If a tiny section-definition helper is needed for testability, keep it local and pure; do not widen the scope beyond the rail widget.
Add or update widget coverage in `./test/widget/map_screen_rebuild_test.dart`, `./test/widget/map_action_rail_grouping_test.dart`, or `./test/widget/tasmap_display_mode_test.dart` for the new section order, the disabled placeholder, the bottom-right info placement, and the unchanged rebuild counter behavior.
Update robot helpers and journeys in `./test/robot/tasmap/tasmap_robot.dart` and `./test/robot/tasmap/tasmap_journey_test.dart` if they need new group selectors for map-screen assertions.
Keep `LeftTooltipFab` unchanged unless a new wrapper makes hover/semantics behavior fail.
Avoid touching `./lib/screens/map_screen.dart` unless the grouped rail cannot stay self-contained.
Add stable keys for `Tools`, `View`, and `Location` group containers so robot tests can anchor on the new structure.
</implementation>

<stages>
Phase 1: Layout split
1. Convert the flat action column into labeled Tools, View, and Loc groups.
2. Add the disabled Create Route placeholder and move the Info FAB to the bottom-right.
3. Verify the existing action buttons still render with their current keys.

Phase 2: Selector and behavior stability
1. Rename the peaks drawer button label to `Select Peak List`.
2. Confirm the existing actions still open the same drawers and toggle the same map state.
3. Add any new stable keys needed for the grouped containers.

Phase 3: Test and polish
1. Add or update widget tests for group order, placeholder inertness, and info placement.
2. Update one robot journey or helper to assert the grouped rail on the map screen.
3. Run the relevant Flutter tests and fix regressions before finishing.
</stages>

<illustrations>
Desired:
1. `Tools` contains `Import Track` and a disabled `Create Route` placeholder.
2. `View` contains `Select Basemaps`, `Show Map Grid`, `Select Peak List`, and `Show tracks`.
3. `Loc` contains `Search Peaks`, `Goto Location`, `Center on marker`, and `My location`.
4. `Info` floats independently at the bottom-right.

Undesired:
1. A single long ungrouped rail with no section labels.
2. `Create Route` mutating map state or opening a drawer.
3. The info button becoming part of the top-right rail stack.
</illustrations>

<validation>
Use vertical-slice TDD if a small section-definition helper is introduced: add one test for section ordering, then one for the placeholder, then one for the info placement, keeping each cycle public and deterministic.
Prefer widget tests for layout and selector coverage; use robot coverage only for the critical map-screen journey that proves the grouped rail is still reachable and the existing actions still work.
Required automated coverage outcome:
1. `widget`: group headers, group order, renamed peaks label, disabled placeholder, and bottom-right info placement.
2. `robot`: open the map screen and verify the grouped rail is visible, then tap a representative action from each group and confirm the placeholder stays inert while Info remains separate.
3. `unit`: only if a pure helper is introduced; cover the section definition/order without depending on widget internals.
Stable selectors to keep or add:
1. Preserve existing keys on real buttons, including `show-basemaps-fab`, `grid-map-fab`, `show-tracks-fab`, `show-peaks-fab`, `search-peaks-fab`, `goto-map-fab`, `import-tracks-fab`, and `map-info-fab`.
2. Add `Key('create-route-fab')` for the placeholder.
3. Add stable group keys `Key('map-action-tools-group')`, `Key('map-action-view-group')`, and `Key('map-action-location-group')`.
</validation>

<done_when>
The spec is complete when the map action rail is visibly grouped into Tools, View, and Loc sections, the Info FAB is independently anchored at the bottom-right, the Create Route placeholder exists but does nothing, the peaks drawer button reads `Select Peak List`, all existing actions still behave the same, and the updated widget and robot coverage passes.
</done_when>
