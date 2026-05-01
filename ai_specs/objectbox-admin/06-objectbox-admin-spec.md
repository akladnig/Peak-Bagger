<goal>
Build a read-only ObjectBox admin viewer that is reachable from the main menu via a database icon above Settings.
It should let maintainers inspect the local ObjectBox schema and browse rows for the current entities without exposing any mutation actions.
</goal>

<background>
Flutter app with Riverpod, GoRouter, and a global `Store` opened in `./lib/main.dart`.
The menu lives in `./lib/widgets/side_menu.dart`, shell routing is in `./lib/router.dart`, and the persisted entities are defined in `./lib/models/peak.dart`, `./lib/models/tasmap50k.dart`, and `./lib/models/gpx_track.dart`.
 The app already uses hardcoded shell branch indexes for Settings, so adding a new menu item must update those references consistently. With the admin branch inserted above Settings, the admin branch should become index `3` and Settings should move to index `4`.
Reject `objectbox_inspector` and implement a custom viewer instead.
Relevant files: `./pubspec.yaml`, `./lib/main.dart`, `./lib/router.dart`, `./lib/widgets/side_menu.dart`, `./lib/models/*.dart`.
</background>

<discovery>
- Confirm the smallest custom adapter over the ObjectBox `Store` needed to fake entity discovery, schema inspection, and row browsing in tests.
- Check every current Settings branch reference before inserting a new shell branch and update them together.
</discovery>

<user_flows>
Primary flow:
1. User taps the new database icon in the left menu above Settings.
2. The ObjectBox admin screen opens in the shell.
3. The user sees schema/data mode controls and an entity dropdown.
4. The user selects an entity.
5. The screen shows either schema metadata or row data in a scrollable grid.
6. The user searches and sorts rows in data mode.
7. The user returns to the app without any database mutation.

Alternative flows:
- Returning user: the admin branch should behave like the other shell branches and preserve its current state while the branch remains active.
- Empty database: the screen should still open and show an empty state instead of crashing.
- No search results: show a distinct no-matches state instead of an empty-looking table.
- Unsupported entity shape: the screen should degrade gracefully and keep browsing available.

Error flows:
- Store unavailable or admin initialization fails: show a clear error state and keep the app responsive.
- Entity query fails: keep the screen usable, show the failure inline, and do not mutate data.
- Navigation changes: if Settings shifts to a new branch index, update all hardcoded branch references together.
</user_flows>

<requirements>
**Functional:**
1. Add a new menu item in `./lib/widgets/side_menu.dart` using `FontAwesomeIcons.database`, placed directly above Settings.
2. Add a new shell branch and route in `./lib/router.dart` for the admin screen, and keep branch ordering consistent with the side menu.
3. Expose schema and data views for all ObjectBox entities currently persisted by the app.
4. Provide an entity dropdown at the top-left of the admin screen.
5. Show all schema fields in schema mode, and row data in data mode.
6. Keep the viewer read-only: no create, edit, delete, import, or schema-mutation actions.
7. Support data browsing features in the data view: default sort by the entity primary key, case-insensitive substring search, and pinned primary-name columns.
   - Search `Peak` by peak name.
   - Search `Tasmap50k` by map name.
   - Search `GpxTrack` by track name.
   - Match any row containing the substring anywhere in the name.
   - Do not add a separate filter UI for now.
   - Keep the primary-name column pinned on the left (`name` for `Peak` and `Tasmap50k`, `trackName` for `GpxTrack`) and keep the header row visible while scrolling.
   - Limit displayed cell content to 80 characters and wrap text in columns instead of clipping it.
   - Rows should auto-expand as text wraps.
   - Selecting a row opens a right-side details pane that shows the full field values.
   - The details pane follows the selected row, closes with an `X`, and resets when the browsing context changes.
    - Use a minimum column width of 160 px.
    - Show a circular progress indicator while the initial load or a search refresh is running.
    - For `GpxTrack` only, show an `Export GPX` button at the top-right of the search box.
    - The export button writes the currently selected row's `gpxFile` to `~/Downloads` by default.
    - If no row is selected, show the inline error message below the export button: `No gpxFile selected`.
8. Use the local ObjectBox store as the source of truth; do not add a network dependency.

**Schema contract:**
9. Schema mode must show every stored field for the selected entity, including the id field.
10. For `Peak`, show: `id`, `name`, `elevation`, `latitude`, `longitude`, `area`.
11. For `Tasmap50k`, show: `id`, `series`, `name`, `parentSeries`, `mgrs100kIds`, `eastingMin`, `eastingMax`, `northingMin`, `northingMax`, `mgrsMid`, `eastingMid`, `northingMid`, `tl`, `tr`, `bl`, `br`.
12. For `GpxTrack`, show: `gpxTrackId`, `contentHash`, `trackName`, `trackDate`, `gpxFile`, `displayTrackPointsByZoom`, `startDateTime`, `endDateTime`, `distance`, `ascent`, `totalTimeMillis`, `trackColour`.

**Error Handling:**
13. If the store or viewer initialization fails, show a clear error state and keep the rest of the app responsive.
14. If an entity has no rows, show an empty state instead of an exception.
15. If a field type cannot be rendered cleanly, show a fallback representation and keep browsing available.
16. If a search returns zero rows, show a distinct no-matches state instead of an empty-looking table.

