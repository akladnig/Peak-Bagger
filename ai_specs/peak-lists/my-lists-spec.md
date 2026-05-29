<goal>
Add a compact `My Lists` dashboard card that helps users review peak-list progress without opening the Peak Lists screen. The card occupies the dashboard slot renamed to `my-lists`, and the visible title becomes `My Lists`.
</goal>

<background>
- Flutter app with Riverpod, Material, ObjectBox-backed repositories, and the existing draggable dashboard grid.
- Dashboard layout and persistence live in `./lib/providers/dashboard_layout_provider.dart`; card rendering lives in `./lib/screens/dashboard_screen.dart`.
- Peak list data already exists in `./lib/services/peak_list_repository.dart`, `./lib/services/peaks_bagged_repository.dart`, and the peak list summary rules in `./lib/screens/peak_lists_screen.dart`.
- Peak-list and climb-data changes must flow through a single derived Riverpod provider so the dashboard card refreshes when lists or climb data change.
- Relevant files to examine: `./lib/screens/dashboard_screen.dart`, `./lib/providers/dashboard_layout_provider.dart`, `./lib/screens/peak_lists_screen.dart`, `./lib/services/peak_list_repository.dart`, `./lib/services/peaks_bagged_repository.dart`, `./test/widget/dashboard_screen_test.dart`, `./test/providers/dashboard_layout_provider_test.dart`, `./test/widget/peak_lists_screen_test.dart`, `./test/widget/peaks_bagged_card_test.dart`, `./test/robot/dashboard/dashboard_robot.dart`, and `./test/robot/peaks/peak_lists_robot.dart`.
</background>

<discovery>
- Inspect the existing `_PeakListSummaryRow` logic and mirror its dedupe and climb rules where they overlap.
- Decide whether to extract a dedicated peak-list summary service or share a small helper boundary with the peak-lists screen.
- Rename the dashboard slot id to `my-lists` and migrate any saved `top-5-highest` entries to the new id during layout load or sanitation.
- Confirm malformed or legacy peak-list payloads should be skipped, not crash the dashboard summary.
</discovery>

<user_flows>
Primary flow:
1. User opens the dashboard.
2. The `My Lists` card appears in the existing top-5 slot.
3. The card shows up to five peak lists sorted by `% Climbed` descending.
4. Each row shows `List`, `Total Peaks`, `Climbed`, `% Climbed`, and `Unclimbed`.
5. The summary is readable without leaving the dashboard.

Alternative flows:
- Returning user: the dashboard order remains whatever was previously saved; the card content still reflects current repository data.
- User has fewer than five lists: show only the available rows.
- User has lists with zero peaks: show `0` for all numeric columns and `0%` climbed.
- User has malformed stored list payloads: ignore the bad rows and keep rendering the rest.
- User has an older saved dashboard order: transparently map `top-5-highest` to `my-lists` and preserve the rest of the order.

Error flows:
- No usable peak lists exist: show a compact empty state instead of an empty table shell.
- A peak list contains duplicate peak ids: count each peak once in totals and climbed calculations.
- A peak has been climbed multiple times: still count it once as climbed for that list.
</user_flows>

<requirements>
**Functional:**
1. Rename the dashboard slot id to `my-lists` and update the visible title to `My Lists`.
2. Render a compact table with the columns `List`, `Total Peaks`, `Climbed`, `% Climbed`, and `Unclimbed`.
3. Populate the card from watched Riverpod state backed by peak-list repository data and climb data; do not add a new persistence layer.
4. Show at most five rows, ordered by `% Climbed` descending.
5. Use deterministic tie-breakers for equal percentages: `List` name ascending, then `peakListId` ascending.
6. Calculate `Total Peaks`, `Climbed`, and `Unclimbed` from unique peak ids per list.
7. Calculate `% Climbed` as `climbed / totalPeaks * 100`, rounded to the nearest whole number.
8. Keep the card stateless unless the UI needs a minimal local seam for scrolling or row capping.
9. Preserve the existing dashboard reorder/persistence behavior and card ordering.
10. Migrate stored dashboard layouts so existing `top-5-highest` entries become `my-lists` without dropping the rest of the saved order.

**Error Handling:**
10. Skip malformed or unsupported peak-list payloads instead of crashing the dashboard.
11. Render an empty state when no usable lists are available.
12. Treat a list with zero peaks as a valid row with zero values, not an error state.
13. Render the card immediately from derived provider state; if no usable peak lists exist, show the empty state instead of a loading placeholder.

