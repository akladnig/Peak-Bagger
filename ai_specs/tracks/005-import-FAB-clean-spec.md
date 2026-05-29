<goal>
Remove the map-screen track import FAB and make Settings the only place users manage track rebuild or repair actions.

This matters because the current map FAB triggers a parallel manual rescan path with its own snackbar and test scaffolding, while the intended product behavior is to manage track rebuild and repair from Settings. After this cleanup, `Reset Track Data` remains the only user-facing import or re-import action, and `Recalculate Track Statistics` remains a separate non-destructive repair action. Startup-warning flows may still leave both Settings actions valid, but recovery-state flows must not imply that recalculation can clear recovery unless implementation changes make that true. The change should reduce confusion, remove duplicate UI, and leave one clear Settings-led maintenance model.
</goal>

<background>
The app is a Flutter application using Material, Riverpod, and GoRouter.

Relevant files to examine:
- `@ai_specs/005-import-FAB-clean.md`
- `@lib/widgets/map_action_rail.dart`
- `@lib/screens/settings_screen.dart`
- `@lib/router.dart`
- `@lib/providers/map_provider.dart`
- `@lib/services/gpx_importer.dart`
- `@test/gpx_track_test.dart`
- `@test/widget/gpx_tracks_shell_test.dart`
- `@test/widget/gpx_tracks_recovery_test.dart`
- `@test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `@test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- `@test/robot/gpx_tracks/recovery_journey_test.dart`
- `@test/robot/gpx_tracks/recovery_robot.dart`
- `@test/harness/test_map_notifier.dart`

Verified current behavior:
- `Key('import-tracks-fab')` in `./lib/widgets/map_action_rail.dart` is the only production UI entry point that calls `MapNotifier.rescanTracks()`.
- `consumeTrackSnackbarMessage()` is only consumed in the map branch of `./lib/router.dart`, but the pending snackbar state it consumes is currently populated by both manual rescan and `resetTrackData()` because both use `_importTracks()`.
- Startup backfill warning snackbars via `consumeStartupBackfillWarningMessage()` are a separate path and must remain.
- Recovery guidance via `hasTrackRecoveryIssue`, `consumeRecoverySnackbarSignal()`, and `Key('open-track-recovery-settings')` is a separate path and must remain.
- Settings already exposes `Reset Track Data` with confirmation plus result or failure dialogs, `Recalculate Track Statistics` with result or failure dialogs, and inline status surfaces. Startup-warning detail is mirrored through `trackImportError`, while reset or recalc summaries use `trackOperationStatus` and `trackOperationWarning`.
- `TrackImportResult.warning` is produced in `./lib/services/gpx_importer.dart` and is currently gated by the importer `surfaceWarnings` flag, so snackbar cleanup must not accidentally suppress reset warnings shown in Settings dialogs.

Constraint decisions for this spec:
- Keep `Reset Track Data` in Settings as the only user-facing track import or re-import action.
- Keep `Recalculate Track Statistics` in Settings as a separate valid non-destructive repair action.
- Keep startup-warning copy generic where either Settings action may remain valid depending on the user's need.
- Keep recovery guidance routed to Settings without implying that `Recalculate Track Statistics` can clear recovery unless implementation changes explicitly make that true.
- Keep Settings dialogs and inline status or warning presentation.
- Remove dead code aggressively where it only exists for the deleted map FAB or manual rescan journey.

Output path: `./ai_specs/005-import-FAB-clean-spec.md`
</background>

<discovery>
Verified by code inspection:
- `MapNotifier.rescanTracks()` has one remaining production caller: the map-screen `import-tracks-fab`.
- `consumeTrackSnackbarMessage()` has one remaining production consumer: the map branch in `./lib/router.dart`, and the pending message it consumes is currently written by both manual rescan and Settings reset.
- The manual-rescan snackbar tests live primarily in `./test/widget/gpx_tracks_shell_test.dart` and must be removed or rewritten.
- Recovery-oriented tests still reference the deleted selector in `./test/widget/gpx_tracks_recovery_test.dart`, `./test/robot/gpx_tracks/gpx_tracks_robot.dart`, `./test/robot/gpx_tracks/recovery_robot.dart`, and `./test/robot/gpx_tracks/recovery_journey_test.dart` and must be updated.

