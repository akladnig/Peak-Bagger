<goal>
Refactor `./lib/screens/objectbox_admin_screen.dart` into smaller, screen-scoped files so the ObjectBox Admin screen is easier to navigate, review, and extend without changing how `/objectbox-admin` behaves for users.

This cleanup matters because the current screen mixes route-entry refresh handling, controller ownership, snackbar side effects, and several already-cohesive private widgets inside one 840-line file. The outcome should preserve the current admin browser exactly while leaving the root screen as a clear coordinator for lifecycle, provider orchestration, and controller state.
</goal>

<background>
Tech stack: Flutter, Riverpod, GoRouter, ObjectBox, and existing widget/robot/service tests.

Project constraints:
- Preserve the `/objectbox-admin` route entry in `./lib/router.dart`.
- Preserve current user-visible copy, current stable widget keys/selectors, and current route-entry refresh behavior.
- Preserve current provider and repository contracts in `./lib/providers/objectbox_admin_provider.dart` and `./lib/services/objectbox_admin_repository.dart`.
- Keep the refactor low-risk and mechanical; do not turn this into a redesign of provider state, repository logic, schema formatting, or ObjectBox model handling.
- Do not add packages.
- Do not introduce `part` / `part of`; use explicit imports and explicit parameters.

Files to examine:
- @pubspec.yaml
- @lib/router.dart
- @lib/screens/objectbox_admin_screen.dart
- @lib/providers/objectbox_admin_provider.dart
- @lib/services/objectbox_admin_repository.dart
- @test/widget/objectbox_admin_shell_test.dart
- @test/widget/objectbox_admin_browser_test.dart
- @test/robot/objectbox_admin/objectbox_admin_journey_test.dart
- @test/robot/objectbox_admin/objectbox_admin_robot.dart
- @test/services/objectbox_admin_repository_test.dart
- @test/harness/test_objectbox_admin_repository.dart

Output paths:
- Keep `./lib/screens/objectbox_admin_screen.dart` as the stable route-facing screen and coordinator.
- Create `./lib/screens/objectbox_admin_screen_controls.dart` for a non-private exported controls widget such as `ObjectBoxAdminControls` and closely related control-surface UI only.
- Create `./lib/screens/objectbox_admin_screen_states.dart` for non-private exported schema and shared screen-state presentation widgets such as `ObjectBoxAdminSchemaView`, `ObjectBoxAdminSchemaHeader`, `ObjectBoxAdminLoadingState`, `ObjectBoxAdminErrorState`, and `ObjectBoxAdminEmptyState` if those remain purely presentation widgets.
- Create `./lib/screens/objectbox_admin_screen_table.dart` for non-private exported table widgets such as `ObjectBoxAdminDataGrid`, `ObjectBoxAdminDataHeaderRow`, `ObjectBoxAdminDataRowTile`, and `ObjectBoxAdminCell`.
- Create `./lib/screens/objectbox_admin_screen_details.dart` for a non-private exported details widget such as `ObjectBoxAdminDetailsPane`.
- Create `./lib/screens/objectbox_admin_screen_helpers.dart` only if extracting a pure, screen-local helper materially reduces the root file without moving controller ownership, provider access, router listening, or widget state out of `objectbox_admin_screen.dart`.
</background>

<user_flows>
These are regression flows to preserve, not new behavior to invent.

Primary flow:
1. User opens ObjectBox Admin from the side menu.
2. The screen loads the selected entity in data mode, shows the current control bar, current data table, and current details pane.
3. User selects a row and sees the same full-value details in the side pane.

Alternative flows:
- Schema flow: user switches from Data to Schema and sees the same entity schema list with the same field metadata rows.
- Search flow: user types a search query, submits it, and gets the same filtered rows or the same `No matches` empty state.
- Sort flow: user taps the primary-name header and gets the same ascending/descending sort behavior with the same arrow indicator.
- Pagination flow: user scrolls a long row list and more rows become visible in the same 50-row chunk pattern.
- Export flow: user views `GpxTrack` rows, sees the same `Export GPX` button behavior, the same inline `No gpxFile selected` error text when no row is selected, and the same success/failure snackbar behavior after export.
- Re-entry flow: user leaves `/objectbox-admin` and returns later; the screen refreshes entities and rows again on visible re-entry exactly as it does today.

