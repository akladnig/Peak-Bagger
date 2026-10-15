# Before-cutover Mapping performance baseline

Spec 0063, Work Item 02. Recorded 2026-10-11/12 on the MacBook, **before any
startup/routing optimization or replica cutover**. Original interview timings
and affected coordinates/mode remain historical observations, not these samples.
Use [the measurement protocol](mapping-performance-measurement.md) to reproduce.

## Dataset, build and workload identity

- Root: `/Volumes/Services/Mapping`; observed mount is **smbfs** from
  `mac-mini.local/Services`. ObjectBox is under the MacBook's local Application
  Support directory. This describes access, not proven SMB causality.
- Native ARM64, macOS 27.0.1, Flutter 3.47.7, Dart 3.13.5, release build;
  Xcode 27. Native GDAL opens the selected ELVIS runtime DEM through the existing
  production resolver. No debugger is attached to these built-app launches.
- Manifest-pair identity (region text + NUL + polygon-manifest text):
  `0c2bf374beaffa0c12f5adf587d16d97905a06db2369a9588cdf341ac21c3baa`.
- Fresh full inventory executed with `dart run tool/mapping_runtime_inventory.dart`,
  completed **2026-10-12T01:16:38.858087Z**: **25 files, 4,255,657,108 bytes**,
  no stale peak fingerprints. Every path, byte count and SHA-256 matched the
  [2026-10-11 per-file inventory](mapping-runtime-audit-2026-10-11.md). ELVIS SHA-256:
  `adfe35ee878b07b0172ca5e90d49e54c83a987a4a95b2f4482ab30d3b72a1e9f`.
  This read-only observation is not coordinated capture or full payload-format
  validation. Hashing ran separately from timing, and may warm future OS caches.
- A separate `MEASURE_WORKLOAD=true` summary run captured the following counts
  without exporting databases, track names/coordinates, GPX content or private
  configuration. Timed launches had that expensive summary flag **off**.

| ObjectBox entity | Records |
| --- | ---: |
| GpxTrack | 196 |
| Peak | 46,659 |
| PeaksBagged | 131 |
| PeakList | 10 |
| PeakListItemEntity | 9,776 |
| Route | 77 |

Stored raw GPX track vertices (`trkpt`): **166,084**. Stored display-cache vertices:

| Zoom | Vertices | Zoom | Vertices |
| --- | ---: | --- | ---: |
| 6 | 439 | 13 | 7,665 |
| 7 | 511 | 14 | 13,525 |
| 8 | 658 | 15 | 24,088 |
| 9 | 976 | 16 | 43,307 |
| 10 | 1,493 | 17 | 76,650 |
| 11 | 2,559 | 18 | 126,382 |
| 12 | 4,374 | | |

All four named migration/backfill flags were **true**: track optimization v1,
PeaksBagged backfill v1, item visibility backfill v1, list coverage backfill v1.
These are provisioned-data runs, not initial sync/import measurements.

Saved dashboard order: `latest-walk`, `year-to-date`, `peaks-bagged`, `elevation`,
`distance`, `my-lists`, `my-ascents`. Peak information: **true**. Theme: **dark**,
seed **baseColor**, variant **content**, contrast **0.0**. Summary period/mode and
ascent sort use existing widget-local defaults. Native window: **1710 × 1073**
logical points; app content reported **1710 × 1041**; text scale **1.0**.

Both imported graph coverages were ready before launch:

| Coverage | Schema / generation | Nodes | Ways | Chunks | Source hash |
| --- | --- | ---: | ---: | ---: | --- |
| Tasmania | route-graph-v5 / 3 | 1,508,432 | 113,168 | 4,709 | `5009af35449e23a21a479f571d2f0222c98e91ffeeda00c3d3bd8505c7476be9` |
| Northeast Alps | route-graph-v5 / 4 | 7,780,038 | 558,284 | 4,081 | `e9dddc684c1fe0a94553029037b39e4315631fab94fa50384911776476420710` |

Keep these local-data/presentation values and source identities fixed for
comparable before/after runs. Different counts, settings, graph generations,
window size or point sequences define different workloads. The workstation was
used for development; thermal/CPU load and OS/SMB caches were not controlled or
flushed. These are diagnostic samples, not a controlled idle-machine study.

## Startup samples

Fresh app processes were launched from the already-built release app through
LaunchServices, without compilation or Flutter/Xcode tool startup. Native entry
and Flutter/native clock brackets were recorded. `process-cold` means a fresh
app/query/DEM process, not cold OS caches.

| Sample / run ID | Launch clock | Manifest/path | Polygon/catalog | Ready dependencies | Post-ready graph bootstrap | Local data/import/backfill | Qualifying rasterized frame |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Process-cold 1 / `6c0b3321-94d5-4e81-a3c3-8aed52d9e134` | Pre-dispatch upper bound, ±25.289 ms correlation | 1364.933 ms | 147.931 ms | 11.959 ms | 100672.583 ms | 1025.333 ms | **104283.816 ms upper bound** |
| Repeated launch 2 / `827c9110-170b-41f6-b6a7-d9a079dbb009` | Kernel process birth, ±29.830 ms correlation | 4853.014 ms | 139.581 ms | 23.274 ms | 121782.898 ms | 1345.702 ms | **130235.468 ms upper bound** |

