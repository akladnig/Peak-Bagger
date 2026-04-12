<goal>
Display GPX tracks on the map for the macOS app. Import Tasmanian GPX tracks from a folder, save them to ObjectBox, and render them with toggle and rescan controls.

Who: Users who want to view their Bushwalking tracks on the map
Why: Track visualization is needed for navigation and trip planning
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, flutter_map
Platform: macOS only for this spec
Context: Peak bagging app with map viewing capability
Files to examine:
- @lib/models/peak.dart - ObjectBox entity pattern
- @lib/models/gpx_track.dart - existing GPX entity to retrofit
- @lib/services/gpx_track_repository.dart - existing GPX repository to retrofit
- @lib/services/gpx_importer.dart - existing GPX importer to retrofit
- @lib/router.dart - FAB placement and MapProvider usage
- @lib/providers/map_provider.dart - existing state ownership pattern
- @lib/screens/map_screen.dart - existing keyboard handling and map rendering pattern
- @lib/objectbox-model.json - generated ObjectBox model file
- @lib/objectbox.g.dart - generated ObjectBox bindings
- @lib/screens/settings_screen.dart - existing settings integration point
- @pubspec.yaml - Dependencies (latlong2, csv, xml already present; this feature adds crypto)

Repo prerequisite:
- This slice requires the project to use unsandboxed direct-distribution macOS builds for both debug and release.
- The current release target must be changed away from App Sandbox to match that project-level requirement.
- Preserving sandboxed/App-Store-style distribution is intentionally out of scope for this slice.

Constraints:
- Tracks are stored on macOS in ~/Documents/Bushwalking/Tracks
- Also examine subfolder: ~/Documents/Bushwalking/Tracks/Tasmania
- Route GPX destination folder: ~/Documents/Bushwalking/Routes
- No other child folders are examined
- First track point determines Tasmania/non-Tasmania classification
- Tasmania bounds: latitude -39 to -44, longitude 143 to 149
- Track color: #a726bc (purple)
- Preserve segmented GPX geometry when persisting and rendering tracks
- When files are organized, rename them to a canonical lowercase filename with normalized separators and a date suffix
</background>

<user_flows>
Primary flow:
1. User opens the map screen
2. If the track repository is empty, the system automatically performs an initial track import attempt
3. During any import or rescan, the import FAB shows a circular progress indicator and ignores repeat taps until the operation completes
4. On initial import, the system scans ~/Documents/Bushwalking/Tracks and ~/Documents/Bushwalking/Tracks/Tasmania
5. On later routine manual imports/rescans, the system scans only ~/Documents/Bushwalking/Tracks because previously organized imported files should already reside under ~/Documents/Bushwalking/Tracks/Tasmania
6. Files in ~/Documents/Bushwalking/Tracks/Tasmania are outside routine manual rescan scope and require Reset Track Data
7. For each GPX file, the system determines:
   - whether the GPX is a route (`rte`/`rtept`) or a track (`trk`/`trkpt`); if any `trkpt` exists, treat the GPX as a track, and only route-only GPX files are treated as routes
   - track name from GPX metadata, or filename if metadata is missing
   - track date as a normalized local day value at midnight derived from GPX start time, or file modification time if GPX date metadata is missing
   - contentHash as the lowercase SHA-256 hex digest of the raw GPX file bytes, used for unchanged-file detection
   - first track point for Tasmania classification
   - canonical move filename by lowercasing the source filename stem, replacing whitespace/`.`/`,`/`&` with `-`, collapsing repeated dashes, and appending `_(dd-mm-yyyy)` using a filename date/datetime in parentheses when present, otherwise using the derived trackDate
8. If the GPX is identified as a route rather than a track, move it to ~/Documents/Bushwalking/Routes using collision rules and do not persist it in ObjectBox
9. If the track is Tasmanian and not already in the Tasmania folder, move it into the Tasmania folder using collision rules
10. If the track is non-Tasmanian and currently in the Tasmania folder, move it to the parent Tracks folder using collision rules
11. Parse track GPX files into segmented geometry
12. If an existing row has the same contentHash, do not create another persisted row; use the canonical persisted trackName/trackDate chosen for that duplicate group rather than whichever later filename was scanned, attempt on-disk organization for the duplicate, and count it as unchangedCount only if organization succeeds without a destination-path collision
13. Persist and render only Tasmanian tracks; non-Tasmanian tracks and route GPX files are organized on disk only and are not inserted into ObjectBox or shown on the map
14. If an existing row has the same logical track match (trackName + trackDate) but different contentHash, replace the prior row in the database only when both the incoming track and the persisted row have startDateTime != null, which marks trackDate as metadata-derived rather than file-modification-derived
15. This replacement rule is an accepted tradeoff and may destructively replace distinct tracks that share the same trackName and normalized trackDate
16. Logical-match replacement first moves the new file while preserving the existing organized destination filename for that logical match, then replaces the database row
17. For logical-match replacement only, overwrite is allowed only when the current move target path already exists and the existing destination file resolves to the same logical match (trackName + trackDate)
18. This overwrite rule is also an accepted destructive tradeoff and may overwrite the wrong file when multiple files share the same logical match
19. The feature does not track or delete old organized files on disk
20. Otherwise insert a new track row
21. During manual rescan, already-visible tracks remain visible until refreshed data is ready
22. User taps the show tracks FAB to display or hide imported tracks
23. Tracks render on the map with color #a726bc

