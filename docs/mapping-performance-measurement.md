# Mapping startup and route measurement protocol

Spec 0063, Work Item 02. Instrumentation is enabled with
`--dart-define=MEASURE_PERFORMANCE=true`; normal builds do not write measurement
records. This is diagnosis instrumentation, not a startup or routing optimization.

## Qualifying dashboard endpoint

`dashboard.local_data_ready.frame` identifies completion of a **framework** frame
with successfully loaded local content. `dashboard.local_data_ready.frame.rasterized`
attaches the matching engine frame's raster-finish timestamp. Neither shell
handoff nor ObjectBox initialization is a dashboard-ready measurement.

The observer watches the actual loaders supplying visible and off-screen cards:

| Dependency | Outcome source | Content/settings covered |
| --- | --- | --- |
| `dashboard-layout` | `dashboardLayoutReadProvider` | Successful preferences read, including absent saved order; sanitized order applied by the existing layout notifier |
| `peak-info-settings` | `peakMarkerInfoReadProvider` | Latest Walk peak-information setting, including successful absence/default |
| `peak-info-hydration` | `peakMarkerInfoHydrationProvider` | The read value has been applied, or a newer user toggle deliberately retained; fallback state before hydration cannot qualify |
| `tracks-migrations-settings` | `mapDashboardLoadProvider` | Existing map startup chain: visibility backfill/preferences, peak import/backfill, persisted tracks, migration decision and bagged-history backfill/imports |
| `track-presentation` | Existing `MapState.isLoadingTracks` | The visible cards must no longer present their track-loading state; this flag alone is not read-success evidence |
| `peak-lists` | Existing `peakListsLoadProvider` | Actual list repository read, not its cached failure fallback |
| `my-lists` | `myListsSummaryReadProvider` | Per-list membership reads and derived rows |
| `list-ascent-dates` | `myListsAscentDatesReadProvider` | Actual climbed-peak date read, separately from its empty UI fallback |
| `my-ascents` | `myAscentsSummaryReadProvider` | Bagged rows and stored peak index, separately from the existing empty UI fallback |
| `main-navigation` | Mapping failure-dialog host/coordinator | No blocking Mapping failure modal covering navigation |

Async outcomes distinguish pending, successful (including legitimately empty),
and failed. Required failures emit `dashboard.dependency.failed` with their
dependency name, retain the existing UI behavior, and suppress readiness.
The final map startup transition refreshes ascent/list reads after any backfill.
Summary period/mode and ascent sorting currently have widget-local defaults,
not saved preferences. Production theme preferences are read during ready
initialization and applied synchronously from its bootstrapped preferences.

The observer starts data providers even when their cards are off-screen; it does
not construct or scroll those widgets. Existing summary-header callbacks finish
before the qualifying frame. Remote Latest Walk tiles and unrelated bootstrap
work are excluded unless they actually block the UI endpoint. Offstage/noncurrent
screens do not qualify. The deterministic tests prove these semantics, not the
5,000 ms hardware ceiling.

## Clocks, launch and frame evidence

Build once **before** timing:

```sh
flutter build macos --release --no-pub \
  --dart-define-from-file=dart_defines.local.json \
  --dart-define=MEASURE_PERFORMANCE=true \
  --dart-define=MEASUREMENT_TRANSPORT=smbfs
```

Use the observed transport (`smbfs` for the before-cutover MacBook, local APFS
for an actually provisioned replica), not a guessed cause. The log includes build
mode, selected root, and SHA-256 of `region_manifest` text + NUL + polygon-manifest
text. This manifest identity is **not** full payload-integrity/eligibility proof;
retain the read-only inventory's per-file digests for dataset comparisons.

Quit the existing app normally. With a verified existing local log directory:

```sh
python3 tool/measure_built_macos_app.py \
  build/macos/Build/Products/Release/peak_bagger.app \
  --condition process-cold --repetition 1 --seconds 0 --detach \
  --output /absolute/local/logs/startup-01.log
```

The native runner reads this process's kernel birth time with
`proc_pidinfo(PROC_PIDTBSDINFO)`. It correlates the birth `timeval` to
`mach_absolute_time` using a bracketed `gettimeofday` sample, publishing
`process_launch_monotonic_us` and the conversion uncertainty. This includes native
and Flutter startup before any Dart initialization. Discard runs spanning sleep
or system wall-clock adjustments during this initial correlation.

The foreground launcher additionally uses LaunchServices and sets a Python
`time.monotonic_ns()` anchor immediately before dispatch. macOS implements that
clock using `mach_absolute_time`. `dispatch_to_endpoint_upper_bound_us` includes
LaunchServices overhead and is distinct from the kernel process-launch endpoint.
The non-detached launcher directly starts the built executable with
an anchor before process creation and filters stdout to JSON records; distinguish
that launch condition from ordinary foreground app launching. Native delegate
entry (`native_entry_us`) is recorded separately and is not substituted for launch.
Compilation, Flutter/Xcode startup and debugger attachment are outside both runs.