**Edge Cases:**
17. Handle large entities with chunked eager loading of 50 rows at a time with scrollable row and column regions rather than pagination.
    Search should query the full entity set, then chunk the rendered result set.
    Use the same loading state and indicator pattern for initial loads and search refreshes.
18. Preserve state changes within the admin branch using the same shell behavior as the rest of the app.
19. Keep the screen usable on window resizing.

**Validation:**
21. Add deterministic tests for entity discovery, schema/data selection, and branch routing.
22. Add robot coverage for the journey from the side menu entry to schema/data browsing.
23. Add widget tests for empty-state, error-state, and selection behavior.
24. Add unit tests for the custom data-source adapter and query-mapping layer.
</requirements>

<boundaries>
Edge cases:
- Empty database: show a usable admin shell with no entity rows.
- No selectable entities: show an empty-state message and no crash.
- Unknown or unsupported field types: display a placeholder or omit only that field, never the whole entity.
- Very large entities: keep the grid scrollable in both directions, load rows in chunks of 50, and avoid pagination.
- Window resize: the table and left menu should remain legible and scroll as needed.

Error scenarios:
- ObjectBox store cannot open: display an error state and keep the app running.
- Route index drift: verify Settings and recovery actions still target the correct branch after inserting the admin branch.

Limits:
- Admin viewer is read-only only.
- No authenticated role system is required for this task.
</boundaries>

<implementation>
- Modify `./lib/widgets/side_menu.dart` to add the new database entry above Settings.
- Modify `./lib/router.dart` to add the new shell branch, wire the route, and update any hardcoded Settings branch references.
- Add `./lib/screens/objectbox_admin_screen.dart` for the viewer UI.
- Add `./lib/services/objectbox_admin_repository.dart` as the ObjectBox-backed read-only adapter seam.
- Do not add `objectbox_inspector`; build the viewer directly on top of the ObjectBox store and generated model metadata.
- Keep the UI aligned with the existing app style: compact menu items, simple tables, and explicit keys for test selectors.
- Avoid mutating ObjectBox records from this screen.
</implementation>

<stages>
Phase 1: Discovery and decision
- Verify the current entity set and the current Settings branch references.
- Complete when the implementation path is chosen and the affected files are known.

Phase 2: Screen and navigation
- Add the new menu item, branch, and screen scaffold.
- Complete when the screen opens from the menu and Settings still routes correctly.

Phase 3: Schema and data browsing
- Implement entity selection, schema display, and data table browsing with default primary-key sorting and entity-specific search.
- Complete when the entity browser works for `Peak`, `Tasmap50k`, and `GpxTrack`.

Phase 4: Test hardening
- Add unit, widget, and robot coverage for the supported journeys and failure states.
- Complete when the coverage proves the screen is read-only and reachable from the shell.
</stages>

<illustrations>
Desired:
- A user clicks the database icon and immediately sees the ObjectBox admin viewer.
- Selecting `GpxTrack` shows its schema fields, then its rows, without any edit controls.
- Searching and scrolling in a large entity never blocks the rest of the app.

Avoid:
- Any delete, edit, or create affordance in the viewer.
- A route that breaks existing Settings navigation after branch insertion.
- A package integration that cannot be kept read-only or cannot be tested deterministically.
</illustrations>

<validation>
TDD expectations:
- Build the feature in vertical slices: first entity discovery, then schema rendering, then data rendering, then search/sort, then route/menu wiring.
- Write one failing test at a time and implement only enough code to make it pass.
- Prefer a fake admin data source or repository seam over mocking ObjectBox internals.
- Keep all queries deterministic in tests; do not rely on a real store unless the test explicitly seeds one.

Automated coverage:
- Unit tests: entity discovery, schema mapping, entity-specific search/sort behavior, and fallback handling for unsupported fields.
- Widget tests: menu item presence, branch routing, empty/error states, no-matches state, entity dropdown selection, schema/data toggle, pinned-name columns, sticky headers, details-pane close/reset behavior, and Settings-index regression.
- Robot tests: the happy path from side menu entry to browsing entity data and switching back to Settings.
- Use stable, app-owned `Key` selectors for the admin menu item, schema/data toggle, entity dropdown, export button, export error, table, empty state, and error state.

Selectors to add:
- `Key('side-menu-objectbox-admin')`
- `Key('objectbox-admin-schema')`
- `Key('objectbox-admin-data')`
- `Key('objectbox-admin-entity-dropdown')`
- `Key('objectbox-admin-export-gpx')`
- `Key('objectbox-admin-export-error')`
- `Key('objectbox-admin-table')`
- `Key('objectbox-admin-empty-state')`
- `Key('objectbox-admin-error-state')`

Success criteria:
- The admin viewer opens from the menu.
- The viewer is read-only.
- Schema and data browsing work for all current ObjectBox entities.
- Sorting, entity-specific search, pinned-name columns, sticky headers, and the GpxTrack-only export affordance are covered by tests.
- Existing Settings navigation still works after the new branch is added, with all settings branch references updated to the new index.
</validation>

<done_when>
- The side menu shows a database icon above Settings.
- The new admin route opens a read-only ObjectBox viewer.
- Entity dropdown, schema view, and data view all work for current entities.
- Search and sorting behave as specified, with no pagination, pinned name columns, sticky headers, a details pane for full cell values, and the GpxTrack export button with its no-selection error.
- All automated tests pass, including the journey coverage and the Settings-branch regression coverage.
</done_when>
