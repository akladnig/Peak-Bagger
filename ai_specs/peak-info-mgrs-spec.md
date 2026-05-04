<goal>
Add an MGRS line to the peak info popup on the map screen so users can inspect the peak's grid reference directly in context. At the same time, make the peak list membership label grammatically correct so the popup reads naturally for one list versus many.
</goal>

<background>
This is a Flutter map-screen UI change. The peak popup is built in `./lib/screens/map_screen_panels.dart` and is driven by `PeakInfoContent` from `./lib/providers/map_provider.dart`.

Relevant files to inspect and update:
- `./lib/screens/map_screen_panels.dart`
- `./test/widget/map_screen_peak_info_test.dart`
- `./test/widget/peak_info_popup_placement_test.dart`
- `./test/robot/peaks/peak_info_robot.dart`
- `./test/robot/peaks/*` journey coverage that exercises the peak popup

The popup already shows peak name, height, map name, and list memberships. For this popup, render the MGRS display string explicitly as `55G EN 12345 67890`; do not rely on unrelated two-line or lat/lng-appended MGRS displays elsewhere in the app.

The popup currently uses a fixed placement size, so the added row must also keep the card readable near screen edges.
</background>

<user_flows>
Primary flow:
1. User taps a peak marker on the map.
2. The peak info popup opens.
3. The popup shows peak name, height, map, MGRS, and list memberships when available.

Alternative flows:
- One list membership: show `List:` followed by the single list name.
- Multiple list memberships: show `Lists:` followed by the comma-separated names.
- No list memberships: omit the list row entirely.

Error flows:
- Incomplete peak coordinate data: omit the MGRS row rather than rendering malformed text.
- Empty list lookup result: keep the list row hidden, matching current popup behavior.
</user_flows>

<requirements>
**Functional:**
1. Render a new `MGRS:` row directly under the `Map:` row in `PeakInfoPopupCard`.
2. Format the MGRS value as `55G EN 12345 67890`, using the peak's existing grid zone, 100k ID, easting, and northing fields.
3. Keep the existing title and height rows unchanged. Keep the `Map:` row presentation unchanged.
4. Render `List:` when exactly one non-empty list name is present after trimming whitespace.
5. Render `Lists:` when more than one non-empty list name is present after trimming whitespace.
6. Keep the list row hidden when no memberships exist after trimming whitespace.
7. Only render the MGRS row when `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` are all non-empty after trimming.
8. Render the popup using trimmed list names and trimmed MGRS components so displayed text never includes leading or trailing whitespace.
9. Join the rendered MGRS value with exactly one space between components: `zone`, `square`, `easting`, `northing`.

**Error Handling:**
10. If the peak does not have a complete trimmed MGRS value, do not render a malformed row or use the stored MGRS parts for `Map:` lookup.
11. If list-name resolution returns an empty set, do not render the row.

**Edge Cases:**
12. Preserve the repository-provided sorted order after filtering out trimmed-empty list names, and do not deduplicate names that trim to the same visible value.
13. Do not change popup dismiss behavior or map click handling.
14. Increase `UiConstants.peakInfoPopupSize.height` enough to fit the extra MGRS row, and keep `resolvePeakInfoPopupPlacement()` unchanged except for any offset math needed to respect the larger fixed card.
15. Style the MGRS value with the app's existing monospace font treatment used for grid references, but do not reuse the two-line highlighted map readout renderer.

**Validation:**
16. Add widget-test coverage in `./test/widget/map_screen_peak_info_test.dart` for the popup showing the new MGRS row.
17. Add widget-test coverage for singular and plural list labels so exact `List:` and `Lists:` expectations are both verified, replacing legacy `List(s):` assertions.
18. Keep or extend coverage for the no-list case so the row stays hidden when memberships are absent after trimming.
19. Keep popup text/content assertions in `./test/widget/map_screen_peak_info_test.dart`.
20. Keep edge-safe placement assertions in `./test/widget/peak_info_popup_placement_test.dart`, and validate the larger popup using `UiConstants.peakInfoPopupSize` rather than toy popup dimensions alone.
21. Add or update a robot-driven journey in `./test/robot/peaks/peak_info_robot.dart` or its companion peak-info journey test to open a peak popup and assert the rendered text.
22. Extend `PeakInfoRobot.pumpMap()` with the smallest seam needed to accept provider overrides for `peakListRepositoryProvider` and `tasmapRepositoryProvider`, following the existing robot pattern of optional repository inputs passed through `ProviderScope` overrides.
23. Replace any hard-coded popup-content robot expectation with assertions that accept expected lines, so journeys can verify the seeded MGRS and singular/plural list text deterministically.
24. Seed robot coverage with a peak that has complete MGRS fields and with peak-list repository data that produces both the single-list and multi-list label cases.
25. Use behavior-first TDD for the popup text change: write the failing test first, implement the smallest formatter/branch needed, then refactor.
26. Keep tests deterministic by relying on the existing provider overrides and stable popup keys already in the codebase.
27. Baseline automated coverage must include popup formatting logic, widget rendering, edge-safe popup placement, and the critical user journey of opening the popup on the map.
</requirements>

