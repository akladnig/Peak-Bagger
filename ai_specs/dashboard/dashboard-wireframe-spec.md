<goal>
Build the dashboard overview screen that gives users an immediately useful area with six configurable placeholder cards. The screen should feel like part of the existing app shell, let users reorder cards with mouse or trackpad drag-and-drop, and remember that order locally so the dashboard returns in the same state on later visits.
</goal>

<background>
- Flutter app using Riverpod, go_router, and the existing Material theme.
- The dashboard route is `/` and `./lib/screens/dashboard_screen.dart` currently renders only an empty scaffold.
- Shared preferences is already the app's lightweight settings store, so use it for dashboard layout persistence instead of adding a heavier datastore.
- Relevant files to examine: `@lib/screens/dashboard_screen.dart`, `@lib/router.dart`, `@lib/theme.dart`, `@lib/providers/theme_provider.dart`, `@test/widget/objectbox_admin_shell_test.dart`, `@test/robot/settings/tile_cache_robot.dart`.
</background>

<user_flows>
Primary flow:
1. User opens the dashboard from the home button or by navigating directly to `/`.
2. Six placeholder cards render in the default order.
3. User drags a card with mouse or trackpad to a new slot.
4. The board reflows immediately and the new order is saved locally.
5. User returns later and sees the same order restored.

Alternative flows:
- First-time user: dashboard uses the built-in default order because no saved layout exists.
- Returning user: dashboard loads the last saved order from shared preferences before the board is shown or as early as practical without blocking the screen.
- Small viewport: the layout adapts column count first, then becomes scrollable if needed to keep cards usable.

Error flows:
- Missing or malformed saved order: ignore the bad value and fall back to the default order.
- Persistence failure: keep the current on-screen order, do not block interaction, and continue with the default in-memory state if saving cannot complete.
</user_flows>

<requirements>
**Functional:**
1. Render exactly six placeholder cards titled `Elevation`, `Distance`, `Latest Walk`, `Peaks Bagged`, `Top 5 Highest`, and `Top 5 Walks`.
2. Use one reusable card chrome with a header row, `primaryContainer` header background, and shadow.
3. Use a 3-column layout at widths `>= 1200px` with cards at a `4:3` aspect ratio, a 2-column layout from `800px` to `1199px`, and a 1-column layout below `800px`.
4. Allow vertical scrolling when the viewport is too short to keep the `4:3` desktop cards visible.
5. Allow mouse/trackpad drag reordering of the cards.
6. Reposition the remaining cards automatically when one card moves.
7. Persist the card order locally in shared preferences and restore it on next launch.
8. Use a deterministic default order when no saved order exists.
9. Use stable card ids separate from display titles: `elevation`, `distance`, `latest-walk`, `peaks-bagged`, `top-5-highest`, `top-5-walks`.

**Error Handling:**
10. Sanitize stored order data by filtering unknown ids and appending missing default cards in default order.
11. If persistence read/write fails, the dashboard must still render and allow reordering.

**Edge Cases:**
12. Dragging a card back onto its original position must leave the order unchanged.
13. Rebuilding or resizing the screen must not duplicate cards or lose the current order.
14. The feature must remain isolated to the dashboard screen and must not change route behavior elsewhere.

**Validation:**
15. Add stable `Key` values for the board, each card root, and each drag handle so tests can target them without pixel brittleness.
16. Expose the layout state behind an injectable seam so tests can supply fake or in-memory shared preferences.
</requirements>

<boundaries>
- Placeholder content only; do not wire real dashboard metrics into this change.
- Mouse/trackpad reordering is in scope; touch drag support is out of scope unless later requested.
- Keep persistence local to the device; no sync, server storage, or ObjectBox schema changes.
- Do not add a new third-party drag/reorder package unless the built-in Flutter approach is clearly insufficient.
- Avoid hard-coded pixel sizes that only work on one desktop resolution.
- Keep the dashboard independent from map, peaks, settings, and objectbox admin state.
</boundaries>

<implementation>
- Modify `./lib/screens/dashboard_screen.dart` to render the board instead of an empty scaffold.
- Add `./lib/providers/dashboard_layout_provider.dart` to own the ordered card ids and shared-preferences persistence.
- Prefer a single source of truth for card ids and titles so the UI, persistence, and tests all agree.
- Use `shared_preferences` string-list storage for the order value under a single dashboard layout key such as `dashboard_card_order`.
- Add keys like `dashboard-card-elevation` and a matching drag-surface key for each card.
- Implement the reorder interaction as a custom Flutter drag grid using draggable header rows and drop targets; do not introduce a third-party reorder package for this feature.
- Keep the card template small and local unless a separate widget file is needed for testability.
- Add tests under `./test/providers/`, `./test/widget/`, and `./test/robot/dashboard/`.
- Follow the existing Riverpod and shell patterns already used elsewhere in the app.
</implementation>

<stages>
1. Layout state and persistence: implement the ordered card list, default fallback, save/load behavior, and provider tests.
2. Dashboard board UI: replace the empty screen with the responsive card grid, drag-reorder behavior, and widget tests for layout and reordering.
3. Journey coverage: add a robot test that drags a card, verifies the new order, restarts the harness, and confirms persistence.
</stages>

<validation>
- Build behavior first in small slices: default order load, persistence save/load, sanitize invalid data, then drag reorder.
- Keep each slice test-driven: one failing test, minimal implementation, then refactor after green.
- Unit/provider tests must cover default initialization, successful save/load, invalid stored data recovery, and repeated updates.
- Widget tests must cover card rendering, responsive layout on a narrow width, and reorder behavior without relying on fixed pixels.
- Robot tests must cover the primary dashboard journey: open dashboard, drag one card to a new position, and confirm the order persists after a rebuild/relaunch.
- Use stable keys as the main selector contract in robot tests; do not rely on text matching alone for drag targets.
- Use deterministic seams for shared preferences so tests do not depend on real device storage.
- Verify the desktop layout contract at the three required width bands: `>= 1200px`, `800px` to `1199px`, and `< 800px`.
- Verify the desktop card shape stays at `4:3` in the wide layout and that short viewports scroll vertically instead of clipping cards.
- Baseline automated coverage must include business/state logic, UI behavior, and the critical reorder journey.
</validation>

<done_when>
- The dashboard route shows six placeholder cards with the required titles.
- Card order can be changed by mouse or trackpad drag-and-drop.
- The new order is restored from local storage after restart.
- Invalid persisted layouts fail safely back to the default order.
- The responsive layout keeps all cards accessible on smaller windows.
- Required unit, widget, and robot tests are in place and passing.
</done_when>
