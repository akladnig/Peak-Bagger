<goal>
Add a Peaks Bagged dashboard card.
It mirrors the Distance card shell, but charts peak climbs instead of distance: total climbs use `Theme.primary`, new peaks climbs use green.
</goal>

<background>
Flutter + Riverpod dashboard. `lib/screens/dashboard_screen.dart` already reserves the `peaks-bagged` card slot in the grid order, but the body still renders a placeholder.
Existing dashboard cards (`distance`, `elevation`) use the shared summary-card chrome, visible-summary header metrics, and stable key prefixes. `GpxTrack.peaks` already holds the correlated peak list; use that existing track data flow for the card.
Keep the header metric aligned with the primary series only; the secondary series stays in the chart/tooltip.

Files to examine:
- `./lib/screens/dashboard_screen.dart`
- `./lib/providers/dashboard_layout_provider.dart`
- `./lib/widgets/dashboard/distance_card.dart`
- `./lib/widgets/dashboard/elevation_card.dart`
- `./lib/widgets/dashboard/summary_card.dart`
- `./lib/widgets/dashboard/summary_chart.dart`
- `./lib/models/gpx_track.dart`
- `./lib/models/peaks_bagged.dart`
- `./lib/services/peaks_bagged_repository.dart`
- `./test/widget/dashboard_screen_test.dart`
- `./test/robot/dashboard/dashboard_journey_test.dart`
- `./test/robot/dashboard/elevation_journey_test.dart`
- `./test/services/summary_card_service_test.dart`
- `./test/widget/distance_card_test.dart`
- `./test/widget/elevation_card_test.dart`
</background>

<user_flows>
Primary flow:
1. User opens Dashboard.
2. Peaks Bagged card appears in the existing grid order.
3. Card shows total peak climbs and new peak climbs for the selected period.
4. User switches period, scroll window, or chart mode.
5. Header metrics update for the visible window.

Alternative flows:
- No tracks or no correlated peaks: show empty state.
- Some tracks lack `trackDate`: omit them from the chart, same as the other summary cards.
- Repeated climbs of the same peak: count once as new, then as repeat climbs on later occurrences.

Error flows:
- While tracks are loading: show loading state.
- Invalid peak ids or malformed track data: skip those values, do not fail the card.
</user_flows>

<requirements>
**Functional:**
1. Add `PeaksBaggedCard` under `./lib/widgets/dashboard/peaks_bagged_card.dart`.
2. Replace the `peaks-bagged` placeholder branch in `./lib/screens/dashboard_screen.dart` with the real card.
3. Preserve the existing dashboard card chrome: drag handle, card border behavior, summary header, period dropdown, prev/next window buttons, and mode toggle.
4. Use a stable key prefix `peaks-bagged` and card key `peaks-bagged-card`.
5. Render the primary series as total climbs per bucket, using the existing theme primary color.
6. Render the secondary series as first-time climbs per bucket, using green.
7. Keep the visual order fixed: primary first, secondary second.
8. Show header metrics for the primary series only.

**Error Handling:**
9. Loading state key: `peaks-bagged-loading-state`.
10. Empty state key: `peaks-bagged-empty-state` with clear no-data copy.
11. Ignore undated or invalid inputs rather than inventing fallback dates.

**Edge Cases:**
12. Collapse duplicate peak ids within one track to a single climb.
13. Classify a peak as new only on its first chronological occurrence.
14. Break ties deterministically by `trackDate`, then `gpxTrackId`, then `peakId`.

**Validation:**
15. Read-only UI only; no persistence writes.
16. Keep tooltip, bucket, and header text deterministic for widget and robot tests.
</requirements>

<boundaries>
Edge cases:
- Empty tracks list: render empty state.
- Null `trackDate`: skip from timeline.
- Same peak on multiple tracks: first occurrence is new, later occurrences are repeats.
- Same track containing duplicate peak ids: count once.

Error scenarios:
- Malformed track or peak data: skip invalid rows, keep the card alive.
- Loading in progress: show loading state, not stale content.

Limits:
- Do not mutate track data or bagged persistence.
- Do not add a new dashboard layout slot or storage key; reuse the existing `peaks-bagged` slot.
</boundaries>

<implementation>
Create:
- `./lib/widgets/dashboard/peaks_bagged_card.dart`
- `./lib/services/peaks_bagged_summary_service.dart`
- `./test/services/peaks_bagged_summary_service_test.dart`
- `./test/widget/peaks_bagged_card_test.dart`

Modify:
- `./lib/screens/dashboard_screen.dart`
- `./test/widget/dashboard_screen_test.dart`
- `./test/robot/dashboard/dashboard_journey_test.dart`
- `./test/robot/dashboard/elevation_journey_test.dart` only if shared dashboard robot helpers need a new selector

Assumption:
- Derive the card from current `MapState.tracks` / `GpxTrack.peaks`, matching the existing dashboard data flow. Do not introduce a separate bagged-history provider unless the implementation needs it for determinism.

Implementation notes:
- Keep the card nearly identical to `DistanceCard` in structure.
- Use a small summary service for timeline math so the widget stays thin.
- Reuse the existing summary chart chrome and stable selectors where possible.
- Keep the card header metrics wired through the same visible-summary callback pattern used by `DistanceCard` and `ElevationCard`.
</implementation>

<validation>
Use vertical-slice TDD.

Behavior-first slices:
1. Add a failing service test for total climb counts, new peak counts, and duplicate collapse.
2. Add a failing service test for chronological first-occurrence logic and tie-breaking.
3. Add a failing widget test for empty/loading states and stable keys.
4. Add a failing widget test for dashboard wiring and header summary updates.
5. Add a failing robot regression for dashboard card presence plus scoped summary controls.

Baseline automated coverage:
- Logic/business rules: total-vs-new peak series, dedupe, null-date skipping, tie-breaking, and empty inputs.
- UI behavior: card slot renders in the dashboard grid, loading/empty/content states work, summary controls remain scoped.
- Critical journey: Dashboard opens with Peaks Bagged present; card controls still work after layout reordering and track refresh.

Test split:
- Service tests for derivation/timeline math.
- Widget tests for card rendering, keys, empty/loading state, and header metrics.
- Robot tests for dashboard-level regression only; keep the selectors key-first.

Stable selectors:
- `dashboard-card-peaks-bagged`
- `peaks-bagged-card`
- `peaks-bagged-loading-state`
- `peaks-bagged-empty-state`
- `peaks-bagged-period-range`
- `summary-period-dropdown`
- `summary-prev-window`
- `summary-next-window`
- `summary-mode-fab`

Known risk:
- The peak-first-occurrence rule depends on track ordering. Keep the ordering explicit in the summary service so tests stay deterministic.
</validation>

<done_when>
Dashboard shows a real Peaks Bagged card in the `peaks-bagged` slot, the card renders total and new peak climb series with the existing summary controls, empty/loading states are covered, and tests prove the card is deterministic and stable under dashboard reorders.
</done_when>