<boundaries>
Edge cases:
- One membership must never be labeled `Lists:`.
- Two or more memberships must never be labeled `List:`.
- Whitespace-only list names must not force the row visible.
- Singular/plural label choice must be based on the filtered list-name count, not the raw repository result count.
- The displayed list names themselves must be the trimmed values.
- The displayed MGRS components themselves must be the trimmed values.

Error scenarios:
- If the popup cannot resolve map or list data, keep the current fallback text and only add the new rows when data exists.
- If the stored MGRS parts are incomplete after trimming, omit the `MGRS:` row and use the existing lat/lng-based map fallback instead of the stored MGRS pieces.
- If MGRS formatting cannot produce the expected string, fail closed by omitting the row.

Limits:
- Keep the change localized to the popup presentation layer, plus the small `_resolvePeakMapName()` completeness check needed to keep `Map:` and `MGRS:` behavior consistent.
- Avoid changing persistence, repository, or coordinate-conversion logic just to support display text.
</boundaries>

<implementation>
Update `./lib/screens/map_screen_panels.dart` so `PeakInfoPopupCard` renders the new MGRS row and chooses `List:` versus `Lists:` based on the count of trimmed, non-empty list names without deduplicating post-trim duplicates.

Update `./lib/providers/map_provider.dart` so `_resolvePeakMapName()` applies the same trimmed completeness rule before using stored MGRS parts; otherwise keep the existing lat/lng fallback behavior.

Increase `./lib/core/constants.dart` `UiConstants.peakInfoPopupSize.height` by the minimum amount needed to keep the new row visible, and keep the popup placement logic in `./lib/screens/map_screen.dart` functionally the same.

Build the popup MGRS string inline or with a small private helper in `./lib/screens/map_screen_panels.dart`; do not attempt to reuse unrelated display helpers unless they are explicitly refactored to produce the exact same output.

Update `./test/widget/map_screen_peak_info_test.dart` to cover the new popup text, replace legacy `List(s):` assertions, and verify the singular/plural grammar with exact `List:` and `Lists:` expectations.

Update `./test/widget/peak_info_popup_placement_test.dart` to validate the larger fixed popup size using `UiConstants.peakInfoPopupSize` and confirm there is no clipping regression near edges.

Update `./test/robot/peaks/peak_info_robot.dart` or the peak-info journey test that uses it so the critical popup flow remains covered end-to-end.

If the existing robot helper cannot accept repository overrides, add the smallest seam needed so the journey can supply peak-list and tasmap fixtures without relying on global state. Mirror the existing robot pattern: optional repository inputs passed through `ProviderScope` overrides rather than a new harness.

Avoid broad refactors in `./lib/providers/map_provider.dart` unless the popup truly cannot be rendered from existing `PeakInfoContent` data; the trimmed-completeness consistency check in `_resolvePeakMapName()` is in scope.
</implementation>

<validation>
Verify the feature with:
- Widget tests that assert the popup now includes `MGRS:` under `Map:`.
- Widget tests that assert a single trimmed list name shows `List:` and multiple trimmed names show `Lists:`.
- Widget tests that assert the list row is omitted when there are no trimmed list names.
- Widget tests that assert incomplete or whitespace-only MGRS parts hide the `MGRS:` row and preserve the lat/lng-based `Map:` fallback behavior.
- Widget tests in `./test/widget/peak_info_popup_placement_test.dart` that exercise edge-position placement using `UiConstants.peakInfoPopupSize` so the added row does not clip after the height increase.
- A robot journey that opens the popup through the map UI and checks the rendered content.

Expected behavior:
- The popup reads naturally for one versus many memberships.
- The MGRS row matches the requested spacing and field order.
- The rendered list names and MGRS components are trimmed.
- The `Map:` row and `MGRS:` row apply the same completeness rule when deciding whether stored MGRS parts are usable.
- The popup remains stable under the existing provider/test harness setup.
- The updated popup produces no overflow and no edge clipping in placement coverage.

Test split:
- Robot tests: critical peak-popup journey from the map screen, with seeded MGRS and peak-list fixtures passed through explicit provider overrides using the existing robot override pattern.
- Widget tests: popup text, row ordering, singular/plural grammar, and empty-state handling.
- Unit tests: only if a helper is extracted for MGRS/label formatting; cover the formatter first, then the widget.

TDD expectations:
- Start with one failing assertion for the new popup row.
- Add the minimum code to make that assertion pass.
- Add the next assertion for singular/plural grammar.
- Refactor only after each slice is green.
</validation>

<done_when>
The popup shows an MGRS row in the requested format, the list label is grammatically correct for singular and plural memberships, the no-membership case stays hidden, and the updated widget/robot tests pass.
</done_when>
