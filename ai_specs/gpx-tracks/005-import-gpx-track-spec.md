<goal>
Add a selective multi-file GPX import dialog to the target-state `Import Track(s)` FAB on the map screen. The FAB no longer runs a manual folder rescan; instead, users can select one or more GPX files from a picker that starts from the canonical Bushwalking root when available and import them as new tracks without deleting existing data.

Who: Users wanting to add individual GPX tracks from specific files instead of rebuilding all track data
Why: Provides fine-grained control over which tracks get imported, supporting selective track addition workflows
</goal>

<background>
Flutter app with Riverpod, flutter_map, ObjectBox, and existing GPX track functionality. In the current production code, the map import FAB still triggers a folder rescan via `rescanTracks()` in `MapNotifier`; this spec defines the target-state replacement UX.

The UI pattern comes from `peak_list_import_dialog.dart` which uses `PeakListFilePicker` for CSV file selection. A parallel picker needs to be created for GPX files.

Repurposing note:
- The map-screen import FAB is intentionally being repurposed from manual folder rescan to selective GPX file picking.
- `Reset Track Data` in Settings remains unchanged and destructive. It is the only in-scope full rebuild fallback after manual map-screen rescan is removed.

Files to examine:
- @lib/widgets/peak_list_import_dialog.dart - current production reference for the import-dialog UI pattern
- @lib/widgets/map_action_rail.dart - current production reference for the import FAB at line 256-283
- @lib/providers/map_provider.dart - current production reference for track state management (lines 471-600)
- @lib/services/gpx_importer.dart - current production reference for track import logic
- @lib/models/gpx_track.dart - GPX track entity
- @lib/services/peak_list_file_picker.dart - existing file picker to mirror
- @test/widget/peak_lists_screen_test.dart - existing import dialog tests
</background>

<user_flows>
Primary flow:
1. User taps the `Import Track(s)` FAB on the map screen
2. A selective GPX import dialog opens with a `Select GPX Files` action
3. The native file picker opens at the folder resolved by the picker-specific import-root helper, which starts from the canonical Bushwalking root when available and may fall back for dialog usability, and allows one or more `.gpx` files to be selected
4. If files selected, the same import dialog updates in place to show all selected files with editable name fields (one per file), prefilled from a best-effort shared helper that extracts the GPX metadata name and falls back to the basename without surfacing a pre-import row error
5. On confirmation, the dialog submits the full batch to MapNotifier in one operation
6. The app processes every selected file using the same GPX processing pipeline as folder import
7. Valid Tasmanian tracks are added and, after persistence succeeds, their source files may be moved into managed watched storage under `~/Documents/Bushwalking/Tracks/Tasmania` so future reset or rebuild flows preserve them; duplicates, route-only files, non-Tasmanian files, and invalid files are reported in the aggregate batch result while the rest of the batch continues
8. Existing tracks remain unchanged; no existing track rows are replaced or deleted by this feature
9. When the batch finishes, a separate result dialog shows added, unchanged, non-Tasmanian, and error counts while the input dialog remains mounted underneath; after the result dialog closes, the input dialog closes and new tracks become visible on the map

Alternative flows:
- User taps Cancel or outside the dialog before submitting: dialog closes, no action taken
- User selects a single GPX file: the same batch dialog appears with one editable row
- User selects multiple GPX files: batch import flow with rename options for each
- User cancels the native file picker: the import dialog remains open and keeps its current state unchanged
- User selects a file that already exists (same contentHash): that file is counted as unchanged, duplicate feedback is shown in the batch summary, and the remaining files continue processing

Error flows:
- File picker fails (permission denied): show error dialog, then return to the same import dialog so the user can dismiss it or retry
- Invalid GPX file selected: skip the file, count it in `errorCount`, include it in the aggregate batch summary, and continue with other files
- Non-Tasmanian GPX selected: skip and increment nonTasmanianCount, continue with other files
- Route-only GPX selected: leave the file in place, do not import it as a track, count it in `errorCount`, and continue with other files
- Peak correlation fails for an imported track after GPX processing: persist the track without correlated peaks, keep it counted as added, and include an aggregate warning in the result dialog
- Any submitted batch with 0 added: show a completed batch summary with a breakdown of unchanged, non-Tasmanian, and error counts
- Import operation fails before returning a batch result: close the input dialog and show a failure dialog using the existing import-dialog pattern, then clear any selective-import-specific fatal error state after display
</user_flows>