Patterns to preserve:
- Recovery and startup warning flows still direct users to Settings.
- `Reset Track Data` continues to use confirmation plus result or failure dialogs.
- Settings continues showing `trackImportError` for startup-warning detail, and `trackOperationStatus` or `trackOperationWarning` for reset and recalc summaries.
- Recovery-state fixes remain reset-led unless future implementation explicitly extends recalculation to clear `hasTrackRecoveryIssue`.
- When `hasTrackRecoveryIssue` is true and the user opens Settings, the UI must make it explicit that `Reset Track Data` is the action that clears recovery in the current implementation.
- When `hasTrackRecoveryIssue` and startup backfill detail are both present, the Settings screen must preserve both pieces of information, but the recovery guidance takes precedence for the recommended action.
</discovery>

<user_flows>
Primary flow:
1. User needs to rebuild or re-import tracks.
2. User opens `Settings`.
3. User taps `Reset Track Data`.
4. User sees the existing destructive confirmation dialog.
5. On confirm, the app resets stored track data and rebuilds from disk.
6. On success, the app keeps the existing success dialog and returns rebuilt tracks in a map-visible state when the user returns to the map, unless recovery safeguards still apply.
7. On failure, the app shows the existing failure dialog in Settings.

Alternative flows:
- Startup warning path: if bagged-history backfill is stale on startup, the startup-warning snackbar sends the user to Settings. That shell entry copy remains generic because both `Reset Track Data` and `Recalculate Track Statistics` can remain valid depending on whether the user needs a full re-import or a non-destructive repair.
- Recovery banner path: if the map is in track recovery mode, the banner or CTA still routes to Settings instead of offering a map-screen import action. This flow remains reset-led unless implementation work explicitly makes recalculation sufficient to clear `hasTrackRecoveryIssue`, and Settings must show explicit recovery copy that points the user to `Reset Track Data`.
- Combined-state path: if `trackImportError` startup backfill detail and recovery state are both present, Settings shows both the startup detail and the explicit recovery guidance, but the recovery guidance is the recommended action because reset clears recovery while recalc does not guarantee that outcome.
- Recalculate path: `Recalculate Track Statistics` remains separate from `Reset Track Data` and should continue working unchanged.

Error flows:
- Reset failure: Settings shows the existing failure dialog backed by `trackImportError`.
- Missing or unreadable GPX source files during reset: Settings shows the resulting warning or reduced import counts in the existing result surfaces.
- User cancels the reset confirmation: no track data changes occur and no extra status UI appears.
</user_flows>

<requirements>
**Functional:**
1. Remove the `Import track` FAB from `./lib/widgets/map_action_rail.dart` so the map screen no longer offers a direct track import or rescan action.
2. Remove the stable selector `Key('import-tracks-fab')` from production UI because the control itself is being deleted.
3. Preserve `Reset Track Data` in `./lib/screens/settings_screen.dart` as the only user-facing entry point for resetting or re-importing tracks.
4. Preserve the existing `Reset Track Data` confirmation dialog, success dialog, and failure dialog behavior.
5. Preserve `Recalculate Track Statistics` in `./lib/screens/settings_screen.dart` as a separate valid non-destructive repair action.
6. Preserve existing Settings-side display of track status, warning, and error text where it is still used: `trackImportError` for startup-warning detail, and `trackOperationStatus` or `trackOperationWarning` for reset or recalculation flows.
7. Preserve startup-warning guidance that routes users into Settings without prescribing a single action when both reset and recalc remain valid for that warning state.
8. Preserve recovery guidance that routes users from shell or map recovery messaging into Settings without implying that recalculation alone clears recovery unless code changes explicitly make that true.
9. When `hasTrackRecoveryIssue` is true and the user is on `./lib/screens/settings_screen.dart`, show explicit in-Settings recovery copy that directs the user to `Reset Track Data` as the current recovery-clearing action.
10. The explicit recovery guidance must expose a stable selector `Key('track-recovery-settings-guidance')` so widget and robot tests can target it deterministically.
11. Merge the existing generic recovery text into the explicit recovery guidance block rather than rendering two separate recovery messages in Settings.
12. Place the explicit recovery guidance adjacent to or immediately above `Reset Track Data`, not below unrelated status or warning text.
13. In Settings, “startup backfill detail” refers to the existing `trackImportError` surface for stale bagged-history rebuild failures, not a duplicated copy of the startup snackbar message.
14. The Settings startup-detail surface must expose a stable selector `Key('track-startup-backfill-detail')` so widget tests can verify startup-warning and combined-state detail deterministically.
15. When `hasTrackRecoveryIssue` and `trackImportError` startup backfill detail are both present in Settings, show both pieces of information, but make the recovery guidance the recommended action because reset clears recovery while recalc may still only address stale bagged-history state.
16. After a successful `resetTrackData()` operation, `MapState.showTracks` must be `true` when rebuilt tracks exist and `hasTrackRecoveryIssue` is `false`.
17. After a successful `Reset Track Data` operation, rebuilt tracks must therefore be visible automatically when the user returns to the map if tracks exist and `hasTrackRecoveryIssue` is false.
18. Remove production code that exists only to support the deleted manual rescan flow, including `MapNotifier.rescanTracks()`, `consumeTrackSnackbarMessage()`, the shared pending snackbar state currently populated by manual rescan and reset, and the corresponding shell wiring in `./lib/router.dart`.
19. Decouple importer warning generation for `Reset Track Data` from shell snackbar delivery so `TrackImportResult.warning` remains available to the Settings result dialog even after `_pendingTrackSnackbarMessage` and `consumeTrackSnackbarMessage()` are removed.

