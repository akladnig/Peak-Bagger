<goal>
Add a seventh dashboard card that summarizes a selected calendar year so users can review distance, ascent, walk count, peaks climbed, and new peaks climbed directly from the dashboard.
The card should default to the current local year, let users move backward and forward one year at a time, and keep the selected year tied to the card during normal dashboard rebuilds and reordering.
</goal>

<background>
- Flutter app using Riverpod, Material, and the existing draggable dashboard grid.
- The dashboard already has summary cards for Elevation, Distance, and Peaks Bagged, plus existing placeholder cards for the top-5 views.
- The new card should derive its data from `mapProvider.tracks`; do not add a persisted analytics store.
- Existing summary and peak chronology conventions live in `./lib/services/summary_card_service.dart`, `./lib/services/peaks_bagged_summary_service.dart`, `./lib/widgets/dashboard/summary_card.dart`, and `./lib/widgets/dashboard/peaks_bagged_card.dart`.
- The new card must survive reorder-driven widget reuse, so its dashboard tile wrapper needs a stable key at the tile boundary, not just on the inner body.
- Relevant files to examine: `./lib/screens/dashboard_screen.dart`, `./lib/providers/dashboard_layout_provider.dart`, `./lib/providers/map_provider.dart`, `./lib/core/number_formatters.dart`, `./lib/widgets/dashboard/latest_walk_card.dart`, `./test/providers/dashboard_layout_provider_test.dart`, `./test/widget/dashboard_screen_test.dart`, `./test/widget/latest_walk_card_test.dart`, `./test/services/peaks_bagged_summary_service_test.dart`, `./test/robot/dashboard/dashboard_robot.dart`, and `./test/robot/dashboard/dashboard_journey_test.dart`.
</background>

<discovery>
- Inspect the current dashboard card shell and robot selector patterns before wiring the new card.
- Reuse the app's existing peak chronology rules so "new peaks climbed" stays consistent with the Peaks Bagged card.
- Decide whether the year selector should live inside a dedicated year-summary widget or be exposed through the existing dashboard shell, but keep the visible year label deterministic and testable.
</discovery>

<user_flows>
Primary flow:
1. User opens the dashboard.
2. The Year-to-Date card shows the current local year by default.
3. The card displays distance walked, ascent climbed, total walks, peaks climbed, and new peaks climbed for that year.
4. User taps Prev or Next to move one year backward or forward.
5. The visible year label and all metric values update together.

Alternative flows:
- Returning user: dashboard card order persists, but the selected year resets to the current year on launch.
- User navigates to a year with no walks: the card still renders and shows zero values.
- User imports or deletes tracks: the currently selected year recomputes from the updated track list.

Error flows:
- Tracks are still loading: show a loading state instead of stale metrics.
- Tracks with null `trackDate` are ignored.
- Duplicate peak ids within a walk count once.
- Same-day tracks use `gpxTrackId` as a deterministic tie-breaker when deciding first-time peaks.
</user_flows>

<requirements>
**Functional:**
1. Add a seventh dashboard card with stable id `year-to-date` and place it with the other summary cards before the `top-5-*` placeholders in `dashboardCards`, `dashboardDefaultCardOrder`, `dashboard_screen.dart`, and the dashboard tests.
2. Keep the selected year local to the card widget. Initialize it from the current local year and move it by exactly one calendar year when Prev or Next is tapped.
3. Keep the dashboard tile label as `My Year to Date`, and show a visible year header row inside the card body that reads `My Walks in YYYY`.
4. Display these metrics for the selected year:
   - Kilometers walked: total distance for tracks in that year.
   - Metres climbed: total ascent for tracks in that year.
   - Total Walks: count of usable tracks in that year.
   - Peaks Climbed: count of unique peaks climbed on those walks, matching the existing per-walk peak counting rule.
   - New Peaks Climbed: count of peaks whose first chronological occurrence across all tracks falls in the selected year.
5. Use `mapProvider.tracks` as the source of truth.
6. Filter by local calendar-year boundaries, not UTC year boundaries, so the summary matches the user's timezone.
7. Ignore tracks with null `trackDate`.
8. Treat tracks with null `ascent` as zero metres climbed rather than excluding the walk from the yearly summary.
9. Keep the selected year stable across ordinary dashboard rebuilds and drag-reorder operations within the same app session.
10. Format distance with the existing distance formatter and format ascent/count values with the app's existing whole-number style.
11. Keep the dashboard's existing drag/reorder and persistence behavior intact.
12. Thread an optional `now` seam through the year summary service and card widget so tests can pin the initial year deterministically.

**Error Handling:**
12. While tracks are unavailable or loading, show a loading state.
13. If a selected year has no usable walks, render zero values rather than an empty or broken state.
14. Do not crash if a walk has no peaks or contains duplicate peak ids.

