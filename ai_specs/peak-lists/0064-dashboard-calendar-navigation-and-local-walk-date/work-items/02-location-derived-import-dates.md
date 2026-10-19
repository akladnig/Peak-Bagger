---
type: Work Item
title: Import location-derived Track dates and preserve them through consumers
parent: ../spec.md
---

## What to build

Deliver the permanent location-day import flow through injected derivation, ObjectBox status/calendar encoding, peak-ascent synchronization, date consumers, and visible unknown-date warnings. Provide a canonical/legacy decoding boundary reusable by the existing-data migration and timeline work; this item does not scan/recalculate all existing Tracks automatically.

## Required context

Paths in this section are relative to the project root.

- `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS-only, ObjectBox/Riverpod/GoRouter, lifecycle and observable async outcomes).
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`: Requirements 20 and 24–27; Technical Decisions 1–2 and 8–12 (import portions); Testing Strategy 1, 8, and 10–12; R1–R2 and R4–R5. Read sibling `interview-ledger.md` and `GLOSSARY.md`; L2's original importer exclusion was expanded explicitly by R1, not silently discarded.
- `pubspec.yaml` and `pubspec.lock` for the approved dependencies and reproducible resolution.
- `lib/services/gpx_importer.dart`, `lib/services/import/gpx_track_import_models.dart`, `lib/models/gpx_track.dart`, `lib/models/peaks_bagged.dart`, `lib/services/gpx_track_repository.dart`, and `lib/services/peaks_bagged_repository.dart` for import, serialization, storage, and sync conventions.
- `lib/providers/map_provider.dart`, `lib/widgets/gpx_import_dialog.dart`, `lib/services/summary_card_service.dart`, `lib/services/year_to_date_summary_service.dart`, `lib/services/track_date_query_parser.dart`, `lib/services/map_search_service.dart`, `lib/services/my_ascents_summary_service.dart`, `lib/providers/my_ascents_summary_provider.dart`, and `lib/core/date_formatters.dart` for recovery, warnings, date search/grouping, and projections. Audit other affected Track/ascent consumers and filename formatting too.
- `test/gpx_track_test.dart`, `test/services/gpx_importer_selective_import_test.dart`, `test/services/gpx_track_repository_test.dart`, `test/services/peaks_bagged_repository_test.dart`, `test/providers/map_provider_import_test.dart`, and `test/providers/map_provider_track_replacement_test.dart` for temporary-store, import, rollback, and provider conventions.
- Historical conflicts: `ai_specs/tracks/005-gpx-tracks-spec.md` allows Mac-local/file-date derivation and treats every null Track date as recovery; `ai_specs/bags/peaks-bagged-date-fix-plan.md` uses Australian Eastern fallback. The parent Spec's R1–R2/R5 and Technical Decision 12 supersede those affected behaviors. Preserve unrelated import/deduplication/repair behavior.

## Acceptance criteria

