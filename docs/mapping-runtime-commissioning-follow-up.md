# Item 11 commissioning follow-up — 2026-10-15

Completes the four open checks in [Work Item 11](../ai_specs/peak-lists/0063-macbook-local-mapping-runtime-replica/work-items/11-commission-and-publish-operating-evidence.md).
The [2026-10-14 record](mapping-runtime-commissioning.md) remains historical
evidence, including its failures. ADS-1.0 / Desktop wide / macOS apply; no window
minimum, layout threshold, foundation replacement or exception is introduced.

## Startup: diagnosis, correction and fixed-workload results

**Preserve the 5,091.930 ms observation.** Inspection of the original raw logs
found that **both** Item 11 launches (`2aacf851…` online and `c8912084…` offline)
contain `workload.read-only-summary` with **`timing_run: false`**. The prior prose
claim that summary capture was off was incorrect. Their 3,461.793 / 5,091.930 ms
totals include expensive diagnostic geometry summarization and are **not valid
timed acceptance samples**. The latter still exceeds the ceiling; neither its
bytes nor its original failed classification is erased. Do not subtract summary
time and present an invented passing launch, or compare these as identical builds
to the new summary-disabled runs.

An additional real startup cost was redundant JSON encoding/decoding of each
already-decoded Track display-cache zoom. `GpxTrack` now passes the decoded lists
directly through the same segment/coordinate validation. Stored geometry, schema,
cache invalidation and recovery checks are unchanged. Existing Track regressions
cover geometry, zoom selection, segments and recovery. Track-load phases fell
from the historical 625.723–757.579 ms to 196.694–200.711 ms in the new observations;
the old summary-enabled builds are not controlled whole-launch comparisons.

The separate final read-only summary, run **`9b0a4c80-d129-46fc-a89b-62329a42496f`**,
matches workload C's original summary for **every** recorded field: 198 Tracks,
46,659 Peaks, 132 PeaksBagged, 10 lists, 9,776 items, 80 Routes; 168,046 GPX
vertices and every per-zoom display count; migration/backfill flags, saved
order/theme/peak-info settings, graph manifests, concrete root and manifest hash.
It is excluded from startup acceptance. Native window remains **1710 × 1073**,
content **1710 × 1041**, text scale **1.0**. No test draft was saved.

Timed builds explicitly set `MEASURE_WORKLOAD=false`, `MEASURE_PERFORMANCE=true`,
`MEASUREMENT_TRANSPORT=local-apfs`; inspection confirms **zero summary events and
zero failed required dependencies** in both timed logs. Both use the original
local generation `2be1ef1d-0f92-41a7-ae7d-722142dee4d1`, unchanged manifest pair
`0c2bf374beaffa0c12f5adf587d16d97905a06db2369a9588cdf341ac21c3baa`, real local
ELVIS/GDAL, workload C and the already-built ARM64 release / LaunchServices protocol.

| Phase (ms; overlapping phases are not additive) | Online process-cold 1 | Physically disconnected repeated launch 2 |
| --- | ---: | ---: |
| Manifest/path checks | 7.197 | 7.637 |
| Required polygon/catalog | 11.811 | 11.116 |
| Ready dependencies | 7.198 | 5.514 |
| ObjectBox directory / open / schema | 0.322 / 1.387 / 1.364 | 0.308 / 1.333 / 0.594 |
| Preferences / tile-cache initialization | 0.020 / 3.477 | 0.021 / 2.694 |
| Provisioned peak import/backfill check/load | 202.761 | 187.338 |
| Provisioned Track import/backfill check/load | 196.694 | 200.711 |
| Dashboard local-data loading | 399.909 | 388.606 |
| Unrelated background graph bootstrap | 64,724.583 | 41,875.576 |
| **Process birth → qualifying raster frame upper bound** | **1,447.644 — pass** | **1,405.975 — pass** |

