<goal>
Add inline peak metadata editing to the map screen peak info popup so common fixes can be completed without leaving the map.
Keep full-database editing available through ObjectBox Admin for broader changes.

This matters because the current popup exposes an edit affordance that jumps away from the map, even for small corrections such as fixing a peak name, height, or marker-based location. The new flow should make quick edits fast while preserving the existing admin workflow for advanced edits.
</goal>

<background>
Tech stack: Flutter, Riverpod, GoRouter, ObjectBox.

Current map popup behavior:
- `@lib/screens/map_screen_panels.dart` renders `PeakInfoPopupCard` and currently shows read-only peak content with a header edit icon.
- `@lib/screens/map_screen.dart` wires the popup edit icon to `setObjectBoxAdminPendingPeakId(content.peak.id)` and `context.goNamed('objectboxAdmin')`.

Current peak persistence and refresh behavior:
- `@lib/services/peak_repository.dart` provides `saveDetailed` for peak writes.
- `@lib/providers/map_provider.dart` provides `reloadPeakMarkers`, keeps the current popup content in sync, and stores the current selected marker location.

Current coordinate validation and conversion behavior:
- `@lib/services/peak_admin_editor.dart` already contains the canonical peak coordinate validation and MGRS conversion rules used by ObjectBox Admin.

Current ObjectBox Admin behavior:
- `@lib/providers/objectbox_admin_provider.dart` already supports a pending peak id handoff into the admin screen.
- `@lib/screens/objectbox_admin_screen.dart` and `@lib/screens/objectbox_admin_screen_controls.dart` own entity selection, search, row selection, and details display.
- `@lib/screens/objectbox_admin_screen_details.dart` owns peak edit mode inside ObjectBox Admin.

Existing test patterns to follow:
- `@test/services/peak_admin_editor_test.dart`
- `@test/widget/map_screen_peak_info_test.dart`
- `@test/robot/peaks/peak_info_robot.dart`
- `@test/robot/objectbox_admin/objectbox_admin_robot.dart`
</background>

<user_flows>
Primary flow:
1. User opens a peak info popup from the map.
2. User taps the popup edit icon.
3. If the popup is in transient hover mode, it is immediately converted to pinned mode before any editable state is shown.
4. The popup enters an inline edit mode instead of navigating away.
5. User edits the peak name and/or height.
6. User optionally taps the move-to-marker action to copy the current marker location into the peak draft, recalculating latitude, longitude, and MGRS-derived fields.
7. User taps Save.
8. The popup shows a temporary `Saving...` state while persistence is in progress.
9. The peak is persisted, peak markers are reloaded, `sourceOfTruth` is stamped to `HWC`, `verified` is set to `true`, and the popup stays open showing refreshed saved content.

Alternative flows:
- User opens the popup, enters inline edit mode, and taps Cancel. All draft changes are discarded and the popup returns to read-only mode.
- User opens the popup and taps `Edit in Peak Admin`. The app navigates to ObjectBox Admin, opens the `Peak` entity data view, keeps the matching peak row selected, and prefills the search field with the peak name.
- User opens a transient hover popup and taps edit. The popup becomes pinned first, then enters inline edit mode without closing.
- User opens a popup for a peak while a current marker exists, uses move-to-marker, then continues editing name/height before saving as a single commit.

Error flows:
- User clears the peak name and taps Save: inline validation blocks save and shows the same required-name semantics used by peak editing elsewhere.
- User enters a non-integer height and taps Save: inline validation blocks save and shows integer-only height feedback.
- User taps Save and the repository write fails: the popup remains in edit mode, the draft is preserved, and an inline error message is shown.
- User has no current marker: move-to-marker is visibly unavailable and cannot be triggered.
- User has a current marker outside Tasmania or one that cannot be converted into valid peak coordinates: the move-to-marker action must not silently persist invalid coordinates; the draft remains unchanged and the user receives inline feedback.
</user_flows>