<requirements>
**Functional:**
1. Repurpose the current `Import Track(s)` FAB tap action from `rescanTracks()` to a dialog-based selective GPX import flow
2. Create a new GPX file picker class mirroring `PeakListFilePicker` pattern but for `.gpx` files
3. Allow selection of multiple GPX files in a single picker session
4. Use a shared canonical Bushwalking-root helper (normally `~/Documents/Bushwalking`) for importer storage semantics; importer watched subfolders (`Tracks`, `Tracks/Tasmania`, and `Routes`) are always derived from that canonical root, while the file picker may use a separate picker-specific fallback only for its initial dialog directory
5. Show an import dialog allowing the user to edit the track name for each selected file; prefill each field from a best-effort public/shared name-derivation helper that extracts the GPX metadata name and falls back to the basename without surfacing a pre-import row error
6. Do not show a date field in the dialog; date remains derived internal metadata
7. Extract a public shared helper for track-date derivation and use it wherever selective import and folder import need the same rule set
8. Extract a public/shared name-derivation helper so dialog prefills and importer defaults reuse the same GPX metadata-name plus basename-fallback rule
9. Import selected GPX files through an importer-owned selective-import API that reuses the same processing pipeline as folder import for GPX parsing, repair/processing selection, `processTrack(...)`, `filterConfig`, derived-field application, content-hash detection, and aggregate counting; peak correlation remains provider-owned and runs afterward in `MapNotifier`
10. Existing tracks must NOT be deleted; the selective import feature is additive-only
11. Skip exact `contentHash` duplicates, increment `unchangedCount`, and continue processing the remaining selected files
12. Do not use logical-match replacement by `trackName + trackDate` for this feature
13. Preserve existing importer semantics for non-Tasmanian files: skip them and increment `nonTasmanianCount` instead of `errorCount`
14. Allow duplicate track names in the database when `contentHash` differs
15. Show a separate batch result dialog after import: X added, Y unchanged, Z non-Tasmanian, W errors
16. Set `showTracks = true` only when at least one new Tasmanian track was imported; otherwise preserve the current `showTracks` value
17. Successfully imported Tasmanian GPX files may be moved into managed watched storage under `~/Documents/Bushwalking/Tracks/Tasmania` so future reset or rebuild flows preserve them; edited names drive both the stored `trackName` and the managed filename, which must reuse the existing `GpxImporter` canonical filename normalization and date-format rules while explicitly ignoring source-filename date overrides for selective import and deriving the date component from `trackDate`, with deterministic filename suffixing on collision; route-only, non-Tasmanian, duplicate, and invalid files remain in their source directory

Shared selective-import pipeline scope:
- Reuse from folder import: GPX parsing, repair/processing XML selection, `processTrack(...)`, derived-field application, `contentHash` detection, and shared track-date derivation.
- Peak correlation is not part of the importer-shared pipeline for this feature; it remains provider-owned and is applied afterward in `MapNotifier`.
- Do not reuse from folder import: directory scanning, logical-match replacement by `trackName + trackDate`, route-file relocation to `Routes`, or snackbar completion feedback. Managed watched-storage placement for successfully imported Tasmanian files remains in scope.

**Error Handling:**
18. File picker permission failure: show error dialog with dismiss action, then return to the same import dialog
19. Invalid GPX selected: increment `errorCount`, continue processing the remaining selected files, and include the failure in the aggregate batch summary
20. Route-only GPX selected: increment `errorCount`, continue processing the remaining selected files, and include the failure in the aggregate batch summary
21. Import partial failures must not abort the full batch; aggregate what succeeded and what failed
22. No files selected: keep the import dialog open with no state change
23. The underlying import operation must use provider-owned busy state so the map FAB and other track operations obey the existing single-flight behavior, and it must clear existing `trackOperationStatus` and `trackOperationWarning` surfaces on start without wiping unrelated `trackImportError` detail that did not originate from the selective-import flow
24. The provider-owned selective import operation must use existing provider state for single-flight loading and dialog-local fatal-error handling, but selective-import completion summary or warning text must not persist into Settings surfaces after the dialog flow finishes, and unrecoverable selective-import failures must return or throw back to the dialog instead of using the shared `trackImportError` surface
25. Dialog summary replaces map snackbar feedback and Settings completion surfaces for this feature; selective import must not rely on `_pendingTrackSnackbarMessage`, and any manual-review warning text must direct the user to `import.log`

