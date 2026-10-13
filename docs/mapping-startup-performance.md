# Provisioned local Mapping startup performance

Spec 0063, Work Item 09. This record separates the historical SMB workloads in
`mapping-performance-baseline.md` from the current local-replica workload. The
endpoint and clock protocol remain `mapping-performance-measurement.md`.

## Fixed workload C — recorded before optimization, 2026-10-14

The separate read-only summary run `d6a352da-1f83-4a74-a311-5b590caecadc`
activated the already validated generation `2be1ef1d-0f92-41a7-ae7d-722142dee4d1`.
Its root is the concrete `generations/<UUID>/payload` directory under
`~/Library/Application Support/com.example.peakBagger/MappingRuntimeReplica` on
local APFS. No explicit machine config exists; the app uses its replica default.
Initial replication/validation already completed in Item 08. No dataset imports
are required in these provisioned launches.

| ObjectBox entity | Records |
| --- | ---: |
| GpxTrack | 198 |
| Peak | 46,659 |
| PeaksBagged | 132 |
| PeakList | 10 |
| PeakListItemEntity | 9,776 |
| Route | 80 |

Stored GPX vertices: **168,046**. Stored display-cache vertices:

| Zoom | Vertices | Zoom | Vertices |
| --- | ---: | --- | ---: |
| 6 | 444 | 13 | 7,756 |
| 7 | 517 | 14 | 13,694 |
| 8 | 664 | 15 | 24,393 |
| 9 | 987 | 16 | 43,818 |
| 10 | 1,515 | 17 | 77,553 |
| 11 | 2,595 | 18 | 127,908 |
| 12 | 4,434 | | |

All four named track optimization, bagged-history, item-visibility and list-coverage
migration/backfill flags remain true. Both existing `route-graph-v5` coverages
remain ready: Tasmania generation 3 (1,508,432 nodes / 113,168 ways / 4,709 chunks),
Northeast Alps generation 4 (7,780,038 nodes / 558,284 ways / 4,081 chunks), with
the source hashes recorded in Item 02 unchanged.

Saved order: `latest-walk`, `year-to-date`, `peaks-bagged`, `elevation`, `distance`,
`my-lists`, `my-ascents`. Peak information true; theme dark / baseColor / content /
0.0. Content window **1710 × 1041**, native **1710 × 1073**, text scale **1.0**.
These are observed benchmark values, not resolutions of pending profile minima.
No layout changes are scoped here. ADS-1.0 and Desktop wide/macOS apply; no
foundation replacement or shared-rule exception is proposed.

Manifest-pair SHA-256:
`0c2bf374beaffa0c12f5adf587d16d97905a06db2369a9588cdf341ac21c3baa`.
The generation retains Item 08's complete 25-file / 4,255,657,108-byte validated
inventory. Integrity hashing is background-pipeline evidence, not launch work.
User-added records distinguish workload C from historical A/B; none are deleted
or copied to make the benchmark easier.

Freeze **one process-cold and one repeated launch** before and after optimization,
using the already-built ARM64 macOS **release** app, summary flag off, no debugger.
Use LaunchServices foreground launch, kernel process birth correlated to
`mach_absolute_time`, the bracketed Flutter/native sample and the first matching
`dashboard.local_data_ready.frame.rasterized` engine frame. Retain individual
totals and their maximum against **5,000 ms**, including clock uncertainty.
Process-cold means a new process, not flushed OS caches. Recheck the same read-only
summary after verification; record any deviations as another workload.

## Diagnosis

The summary-on launch is **not a timed sample**. Its Mapping preflight is local
and succeeds, but graph bootstrap takes **113,434 ms**, stalling the UI isolate.
A native process sample during that phase shows Dart microtask CPU work on the
main thread; RSS reached approximately 8.4 GiB. Code inspection finds full-table
materialization in legacy migration and active coverage checks, plus JSON payload
counting for millions of graph nodes. The existing completed migration marker
does not prevent repeated legacy scans. Further before/after phase and endpoint
evidence is recorded below when executed; this observation does not prove an
SMB-only cause or satisfy the startup ceiling.

## Implemented change and preservation boundary