**Error Handling:**
20. If `Reset Track Data` fails, the Settings flow must continue surfacing the failure through the existing failure dialog and `trackImportError` state.
21. Removing the map FAB must not remove startup backfill warnings or recovery guidance that are still relevant to non-rescan failure states.
22. If code deletion reveals shared logic between manual rescan and Settings reset, keep the shared logic needed by Settings and delete only the manual-rescan-specific branch.
23. If recovery safeguards still apply after reset, do not auto-show tracks; preserve the existing recovery protections and guide the user through Settings.
24. After the shared snackbar path is removed, a successful Settings reset must not produce a shell snackbar when the user navigates back to the map.
25. Deleting the shared snackbar delivery path must not suppress `TrackImportResult.warning` content that is still needed for the `Reset Track Data` result dialog in Settings.

**Edge Cases:**
26. Users with no stored tracks must still be able to rebuild or import tracks through Settings only. No replacement map-surface discoverability affordance is required; that reduced discoverability is an intentional product tradeoff for this cleanup.
27. Users in recovery mode must not see any remaining map-screen affordance that implies repair can happen from the map screen, and must see explicit in-Settings recovery guidance pointing to `Reset Track Data`.
28. When recovery state and `trackImportError` startup backfill detail coexist, the Settings screen must keep both visible without presenting conflicting recommended actions.
29. Rapid navigation between map and Settings must not produce stale snackbars from the deleted shared import or reset notification path.
30. Concurrent track work already in progress must continue disabling or protecting Settings actions as today; removal of the FAB must not weaken those guards.

**Validation:**
31. Automated coverage must prove that the map screen no longer renders `import-tracks-fab`.
32. Automated coverage must prove that the Settings reset journey still works end-to-end through confirmation and result or failure dialogs.
33. Automated coverage must prove that shell-level snackbar assertions tied to the deleted shared import or reset notification path are removed or updated.
34. Automated coverage must explicitly prove that a successful Settings reset no longer produces a shell snackbar after navigating back to the map.
35. Automated coverage must prove that when `hasTrackRecoveryIssue` is true and the user opens Settings, explicit recovery guidance is visible, uses `Key('track-recovery-settings-guidance')`, and points to `Reset Track Data`.
36. Automated coverage must prove that when recovery state and `trackImportError` startup backfill detail coexist, both are visible and the recovery guidance remains the recommended action.
37. Automated coverage must prove that opening Settings from the startup backfill warning still shows the `track-startup-backfill-detail` surface backed by `trackImportError`.
38. Automated coverage must prove that for startup-warning flows without `hasTrackRecoveryIssue`, both `reset-track-data-tile` and `recalculate-track-statistics-tile` are visible, `track-startup-backfill-detail` is present, and `track-recovery-settings-guidance` is absent.
39. Remove dead test seams created only for the deleted manual rescan path, including fake notifier rescan behavior, snackbar-consumption helpers, and reset fakes that still encode the old hidden-after-reset behavior.
40. Automated coverage must include provider-level assertions for notifier cleanup around `resetTrackData()` and `recalculateTrackStatistics()` so snackbar-path deletion is verified below the UI layer.
</requirements>

