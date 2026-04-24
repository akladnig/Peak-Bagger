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
5. On confirmation, the selected GPX files are imported as new tracks
6. Existing tracks remain unchanged; no tracks are deleted
7. Success message shows the number of tracks added

Alternative flows:
- User taps Cancel or outside the dialog: dialog closes, no action taken
- User selects a single GPX file: single-file import flow with one confirmation step
- User selects multiple GPX files: batch import flow with rename options for each
- User selects a file that already exists (same contentHash): show dialog "This track has already been imported", count as unchanged, stop import flow

Error flows:
- File picker fails (permission denied): show error dialog, close gracefully
- Invalid GPX file selected: skip the file, show error in summary, continue with other files
- Non-Tasmanian GPX selected: skip and increment error count (consistent with existing import rules)
- No GPX files found in selection: show "No valid GPX files selected" message
</user_flows>

<requirements>
**Functional:**
1. Replace the current import FAB tap action (which calls `rescanTracks()`) with a file picker dialog
2. Create a new GPX file picker class mirroring `PeakListFilePicker` pattern but for `.gpx` files
3. Allow selection of multiple GPX files in a single picker session
4. Default the file picker to ~/Documents/Bushwalking/Tracks
5. Show an import list dialog allowing the user to edit the track name for each selected file
   - NOTE: Do NOT show a date field at all (date is derived internally, user doesn't need to see it)
   - Use GpxImporter._extractStartDateTime() for GPX date, fall back to modification time, apply _normalizeTrackDate() to get midnight
7. Import selected GPX files as new tracks using the renamed track name
8. Existing tracks must NOT be deleted; the import is additive only
11. Show a success summary after import: X tracks added, Y unchanged (skipped), Z errors
12. On success, auto-show tracks (set showTracks = true so new tracks are immediately visible)

**Error Handling:**
13. File picker permission failure: show error dialog with dismiss action
14. Invalid GPX selected: skip file, continue processing others
15. Import partially fails: show what succeeded and what failed
16. No files selected: close dialog silently

**Loading State:**
16a. During import, show circular progress indicator on the Import button
16b. During import, disable the Import/Cancel buttons
16c. Use same loading state pattern as existing import dialogs

**Edge Cases:**
17. User renames track to empty string: show validation error, require non-empty name
18. User selects a file already imported (same contentHash): show dialog "already imported", halt import flow

**Validation:**
21. Reuse stable keys from existing import dialogs, especially `Key('peak-list-import-*')` patterns
22. Add `Key('gpx-file-picker')` for the file picker trigger
23. Add `Key('gpx-track-import-dialog')` for the main dialog container
24. Add `Key('gpx-track-name-field')` for the track name text field
25. Add keys for each import action button in the dialog flow
</requirements>

<boundaries>
Edge cases:
- Empty track name: require at least 1 character, show inline validation error
- No GPX files in default folder: file picker opens but shows empty folder (user can navigate)
- GPX with no metadata: use filename as track name, derive date from file mtime
- Non-Tasmanian GPX file selected: skip and report in error count (consistent with existing import rules)

Error scenarios:
- File picker cancelled: no state change
- All selected files invalid: show "No valid GPX files found" error dialog
- Partial failure with some valid files: show mixed result summary

Limits:
- File picker must only allow `.gpx` extension
- Default folder: ~/Documents/Bushwalking/Tracks (same as existing import folder)
- No limit on number of files selected, but warn on very large selections (> 50 files)
- Do not change existing track database or rescan behavior
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
     final bool success;
     final int addedCount;
     final int unchangedCount;
     final int errorCount;
     final String? errorMessage;
   }
   ```
   NOTE: Uses PeakListImportPresentationResult structure to align with existing dialog patterns

3. Create @lib/widgets/gpx_track_import_dialog.dart - mirror peak_list_import_dialog.dart for multi-file list-based UX
   - Accept GpxFilePicker (allowMultiple: true)
   - Show all selected files in a scrollable list with editable name field for each
   - Store edited names in a Map<String, String> (path → edited name) for passing to importGpxFile
   - NOTE: No date field - date is derived internally
   - Add loading state UX: show circular progress, disable buttons during import
   - Match existing dialog patterns for keys, state, and error handling
   - Reuse presentation result class GpxTrackImportResult

4. Update @lib/widgets/map_action_rail.dart
   - Replace current `rescanTracks()` call with dialog-based import flow
   - Use dialog-local state (setState), not provider state for dialog loading

5. Update @lib/providers/map_provider.dart
   - Add new method `importGpxFile()` to MapNotifier that returns GpxTrackImportResult:
     ```
     Future<GpxTrackImportResult> importGpxFile({
       required String gpxPath,
       String? overrideName,
     })
     ```
   - This method (single file):
     - First: compute contentHash for the GPX file
     - Check contentHash via GpxTrackRepository.findByContentHash()
       - If contentHash matches existing: skip, return unchangedCount=1, show dialog "This track has already been imported"
       - If not found: proceed to create new track
     - Parse GPX file using GpxImporter.parseGpxFile() logic
     - If overrideName provided, override track.trackName
- If new track has gpxTrackId=0, ObjectBox auto-assigns the ID
      - AFTER inserting track, call _applyPeakCorrelation(track, correlationService, xml) where xml = track.gpxFileRepaired.isNotEmpty ? track.gpxFileRepaired : track.gpxFile
      - Updates track list state
     - Sets showTracks = true
     - Returns GpxTrackImportResult
   - For multiple files: dialog loops over selected files, calls importGpxFile() for each, aggregates results into final GpxTrackImportResult

6. Add tests in @test/widget/gpx_track_import_dialog_test.dart
   - Test file picker opens with correct defaults
   - Test single file selection and rename
   - Test multiple file selection with per-file rename
   - Test empty name validation
   - Test import success and error flows

7. Add unit tests in @test/gpx_track_test.dart
   - Test GpxFilePicker resolves correct default folder
   - Test importGpxFile creates new track record
   - Test contentHash deduplication works for file-based imports
   - Test non-Tasmanian files rejected appropriately
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
- Update @lib/providers/map_provider.dart with importGpxFile method
- Verify: flutter analyze && flutter test

Phase 4: Integration tests
- Add widget tests for dialog flow
- Add unit tests for single-file import logic
- Verify: flutter test
</stages>

<validation>
1. TDD-first for the new import dialog and picker:
   - Test slice 1 (RED): File picker button opens dialog and shows default folder
   - Test slice 2 (GREEN): Selected files appear in list view
   - Test slice 3 (RED): Name field is editable for each file
   - Test slice 4 (GREEN): Import button creates new track

2. Unit tests must cover:
   - GpxFilePicker picks .gpx files from correct default folder
   - GpxFilePicker resolves to ~/Documents/Bushwalking/Tracks
   - importGpxFile creates new track record with correct fields
   - Duplicate contentHash is detected and skipped
   - Non-Tasmanian files are rejected
   - Invalid GPX is caught and reported

3. Widget tests must cover:
   - Import FAB shows dialog on tap
   - File picker opens with GPX filter
   - Selected files list updates correctly
   - Name field validation for empty input
   - Success dialog shows correct counts
   - Duplicate dialog shows "already imported" message
   - Error dialog shows for invalid GPX

4. Robot tests must cover the primary journey using stable keys:
   - Tap import FAB
   - Select GPX file(s) from picker
   - Verify dialog shows selected files
   - Edit track name
   - Confirm import
   - Verify success message

5. Stable selectors:
   - `Key('gpx-file-picker')` for file picker trigger button
   - `Key('gpx-track-import-dialog')` for main dialog container
   - `Key('gpx-track-name-field')` for track name text field
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
4. Import adds new tracks without deleting existing tracks
5. Success summary shows count of added tracks
6. Duplicate tracks show "already imported" dialog
7. Existing tracks remain unchanged after import
8. Tests cover the import dialog, file picker, and single-file import logic
9. flutter analyze passes
10. flutter test passes
</done_when>