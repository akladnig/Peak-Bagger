<goal>
Add one shared shell `AppBar` so every top-level route renders under the same header instead of mixing route-local app bars, left-rail branding, and shell overlay controls.
This matters because top-level navigation and shell chrome are currently split across multiple places. A single header should make the active destination obvious, keep the layout consistent, and prepare the shell for narrow-width navigation.
</goal>

<background>
Project is a Flutter app using Material, Riverpod, and GoRouter.

Current state:
- `./lib/router.dart` owns the top-level shell and currently renders a permanent left-side menu plus a floating theme button overlay.
- `./lib/widgets/side_menu.dart` currently renders the mountain icon at the top of the left rail.
- `./lib/screens/settings_screen.dart` and `./lib/screens/objectbox_admin_screen.dart` still define local top-level `AppBar`s.
- Other top-level screens rely on shell layout only, so the app has no single consistent shared header.

Files to examine:
- `./pubspec.yaml`
- `./lib/app.dart`
- `./lib/router.dart`
- `./lib/theme.dart`
- `./lib/widgets/side_menu.dart`
- `./lib/screens/dashboard_screen.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- `./lib/screens/settings_screen.dart`
- `./test/widget/objectbox_admin_shell_test.dart`
- `./test/widget/gpx_tracks_shell_test.dart`
- `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart`

Constraints:
- Keep the change shell-focused and minimal.
- Preserve existing route behavior, provider wiring, snackbars, floating action buttons, and map interactions.
- Follow existing Material and test patterns already used in the repo.
</background>

<discovery>
Before coding, confirm the smallest shell seam that can own:
- a shared `AppBar`
- one explicit fixed route-to-title mapping for the active top-level destination
- responsive shell navigation behavior for wide vs compact layouts

Verify that the router's existing branch index and route paths can drive one shared destination definition without adding duplicate navigation definitions.
</discovery>

<user_flows>
Primary flow:
1. User opens the app on any top-level route.
2. User sees one shared `AppBar` spanning the shell width.
3. On wide layouts, the `AppBar` shows the mountain home icon in the leading slot, the active page title beside it, and the theme toggle on the right.
4. On wide layouts, the navigation rail starts below the `AppBar` and shows labeled destinations with icon and text, with the text centered under the icon.
5. User changes routes and the shared `AppBar` stays in place while the title updates.

Alternative flows:
- Home shortcut: user taps the mountain icon and returns to Dashboard.
- Theme toggle: user toggles theme from the `AppBar` without losing route state.
- Compact layout: user opens a narrow-width layout, uses the `AppBar` menu button to open compact navigation, sees labeled destinations rendered as `ListTile`-style rows with icon and text, sees the mountain home icon at the start of the title row, and reaches the same top-level routes.
- Deep link: user lands directly on Map, Peak Lists, ObjectBox Admin, or Settings and still sees the correct shared header title.

Error flows:
- Drawer open during route change: navigation completes and the drawer no longer obstructs content.
- Theme toggle during compact navigation: theme changes without breaking the current route or hiding the title.
</user_flows>

<requirements>
**Functional:**
1. Add a shared shell-level `AppBar` in `./lib/router.dart` or a directly related shell widget used by the router.
2. Use the shared `AppBar` for every top-level route: Dashboard, Map, Peak Lists, ObjectBox Admin, and Settings.
3. Render the `AppBar` across the shell width above both navigation and route content.
4. On wide layouts, move the mountain app icon from the left rail into the `AppBar` leading area.
5. On wide layouts, replace the current icon-only navigation rail with labeled destinations that show icon and text, with the text centered under the icon.
6. On compact layouts, use `AppBar.leading` for the navigation menu trigger and place the mountain home action at the start of the title row before the title text.
7. On compact layouts, render navigation inside a drawer using labeled `ListTile`-style destinations with icon and text.
8. Make the mountain icon an explicit home action that navigates to Dashboard.
9. Use one explicit shared destination model for the current top-level routes only, with each destination defining its branch index as the primary shell identity, route path as supporting deep-link data, navigation label, `AppBar` title, icon, and stable key.
10. Define the current top-level destinations in that shared model as:
   - branch `0`, route `/`, navigation label `Dashboard`, `AppBar` title `Dashboard`, and stable key `nav-dashboard`
   - branch `1`, route `/map`, navigation label `Map`, `AppBar` title `Map`, and stable key `nav-map`
   - branch `2`, route `/peaks`, navigation label `Peak Lists`, `AppBar` title `Peak Lists`, and stable key `nav-peak-lists`
   - branch `3`, route `/objectbox-admin`, navigation label `ObjectBox Admin`, `AppBar` title `ObjectBox Admin`, and stable key `nav-objectbox-admin`
   - branch `4`, route `/settings`, navigation label `Settings`, `AppBar` title `Settings`, and stable key `nav-settings`
11. Use the destination model as the single source of truth for both navigation labels and `AppBar` titles unless a future spec explicitly splits them.
12. Do not derive display titles or navigation labels from route names as part of this feature.
13. Show the active route title beside the icon with clear spacing.
14. Display titles in title case for the user-visible label.
15. Both wide and compact navigation must show a clear selected state for the current top-level destination.
16. Tapping the already-selected top-level destination is a no-op in both wide and compact navigation.
17. If the already-selected destination is tapped from the compact drawer, close the drawer without re-running cleanup or branch navigation.
18. On compact layouts, keep the menu trigger and theme action visible at all times, give the title area flexible width, and truncate long titles with ellipsis rather than allowing overflow.
19. On wide layouts, widen the navigation surface as needed for the defined destination labels and wrap each destination label to two lines before truncating it.
20. Move the existing theme toggle into the `AppBar` actions area.
21. Remove the floating theme button overlay from the shell.
22. Preserve the current theme toggle runtime behavior: tapping the `AppBar` action switches only between `ThemeMode.dark` and `ThemeMode.light`, and if the current state is `ThemeMode.system`, the first toggle sets `ThemeMode.dark`.
23. Preserve the current theme icon semantics: show `Icons.light_mode` only when the stored theme mode is `ThemeMode.dark`; otherwise show `Icons.dark_mode`.
24. Pressing the mountain icon while already on Dashboard is a no-op.
25. Remove top-level `AppBar` usage from `./lib/screens/settings_screen.dart` and `./lib/screens/objectbox_admin_screen.dart` so the shell owns the top-level header.
26. Remove the in-body title text from `./lib/screens/dashboard_screen.dart` and `./lib/screens/peak_lists_screen.dart` so the shared shell title is the visible page heading.
27. Treat the empty body on Dashboard after that title removal as intentional for this feature.
28. Treat the Peak Lists screen as intentionally showing only the existing FAB plus the shared shell title until future feature work adds page content.
29. Preserve each route's existing body content, scrolling, dialogs, snackbars, floating action buttons, and internal controls after the shell layout change.
30. Use `LayoutBuilder` in the shell and treat widths `>= 720` logical pixels as wide layouts and widths `< 720` logical pixels as compact layouts.
31. Both wide and compact navigation must present destinations in the same order as the shared destination model: Dashboard, Map, Peak Lists, ObjectBox Admin, Settings.

**Error Handling:**
32. If a compact navigation surface is open when navigation occurs, the selected route must resolve and the navigation surface must no longer obstruct the content.
33. All shell-owned top-level navigation actions, including wide navigation destinations, compact drawer destinations, and the AppBar home action, must invoke the same pre-navigation cleanup currently used before side-menu branch changes, and must do so exactly once per navigation action.

**Edge Cases:**
34. Support deep linking or direct router navigation to any top-level branch while still showing the correct title from the shared destination model.
35. On narrow layouts, replace the persistent left rail with a drawer or equivalent shell-owned compact navigation container.
36. On wide layouts, keep the navigation rail permanently visible below the `AppBar`.
37. The top edge of the wide-layout rail must align to the bottom of the `AppBar`, not the top of the screen.
38. The `AppBar` must coexist with route-level floating action buttons, end drawers, and shell messages without making core controls inaccessible.
39. The `AppBar` should retain visible separation from the content below in both light and dark themes.
40. After closing compact navigation, after using a shell `AppBar` action, or after returning to the Map route, keyboard shortcuts must still work without an extra click unless an in-map text input is intentionally focused.

**Validation:**
41. Add stable keys for new shell controls that require automated verification.
42. At minimum, provide stable keys for the shared `AppBar`, home action, title widget, theme action, compact navigation trigger, and every top-level destination.
43. Attach each shared destination key to the interactive control used to select that destination in both wide and compact navigation.
44. Use this shared app-owned key contract for top-level destinations across both wide and compact navigation surfaces: `nav-dashboard`, `nav-map`, `nav-peak-lists`, `nav-objectbox-admin`, and `nav-settings`.
45. Keep the title source in the shared destination model rather than in a separate derived mapping.
46. Add automated coverage that verifies the selected-state behavior for the active destination in both wide and compact navigation layouts.
47. Add automated coverage that verifies wide and compact navigation render destinations in the shared destination model order.
48. Do not leave duplicate dedicated shell actions for theme switching, and do not add extra dedicated home actions beyond the intentional mountain icon and the Dashboard destination in the shared navigation model.
</requirements>

<boundaries>
Layout boundaries:
- Do not redesign route-specific page content beyond removing redundant top-level headings or app bars made obsolete by the shared shell header.
- Keep the side navigation widget focused on navigation items rather than branding or header content, but allow the navigation presentation itself to change from icon-only to labeled destinations in both wide and compact layouts.
- Do not move route-specific actions into the shared `AppBar` unless they are already global shell actions.

Technical boundaries:
- Do not add new packages for responsive layout or shell chrome unless an existing dependency already requires it.
- Do not duplicate navigation definitions just to support wide and compact layouts if the same destination model can drive both.
- Do not broadly refactor unrelated route internals.

Failure boundaries:
- Repeated theme toggles must remain safe and idempotent.
- Compact navigation must not trap focus or remain stuck open after route changes.
- Compact navigation and header interactions must not leave the Map screen without working keyboard shortcuts once focus should have returned to the map region.
</boundaries>

<implementation>
Modify only the files needed for the shell/header change, likely including:
- `./lib/router.dart`
- `./lib/widgets/side_menu.dart`
- `./lib/theme.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- affected tests under `./test/widget/`
- affected robot journeys under `./test/robot/`

