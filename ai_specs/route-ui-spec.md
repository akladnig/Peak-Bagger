<goal>
Refine the route creation UI so the elevation graph and the controls are split into two separate overlay surfaces: the graph stays bottom-left, the control strip stays bottom-right, and the route name / Cancel / Save line up cleanly with the adjacent icon buttons.
This matters because route drafting is a primary flow and the current single-row layout becomes visually cramped and misaligned on desktop and narrow widths.
</goal>

<background>
The app is a Flutter/Riverpod map app. Route drafting currently lives in `./lib/widgets/map_route_bottom_sheet.dart` and is driven by `./lib/providers/map_provider.dart`.
The current route sheet already exposes stable keys and behaviors used by tests, including `route-name-field`, `route-mode-route-to-peak`, `route-mode-straight-line`, `route-mode-out-and-back`, `route-mode-close-loop`, `route-undo-button`, `route-redo-button`, `route-cancel-button`, and `route-save-button`.
Relevant tests: `./test/widget/map_screen_route_sheet_test.dart`, `./test/robot/map/map_route_robot.dart`, and `./test/robot/map/map_route_journey_test.dart`.
This change should stay UI-only; no route planning, persistence, export, or draft state semantics should change.
The split layout should be implemented as separate overlay surfaces so the graph and control panels can be repositioned independently later.
The overlay entries should be owned by the map screen layer, not by the route sheet widget itself, so lifecycle and positioning can be controlled centrally.
The old `route-bottom-sheet` root is replaced by explicit overlay-root keys and the tests should be updated to target those new roots.
Every test/helper that references `route-bottom-sheet` must be migrated to the new overlay-root keys.
</background>

<discovery>
Review the current route sheet layout in `./lib/widgets/map_route_bottom_sheet.dart` and confirm where the graph and control shell are composed.
Inspect `./test/widget/map_screen_route_sheet_test.dart` for the existing width/alignment expectations and narrow-viewport assertions.
Check `./test/robot/map/map_route_robot.dart` and `./test/robot/map/map_route_journey_test.dart` to keep selector names stable and to extend the visible journey coverage if needed.
Identify the exact `OverlayEntry` insertion/removal points in the map screen layer and the stable keys needed for each overlay root.
</discovery>

<user_flows>
Primary flow:
1. User opens Create Route.
2. The route editor appears with the elevation graph anchored bottom-left and the control strip anchored bottom-right as separate overlay surfaces.
3. The user reads the graph, edits the route name, toggles route modes, and uses out-and-back/close-loop/undo/redo.
4. The user cancels or saves from the aligned action row.

Alternative flows:
- Narrow desktop viewport: the control strip scrolls horizontally as a unit while the graph panel remains anchored.
- Returning user: reopening the route editor shows the same split layout and the same control positions; no stale layout state is preserved.
- Invalid or in-progress route state: disabled buttons remain disabled, but the layout still reads as two aligned panels.

Error flows:
- Route name validation errors appear without pushing the action buttons out of alignment or obscuring controls.
- Routing or save-in-progress states do not reflow the panels in a way that breaks access to Cancel/Save.
- If the graph content is absent or empty, the control strip still renders and the route draft remains usable.
</user_flows>

<requirements>
**Functional:**
1. Split the route editor UI into two separate `OverlayEntry` panels: an elevation-graph overlay aligned bottom-left and a control overlay aligned bottom-right.
2. Own the overlay lifecycle in `./lib/screens/map_screen.dart` (or an equivalent map-screen overlay host) so both entries are inserted together, repositioned together, and removed together.
3. Create the graph overlay before the control overlay so the control overlay sits on top in the overlay stack.
4. Use explicit root keys `route-graph-overlay-root` and `route-controls-overlay-root`; remove the old `route-bottom-sheet` root contract.
5. Synchronize the overlays from `isRouteDrafting` on mount and on every draft-state change so the two entries are created on the first `true`, updated/repositioned on rebuilds, and removed on `false` and `dispose`.
6. Give both overlay panels the same outer padding and insets so they read as a matched pair.
7. Keep the control panel vertically compact so it behaves like a thin strip, not a full-height sheet.
8. Vertically align the route name field, Cancel, and Save with the adjacent icon buttons instead of top-aligning the text field inside the strip.
9. Preserve all existing stable keys, tooltip text, icons, semantics, and enable/disable logic for the route controls.
10. On narrow widths, keep the route name field at its intended width and let the control strip scroll horizontally as a unit while the graph panel remains anchored rather than compressing controls below their designed size.
11. Use a right inset of `88` so the control overlay clears the existing action rail, and apply the same outer padding to the graph overlay.
12. Do not introduce any new route state, mode, or persistence behavior.
13. Keep the existing route editor widget content intact inside the overlay surfaces, including the distance/elevation summary, loading and error states, ascent/descent metrics, chart, route name input, and action buttons.