**Loading State:**
26. During import, show a circular progress indicator in the dialog and disable the dialog Import/Cancel controls
27. During import, set provider busy state so the map import FAB disables and shows the existing spinner behavior
28. Selective import must remain unavailable while `hasTrackRecoveryIssue` is true; in recovery mode the map import FAB stays disabled until the user resolves recovery from Settings
29. While the batch is running, follow the existing import-dialog route pattern: disable explicit dialog controls and keep the input dialog mounted until the result dialog completes; the spec does not require a separate staged dialog flow or a custom route solely to change barrier-dismiss behavior mid-operation

**Edge Cases:**
30. User renames a track to a trimmed empty string: show validation error and require trimmed non-empty input for that row
31. If every selected file is a duplicate, route-only, non-Tasmanian, or invalid, finish the batch with 0 added and a completed summary rather than an ambiguous failure state
32. Preserve per-file edited names by selected file path so the right override name is passed for each batch item, applied to both the returned `trackName` and the managed filename for successfully placed files
33. Maintain an importer-owned operation-level `seenContentHashes` set so duplicate content within the same selected batch counts as `unchangedCount` without inserting a second row

**Validation:**
33. Reuse stable keys from existing import dialogs, especially `Key('peak-list-import-*')` patterns
34. Add `Key('gpx-track-select-files')` for the dialog button that launches the native file picker
35. Add `Key('gpx-track-import-dialog')` for the main dialog container
36. Use stable per-row keys such as `Key('gpx-track-row-<index>')` and `Key('gpx-track-name-field-<index>')` for multi-file editing
37. Add stable keys for dialog actions and the aggregate batch summary surface, including `Key('gpx-track-import-button')`, `Key('gpx-track-import-cancel')`, `Key('gpx-track-import-summary')`, and `Key('gpx-track-import-result-close')`
</requirements>

<boundaries>
Edge cases:
- Empty track name: require trimmed non-empty input, show inline validation error
- No GPX files in default folder: file picker opens but shows empty folder (user can navigate)
- GPX with no metadata or failed name extraction during dialog prefill: use basename as the prefilled and default track name, and derive date via the shared public helper using file mtime fallback
- Non-Tasmanian GPX file selected: skip and count in `nonTasmanianCount`, not `errorCount`
- Route-only GPX file selected: do not import it as a track and leave it in the source directory
- Exact `contentHash` duplicate: count in `unchangedCount`, surface duplicate feedback in the aggregate batch summary, continue the rest of the batch
- Duplicate content within the same selected batch must also count in `unchangedCount`
- Managed filename collision for a successfully imported Tasmanian file: suffix the managed filename deterministically while keeping the DB `trackName` unchanged

Error scenarios:
- File picker cancelled: keep the import dialog open with no state change
- All selected files invalid/skipped: show a completed batch summary with 0 added and a full count breakdown
- Partial failure with some valid files: continue the batch and show a mixed result summary
- Any batch that surfaces manual-review or skipped-file warnings must direct the user to `import.log` for diagnostic detail
- Peak correlation failure after GPX processing: persist the imported track without correlated peaks and include an aggregate warning rather than failing the file
- Managed-file placement failure after persistence: keep the imported row, mark the track as managed-placement-pending, and warn that reset durability is not guaranteed until a future recovery action writes the managed file from stored GPX XML

Limits:
- File picker must only allow `.gpx` extension
- `.gpx` extension filtering is a picker convenience only; malformed `.gpx` files must still fail parse validation and count in `errorCount`
- Importer storage root: resolve from the shared canonical Bushwalking-root helper (normally `~/Documents/Bushwalking`)
- Picker default folder: start from the canonical Bushwalking root when available and otherwise use picker-only fallback behavior for dialog usability
- Repurposing the map FAB from manual rescan to selective import is an intentional UX change in scope for this spec
- Selective import remains blocked while `hasTrackRecoveryIssue` is true; the existing recovery gate on the map import FAB stays in place
- Selective import must not call logical-match replacement paths that overwrite existing rows
- Successfully imported Tasmanian GPX files may be moved into managed watched storage under `~/Documents/Bushwalking/Tracks/Tasmania` after persistence succeeds; skipped files remain in their source directory
- The result dialog keeps the existing dismiss-on-barrier behavior used by `showSingleActionDialog`
- Future note: a Settings recovery action may later surface retry for managed-placement-pending tracks, but that recovery UI is out of scope for this spec
</boundaries>

