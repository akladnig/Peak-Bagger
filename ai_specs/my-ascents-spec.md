<goal>
Create a My Ascents dashboard card that lets users review their recorded ascents directly from the dashboard. It replaces the old top-5-walks slot with a compact table of peak name, elevation, and climb date so users can scan recent and historical ascents without leaving the home screen.
</goal>

<background>
- Flutter app with Riverpod, ObjectBox repositories, shared preferences dashboard layout persistence, and reusable dashboard card chrome.
- Dashboard layout lives in `./lib/providers/dashboard_layout_provider.dart`; dashboard rendering lives in `./lib/screens/dashboard_screen.dart`.
- Reuse existing card patterns from `./lib/widgets/dashboard/my_lists_card.dart` and `./lib/widgets/dashboard/latest_walk_card.dart`.
- Ascents are stored in ObjectBox `PeaksBagged` rows in `./lib/models/peaks_bagged.dart` and exposed through `./lib/services/peaks_bagged_repository.dart`.
- Peak metadata comes from `./lib/providers/peak_provider.dart` and `./lib/services/peak_repository.dart`; lookups must use `PeakRepository.findByOsmId()` because `PeaksBagged.peakId` stores the peak OSM id, not the ObjectBox primary key.
- The dashboard card must refresh from explicit revision signals, not from a live repository listener, because the repositories are synchronous ObjectBox wrappers.
- Relevant files to examine: `./lib/providers/dashboard_layout_provider.dart`, `./lib/screens/dashboard_screen.dart`, `./lib/widgets/dashboard/my_lists_card.dart`, `./lib/widgets/dashboard/latest_walk_card.dart`, `./lib/models/peaks_bagged.dart`, `./lib/services/peaks_bagged_repository.dart`, `./lib/providers/peak_provider.dart`, `./lib/services/peak_repository.dart`, `./test/widget/dashboard_screen_test.dart`, `./test/robot/dashboard/dashboard_robot.dart`, and `./test/robot/dashboard/dashboard_journey_test.dart`.
</background>

<discovery>
- Confirm the card should read from `PeaksBagged` rows as the source of truth, and only join `PeakRepository` for display metadata.
- Confirm the refresh seam for summary updates: add explicit revision/invalidation signals for bagged ascents and peak metadata, and list the write paths that must bump them.
- Decide the fallback for missing peak metadata: render `Unknown Peak` / `Unknown` elevation instead of hiding the ascent.
- Confirm legacy `top-5-walks` dashboard entries must be migrated to `my-ascents` while preserving the saved order.
</discovery>

<user_flows>
Primary flow:
1. User opens the dashboard.
2. The `My Ascents` card appears in the existing top-5-walks slot.
3. The card lists ascents grouped by year.
4. Within each year, rows are sorted by `Date Climbed` descending by default.
5. User taps the sort toggle to switch between descending and ascending date order.
6. The card updates in place without affecting the rest of the dashboard.

Alternative flows:
- Returning user: the saved dashboard order remains intact after the slot id migration.
- User has many ascents: the card scrolls vertically inside the tile instead of clipping content.
- User has ascents across several years: each year gets a header row and rows remain grouped under the correct year.
- Year sections follow the same ascending/descending direction as the date sort.

Error flows:
- No ascent rows exist: show a compact empty state instead of an empty table shell.
- A `PeaksBagged` row has a missing peak lookup or missing elevation: show the ascent with fallback text and keep rendering.
- A `PeaksBagged` row has a null `date`: skip the row entirely so it does not appear in the card.
</user_flows>

<requirements>
**Functional:**
1. Rename the dashboard slot id from `top-5-walks` to `my-ascents` and update the visible card title to `My Ascents`.
2. Register `my-ascents` in `dashboardCards` and replace the default dashboard order entry `top-5-walks` with `my-ascents`.
3. Render a compact table with the columns `Peak Name`, `Elevation`, and `Date Climbed`.
4. Build the card from `PeaksBagged` rows as the source of truth, joining `PeakRepository` only for peak name and elevation display.
5. Sort ascents by `date` descending by default, with a toggle to switch to ascending order.
6. Group rows by year and render a full-width year header row before each year section.
7. Preserve deterministic ordering for ties using `peak name` ascending, then `peakId`, then `baggedId`.
8. Keep rows visible for repeated ascents of the same peak; do not deduplicate bagged rows.
9. Skip any `PeaksBagged` row whose `date` is null.
10. Use the app's existing date formatting conventions for `Date Climbed`.
11. Render elevation as an integer SI value with no decimal places and the existing meter suffix convention used by the app.
12. Keep the card within the existing dashboard tile contract without changing the dashboard grid layout or persisted ordering behavior beyond the slot migration.
13. Reorder year sections with the same direction as the sort toggle.

**Error Handling:**
14. Show an empty state when there are no ascent rows to render.
15. If a peak lookup fails, render `Unknown Peak` and `Unknown` elevation instead of crashing or hiding the ascent.
16. If `date` is null or unreadable, skip the row so it does not appear in the card.
17. The sort toggle must be a no-op safe action when the data set is empty.

**Edge Cases:**
18. Multiple ascents on the same date must still sort deterministically.
19. Very long peak names must ellipsis within the card rather than wrap into multiple lines.
20. If the grouped content exceeds the card height, the table body should scroll vertically inside the card.
21. Keep the sort direction local to the card state; do not add persisted user preference storage for this toggle.