Alternative flows:
- No tracks found: show import FAB enabled, show tracks FAB disabled
- Tracks already imported: routine manual rescan still attempts on-disk organization for unchanged contentHash duplicates, counts them as unchangedCount only when organization succeeds, and leaves collision-blocked duplicates at their source path for manual review and future rescans
- Tracks already imported: changed tracks whose incoming and persisted rows both have startDateTime != null can replace a prior logical match; changed tracks whose trackDate came from file modification time are not eligible for logical-match replacement and may import as additional rows
- Tracks already imported: non-Tasmanian files are not persisted, so unchanged detection across rescans does not apply to them; they are reclassified and reorganized on each routine manual rescan, excluded from importedCount/replacedCount/unchangedCount/errorSkippedCount, and reported only in nonTasmanianCount
- Route GPX files are moved to ~/Documents/Bushwalking/Routes, excluded from track persistence, and excluded from importedCount/replacedCount/unchangedCount/errorSkippedCount/nonTasmanianCount
- Successful route moves are omitted from the quantitative summary; failed route moves count as errorSkippedCount and set the manual-review warning
- Files already in ~/Documents/Bushwalking/Routes are not scanned during initial import, routine manual rescan, or Reset Track Data
- Tracks already imported: if multiple metadata-date-eligible files discovered in the same operation share a logical match, candidates are sorted lexicographically by original pre-move source path, only the first candidate may replace, and later candidates remain at source path for manual review and count as errorSkippedCount
- Files in Tracks/Tasmania are not discovered by routine manual rescans
- During routine manual rescan, if the watched folder contains no GPX files, show a snackbar such as "No GPX files found in watched folder"
- Duplicate track names in the database are allowed
- Archive mode: previously imported tracks remain in ObjectBox even if the source GPX file is later removed from disk
- Same-name same-day replacement is intentionally lossy and accepted for this slice

Error flows:
- Folder doesn't exist: create the folder structure and continue
- Permission denied reading folder: show error, keep existing imported tracks, allow retry via import FAB
- Permission denied moving/writing file: show error, skip that file, continue processing others
- Invalid GPX file: log error, skip file, continue
- No track points found: skip file, continue
- Destination path collision: for non-replacement imports, skip the file, surface an error explaining that the file remains at its current source path for manual review, and continue processing other files; for logical-match replacement only, overwrite is allowed only when the current move target path already exists
- Same-operation logical-match conflict: if multiple metadata-date-eligible files share a logical match, sort candidates lexicographically by original pre-move source path, only the first candidate may replace, and later candidates remain at source path for manual review, are logged, and count as errorSkippedCount
</user_flows>

<requirements>
**Functional:**
F-1. Retrofit the existing GPX track ObjectBox entity with schema:
   - gpxTrackId (int, @Id)
   - contentHash (String) - populated now as the lowercase SHA-256 hex digest of the raw GPX file bytes and used only to detect unchanged content
   - trackName (String) - populated now with track name only
   - trackDate (DateTime?) - populated now as a normalized local day value at midnight derived from GPX start time, or file modification time when GPX date metadata is missing; legacy pre-reset rows may be null, and mtime-derived values are used only for display/sorting rather than logical-match replacement
   - trackPoints (String) - persisted as a JSON-encoded segmented geometry string in the form [[[lat,lng],[lat,lng]], [[lat,lng]]]
   - startDateTime (DateTime?) - populated when GPX metadata contains a start time, otherwise null; startDateTime != null is the persisted marker that trackDate came from GPX metadata and may participate in logical-match replacement
   - endDateTime (DateTime?) - populated by traversing all trkpt elements in document order and using the final point with a parseable <time>, otherwise null
   - distance (double?) - future, null for now
   - ascent (double?) - future, null for now
   - totalTimeMillis (int?) - future, null for now (Duration stored as milliseconds)
   - trackColour (int) - populated now with #a726bc
F-2. Remove fileLocation from the GPX track database schema
F-3. Do not add canonicalFileName to the database schema
F-4. Import GPX tracks from ~/Documents/Bushwalking/Tracks and the Tasmania subfolder on macOS
F-5. Auto-organize GPX files: move Tasmanian tracks to Tasmania folder, non-Tasmanian tracks to the parent Tracks folder, and route GPX files to ~/Documents/Bushwalking/Routes
F-5a. When a GPX file is moved, rename it to a canonical filename: lowercase, whitespace replaced with `-`, multiple whitespace collapsed to one `-`, `.` replaced with `-`, `,` replaced with `-`, `&` replaced with `-`, repeated dashes collapsed to one `-`, then append `_(dd-mm-yyyy)` before the `.gpx` extension using a filename date/datetime in parentheses when present, otherwise using the derived trackDate
F-6. Persist and render only Tasmanian tracks; non-Tasmanian tracks and route GPX files are organized on disk only and are not inserted into ObjectBox or shown on the map
F-7. Use contentHash to detect unchanged persisted Tasmanian tracks during rescans; non-Tasmanian tracks and route GPX files are not stored in ObjectBox and are reclassified/reorganized on each routine rescan instead
F-7a. GPX route-vs-track precedence: if any `trkpt` exists, treat the GPX as a track; only route-only GPX files are moved to ~/Documents/Bushwalking/Routes
F-8. Use logical track match (trackName + trackDate) to replace a prior row when the source file content changes, but only when both the incoming track and the persisted row have startDateTime != null so trackDate is known to come from GPX metadata rather than file modification time
F-9. Keep database trackName values non-unique; duplicate track names are valid
F-10. Add an import FAB with Icons.input, tooltip text "Import track", and a matching semantics label; map route-shell FABs must use the same left-positioned tooltip/semantics wrapper pattern as the import and show tracks FABs
F-11. Add a show tracks FAB with Icons.route
F-12. FAB order must be: info, import, show tracks, grid
F-13. Show tracks FAB is disabled when there are no imported tracks, while tracks are currently loading, or while hasTrackRecoveryIssue is true
F-14. Import FAB remains visible at all times, but is disabled while tracks are loading or while hasTrackRecoveryIssue is true
F-15. Import FAB shows a circular progress indicator while import/rescan is running
F-16. Toggle displays/hides tracks on the map with color #a726bc
F-17. Add keyboard shortcut 't' using the same keyboard handling pattern already used by the map screen; it must obey the same enablement rules as the Show tracks FAB
F-18. Preserve the existing track-count row in the info popup when hasTrackRecoveryIssue is false; during recovery, replace that row with the text "Some tracks need to be rebuilt."
F-19. Add a manual "Reset Track Data" action to the settings screen directly below the existing Reset Map Data action, with its own explicit UX and clearly differentiated subtitle/help text
F-20. Reset Track Data must show a confirmation dialog with:
   - title: "Reset Track Data?"
   - body: "This will wipe all track data and re-import tracks from disk. If source files are missing or unreadable, you may end up with fewer imported tracks than before. Do you wish to proceed?"
   - actions: "Cancel" and "Reset"
   - destructive styling on the "Reset" action when supported by the app theme
   - barrier dismiss disabled so tapping outside the dialog does not dismiss it