<implementation>
1. Extract a shared public canonical Bushwalking-root helper (for example `resolveBushwalkingRoot()`) for importer storage semantics, and keep picker initial-directory fallback behavior separate

2. Create @lib/services/gpx_file_picker.dart - based on PeakListFilePicker pattern but with multiple selection support
   - Add `gpxFilePickerProvider` so widget/robot tests can override the picker without invoking the native platform dialog
   - Add `pickGpxFiles()` method allowing multiple selection (allowMultiple: true)
   - Add `resolveImportRoot()` that starts from the canonical Bushwalking root when available and otherwise uses picker-only fallback behavior similar to `PeakListFilePicker`
   - Use FilePicker.platform with allowedExtensions: ['gpx']
   - NOTE: The picker starts at `~/Documents/Bushwalking` when that canonical root exists, so users can browse the managed `Tracks` tree and nearby folders without changing importer watched-subfolder derivation

3. Create separate shared contracts for importer planning and provider-finalized dialog results so pre-persistence planning is not conflated with post-persistence placement state:
   ```dart
    class GpxTrackImportPlan {
      final List<GpxTrackImportPlanItem> items;
      final int unchangedCount;
      final int nonTasmanianCount;
      final int errorCount;
      final String? warningMessage;
    }

    class GpxTrackImportPlanItem {
      final String sourcePath;
      final GpxTrack track;
      final String? plannedManagedRelativePath;
      final bool shouldPlaceInManagedStorage;
    }

    class GpxTrackImportResult {
      final List<GpxTrackImportItem> items;
      final int addedCount;
      final int unchangedCount;
      final int nonTasmanianCount;
      final int errorCount;
      final String? warningMessage;
    }

    class GpxTrackImportItem {
      final GpxTrack track;
      final String? managedRelativePath;
      final bool managedPlacementPending;
    }
    ```
   NOTE: `GpxTrackImportPlan` is returned by the importer-owned selective-import API and contains only successful additive-import candidates that may be persisted and optionally placed into managed storage; duplicates, skipped files, and hard failures are represented through counts and warning text instead.
   NOTE: `GpxTrackImportResult` is the final dialog-facing result returned by `MapNotifier` after persistence and managed-file placement handling.
   NOTE: `track.trackName` is the authoritative final track name for each item.
    NOTE: `managedPlacementPending` on the final result item reflects the persisted `GpxTrack.managedPlacementPending` state; the persisted track model is the source of truth.
   NOTE: `plannedManagedRelativePath` is the intended path relative to the canonical Bushwalking root before provider persistence/placement handling.
   NOTE: `managedRelativePath` is the final persisted path relative to the canonical Bushwalking root.
    NOTE: `warningMessage` is an optional aggregate detail block. It may summarize categories such as invalid GPX, route-only GPX, duplicate selections, or parse failures, but it must not become a file-by-file listing; when manual review is required it must direct the user to `import.log`.

    NOTE: Final `GpxTrackImportResult.items` must reflect persisted post-placement state for both success and failure cases, including the final persisted `managedRelativePath` and `managedPlacementPending` values.
    NOTE: The importer-owned plan carries `unchangedCount`, `nonTasmanianCount`, `errorCount`, and any importer-generated warning text; `MapNotifier` computes final `addedCount` from persisted successes and may append provider-owned warning text for post-import correlation or placement outcomes.

4. Update @lib/models/gpx_track.dart so managed-placement recovery can survive dialog close and app restart
    - Add minimal persisted fields needed for managed-file recovery: `managedPlacementPending` and `managedRelativePath`
    - `managedRelativePath` is relative to the canonical Bushwalking root
    - For pre-existing stored tracks that predate these fields, default to `managedPlacementPending = false` and `managedRelativePath = null`
    - On startup load, treat legacy rows with missing recovery fields as not pending and do not attempt to recompute recovery metadata in this spec
    - Persist the chosen relative managed path so recovery does not have to recompute collision suffixing from scratch
    - On successful initial placement, persist `managedPlacementPending = false` and the final chosen `managedRelativePath`
    - Update `GpxTrack.fromMap()` and `GpxTrack.toMap()` so these persisted recovery fields survive existing clone/replace flows
    - On placement failure after persistence, persist `managedPlacementPending = true` and preserve the chosen `managedRelativePath`
    - On future recovery success, set `managedPlacementPending = false` and keep `managedRelativePath` unchanged
    - On future recovery failure, keep `managedPlacementPending = true` and keep `managedRelativePath` unchanged
    - Regenerate ObjectBox bindings/schema after adding these persisted fields