Implementation expectations:
- Keep shared header ownership at the shell layer so route screens do not manage global header concerns.
- Resolve the visible title from the active top-level route or branch index using the shared destination model in one obvious place.
- Use the shared destination model as the single source of truth for branch index, route path, navigation label, `AppBar` title, icon, and stable key.
- Do not add fallback title generation or route-name-to-title transformation for this feature.
- Use `LayoutBuilder` at the shell layer with a `720` logical pixel breakpoint for wide vs compact behavior.
- On wide layouts, use the mountain icon as the `AppBar` leading action.
- On compact layouts, use the menu trigger as `AppBar.leading` and render the mountain home action at the start of the title row.
- Update the shared navigation presentation so both wide and compact layouts use labeled destinations rather than the current icon-only rail.
- Use one shared destination model that carries branch index, route path, navigation label, `AppBar` title, icon, and stable key for each top-level destination.
- Keep navigation labels aligned with the fixed destination titles unless a future spec explicitly requires them to differ.
- Icon choice may change as long as destination identity, order, and labels remain stable.
- Ensure the active destination is visibly selected in both wide and compact layouts, and treat taps on the active destination as no-ops.
- If the active destination is tapped from the compact drawer, close the drawer without retriggering navigation or cleanup.
- Widen the wide-layout navigation surface as needed for the defined labels, and allow labels to wrap to two lines.
- On compact layouts, make long titles truncate with ellipsis before they can push shell actions off-screen.
- Reuse the same destination definitions for wide and compact navigation where practical, and present them in the same shared-model order.
- Keep `side-menu-objectbox-admin` as a temporary migration alias if needed while `nav-objectbox-admin` becomes the long-term selector contract.
- Update theme styling in `./lib/theme.dart` only as needed so the `AppBar` elevation, shadow, and colors remain coherent in both themes.
- Preserve the current two-state `themeModeProvider` toggle behavior and current icon semantics unless this spec is explicitly changed later.
- Reuse the same pre-navigation cleanup path for every shell-owned branch-switching action.

