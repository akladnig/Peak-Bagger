# Complete local route-point performance

Spec 0063, Work Item 10. ADS-1.0 / Desktop wide / macOS apply. This slice
changes computation and ownership, with no dimension-dependent layout work or
foundation exception. Profile minima remain Pending.

## Fixed pre-optimization workload — 2026-10-14

Retain the exact Item 02 primary Snap-to-trail sequence:

| Point | Latitude | Longitude |
| --- | ---: | ---: |
| P1 | -42.91528495555278 | 147.24804506457454 |
| P2 | -42.9157878260805 | 147.2494612709344 |
| P3 | -42.917107841691745 | 147.25053415454036 |

Fresh P1→P2: 132 m, 13 geometry vertices / 13 dense samples. Accumulated
P1→P2→P3: new 221 m / total 353 m, 20 geometry vertices / 26 dense samples.
P2 snaps endpoints to (-42.9153884,147.2480381) and
(-42.9158038,147.2493777). Statistics: 695/689 m, 0/6 m ascent/descent;
P3: 695/675 m, 0/20 m. These workloads cannot be substituted for passing cases.

Use workload C's ObjectBox and presentation contract from
`mapping-startup-performance.md`: 198 Tracks / 46,659 Peaks / 132 PeaksBagged /
10 lists / 9,776 items / 80 Routes, both ready graph coverages (Tasmania
generation 3, Northeast Alps generation 4), completed migrations, 1710×1041
content / native 1710×1073, text scale 1.0. Dataset generation
`2be1ef1d-0f92-41a7-ae7d-722142dee4d1`, concrete Application Support
`MappingRuntimeReplica/generations/<UUID>/payload` on local APFS. Manifest-pair
SHA-256 `0c2bf374beaffa0c12f5adf587d16d97905a06db2369a9588cdf341ac21c3baa`;
ELVIS SHA-256 `adfe35ee878b07b0172ca5e90d49e54c83a987a4a95b2f4482ab30d3b72a1e9f`.
Existing graph source hashes and dataset inventory remain those of Items 02/08/09.

Freeze one fresh process with first lazy route/DEM access and one P3 repeated
accumulated placement, before/after, ARM64 macOS release / no debugger / summary
capture off. OS caches are not flushed; this is process-cold, not disk-cold.
Use the existing accepted-click → complete framework/engine raster-finish
markers and verify visible geometry and current statistics. Raster finish is
not an exact physical WindowServer presentation timestamp. Report individuals
and maximum against 1,000 ms, with 500 ms desired; ordinary starts separately
against 100 ms. Straight-line P1/P2/P3 and the recorded workload B Chimney Pot
Hill Route-to-peak action are separate correctness/responsiveness checks.

## Local baseline, before any Item 10 optimization

Run `6ed40f42-7f4c-4261-bc33-70bb5f583a81`, release, pinned local generation above.
Exact clicked coordinates, snapped geometry/lengths and statistics match Item 02.

| Placement | Dispatch (includes graph load) | Graph load / plan | Geometry elevation / dense total | Complete raster frame |
| --- | ---: | ---: | ---: | ---: |
| P1, ordinary start | 107.209 ms | none | no segment sampling | **180.529 ms** |
| P2, first subsequent | 7,413.918 ms | 2,940.026 / 29.860 ms | 1,141.924 / 65.075 ms | **9,121.479 ms** |
| P3, repeated accumulated | 9,116.582 ms | 3,505.670 / 24.424 ms | 301.662 / 188.176 ms | **10,169.320 ms** |

Maximum 10,169.320 ms fails the ceiling; P1 separately fails 100 ms. First
local GDAL open 980.223 ms, geometry raster loops 2.894 / 0.128 ms, dense loops
0.079 / 0.104 ms. Heartbeat gaps reached 7,886.113 / 9,707.813 ms plus a
1,046.846 ms first-open stall. Map navigation also produced an OS non-responsive
application warning before these placements. The warning is not a reliable
spinning-cursor capture. A native process sample and code audit show synchronous
graph validation/materialization on interactive reads; local storage alone has
not removed CPU/UI-isolate stalls. DEM source opening and region classification
also remain distinct measured costs. These phases may overlap: do not sum them
into a replacement total or attribute dispatch gaps to raster sampling.

Raw logs and captures remain local; no personal database/GPX/private config is
published.

## Implementation and ownership