- [x] Add exactly the initially approved `timezone_finder: 1.0.0` and `timezone: 0.11.2`, maintaining compatible reproducible resolution in `pubspec.lock`. Initialize `package:timezone/data/latest_all.dart` and embedded macOS geographic data; use no runtime download, external-machine dataset, credentials, longitude/current-offset approximation, or Mac-local timezone fallback.
- [x] Document Timezone Boundary Builder 2026e/OpenStreetMap land-polygon provenance and IANA tzdb 2026e, MIT geographic code, ODbL boundary data, and BSD-2-Clause rules-package code. Include required OpenStreetMap/Timezone Boundary Builder attribution and data-license information. Preserve the approved approximately 110-metre border simplification, documented coastal coverage/overlap handling, and lack of historical geographic-boundary reconstruction as dataset limitations, not a claim of exact historical polygons.
- [x] Inject `TrackDateDerivationService` and replaceable geographic/rules dependencies through existing provider/construction seams. Adapt the package's longitude-before-latitude API deliberately. Initialize required data at an explicit owned boundary, not repeatedly during widget rendering.
- [x] Select the first `trkpt` in the first `trkseg`, falling back to the first `rtept`; derive from that point's coordinates and valid, unambiguous recorded timestamp in original GPX. Apply the resolved zone's historical rules at the recorded instant before extracting year/month/day. Do not substitute a later point, file modification/name date, fixed Australian Eastern rules, or the host timezone. Reject unusable/non-finite/out-of-range coordinates and missing/invalid/ambiguous timestamps as unresolved derivation outcomes.
- [x] Persist successful `trackDate` and linked `PeaksBagged.date` as `DateTime.utc(year, month, day)` in the existing `dateUtc` fields. UTC midnight is a calendar carrier, not the walk's midnight instant. Required Track/ascent writes are atomic through the data-access boundary; preserve IDs, associations, peak counts and first-climb meanings, GPX content, and start/end timestamps. Expose explicit action/data-access ownership so item 3 can subsequently coordinate these same writers during migration.
- [x] Add persistent `trackDateStatus` codes `0` legacy/unprocessed, `1` resolved, `2` legacy skipped, `3` unresolved new import; `trackDateDerivationVersion` (`0` unprocessed, initially `1` after processing); `trackDateTimezoneId` when resolved; and stable `trackDateFailureReason` codes mapped to actionable feedback. Preserve fields through `toMap`/`fromMap`, cloning, replacements, and ObjectBox. Missing old metadata decodes as `0`, never inferred from `isUtc`, a midnight-looking value, or `startDateTime != null` alone.
- [x] Corrected days survive serialization, ObjectBox round-trips, formatting, date-range search, timeline/day and year grouping, future-date comparisons, and endpoint consumption without `toLocal()` shifting them. Preserve legacy/unprocessed and skipped values and their legacy interpretation; do not pretend their original intended day has been recovered. Keep Latest Walk's separate Mac-local timestamp display intact.
- [x] For unresolved new-import derivation, allow the import with `trackDate = null`, status `3`, unknown linked ascent dates, and a visible reason-bearing warning. Cover missing/invalid/ambiguous time, unusable coordinates/GPX, and geographic/rules resolution failures under Requirement 27. Retain ordinary unknown-date display/metric eligibility, and do not mark a recognized status-`3` null date as damaged data merely because it is null. Preserve genuine unrelated recovery checks.
- [x] Subsequent peak-ascent synchronization uses resolved canonical Track days, retains unknown dates for status `3`, and preserves existing linked dates for skipped legacy Tracks. It must not silently restore timestamp, file-date, Mac-local, or Australian Eastern fallbacks; update existing rows without rebuilding their IDs as part of date correction.
- [x] Import warnings/results are exposed through state/action boundaries and visible UI; diagnostics log technical context separately. Use existing import feedback mechanisms and exact existing route/interaction contracts, preserving input on recoverable failure, duplicate prevention, and owned async lifecycle. No new route or unrelated import redesign is introduced.
- [x] Add independently known GPX/zone/offset/day fixtures for Hobart and at least one non-Australian walk whose location day differs from the Hobart host day; include midnight/year rollovers, historical DST, first-point convention, geographic/rules failures, and a zone identifier requiring `latest_all`. Verify absence of prohibited fallbacks and visible unknown-date import warnings.
- [x] Add the planned tests named below. Cross-host persistence coverage must write a temporary ObjectBox database in one host-timezone process, close it, reopen it in the other, and prove identical corrected Track/linked calendar components; changing a local `DateTime` constructor is insufficient. Close stores before removing temporary directories and dispose containers/controllers. Tests use no live timezone service, user database, API keys, or network dependency.
- [x] Edit entity source and regenerate with the command below; retain ObjectBox entity/property UIDs and model history, review `lib/objectbox-model.json` with `lib/objectbox.g.dart`, and never hand-edit generated output. Behavior-first regressions are required; no extra strict TDD mandate is added.

### Verification

Create these concrete test surfaces in this slice: `test/services/track_date_derivation_service_test.dart`, `test/services/track_date_calendar_codec_test.dart`, `test/services/track_date_persistence_test.dart`, `test/services/track_date_cross_host_persistence_test.dart`, `test/services/track_date_import_test.dart`, and `test/widget/track_date_import_warning_test.dart`. Extend the existing import/repository/provider/consumer tests in Required context.

Run from the project root. Each cross-host process must assert actual expected host offsets (Hobart January `+11:00`, July `+10:00`; UTC `+00:00`) and identical independently expected location days. Keep Hobart-specific Latest Walk expectations in the Hobart run.

```sh
dart run build_runner build --delete-conflicting-outputs
TZ=Australia/Hobart flutter test \
  test/services/track_date_derivation_service_test.dart \
  test/services/track_date_calendar_codec_test.dart \
  test/services/track_date_persistence_test.dart \
  test/services/track_date_cross_host_persistence_test.dart \
  test/services/track_date_import_test.dart \
  test/widget/track_date_import_warning_test.dart
TZ=UTC flutter test \
  test/services/track_date_derivation_service_test.dart \
  test/services/track_date_calendar_codec_test.dart \
  test/services/track_date_persistence_test.dart \
  test/services/track_date_cross_host_persistence_test.dart \
  test/services/track_date_import_test.dart \
  test/widget/track_date_import_warning_test.dart
TZ=Australia/Hobart flutter test \
  test/gpx_track_test.dart \
  test/services/gpx_importer_selective_import_test.dart \
  test/services/gpx_track_repository_test.dart \
  test/services/peaks_bagged_repository_test.dart \
  test/providers/map_provider_import_test.dart \
  test/providers/map_provider_track_replacement_test.dart
flutter analyze
TZ=Australia/Hobart flutter test
```