Error flows:
- Repository load failure: the same error card appears with the same `Failed to load ...` message shape.
- No entities or no selection: the same empty-state cards appear with the same titles/messages.
- No rows or no matches: the same empty-state cards appear with the same titles/messages.
- Export failure: the same snackbar appears with `Export failed: ...` copy.
</user_flows>

<discovery>
Before implementation, confirm:
- The current split candidates remain the same as the cleanup finding: controls, schema widgets, data-grid widgets, and details pane.
- Existing tests already cover shell opening, route re-entry refresh, filtering/no-match behavior, row chunking, fixed-first-column behavior, details rendering, schema rendering, and GPX export visibility.
- Current robot coverage is intentionally narrow: it protects the menu-open shell path and stable shell selectors, not the deeper browser behaviors.
- All stable `objectbox-admin-*` selectors used by widget and robot tests are catalogued before extraction starts.
- Any helper extracted beyond the trapped widgets is truly screen-local and mechanical, not a new abstraction layer.
- Provider and repository already own business logic, filtering, sorting, repository-load errors, and export operations, so this cleanup does not need model, provider, or service redesign.
- There is currently no dedicated provider test surface for `ObjectBoxAdminNotifier`; provider behavior is protected indirectly through widget tests and repository/service tests, so add a focused regression only if extraction would otherwise weaken coverage on a behavior-sensitive seam.
</discovery>

<requirements>
**Functional:**
1. Reduce `./lib/screens/objectbox_admin_screen.dart` to a coordinator that owns route-entry lifecycle, controller ownership, provider reads, snackbar side effects, and composition of extracted admin-screen widgets.
2. Keep the public `ObjectBoxAdminScreen` type, constructor, and route wiring in `./lib/router.dart` unchanged.
3. Extract the current controls widget into `./lib/screens/objectbox_admin_screen_controls.dart` using a non-private exported top-level name such as `ObjectBoxAdminControls`, without changing its visible controls, layout behavior, or callback contract.
4. Extract schema-related presentation widgets into `./lib/screens/objectbox_admin_screen_states.dart` using non-private exported top-level names, without changing schema titles, field rows, or empty/loading/error card copy.
5. Extract the table/grid widgets into `./lib/screens/objectbox_admin_screen_table.dart` using non-private exported top-level names, without changing fixed-first-column behavior, vertical header positioning, row selection rendering, chunked loading row, or the current stable keys.
6. Extract the current details-pane widget into `./lib/screens/objectbox_admin_screen_details.dart` using a non-private exported top-level name such as `ObjectBoxAdminDetailsPane`, without changing close-button behavior, detail-title formatting, details-list rendering, or `SelectableText` usage for values.
7. Preserve current control-bar behavior exactly: entity dropdown, schema/data toggle, search field, search icon button, export button visibility rules, and inline export error text for `GpxTrack`.
8. Preserve current body-state branching exactly: no selectable entities, load error, loading spinner, no selected entity, schema mode, no matches, no rows, and data-table-plus-details layout.
9. Preserve route-visible re-entry refresh behavior exactly: refresh when `/objectbox-admin` becomes visible after a path change, do not trigger duplicate refreshes while that route remains visible and unchanged, and do not introduce extra refreshes caused only by ordinary rebuilds.
10. Preserve the current `App()`- and router-driven test entry patterns by keeping extracted widgets compatible with the existing route navigation flow and current provider overrides.

**Error Handling:**
11. Preserve current repository-load failure behavior from `objectboxAdminProvider`, including the current `Failed to load <entity>: <error>` message shape and current empty/error state transitions.
12. Preserve current GPX export success and failure snackbar behavior, including success text starting with `Exported to` and failure text starting with `Export failed:`.
13. Preserve current empty/no-match/no-selection messages exactly, since widget tests and finder-based expectations depend on those visible states.
14. If helper extraction introduces new parameters or helper functions, surface failures through the same existing screen/provider/repository paths rather than swallowing exceptions or inventing new fallback UI.