- Full graph validation retains the same payload/node/way/child-row and record-key
  checks, now issuing an in-memory receipt bound to the complete manifest identity.
  Production interactive readiness uses that validated receipt rather than
  reloading full tables. Import/failure/clear and manifest changes invalidate it;
  explicit async maintenance validation still rereads current stored bytes.
- Bounded native ObjectBox queries keep the original inclusive intersection and
  1,000 m buffer, coverage, generation and result ordering. A read transaction
  produces an immutable bounded snapshot; before/during/after identity checks
  reject replaced manifests, including same-generation changes. Each ObjectBox
  read worker owns its attached Store and closes it on return/error; queries close
  in `finally`. No native Store crosses into the graph-computation worker.
- Merge/deduplication, graph construction, A* and endpoint probing run in short-lived
  isolates with the same trip_routing options and snapshot geometry. The result
  rechecks the graph manifest; existing provider request/draft-version checks
  reject canceled/newer work. Workers return small domain results and exit; there
  is no persistent graph-worker cache or changed routing-in-progress guard.
- `WorkerRouteElevationSampler` is owned/disposed by the existing Riverpod sampler
  provider. Its lazy, serial isolate opens GDAL and owns native datasets, spatial
  references and transforms; these never move between isolates. Each request
  freezes geometry before its first await. The concrete catalog root is copied
  without a mutable selection pointer; later activation cannot redirect it.
- A main-isolate `retainNative` lease protects the selected generation before
  worker creation through confirmed worker exit. Disposal rejects new work, drains
  admitted requests, closes native resources, acknowledges close, then exits on
  the same ordered response port. Exit/bootstrap failures fail pending requests
  and release protection only after exit/no-created-worker is established.
  No force-kill/release while native work is in use is introduced. Provider
  cancellation/version checks suppress obsolete results without needing to
  interrupt GDAL mid-read.
- Source validation runs on every worker request, including cached native handles.
  Typed source failures cross back with their paths/stack, clear failed cached
  datasets, retain the existing visible error/Retry behavior, and log operation
  and concrete local root. Host-library errors remain the lazy device-unavailable
  outcome. No SMB fallback, different DEM, accuracy change or zero-success failure
  substitution is added. Existing nodata semantics are unchanged.
- Catalog polygons are normalized/validated once as immutable prepared rings;
  conservative epsilon-inclusive bounds reject distant polygons before the exact
  existing containment test. This removes repeated vertex-copy/string/set
  allocation from region classification. A conservative latitude-only peak bound
  rejects distant peaks before the original exact 5 m distance test, preserving
  matching order. This separately addresses ordinary start feedback.
- Ordinary starts publish history availability, markers and optional Straight-line
  geometry together. The prior three synchronous state publications were separately
  profiled; undo/redo behavior is unchanged. After an accepted subsequent placement,
  optional `RouteElevationPreparation` opens the selected DEM in parallel with
  graph loading/planning. No work is moved before the measured click, and ordinary
  starts perform neither preparation nor segment sampling. The committed/snapped
  geometry is still revalidated/sampled afterward; preparation errors are logged,
  and actual source reads retain authoritative failure/retry handling.
- There is **no DEM sample reuse**. Geometry and densified samples are reread,
  and the full combined draft summary uses unchanged three-point smoothing.
  Conditional sample-cache invalidation work is therefore inapplicable. Native
  synthetic-raster tests still compare full recomputation for appended, reversed,
  shortened and restored geometry, and all summary fields.

Intermediate diagnostic builds are not final acceptance: worker/bounded-query
changes alone measured P2 **2,587.228 ms**, P3 **1,448.821 ms**, start **131.873 ms**
in run `8e2fc5f6-882a-4423-bbf9-4f28059fde37`. Repeated polygon normalization
remained a measurable cause. After prepared containment, run
`b801cb9b-4a6c-46a3-9492-8dcda1a3c519` measured P2 **737.396 ms**, P3
**209.930 ms**, start **57.984 ms**, with matching exact coordinates/geometry/
statistics. First GDAL library load **470.037 ms**, source open **60.739 ms**,
sampling transform **12.342 ms**, total first open **544.126 ms**. Sample loops
were **2.192 / 0.037 ms** (geometry) and **0.046 / 0.030 ms** (dense). These
separate phases explain the remaining first-use cost; sample caching was not
justified by sub-millisecond repeated loops.

## Final live evidence — 2026-10-14