**Edge Cases:**
13. Deduplicate repeated peak ids within a list before counting totals or climbed peaks.
14. If more than five lists exist, truncate after the top five.
15. If fewer than five lists exist, render only the available rows.
16. Keep all headers and values to one line where possible so the 4:3 dashboard tile stays compact.

**Validation:**
17. Add a pure, deterministic summary service seam so unit tests can cover sorting, dedupe, empty-state behavior, and malformed-data handling without widget plumbing.
18. Add stable keys for the card root, table root, empty state, and each row so widget and robot tests can target them reliably.
19. Baseline automated coverage must include business logic, widget/UI behavior, and the critical dashboard journey.
20. Use TDD-style slices for the summary logic first, then the widget, then the dashboard wiring.
21. Dashboard/widget/robot fixtures must inject in-memory peak-list and bagged-data providers so the card renders against deterministic state.
</requirements>

<boundaries>
- This is a dashboard summary card only; do not add editing, navigation, or peak-list management controls.
- Do not change peak-list screen behavior as part of this work unless a shared helper is required to avoid duplicated summary logic.
- Avoid adding a new database or cache; reuse the existing repositories.
- Migrate the dashboard slot id from `top-5-highest` to `my-lists` and preserve legacy saved layouts by rewriting that id during load or sanitation.
- If the card cannot fit all rows cleanly, cap it at five rows rather than introducing a new scroll interaction.
</boundaries>

<implementation>
- Add `./lib/services/peak_list_summary_service.dart` as a pure aggregation layer that builds ranked peak-list rows from `PeakListRepository` and `PeaksBaggedRepository`.
- Add `./lib/widgets/dashboard/my_lists_card.dart` as the dashboard card body and table UI.
- Update `./lib/screens/dashboard_screen.dart` to render `MyListsCard` in the `my-lists` slot.
- Update `./lib/providers/dashboard_layout_provider.dart` so the card definition title becomes `My Lists` and the persisted order migrates `top-5-highest` to `my-lists`.
- Add or update tests in `./test/services/peak_list_summary_service_test.dart`, `./test/widget/my_lists_card_test.dart`, `./test/widget/dashboard_screen_test.dart`, `./test/providers/dashboard_layout_provider_test.dart`, `./test/robot/dashboard/dashboard_robot.dart`, and `./test/robot/dashboard/dashboard_journey_test.dart`.
- Reuse the existing dashboard card chrome and key conventions; do not introduce a new card system.
</implementation>

<stages>
1. Build the summary service and prove ranking, dedupe, tie-breaking, and empty-state behavior with unit tests.
2. Build the dashboard card table and prove the header, row values, cap-at-five behavior, and empty state with widget tests.
3. Wire the card into the dashboard grid and prove the dashboard shows `My Lists` in the expected slot with robot coverage.
4. Verify legacy dashboard orders containing `top-5-highest` migrate to `my-lists`.
</stages>

<validation>
- Follow vertical-slice TDD: one failing test, minimum implementation, then refactor after green.
- Unit tests must cover empty input, malformed payload skipping, duplicate peak ids, zero-peak lists, and stable top-five ordering.
- Widget tests must cover the visible title, the five table columns, row rendering, empty state, and a narrow/wide dashboard tile sanity check.
- Dashboard tests must cover the `my-lists` slot while preserving the existing card order and drag behavior.
- Dashboard tests must cover legacy migration from `top-5-highest` to `my-lists`.
- Robot tests must cover the primary dashboard journey: open dashboard, locate the `My Lists` card by stable keys, and verify the top rows and columns render from fake repository data.
- Use fake repositories or in-memory storage for all tests; do not depend on live ObjectBox data or the real clock.
- Dashboard/widget/robot fixtures must override peak-list and bagged-data providers with deterministic in-memory implementations.
- Required baseline automated coverage outcomes: logic/business rules, UI behavior, and the critical dashboard interaction path.
</validation>

<done_when>
- The dashboard shows a `My Lists` card in the `my-lists` slot and migrates existing saved orders.
- The card displays up to five peak lists sorted by `% Climbed`.
- The table columns and row values match the expected peak-list summary math.
- Empty and malformed data fail safely without crashing the dashboard.
- Unit, widget, dashboard, and robot tests cover the feature and pass.
</done_when>
