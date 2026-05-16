<goal>
Create the Distance dashboard card so users can see total distance across the same time-window presets used by Elevation, with the same chart interactions and card chrome.
This is a derived summary card, not a raw track detail view, and it should help dashboard users compare distance alongside elevation without leaving the dashboard.
This work should also set up reusable summary-card code so a future Peaks Bagged card can share the same shell instead of copying the Elevation implementation again.
</goal>

<background>
- Flutter app using Riverpod, Material, and the existing dashboard grid contract.
- The dashboard already reserves a `distance` slot in `./lib/providers/dashboard_layout_provider.dart`.
- The Elevation card already establishes the interaction and formatting pattern to mirror.
- A third dashboard summary card, Peaks Bagged, is planned to follow the same pattern, so shared card chrome and reusable metric hooks matter here.
- Relevant files to examine: @lib/screens/dashboard_screen.dart, @lib/providers/dashboard_layout_provider.dart, @lib/widgets/dashboard/elevation_card.dart, @lib/widgets/dashboard/elevation_chart.dart, @lib/services/elevation_summary_service.dart, @lib/services/latest_walk_summary.dart, @lib/screens/map_screen_panels.dart, @lib/core/number_formatters.dart, @test/widget/elevation_card_test.dart, @test/services/elevation_summary_service_test.dart, @test/robot/dashboard/elevation_journey_test.dart, @test/widget/dashboard_screen_test.dart, @test/widget/latest_walk_card_test.dart, @test/widget/map_track_info_formatting_test.dart, @test/robot/dashboard/dashboard_journey_test.dart.
</background>

<discovery>
- Review the Elevation card/service/chart before implementing Distance so any shared chrome or formatter extraction stays behaviorally identical.
- Identify the reusable summary-card shell and metric adapter boundary that can support Distance now and Peaks Bagged later without forcing each metric to duplicate the same header, controls, scroll behavior, or header summary reporting.
- Extract shared chart primitives that keep the column/line rendering, tooltip, bucket hover, and horizontal scroll behavior aligned across metrics.
- Move `formatDistance` into a shared helper so the dashboard, latest-walk, and map-panel views keep the same existing `m/km` distance formatting.
</discovery>

<user_flows>
Primary flow:
1. User opens the dashboard.
2. Distance card renders from the loaded track list and shows the total distance for the selected period using `distance2d`.
3. The Distance header summary matches the Elevation summary behavior exactly, with the same placement and update timing.
4. User changes the period, pages previous/next, or toggles the chart mode, and the card updates without affecting dashboard layout or ordering.

Alternative flows:
- Returning user with saved dashboard order sees Distance in the stored position.
- User imports or deletes tracks and the card updates on the next dashboard rebuild.
- User with no usable tracks sees the empty state instead of a broken chart.

Error flows:
- No usable tracks or no track dates: show the empty state.
- Tracks are still loading: show the loading state.
- Small dashboard widths: keep controls accessible and truncate text instead of overflowing.
</user_flows>

<requirements>
**Functional:**
1. Add a real Distance card body to the existing dashboard `distance` slot in `./lib/screens/dashboard_screen.dart`.
2. Mirror the Elevation card interaction model: period dropdown, previous/next arrows, column/line toggle, and horizontally scrollable buckets.
3. Build distance buckets from `GpxTrack.trackDate` and sum `GpxTrack.distance2d` for every usable track in the selected window.
4. Use the same preset set as Elevation: Week, Month, Last 3 Months, Last 6 Months, Last 12 Months, All Time.
5. Use the existing `formatElevationMetres` helper for elevation-style metre values and a shared `formatDistance` helper for distance values so current `m/km` output stays consistent across the app.
6. Keep the Distance header summary behavior identical to Elevation: same location, same timing, and same header-trailing rendering contract, but using distance totals and averages for the active window.
7. Keep the dashboard header metrics in a fixed single-row desktop layout rather than wrapping the summary pills; validate that header-summary contract at a wide desktop width.
8. Extract a reusable summary-card shell plus metric adapters so Elevation, Distance, and Peaks Bagged can share the same header, controls, scroll behavior, summary reporting, and card chrome.
9. Extract shared chart primitives so the bucket hover, tooltip, column/line rendering, and horizontal scrolling behavior stay consistent across summary cards.
10. Migrate shared summary logic to neutral `Summary*` types rather than reusing `Elevation*` names inside shared layers.