The provisioned catalog bootstrap now awaits full stored-graph validation in
ObjectBox's `runInTransactionAsync` worker rather than executing it synchronously
during `App.build`. Legacy cleanup also runs in a worker transaction and removes
exact empty-coverage rows through native queries rather than materializing every
payload. Active-row queries filter by the same coverage/generation in ObjectBox.
No schema/model UID or foundation changes are needed.

Validation still checks payload node/way totals, all three child-table counts,
coverage/generation identities and record keys. Each validation has a coherent
read transaction. It returns only a boolean; before/after manifest identity
comparison rejects a result superseded during the await. Workers have their own
attached Store, closed by ObjectBox on return/error; queries close in `finally`.
No graph payload cache, native dataset handle or persistent worker is transferred
to the UI. Coordinator disposal suppresses late state/listener publication without
canceling app-owned work. Failed worker reads publish failed coverage readiness,
not successful fallback content.

The dashboard observer/dependencies are unchanged: all required on/off-screen
data/settings must succeed, current visible content must be painted, and no
blocking Mapping dialog may cover main navigation. Stored-graph validation is
unrelated background work under the approved endpoint contract; it is not declared
ready early and route controls retain their existing readiness gates. Preflight,
all declared DEM checks, polygon validation, immutable generation/session pinning
and preflight-before-ObjectBox ordering are unchanged. No network/controller wait,
canonical fallback, launch-time bulk hash, payload write or reduced source set is
introduced. First-time imports retain their existing path and are not represented
by these provisioned-data timings.

## Matching local before/after evidence — 2026-10-14

Each row is one built-app launch with summary capture disabled. Phase durations
can overlap and must not be summed into a replacement total.

| Sample | Manifest/path | Polygon/catalog | Ready dependencies | Graph bootstrap | Dashboard local load | Launch → qualifying raster finish |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Before C, process-cold 1 | 17.936 ms | 34.066 ms | 16.232 ms | 98,287.281 ms, UI isolate | 1,212.432 ms | **102,705.318 ms** |
| Before C, repeated 2 | 14.964 ms | 34.423 ms | 14.564 ms | 105,845.945 ms, UI isolate | 888.469 ms | **108,727.420 ms** |
| Final C, process-cold 1 | 13.752 ms | 20.148 ms | 20.220 ms | async; not a dashboard prerequisite | 1,344.804 ms | **3,985.827 ms** |
| Final C, repeated 2 | 12.524 ms | 20.336 ms | 15.992 ms | async; not a dashboard prerequisite | 1,216.084 ms | **3,690.190 ms** |

The final **maximum is 3,985.827 ms**, within **5,000 ms**, including native/Flutter
startup and uncertainty. Before-run IDs:
`764cfc6f-7440-4d9f-8227-68b5d6339d36` and
`af197aff-5f9e-45bf-950c-0935197b3aaa`.
Clock uncertainty respectively **±46.155 / ±66.187 ms**. These are local C
comparisons, not interchangeable improvements over historical SMB A/B samples.

Final clock/frame evidence, microseconds unless stated otherwise:

| Observation | Process-cold 1 | Repeated 2 |
| --- | --- | --- |
| Run ID | `df72092b-d052-47a9-be85-894dd128cfa4` | `508861d9-401d-4abe-9068-48b6207acdbf` |
| Binding log timestamp (local) | 2026-10-14 09:49:55.995922 | 2026-10-14 09:50:48.378646 |
| Kernel process birth, native monotonic | 268821830621 | 268874201570 |
| Native delegate entry | 268822309791 | 268874567791 |
| Dart bracket before … after | 527054164596 … 527054216193 | 527106547265 … 527106624316 |
| Native clock sample | 268823003125 | 268875414375 |
| Clock uncertainty | ±25799 | ±38526 |
| Qualifying engine frame | 15 | 11 |
| Raster finish, Dart monotonic | 527056977918 | 527109024649 |
| Raster finish, native-correlated | 268825790649 | 268877853234 |
| Frame build / raster duration | 84080 / 14266 | 82399 / 12367 |

