<goal>
Add a GPX file picker dialog to the import track FAB on the map screen. When tapped, users can select one or more GPX files from the default track folder and import them as new tracks without deleting existing data.

Who: Users wanting to add individual GPX tracks from specific files without triggering a full folder rescan
Why: Provides fine-grained control over which tracks get imported, supporting selective track addition workflows
</goal>

<background>
Flutter app with Riverpod, flutter_map, ObjectBox, and existing GPX track functionality. The import track FAB currently triggers a folder rescan via `rescanTracks()` in MapNotifier.

The UI pattern comes from `peak_list_import_dialog.dart` which uses `PeakListFilePicker` for CSV file selection. A parallel picker needs to be created for GPX files.

Files to examine:
- @lib/widgets/peak_list_import_dialog.dart - UI pattern for import dialog
- @lib/widgets/map_action_rail.dart - current import FAB at line 256-283
- @lib/providers/map_provider.dart - track state management (lines 471-600)
- @lib/services/gpx_importer.dart - track import logic
- @lib/models/gpx_track.dart - GPX track entity
- @lib/services/peak_list_file_picker.dart - existing file picker to mirror
- @test/widget/peak_lists_screen_test.dart - existing import dialog tests
</background>

<user_flows>
Primary flow:
1. User taps the import track FAB on the map screen
2. A GPX file picker dialog opens, showing ~/Documents/Bushwalking/Tracks as the default folder
3. User selects one or more GPX files from the file picker (or cancels)
4. If files selected, a list-based dialog shows all selected files with editable name fields (one per file)
5. On confirmation, the dialog submits the full batch to MapNotifier in one operation
6. The app processes every selected file using the same GPX processing pipeline as folder import
7. Valid Tasmanian tracks are added; duplicates, non-Tasmanian files, and invalid files are reported in the batch result while the rest of the batch continues
8. Existing tracks remain unchanged; no existing track rows are replaced or deleted by this feature
9. Success feedback shows added, unchanged, non-Tasmanian, and error counts, and new tracks become visible on the map

Alternative flows:
- User taps Cancel or outside the dialog: dialog closes, no action taken
- User selects a single GPX file: the same batch dialog appears with one editable row
- User selects multiple GPX files: batch import flow with rename options for each
- User selects a file that already exists (same contentHash): that file is counted as unchanged, duplicate feedback is shown in the batch summary or inline status, and the remaining files continue processing

Error flows:
- File picker fails (permission denied): show error dialog, close gracefully
- Invalid GPX file selected: skip the file, show error in summary, continue with other files
- Non-Tasmanian GPX selected: skip and increment nonTasmanianCount, continue with other files
- No GPX files found in selection: show "No valid GPX files selected" message
- All selected files are skipped or invalid: show a completed batch summary with 0 added and a breakdown of unchanged, non-Tasmanian, and error counts
</user_flows>

<requirements>
**Functional:**
1. Replace the current import FAB tap action (which calls `rescanTracks()`) with a file picker dialog
2. Create a new GPX file picker class mirroring `PeakListFilePicker` pattern but for `.gpx` files
3. Allow selection of multiple GPX files in a single picker session
4. Default the file picker to ~/Documents/Bushwalking/Tracks
5. Show an import list dialog allowing the user to edit the track name for each selected file
6. Do not show a date field in the dialog; date remains derived internal metadata
7. Extract a public shared helper for track-date derivation and use it wherever selective import and folder import need the same rule set
8. Import selected GPX files using the same processing pipeline as folder import, including repair/processing selection, `processTrack(...)`, `filterConfig`, `_applyProcessingResult(...)`, and peak correlation
9. Existing tracks must NOT be deleted; the selective import feature is additive-only
10. Skip exact `contentHash` duplicates, increment `unchangedCount`, and continue processing the remaining selected files
11. Do not use logical-match replacement by `trackName + trackDate` for this feature
12. Preserve existing importer semantics for non-Tasmanian files: skip them and increment `nonTasmanianCount` instead of `errorCount`
13. Allow duplicate track names in the database when `contentHash` differs
14. Show a batch result summary after import: X added, Y unchanged, Z non-Tasmanian, W errors
15. On success, set `showTracks = true` so new tracks are immediately visible

**Error Handling:**
16. File picker permission failure: show error dialog with dismiss action
17. Invalid GPX selected: increment `errorCount`, continue processing the remaining selected files, and include the failure in batch feedback
18. Import partial failures must not abort the full batch; aggregate what succeeded and what failed
19. No files selected: close dialog silently
20. The underlying import operation must use provider-owned busy state so the map FAB and other track operations obey the existing single-flight behavior

**Loading State:**
21. During import, show a circular progress indicator in the dialog and disable the dialog Import/Cancel controls
22. During import, set provider busy state so the map import FAB disables and shows the existing spinner behavior

**Edge Cases:**
23. User renames a track to an empty string: show validation error and require non-empty name for that row
24. If every selected file is a duplicate, non-Tasmanian, or invalid, finish the batch with 0 added and a completed summary rather than an ambiguous failure state
25. Preserve per-file edited names by selected file path so the right override name is passed for each batch item