5. Create @lib/widgets/gpx_track_import_dialog.dart - mirror peak_list_import_dialog.dart for multi-file list-based UX
    - Accept GpxFilePicker (allowMultiple: true)
    - Use `Key('gpx-track-select-files')` for the dialog action that launches the native file picker
    - Show all selected files in the same dialog in a scrollable list with editable name field for each, prefilled from a best-effort public/shared name-derivation helper that extracts the GPX metadata name and falls back to the basename without surfacing a pre-import row error
    - Store edited names in a Map<String, String> (path → edited name) for passing to `importGpxFiles(...)`
    - NOTE: No date field - date is derived internally
    - Add loading state UX: show circular progress, disable buttons during import
    - Match the current import-dialog pattern: picker cancel keeps the dialog open, picker failure shows an error dialog then returns to the input dialog, and fatal submit failure closes the input dialog before showing a failure dialog
    - Fatal selective-import errors are dialog-only and are returned or thrown back to the dialog instead of being stored in a shared provider error surface
    - On completion, show a separate result dialog that keeps the existing dismiss-on-barrier behavior from `showSingleActionDialog`, then close the input dialog after the result dialog closes
   - Show duplicate, invalid, route-only, and mixed-result feedback in the aggregate batch summary only; do not add inline per-file status surfaces
   - The dialog summary replaces snackbar feedback and must be the only completion-summary surface for selective import
    - Match existing dialog patterns for keys, state, and error handling
    - Reuse shared result class GpxTrackImportResult

6. Update @lib/widgets/map_action_rail.dart
   - Repurpose the current `Import Track(s)` FAB from manual rescan to dialog-based selective import
   - Read the picker through `gpxFilePickerProvider` so tests can override file selection
   - Continue to respect provider busy state (`mapState.isLoadingTracks`) so the FAB stays aligned with the rest of the track operation UX
   - Preserve the existing recovery gate: when `mapState.hasTrackRecoveryIssue` is true, the selective-import FAB remains disabled

7. Update @lib/services/gpx_importer.dart
   - Extract a public/shared name-derivation helper in `gpx_importer.dart` so dialog prefills and importer defaults reuse the same GPX metadata-name plus basename-fallback rule
   - Add a public selective-import API that returns `GpxTrackImportPlan`; make the importer the single owner of duplicate detection, parse/repair/filter/process rules, content-hash detection, aggregate counting, default-name derivation, and managed-filename planning
   - This selective-import API must reuse shared importer rules for parsing, route classification, track-date derivation, repair/processing selection, `processTrack(...)`, and derived-field application
   - This selective-import API must intentionally skip directory scanning, logical-match replacement, peak correlation, and snackbar behavior
   - Accept the edited-name map keyed by file path so the importer layer can apply per-file overrides to returned `trackName` values and managed-file planning before returning processed plan items
   - Managed-filename planning for selective import must reuse the existing `GpxImporter` canonical filename normalization and date-format rules while explicitly ignoring source-filename date overrides and deriving the date component from `trackDate`
   - Provide importer-owned managed-file placement logic that the provider can invoke after persistence succeeds; this logic must suffix managed filenames deterministically on collision while keeping the DB `trackName` unchanged and return the chosen `managedRelativePath`