All required on/off-screen data/settings succeeded; current visible content and
navigation were checked. Background graph validation remained genuinely pending,
with route controls gated until it finished. No preflight, source, DEM, import,
off-screen dependency or failure outcome was removed to qualify. Initial transfer
and first-time imports remain separate events. No SMB probe/controller wait occurs.

Clock evidence, microseconds, under the unchanged
[measurement protocol](mapping-performance-measurement.md):

| Observation | Online | Offline |
| --- | ---: | ---: |
| Run ID | `1603b383-a730-4b33-88b5-02ba0fe7cc9d` | `29f1bd3b-768d-447b-a009-801d3b0b945b` |
| Kernel birth, native monotonic | 309336967645 | 310307509904 |
| Native delegate entry | 309337074291 | 310307617333 |
| Dart clock bracket before … after | 601060836213 … 601060879321 | 602031379023 … 602031418648 |
| Native clock sample | 309337320375 | 310307860708 |
| Correlation uncertainty | ±21554 | ±19813 |
| Qualifying engine frame | 8 | 8 |
| Raster finish, Dart | 601061931127 | 602032434193 |
| Raster finish, native-correlated | 309338393735 | 310308896066 |
| Frame build / raster duration | 26434 / 5137 | 42434 / 5478 |

Marker: **`dashboard.local_data_ready.frame.rasterized`**. Kernel-birth correlation
uncertainty was zero at logged microsecond resolution. Totals include method-channel
uncertainty and native/Flutter startup, exclude compilation/tool/debugger startup,
and describe engine raster finish, not exact WindowServer scanout. Process-cold
does not mean flushed disk caches. Startup still has 624.183 / 632.197 ms heartbeat
gaps while loading local data; these are not zero-jank startup claims.

## First-use route responsiveness

Native sampling proved that cold `DynamicLibrary.open` in the elevation isolate
can block Dart group safepoints: the UI waits for GC while that isolate is inside
the VM's `DN_Ffi_dl_open`. Merely using a worker did not remove this stall.
A first correction using non-leaf FFI `dlopen` exposed a second path: a concurrently
starting ObjectBox snapshot worker blocked in `DN_Ffi_dl_lookup` / `dlsym` on dyld's
loader lock and again prevented UI safepoints. This was measured, not attributed
to SMB or the raster sample loop.

The final macOS loader acquires a temporary **RTLD_LAZY | RTLD_LOCAL** reference
through non-leaf FFI, then GDAL acquires its normal reference. Temporary native
references and UTF-8 buffers are released on success/failure. GDAL datasets,
transforms and session/native leases retain their existing worker ownership.
The bounded native graph snapshot completes before DEM preparation; **pure graph
construction/search overlaps preparation**. Other planner implementations use the
serial preparation boundary. All work remains **after the accepted subsequent
click**; ordinary starts neither open nor sample a DEM. Request, manifest,
geometry-version and disposal checks suppress obsolete work/results. Preparation
failure remains diagnostic; authoritative snapped-geometry sampling retains its
existing visible failure/Retry contract. Accuracy, densification and smoothing
are unchanged; no sample cache was introduced.

The exact P1/P2/P3 inputs and geometry/statistics from
[the fixed route workload](mapping-route-performance.md) are unchanged:

| Condition | Ordinary P1 feedback | First-lazy P2 complete frame | Accumulated P3 complete frame | Max subsequent |
| --- | ---: | ---: | ---: | ---: |
| Online cold process | **56.056 ms** | **900.297 ms** | **310.492 ms** | **900.297 ms** |
| Offline repeated process | **57.593 ms** | **936.575 ms** | **292.108 ms** | **936.575 ms** |

P2: **132 m / 13 vertices / 695→689 m / 0 m ascent / 6 m descent**.
P3: **353 m / 20 vertices / 695→675 m / 0 / 20 m**. Required fixed-workload
**100 ms start / 1,000 ms complete-update** ceilings pass. **500 ms desired first
use remains unmet.** First native library loads were **619.829 / 642.909 ms**;
first source open/transform totals were **709.281 / 745.222 ms**. Native snapshot
reads were **39.742 / 38.041 ms**, overlapping pure planning **122.539 / 109.974 ms**.