**Edge Cases:**
15. Preserve current row-chunk behavior where `visibleRowCount` increases by 50 and the loading indicator row appears only when more rows remain.
16. Preserve current horizontal-scroll coordination owned by the root screen, including `_headerHorizontalController`, `_rowHorizontalControllers`, and `_horizontalOffset` synchronization.
17. Preserve current selection clearing behavior when entity, mode, sort order, or loaded rows change.
18. Preserve current behavior when `state.selectedRow` is null, including the disabled details close button and visible `No gpxFile selected` export warning for `GpxTrack`.
19. Preserve current behavior when the entity list becomes empty or the previously selected entity no longer exists on refresh.
20. Keep visible-entry refresh orchestration, load-more triggering, horizontal-scroll coordination, and export/snackbar side effects in `objectbox_admin_screen.dart`; optional helper extraction is limited to truly pure screen-local utilities that do not read `ref`, listen to the router, mutate screen-owned controllers, or show snackbars.
21. Avoid over-fragmentation: do not create files smaller than the listed responsibilities unless a pure helper extraction clearly removes repeated coordination code from the root screen.

**Validation:**
22. Treat this as a behavior-preserving mechanical refactor first; any new tests should lock existing behavior, not justify a redesign.
23. Keep or improve automated coverage across repository logic, screen/widget behavior, and critical admin journeys.
24. Do not update test expectations to fit a new internal structure; if a test fails, prefer restoring the previous user-visible behavior unless the spec explicitly allows the change, which it does not.
</requirements>

<boundaries>
Edge cases:
- Extracted screen files may contain top-level widgets and pure helpers, but controller creation, controller disposal, provider reads/writes, router listening, snackbar side effects, and route-refresh logic remain owned by `objectbox_admin_screen.dart`.
- `objectbox_admin_screen_helpers.dart` is optional and may only hold pure helper logic such as screen-local controller-key derivation or other explicit-parameter helpers that reduce root-file noise without moving orchestration ownership.
- `objectbox_admin_screen_states.dart` may intentionally hold shared screen-state presentation widgets used by both schema and data branches.
- The current two-pane layout, current `Wrap` controls layout, and current fixed-width detail pane remain intact; no responsive redesign is in scope for this cleanup pass.

Error scenarios:
- If a proposed extraction requires renaming route-facing types, provider names, repository contracts, or stable widget keys, keep that change out of scope.
- If extracting a helper makes scroll synchronization or route-refresh timing harder to reason about or more fragile under tests, keep that helper in the root screen.
- If an extracted widget would need direct provider access to stay functional, prefer passing explicit state/callback inputs from the coordinator instead.
- If an implementation changes the refresh trigger path, it must still satisfy the observable contract: refresh on visible route entry, not on unchanged visibility, and not on unrelated rebuilds.

Limits:
- No new dependencies.
- No ObjectBox model or generated-file changes.
- No provider-state redesign.
- No repository contract redesign.
- No copy edits.
- No UX redesign.
- No `lib/widgets/` promotion for admin-only UI in this pass.
</boundaries>

<implementation>
Do not introduce `part` / `part of` files for this refactor. Keep the extraction screen-scoped using non-private exported top-level widgets and pure helpers with explicit constructor arguments and explicit parameters.

Any logic that directly reads `ref`, calls notifier methods, listens to `router.routerDelegate`, creates or disposes controllers, or shows snackbars stays in `./lib/screens/objectbox_admin_screen.dart` unless it is invoked through a shell-owned callback.

Keep visible-entry refresh orchestration, load-more triggering, horizontal-scroll coordination, and export/snackbar side effects in `./lib/screens/objectbox_admin_screen.dart`. Optional helper extraction must not move those side effects or ownership boundaries out of the root screen.