Marker: **`dashboard.local_data_ready.frame.rasterized`**, correlated to the
framework marker and the following requested engine frame under Item 02's
protocol. Kernel wall birth is bracket-correlated to `mach_absolute_time`; Flutter
uses the bracketed method-channel midpoint. Raster finish is an engine milestone,
not an exact WindowServer/display scanout timestamp. No compilation, Xcode/Flutter
tool startup or debugger attachment is inside the measured interval.

Final ready-dependency phase detail:

| Phase | Cold | Repeated |
| --- | ---: | ---: |
| ObjectBox directory preparation | 1.190 ms | 3.316 ms |
| ObjectBox open | 4.421 ms | 2.887 ms |
| Schema verification | 1.792 ms | 1.361 ms |
| Local Topo restore | 0.131 ms | 0.174 ms |
| Preferences read | 0.033 ms | 0.036 ms |
| Tile-cache initialization | 9.669 ms | 6.532 ms |
| Provisioned peak import/backfill check and load | 396.705 ms | 347.661 ms |
| Provisioned track import/backfill check and load | 947.393 ms | 867.595 ms |

Legacy worker migration took **606.449 / 418.893 ms** (includes scheduling while
dashboard CPU work runs). Tasmania stored validation completed in **15,389.203 /
11,530.859 ms** in the worker. The cold app was normally quit before the Northeast
Alps worker completed; that completion is not claimed. Repeated Northeast Alps
validation completed in **73,337.342 ms**, full graph bootstrap **73,758.541 ms**.
Later regression execution overlaps these background timings; they are phase
diagnostics, not an independent graph-throughput benchmark or route performance
claim. An earlier optimized launch observed full worker bootstrap **97,553.529 ms**
while the dashboard endpoint was **3,682.997 ms**.

Visible dashboard content/order was checked using a window-specific capture;
Settings navigation and return to Dashboard worked while graph validation was
pending, without changing preferences or records. Required dependency diagnostics:
**none** in all four before/final timed runs. Deterministic failed-read tests
continue to name/suppress failed dashboard dependencies. Remote tiles are excluded
as approved. Source-replica configuration and installed pipeline are unchanged.

Read-only recheck run **`46f9d610-e80f-4a86-b536-a0cd21fe80c1`** compared equal to
the initial C summary for every record count, stored geometry count, migration
flag, saved order/setting, graph manifest, selected root and dataset identity.
Its summary-enabled **6,837.551 ms** endpoint is deliberately excluded from timed
acceptance; expensive GPX/workload summary processing is not production startup.
Both summaries and all raw logs/screenshots remain local. No private defines,
API credentials, personal database or GPX content are published here.

## Verification and remaining boundaries

- Behavior-first failing/passing tests: worker validation API/payload corruption,
  pending catalog bootstrap, failed async read publication, disposal during a
  pending read, and replacement of a generation during validation.
- Focused 13-file startup/dashboard/provider/graph/service/robot run:
  **120 passed**; three subsequent async failure/disposal/version tests also passed
  in the final **16-test** repository/coordinator run.
- `flutter analyze --no-pub`: **no issues**.
- Final `caffeinate -i flutter test --no-pub --reporter expanded`:
  **2,264 passed, 5 existing environment-dependent skips, 11m55s**. The suite
  includes readiness success/empty/failure/off-screen/remote tile cases, navigation,
  existing dashboard and startup robot journeys, replica retention/preflight/I/O
  guards, native capture integration, and route regressions.
- Instrumented ARM64 macOS release builds succeeded. Existing ObjectBox Swift
  Package Manager and Xcode architecture notices remain build-tool notices.
- Startup ceiling met for this fixed two-launch workload. OS caches/thermal load
  are not controlled or flushed; no arbitrary-machine/universal timing guarantee
  is inferred. Initial transfer and first imports were not timed anew.
- This removes the minute-long graph UI-isolate stall, not every startup frame
  gap: unchanged dashboard data loading still produced **1,983.821 / 1,668.189 ms**
  heartbeat gaps before the qualifying frame. No zero-jank or spinning-wheel
  absence claim is made. Large stored-graph validation remains expensive in
  background workers; route-point latency/caching/native sampling are Item 10,
  and offline/disconnect/handover commissioning is Item 11.