8. Update @lib/providers/map_provider.dart
   - Keep `MapNotifier` responsible for single-flight state, persistence, peak correlation, and dialog-local fatal-error propagation
   - Add a provider-owned batch method that returns `GpxTrackImportResult` and owns the single-flight state for the full operation:
      ```
      Future<GpxTrackImportResult> importGpxFiles({
        required Map<String, String> pathToEditedNames,
      })
      ```
    - This method:
      - Sets provider busy state using the same pattern as existing track operations so the rail FAB and other track actions disable correctly
      - Instantiates `GpxImporter()` and loads `filterConfig` from `gpxFilterSettingsProvider.future`
       - Delegates duplicate detection plus all per-file parse/repair/filter/process/count logic to the new public selective-import API on `GpxImporter`
       - Persists the returned successful plan items additively only; do not invoke logical-match replacement paths for `trackName + trackDate`
       - Applies peak correlation to each returned track before persistence; if correlation fails for a new imported track, persist the track anyway without correlated peaks, leave `peakCorrelationProcessed = false`, keep it counted as added, and append an aggregate warning
       - If a new track has `gpxTrackId == 0`, let ObjectBox assign the ID on insert
        - After persistence succeeds, invoke importer-owned managed-file placement for successfully added Tasmanian plan items using the per-file placement data returned in `GpxTrackImportPlan`; if placement fails, keep the imported row, persist `managedPlacementPending` plus `managedRelativePath` for future recovery across restarts, and append a warning that reset durability is not guaranteed until a future recovery action writes the managed file from stored GPX XML
       - Before rethrowing any unrecoverable selective-import failure, restore provider busy state and clear operation-local transient selections/flags so the map UI does not remain locked
       - Propagate unrecoverable selective-import failures back to the dialog by throwing from `importGpxFiles(...)`; do not use the shared `trackImportError` surface for dialog-local selective-import failures
        - Does not populate `_pendingTrackSnackbarMessage`; dialog summary is the user-facing completion surface for this feature
        - Refresh state tracks from the repository, set `showTracks = true` only when at least one new Tasmanian track was imported, otherwise preserve the current `showTracks` value, clear hovered/selected track ids as needed, and return the final `GpxTrackImportResult`

9. Preserve new managed-placement fields in existing non-selective track flows
   - Reset or folder-import flows that rebuild tracks from managed files must persist `managedPlacementPending = false` and the actual `managedRelativePath` for those rebuilt tracks
   - Recalculate-track-statistics flows must preserve existing `managedPlacementPending` and `managedRelativePath` values unchanged while recomputing statistics and peak correlation

10. Add tests in @test/widget/gpx_track_import_dialog_test.dart
   - Override `gpxFilePickerProvider` with a test picker harness instead of invoking the native picker
    - Test file picker opens with correct defaults
    - Test selected rows are prefilled from GPX metadata name with basename fallback
   - Test single file selection and rename
   - Test multiple file selection with per-file rename
   - Test trimmed empty-name validation
    - Test import success, aggregate duplicate feedback, mixed-result flows, and the separate result-dialog step
    - Test completion summary or warning text does not persist into Settings after the dialog flow closes
   - Test picker cancel keeps the input dialog open with no state change
    - Test the success path keeps the input dialog mounted until the result dialog closes, following the current import-dialog pattern

11. Add test support and unit tests
    - Create @test/harness/test_gpx_file_picker.dart for override-based widget and robot tests
    - Update @test/harness/test_map_notifier.dart and existing GPX track shell/robot tests so `import-tracks-fab` no longer asserts rescan behavior
     - Add picker service tests in @test/services/gpx_file_picker_test.dart
      - Test GpxFilePicker resolves the canonical Bushwalking-root default folder when available
      - Test GpxFilePicker uses picker-only fallback behavior when the canonical Bushwalking root is unavailable
    - Add selective-import service tests in @test/services/gpx_importer_selective_import_test.dart
      - Test the selective-import API returns `GpxTrackImportPlan` and reuses the same processing pipeline as folder import
      - Test default-name derivation uses the public/shared helper owned with the importer, with GPX metadata name, basename fallback, and no pre-import row error on extraction failure
     - Test exact `contentHash` duplicates increment `unchangedCount` and do not abort the remaining batch
     - Test duplicate content within the same selected batch increments `unchangedCount`
     - Test non-Tasmanian files increment `nonTasmanianCount`
     - Test route-only GPX files are left in place and count in `errorCount`
     - Test logical-match replacement is not used by selective import
     - Test the extracted public track-date helper matches existing importer behavior
      - Test edited names drive `plannedManagedRelativePath` generation by reusing the existing `GpxImporter` canonical filename normalization and date-format rules with the date derived from `trackDate`
     - Test managed-filename collisions use deterministic suffixing
     - Test peak-correlation failure persists imported tracks without correlated peaks and appends a warning
      - Test managed-file placement failure keeps the imported row, persists `managedPlacementPending` plus `managedRelativePath`, and appends a reset-durability warning
      - Test managed-placement-pending fields persist on `GpxTrack` and survive app restart for future recovery
      - Test successful placement persists `managedPlacementPending = false` and the final chosen `managedRelativePath`
      - Test `GpxTrack.fromMap()` / `toMap()` and clone-style flows preserve `managedPlacementPending` and `managedRelativePath`
    - Add provider/model tests covering non-selective recovery-field behavior
      - Test startup load of legacy rows with missing recovery fields defaults to `managedPlacementPending = false` and `managedRelativePath = null` without recomputation in this spec
      - Test reset or folder-import rebuilt tracks persist `managedPlacementPending = false` and the actual `managedRelativePath`
      - Test recalculate-track-statistics preserves `managedPlacementPending` and `managedRelativePath`