F-21. On confirmation, Reset Track Data wipes track data and performs the reimport immediately
F-22. Reset Track Data performs a full rebuild scan of both ~/Documents/Bushwalking/Tracks and ~/Documents/Bushwalking/Tracks/Tasmania
F-23. Restart the app only if technically required by the implementation
F-24. On success, show a quantitative result message including importedCount, replacedCount, unchangedCount, nonTasmanianCount, and errorSkippedCount
F-25. Use a TrackImportResult-style contract with named fields including importedCount, replacedCount, unchangedCount, nonTasmanianCount, and errorSkippedCount
F-26. importedCount counts new Tasmanian tracks inserted into ObjectBox during the current operation
F-27. replacedCount counts Tasmanian tracks that replaced an existing logical match during the current operation
F-28. unchangedCount counts Tasmanian tracks skipped because an existing row already has the same contentHash and on-disk organization succeeds without a destination-path collision
F-29. nonTasmanianCount counts scanned non-Tasmanian track GPX files that are organized on disk only and not inserted into ObjectBox; successful route GPX moves are excluded from this count
F-30. errorSkippedCount counts GPX files not imported into ObjectBox because they were invalid, unreadable, blocked by collisions, blocked by overwrite verification, left at source path for manual review after losing a same-operation logical-match conflict, or failed route moves that require manual review
F-31. Per-file skip reasons that represent an error or manual-review condition must be recorded in ~/Documents/Bushwalking/import.log with the filename and reason
F-32. During routine manual rescan, if the watched folder contains no GPX files, show a snackbar such as "No GPX files found in watched folder"
F-33. Do not show an additional Reset Track Data snackbar when the watched folder contains no GPX files; the generic no-files-found snackbar takes precedence
F-34. Set the default import folder file location to ~/Documents/Bushwalking/Tracks
F-35. Set the default track destination folder file location to ~/Documents/Bushwalking/Tracks/Tasmania
F-35a. Set the default route destination folder file location to ~/Documents/Bushwalking/Routes
F-36. This feature assumes unsandboxed direct-distribution macOS app configurations for both debug and release targets, with direct access to the user's Documents folder; sandboxed/App-Store-style distribution is out of scope for this slice
F-37. Identical-content GPX files are treated as the same imported track for ObjectBox purposes; contentHash is authoritative for identical-content duplicates. Source-path tie-breakers for duplicate groups use the original pre-move scan snapshot captured for the operation. When a new contentHash is first seen during an import/reset operation, prefer GPX metadata name when present; otherwise choose the filename from the lexicographically smallest original pre-move source path in that in-operation duplicate group as the canonical persisted trackName. When GPX date metadata is missing, choose the earliest derived trackDate across that in-operation duplicate group as the canonical persisted trackDate. Once a persisted row exists for that contentHash, later duplicate trackName/trackDate values do not rewrite the persisted row and are ignored for persistence/counting; only one persisted row is kept, and later identical-content files are organized on disk rather than imported as separate rows
F-38. While hasTrackRecoveryIssue is true, the map route shell must show a persistent recovery banner or chip pinned bottom-center with the text "Some tracks need to be rebuilt." and an action that opens Settings

**State Management:**
SM-1. Add to MapState:
   - showTracks (bool)
   - tracks (List<GpxTrack>)
   - isLoadingTracks (bool)
   - trackImportError (String?)
   - hasTrackRecoveryIssue (bool)
   - trackOperationStatus (String?)
   - trackOperationWarning (String?)
SM-2. Add toggleTracks() method to MapNotifier
SM-3. Add importTracks()/rescanTracks() behavior to MapNotifier as the smallest-fit owner of this feature
SM-4. On initial map load, automatically attempt import only when the track repository is empty
SM-5. Manual rescan via the "Import track" FAB must work regardless of repository state and only scans the default import folder, except when hasTrackRecoveryIssue is true
SM-6. Archive mode: rescans must not delete previously imported tracks just because the source GPX file is no longer present
SM-7. Initial auto-import and manual rescan must use the same loading/error state, but manual rescan is the only path that shows the summary snackbar and the dedicated Tracks status/warning area in Settings
SM-8. During manual rescan, existing tracks remain rendered until refreshed results are ready to replace them atomically, except when hasTrackRecoveryIssue is true
SM-9. Only one track operation may run at a time
SM-10. While isLoadingTracks is true, both the import FAB and Reset Track Data entry point are disabled
SM-11. Repeated import or reset requests while isLoadingTracks is true are ignored
SM-12. Starting any track operation clears trackImportError, trackOperationStatus, and trackOperationWarning
SM-13. Successful manual rescan and successful Reset Track Data set trackOperationStatus to the latest quantitative summary
SM-14. Fatal track-operation failures set trackImportError
SM-15. Non-fatal track-operation warnings, including manual-operation import.log write failures and any files left at source path for manual review, set trackOperationWarning without replacing a successful quantitative summary
SM-16. hasTrackRecoveryIssue reflects whether persisted track data failed validation under the current schema; it is not a dismissible UI-visibility flag
SM-17. MapNotifier owns the once-per-launch recovery snackbar gate as in-memory session state; the map route shell in router.dart is responsible for listening to that state and showing the snackbar
SM-18. Full-rebuild scans that examine both Tracks and Tracks/Tasmania must capture a fixed pre-move scan snapshot; source-path-based canonicalization and same-operation logical-match conflict sorting use those original pre-move paths, and an operation-level processed-file identity set may also be used so files moved earlier in the same operation are not processed again when the second directory is scanned
SM-19. After a successful Reset Track Data operation that leaves no remaining recovery issue, clear hasTrackRecoveryIssue, re-enable Import track and Show tracks, and restore showTracks to false so track display returns to normal user-controlled behavior
SM-20. On initial auto-import and startup load from valid persisted rows, set showTracks to true; on manual rescan, preserve the current showTracks value unless recovery mode is entered