<requirements>
**Functional:**
1. Update `./lib/screens/map_screen_panels.dart` so the popup header edit icon enters a local inline edit mode instead of navigating to ObjectBox Admin.
2. If the popup is currently in `PeakInfoPopupMode.hover`, tapping the edit icon must first convert it to a pinned popup before the inline edit UI is shown.
3. Inline edit mode must allow editing only `name` and `elevation` from the popup. It must not expose broader peak fields such as `osmId`, `altName`, `region`, or direct coordinate text entry.
4. Inline edit mode must use explicit `Save` and `Cancel` controls. No field may persist on blur, submit, or keystroke.
5. Inline edit mode must initialize its draft from the currently displayed peak and preserve all untouched fields when saving, except that a successful popup save must intentionally set `sourceOfTruth` to `Peak.sourceOfTruthHwc` and set `verified` to `true`.
6. Add a new row under the popup title row and above the height row in inline edit mode only. The row must visually show a peak icon, right-arrow icon, and marker icon, with tooltip text `Move Peak to Marker`.
7. The move-to-marker row must be clickable as a single action target, not three unrelated buttons.
8. When move-to-marker is triggered, the popup draft must update the peak latitude and longitude from the current persisted map marker, then recalculate `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` using the same conversion rules already used by peak editing code.
9. Move-to-marker must update the popup draft immediately so the user can review the changed MGRS display before saving.
10. Preserve the existing `peak-info-popup-drop-marker` action in read-only mode. It may be hidden or disabled in inline edit mode, but it must not be removed from the feature set.
11. Add a bottom-of-popup `Edit in Peak Admin` button in read-only mode.
12. `Edit in Peak Admin` must navigate to `./lib/screens/objectbox_admin_screen.dart`, switch the selected entity to `Peak` data view if needed, keep the target peak row selected by id, and prefill the ObjectBox Admin search field with the current peak name.
13. The pending ObjectBox Admin handoff must carry the initial search query into provider state before the first admin data load so the first loaded Peak row set, selected row, and visible search field all reflect the same peak name filter.
14. The same ObjectBox Admin handoff must also work when the admin branch is already mounted and the user navigates back to it from the map. The visible-entry refresh path must consume the pending peak id and pending search query, not just the notifier build path.
15. `Edit in Peak Admin` does not need to auto-enter ObjectBox Admin edit mode. The selected row and search-prefill are sufficient.
16. After a successful inline save, the map popup must remain associated with the same saved peak record and render the updated name, height, and recalculated MGRS values without requiring the user to reopen it. `sourceOfTruth` and `verified` must be updated in storage as specified, but they do not need to be shown in the popup.

**Error Handling:**
17. Inline popup validation for `name` and `elevation` must align with existing peak editing semantics. Reuse existing editor/service rules where practical, but do not introduce popup save assembly that rewrites unrelated fields accidentally.
18. If save fails, show a popup-local error message, keep edit mode active, keep the unsaved draft unchanged, and clear any temporary `Saving...` state.
19. If move-to-marker fails validation or coordinate conversion, do not mutate the popup draft. Surface a popup-local error message and keep the user in edit mode.
20. If the target peak can no longer be found during save refresh, fail safely: do not crash, close the popup only if the existing map refresh logic determines the peak has disappeared, and report the save failure to the user.

**Edge Cases:**
21. The move-to-marker action must use the persisted current marker record as its source of truth. It must not use raw `selectedLocation`, because `selectedLocation` can be set by non-marker flows.
22. The move-to-marker action must be disabled when there is no current persisted marker.
23. Cancel must fully discard unsaved field edits and unsaved move-to-marker coordinate changes.
24. Closing the popup while not editing should continue to work exactly as today.
25. While a save is in progress, Save, Cancel, move-to-marker, `Edit in Peak Admin`, popup-close, and the read-only drop-marker action must be disabled to prevent duplicate writes or silent draft loss.
26. If the current marker location is identical to the current saved peak coordinates, move-to-marker may be treated as a no-op, but it must not create false validation errors.
27. The inline editing layout must continue to fit within the existing popup width and max-height constraints defined by `UiConstants.peakInfoPopupSize`.

**Validation:**
28. Name must be required and trimmed before save.
29. Height must accept blank input or an integer value only, matching existing peak elevation editing semantics.
30. Coordinate recalculation must continue to enforce Tasmania bounds and valid MGRS generation before a move-to-marker draft is accepted.
31. New popup controls and states must expose stable app-owned `Key` selectors for widget and robot tests.
32. Saving state must be visible in the popup, with temporary `Saving...` feedback or equivalent progress affordance while persistence is in flight.
</requirements>

<boundaries>
Edge cases:
- Unsaved admin handoff: keep `Edit in Peak Admin` out of inline edit mode, or otherwise disable it there, so navigation never silently discards a dirty inline draft.
- Read-only data preservation: inline popup save must not rewrite unrelated peak fields beyond the intentional `sourceOfTruth = HWC` and `verified = true` stamp.
- Height formatting: saved heights should continue to display through the existing `formatElevation` UI path.
- Marker provenance: use the app's current persisted marker record, not raw `selectedLocation`, a transient hover point, or a tap-derived selection.
- Existing marker affordance: keep `peak-info-popup-drop-marker` available in read-only mode.

Error scenarios:
- Repository write throws: keep draft, show inline error, do not navigate.
- Marker missing: action disabled, tooltip or helper text still explains the purpose.
- Marker outside Tasmania: reject the move with inline feedback and no draft mutation.
- MGRS conversion throws: reject the move with inline feedback and no draft mutation.