<boundaries>
Edge cases:
- First-time user: there is no map import action; Settings remains the only place to trigger track reset or rebuild, and no compensating map CTA is required.
- Returning user with existing tracks: deleting the FAB must not alter stored tracks, selected tracks, or map visibility state by itself.
- Recovery-state user: the map continues to warn and route toward Settings; no alternate repair control remains on the map action rail.
- Successful reset without recovery issue: the app returns rebuilt tracks in a visible state when the user returns to the map.
- Combined startup-warning and recovery state: both pieces of information remain visible in Settings, but the recovery guidance is the recommended action.
- Cancelled reset: the confirmation dialog closes cleanly and leaves state unchanged.

Error scenarios:
- Old shared snackbar code remains wired after the FAB is deleted: remove it if no remaining production caller exists.
- Settings reset still triggers a shell snackbar after the shared pending snackbar path is removed: treat this as a regression and cover it explicitly in tests.
- Tests still search for `import-tracks-fab`: update or delete those tests so they assert the new canonical Settings-led behavior instead.
- Shared notifier state is still used by `Reset Track Data` or `Recalculate Track Statistics`: keep that shared state and remove only unreachable manual-rescan entry points.

Limits:
- Do not add a replacement map action for importing tracks.
- Do not redesign the Settings screen beyond what is necessary to preserve `Reset Track Data` as the canonical import or re-import entry point.
- Do not introduce new import services, file pickers, or background workflows.
- Do not add a compensating empty-state or map-surface CTA for zero-track discoverability as part of this cleanup.
- Do not remove startup backfill or recovery messaging unless code inspection proves it is dead after the cleanup.
</boundaries>

<implementation>
Modify or delete as needed:
- `./lib/widgets/map_action_rail.dart` to remove the `Import track` FAB and any spacing or layout code that only existed for it.
- `./lib/router.dart` to remove the map-branch snackbar consumer tied to the shared pending import or reset snackbar path, while preserving startup-backfill and recovery messaging.
- `./lib/providers/map_provider.dart` to remove `rescanTracks()`, shared pending import or reset snackbar state, and any other rescan-only notifier plumbing, while keeping the surviving reset and recalc paths correct, making `resetTrackData()` set `showTracks` consistently with the new visible-after-reset contract, and decoupling importer warning generation from shell snackbar delivery.
- `./lib/screens/settings_screen.dart` only as needed to preserve the canonical import or re-import flow, any still-used status or warning presentation, the existing `recalculate-track-statistics-tile` selector for startup-warning flows, the `track-startup-backfill-detail` surface backed by `trackImportError`, and the explicit recovery guidance shown when `hasTrackRecoveryIssue` is true adjacent to `Reset Track Data`.
- `./test/gpx_track_test.dart` to add or update provider-level coverage for notifier cleanup after shared snackbar deletion.
- `./test/widget/gpx_tracks_shell_test.dart` to remove manual-rescan snackbar coverage and replace it with absence-of-FAB and surviving Settings/startup-warning assertions.
- `./test/widget/gpx_tracks_recovery_test.dart` to update expectations now that the map no longer shows an import FAB.
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart` and `./test/robot/gpx_tracks/recovery_robot.dart` to remove deleted selectors and helper methods, including the `importFab` getters that currently point at `Key('import-tracks-fab')`.
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart` and `./test/robot/gpx_tracks/recovery_journey_test.dart` to preserve Settings-led journeys and remove deleted map-FAB assertions.
- `./test/harness/test_map_notifier.dart` to remove fake rescan behavior and manual-rescan snackbar plumbing, and to update fake `resetTrackData()` so it matches the new visible-after-reset contract.