**Migration:**
MIG-1. On initial map load, do not wipe or reimport a non-empty track database automatically
MIG-2. After opening the store, if a non-empty track database is present and any persisted tracks fail geometry decode, have empty trackPoints, have empty contentHash, or have null trackDate, surface a recovery state instead of auto-resetting the data
MIG-3. The recovery hint text must be exactly "Some tracks need to be rebuilt."
MIG-4. The recovery hint must appear both as an inline warning in Settings and as a snackbar in the map route shell
MIG-5. Show the map route shell snackbar once per app launch when the recovery issue is first detected while the map route shell is active, show the persistent recovery banner at the same time, and do not re-show the snackbar until the recovery state changes
MIG-6. Reset the once-per-launch recovery snackbar gate only when hasTrackRecoveryIssue transitions from false to true; clearing the recovery issue does not itself emit a snackbar
MIG-7. Manual dismissal of the recovery snackbar does not reset the once-per-launch gate or cause the snackbar to reappear in the same launch
MIG-8. Users must use Reset Track Data to rebuild legacy or incompatible track data under the new schema
MIG-9. Reset Track Data may lose previously imported archived tracks whose source GPX files no longer exist on disk; that data loss is accepted for this slice
MIG-10. Automatic import on map load is non-interactive and must not require user confirmation
MIG-11. If recovery is detected while the map route shell is not active, defer the snackbar until the user next returns to the map route shell; the persistent recovery banner appears when the map route shell next becomes visible

**Error Handling:**
ERR-1. Missing folders: create ~/Documents/Bushwalking/Tracks, the Tasmania subfolder, and ~/Documents/Bushwalking/Routes
ERR-2. Invalid GPX: skip the file, continue processing, and record the filename and reason in import.log
ERR-3. No track points found: skip the file, continue processing, and record the filename and reason in import.log
ERR-4. During initial auto-import, keep failures silent except for a single snackbar when a fatal folder-access failure prevents the import attempt from reading the watched folder
ERR-5. During manual rescan or Reset Track Data, show a summary snackbar for the completed operation and update the dedicated Tracks status/warning area in Settings with the same quantitative result
ERR-6. The manual-operation summary reports importedCount, replacedCount, unchangedCount, nonTasmanianCount, and errorSkippedCount
ERR-7. Per-file failures do not produce their own snackbar; they are recorded in import.log and rolled into errorSkippedCount
ERR-8. Permission denied reading or moving files must keep processing unaffected files and be reflected through the startup/manual surfaces above
ERR-9. Track import failures must update trackImportError so Settings and map UI can reflect the latest operation state
ERR-10. Failed track imports, route moves, and manual-review skips must append a timestamp, filename, and reason to ~/Documents/Bushwalking/import.log
ERR-11. If import.log cannot be written during startup auto-import, continue silently
ERR-12. If import.log cannot be written during manual rescan or Reset Track Data, continue the import, set trackOperationWarning, and do not fail the whole operation solely because logging failed
ERR-13. If the user navigates away from the map screen while import is running, the import continues in MapNotifier state and the UI reflects completion when the user returns
ERR-14. Before overwrite during logical-match replacement, stage or copy the existing destination file so it can be restored if the database replacement fails
ERR-15. If logical-match replacement moves a file successfully but the database replacement fails, restore the staged destination file, move the new file back to its original location, and surface an error through the operation summary
ERR-16. If overwrite verification cannot resolve the existing destination file to the same logical match, treat it as a non-replacement collision, do not overwrite, and record the filename and reason in import.log
ERR-17. Reset Track Data failures must surface that source files missing or unreadable during reimport can result in fewer imported tracks than before

**Edge Cases:**
EC-1. Empty Tracks folder: show import enabled and show tracks disabled
EC-2. Tasmania folder doesn't exist: create it
EC-2a. Routes folder doesn't exist: create it
EC-3. Duplicate track names in the database are allowed
EC-4. Destination path collisions on non-replacement imports must skip the file, leave the file at its current source path for manual review, continue processing, and record the collision reason in import.log
EC-5. Multi-segment GPX tracks must preserve segment boundaries in storage and rendering
EC-6. If GPX metadata has no name, use the filename as trackName
EC-7. If GPX metadata has no date, use the file modification time to derive trackDate
EC-8. During logical-match replacement, preserve the existing organized destination filename for that logical match and allow overwrite only when the current move target path already exists and the existing destination file resolves to the same logical match
EC-9. This overwrite rule is an accepted destructive tradeoff and may overwrite the wrong file when multiple files share the same logical match
EC-10. If an unchanged identical-content duplicate can be organized without a destination-path collision, count it as unchangedCount; if organization hits a destination-path collision, leave the file at its current source path for manual review, record the reason in import.log, and count it as errorSkippedCount instead of unchangedCount
EC-11. Collision-blocked unchanged identical-content duplicates are expected to recur on subsequent rescans until the user manually resolves the file on disk
EC-12. Changed tracks whose trackDate came from file modification time are not eligible for logical-match replacement and may import as additional rows when content changes
EC-13. If multiple metadata-date-eligible files discovered in the same operation share the same logical match, sort candidates lexicographically by their original pre-move source paths and only the first candidate may perform the logical-match replacement; later candidates remain at their source paths for manual review, are logged, and count as errorSkippedCount
</requirements>