</implementation>

<stages>
Phase 1: Create GPX file picker service
- Extract shared canonical Bushwalking-root helper and separate picker fallback behavior
- Create @lib/services/gpx_file_picker.dart with pickGpxFiles method
- Test picker resolves canonical root and fallback behavior correctly
- Verify: flutter analyze

Phase 2: Create GPX import dialog UI
- Create @lib/widgets/gpx_track_import_dialog.dart mirroring import dialog pattern
- Add stable keys for testing
- Verify: flutter analyze

Phase 3: Wire FAB to dialog
- Update @lib/widgets/map_action_rail.dart to show dialog on FAB tap
- Update @lib/services/gpx_importer.dart with the public selective-import API
- Update @lib/providers/map_provider.dart with `importGpxFiles(...)`
- Verify: dart run build_runner build && flutter analyze && flutter test

Phase 4: Integration tests
- Add widget tests for dialog flow
- Add unit tests for provider-owned batch import logic
- Migrate old rescan-based import FAB tests and notifier harnesses
- Verify: flutter test
</stages>

<validation>
1. TDD-first for the new import dialog and picker:
   - Test slice 1 (RED): File picker button opens dialog and starts from the canonical Bushwalking root when available, with picker-only fallback otherwise
    - Test slice 2 (GREEN): Selected files appear in list view with names prefilled from GPX metadata or basename fallback
    - Test slice 3 (RED): Name field is editable for each file and rejects trimmed empty input
   - Test slice 4 (RED): batch import distinguishes added, unchanged, non-Tasmanian, and error outcomes without aborting on duplicates
   - Test slice 5 (GREEN): Import button completes one provider-owned batch operation and creates new tracks

2. Unit tests must cover:
    - `test/services/gpx_file_picker_test.dart`: GpxFilePicker picks .gpx files from the canonical Bushwalking-root default folder when available
    - `test/services/gpx_file_picker_test.dart`: GpxFilePicker falls back only for picker usability and does not redefine importer storage semantics
    - `test/services/gpx_importer_selective_import_test.dart`: the importer-owned selective-import API returns `GpxTrackImportPlan` and reuses the same `processTrack(...)` and derived-field application path as folder import while intentionally skipping logical replacement and peak correlation
    - `test/services/gpx_importer_selective_import_test.dart`: default-name derivation uses the public/shared helper owned with the importer, with GPX metadata name, basename fallback, and no pre-import row error on extraction failure
    - `test/services/gpx_importer_selective_import_test.dart`: the extracted public track-date helper matches the current importer rule set
    - `test/services/gpx_importer_selective_import_test.dart`: additive-only selective import inserts new tracks and does not use logical-match replacement
    - `test/services/gpx_importer_selective_import_test.dart`: exact `contentHash` duplicates are detected, counted in `unchangedCount`, and do not abort the rest of the batch
    - `test/services/gpx_importer_selective_import_test.dart`: non-Tasmanian files are counted in `nonTasmanianCount`
    - `test/services/gpx_importer_selective_import_test.dart`: invalid GPX is caught and reported
    - `test/services/gpx_importer_selective_import_test.dart`: edited names drive managed-file planning by reusing the existing `GpxImporter` canonical filename normalization and date-format rules with the date derived from `trackDate`, and managed-file collisions use deterministic suffixing
    - `test/services/gpx_importer_selective_import_test.dart`: peak-correlation failure persists imported tracks without correlated peaks and appends a warning
    - `test/services/gpx_importer_selective_import_test.dart`: managed-file placement failure keeps the imported row, persists `managedPlacementPending` plus `managedRelativePath`, and appends a reset-durability warning
    - `test/services/gpx_importer_selective_import_test.dart`: successful placement persists `managedPlacementPending = false` and the final chosen `managedRelativePath`

