<goal>
Keep the `Tassy Full` peak list as a super-set of all other peak lists, and add a Settings action that refreshes it on demand.

This matters because users need one canonical list that stays current as other peak lists change, without manually copying peaks across lists.
</goal>

<background>
Flutter macOS desktop app using Riverpod, ObjectBox, and the existing peak-list repository and dialog patterns.

Files to examine:
- `./lib/screens/settings_screen.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/peak_list_peak_dialog.dart`
- `./lib/services/peak_list_repository.dart`
- `./lib/services/peak_list_import_service.dart`
- `./lib/models/peak_list.dart`
- `./lib/providers/peak_list_provider.dart`
- `./lib/providers/peak_list_selection_provider.dart`
- `./lib/widgets/dialog_helpers.dart`
- `./test/widget/gpx_tracks_shell_test.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/widget/peak_list_csv_export_settings_test.dart`
- `./test/robot/peaks/peak_refresh_robot.dart`
- `./test/robot/peaks/peak_list_export_robot.dart`
- `./test/robot/peaks/peak_lists_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. User opens Settings.
2. User taps `Update Tassy Full Peak List`.
3. User confirms the action.
4. App refreshes `Tassy Full` from all other peak lists by adding or updating peaks.
5. App shows a completion dialog with added and updated counts.

Alternative flows:
- User adds a peak to any non-`Tassy Full` list: `Tassy Full` gains the peak automatically.
- User removes a peak from one list: `Tassy Full` remains a super-set and does not auto-delete it.
- User imports a peak list: the imported data is included in the next automatic reconciliation.
- User deletes a source peak list: `Tassy Full` remains a super-set unless the user directly edits it.
- User edits `Tassy Full` directly: editing remains possible, and deletions are only allowed through direct edits.

Error flows:
- `Tassy Full` does not exist: create it during reconciliation.
- A source peak-list payload is malformed: skip that list and continue.
- The explicit Settings update fails: show a failure dialog and leave the target list unchanged.
</user_flows>

<requirements>
**Functional:**
1. Treat the exact peak-list name `Tassy Full` as the sync target.
2. Exclude `Tassy Full` from source aggregation when computing the derived list.
3. Refresh `Tassy Full` after every successful non-`Tassy Full` peak-list membership change, including add, point update, save and import flows, using best-effort automatic sync.
4. Refreshing `Tassy Full` must build the union of all peaks in the source lists, dedupe by `peakOsmId`, and keep the highest `points` value seen for each peak.
5. Reconciliation must write a deterministic list order, sorted by `peakOsmId` ascending.
6. If the target list is missing, create it automatically.
7. Automatic sync must never delete peaks from `Tassy Full`; only direct edits to `Tassy Full` may remove peaks.
8. Add a Settings tile titled `Update Tassy Full Peak List` with the subtitle `Updates the Tassy Full Peak List to include peaks from all other peak lists`.
9. The explicit update action must use the same confirm-and-result pattern as `Recalculate Track Statistics`.
10. The explicit update result dialog must display added and updated counts, with copy that makes each count clear.
11. `Tassy Full` remains editable, but automatic sync only adds or updates peaks; deletions must be done by direct edits to `Tassy Full` and are temporary, so a later successful refresh may restore those peaks.
12. The sync helper must return a result object describing added and updated counts.
13. The provider/orchestrator that calls the sync helper must use the returned result to invalidate peak-list consumers and reconcile any active selection after every successful automatic refresh.
14. The provider/orchestrator that runs the Settings rebuild must also invalidate peak-list consumers and reconcile any active selection after a successful rebuild.

**Error Handling:**
15. Malformed source peak-list JSON must be skipped without crashing the app.
16. A sync failure from the explicit Settings action must show a failure dialog and must not partially update the target list.

**Edge Cases:**
17. A peak that appears in multiple source lists with different points uses the highest points value.
18. An empty source union leaves `Tassy Full` unchanged unless the user explicitly edits it.
19. Peaks removed from source lists are not auto-deleted from `Tassy Full`.

**Validation:**
20. Add stable selectors for the new Settings flow: `Key('update-tassy-full-peak-list-tile')`, `Key('update-tassy-full-confirm')`, `Key('update-tassy-full-cancel')`, and `Key('update-tassy-full-result-close')`.
</requirements>

<boundaries>
Edge cases:
- `Tassy Full` is special and must never be included as an input source when refreshing itself.
- Direct edits to `Tassy Full` are allowed, and they are the only way to remove peaks from `Tassy Full`.
- Source lists may be empty, missing, or partially malformed.

Error scenarios:
- If a source list cannot be decoded, ignore that list and continue with the remaining valid lists.
- If the explicit update cannot complete, keep the existing target data and surface the failure in the result dialog path.
- Automatic sync after source edits is best-effort; if it fails, the source edit remains committed and `Tassy Full` may stay stale until the next successful refresh.
- The explicit Settings refresh is all-or-nothing.

Limits:
- No ObjectBox schema changes.
- No SharedPreferences or file-backed persistence for this feature.
- No new global state layer.
</boundaries>

<implementation>
Create a small sync helper beside the peak-list repository, for example `./lib/services/tassy_full_peak_list_sync_service.dart`, and use it as the single source of truth for the derived list calculation.

Add a separate internal write path for `Tassy Full`, for example an internal repository or storage method that bypasses the normal mutation hooks. The sync helper must use that internal path so its writes do not recurse back into sync.

Wire the helper into the existing mutation paths:
- `./lib/services/peak_list_repository.dart`
- `./lib/services/peak_list_import_service.dart`
- any existing source-list mutation flow that saves,  adds,  or updates peak-list items

Do not make automatic deletions from source changes; the sync helper may add new peaks and update points, but direct edits are the only path that may remove peaks from `Tassy Full`.

Update `./lib/screens/settings_screen.dart` to add the new Settings tile, confirmation dialog, and completion/failure dialogs using the existing dialog helpers.

Keep the implementation minimal:
- Reuse existing repository and dialog patterns.
- Avoid introducing another persistence abstraction.
- Avoid duplicating the union/dedupe logic in multiple screens or services.
</implementation>

<stages>
Phase 1: Implement the sync contract and add unit coverage for union, dedupe, highest-points selection, ordering, missing-target creation, malformed-source skipping, the internal non-recursive write path, and the result object shape.

Phase 2: Wire best-effort automatic refresh into all source-list mutation paths and verify the existing add/update/import flows still succeed while keeping `Tassy Full` current.

Phase 3: Add the Settings tile, confirmation dialog, and result/failure dialogs, then verify the explicit refresh path uses the same reconciliation logic and is all-or-nothing.

Phase 4: Add or update robot/widget journey coverage for the Settings action and the source-list mutation flows that indirectly keep `Tassy Full` in sync.
</stages>

<validation>
Use vertical-slice TDD: write one failing test at a time, make it pass with the smallest implementation, then refactor.

Logic and service coverage:
- Unit tests must cover the sync helper or repository contract for unioning source lists, deduping by `peakOsmId`, highest-points selection, deterministic ordering, target creation, the internal non-recursive write path, and the result object shape.
- Unit tests must cover malformed source payload skipping and empty-source behavior.
- If the helper is injected, keep the seam deterministic and use in-memory repository/storage fakes.

Widget coverage:
- Add widget tests for the new Settings tile, confirm dialog, result dialog, and failure dialog.
- Verify the completion dialog shows added and updated counts.
- Verify the new tile is disabled or busy only when the same settings action pattern requires it; otherwise keep it tappable like the recalculate action.

Robot coverage:
- Add a robot-driven journey for opening Settings, tapping `Update Tassy Full Peak List`, confirming, and observing the result dialog.
- Extend a peak-list journey to prove a non-`Tassy Full` add/update/import path triggers best-effort refresh.

Deterministic seams:
- Use `PeakListRepository.test(InMemoryPeakListStorage(...))` for sync logic tests.
- Use a fake CSV loader for import-path tests.
- Reuse the existing confirmation/result dialog helpers so the UI path stays stable.

Baseline automated coverage outcomes:
- Logic/business rules: yes.
- UI behavior: yes.
- Critical user journeys: yes.
</validation>

<done_when>
1. `Tassy Full` stays synchronized with all other peak lists.
2. The Settings screen includes the new update action and confirmation/result dialogs.
3. Duplicate peaks across lists use the highest points value.
4. Source-list add/remove/import flows keep `Tassy Full` current.
5. Automated tests cover the sync logic, Settings UI, and the critical update journey.
</done_when>