The phase durations are separately observed and may overlap post-ready work;
do not add them into a replacement total. The first sample preceded the kernel
birth-clock refinement: its conservative launch upper bound is explicitly not
an exact kernel-launch timestamp. The repeated sample has:

- Process launch (native monotonic µs): **204294736618**.
- Native delegate entry (µs): **204295271000**.
- Dart/native bracket (Dart µs): **356418828342 … 356418888001**;
  native sample (µs): **204296030541**.
- Qualifying framework callback (Dart µs): **356547758115**;
  engine frame **285**, raster finish (Dart µs): **356547769886**.
- Native-correlated raster finish (µs): **204424942256**.
- Required local reads succeeded, saved order/current local content were shown,
  and main navigation was exercised. Pending tiles are not the endpoint.

Neither sample meets **5,000 ms**. Maximum reported upper bound:
**130235.468 ms**. UI-isolate heartbeat gaps reached **100694.660 ms** and
**121886.034 ms** respectively. These are real event-loop stalls, not proof that
SMB alone caused them. Earlier exploratory runs with human permission waits,
direct/background launch differences, timing-correlation experiments or colliding
stdout/stderr logs are excluded from this table. The final first-frame observer
refinement specifically handles already-loaded empty data and delayed saved-setting
application; fake tests do not establish the real hardware ceiling.

## Fixed primary Snap-to-trail sequence

Tasmania / The Springs, Wellington. Fresh draft **P1 → P2** and accumulated draft
**P1 → P2 → P3**, with both graph coverages above present in ObjectBox. Each
reported primary placement has **one recorded repetition**; P2 is first lazy
graph/DEM use in this fresh process, P3 is repeated use in its accumulated draft.
The exact accepted coordinates are:

| Point | Latitude | Longitude |
| --- | ---: | ---: |
| P1 | -42.91528495555278 | 147.24804506457454 |
| P2 | -42.9157878260805 | 147.2494612709344 |
| P3 | -42.917107841691745 | 147.25053415454036 |

The viewport was navigated to MGRS **55GEN2024948561**, zoom **15**, at the fixed
window size. On this window the clicks were `(897,614)`, `(930,630)`, `(955,672)`
in global logical screen coordinates. Recorded geographic coordinates, not a
generic pixel sequence on another viewport, are the workload authority.

| Placement | New segment | Cumulative | Geometry / dense samples | Graph load / plan | Elevation totals (geometry / summary) | Click → rasterized geometry + statistics |
| --- | ---: | ---: | --- | --- | --- | ---: |
| P2, first subsequent | 132 m | 132 m | 13 / 13 | 16667.628 / 12.867 ms | 1951.966 / 46.269 ms | **41920.907 ms** |
| P3, repeated accumulated | 221 m | 353 m | 20 / 26 | 11865.108 / 6.028 ms | 254.733 / 68.512 ms | **33764.779 ms** |

Maximum: **41920.907 ms**, not an average. Both fail **1,000 ms**, and the
500 ms desired target. First DEM open: **1648.508 ms**. Geometry-point raster
sampling alone: **74.421 ms**, then **0.081 ms**; dense-summary sampling itself:
**0.046 ms**, then **0.065 ms**. Those narrow sample-loop times exclude resolver
checks/opening and must not replace complete-update latency. Remaining time before
graph loading and dispatch is separately observable in the final
`route.acceptance-and-dispatch` instrument; do not attribute that gap to the DEM.

Current visible results were checked: P2 start/end elevation **695/689 m**, ascent
**0 m**, descent **6 m**; P3 start/end **695/675 m**, ascent **0 m**, descent **20 m**.
Snapping moved the initial control endpoints to **(-42.9153884,147.2480381)** and
**(-42.9158038,147.2493777)**. Frame/request versions matched committed geometry
and current point elevations. No draft was saved by the scripted primary checks.
UI-isolate gaps during these placements reached **39902.045 ms** and **33485.746 ms**.
No spinning-wheel absence claim is made: screenshots did not reliably capture
the cursor, while the measured UI stalls are unambiguous.

## Ordinary start feedback and secondary modes

Ordinary start feedback is independently measured, with **no segment elevation
sampling** for the first point:

| Case | Click → rasterized start feedback | Observation |
| --- | ---: | --- |
| Snap P1 above | 181.458 ms | Above 100 ms; separate reproduced start regression |
| Straight-line P1, same coordinates | 243.414 ms | Above 100 ms; no segment samples |
| Operator start near Chimney Pot Hill, below | 98.207 ms | Within 100 ms for this distinct workload; dispatch 54.426 ms, frame build 41.218 ms |

Do not substitute the passing different-coordinate start for P1's failure. The
start path calls local control-endpoint/peak classification and UI rebuild work;
the production `_peakAtPoint` scans stored peaks. Profiling that CPU/render path
is separate from later DEM/graph work. No start-point optimization was made here.