Implementation style:
- Use the existing `map_screen.dart` plus sibling `map_screen_*` files as the organizational model.
- Use non-private exported names for any widgets or helpers moved into sibling files, because library-private `_WidgetName` symbols cannot be imported across files.
- Prefer pure presentational widgets with explicit constructor arguments over new abstractions.
- Keep the extraction feature-local and mechanical.

File-specific expectations:
- `./lib/screens/objectbox_admin_screen.dart`: keep `ObjectBoxAdminScreen`, `_ObjectBoxAdminScreenState`, controller ownership/disposal, route-listener ownership, provider reads, snackbar side effects, route-refresh logic, row-controller map ownership, `_buildBody`, and high-level screen composition.
- `./lib/screens/objectbox_admin_screen_controls.dart`: own a non-private exported controls widget and only the presentational control surface for entity selection, view-mode toggle, search field, and export controls.
- `./lib/screens/objectbox_admin_screen_states.dart`: own non-private exported schema and shared screen-state presentation widgets that do not need provider access or controller ownership.
- `./lib/screens/objectbox_admin_screen_table.dart`: own non-private exported table header, row, cell, and data-grid widgets for the current data view.
- `./lib/screens/objectbox_admin_screen_details.dart`: own a non-private exported details widget and full-row-value rendering.
- `./lib/screens/objectbox_admin_screen_helpers.dart`: optional; use only for pure helper extraction that reduces root-file noise without moving orchestration ownership.

Stable selectors to preserve:
- `Key('objectbox-admin-empty-state')`
- `Key('objectbox-admin-error-state')`
- `Key('objectbox-admin-table')`
- `Key('objectbox-admin-entity-dropdown')`
- `Key('objectbox-admin-schema-data-toggle')`
- `Key('objectbox-admin-export-gpx')`
- `Key('objectbox-admin-export-error')`
- `Key('objectbox-admin-header-row')`
- `Key('objectbox-admin-row-list')`
- `Key('objectbox-admin-details-close')`
- `Key('objectbox-admin-details-list')`

Current screen-private behaviors to preserve:
- `_searchController` stays synchronized with `state.searchQuery`.
- Re-entering `/objectbox-admin` triggers `refresh()` through the current route-visibility change flow, not by changing route structure or by ordinary rebuild churn.
- Header and row horizontal scroll positions stay synchronized through the current shell-owned controller coordination.
- Details-title formatting remains `${entity.displayName} #${objectBoxAdminFormatValue(row.primaryKeyValue)}` when a row is selected.

What to avoid:
- Avoid moving filtering, sorting, export logic, or schema/model formatting out of the provider/repository into extracted widgets.
- Avoid adding new stable keys unless an uncovered regression needs a deterministic selector already justified by this screen.
- Avoid extracting stateful widgets that duplicate controller ownership already held by the root screen.
- Avoid broad renaming churn for private widget classes if the split can stay mechanical.
- Avoid leaving extracted sibling-file widgets with library-private `_...` names; once moved across files they must become non-private exported symbols.
</implementation>

<stages>
Phase 1: Lock down regression boundaries.
- Confirm current selectors, current copy, current route-refresh behavior, and the actual existing test files that protect them.
- Add a missing focused regression test first only if inspection shows a behavior-sensitive gap for the chosen extraction boundary.

Phase 2: Extract the trapped presentational widgets.
- Move controls, schema widgets, data-grid widgets, and details pane into the planned sibling files.
- Keep the current callback/state inputs explicit and mechanical.
- Re-run targeted widget coverage before any optional helper extraction.

Phase 3: Extract any allowed pure shell helpers.
- Only extract a helper if it is pure, screen-local, and leaves controller ownership, provider access, router listening, and side effects in the root screen.
- Re-verify route-entry refresh and scroll-related behavior before continuing.

Phase 4: Final sweep.
- Remove dead imports and stray inline widgets/helpers.
- Run targeted ObjectBox Admin verification first, then full analysis and tests.
- Confirm `objectbox_admin_screen.dart` reads as a coordinator instead of a full widget catalog.
</stages>

