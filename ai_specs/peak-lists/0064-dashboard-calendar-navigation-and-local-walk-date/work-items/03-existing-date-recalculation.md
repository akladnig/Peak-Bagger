---
type: Work Item
title: Automatically recalculate existing dates with progress and safe retry
parent: ../spec.md
---

## What to build

Implement the app-owned, once-per-database existing-date migration through preparation, atomic storage, startup state, visible progress/outcomes, and retry. Reuse the permanent derivation/encoding/synchronization boundaries from item 2 and retain the version-gated migration for older databases/backups.

## Required context

Paths in this section are relative to the project root.

- `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS-only, ObjectBox transaction/schema discipline, Riverpod state and resource ownership).
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`: Requirements 20 and 25–30; Technical Decisions 8–12; Testing Strategy 1, 8, and 11–12; R1–R5. Read sibling `interview-ledger.md` and `GLOSSARY.md`.
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/work-items/02-location-derived-import-dates.md` and its implemented derivation/calendar/status boundaries.
- `lib/main.dart`, `lib/startup_shell.dart`, `lib/providers/map_provider.dart`, `lib/providers/local_data_load_outcome_provider.dart`, and `lib/providers/dashboard_readiness_provider.dart` for store startup, Track loading/backfills, dependency outcomes, and UI readiness.
- `lib/services/gpx_track_repository.dart`, `lib/services/peaks_bagged_repository.dart`, `lib/services/migration_marker_store.dart`, `lib/models/route_graph_import_metadata.dart`, and `lib/services/route_graph_repository.dart` for data-access transactions and existing per-database metadata conventions. Preference flags do not satisfy this migration's database ownership.
- `test/services/gpx_track_repository_test.dart`, `test/services/peaks_bagged_repository_test.dart`, `test/providers/map_provider_import_test.dart`, `test/providers/map_provider_track_replacement_test.dart`, and `test/widget/dashboard_readiness_test.dart` for temporary-store, injected failure, provider, and startup/readiness conventions.
- The old preference-gated `wipeAndImport` path, Track-null recovery check, and ascent rebuild are implementation conflicts described in Technical Decision 12, not approval to destroy or renumber existing records.

## Acceptance criteria

- [x] Add database-owned singleton `TrackDateMigrationMetadata` with assignable `id = 1`, stable migration key `track_location_calendar_day`, `completedVersion` initially targeting `1`, completion timestamp, Timezone Boundary Builder/IANA dataset versions, updated/unchanged/skipped counts, and serialized skipped-record identities/reasons. Use ObjectBox, not SharedPreferences, for the authoritative completion record.
- [x] At the next app launch, automatically process an existing database without completed version `1`; absent completion metadata means incomplete. A fresh empty database can atomically record current version and zero counts. Completed databases skip scanning on later launches, including databases restored with their completed marker; an older opened/restored database without the marker triggers processing regardless of installation preference flags.
- [x] Read each existing Track's original stored `gpxFile`, using item 2's first-point/location/historical-rule derivation. Do not use repaired/filtered/later-point, filename, modification-date, host-local, Australian Eastern, or stored-start fallback sources to invent its day.
- [x] On successful resolution, update `trackDate`, all linked `PeaksBagged.date`, and per-Track metadata consistently with status `1` and derivation version `1`. Preserve Track IDs, bagged-row IDs, associations, counts, first-climb meanings, GPX XML, and start/end timestamps. Corrected dates remain UTC-midnight calendar carriers decoded without `toLocal()`.
- [x] Unresolvable existing GPX/time/coordinates/timezone/rules preserve every existing Track/linked date unchanged and record processed-skip status `2`, derivation version `1`, identity, and actionable reason. A processed skip does not cause automatic rescanning on every launch; retain legacy decoding without claiming recovered calendar-day correctness.
- [x] Prepare GPX/timezone outcomes outside ObjectBox transactions. Coordinate competing Track/ascent writers throughout the operation; perform the Track/date/status changes, linked-date changes, persisted outcome summary, and completion marker in one final ObjectBox write transaction inside the data-access boundary. Revalidate/protect the prepared inputs against competing writes rather than committing stale replacements.
- [x] Injected linked-date, metadata, or completion-marker write failure rolls back the entire final attempt. Failure/interruption before commit leaves version incomplete and retries safely in-app or on next launch without duplicated records, partially corrected pairs, lost relations, or changed IDs. Operational failures are not silently counted as successful completion.
- [x] Count resolved Tracks as unchanged when their canonical Track date and linked dates already agree, even when metadata must be recorded; otherwise count them updated. Updated/unchanged/skipped counts account for processed Tracks and match the durable summary; skipped details identify their Track and actionable reason.
- [x] Expose preparation/commit progress, completion with all three counts and skipped reasons, and diagnostic-logged operational failure with actionable retry through app-owned Riverpod state. Widgets render outcomes and dispatch retry; they do not own database writes or cancel app-owned migration simply by leaving a screen. Protect duplicate starts/retries before awaited work, dispose resources deliberately, and prevent stale/post-disposal UI updates.
- [x] Publish success only after the final durable commit, then refresh Track/ascent projections coherently, including Dashboard readiness and dependent summaries. Loading must not briefly present no-data/success, and failures remain observable without replacing existing dependency reporting or routes. Running migration/backfills must not overwrite each other's dates.
- [x] Recognized status-`3` imports remain valid unknown-date Tracks. Supported existing/restored databases must not enter preference-gated wipe/reimport merely because installation flags are absent. Avoid incompatible ascent rebuild/backfill renumbering; subsequent sync preserves skipped dates/IDs and status-`3` nulls instead of recreating fallbacks.
- [x] Retain this small version-gated scanning/orchestration path for older databases/backups after success, and retain durable metadata. Removal requires separately scoped supported-baseline cleanup; no baseline/removal date is invented here. Permanent derivation for future imports remains in item 2.
- [x] Add temporary-ObjectBox tests for legacy Mac-local/UTC Track representations and Australian-Eastern ascent dates, mixed updated/unchanged/skipped results, preservation, atomic rollback, marker failure, interruption/retry/idempotency, completed-startup no-op, fresh empty databases, old backups without markers, absent installation preferences, and writer coordination. Add deterministic provider/widget progress/warning/failure/retry coverage with stable selectors.
- [x] Use stable equivalent selectors for progress, result counts, skipped details, failure and retry, scoped to the status surface. Use injected GPX/lookup/storage failures and controlled clocks; no production database/live timezone service/API keys. Close stores before deleting temporary directories and dispose containers/subscriptions. Follow behavior-first regressions without adding a strict TDD mandate.
- [x] Regenerate entity output with the documented command, preserve ObjectBox UIDs/model history, and review source plus `lib/objectbox-model.json` / `lib/objectbox.g.dart` together. Preserve macOS/Desktop wide semantic light/dark styling, reachable progress/retry details, keyboard focus, and accessible actions; use shared component rules if a popup/dialog is used.

### Verification

Create `test/services/track_date_migration_repository_test.dart`, `test/services/track_date_migration_service_test.dart`, `test/providers/track_date_migration_provider_test.dart`, and `test/widget/track_date_migration_status_test.dart`. Extend item 2's `test/services/track_date_cross_host_persistence_test.dart` to migrate/write and close a database in one timezone process, then reopen it in the other; also exercise the reverse direction. Assert actual host offsets and independently expected corrected days, including a non-Australian walk.

```sh
dart run build_runner build --delete-conflicting-outputs
TZ=Australia/Hobart flutter test \
  test/services/track_date_migration_repository_test.dart \
  test/services/track_date_migration_service_test.dart \
  test/services/track_date_cross_host_persistence_test.dart \
  test/providers/track_date_migration_provider_test.dart \
  test/widget/track_date_migration_status_test.dart