<boundaries>
Error scenarios:
- Initial auto-import fatal folder access failure: show one snackbar such as "Could not access tracks folder" and otherwise keep startup import silent
- Manual rescan or Reset Track Data folder/move failures: show the operation summary snackbar, update the dedicated Tracks status/warning area in Settings, and record per-file reasons in import.log
- Corrupted GPX: count as skipped, do not show a per-file snackbar, and record the reason in import.log

Limits:
- macOS only in this spec
- The feature assumes unsandboxed direct-distribution macOS app configurations for both debug and release targets so the app can access ~/Documents/Bushwalking/Tracks directly
- Sandboxed/App-Store-style distribution is out of scope for this slice
- Only examine Tracks and Tasmania subfolder as scan inputs (no recursive depth); ~/Documents/Bushwalking/Routes is a destination-only folder
- First track point only for Tasmania classification
- Archive mode: imported tracks remain in ObjectBox after source-file removal unless the user later gets an explicit delete feature
- Files manually placed or edited in Tracks/Tasmania are out of scope for routine manual rescans
- Manual GPX metadata edits are out of scope for this slice and may produce new imports or lossy replacement behavior
- Imported tracks do not retain stable source-file provenance in this slice
- Reset Track Data rebuilds track data from the current on-disk GPX files rather than reconciling against previously imported source files
- Logical-match replacement preserves the existing organized destination filename and may overwrite only when the current move target path already exists and the existing destination file resolves to the same logical match; this is an accepted destructive tradeoff when multiple files share the same logical match
</boundaries>

<implementation>
This feature is a schema-and-import rewrite, not a small incremental tweak.

Retrofit existing files:
- @lib/models/gpx_track.dart
  - remove fileLocation
  - add contentHash and trackDate
  - add endDateTime by traversing all trkpt elements in document order and using the final point with a parseable <time>
  - allow trackDate to remain null for legacy pre-reset rows, but require it for newly imported rows
  - keep `trackPoints` as the persisted JSON string field
  - expose parsed segmented geometry via `getSegments()` returning `List<List<LatLng>>`
  - make GpxTrack the single owner of segmented geometry decode/point parsing
- @lib/services/gpx_track_repository.dart
  - remove fileLocation-based lookup
  - add contentHash-based lookup for unchanged-content detection
  - add logical-match lookup by trackName + trackDate only for rows whose startDateTime != null so replacement remains metadata-date-only
  - add upsert behavior that replaces a matched prior row when content changes only when both incoming and persisted rows are metadata-date-eligible
- @lib/services/gpx_importer.dart
  - use the filename as trackName when GPX metadata name is missing
  - detect GPX routes separately from tracks and move route-only GPX files to ~/Documents/Bushwalking/Routes without inserting them into ObjectBox
  - if any `trkpt` exists, treat the GPX as a track even if `rtept` also exists
  - use file modification time fallback for trackDate derivation
  - derive endDateTime by traversing all trkpt elements in document order and using the final point with a parseable <time>
  - return a TrackImportResult-style summary including importedCount, replacedCount, unchangedCount, nonTasmanianCount, and errorSkippedCount
  - when a new contentHash is first seen in an import/reset operation, group identical-content files in that operation, prefer GPX metadata name when present, otherwise choose the filename from the lexicographically smallest original pre-move source path as the canonical persisted trackName, and choose the earliest derived trackDate as the canonical persisted value when GPX date metadata is missing
  - treat later GPX files with an already-imported contentHash as identical-content duplicates whose later derived trackName/trackDate values never rewrite the persisted row and are ignored for persistence/counting
  - use the fixed pre-move scan snapshot for all source-path-based tie-breakers, including canonical duplicate naming and same-operation logical-match conflict sorting
  - if multiple metadata-date-eligible files in the same operation share a logical match, sort candidates lexicographically by their original pre-move source paths and only the first candidate may perform the logical-match replacement
  - count identical-content duplicates as unchangedCount only when their on-disk organization succeeds without a destination-path collision
  - if an unchanged identical-content duplicate hits a destination-path collision, leave the file in place for manual review, record the reason in import.log, and count it as errorSkippedCount
  - build a fixed pre-move scan snapshot before moves, and optionally use an operation-level processed-file identity set based on source path/file instance so files moved earlier in the same full-rebuild operation are not processed twice
  - move files using collision rules, including route moves into ~/Documents/Bushwalking/Routes
  - compute canonical move filenames by lowercasing the source filename stem, replacing whitespace/`.`/`,`/`&` with `-`, collapsing repeated dashes, and appending `_(dd-mm-yyyy)` before the extension using a filename date/datetime in parentheses when present, otherwise using the derived trackDate
  - preserve the existing organized destination filename during logical-match replacement instead of recomputing it from the incoming source filename
  - allow overwrite only when the current move target path already exists and the existing destination file resolves to the same logical match during logical-match replacement
  - stage or copy the existing destination file before overwrite during logical-match replacement
  - if the move succeeds but the database replacement fails, restore the staged destination file, move the new file back to its original location, and surface an error
  - if overwrite verification cannot resolve the existing destination file to the same logical match, treat it as a non-replacement collision and surface an error
  - compute contentHash as the lowercase SHA-256 hex digest of the raw GPX file bytes
  - append a timestamp, filename, and skip/failure reason to ~/Documents/Bushwalking/import.log
  - continue silently if import.log cannot be written during startup auto-import
  - continue the import and surface one operation-level warning if import.log cannot be written during manual rescan or Reset Track Data
  - preserve segmented geometry