**Validation:**
26. Reuse stable keys from existing import dialogs, especially `Key('peak-list-import-*')` patterns
27. Add `Key('gpx-file-picker')` for the file picker trigger
28. Add `Key('gpx-track-import-dialog')` for the main dialog container
29. Use stable per-row keys such as `Key('gpx-track-row-<index>')` and `Key('gpx-track-name-field-<index>')` for multi-file editing
30. Add stable keys for dialog actions and any inline per-file status surface used for duplicate feedback
</requirements>

<boundaries>
Edge cases:
- Empty track name: require at least 1 character, show inline validation error
- No GPX files in default folder: file picker opens but shows empty folder (user can navigate)
- GPX with no metadata: use filename as track name, derive date via the shared public helper using file mtime fallback
- Non-Tasmanian GPX file selected: skip and count in `nonTasmanianCount`, not `errorCount`
- Exact `contentHash` duplicate: count in `unchangedCount`, surface duplicate feedback, continue the rest of the batch

Error scenarios:
- File picker cancelled: no state change
- All selected files invalid/skipped: show a completed batch summary with 0 added and a full count breakdown
- Partial failure with some valid files: continue the batch and show a mixed result summary

Limits:
- File picker must only allow `.gpx` extension
- Default folder: ~/Documents/Bushwalking/Tracks (same as existing import folder)
- No limit on number of files selected, but warn on very large selections (> 50 files)
- Do not change existing track database or rescan behavior outside this selective-import flow
- Selective import must not call logical-match replacement paths that overwrite existing rows
</boundaries>

<implementation>
1. Create @lib/services/gpx_file_picker.dart - based on PeakListFilePicker pattern but with multiple selection support
   - Add `pickGpxFiles()` method allowing multiple selection (allowMultiple: true)
   - Add `resolveImportRoot()` returning ~/Documents/Bushwalking/Tracks folder
   - Use FilePicker.platform with allowedExtensions: ['gpx']
   - NOTE: This default path differs from PeakListFilePicker (~/Documents/Bushwalking) because GPX files are organized under Tracks subfolder, consistent with GpxImporter.getTracksFolder()

2. Create a reusable result class based on PeakListImportPresentationResult pattern, renamed for tracks:
   ```dart
   class GpxTrackImportResult {
      final int addedCount;
      final int unchangedCount;
      final int nonTasmanianCount;
      final int errorCount;
      final String? warningMessage;
    }
   ```
   NOTE: The result is presentation data only. It carries counts/status back to the widget layer; it does not own dialog side effects.

3. Create @lib/widgets/gpx_track_import_dialog.dart - mirror peak_list_import_dialog.dart for multi-file list-based UX
   - Accept GpxFilePicker (allowMultiple: true)
   - Show all selected files in a scrollable list with editable name field for each
   - Store edited names in a Map<String, String> (path → edited name) for passing to `importGpxFiles(...)`
   - NOTE: No date field - date is derived internally
   - Add loading state UX: show circular progress, disable buttons during import
   - Show duplicate feedback in batch summary or inline per-file status from returned result data; the widget owns dialogs and status presentation
   - Match existing dialog patterns for keys, state, and error handling
   - Reuse presentation result class GpxTrackImportResult

4. Update @lib/widgets/map_action_rail.dart
   - Replace current `rescanTracks()` call with dialog-based import flow
   - Continue to respect provider busy state (`mapState.isLoadingTracks`) so the FAB stays aligned with the rest of the track operation UX

5. Update @lib/providers/map_provider.dart
   - Add a provider-owned batch method that returns GpxTrackImportResult and owns the single-flight state for the full operation:
     ```
     Future<GpxTrackImportResult> importGpxFiles({
       required Map<String, String> pathToEditedNames,
     })
     ```
   - This method:
     - Sets provider busy state using the same pattern as existing track operations so the rail FAB and other track actions disable correctly
     - Instantiates `GpxImporter()` and loads `filterConfig` from `gpxFilterSettingsProvider.future`
     - Extracts a public shared track-date helper from the existing importer rules and reuses it where shared date derivation is needed
     - Iterates over the selected file batch inside MapNotifier so the whole batch is one tracked operation
     - For each file:
       - compute `contentHash`
       - if `findByContentHash()` matches, increment `unchangedCount`, record duplicate feedback, and continue the batch
       - parse the GPX using the importer
       - if `overrideName` exists for that path, overwrite `track.trackName`
       - if the file is non-Tasmanian, increment `nonTasmanianCount` and continue the batch
       - run the same processing pipeline as folder import: select processing XML, call `processTrack(..., filterConfig: filterConfig)`, and `_applyProcessingResult(...)`
       - do not invoke logical-match replacement paths for `trackName + trackDate`; additive-only selective import inserts new rows only
       - if new track has `gpxTrackId == 0`, let ObjectBox assign the ID on insert
       - create `TrackPeakCorrelationService` exactly as existing import paths do, then call `_applyPeakCorrelation(track, correlationService, xml)` where `xml = track.gpxFileRepaired.isNotEmpty ? track.gpxFileRepaired : track.gpxFile`
       - persist the new track
     - Refresh state tracks from the repository, set `showTracks = true`, clear hovered/selected track ids as needed, and return aggregated presentation counts