Flutter brackets one native method-channel sample with `Timeline.now`. Offset is
native sample minus bracket midpoint; half the round-trip is logged as
`clock_uncertainty_us`. `launch_to_endpoint_upper_bound_us` adds that uncertainty
and the kernel-birth conversion uncertainty. On older diagnostic runs lacking
the birth record, this field was a pre-dispatch upper bound; identify those
explicitly rather than calling them exact kernel process-launch measurements.
Inspect the bracket, native entry, launch method and run ID; discard runs spanning
sleep, human permission prompts, lost/colliding logs, or instrumentation changes.
`process-cold` means a new app process, **not** flushed filesystem/SMB/GDAL caches.

Engine timings arrive in batches. Correlation retains the last engine frame
whose build began before the framework post-frame marker, and bounds it with an
explicitly requested following frame. Records retain frame number, build start/
finish, callback timestamp, next build start, raster duration and raster finish.
Use the frame's timestamp, not timing-callback arrival. A raster-finish record is
stronger than framework paint, but **not a WindowServer/display presentation
timestamp**. Confirm visible content and navigation separately; do not claim
exact physical display latency from Flutter's timing API.

Detached logs keep stdout and stderr separate (`.stderr` sibling). Point both at
the same file and independently opened descriptors can overwrite each other's
evidence. Raw logs/screenshots remain local; publish only reviewed non-sensitive
measurement summaries. No private defines, personal database/GPX content, or
private configurations belong in workflow artifacts.

## Startup workload capture (separate run)

Add `--dart-define=MEASURE_WORKLOAD=true` to make a separate read-only summary
run. `workload.read-only-summary` reports relevant record counts, total stored GPX
track vertices and display-cache vertices per zoom, named migration/backfill flags,
saved dashboard order/peak-info/theme settings, and graph generation metadata.
It exports no track names, IDs, coordinates or GPX/database bytes. Parsing all
stored geometry is intentionally expensive: **rebuild without this flag for
timed runs**. A summary failure is reported, not silently considered an empty
workload. Capture again after runs and compare counts/settings/generations.

Freeze window size/text scale, dataset inventory/identity, ObjectBox workload,
migration state, launch conditions and repetitions before optimization. Preserve
individual samples and maximum; different workloads must have different labels.
Initial synchronization and first imports are separate runs, not provisioned
startup samples. The phase log separates manifest/path checks, polygon/catalog,
ObjectBox preparation/open/schema, preferences/tile-cache initialization,
post-shell graph bootstrap, and dashboard data/import/backfill work. Phase return
success alone is not endpoint readiness: existing functions can retain fallbacks.

## Route endpoints and fixed cases

`route.placement.accepted` is emitted only when existing placement guards accept
a new control endpoint, with exact clicked and control coordinates, mode,
placement number and first-subsequent/repeated condition. Its stopwatch begins
before the synchronous placement work. Duplicate/rejected clicks do not count.

Ordinary first points emit `route.start-feedback.frame`, separately from the
complete-segment endpoint and the 100 ms ceiling. They do not sample segment
elevation. The existing controls require a start marker before enabling the
Route to Peak button. This button immediately routes from the existing last
point. Its distinct `route.mode-action.accepted` →
`route.mode-action.complete.frame`/`.rasterized` span includes current geometry
and statistics, without relabelling the earlier ordinary first point. The
provider's preselected Route-to-peak first-placement flow is likewise supported
by the point observer when exercised through an entry point allowing it.

`route.complete-update.frame` waits for committed geometry, current geometry/
elevation request versions, point elevations and refreshed elevation/ascent/
descent. It rechecks the same geometry and summary in the frame callback, rejects
cancelled/superseded/failed work, and has a `.rasterized` companion. Records include
new-segment/cumulative length, geometry vertices and statistics. Use individual
placements and their **maximum** against 1,000 ms (500 ms desired), not averages
or the endpoint marker appearing early. Graph loading/planning, DEM path validation,
first DEM opening, geometry-point sampling and densified summary sampling have
separate phase records. A 50 ms process-lifetime heartbeat reports UI-isolate gaps
over 100 ms; it does not prove a macOS spinning cursor was displayed.

The baseline record must freeze real Tasmania Snap-to-trail coordinates for fresh
and accumulated drafts, segment/draft lengths/vertices, build/dataset/ObjectBox/
graph conditions, and repetitions. Exercise fresh launches with first lazy DEM/
graph access and repeated use. Record Straight-line and Route-to-peak separately.
Check geometry, snapping, statistics, responsiveness and spinning-wheel observations.
Keep failed placements as failures, not zero-duration samples. Deterministic fake
tests cannot replace native GDAL/UI measurements.

Executed observations and any remaining gate gaps are recorded in
[the baseline record](mapping-performance-baseline.md).