- @lib/providers/map_provider.dart
  - add track loading/error state
  - add import/rescan behavior
  - enforce single-flight track operations while isLoadingTracks is true
  - keep archive-mode semantics during rescans
  - auto-import only for the empty-database case
  - do not auto-wipe or auto-reimport non-empty track data on startup
  - show a visible recovery hint when any persisted tracks in a non-empty track database fail geometry decode, have empty trackPoints, have empty contentHash, or have null trackDate under the current schema, with the exact text "Some tracks need to be rebuilt."
  - surface the recovery hint both in Settings and as a one-shot snackbar in the map route shell
  - require Reset Track Data for rebuilding legacy or incompatible non-empty databases
  - keep the Import track FAB visible but disabled while hasTrackRecoveryIssue is true, and direct the user to Reset Track Data via the recovery UI
  - hide track rendering and disable the Show tracks FAB while hasTrackRecoveryIssue is true
  - keep startup auto-import silent except for a fatal folder-access snackbar
  - expose manual rescan/reset summary text for reuse by Settings
  - expose non-fatal manual-operation warnings separately from the quantitative summary text
  - use `hasTrackRecoveryIssue` as the persisted-track recovery state instead of a UI visibility flag
  - clear `trackImportError`, `trackOperationStatus`, and `trackOperationWarning` when a new track operation starts
  - own the once-per-launch recovery-snackbar gate in MapNotifier session state and reset it only when `hasTrackRecoveryIssue` transitions from false to true
  - do not reset the once-per-launch recovery-snackbar gate when the user manually dismisses the snackbar
- @lib/router.dart
  - wire up import/rescan FAB
  - expose the import action as "Import track" via tooltip and semantics label
  - make map route-shell FABs use the same left-positioned tooltip/semantics wrapper pattern as the import and show tracks FABs
  - show circular progress state while import runs
  - keep FAB order as info, import, show tracks, grid
  - listen for the once-per-launch recovery state in the map route shell and show the recovery snackbar from router.dart
  - add a snackbar action that navigates the user to Settings so they can use Reset Track Data
  - if recovery is detected while the map route shell is inactive, defer the snackbar until the user next returns to the map route shell
  - render a persistent recovery banner or chip pinned bottom-center while hasTrackRecoveryIssue is true, with text explaining that tracks need to be rebuilt and an action to open Settings
  - show the snackbar and persistent recovery banner together on first visible recovery detection; dismissing the snackbar leaves the banner visible until recovery clears
- @lib/screens/settings_screen.dart
  - add a Reset Track Data action directly below Reset Map Data, with an explicit destructive confirmation dialog, immediate reimport, success messaging, and inline recovery warning support
  - add a dedicated Tracks status/warning area for track operation results instead of reusing one global status surface
  - place the inline recovery warning and helper copy directly with the Reset Track Data action, including copy that explains Reset Track Data rebuilds from Tracks and Tracks/Tasmania, and that route GPX files are organized into ~/Documents/Bushwalking/Routes rather than persisted as tracks
- @macos/Runner/DebugProfile.entitlements
  - verify the debug target already matches the unsandboxed assumption for this feature slice
- @macos/Runner/Release.entitlements
  - align the release target with the unsandboxed assumption by not enabling App Sandbox for this feature slice
- @lib/screens/map_screen.dart
  - render segmented track geometry
  - remove raw trackPoints parsing logic
  - consume parsed geometry from GpxTrack.getSegments() instead
  - keep currently visible tracks rendered during manual rescan until refreshed data is ready
  - replace the normal info-popup track-count row with "Some tracks need to be rebuilt." while hasTrackRecoveryIssue is true

Regenerate generated files after entity changes:
- @lib/objectbox-model.json
- @lib/objectbox.g.dart

Dependencies:
- Update @pubspec.yaml
- Reuse existing xml dependency in @pubspec.yaml
- Use package:crypto for SHA-256 contentHash generation

Patterns:
- Follow existing ObjectBox entity pattern from Peak entity
- Keep track import/state ownership inside MapNotifier as the smallest fit
- Reuse the existing keyboard handling pattern already used in MapScreen
- Render segmented geometry as separate polylines so segment boundaries are preserved
- Keep geometry parse ownership inside GpxTrack so UI code consumes `getSegments()` instead of re-parsing raw `trackPoints` strings
</implementation>

<validation>
**TDD expectations for entity and repository:**
- Test file: @test/gpx_track_test.dart
- Test slice 1 (RED): Newly imported GpxTrack rows populate valid identity fields (contentHash, trackName, trackDate) and default optional fields correctly
- Test slice 2 (GREEN): GpxTrack.getSegments() decodes segmented geometry into LatLng-ready segments for map rendering
- Test slice 3 (RED): Repository.addTrack() persists to ObjectBox
- Test slice 4 (GREEN): Repository.getAllTracks() returns all tracks
- Test slice 5 (RED): Repository.findByContentHash() finds track
- Test slice 6 (RED): Repository.findByTrackNameAndTrackDate() finds the logical track match used for replacement only for rows whose startDateTime != null
- Test slice 7 (RED): Repository.upsertTrack() replaces an existing row when trackName + trackDate match, contentHash differs, and both rows are metadata-date-eligible
- Test slice 8 (RED): Repository.isEmpty() returns true when no tracks