TZ=UTC flutter test \
  test/services/track_date_migration_repository_test.dart \
  test/services/track_date_migration_service_test.dart \
  test/services/track_date_cross_host_persistence_test.dart \
  test/providers/track_date_migration_provider_test.dart \
  test/widget/track_date_migration_status_test.dart
TZ=Australia/Hobart flutter test \
  test/services/gpx_track_repository_test.dart \
  test/services/peaks_bagged_repository_test.dart \
  test/providers/map_provider_import_test.dart \
  test/providers/map_provider_track_replacement_test.dart \
  test/widget/dashboard_readiness_test.dart
flutter analyze
TZ=Australia/Hobart flutter test
```

Run the parent Spec's exact Testing Strategy 8 focused block as well. Record an actual macOS startup/retry/status check using controlled data as implementation evidence, not a claim derived from documentation or the isolated research probe.

### Completion evidence — 2026-10-16

- Added database-owned `TrackDateMigrationMetadata` (entity 18, singleton ID 1), retaining every existing ObjectBox entity/property/relation UID and retired history. Regenerated with `dart run build_runner build --delete-conflicting-outputs`; the installed generator reported that flag as removed/ignored. Reviewed the model and generated bindings with the source; no generated output was hand-edited.
- `TrackDateMigrationService` reuses item 02's original-GPX/location/historical-rule derivation, yields preparation progress, and commits through `ObjectBoxTrackDateMigrationRepository`. The final write transaction revalidates SHA-256 fingerprints of all Track fields/memberships and ascent rows, updates date/status fields and linked dates in place, and durably writes the counts/skipped details/completion marker together. Injected Track, linked-date, metadata and post-marker failures all roll back. Interrupted preparation, changed input, duplicate starts, retry/idempotency, empty databases, completed no-op, and older backups without metadata are covered.
- Production injects the repository from the opened store. App-scoped Riverpod state and the root `TrackDateMigrationHost` run before the routed subtree and its Track/ascent writers mount. Eager Map startup also waits before visibility/ascent backfills; a real MapNotifier/temporary-store regression with absent installation flags verifies committed projections, original IDs, skipped dates and status-3 nulls. The existing non-destructive startup decision and row-preserving synchronization from item 02 remain applicable.
- The scrollable status surface exposes preparation/commit progress, operational failure and `Retry`, and durable updated/unchanged/skipped results with selectable identity/reason details. `Continue` opens the original routed content; completed subsequent startup avoids another acknowledgement/scan. Widget regressions cover light/dark themes, keyboard activation, enlarged text/short-height representative constraints, writer gating, route preservation, leaving/remounting status UI during app-owned work, and app-owner disposal. These fixtures select no new minimum-window values or profile exceptions.
- Added all four planned test files and the shared temporary-database fixture. Extended the cross-host persistence test to migrate legacy Track/ascent carriers, close the store, reopen in the opposite host-timezone process, verify the durable completion record/no-op and expected Hobart/Los Angeles days, then reopen in the origin. Both host processes assert January/July offsets; both origin directions passed. Stores close before temporary-directory deletion.
- Migration-focused tests: **20 passed under UTC**; the final Hobart migration-focused run plus the affected schema/inventory regressions: **53 passed** (20 migration tests). Earlier five-file focused runs passed in both host zones before the additional eager-startup regression. Required existing repository/import/replacement/readiness block: **29 passed, 1 pre-existing skip**. Parent Testing Strategy 8's exact nine-file focused block: **74 passed**.
- Final `flutter analyze`: **no issues**. Final complete `TZ=Australia/Hobart flutter test`: **2,342 passed, 5 skipped**. The first full run exposed the expected new-entity schema assertion and missing smoke-tool inventory entry; both were corrected before the successful final full run. `git diff --check` passed.
- Actual macOS check: built/launched `flutter run -d macos -t tool/track_date_migration_smoke.dart --no-resident` using a fresh system-temporary fixture store. Observed the injected completion-write failure and reachable semantic error/Retry; Tab/Enter retried successfully. Observed `Updated: 1`, `Unchanged: 0`, `Skipped: 1`, the missing-timestamp Track identity/reason, and reachable `Continue`; keyboard Continue opened the controlled completion content. Local screenshots `spec0064-migration-failure.png`, `spec0064-migration-complete.png`, and `spec0064-migration-continued.png` were captured in the agent temporary workspace. Native dark-target launch also built successfully; dark visual assertions are supplied by the deterministic widget tests. No production database or live mapping/timezone service was used by the smoke target.
- Final normal-target `flutter build macos --debug`: **passed**. Xcode emitted the existing non-fatal CoreSimulator-version warning; Flutter reported ObjectBox's existing Swift Package Manager warning. `docs/track-date-timezones.md` describes lifecycle/retry/marker semantics and the reusable controlled smoke command, which is classified as store-isolated in the existing tool inventory.

## Covers

- User Stories: 7.
- Requirements: 20 (allowed migration metadata/refresh); 25–30 (existing-data processing and lifecycle).
- Technical Decisions: 1–2; 8; 10–12.
- Testing Strategy: 1; 8; 11–12 (migration/startup/atomicity/consumer refresh).
- Interview Ledger: no new interview record; this expanded migration scope is approved explicitly by R1–R5. Preserve L2's independent timestamp-display distinction.
- Approved refinement decisions: R1–R5.

## Blocked by

- [02-location-derived-import-dates.md](02-location-derived-import-dates.md)