Maximum logged >100 ms heartbeat gaps inside P2/P3 were **none / 101.734 ms**
online and **102.885 ms / none** offline, versus the preserved historical
**474.564 / 638.130 ms** first-use gaps. A zero entry means no heartbeat exceeded
the logging threshold, not zero latency. The operator explicitly confirmed the
offline **353 m / 0 / 20 m** result and **no spinning wheel**. Frames/input and
deterministic pending-interaction/cancel/undo/redo journeys complement this scoped
observation; no universal no-jank/no-cursor guarantee is inferred.

The offline startup and route phases occurred in the **same process**, but a
synthetic Create Route input initially failed before any point was accepted.
After fixing the pointer-move/input helper, the points-only watcher completed
the first native/DEM use while disconnected. Network links were briefly restored
between phases; **each** phase independently recorded no IPv4/IPv6 states and
failed mini SSH before/after its executed checks. No continuous-disconnection
claim is made across that gap, and no accepted placement was discarded.

Supplemental mode checks, in the separate summary-enabled process (not startup
acceptance): Straight-line P1 **93.138 ms**, first-lazy P2 **981.069 ms**, P3
**322.412 ms**, expected 128/299 m, 2/3 vertices, 0/6 then 1/19 m ascent/descent.
Warm Route-to-peak action **966.571 ms**, expected **409 m / 31 vertices / 440→490 m /
50/0 m**. Its ordinary selected-peak-context start was **118.127 ms**, above
100 ms; retain this supplemental responsiveness finding separately from the
passing fixed P1 pair. Its input `(-42.91886781852139,147.27392301715022)` differs
from the old secondary start by about 1.8 m and is not an identical-workload
replacement. These secondary checks establish correctness and report timings,
not a universal ordinary-start performance guarantee. All drafts were canceled.

## Native invalid-configuration readability and recovery

Reused the normal built app with a temporary exclusively created machine-local
schema-99 configuration. Both the six-second and ten-second window captures show
clean exact **`Mapping runtime replica unavailable`**, full configuration path,
machine-local configuration explanation and **Retry / Quit**. Removing only this
test-owned file and clicking Retry reached the populated Dashboard. Original
configuration absence and runtime-refresh resume were restored in `finally`.

The original garbled capture remains evidence. **It did not reproduce in this
recheck**; no proven engine root cause or speculative font/renderer workaround is
claimed. Current native readability/recovery passed. Pending retry, failed retry,
keyboard/enlarged-text reachability and callback Quit also retain their executed
deterministic/full-suite coverage and the original live missing-replica drill.

## Changed-generation lifecycle: both hosts and native app readers

Used **disposable, complete 25-file fixture datasets**, outside source/canonical/
production replica roots. A has peak **Fixture A** and three tiny valid rasters
with **100 m** samples; B changes the peak, its legitimate fingerprint, manifest
and all three rasters to **Fixture B / 200 m**. Both pass the real source/local
matrix, including native full band-1 validation. This is a changed-byte lifecycle
drill, **not** a changed 3.963 GiB canonical production publication or transfer-speed
benchmark.

- Mini immutable installed source libraries/helper:
  **`dfe2a953-e4fb-4902-8da6-4b8e37f7fdaf`**. Guarded `Coordinator.maintenance` and
  `prepare` integration APIs capture/validate the explicitly injected disposable
  roots. The production publisher register/canonical source is not changed.
- MacBook installed capture libraries/helper:
  **`8918ed0f-54a0-4dd8-b54f-ae3147af3942`**, `Replica.capture` / `DatasetValidator`.
  The disposable reader base explicitly registers the same v1 release/profile
  compatibility; trusted completion/eligibility records are never edited to pass.
- Real Mutagen **one-way-replica**, mini disposable prepared alpha → MacBook
  disposable incoming beta. Final session
  **`sync_A6WeUprmDF1XTiYjO2RcQ27XKj1BjvHZlTAZt484mW4`** was terminated afterward.
  Transfer waits require a later completed cycle and connected/scanned/error-free
  endpoints before capture; the following pause naturally reports disconnected.