Final release run **`3be53d74-f3a3-4180-944c-65727b5606c0`**, summary off, same
pinned APFS dataset and workload C. Both stored graph coverages were ready before
placement; these are the first route/DEM operations in this fresh process. The
ordinary P1 opens/samples no DEM. Geographic coordinates, snapped endpoints,
lengths, vertices and visible statistics match the fixed workload exactly.

| Placement | Dispatch | Bounded graph load | Worker construction / search | Geometry elevation / dense total | Complete raster frame |
| --- | ---: | ---: | ---: | ---: | ---: |
| Snap P1, ordinary start | 13.004 ms | none | none | no segment sampling | **50.343 ms** |
| Snap P2, first lazy | 19.685 ms | 278.964 ms | 41.818 / 3.424 ms | 25.902 / 0.966 ms | **432.103 ms** |
| Snap P3, repeated accumulated | 19.106 ms | 36.224 ms | 59.804 / 10.802 ms | 1.840 / 25.337 ms | **229.414 ms** |

Primary complete-update **maximum: 432.103 ms**, meeting **1,000 ms** and the
**500 ms** desired target for this fixed process-cold/repeated pair. The clock
endpoint remains the accepted-click → current geometry/statistics engine raster
finish, not marker appearance or worker completion. Matching engine frames:
P2 **143**, P3 **159**. First lazy GDAL library load **282.970 ms**, source open
**30.455 ms**, transform **14.344 ms**, total first open **328.087 ms**; all are
inside P2's accepted-click interval and overlap graph work. Point loops **2.266 /
0.039 ms**, dense loops **0.053 / 0.031 ms**. Four original intersecting graph
chunks are read for each short segment; buffers/options/accuracy were not reduced.
Do not add overlapping phases into a replacement total.

Separate secondary-mode verification in that same process (warm DEM):

| Case | Complete frame | Geometry / dense | Length | Start / end | Ascent / descent |
| --- | ---: | --- | --- | --- | --- |
| Straight-line P1 feedback | **46.839 ms** | one / no samples | none | none | none |
| Straight-line P2 | **89.654 ms** | 2 / 7 | 128 m | 695 / 689 m | 0 / 6 m |
| Straight-line P3 | **119.246 ms** | 3 / 14 | new 171 / total 299 m | 695 / 677 m | 1 / 19 m |
| Route-to-peak button | **339.345 ms** | 31 / 34 | 409 m | 440 / 490 m | 50 / 0 m |

Straight-line maximum **119.246 ms** is reported separately. Route-to-peak uses
the existing captured Chimney Pot Hill target
(-42.918977844589946,147.2781093123743) and a preceding ordinary start at
(-42.918879847521815,147.27393913135907), feedback **39.486 ms**. The projected
start differs from historical B by less than a millimetre; record that input
precision deviation rather than claiming identical B click bytes. The actual
button triggers immediate routing; the ordinary start is not relabeled as the
Route-to-peak action. Visible geometry/chart/statistics were captured and checked.
All test drafts were canceled; none was saved.

A supplemental repeated-process run **`27b637bd-1636-42aa-a1d6-3cf7f4528565`**
reproduced exact primary P1/P2/P3 after correcting its viewport to zoom 15:
P1 **39.378 ms**, P2 **196.244 ms**, P3 **223.997 ms**, same 132/353 m and
13/20 geometry vertices/statistics. These are **warm-use** results: its initial
zoom-13 inputs were different coordinates/workloads and are excluded from primary
acceptance, including an incomplete third-placement span. They do not substitute
for first-lazy evidence. Logs retain those exploratory inputs/failures.

### Longer calculations and responsiveness

One separate zoom-13 Snap-to-trail draft from
(-42.894616570709424,147.1711836830438) to
(-42.94238696815991,147.35142812884456) completed in **1,020.338 ms**, outside
the short benchmark. Existing off-track endpoint handling retained a **15,644 m**
two-vertex fallback, **627** dense samples, elevations **628/60 m**, ascent/descent
**1,182/1,750 m**. The pending `Routing...` UI was captured with disabled mode
controls and available Cancel/name input; name input was accepted, the completed
chart/statistics appeared, and the draft was canceled. There were no logged
heartbeat gaps over 100 ms during this longer placement. No macOS spinning wheel
or non-responsive-app warning was observed in final route checks. Deterministic
journeys additionally verify pending frames and typed input, completion, cancel,
undo/redo, guarded extra placement, visible source failures and retry.

