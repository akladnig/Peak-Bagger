# Offline walk-calendar dates

New Track imports derive the walk's day from the first `trkpt` in the first
`trkseg`, falling back only to the first `rtept`. Coordinates and an explicit
timestamp offset (`Z` or `±hh:mm`) are required on that point. Later points,
filenames, file modification dates, the Mac's timezone, and fixed Australian
Eastern offsets are not date fallbacks. Original GPX and start/end timestamps
are retained. Unresolved derivations import with an unknown date and a
reason-bearing import warning (SnackBar and Background Jobs details).

## Packaged datasets and licenses

- `timezone_finder: 1.0.0`: MIT code, geographic index from **Timezone Boundary
  Builder 2026e**, derived from OpenStreetMap worldwide land polygons. The
  package's quantized/indexed derivative database is **ODbL v1.0**.
- `timezone: 0.11.2`: BSD-2-Clause code and **IANA tzdb 2026e** historical rules.
  Use `package:timezone/data/latest_all.dart`: the reduced/default dataset
  omits linked zone identifiers used by the geographic index.
- Both datasets are embedded Dart data compiled into the macOS application;
  no runtime download, credentials, external data directory, or service is used.
  Dependency checksums/versions are locked in `pubspec.lock`.

**Time zone boundary data © OpenStreetMap contributors, available under the
Open Database License (ODbL). Boundaries built by
[Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder).**

[Full ODbL v1.0 license](https://opendatacommons.org/licenses/odbl/1-0/),
[OpenStreetMap attribution](https://www.openstreetmap.org/copyright), and
[redistributable derivative data/source](https://pub.dev/packages/timezone_finder/versions/1.0.0).
Public adaptations of the database must be offered under ODbL as well, without
technological restrictions on use. The runtime registers this data notice with
Flutter's license registry in addition to the packages' collected code licenses.

Borders are simplified to approximately **110 metres**. Coastal belts extend
approximately **22 km offshore**; uncovered open-ocean locations are unresolved.
Overlaps select the smallest containing polygon, then lexicographic identifier;
this deterministic technical rule is not a sovereignty statement. The polygons
do **not** reconstruct historical boundary movements. Historical offsets/DST
come from IANA rules for the resolved zone, not from historical polygons.

## Persistence and consumers

`trackDateStatus` is an explicit persisted discriminator: `0` legacy/unprocessed,
`1` resolved, `2` skipped legacy, `3` unresolved new import. Derivation version
starts at `1`; missing metadata is version/status `0`. Resolved dates and linked
ascent dates are UTC-midnight **calendar carriers**, not midnight instants.
`TrackDateCalendarCodec` decodes components without `toLocal()`; legacy paths
retain their former interpretation until the separate existing-data migration.
Unresolved imports retain null Track/ascent dates even during later sync.

`TrackDateDerivationService` has replaceable geographic lookup and historical
rules functions. Its offline factory initializes the full rules and embedded
index at the import/provider action boundary, once per isolate. The geographic
adapter deliberately passes **longitude before latitude**.

`TrackDerivedDataPersistence` owns new-import and replacement Track/ascent
transactions. `PeaksBaggedRepository.buildSyncPlan` updates existing rows in
place, preserving IDs and skipped/unprocessed legacy linked dates. Date
derivation happens before the transaction; consumers refresh after commit.
`TrackDateMigrationService` runs automatically at app startup for databases
without completion version `1`. The app-root `TrackDateMigrationHost` holds the
routed subtree (and its Track/ascent writers) until processing commits and the
user acknowledges the result. The Map startup boundary also waits before any
Track visibility/ascent backfill, protecting eager consumers. New imports keep
the permanent derivation path after the migration has completed.

Preparation reads original stored GPX and resolves dates outside write
transactions. The repository fingerprints all Track fields/peak memberships and
linked ascent rows, then revalidates that input in the final ObjectBox write
transaction. A competing edit/import/deletion/synchronization aborts with an
actionable retry instead of applying stale results. The transaction updates dates
and statuses in place, preserves skipped legacy dates, and commits the outcome
and `TrackDateMigrationMetadata(id: 1)` completion marker together. IDs, relations,
GPX, start/end timestamps and unrelated fields are retained. Recognized status-3
unknown imports remain status 3 when unresolved. A resolved Track counts as
unchanged when its Track and linked dates already agree, even without metadata.

The stable marker key is `track_location_calendar_day`; its record includes
completion time, geographic/IANA versions, all three counts and skipped identities
with stable reason codes. It belongs to the database and its backups, not to
installation preferences. Completed databases avoid scanning on later startup;
an older backup without the marker runs the retained version-gated path. Empty
databases commit zero counts without initializing geographic data. Failure or
interruption before commit leaves no corrected pairs or completed marker and can
be retried in-app or at next launch. App-scoped Riverpod state owns progress,
failure and retry; leaving the status widget does not cancel it. Disposing the
application owner prevents a pending attempt from committing after disposal.

The scrollable startup status shows preparation/commit progress, durable
updated/unchanged/skipped counts and actionable skipped reasons. Failure keeps
the writer barrier in place and offers `Retry`; `Continue` opens the original
route after success. Subsequent launches with a completed marker open the route
without showing a new result acknowledgement. No page-position preference or
persisted Dashboard summary is added.

## Verification

The focused `track_date_*` tests run under `TZ=Australia/Hobart` and `TZ=UTC`;
the cross-host test launches a second Flutter test process using the opposite
timezone to reopen a closed temporary ObjectBox database, then checks it again
in the originating process. Each process checks January/July host offsets.
Independent fixtures include Hobart, Los Angeles, Ljubljana and a full-dataset
zone link; tests require no network or production database.

For controlled native macOS verification, run
`flutter run -d macos -t tool/track_date_migration_smoke.dart`. Its isolated
temporary database injects one completion-write failure; use keyboard/pointer
`Retry`, inspect counts/skipped reasons, then `Continue`. Debug assertions verify
rollback and the subsequent durable correction. Quit closes the store and
deletes the fixture directory. Add
`--dart-define=MIGRATION_SMOKE_DARK=true` for the dark theme. Never use the normal
app database as a migration test fixture.