**Importer tests:**
- Unit test: GPXImporter uses GPX metadata name/date when available
- Unit test: GPXImporter derives normalized local-midnight trackDate from GPX start time
- Unit test: GPXImporter derives endDateTime by traversing all trkpt elements in document order and using the final point with a parseable <time>
- Unit test: GPXImporter falls back to file modification time when GPX date metadata is missing
- Unit test: GPXImporter preserves segmented geometry
- Unit test: GPXImporter moves Tasmanian tracks into Tasmania folder
- Unit test: GPXImporter moves non-Tasmanian tracks out of Tasmania folder
- Unit test: GPXImporter moves route-only GPX files into ~/Documents/Bushwalking/Routes and does not insert them into ObjectBox
- Unit test: GPX files already in ~/Documents/Bushwalking/Routes are not scanned as import inputs
- Unit test: If both `trkpt` and `rtept` exist, GPXImporter treats the file as a track rather than a route
- Unit test: GPXImporter renames moved files to the canonical lowercase dashed filename with `_(dd-mm-yyyy)` suffix
- Unit test: If the filename contains a date/datetime in parentheses, the canonical move filename uses that date instead of GPX metadata
- Unit test: GPXImporter skips non-replacement imports when the destination path already exists, surfaces an error, and leaves the file at its current source path for manual review
- Unit test: GPXImporter computes stable contentHash values for unchanged-content detection
- Unit test: TrackImportResult reports importedCount, replacedCount, unchangedCount, nonTasmanianCount, and errorSkippedCount correctly for a mixed scan result
- Unit test: Non-Tasmanian files are excluded from importedCount, replacedCount, unchangedCount, and errorSkippedCount, and are reported only in nonTasmanianCount
- Unit test: Identical-content GPX files produce one persisted row and count later duplicates as unchangedCount when on-disk organization succeeds without a destination-path collision
- Unit test: If an unchanged identical-content duplicate hits a destination-path collision, the file remains at its source path, the reason is logged, and the result counts it as errorSkippedCount
- Unit test: Invalid or unreadable GPX files are counted in errorSkippedCount and write a reason to import.log
- Unit test: GPX files with no track points are counted in errorSkippedCount and write the reason "No track points found" to import.log
- Unit test: Failed track imports and route moves append a timestamp, filename, and reason to ~/Documents/Bushwalking/import.log
- Unit test: If import.log cannot be written during startup auto-import, import continues silently
- Unit test: If import.log cannot be written during manual rescan or Reset Track Data, import continues and surfaces one operation-level warning
- Unit test: If files are left at source path for manual review, trackOperationWarning tells the user to inspect import.log
- Unit test: Persisted rows with empty contentHash or null trackDate trigger the recovery state even when geometry is decodable
- Unit test: Full-rebuild scans do not reprocess a file moved earlier in the same operation when the second directory is scanned when using a fixed scan list or processed-file identity set
- Unit test: When identical-content duplicates rely on file-modification-time fallback, the canonical persisted trackDate is the earliest derived trackDate across the duplicate contentHash group
- Unit test: When identical-content duplicates have no GPX metadata name, the canonical persisted trackName uses the filename from the lexicographically smallest original pre-move source path in the duplicate group
- Unit test: Once a persisted row exists for a contentHash, later identical-content duplicates do not rewrite that row's trackDate
- Unit test: Tracks whose trackDate came from file modification time are not eligible for logical-match replacement
- Unit test: If multiple metadata-date-eligible files in the same operation share a logical match, candidates are sorted lexicographically by original pre-move source path and only the first candidate may perform the logical-match replacement
- Unit test: logical-match replacement preserves the existing organized destination filename even when the incoming source filename canonicalizes differently
- Unit test: logical-match replacement may overwrite only when the current move target path already exists and the existing destination file resolves to the same logical match
- Unit test: overwrite replacement stages the destination file before overwrite
- Unit test: if logical-match replacement moves the file successfully but database replacement fails, the staged destination file is restored, the new file is moved back to its original location, and an error is surfaced
- Unit test: if overwrite verification cannot resolve the existing destination file to the same logical match, replacement is blocked and an error is surfaced
- Unit test: logical-match replacement may overwrite same-name same-day distinct tracks and this is accepted behavior for this slice
- Unit test: only Tasmanian tracks are persisted while non-Tasmanian tracks and route GPX files are organized on disk only

**UI behavior tests:**
- Widget test: Import FAB is visible when tracks list is empty
- Widget test: Show tracks FAB is disabled when tracks list is empty
- Widget test: Show tracks FAB is disabled while import is running
- Widget test: Show tracks FAB is enabled when tracks exist, loading has finished, and hasTrackRecoveryIssue is false
- Widget test: Import FAB shows a circular progress indicator while import is running
- Widget test: Tapping import FAB triggers rescan behavior when hasTrackRecoveryIssue is false
- Widget test: Keyboard shortcut 't' is ignored when the Show tracks FAB would be disabled
- Widget test: Existing visible tracks remain rendered during manual rescan until refreshed data is ready
- Widget test: Import FAB and Reset Track Data are disabled while isLoadingTracks is true
- Widget test: When the watched folder contains no GPX files, a snackbar says no GPX files were found
- Widget test: During manual rescan, when both the empty-folder and Tracks/Tasmania conditions are true, only the no-GPX-files-found snackbar is shown
- Widget test: When any persisted tracks in a non-empty database fail geometry decode, have empty trackPoints, have empty contentHash, or have null trackDate, a visible recovery hint saying "Some tracks need to be rebuilt." is shown
- Widget test: The recovery hint appears both as an inline warning in Settings and as a snackbar in the map route shell
- Widget test: The recovery snackbar is shown only once per app launch until the recovery state changes
- Widget test: On first visible recovery detection, the map route shell shows both the recovery snackbar and the persistent recovery banner
- Widget test: Dismissing the recovery snackbar does not reset the once-per-launch gate or re-show the snackbar in the same launch
- Widget test: If recovery is detected while the map route shell is inactive, the recovery snackbar is deferred until the user next returns to the map route shell
- Widget test: The recovery snackbar includes an action that navigates the user to Settings
- Widget test: While hasTrackRecoveryIssue is true, the map route shell shows a persistent bottom-center recovery banner or chip with an action to open Settings
- Widget test: Settings screen offers a Reset Track Data action
- Widget test: When hasTrackRecoveryIssue is true, the Import track FAB remains visible but disabled and recovery UI directs the user to Reset Track Data
- Widget test: When hasTrackRecoveryIssue is true, track rendering is hidden and the Show tracks FAB is disabled until reset completes
- Widget test: During recovery, the info popup shows "Some tracks need to be rebuilt." instead of the normal track-count row
- Widget test: Reset Track Data is placed below Reset Map Data with distinct helper copy
- Widget test: Track operation results render in a dedicated Tracks status/warning area
- Widget test: A successful manual track operation can show both a quantitative summary and a non-fatal warning in the dedicated Tracks status/warning area
- Widget test: Reset Track Data shows a confirmation dialog before wiping data
- Widget test: Reset Track Data dialog warns that missing or unreadable source files can reduce the imported track count
- Widget test: Reset Track Data dialog shows the expected title, body, and Cancel/Reset actions, and is not barrier-dismissible
- Widget test: Reset Track Data shows a success message with importedCount, replacedCount, unchangedCount, nonTasmanianCount, and errorSkippedCount after wipe and reimport
- Widget test: Import FAB exposes tooltip and semantics label text "Import track"
- Widget test: Toggle tracks changes showTracks state