Avoid:
- Duplicating title logic inside individual screens.
- Reintroducing per-screen top-level `AppBar`s for shell-managed destinations.
- Leaving the branding icon in the rail after moving it into the shared header.
- Replacing existing wide-layout navigation test selectors unless a selector change is required for correctness.
- Broad refactors outside the shell/navigation/header scope.
</implementation>

<stages>
Phase 1: Shared header
- Introduce the shared shell `AppBar`.
- Add the shared destination model with explicit branch index, route path, label, title, icon, and key definitions in Dashboard, Map, Peak Lists, ObjectBox Admin, Settings order.
- Move the home icon and theme action into the `AppBar`.

Phase 2: Responsive shell navigation
- Update wide-layout composition so the rail begins below the `AppBar` and shows labeled destinations.
- Add compact navigation behavior for widths below `720` using `LayoutBuilder`.
- Verify existing route cleanup hooks still run correctly.

Phase 3: Screen cleanup and styling
- Remove redundant route-level `AppBar`s and remove the in-body titles from Dashboard and Peak Lists.
- Finalize `AppBar` spacing, elevation, and theme coherence.

Phase 4: Automated coverage
- Add or update unit, widget, and robot tests for the shared header behavior.
- Cover both wide and compact shell behavior where practical.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic: unit tests for the shared destination model's explicit branch/route/title/label/key definitions, including a guard against reintroducing route-name-derived display text.
- UI behavior: widget tests for shared `AppBar` rendering, title updates across route changes, theme action placement, removal of duplicate local app bars and in-body titles, wide-layout rail positioning, compact navigation trigger behavior at widths above and below `720`, destination order rendering, selected-state rendering, wide-label wrapping behavior, and compact-title truncation behavior.
- Critical journeys: robot coverage for shared-shell navigation, title changes, and home navigation back to Dashboard.