**Straight-line**, same P1/P2/P3, repeated-use DEM conditions in the first process:
P2 **684.966 ms**, 128 m, two geometry vertices/seven dense samples, elevations
695/689 m, ascent 0 m/descent 6 m. This is a separate mode result, not a passing
Snap-to-trail sample. P3: **496.450 ms**, new segment **171 m**, cumulative
**299 m**, three geometry vertices, elevations **695/677 m**, ascent **1 m** /
descent **19 m**. This mode's individual-placement maximum is **684.966 ms**.

**Route-to-peak**, operator-confirmed complete native flow, second fresh process:
start **(-42.91984464780659,147.27235945693278)**, Chimney Pot Hill target
**(-42.918977844589946,147.2781093123743)**. The existing UI enables Route to Peak
only after a start marker; selecting the button triggers immediate routing.
The initial operator run captured **39 geometry vertices / 44 dense samples**,
graph loading **17484.113 ms**, planning **13.521 ms**, first DEM open
**900.447 ms**, elevation totals **1271.336 / 126.052 ms**. A UI-isolate gap reached
**51363.976 ms**. The operator confirmed visible completion; that run predates
the dedicated mode-button frame span and is **service-phase evidence only**, not
a complete click-to-frame latency. The final dedicated span is recorded below.

## Final evidence and verification

Final read-only recheck, run `92d96ecf-80a6-49af-a44e-2e5ab5f3cffd`, succeeded:
all track/peak/ascent/list counts, track-geometry vertex counts, saved dashboard/
theme settings, migration flags and both graph identities match the first
summary. **Route count is now 79 rather than 77** after the operator's intervening
activity. Define this as **workload B**; retain workload A above historically.
Do not delete the operator's routes or treat those different counts as identical
acceptance evidence. The final recheck launch had `MEASURE_WORKLOAD=true`, so its
**113923.165 ms** rasterized endpoint is a summary/verification run, **not** a
comparable steady-state startup sample. The subsequent summary-off run and
dedicated Route-to-peak button span are appended below.

### Workload B: final implementation live checks

Summary-off release run **`cdfa274f-f38c-4d03-8a00-d25034ebbe1f`**, one fresh-process
repetition, retained the 79-route workload, 196 tracks, the same graph/dataset
identities and presentation settings. It reached the named rasterized dashboard
endpoint in **60452.022 ms** (kernel process-launch upper bound, ±20.452 ms
correlation). Phases: manifest/path **4414.195 ms**, polygon/catalog
**239.559 ms**, ready dependencies **15.609 ms**, graph bootstrap **54140.838 ms**,
local data/import/backfill **513.986 ms**. Process launch: **217801661986 µs**;
native entry: **217802072541 µs**; qualifying engine frame **267**, raster finish
**217862093556 µs** in the correlated native clock. This still fails 5,000 ms.
Do not describe its difference from workload A as an optimization gain: counts,
cache/operating conditions and instrumentation revision differ.

The operator repeated the actual enabled **Route to Peak button** flow and
confirmed visible geometry/statistics completion, then cancelled the draft.
This is a distinct fixed **workload B secondary-mode case**, one repetition:

- Start: **(-42.918879847245336,147.27393912951894)**.
- Chimney Pot Hill target: **(-42.918977844589946,147.2781093123743)**.
- The preceding ordinary start feedback took **79.754 ms**, with no segment
  samples. It is not the primary P1 coordinate workload.
- Button accepted → rasterized committed geometry/current statistics:
  **34775.158 ms** (`route.mode-action.complete.frame.rasterized`, frame **4610**).
- New/cumulative segment **409 m**, **31 geometry vertices / 34 dense samples**;
  elevations **440/490 m**, ascent **50 m**, descent **0 m**.
- Synchronous acceptance/dispatch **32714.560 ms**; included graph loading
  **10536.325 ms**, followed by planning **8.415 ms**. First lazy DEM open
  **1455.481 ms**. A UI-isolate gap reached **32992.892 ms**.

This button-action span is separate from ordinary first-point feedback and from
the primary Snap-to-trail point-placement ceiling. Together the named spans,
source identities and exact cases now permit trustworthy subsequent profiling;
use a matching recorded workload or explicitly re-baseline changed local data
before performance comparisons. Preserve the operator's added routes.

- Focused provider/widget/robot regression run: **157 tests passed**; additional
  first-frame, saved-setting/layout application and mode-button regression tests
  were then driven through observed failures and passing fixes.
- Final full suite: `flutter test --no-pub --concurrency=4 --reporter expanded`:
  **2,202 passed, five environment-dependent skips**. A previous 10-minute tool
  timeout is not counted as a complete suite; the successful run used a longer
  execution limit.
- Final `flutter analyze --no-pub`: **no issues**. Final instrumented macOS release
  build: **succeeded**. The summary-mode build also succeeded; its startup timing
  remains excluded as described above.
- Initial synchronization, first-time imports, replica startup/cutover, and the
  later numeric performance recovery are not claimed by these observations.
  Items 09/10 own optimization and ceiling delivery against these fixed workloads.