- Native ARM64 release **probe entry point** uses production
  `MappingRuntimeSelector`, `WorkerRouteElevationSampler` and
  `PeakRegionAssetImportService`, with explicit in-memory import storage/markers.
  Separate LaunchServices processes exercise real session locks, startup preflight,
  selection transactions and lazy native reads without opening a personal database
  or modifying personal preferences. This is not claimed as another normal
  Dashboard performance sample or scheduled-controller tick test.

| Executed boundary | Result |
| --- | --- |
| A source preparation, real transfer, independent capture, validation, receipt/source acknowledgement | Eligible A **`4aaf81a0-9f7e-4ccb-9341-fc128e5d1e7c`**, inventory **`1f18102ed41ab18e03cff4094a95dd986596e3f9edefd56411ae10bdf43c4f72`** |
| A native process, PID **47079** | Launch selects/pins A; no DEM open yet |
| B completed at source, transfer still paused/pending and absent locally | PID **47103** launches successfully on A; this is a pending-transfer check, not an observed partially streamed large file |
| B transferred; disposable incoming peak file deliberately corrupted | Capture **`a7262bfb-f204-43ec-9c4d-3f6235440f3b`** rejects size/SHA-256 mismatch; no B eligibility; PID **47132** still launches A |
| Mutagen repairs incoming; independent capture/full validation retry | Eligible B **`c68d41dd-ce50-488f-8b0b-20a2863e1a6b`**, inventory **`82f70ea8007052c8b2862afcc89aa8533aa24568a1afe0b92371f62e3f417506`**; selection remains A/revision 1 |
| Subsequent native launch, PID **47157** | B activated; A retained as recovery |
| Original PID 47079, after B activation | Late real peak import returns **Fixture A**; first worker/native DEM open returns **100 m**, concrete A root |
| New PID 47157 | Late import **Fixture B**, first native read **200 m**, concrete B root |
| Cleanup while both sessions/native owners are live | Protects A as recovery/live-session-native and B as active/live-session-native; prunes failed unowned captures, neither generation |
| Explicit worker drain/session close | Both probe processes exit; disposable transport terminated |

Remote fixture source acknowledgements succeeded; the local integration wrapper
did not persist its own acknowledgement mirror, so cleanup conservatively also
reported `durable-receipt-awaits-source-acknowledgement`. This is not relabelled as
completed production acknowledgement/cleanup. The production pipeline's earlier
durable acknowledgement evidence remains in the 2026-10-14 record.

Harness failures are retained: standalone Dart could not load a Flutter-dependent
fixture helper (rerun under Flutter); the first direct helper invocation inherited
Conda's incompatible PROJ database (explicit host `PROJ_DATA` / `PROJ_LIB` fixed
the wrapper); omitted disposable reader compatibility correctly failed closed
until registered. No eligibility was forged, canonical bytes corrupted, or
personal content copied. Automatic production setup/schedule identities remain
the original ones; this drill specifically composes installed integration APIs,
actual transport and native readers rather than claiming a new full scheduled
production-delta run.

## Verification and retained evidence

- Behavior-first red/green: slow native library constructor with UI allocations
  initially permits **0** heartbeat ticks; non-leaf loading passes. The test uses
  a disposable clang-built dylib, no real Mapping data. Xcode/clang and host GDAL/
  PROJ are native prerequisites on supported macOS.
- Red/green graph-stage test: preparation cannot begin before a pending bounded
  snapshot, and planning joins preparation. Provider regression keeps canceled
  results obsolete. A subsequent disposal test reproduced disposed-Ref access;
  `ref.mounted` request gating fixed it and prevents obsolete graph dispatch.
- Focused initial six-file run: **181 passed / 2 existing skips**. Staged route/
  graph/worker run: **84 passed**; disposal red/green passed separately.