**Edge Cases:**
15. A walk with the same peak repeated multiple times counts that peak once for the walk.
16. Future or past years with no tracks are valid selections.
17. Same-day tracks must produce deterministic new-peak results by ordering chronologically and then by `gpxTrackId`.
18. The card body must stay readable inside the existing 4:3 dashboard tile by using a responsive metric layout that keeps each metric on one line and truncates rather than wraps.
19. The card must not persist the selected year to storage unless that becomes an explicit product requirement.

**Validation:**
20. Add deterministic seams for `now` and track input so unit and widget tests do not depend on the live clock or storage.
21. Use stable keys for the year card root, Prev or Next controls, title, and each metric row or value so widget and robot tests can scope selectors reliably.
22. Baseline automated coverage must include logic or business rules, UI behavior, and the critical dashboard journey.
</requirements>

<boundaries>
Edge cases:
- A year with no tracks should still show the card chrome and zero metrics.
- Null `trackDate` values are ignored, but a track with a valid date and zero metrics still counts as a walk.
- Card-local year state should survive drag reorder within the same session.
- `ascent == null` should behave like `0` for the yearly summary rather than excluding the walk.

Error scenarios:
- No new persistence layer, analytics cache, or server API.
- No chart, map preview, or route navigation is part of this card.
- Do not change GPX import or ObjectBox schema behavior.
- Avoid coupling the new summary logic to private widget internals; keep the math in a testable service boundary.

Limits:
- This is a dashboard summary card only.
- The feature should stay compatible with the existing 4:3 dashboard tile contract.
- Existing saved dashboard orders should keep their stored order; if they are sanitized, the new id can be appended without reshuffling existing cards.
</boundaries>

<illustrations>
Desired:
- In 2026, a walk from 2024 that was already counted before does not become a new peak again.
- Prev on 2026 moves to 2025; Next on 2025 returns to 2026.

Avoid:
- Counting a peak as new just because it is first seen inside the selected year.
- Clearing the card to an empty state for a year that simply has no walks.
</illustrations>

<implementation>
- Add `./lib/services/year_to_date_summary_service.dart` as a pure aggregation layer for year selection, annual totals, walk counts, and peak chronology.
- Add `./lib/widgets/dashboard/year_to_date_card.dart` as the new year-summary card widget.
- Update `./lib/screens/dashboard_screen.dart` to render the new card in the dashboard grid.
- Update `./lib/providers/dashboard_layout_provider.dart` to register the new card id and default order.
- Key the year-to-date dashboard item boundary by `year-to-date` so the selected year does not jump when the dashboard is reordered.
- Give the dashboard tile wrapper a stable `ValueKey('dashboard-card-year-to-date')` or equivalent boundary key so the stateful year selector stays attached to the correct card across reorder operations.
- Reuse the existing peak chronology rules from `./lib/services/peaks_bagged_summary_service.dart` where practical instead of inventing a second definition of "new peaks." 
- Thread an optional `now` parameter through the service and widget APIs so the selected year is deterministic in tests.
- Keep value formatting in shared helpers such as `./lib/core/number_formatters.dart`.
- Add or update tests at `./test/services/year_to_date_summary_service_test.dart`, `./test/widget/year_to_date_card_test.dart`, `./test/widget/dashboard_screen_test.dart`, `./test/providers/dashboard_layout_provider_test.dart`, and `./test/robot/dashboard/dashboard_journey_test.dart`.
</implementation>

<stages>
1. Build the pure year-summary service and prove year filtering, walk counts, ascent, distance, and peak chronology with unit tests.
2. Build the year-to-date card widget and prove title changes, year navigation, zero-year behavior, and loading state with widget tests.
3. Wire the card into the dashboard grid and prove the new slot, card order, and stable selectors with dashboard, widget, and robot tests.
</stages>

<validation>
- Follow vertical-slice TDD: write one failing test, implement the minimum behavior, then refactor after green.
- Unit tests should cover current-year selection, previous or next year movement, null-date filtering, zero-year totals, duplicate peak handling, and deterministic first-occurrence peak counting.
- Widget tests should cover loading state, current-year rendering, year navigation, title updates, zero-value rendering, and compact-width layout stability.
- Widget tests should cover the responsive metric layout contract at wide and narrow widths so the 4:3 tile never wraps metrics into a broken layout.
- Dashboard tests should cover the seventh card appearing in the board and the new id participating in drag or reorder like the existing cards.
- Provider tests should cover the updated default order, sanitization, and persistence behavior with the new `year-to-date` id.
- Robot tests should cover the critical journey: open dashboard, locate the year-to-date card by stable keys, move backward and forward one year, and verify the title and metrics update together.
- Use fake track lists and `now` overrides rather than live storage or the real clock.
- Required baseline coverage outcomes: logic or business rules, UI behavior, and the critical dashboard interaction path.
</validation>

<done_when>
The dashboard shows a seventh card for year-based walk statistics.
The card defaults to the current local year and moves exactly one year at a time with Prev and Next.
The card shows distance, ascent, walk count, peaks climbed, and new peaks climbed for the selected year.
Years with no walks show zeros, not a broken state.
The new card is covered by deterministic unit, widget, and robot tests and participates in the existing dashboard reorder or persistence flow.
</done_when>