Also run the parent Spec's exact Testing Strategy 8 focused block and affected consumer tests; the isolated research probe is not project verification. Preserve macOS/Desktop wide behavior with semantic light/dark feedback and accessible warnings/actions.

### Completion evidence — 2026-10-16

- `TrackDateDerivationService.offline()` initializes full `latest_all` rules and the embedded 2026e geographic index at the action/provider boundary. Independent Hobart, Los Angeles, and Ljubljana fixtures verify geographic identity, historical offsets, midnight/year rollover and a linked identifier omitted by the reduced rules dataset. The adapter deliberately passes longitude before latitude. Invalid inputs and lookup/rules failures have stable actionable reason codes.
- Both import paths derive from original GPX before filtering/repair, persist explicit status/version/zone/reason metadata, and use `TrackDerivedDataPersistence` for atomic Track/ascent writes. Temporary ObjectBox tests inject linked-write failure for new and replacement imports, verify rollback, IDs/associations and unchanged original GPX/timestamps, and exercise later synchronization with canonical, unknown, and skipped legacy dates.
- `TrackDateCalendarCodec` is the reusable status-aware boundary for timeline, year, search, ascent and filename consumers. Legacy callers retain their prior local/component interpretation; search-result regression coverage explicitly distinguishes legacy, resolved and unresolved dates. Latest Walk retains its independent Mac-local timestamp display.
- Unknown imports expose reason-bearing state/results, SnackBars and Background Jobs details. Light/dark widget tests exercise the real import action and visible details. Import-start failures keep selected files/edited names for retry. Startup recognizes status-3 null dates while retaining other recovery checks; a restored database without installation preference flags keeps Track/ascent IDs and relationships. Startup ascent backfill now synchronizes rather than recreating row IDs.
- Dataset provenance, licenses, attribution, coastal/overlap/border limitations, packaging and writer ownership are recorded in `docs/track-date-timezones.md`; the separate ODbL data notice is registered with Flutter's license registry. `pubspec.lock` is now tracked (its former ignore entry was removed) to preserve the approved dependency resolution.
- Generated ObjectBox model review confirms only four new GpxTrack properties (37–40); existing entity/property/relation UIDs and retired history are retained. Ran the specified build-runner command successfully; the installed build-runner reports `--delete-conflicting-outputs` as obsolete/ignored. Generated Dart bindings were not hand-edited.
- Six-file date-focused block: **21 passed under Hobart and 21 under UTC**. Each process asserts actual January/July host offsets. The cross-host test closes a temporary database, starts another Flutter process in the opposite timezone to read/write it, closes that store, and reopens it in the originating process. No production data or runtime service is used.
- Existing import/repository/provider block: **111 passed, 3 pre-existing skips**. Parent Testing Strategy 8's exact nine-file focused block: **74 passed**. Affected ascent/search/year/admin-export/import-dialog consumer block: **75 passed**. Complete `TZ=Australia/Hobart flutter test --reporter expanded`: **2,323 passed, 5 skipped** after fixing the legacy search-result regression. An initial full-suite attempt hit the shell's ten-minute limit; the final complete run used a longer timeout.
- `flutter analyze`: **no issues**. `flutter build macos --debug`: **passed**; Xcode emitted a non-fatal installed CoreSimulator-version warning and Flutter reported ObjectBox's existing Swift Package Manager warning. No native-app visual session was performed; light/dark warning feedback is covered by widgets on the macOS host. This slice requires none of the profile's Pending layout/window dimensions and proposes no exception.
- Database-wide scanning, singleton completion metadata and migration coordination remain Work Item 03; this slice establishes its permanent derivation/decoding/write boundaries.

## Covers

- User Stories: 6.
- Requirements: 20 (offline/data-write/refresh boundary); 24–27 (permanent import, encoding, consumers, unresolved-date and sync contracts).
- Technical Decisions: 1–2; 8–10 (per-Track metadata; database singleton is item 3); 12 (import/recovery/synchronization).
- Testing Strategy: 1; 8; 10–12 (derivation/import/persistence/consumer portions).
- Interview Ledger: L2 (timestamp versus Track-date distinction); import scope is explicitly expanded by R1 rather than inferred from the original L2 answer.
- Approved refinement decisions: R1–R2; R4–R5.

## Blocked by

None - ready to start