**Critical journey tests:**
- Legacy-database flow: non-empty legacy or incompatible track database is not auto-wiped or auto-reimported on startup
- Unusable-data flow: non-empty track data with persisted rows that fail geometry decode, have empty trackPoints, have empty contentHash, or have null trackDate shows the recovery hint text "Some tracks need to be rebuilt."
- Recovery-mode flow: incompatible non-empty track database disables Import track and Show tracks, shows a persistent recovery banner in the map route shell, offers a snackbar action to open Settings, and is cleared by Reset Track Data
- Recovery-route flow: user uses the recovery snackbar or banner action to open Settings, runs Reset Track Data, returns to the map route shell, and normal controls are restored
- Identical-content flow: two identical-content GPX files are scanned, only one row persists, the duplicate group uses the earliest derived trackDate when GPX date metadata is missing, the later duplicate is counted as unchangedCount when organization succeeds, and a destination collision instead leaves the duplicate at its source path and counts it as errorSkippedCount
- Visibility flow: initial auto-import and startup load from valid rows set showTracks to true, manual rescan preserves the current showTracks value, and successful Reset Track Data restores showTracks to false
- Recovery-banner flow: while hasTrackRecoveryIssue is true, the user sees a persistent bottom-center recovery banner in the map route shell until Reset Track Data clears the issue
- Reset flow: user uses Reset Track Data to rebuild legacy or incompatible track data under the new schema
- Reset flow: archived-only tracks are lost if no source files remain, and this is accepted behavior
- Manual reset flow: user confirms Reset Track Data -> track data wiped -> reimport runs immediately
- First load import flow: Empty database -> scan folders -> tracks imported
- Retry flow: Failed import -> user taps import FAB -> import retried with loading indicator
- Modified-file flow: Matching trackName + trackDate with changed contentHash replaces the prior row only when both the incoming and persisted rows have startDateTime != null
- No-date modified-file flow: changed tracks whose trackDate came from file modification time are not eligible for logical-match replacement and may import as additional rows
- Archive flow: Imported track remains available after source file disappears from disk
- Toggle tracks: Tap FAB -> tracks appear on map with preserved segments

Verify:
- ObjectBox generated files are updated for the new schema
- the macOS debug and release targets are aligned with the unsandboxed direct-distribution assumption required for direct access to ~/Documents/Bushwalking/Tracks
- flutter analyze passes
- flutter test passes
</validation>

<done_when>
1. Existing GPX entity/repository/importer have been retrofitted rather than duplicated
2. ObjectBox entity uses contentHash and no longer stores fileLocation
3. ObjectBox generated files are regenerated for the updated schema
4. Reset Track Data rebuilds legacy or incompatible non-empty track databases under the new schema
5. Import logic scans the correct macOS folders for initial and later imports, persists and renders only Tasmanian tracks, treats files in Tracks/Tasmania as out of scope for routine rescans, moves route GPX files into ~/Documents/Bushwalking/Routes, organizes GPX files using the canonical move filename rules, skips non-replacement destination path collisions with a manual-review error, rolls back failed replacement commits after a successful move, replaces matched prior rows when content changes only for metadata-date-eligible tracks, imports changed no-date tracks as additional rows, and leaves later same-operation logical-match conflicts at source path for manual review as errorSkippedCount
6. Import FAB performs retry/rescan and shows a circular progress indicator while loading, and remains disabled during recovery mode
7. Show tracks FAB toggles display on map, remains disabled while tracks are unavailable, loading, or in recovery mode, initial auto-import and startup load from valid rows set showTracks to true, manual rescan preserves the current showTracks value, and successful reset clears recovery and restores showTracks to false
8. Keyboard shortcut 't' works using the existing map keyboard pattern
9. Tracks render with #a726bc color and preserved segment boundaries
10. Geometry parsing lives in GpxTrack rather than map_screen.dart, and GpxTrack exposes LatLng-ready segments
11. Only one track operation runs at a time while isLoadingTracks is true
12. Import/loading/error states are visible to the user, including recovery hints for non-empty track data where persisted rows fail geometry decode, have empty trackPoints, have empty contentHash, or have null trackDate, shown both in Settings and in the map route shell via a snackbar and persistent recovery banner
13. The macOS debug and release targets are aligned with the unsandboxed direct-distribution assumption required for direct access to the configured Documents folders
14. No analyze errors, tests pass
</done_when>