6. Add tests in @test/widget/gpx_track_import_dialog_test.dart
   - Test file picker opens with correct defaults
   - Test single file selection and rename
   - Test multiple file selection with per-file rename
   - Test empty name validation
   - Test import success, duplicate feedback, and mixed-result flows

7. Add unit tests in @test/gpx_track_test.dart
   - Test GpxFilePicker resolves correct default folder
   - Test selective import reuses the same processing pipeline as folder import
   - Test exact `contentHash` duplicates increment `unchangedCount` and do not abort the remaining batch
   - Test non-Tasmanian files increment `nonTasmanianCount`
   - Test logical-match replacement is not used by selective import
   - Test the extracted public track-date helper matches existing importer behavior
</implementation>

<stages>
Phase 1: Create GPX file picker service
- Create @lib/services/gpx_file_picker.dart with pickGpxFiles method
- Test picker resolves correct folder
- Verify: flutter analyze

Phase 2: Create GPX import dialog UI
- Create @lib/widgets/gpx_track_import_dialog.dart mirroring import dialog pattern
- Add stable keys for testing
- Verify: flutter analyze

Phase 3: Wire FAB to dialog
- Update @lib/widgets/map_action_rail.dart to show dialog on FAB tap
- Update @lib/providers/map_provider.dart with `importGpxFiles(...)`
- Verify: flutter analyze && flutter test

Phase 4: Integration tests
- Add widget tests for dialog flow
- Add unit tests for provider-owned batch import logic
- Verify: flutter test
</stages>

<validation>
1. TDD-first for the new import dialog and picker:
   - Test slice 1 (RED): File picker button opens dialog and shows default folder
   - Test slice 2 (GREEN): Selected files appear in list view
   - Test slice 3 (RED): Name field is editable for each file
   - Test slice 4 (RED): batch import distinguishes added, unchanged, non-Tasmanian, and error outcomes without aborting on duplicates
   - Test slice 5 (GREEN): Import button completes one provider-owned batch operation and creates new tracks

2. Unit tests must cover:
   - GpxFilePicker picks .gpx files from correct default folder
   - GpxFilePicker resolves to ~/Documents/Bushwalking/Tracks
   - selective import reuses the same `processTrack(...)` and `_applyProcessingResult(...)` path as folder import
   - the extracted public track-date helper matches the current importer rule set
   - additive-only selective import inserts new tracks and does not use logical-match replacement
   - exact `contentHash` duplicates are detected, counted in `unchangedCount`, and do not abort the rest of the batch
   - non-Tasmanian files are counted in `nonTasmanianCount`
   - Invalid GPX is caught and reported

3. Widget tests must cover:
   - Import FAB shows dialog on tap
   - File picker opens with GPX filter
   - Selected files list updates correctly
   - Name field validation for empty input
   - Dialog disables controls and shows progress while the provider-owned import batch is running
   - Success dialog or batch summary shows added, unchanged, non-Tasmanian, and error counts
   - Duplicate feedback appears in the batch summary or inline per-file status without aborting the rest of the batch
   - Error dialog shows for invalid GPX

4. Robot tests must cover the primary journey using stable keys:
   - Tap import FAB
   - Select GPX file(s) from picker
   - Verify dialog shows selected files
   - Edit track name
   - Confirm import
   - Verify success message and that duplicates/non-Tasmanian items do not prevent valid files from importing

5. Stable selectors:
   - `Key('gpx-file-picker')` for file picker trigger button
   - `Key('gpx-track-import-dialog')` for main dialog container
   - `Key('gpx-track-row-<index>')` for each selected file row
   - `Key('gpx-track-name-field-<index>')` for each editable track name field
   - `Key('gpx-track-import-progress')` for dialog progress state
   - Reuse pattern keys from peak_list_import_dialog where applicable

6. Baseline automated coverage outcome:
   - logic/rules: unit tests
   - UI rendering: widget tests
   - critical journey: robot test
</validation>

<done_when>
1. Tapping the import track FAB opens a GPX file picker dialog
2. User can select one or more GPX files from ~/Documents/Bushwalking/Tracks
3. Dialog allows editing track name for each file (no date field shown)
4. Selective import uses the same processing pipeline as folder import while remaining additive-only
5. Import adds new tracks without deleting or replacing existing tracks
6. Batch feedback shows added, unchanged, non-Tasmanian, and error counts
7. Duplicate files do not abort the rest of the selected batch
8. Existing tracks remain unchanged after import except for newly added rows and refreshed visible state
9. Tests cover the import dialog, provider-owned batch import, shared date helper, and mixed-result flows
10. flutter analyze passes
11. flutter test passes
</done_when>