Limits:
- Scope is limited to popup editing of `name`, `elevation`, and marker-based coordinate relocation.
- Direct popup editing of `altName`, `osmId`, `region`, verification flags, or raw coordinate text entry is out of scope.
- Auto-opening ObjectBox Admin directly in edit mode is out of scope for this slice.
</boundaries>

<implementation>
Modify these existing files:
- `./lib/screens/map_screen_panels.dart`
- `./lib/screens/map_screen.dart`
- `./lib/providers/objectbox_admin_provider.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- `./lib/screens/objectbox_admin_screen_controls.dart`
- `./lib/services/peak_admin_editor.dart` only if a small reusable helper is needed to share validation / coordinate recalculation logic with the popup flow.

Create additional test files as needed, likely under:
- `./test/widget/`
- `./test/services/`
- `./test/robot/peaks/`
- `./test/robot/objectbox_admin/`

Implementation expectations:
- Keep the popup edit implementation minimal. Prefer extending the existing popup card with a contained edit-state widget rather than creating a new screen or large new abstraction layer.
- When edit is triggered from a hover popup, transition the underlying `mapProvider` popup mode to `PeakInfoPopupMode.pinned` through the existing popup state flow before showing edit controls.
- Reuse existing persistence (`PeakRepository.saveDetailed`) and refresh (`mapProvider.reloadPeakMarkers`) flows.
- Reuse or extract small helpers from `PeakAdminEditor` only for narrow validation and marker-to-peak coordinate recalculation so popup and admin editing do not drift. Do not reuse `PeakAdminEditor.validateAndBuild()` directly for popup save payload construction.
- Build the popup save result from the existing peak record plus the edited fields, then intentionally stamp `sourceOfTruth = Peak.sourceOfTruthHwc` and `verified = true` on successful save.
- Extend the existing ObjectBox Admin pending-selection handoff to carry the peak name search-prefill as well as the selected peak id, and make that handoff consumable from both initial notifier build and already-mounted admin re-entry refresh.
- Add or expose a notifier/helper for retrieving the persisted current marker so popup relocation logic does not depend on raw `selectedLocation`.
- Add a stable key for the ObjectBox Admin search field if it does not already exist, because the admin deep-link journey depends on asserting the prefilled search state.
- Add stable keys for inline popup edit controls, including at minimum the edit mode root, name field, elevation field, move-to-marker row, save button, cancel button, error text, and `Edit in Peak Admin` button.
- Add an explicit visible save-progress affordance in the popup, such as a busy Save button or inline `Saving...` label.

Avoid:
- Duplicating coordinate validation logic in a map-screen-only utility.
- Persisting partial edits before Save.
- Introducing a general-purpose deep-link framework when a small pending-admin-handoff extension is sufficient.
</implementation>

<stages>
Phase 1: Popup inline edit state and save flow.
- Add inline edit UI for name and height, including hover-to-pinned conversion when edit is triggered from a transient popup.
- Wire Save/Cancel and repository persistence.
- Verify that successful saves refresh the popup content in place and stamp HWC / verified metadata as specified.

Phase 2: Marker relocation within popup editing.
- Add the move-to-marker row and disabled state.
- Reuse shared validation/conversion logic for marker-based coordinate draft updates.
- Verify draft update, cancel rollback, and invalid-marker handling.

Phase 3: ObjectBox Admin handoff polish.
- Add the bottom `Edit in Peak Admin` button.
- Extend pending admin handoff to carry peak id plus search text.
- Verify the admin screen opens on Peak data view with the row selected and search field prefilled on both first branch entry and return to an already-mounted admin branch.
</stages>

<illustrations>
Desired behavior example:
- User opens `Bonnet Hill` popup.
- User taps edit.
- If the popup was hover-only, it becomes pinned first.
- Popup shows editable `Name` and `Height` fields, a disabled or enabled `Move Peak to Marker` row depending on marker state, and Save/Cancel.
- User changes `Bonnet Hill` to `Bonnet Hill Summit`, taps Save, sees `Saving...`, and the popup stays open showing the new name.

Desired marker move example:
- User already has a current marker placed nearby.
- User opens the popup, taps edit, taps `Move Peak to Marker`, sees the MGRS line change immediately, then taps Save.

Counter-example:
- Tapping the header edit icon should not immediately navigate away from the map anymore.
- Tapping `Edit in Peak Admin` should not silently discard dirty inline edits.
</illustrations>

<validation>
Require baseline automated coverage for logic, UI behavior, and critical journeys.

TDD expectations:
- Implement in vertical slices, one failing test at a time: hover-popup edit pins then enters edit mode -> popup save success -> popup validation failure -> move-to-marker success -> move-to-marker invalid marker -> admin handoff.
- Each slice must follow RED -> GREEN -> REFACTOR before the next slice begins.
- Tests must target public behavior through services, widgets, and robot flows, not private state.

Unit/service coverage:
- Extend `./test/services/peak_admin_editor_test.dart` if shared helpers are added there.
- Otherwise add a focused service-level test file for any extracted popup-edit helper.
- Cover name trimming, blank-name rejection, integer-only elevation parsing, marker-to-MGRS recalculation, Tasmania bounds rejection, and failed conversion behavior.

Widget coverage:
- Add or extend a `./test/widget/` map-screen popup test file for screen-level behavior.
- Verify tapping edit from a hover popup pins it before inline editing begins.
- Verify the hover-to-pinned conversion updates provider popup mode, not just local widget state.
- Verify the popup enters edit mode from the header edit icon.
- Verify Save persists updated name/height and returns to read-only display.
- Verify successful popup save stamps `sourceOfTruth` to `HWC` and `verified` to `true`.
- Verify Cancel discards draft text and draft coordinate changes.
- Verify move-to-marker is disabled with no marker.
- Verify inline error text appears for invalid name/height and repository save failure.
- Verify the existing read-only drop-marker action still exists and is unavailable during inline edit mode.
- Verify `Edit in Peak Admin` button presence in read-only mode and absence or disabled state during inline editing.

Robot-driven journey coverage:
- Extend `./test/robot/peaks/peak_info_robot.dart` with selectors and helper methods for inline editing.
- Add a peak popup journey test, likely `./test/robot/peaks/peak_info_edit_journey_test.dart`, that covers the critical happy path: open popup -> edit name/height -> optionally move to marker -> save -> confirm refreshed popup content and the visible saving state.
- Add or extend an ObjectBox Admin robot journey test to cover the deep-link handoff: open `Edit in Peak Admin` from a popup -> confirm admin entity is `Peak`, the initial admin row load is filtered by the carried search query, the target row is selected, and the search field is prefilled with the peak name.
- Add coverage for the same admin deep-link behavior when the ObjectBox Admin branch is already mounted before the user leaves the map.

Stable selectors required:
- Reuse existing keys such as `peak-info-popup` and `peak-info-popup-edit`.
- Add keys for new popup edit controls, for example `peak-info-popup-edit-form`, `peak-info-popup-name`, `peak-info-popup-elevation`, `peak-info-popup-move-to-marker`, `peak-info-popup-save`, `peak-info-popup-cancel`, `peak-info-popup-error`, and `peak-info-popup-edit-admin`.
- Add a stable search-field key to ObjectBox Admin, for example `objectbox-admin-search-field`, if none exists.

Deterministic seams:
- Use the existing test harnesses such as `TestMapNotifier` and the robot harness structure already present under `./test/harness/` and `./test/robot/`.
- Keep admin handoff state deterministic and reset-on-consume so tests can assert initial load behavior without leaking state across cases.
- If repository save failure coverage requires injection, use a fake repository override rather than mocking widget internals.

Default test split:
- Robot tests: critical cross-screen happy paths and admin handoff journeys.
- Widget tests: popup-level edge cases, disabled states, validation errors, cancel behavior, and failure messaging.
- Unit tests: coordinate conversion / validation logic and any extracted helper behavior.
</validation>

<done_when>
1. The map peak info popup supports inline editing of peak name and height with explicit Save and Cancel.
2. Tapping edit on a hover popup converts it to pinned mode in shared popup state before inline editing begins, so the popup no longer behaves like a transient hover popup while editing.
3. The popup includes a single move-to-marker action row in inline edit mode that updates peak draft coordinates from the persisted current marker and refreshes visible MGRS data before save.
4. Move-to-marker is disabled without a persisted marker and rejects invalid marker-derived coordinates without mutating the draft.
5. The existing read-only `peak-info-popup-drop-marker` action still works and is not exposed as an active action during inline edit mode.
6. Successful popup saves persist through the existing peak repository flow, stamp `sourceOfTruth = HWC` and `verified = true`, show visible saving feedback, and refresh the open popup content in place without adding new HWC/verified display rows to the popup.
7. The popup includes an `Edit in Peak Admin` button that opens ObjectBox Admin on the Peak entity with the initial row load filtered by the carried search query, the row selected, and the search field prefilled with the peak name on both first load and already-mounted admin re-entry.
8. All new controls expose stable test keys.
9. Automated coverage exists for shared logic, popup widget behavior, and the critical popup-edit / admin-handoff journeys.
</done_when>