**Error Handling:**
10. Existing button disablement for invalid route states must remain unchanged.
11. Validation or error text for the route name must not overlap the aligned controls or obscure the save/cancel actions.
12. If one panel has no visible content, the other panel still renders and the route draft remains interactive.
13. The graph overlay must preserve the current distance/elevation summary, loading state, ascent/descent metrics, and chart content that already exists in the route sheet.

**Edge Cases:**
14. Long route names and long validation messages must not break the split-panel alignment.
15. Layout must remain stable while the draft is routing, undoing/redoing, or saving.
16. Desktop and smaller window widths should both preserve the two-panel composition without clipping the sheet root.

**Validation:**
17. Add widget tests that assert the split-panel placement, shared padding, and bottom-left/bottom-right anchoring.
18. Add widget tests that assert the route name field and the Cancel/Save row share the same vertical alignment as the adjacent control buttons.
19. Add widget tests for a narrow viewport that prove the control strip stays compact and usable without shrinking the route name field.
20. Preserve and, if needed, extend the existing robot-driven route journey coverage using stable keys.
21. Maintain baseline automated coverage for UI behavior, route-state gating, and the critical route drafting journey; no new logic should be left untested if the refactor introduces any helper seams.
</requirements>

<boundaries>
Edge cases:
- Closed-loop and in-progress route states keep the same enable/disable behavior after the layout change.
- The route name field may grow an error message, but the controls must not shift off the aligned strip.
- Empty or minimal draft content should not collapse the sheet into a broken state.

Error scenarios:
- Layout overflow should degrade by scrolling or constraining the control strip, not by hiding or resizing essential controls below usability.
- Any rendering failure in the graph panel must not block the control panel from rendering.
- No keyboard, provider, or save-path regressions are allowed.

Limits:
- This is a UI refactor only.
- Do not change route planning, route persistence, export, or map interaction behavior.
- Do not rename existing keys unless a test update explicitly requires a new selector.
</boundaries>

<implementation>
Likely files to update:
- `./lib/screens/map_screen.dart`
- `./lib/widgets/map_route_bottom_sheet.dart`
- `./test/widget/map_screen_route_sheet_test.dart`
- `./test/robot/map/map_route_robot.dart`
- `./test/robot/map/map_route_journey_test.dart`
- Every other widget/robot/helper test or harness that still references `route-bottom-sheet`.

Use the existing route sheet widget tree and styling as the source of truth; prefer small private widget extraction over new shared abstractions unless the split-overlay shell becomes clearer that way.
Keep selector names stable and add only the minimum new keys needed to describe the new graph/control overlay roots.
Add explicit root keys for the graph overlay and control overlay so widget and robot tests can target each surface independently.
</implementation>

<stages>
Phase 1: Refactor the route sheet shell into two anchored panels and verify the existing controls still render.
Phase 2: Add widget tests for panel placement, alignment, and narrow-width behavior.
Phase 3: Extend robot coverage for the visible route-drafting journey using the same stable selectors.
Phase 4: Run the full route UI test slice plus any needed analyze checks and verify there is no behavior regression outside layout.
</stages>

<validation>
Use a behavior-first TDD sequence:
1. Write one failing widget test for the split-overlay layout before changing the widget tree.
2. Add one failing narrow-viewport widget test for the compact control strip.
3. Add one failing robot assertion for the end-to-end route journey if the new layout affects visible interaction.
4. Add one failing widget or robot test that proves both overlay roots appear together and disappear together on cancel, save, or dispose.
5. Implement the smallest layout change needed to satisfy the current failure, then re-run tests before adding the next case.

Expected coverage outcomes:
- Logic/business rules: existing route draft enablement and save gating continue to pass unchanged provider coverage.
- UI behavior: the sheet root, panel anchoring, shared padding, button alignment, and responsive strip behavior are covered by widget tests.
- Critical journey: opening route mode, using the visible controls, and saving or canceling still work through robot-driven coverage.

Required seams:
- Stable app-owned `Key` selectors for the graph overlay root and control overlay root.
- No private-method testing.
- Deterministic widget and robot setup using the existing route robot harness and provider overrides.
</validation>

<done_when>
The route editor opens as two visually distinct anchored panels with the graph bottom-left and the controls bottom-right, the route name and action row are vertically aligned with the rest of the route controls, narrow widths stay usable, and the existing route drafting journey still passes its automated tests.
</done_when>