3. Widget tests must cover:
    - Import FAB shows dialog on tap
    - Dialog `Select GPX Files` action launches the picker with a GPX filter
    - Selected files list updates correctly and shows prefilled names from GPX metadata or basename fallback without surfacing a pre-import row error on extraction failure
    - Name field validation for trimmed empty input
    - Dialog disables controls and shows progress while the provider-owned import batch is running
    - Picker cancel keeps the input dialog open with no state change
    - The success path keeps the input dialog mounted until the result dialog closes, matching the current import-dialog pattern
    - A separate result dialog shows added, unchanged, non-Tasmanian, and error counts plus optional aggregate warning text
    - Any manual-review warning text points the user to `import.log`
    - Duplicate, invalid, and route-only feedback appears only in the aggregate batch summary without aborting the rest of the batch
    - No per-file inline status widgets are required
    - Dialog summary is shown instead of map snackbar feedback for selective import
    - Selective-import completion summary or warning does not persist into Settings surfaces after the dialog flow completes
    - Dialog-local fatal selective-import failures do not overwrite shared Settings-visible `trackImportError` detail
    - Existing shell tests update the map action copy and no longer expect snackbar-based manual rescan from `import-tracks-fab`

4. Robot tests must cover the primary journey using stable keys:
   - Tap import FAB
   - Select GPX file(s) from picker
   - Verify dialog shows selected files
   - Edit track name
   - Confirm import
   - Verify success message and that duplicates/non-Tasmanian items do not prevent valid files from importing

5. Stable selectors:
    - `Key('gpx-track-select-files')` for the dialog button that launches the native file picker
    - `Key('gpx-track-import-dialog')` for main dialog container
    - `Key('gpx-track-row-<index>')` for each selected file row
    - `Key('gpx-track-name-field-<index>')` for each editable track name field
    - `Key('gpx-track-import-progress')` for dialog progress state
    - `Key('gpx-track-import-summary')` for the result-dialog summary surface
    - `Key('gpx-track-import-result-close')` for the result-dialog close action
    - Reuse pattern keys from peak_list_import_dialog where applicable

6. Baseline automated coverage outcome:
   - logic/rules: unit tests
   - UI rendering: widget tests
   - critical journey: robot test
</validation>

<done_when>
1. Tapping the `Import Track(s)` FAB opens a selective GPX import dialog
2. User can select one or more GPX files from the picker-specific import root, which starts from the canonical Bushwalking root when available and otherwise uses picker-only fallback behavior
3. Dialog allows editing track name for each file (no date field shown), prefilled from GPX metadata name with basename fallback and no pre-import row error on extraction failure
4. Selective import uses the same processing pipeline as folder import for parsing/repair/filter/process steps while peak correlation remains provider-owned
5. Import adds new tracks without deleting or replacing existing tracks; successfully imported Tasmanian GPX files are persisted first, then may be moved into managed watched storage so reset or rebuild flows preserve them, while skipped files remain in place
6. A separate result dialog shows added, unchanged, non-Tasmanian, and error counts
7. Duplicate files do not abort the rest of the selected batch, including duplicate content within the same batch
8. Dialog summary replaces snackbar and Settings completion surfaces for this feature; selective-import completion summary or warning does not persist into Settings after the dialog flow completes, and dialog-local fatal selective-import failures do not use the shared `trackImportError` surface
9. If peak correlation fails after GPX processing, the imported track still persists without correlated peaks and the batch returns a warning instead of dropping the track
10. Managed-file naming reuses the existing `GpxImporter` canonical filename normalization and date-format rules with the date derived from `trackDate`, ignores source-filename date overrides for selective import, applies deterministic suffixing on collision, and warns rather than deleting the imported row if post-persistence managed-file placement fails
11. If post-persistence managed-file placement fails, the imported track remains stored and persists `managedPlacementPending` plus `managedRelativePath` for future recovery from stored GPX XML; if placement succeeds, `managedPlacementPending` is false and the final chosen `managedRelativePath` remains persisted
12. Selective import remains unavailable during track-recovery mode until recovery is resolved from Settings
13. Existing tracks remain unchanged after import except for newly added rows and refreshed visible state
14. Tests cover the import dialog, provider-owned batch import, persisted managed-placement-pending recovery state, shared name and date helpers, route/non-Tasmanian handling, mixed-result flows, and migration of old rescan-based FAB expectations
15. flutter analyze passes
16. flutter test passes
</done_when>