Patterns to use:
- Prefer the smallest correct cleanup.
- Delete dead selectors, helpers, and fake behavior instead of leaving placeholder test seams behind.
- Keep recovery and reset behavior centered on existing Settings dialogs and state surfaces.
- Keep startup-backfill warning behavior centered on `consumeStartupBackfillWarningMessage()`; do not fold it into the deleted shared import or reset snackbar path.
- Keep startup-warning copy generic only where both reset and recalc remain valid.
- Keep recovery guidance routed to Settings, but do not imply that recalculation alone clears `hasTrackRecoveryIssue` unless that behavior is explicitly added.
- Preserve importer-generated `TrackImportResult.warning` content for reset flows even after the shared snackbar path is removed.
- Add and preserve a stable selector `Key('track-recovery-settings-guidance')` for the in-Settings recovery guidance so widget and robot tests can target it deterministically.
- Add and preserve a stable selector `Key('track-startup-backfill-detail')` for the Settings startup-detail surface backed by `trackImportError` so widget tests can target it deterministically.

Avoid:
- Do not leave an empty gap in tests where the removed flow used to be; replace it with assertions about the surviving canonical flow.
- Do not keep notifier APIs "for later" if they no longer have a real caller.
- Do not delete shared status or warning state just because part of it was previously exercised by the removed rescan flow.
</implementation>

<stages>
Stage 1:
- Remove the map-screen import FAB and any direct manual rescan UI path.
- Verify the map action rail layout still looks intentional on desktop and mobile widths.

Stage 2:
- Trace and remove production-side dead code created by the deletion, especially the shared import or reset snackbar channel and rescan notifier seams.
- Verify surviving Settings reset, recalc, and recovery flows still compile and behave correctly.

Stage 3:
- Update provider, widget, and robot tests to align with the Settings-led flow.
- Verify deleted selectors and helper methods are removed rather than left unused.

Stage 4:
- Run the targeted test lanes, then broader tests if practical.
- Verify no stale manual-rescan behavior remains in code or coverage.
</stages>

<illustrations>
Desired:
- The map screen shows search, basemap, location, grid, tracks, peaks, info, and other surviving actions, but no track import FAB.
- A user who needs to re-import tracks goes to Settings and uses `Reset Track Data`.
- A user who needs a non-destructive repair can still use `Recalculate Track Statistics`.
- Shell startup-warning and recovery entry messaging still tell the user to open Settings without prescribing one action.
- Once a recovery user reaches Settings, the in-Settings guidance explicitly points them to `Reset Track Data`.
- When startup backfill detail and recovery state coexist, Settings shows both, but the recovery guidance is the recommended action.

Avoid:
- A hidden but still-wired `import-tracks-fab` selector surviving in tests or production.
- Shell snackbars still announcing results from the deleted shared import or reset notification path after the UI entry point is gone.
- Deleting `trackOperationStatus`, `trackOperationWarning`, or `trackImportError` even though Settings still uses them.
- Removing startup-backfill or recovery-to-Settings messaging just because the unrelated manual-rescan snackbar path was deleted.
- Replacing the deleted FAB with a no-op placeholder.
</illustrations>

<validation>
Automated coverage baseline:
- Logic and business rules: verify dead manual-rescan seams are removed, the shared pending snackbar path is deleted, and shared track state used by Settings reset or recalculation remains intact.
- UI behavior: add or update widget tests to assert the map no longer renders `find.byKey(const Key('import-tracks-fab'))`, that recovery UI no longer expects a disabled import FAB, that explicit recovery guidance appears in Settings when `hasTrackRecoveryIssue` is true, and that startup-backfill warning UI still works.
- Critical journeys: keep coverage for startup-warning guidance that routes users to Settings without prescribing one action, recovery guidance that routes users to Settings while preserving reset-led recovery clearing, combined-state Settings behavior when both startup backfill detail and recovery are present, and `Settings > Reset Track Data` success and failure.