**Error Handling:**
11. Show a loading state while tracks are unavailable and an empty state when there are no usable tracks.
12. Do not crash or switch modes if a window contains only zero totals; render zero-value buckets normally.

**Edge Cases:**
13. Ignore tracks with null `trackDate`.
14. Treat `distance2d` as the only source of truth; do not use `distance3d`, `distanceToPeak`, or `distanceFromPeak`.
15. Long labels and compact widths must not force multi-line in-card controls or clipped controls.

**Validation:**
16. Expose deterministic seams for `now` and track input so service and widget tests are stable.
17. Use shared neutral keys for the common shell controls across Elevation, Distance, and Peaks Bagged (`summary-period-dropdown`, `summary-prev-window`, `summary-next-window`, `summary-mode-fab`), and treat those keys as intentionally duplicated across dashboard cards; tests and robots must target them by scoping descendant lookups within a specific card root.
18. Add at least one regression test proving the Elevation card still renders the same header summary and interactions after the shared-shell refactor.
</requirements>

<boundaries>
Edge cases:
- Empty or all-null-date track lists: empty state.
- Zero-distance tracks: still count toward bucket totals.
- Duplicate dates: aggregate them; do not dedupe per day.

Error scenarios:
- Persistence and dashboard ordering are out of scope except for rendering the existing `distance` slot.
- Do not change GPX import, storage, or ObjectBox schema behavior.

Limits:
- Metric values remain in meters/kilometers.
- The card is summary UI only; do not add editing, routing, or map navigation behavior.
- Avoid introducing a new persistence layer or analytics cache for distance summaries.
</boundaries>

<shared_contract>
- `./lib/services/summary_card_service.dart` owns only numeric timeline and bucket math: period handling, bucket construction, visible total calculation, and visible average calculation.
- `./lib/services/summary_card_service.dart` must not own string formatting, unit suffixes, tooltip copy, or empty-state text.
- Shared summary layers must use neutral summary types such as `SummaryPeriodPreset`, `SummaryBucket`, `SummaryTimeline`, and `SummaryVisibleSummary` rather than retaining elevation-specific type names.
- `./lib/widgets/dashboard/summary_card.dart` owns shared dashboard card chrome, loading/empty/populated state switching, period dropdown, previous/next controls, mode toggle, scroll state, and visible-summary callback wiring.
- `./lib/widgets/dashboard/summary_card.dart` also owns the shared control key contract for the dropdown, previous/next buttons, and mode toggle.
- `./lib/widgets/dashboard/summary_chart.dart` owns shared bucket hover/selection behavior, column/line rendering behavior, tooltip placement, and horizontal scroll behavior.
- Each metric adapter (`Elevation`, `Distance`, later `Peaks Bagged`) must provide: key prefix, empty-state text, numeric extractor from `GpxTrack`, value formatter for tooltip and header values, and any metric-specific label strategy that differs from the defaults.
- Metric-specific selectors must follow a reusable `{keyPrefix}-...` pattern for card-local elements such as buckets and tooltips, while preserving existing Elevation selectors and adding matching Distance selectors.
- The shared shell/chart/service split must be explicit in the implementation so future summary cards can plug in a new metric adapter without copying Elevation or Distance widget structure.
</shared_contract>