**Validation:**
21. Add a pure summary/service seam so unit tests can cover grouping, sorting, tie-breaking, null-date handling, and fallback row rendering without widget plumbing.
22. Add explicit revision providers or equivalent invalidation hooks for peak metadata and bagged ascents, and require the summary provider to watch them.
23. Define the mutation paths that must bump those revisions: peak saves/deletes, bagged-ascent rebuild/sync paths, and any import/admin flows that mutate either dataset.
24. Add stable keys for the card root, table root, empty state, sort toggle, year header rows, and ascent rows so widget and robot tests can target them reliably.
25. Use stable selectors such as `dashboard-card-my-ascents`, `my-ascents-card`, `my-ascents-table`, `my-ascents-empty-state`, `my-ascents-sort-toggle`, `my-ascents-year-2026`, and `my-ascents-row-<baggedId>`.
26. Baseline automated coverage must include business logic, widget/UI behavior, and the critical dashboard journey.
27. Follow vertical-slice TDD: write one failing test per behavior slice, implement the minimum code to pass, then refactor after green.
28. For user-facing journey coverage, use robot-driven tests for the dashboard happy path and widget tests for sort toggling, empty state, year grouping, and scroll behavior.
29. Tests must use in-memory repositories or fakes for `PeakRepository`, `PeaksBaggedRepository`, and shared preferences; do not depend on live ObjectBox data.
</requirements>

<boundaries>
- This is a dashboard summary card only; do not add ascent editing, navigation, or map interactions.
- Do not change the existing dashboard card chrome, drag/reorder behavior, or grid breakpoints as part of this work.
- The card should read from ObjectBox-backed ascents, not from a new cache or a track-derived summary.
- The sort toggle is in-memory only for the current session.
- Preserve legacy dashboard layouts by rewriting `top-5-walks` to `my-ascents` during layout load or sanitation, while keeping the existing `top-5-highest` to `my-lists` migration intact. If both legacy ids appear, rewrite both and keep their first-seen relative order after sanitization.
- Keep the UI compact enough for the existing 4:3 dashboard tile.
</boundaries>

<implementation>
- Add `./lib/services/my_ascents_summary_service.dart` as a pure aggregation layer that joins `PeaksBaggedRepository` and `PeakRepository` rows into grouped, sorted ascent sections.
- Add `./lib/providers/my_ascents_summary_provider.dart` to expose a derived Riverpod view model for the dashboard card and to keep the card refreshing when ascent or peak metadata changes.
- Make the provider watch explicit ascent and peak revision signals, or equivalent mutation hooks, so ObjectBox changes invalidate the summary deterministically.
- Add `./lib/widgets/dashboard/my_ascents_card.dart` for the table UI, empty state, year headers, and sort toggle.
- Update `./lib/screens/dashboard_screen.dart` to render `MyAscentsCard` in the `my-ascents` slot.
- Update `./lib/providers/dashboard_layout_provider.dart` so the card definition title becomes `My Ascents` and the persisted order migrates `top-5-walks` to `my-ascents`.
- Add or update tests in `./test/services/my_ascents_summary_service_test.dart`, `./test/providers/my_ascents_summary_provider_test.dart`, `./test/widget/my_ascents_card_test.dart`, `./test/widget/dashboard_screen_test.dart`, `./test/robot/dashboard/dashboard_robot.dart`, and `./test/robot/dashboard/dashboard_journey_test.dart`.
- Reuse the existing dashboard card shell and key conventions; do not introduce a new card system.
</implementation>

<stages>
1. Build the pure ascent summary service first and prove grouping, sorting, tie-breaking, null handling, and fallback display behavior with unit tests.
2. Build the dashboard card widget next and prove the title, columns, year headers, sort toggle, empty state, and internal scrolling with widget tests.
3. Wire the card into the dashboard grid and update the layout migration so the `my-ascents` slot appears in the expected position.
4. Add robot coverage for the dashboard journey and verify the stable keys/selector contract.
</stages>

<validation>
- Follow vertical-slice TDD: one failing test, minimal implementation, then refactor after green.
- Unit tests must cover empty input, year grouping, ascending and descending order, tie-breaking, null dates, missing peak metadata, and repeated ascents of the same peak.
- Widget tests must cover the visible title, the three table columns, year headers, sort toggle behavior, empty state, and narrow/wide tile sanity checks.
- Dashboard tests must cover the `my-ascents` slot while preserving the existing card order and drag behavior.
- Dashboard tests must cover legacy migration from `top-5-walks` to `my-ascents`.
- Robot tests must cover the primary dashboard journey: open dashboard, locate the `My Ascents` card by stable keys, and verify grouped rows and sort toggle behavior with fake data.
- Use fake repositories or in-memory storage for all tests; do not depend on live ObjectBox data or the real clock.
- Baseline automated coverage must include logic/business rules, UI behavior, and the critical dashboard interaction path.
</validation>

<done_when>
- The dashboard shows a `My Ascents` card in the `my-ascents` slot and migrates existing saved orders.
- The card displays grouped ascents with peak name, elevation, and date climbed.
- The sort toggle switches the card between ascending and descending date order.
- Empty and malformed ascent data fail safely without crashing the dashboard.
- Unit, widget, dashboard, and robot tests cover the feature and pass.
</done_when>