TDD expectations:
- Implement one failing test at a time.
- Start with the highest-value visible behavior: shared `AppBar` presence with the correct title on an existing top-level route.
- Continue in this order: home icon navigation, theme action relocation, wide-layout rail positioning, compact navigation behavior, selected-state behavior, compact active-destination no-op behavior, wide-label wrapping, compact-title truncation, map focus preservation, and removal of redundant local app bars and in-body titles.
- Test public behavior, not private router composition details.
- Keep the title source test-friendly so a future localisation-backed mapping can replace the fixed strings without changing shell behavior.

Robot expectations:
- Reuse the existing `./test/robot/` structure.
- Use app-owned key selectors for the shared `AppBar`, title, home action, theme action, and compact navigation trigger.
- Keep provider overrides, router state, and async pumping deterministic.
- Use the shared destination keys for route selection in both wide and compact navigation tests.
- Existing wide-layout selectors such as `side-menu-objectbox-admin` may be retained temporarily as migration aliases if needed, but `nav-dashboard`, `nav-map`, `nav-peak-lists`, `nav-objectbox-admin`, and `nav-settings` become the long-term selector contract.
- Migrate existing icon-based shell navigation tests to the shared destination keys. No icon-selector compatibility is required beyond that migration.

Minimum behavior checks:
- Dashboard shows the shared `AppBar` and `Dashboard`.
- Map shows the shared `AppBar` and `Map`.
- Peak Lists shows the shared `AppBar` and `Peak Lists`.
- ObjectBox Admin shows the shared `AppBar` and `ObjectBox Admin`.
- Settings shows the shared `AppBar` and `Settings`.
- Wide navigation shows labeled destinations with centered text under each icon.
- Compact navigation shows labeled `ListTile`-style destinations in a drawer.
- Wide and compact navigation use the same destination labels as the shared destination model.
- Wide and compact navigation expose the shared destination keys `nav-dashboard`, `nav-map`, `nav-peak-lists`, `nav-objectbox-admin`, and `nav-settings`.
- Wide and compact navigation present destinations in the shared destination model order: Dashboard, Map, Peak Lists, ObjectBox Admin, Settings.
- The active destination is visibly selected in both wide and compact navigation.
- Tapping the already-selected destination is a no-op in both wide and compact navigation.
- Tapping the already-selected destination from the compact drawer closes the drawer without retriggering navigation or cleanup.
- Wide navigation widens as needed and wraps destination labels to two lines.
- Pressing the mountain icon navigates to Dashboard.
- Pressing the mountain icon while already on Dashboard is a no-op.
- Pressing the theme action toggles theme mode from the `AppBar` using the current two-state runtime behavior and current icon semantics.
- Settings and ObjectBox Admin no longer render their old top-level `AppBar(title: ...)` headers.
- Dashboard and Peak Lists no longer render their in-body title text.
- Dashboard is intentionally empty after the in-body title is removed.
- Peak Lists intentionally shows only the existing FAB plus the shared shell title until future page content is added.
- The shared destination model remains the single explicit source of destination titles and labels rather than generating them from route names.
- After closing compact navigation, after shell `AppBar` interactions, or after returning to Map, the existing map keyboard shortcuts still respond without an extra click unless an in-map text field is focused.
- On compact layouts, long titles truncate with ellipsis before shell actions overflow or disappear.
- Existing shell snackbars and route-level floating actions remain usable after the layout change.