- `flutter analyze --no-pub`: **no issues** after correcting two lint findings.
- Final `caffeinate -i flutter test --no-pub --reporter expanded`:
  **2,285 passed / 5 existing skips / 11m51s**. Prior full run before the disposal
  fix: **2,284 passed / 5 skips / 12m16s**. Skips are not claimed as executed.
- `caffeinate -i python3 -B -m unittest discover -s tool/tests -v`:
  **115 passed / 87.136s**; includes actual disposable Mutagen tests. Expected
  negative fixture diagnostics are not failures of production sessions.
- Native instrumented and probe release builds succeeded. Final normal release
  is rebuilt from **`lib/main.dart`**, with both measurement/workload flags off.
  Existing ObjectBox Swift Package Manager and Xcode architecture notices remain.
- Final normal-build Dashboard → Settings → Dashboard native captures passed;
  the log contains no measurement records. Machine configuration is again absent,
  production selection is still **`2be1ef1d-0f92-41a7-ae7d-722142dee4d1`** /
  revision 1, the original runtime session and installed release IDs are unchanged,
  refresh is enabled and the agent installed/loaded. All four intended Mapping
  sessions remain present; an unrelated project session is preserved.
- Documentation verification: **6 Markdown files / 29 existing relative links**,
  balanced fences and **20 checked / 0 unchecked** Item 11 criteria. `git diff
  --check` passed. No commit or push was requested/performed.
- Logs/captures/scripts are retained locally in the operator temporary evidence
  directory: `item11-final-online-11.log`, `item11-final-offline-13.log` and its
  two watcher logs, `item11-readability-08*.png`, `item11-workload-final-14.log`,
  `item11-lifecycle-evidence.jsonl`, capture outcomes, and native probe-process
  logs. Only non-sensitive summaries are published here.

Intermediate performance observations also remain: profiled run `c2727d25…`
startup **6,498.125 ms**, P2 **2,797.350 ms** (native sampling overhead; diagnostic,
not acceptance); incomplete non-leaf-only P2 **1,260.542 ms / 810.661 ms gap**;
serial-preparation P2 **1,249.260** then **1,172.909 ms**. The final staged pipeline
is different. No failed run is silently replaced. A desktop/sleep-interrupted
launch was excluded and a fresh online pair taken; the first offline watcher had
the wrong no-network text predicate and never launched an app. Its corrected
startup watcher then stopped before point acceptance; the successful points-only
watcher is documented above.

### Journey Verification

- Journey: Startup diagnostic → clean native text → configuration restored → Retry → populated Dashboard
- Verification: native schema-99 captures/retry; full startup/widget/robot suite
- Required seams/selectors: temporary exclusively owned config; existing Retry/Quit keys, injected coordinator/quit/preferences for deterministic coverage
- Result: `pass`
- Remaining risk: original glyph corruption is not reproducible/root-caused; clean recheck does not guarantee every future engine frame.

### Journey Verification

- Journey: Real fixture transfer → rejected candidate → repaired validation → next-launch activation → old/new native session reads
- Verification: installed source/capture APIs, real mini SSH/Mutagen, separate native release probe processes; full metadata/retention/provider/robot suites
- Required seams/selectors: explicit disposable roots and tiny real rasters; memory-only peak import storage/markers; production selector/native worker
- Result: `pass`
- Remaining risk: pending/paused transfer is the live surface; no new full-size partial-production-transfer timing or scheduled production-delta claim.

### Journey Verification

- Journey: Fixed online/offline draft → point → current committed geometry/statistics → Cancel
- Verification: final native P1/P2/P3 clocks/captures, operator no-wheel observation, full route/provider/widget/robot suite
- Required seams/selectors: real provisioned local workload for live runs; deterministic pending/failure futures and fake external basemaps in automated journeys
- Result: `pass`
- Remaining risk: 500 ms desired first use remains unmet; ~103 ms residual heartbeat gaps and supplemental selected-peak-context 118.127 ms start remain findings. These observations do not establish universal latency/cursor absence.
