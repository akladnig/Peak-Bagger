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
The next Work Item owns version-gated database-wide recalculation and writer
coordination; this slice performs no automatic existing-Track scan.

## Verification

The focused `track_date_*` tests run under `TZ=Australia/Hobart` and `TZ=UTC`;
the cross-host test launches a second Flutter test process using the opposite
timezone to reopen a closed temporary ObjectBox database, then checks it again
in the originating process. Each process checks January/July host offsets.
Independent fixtures include Hobart, Los Angeles, Ljubljana and a full-dataset
zone link; tests require no network or production database.