TDD expectations:
- Follow behavior-first RED -> GREEN -> REFACTOR cycles, one failing slice at a time.
- Suggested slice order:
1. Map screen no longer renders the import FAB.
2. Shared import or reset snackbar seams are removed without breaking startup-warning or recovery flows or suppressing importer-generated reset warnings.
3. Settings reset flow still shows confirmation and success dialog, preserves `TrackImportResult.warning` content when present, sets `MapState.showTracks` to `true` when rebuilt tracks exist and no recovery issue remains, and does not produce a shell snackbar when returning to the map.
4. Settings reset failure still shows the failure dialog.
5. Recovery state still routes into Settings and shows explicit copy that points users to `Reset Track Data`.
6. `Recalculate Track Statistics` still remains a valid non-destructive repair path for startup-warning or maintenance flows without being treated as a guaranteed recovery-state fix.
7. Combined startup backfill detail plus recovery state still renders both messages in Settings, with recovery guidance as the recommended action.
- Test through public behavior: visible widgets, keys, dialogs, route changes, and externally observable provider state.
- Prefer fakes such as the existing notifier harness over mocks; mock only true external boundaries if a new seam is unavoidable.
- If strict TDD is impractical for pure dead-code deletion, keep the deletion covered by surrounding widget or robot tests and full compilation or test execution.

Robot coverage expectations:
- Use robot-driven coverage for the surviving critical Settings-led journey, not for the deleted map action.
- Default split:
  - Robot tests: startup-warning path into Settings without prescribing reset, and recovery path into Settings plus `Reset Track Data` confirmation and result where the journey spans multiple screens or shells.
  - Widget tests: absence of the map FAB, screen-level recovery UI changes, reset success and failure dialog states, and preservation of startup-backfill warning UI.
  - Unit tests: notifier cleanup around `resetTrackData()` and `recalculateTrackStatistics()`, especially deletion of the shared snackbar path, the post-reset visible-track state, and the distinction between startup-warning and recovery-state expectations.
- Stable selectors required:
  - Keep `Key('reset-track-data-tile')`
  - Keep `Key('reset-track-data-confirm')`
  - Keep `Key('recalculate-track-statistics-tile')`
  - Keep `Key('open-track-recovery-settings')`
  - Keep `Key('startup-backfill-warning-open-settings')`
  - Add `Key('track-recovery-settings-guidance')`
- Deterministic seams required:
  - Continue using provider overrides and fake notifiers to drive reset success, reset failure, startup warning, and recovery states.
  - Avoid timing-sensitive assertions that depend on deleted snackbar scheduling.
- Explicitly report any residual risk if some old GPX-track tests were primarily validating deleted snackbar plumbing rather than real user value.

Manual verification:
- Run the touched widget and robot tests first.
- Open the map screen and confirm there is no import FAB in the action rail.
- Open Settings and confirm `Reset Track Data` still works through confirmation and result or failure dialogs, and that successful reset returns visible tracks on the map when no recovery issue remains.
- Trigger startup-warning states and confirm they still direct the user to Settings with generic copy that leaves both reset and recalc valid where appropriate.
- Trigger recovery states and confirm they still direct the user to Settings, and that Settings shows explicit copy pointing recovery users to `Reset Track Data` without implying that recalculation alone clears recovery.
- Trigger the combined state where recovery and startup backfill detail coexist and confirm both remain visible in Settings while recovery guidance stays the recommended action.
</validation>

<done_when>
- `./ai_specs/005-import-FAB-clean-spec.md` contains this finalized specification.
- The spec makes it unambiguous that the map-screen import FAB is removed, not stubbed or replaced.
- The spec makes it unambiguous that `Reset Track Data` is the only user-facing import or re-import path, while `Recalculate Track Statistics` remains a valid non-destructive repair path.
- The spec makes it unambiguous that the shared snackbar channel used today by manual rescan and reset is deleted as part of the cleanup.
- The spec defines the post-reset map outcome and the intentional lack of compensating zero-track discoverability UI.
- The spec distinguishes startup-warning guidance from recovery-state guidance and does not overstate what recalculation can fix.
- The spec makes it explicit how recovery users are guided once they arrive in Settings and preserves reset warning content while removing snackbar delivery.
- The spec defines the combined-state behavior when recovery and startup backfill detail coexist and provides a stable selector for the new recovery guidance.
- Remaining user flows, error flows, limits, and validation steps are explicit enough for implementation to proceed without guesswork.
</done_when>