Known risk to report if unresolved:
- If compact navigation cannot be fully exercised in the current robot harness, call out that gap explicitly and keep widget coverage for the compact branch strong.
</validation>

<done_when>
- A single shared `AppBar` is visible across all top-level routes.
- The `AppBar` spans the shell width and visually separates the header from content below.
- The mountain icon appears in the `AppBar`, no longer appears in the side rail, and navigates to Dashboard.
- The active route title appears beside the icon and is title-cased for display.
- The theme toggle appears in the `AppBar` actions, preserves the current two-state toggle behavior and current icon semantics, and the old floating theme overlay is removed.
- Wide layouts at widths `>= 720` show the navigation rail below the `AppBar`.
- Narrow layouts at widths `< 720` use a compact drawer or equivalent shell-owned navigation pattern.
- Both wide and compact navigation use labeled destinations backed by one shared destination model and one shared destination key contract.
- Both wide and compact navigation present destinations in Dashboard, Map, Peak Lists, ObjectBox Admin, Settings order.
- Both wide and compact navigation show a clear selected state for the active destination, and selecting the active destination is a no-op.
- Wide navigation is wide enough for the defined labels and wraps labels to two lines.
- Settings and ObjectBox Admin rely on the shared shell `AppBar` rather than local top-level app bars.
- Dashboard and Peak Lists no longer show their in-body title text.
- Dashboard remains intentionally empty after the in-body title is removed.
- Peak Lists remains intentionally limited to the existing FAB plus the shared shell title.
- Existing route content and interactions still work after the shell change.
- Existing map keyboard interactions still work after shell navigation, shell `AppBar` interactions, and compact drawer interactions.
- Compact `AppBar` titles truncate safely without hiding the menu trigger or theme action.
- Automated coverage is updated for shell logic, shell UI behavior, and critical shared-header journeys.
</done_when>