<illustrations>
Desired:
- `./lib/screens/objectbox_admin_screen.dart` shows route/listener setup, controller orchestration, provider reads, and composition of extracted admin widgets.
- The table/grid code lives in its own sibling file, making fixed-column and scroll-sync rendering easier to inspect.
- The details pane and control bar become isolated presentational units without changing behavior.

Avoid:
- Moving row-loading logic or export behavior into widgets.
- Creating many tiny one-method files.
- Changing the admin browser layout or interaction model just because the code is being split.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Repository/service behavior: keep `./test/services/objectbox_admin_repository_test.dart` green for schema metadata, filter/sort helper behavior, admin-row mapping, and GPX export writing.
- Widget behavior: keep `./test/widget/objectbox_admin_shell_test.dart` and `./test/widget/objectbox_admin_browser_test.dart` green for shell opening, route re-entry refresh, filtering/no-match behavior, chunked rows, fixed-first-column behavior, details rendering, schema rendering, export visibility, and current shell selectors.
- Critical user journey: keep `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` green for opening ObjectBox Admin from the menu and confirming the shell renders with the same stable selectors.

Coverage notes:
- Current robot coverage does not protect deep browser behavior; widget tests carry most of the UI regression weight for this screen.
- Current tests do not appear to assert export snackbar copy or every empty/error branch directly, so if the extraction touches those branches in a behavior-sensitive way, add one focused widget regression rather than broad new test surface.
- There is no standalone notifier test today; prefer preserving behavior through existing screen-level seams unless a new pure helper or fragile state path warrants a small additional test.

TDD expectations:
- Treat pure file extraction under already-green coverage as refactor work.
- If a behavior-sensitive area is not already protected before a specific extraction, add one focused failing test slice first, make the smallest change to pass it, then continue.
- Use vertical slices when new coverage is needed: one failing test, minimal extraction/change, green, then refactor further.
- Prefer the existing test harness repository/provider overrides over new mocks; mock only true external boundaries.

Robot/widget/unit split:
- Robot tests: keep `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` green for the menu-open happy path and stable shell selector contract.
- Widget tests: keep `./test/widget/objectbox_admin_shell_test.dart` and `./test/widget/objectbox_admin_browser_test.dart` green for route re-entry refresh, filter/search behavior, visible rows, table/details interactions, schema mode, export controls, and current visible copy already asserted there.
- Unit/service tests: keep `./test/services/objectbox_admin_repository_test.dart` green for descriptor fields, filter/sort helpers, admin-row mapping, and GPX export behavior.

Selectors and seams:
- Preserve the stable app-owned `Key` selectors listed in this spec.
- Keep deterministic test seams via `objectboxAdminRepositoryProvider` overrides, existing fake repositories, and current route navigation through `App()` and `GoRouter`.
- Do not introduce async or controller indirection that makes row scrolling, details rendering, or route re-entry tests flaky.

Verification commands:
- `flutter test test/widget/objectbox_admin_shell_test.dart`
- `flutter test test/widget/objectbox_admin_browser_test.dart`
- `flutter test test/robot/objectbox_admin/objectbox_admin_journey_test.dart`
- `flutter test test/services/objectbox_admin_repository_test.dart`
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- `./lib/screens/objectbox_admin_screen.dart` is materially smaller and acts as a coordinator for route lifecycle, controllers, provider orchestration, and composition only.
- `./lib/screens/objectbox_admin_screen.dart` no longer contains trapped presentational widget class definitions for the controls surface, schema/state presentation, table/grid presentation, or details pane.
- The planned sibling files exist and each owns a cohesive ObjectBox Admin responsibility.
- The `/objectbox-admin` route, current copy, stable selectors, current provider/repository contracts, and current admin-browser behavior are preserved.
- Existing widget, robot, and service regressions for ObjectBox Admin remain green, with only minimal test additions if a genuine uncovered behavior-sensitive seam is found.
- `flutter analyze` and `flutter test` pass.
</done_when>