<implementation>
- Add `./lib/services/summary_card_service.dart` as the pure timeline and bucket computation layer, parameterized by metric so Elevation and Distance can share the same summary math and future cards can plug in different values.
- Introduce neutral shared summary types for the extracted layer and migrate `DashboardScreen`, `ElevationCard`, and related tests away from shared `Elevation*` type names where those types become generic.
- Add `./lib/widgets/dashboard/summary_card.dart` as the shared shell for header, controls, loading/empty states, summary reporting, and card chrome.
- Add `./lib/widgets/dashboard/summary_chart.dart` or equivalent shared chart primitives for bucket rendering, hover selection, tooltip, and horizontal scrolling.
- Add `./lib/widgets/dashboard/distance_card.dart` as a thin metric adapter that supplies `distance2d` and shared `formatDistance` to the shared shell.
- Update `./lib/screens/dashboard_screen.dart` to render `DistanceCard` in the `distance` slot and keep the header summary wiring consistent with Elevation.
- Move `formatDistance` out of `./lib/screens/map_screen_panels.dart` into `./lib/core/number_formatters.dart` or an equivalent shared formatter module, and update existing callers to use that shared helper.
- Keep `formatElevationMetres` in `./lib/core/number_formatters.dart` for whole-metre formatting; do not repurpose it for distance strings.
- Reduce service-to-screen coupling where practical when moving formatters: `./lib/services/latest_walk_summary.dart` should stop depending on `./lib/screens/map_screen_panels.dart` for distance formatting once the shared formatter exists, and any other formatter-only service imports should be cleaned up as part of the same change when safe.
- Keep the shared summary service numeric-only; all display formatting must stay in shared formatter helpers and the card adapters/widgets.
- Keep selector names aligned with the existing dashboard and Elevation conventions, with shared control keys scoped within each card root and metric-specific keys following the adapter `keyPrefix`.
</implementation>

<validation>
- Unit-test `./lib/services/summary_card_service.dart` with `./test/services/summary_card_service_test.dart` for distance and elevation metric adapters, newest-window selection, null `trackDate` filtering, window bucketing, and zero totals.
- Widget-test `./lib/widgets/dashboard/summary_card.dart` and `./lib/widgets/dashboard/distance_card.dart` with `./test/widget/summary_card_test.dart` and `./test/widget/distance_card_test.dart` for populated rendering, empty/loading states, period changes, previous/next navigation, mode toggle, and stable layout on compact sizes.
- Extend `./test/widget/dashboard_screen_test.dart` or add a sibling widget test to verify the dashboard shows the Distance card in the `distance` slot, preserves the existing drag/reorder contract, and keeps the fixed single-row summary header at a wide desktop width.
- Add or extend `./test/robot/dashboard/dashboard_journey_test.dart` to confirm the dashboard exposes stable selectors for the Distance card and its controls without relying on text-only selectors; use a wide desktop surface for header-summary assertions.
- Add regression coverage for the Elevation card and chart to prove the shared shell still preserves the existing header summary, tooltip, and navigation behavior.
- Update formatter coverage to prove the shared `formatDistance` helper preserves existing `840 m` / `12.4 km` behavior and that existing callers in `./lib/screens/map_screen_panels.dart` and `./lib/services/latest_walk_summary.dart` still render unchanged output after the helper move.
- Update widget and robot selector coverage to assert the new shared shell keys for dropdown/previous/next/mode controls via card-scoped descendant lookups, while preserving existing metric-specific Elevation keys and adding metric-specific Distance keys that follow the shared `{keyPrefix}-...` pattern.
- Follow vertical-slice TDD: one failing test, minimal production change, then refactor after green.
- Keep tests deterministic by injecting `now` and using fake track lists or provider overrides instead of live storage.
- Baseline automated coverage must include logic/business rules, UI behavior, and the critical dashboard journey.
</validation>

<stages>
1. Extract the reusable summary shell and chart primitives, prove them with the smallest failing test, and keep Elevation behavior intact.
2. Build the parameterized summary service and metric adapters, then prove the bucket math with unit tests.
3. Build the Distance card thin adapter and prove the controls, states, and chart rendering with widget tests.
4. Wire the card into the dashboard screen and verify the dashboard journey selectors and layout still pass.
</stages>

<done_when>
The dashboard renders a Distance card in the existing `distance` slot.
The card shows period-based distance totals derived from `distance2d`.
The card handles empty, loading, and data-update states without breaking the dashboard.
The Distance header summary is behaviorally identical to Elevation.
The shared shell and chart primitives are in place for Peaks Bagged to reuse.
Existing `m/km` distance formatting remains unchanged across the dashboard, latest-walk, and map-panel views.
Shared generic summary layers no longer expose elevation-specific type names, and formatter extraction reduces avoidable service-to-screen dependencies where practical.
Shared control keys are scoped within each dashboard card, and metric-specific selectors follow the adapter `keyPrefix` pattern.
Required unit, widget, and journey coverage is in place and passing.
</done_when>