This is not a zero-jank guarantee: the first-use primary run recorded a
**278.283 ms** heartbeat gap overlapping native-library/worker initialization.
It is below the former multi-second UI monopolization but remains a first-use
event-loop gap. Startup and map entry have separately recorded gaps and are not
relabeled as point calculations. No universal spinning-cursor absence claim is
inferred from screenshots that omit the cursor. OS caches/thermal/other workload
are not controlled or flushed; ceilings are verified for the fixed recorded cases.

### Retained diagnostic failures and environmental conditions

- Pre-final serial release `ca84503f-a4fb-452e-9e31-76bf9404cb28`: P2
  **924.814 ms**, P3 **231.193 ms**, start **60.423 ms**. A Straight-line
  start was **177.613 ms**, with three separate state publications; subsequent
  detailed profiling repeated **55.251 ms**. The single-publication correction
  addresses that independent ordinary-start path rather than changing coordinates.
- Pre-overlap release `ced737c8-3022-47b1-bbfb-f8232bc3f8b0`: P2
  **1,148.441 ms** (failed ceiling), P3 **238.731 ms**, start **51.580 ms**.
  Graph worker access **476.574 ms** then lazy DEM open **552.690 ms** ran
  serially, motivating overlap. This failure remains evidence, not a discarded
  passing sample; the final pipeline differs as described above.
- Desktop switching interrupted early automation; the operator granted exclusive
  desktop use. Screen locking later prevented inputs and was explicitly resolved
  by the operator. Locked/summary-on launches are not acceptance measurements.
- Read-only recheck **`5aaaeac8-0cc7-4deb-9551-e8fe20080861`** matches workload C
  exactly for all record and track-geometry counts, migrations, saved dashboard/
  theme/peak-info settings, graph manifests, concrete root and manifest identity.
  Route count remains **80**. No personal data or user records were copied/deleted.
  The summary-enabled launch is excluded from performance acceptance.

## Automated and build verification

- Behavior-first observed failures preceded worker APIs, generation readiness/
  bounded snapshots, same-generation stale manifest rejection, disposal after
  rejected startup, frozen dispatch geometry, prepared containment and lazy
  preparation overlap. Existing public route-state/provider tests continue to
  cover canceled/newer geometry, source errors/retry, snapping, saving and history.
- Focused 13-file route/catalog/provider/widget/robot run: **223 passed**; final
  preparation worker/provider cycles passed separately. The single-publication
  refactor then passed the **100-test** route provider/widget/robot regression run.
- `caffeinate -i flutter test --no-pub --reporter expanded`: **2,282 passed,
  5 existing environment-dependent skips**, **4m52s**. Includes native synthetic
  GDAL raster equivalence, Python→Dart replica capture, retention/native pins,
  direct-I/O guards and all existing broader journeys. No new skip was introduced.
- Final `flutter analyze --no-pub`: **no issues**. `git diff --check`: passed.
- Instrumented ARM64 macOS release builds and a final normal release build
  (measurement/workload flags off) succeeded. Existing ObjectBox Swift Package
  Manager and Xcode architecture notices remain unchanged build-tool notices.
- Tests use controlled futures, fakes/provider injection, temporary ObjectBox
  stores and synthetic rasters. They require no real Mapping data, SMB credentials,
  personal databases or API keys. Host GDAL/PROJ remains a native-test prerequisite.

### Journey Verification
- Journey: Draft → point → pending interaction → current geometry/statistics → undo/redo → Cancel
- Verification command(s): `flutter test --no-pub test/robot/map/map_route_journey_test.dart`
- Required seams/selectors: queued planner/elevation futures, fake basemap/in-memory records, existing route marker/name/loading/ascent/descent/undo/redo/Cancel keys
- Result: `pass`
- Remaining risk: Deterministic widget timing does not establish native hardware ceilings; the matching live evidence above supplies those observations.

### Journey Verification
- Journey: Local route-source failure → Dismiss → coverage Retry → completed segment
- Verification command(s): `flutter test --no-pub test/robot/route_graph_mapping_journey_test.dart test/providers/route_elevation_mapping_test.dart`
- Required seams/selectors: controlled local-source/planner failures, Mapping operation coordinator, existing Retry/Dismiss and route-planning keys
- Result: `pass`
- Remaining risk: Live immutable datasets were not corrupted to manufacture source errors; failure/retry coverage uses disposable data and controlled fakes.
