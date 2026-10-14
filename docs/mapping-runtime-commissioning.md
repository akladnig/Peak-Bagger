# Local Mapping runtime commissioning — 2026-10-14

Spec 0063, [Work Item 11](../ai_specs/peak-lists/0063-macbook-local-mapping-runtime-replica/work-items/11-commission-and-publish-operating-evidence.md).
**Status: in progress; release acceptance is not complete.** The installed pipeline,
local/offline app reads and required route-update ceilings have executed evidence.
The disconnected startup sample is **5,091.930 ms**, above **5,000 ms**. Actual
login persistence passed; remaining live lifecycle/performance checks are below.

ADS-1.0 / Desktop wide / macOS apply. Observed benchmark dimensions do not resolve
the profile's pending minimum/window decisions. This commissioning introduces no
layout change, foundation replacement or approved exception.

## Operating entry points

| Need | Current procedure |
| --- | --- |
| Required data, read ownership, publisher register and complete validation matrix | [Access inventory](mapping-data-store.md), [revision-1 contracts](mapping-runtime-replica-contracts.md) |
| Mini canonical maintenance and interrupted-publication recovery | [Guarded publication](mapping-source-publication.md); never unlocked editor/copy/manifest updates |
| Complete installed artifacts, dependencies, compatibility, atomic upgrade/reselection | [Installed releases](mapping-pipeline-releases.md) |
| Initial synchronization, setup/reuse/drift, login/60-second schedule, status, pause/resume, bounded waits/reconciliation | [Automatic controller](mapping-runtime-controller.md) |
| Independent incoming capture, digest/profile validation, eligibility and durable receipt | [Capture](mapping-replica-capture.md) |
| Machine-local configuration, launch activation, Retry/Quit and immutable session/native lifetime | [Startup](mapping-runtime-startup.md) |
| Actual/planned space, active/recovery/newest-pending and operation/session/native protection, receipt-bound cleanup | [Retention](mapping-runtime-retention.md) |
| Timing clocks, endpoint and unchanged workloads | [Measurement protocol](mapping-performance-measurement.md), [startup workload C](mapping-startup-performance.md), [route workload](mapping-route-performance.md) |
| Three source sessions and sequential development handover | [Source operations](two-mac-mutagen-operations.md); independent of runtime refresh pause |

Initial provision uses the ordinary `controller provision`/scheduled refresh
path: coherent completed mini export → completed transfer → independent capture →
integrity and full reviewed profile → durable eligibility/receipt → app-launch
preflight and atomic selection. It is not a direct copy into active data. A valid
older generation remains usable during disconnection/failed updates; it is not
advertised as the latest upstream dataset. Offline Mapping-file availability
does not provide remote basemaps or mini-only Local Topo HTTP availability.

## Installed machines and configuration

Both installation bases are `/Users/adrian/.local/share/peak-bagger-mapping-releases`,
outside source roots and dataset payloads. Full installed `inspect` and `describe`
commands verified artifacts/dependency identities on both hosts, not just checkout
contents. All recorded contracts are **schema 1**, profile **`mapping-runtime-v1`**,
app reader **`e442ea38-fc1d-4ca0-b07d-223b01df6c35`**.

| Host | Selected release | Artifacts / dependency identities | Data base |
| --- | --- | --- | --- |
| MacBook controller | `8918ed0f-54a0-4dd8-b54f-ae3147af3942` | 8 / 1,172 | `~/Library/Application Support/com.example.peakBagger/MappingRuntimeReplica` |
| mini source preparer | `dfe2a953-e4fb-4902-8da6-4b8e37f7fdaf` | 20 / 1,057 | `~/.local/share/peak-bagger-mapping-source` |

Installed support retains source IDs `36363ecc-d359-5591-ba2a-a6a7ffff0e60`,
`90a7f7c6-a2e9-4fba-80a8-d540dd10f449`, `a8ad8ef2-5939-443e-8e32-37e73c56ad42`,
`c827d430-9994-4d2d-9fac-fa2f1df6d22c`, `dfe2a953-e4fb-4902-8da6-4b8e37f7fdaf`,
and controller IDs `8918ed0f-54a0-4dd8-b54f-ae3147af3942`,
`c741996a-6c8b-434a-8290-cd48e87845bd`, `e654c5db-733c-47e1-b899-1d06d359cd61`,
`e88b0e1e-6157-4659-9da4-c47079c576ce`, `fb5e6371-026c-5381-8994-eb5d74a17321`.
These explicit identities, not arbitrary v1 UUIDs, are permitted. Unsupported
versions/profile/releases fail closed; never rewrite old eligibility to force an
upgrade. Item 08's compatible installed upgrade and fixture lifetime/incompatible
rejection checks remain dated evidence, not a new upgrade performed by this item.

MacBook configuration remains **absent**, intentionally selecting the documented
local replica default. The mini's Application Support directory/configuration was
absent at inspection. Created only its machine-local directory and this file:

`~/Library/Application Support/com.example.peakBagger/mapping-runtime.json`

```json
{"schemaVersion":1,"mode":"canonical","canonicalRoot":"/Volumes/Services/Mapping"}
```

No private defines, database, settings or GPX was copied. Both apps built locally
as ARM64 macOS releases with their existing private defines. The mini first launch
required operator volume/file-access approval: it spent **230,364.570 ms** on the
manifest read before approval, subsequently passed every required path/polygon
check, then opened its own ObjectBox. It eventually emitted the data-ready frame
with **197 local tracks**, independently of MacBook's **198**. That first-use run
includes human prompts/initial local work and is not a startup acceptance timing.
SSH screenshot capture on the mini was denied; no captured mini UI image is
claimed. The operator later reported the mini app closed.

## Fresh inventory, integrity, source validity and space

Historical baseline: **25 files, 4,255,657,108 bytes (3.963 GiB)**, 2026-10-10.
This is retained separately from these new observations:

- **2026-10-14T06:29:41.261609Z:** on mini, `dart run
  /Volumes/Development/mapping/peak_bagger/tool/mapping_runtime_inventory.dart
  --root /Volumes/Services/Mapping` derived **25 files / 4,255,657,108 bytes** using
  production preflight/catalog rules; no stale regional peak fingerprints.
- The complete per-path sizes/SHA-256 match the completed export, current MacBook
  generation and [dated per-file audit](mapping-runtime-audit-2026-10-11.md).
  Freshly streamed every required byte in both immutable export and generation;
  no path, size or digest differences. The read-only canonical audit is explicitly
  **not** a coordinated new source capture or a new full-band DEM validation.
- Item 08's completed coherent source/local profile validation remains the
  validity evidence for those unchanged bytes. It includes all three DEMs/full
  band-1 decoding, all polygons, peaks/fingerprints, highways/coverage generation,
  Natural Features (including counted allowed skips) and strict TasMap parsing.
  Matrix limitations remain unchanged; byte equality does not prove terrain truth.
- Mini publication `64dde470-4937-4006-839d-f6d136c62417` remains complete after
  guarded recovery. The compliance register and external guard are present;
  repeated installed preparation succeeded with publisher/capability/guard checks.
  Repo/manual/external procedures remain the reviewed complete register; new
  publishers require explicit registration/guarding before use.

Fresh installed `run -- space --stage refresh` observations (bytes):

| Host / UTC observation | Free | Additional conservative plan | Reserve | Existing relevant logical / allocated occupation |
| --- | ---: | ---: | ---: | --- |
| MacBook, 06:43:11 | 126,086,533,120 | incoming + independent capture **8,511,314,216** | 67,108,864 | incoming **4,255,660,940 / 4,255,719,424**; generation **4,255,668,744 / 4,255,727,616** |
| mini, 06:43:10 | 725,663,019,008 | independent capture **4,255,657,108** | 67,108,864 | prepared export **4,255,660,940 / 4,255,719,424**; publication backup **4,255,665,719 / 4,255,723,520** |

Reports also enumerate publication-validation scratch separately. Current
candidates/source captures are empty; there is one active generation, no previous
recovery yet. Future recovery/live-session generations add their full occupation;
the manifest's 3.963 GiB is not a total-storage budget. These admission reports do
not include the separate installation base in their `releases` category (zero
there is not evidence that installed binaries occupy no space). APFS allocated
blocks can overcount shared extents; recheck actual free space before each copy.
Item 08's earlier pre-provision space reports retain their original timestamps.
Separate fresh `du -sk` inspection of the installation bases reports **48,228 KiB**
on MacBook and **207,228 KiB** on mini, including retained releases/use evidence.

## Pipeline/session/receipt and controller observations

- Session **`mapping-runtime-replica`**, ID
  **`sync_LoJOvzKX3HDbPatMplTGRyoRjuGaeCg6BCN8han8lAT`**:
  alpha **`mini:/Users/adrian/.local/share/peak-bagger-mapping-source/prepared`** →
  beta **`/Users/adrian/Library/Application Support/com.example.peakBagger/MappingRuntimeReplica/incoming`**,
  effective **`one-way-replica`**. Endpoint/scope inspection and repeated installed
  `controller setup --remote-python /Users/adrian/.local/bin/python3.15
  --remote-install /Users/adrian/.local/share/peak-bagger-mapping-releases`
  reused the same session/runner. No destination-local metadata is inside beta.
- Loaded user agent `com.peakbagger.mapping-runtime-replica` uses the installed
  Python/dispatcher, **RunAtLoad / 60 seconds**, inherited normal SSH authentication.
  `launchctl print` advanced from **448** to **554** runs, last exit **0**;
  an explicit `launchctl kickstart` dispatched the installed controller. Schedule
  inspection/controller restart is not proof of an actual new login.
- **Actual logout/login subsequently passed:** the operator logged out and back
  in without manually starting Mutagen/runtime. First post-login commands were
  read-only `launchctl print`: GUI session changed **101147 → 102986**; the runtime
  job had **1 automatic run / last exit 0**, same installed arguments, `runatload`
  and **60-second interval**. Mutagen automatically ran as PID **8473** in the new
  session. Only then were installed status/session commands run, confirming the
  same four persistent session IDs/configuration and generation/selection. The
  bounded mini watcher ended before logout (218 observations, old session only);
  it supplies pre-login evidence, not a claimed continuous logout trace.
- Generation **`2be1ef1d-0f92-41a7-ae7d-722142dee4d1`** remains the sole complete
  local/export generation. Source/local operation identities, in-flight controller
  and preparer releases are visible in installed status. Repeated ticks/refreshes
  reuse its original capture/receipt; no new generation is produced by ticks alone.
- Durable receipt **`2ab31b16-f029-44d4-b39d-3177c619c62f`** remains identical on
  both machines. Item 08 recorded source acknowledgement at **2026-10-13T21:38:12Z**
  before exact transfer-pin release and cleanup. Current source/export retention
  continues to protect the completed current surface. A completed transfer/idle
  state is not receipt acknowledgement.
- Active selection **`d15b2d27-1f4b-45df-8216-1a57bcb05323`**, revision **1**, was
  committed at **2026-10-13T22:26:21.122349Z** by app launch, not by the runner.
  All new MacBook app runs resolve its concrete `generations/<UUID>/payload` root.
  Live-session lock inspection while the app/native route worker ran retained that
  generation. Stale records are not live-lock authority.
- A controlled holder of the real refresh OS lock overlapped installed
  `controller provision`: **busy** with actionable scheduled/maintainer/provisioning
  ownership diagnostic in **2.177 seconds**, journal bytes unchanged. It released
  only its own lock. Healthy original multi-GB operations spanning ticks and
  quiet-stage unknown-outcome reconciliation remain Item 08's live evidence.
- **Physical disconnect:** the operator disabled MacBook links. The independent
  local runner recorded no IPv4/IPv6 network states and failed noninteractive mini
  SSH both before app launch and after completed routing. See performance below.
  After reconnect installed status/commands resumed without replacing session,
  generation, selection or receipt.
- **Source pause:** operator explicitly confirmed all-project/both-Mac saved-source
  freeze. All three `ready --writers-stopped` checks passed before pausing the exact
  three source sessions. Installed `controller provision`, `controller refresh`
  and mini `describe` succeeded while those sessions were paused. Original source
  operation **`ea8dfcd4-47c4-4d54-994e-2154b9d3ebaf`** succeeded/reused the existing
  generation. Restored all three sessions and passed the whole readiness gate.
  Development returned to **MacBook**, mini writers remain stopped. This is a pause/
  readiness drill, not a claimed switch of active development to the mini.

### Real SSH interruption on disposable remote fixtures

Operation **`0c368f61-57cf-4a17-a7ba-9e4d9cb9bc12`** used a complete disposable
release pair on mini, the production release manager/OS locks, a detached controlled
child and actual SSH alias `mini`. Terminated the local SSH client (exit **255**)
while remote child PID **9372** retained the inherited old-release lifetime lock.
A compatible atomic selection had moved future invocations to
`5580e338-619e-4c52-81cf-81b1eba139c1`; original helper release
`a697331c-d297-4d76-af10-51c9aaa83b8f` stayed present/pinned. Bounded reconciliation
reported **`surviving invocation/child owns release`** with the same operation ID;
retirement reported **`release protected by unresolved operation`**. After ending
only the identified disposable child/supervisor, bounded reconciliation recorded
failed/no-stage completion, then old-release retirement succeeded. Fixture cleanup
removed only that temporary installation/data tree. No timeout/SSH exit was treated
as successful preparation or release permission. Capture/export/data protection
and hung-process/poll/unknown-outcome cases are exercised by the complementary
disposable pipeline suites; this remote drill is not a multi-GB canonical export.

### Production startup-shell recovery with disposable configuration

Paused only runtime refresh, selected a temporary **empty** replica base through
an exclusively created machine-local configuration, and launched the normal built
app. Captured exact **`Mapping runtime replica unavailable`**, the selected local
root/affected path, initial-synchronization explanation, and **Retry / Quit**.
A failed Retry stayed recoverable; Quit exited the process. The missing-replica
log contains binding initialization only, no ObjectBox initialization.

A second launch with unsupported configuration schema **99** showed the same
heading and a configuration-path/cause diagnostic, without SMB fallback. Removing
only the test-owned configuration restored the original absent-config default;
Retry reached the populated normal Dashboard, with ObjectBox initialization logged
only after that retry. Restored configuration absence and resumed runtime refresh
in `finally`. The first invalid-config screenshot has glyph/raster artifacts in
parts of the long diagnostic; it is not full native diagnostic-readability proof.
Exact text/paths, pending/keyboard/enlarged-text behavior and candidate activation
on successful retry retain deterministic widget/service coverage.

A repeat after login failed its synthetic Quit-input observation rather than
receiving the expected click; it is not another passing exit test. Its `finally`
restored absent configuration/runtime refresh, and the operator clicked Retry
and explicitly confirmed **Dashboard restored**. No temporary replica/configuration
or unsaved test draft remains in use. Native diagnostic-rendering/readability and
repeat input automation remain follow-up verification rather than silently passed.

Use the controller's documented **0/5/10/30/180/600/7,200-second** boundaries for
ownership deferral, locks, connection, RPC, outer controller, quiet-progress
diagnostic and detached-stage budget. **60 seconds is a trigger interval.** An
expired SSH/controller call never means remote work ended. Inspect/reconcile the
same original UUID, retaining inherited helper/data locks; unresolved ownership
blocks conflicting mutation. Disposable suites below exercise failure/corruption,
child lifetime, low space, incompatible versions and lost acknowledgements; live
canonical bytes were not corrupted to manufacture faults.

## Fixed-workload performance recheck

Workload C summary run **`e1c81ca1-9276-4b91-bf4b-4774df8a0b33`** matches the
pre-optimization C counts/geometry/migrations/settings/graphs/dataset: 198 Tracks,
46,659 Peaks, 132 PeaksBagged, 10 lists, 9,776 items, 80 Routes; 168,046 GPX
vertices, unchanged per-zoom display vertices; both ready graph generations 3/4.
Observed content **1710 × 1041**, text scale **1.0**, same saved dark theme/order.
This summary-enabled launch's **5,685.684 ms** is explicitly **not** a timed
acceptance sample. Rebuilt with `MEASURE_WORKLOAD` off before timed runs.
Final separate read-only summary **`1033a6bb-b898-41c6-8463-983ed95eed12`** matched
every recorded C field before/after (counts, all geometry/migration/settings/graph
fields, selected root and dataset identity). Route count remains **80**. That
summary-enabled recheck is also excluded from acceptance timing. The final MacBook
normal release was rebuilt with both measurement/workload flags off.

ARM64 release / already-built LaunchServices launch / no debugger, same concrete
APFS generation and real local GDAL/ELVIS. Process-cold means new process, not
flushed disk caches. Endpoint **`dashboard.local_data_ready.frame.rasterized`**:

| Condition / run | Kernel birth, native monotonic µs | Clock uncertainty µs | Qualifying engine frame | Launch → frame upper bound |
| --- | ---: | ---: | ---: | ---: |
| Online process-cold, `2aacf851-7f3d-4011-8f5a-ee89928fb9a0` | 292,831,721,705 | ±25,954 | 10 | **3,461.793 ms — pass** |
| Disconnected repeated launch, `c8912084-36af-4194-90d1-7347f73044cf` | 298,626,880,473 | ±21,286 | 10 | **5,091.930 ms — FAIL** |

Phase observations (milliseconds; overlapping phases must not be summed):

| Phase | Online cold | Disconnected repeat |
| --- | ---: | ---: |
| Manifest/path checks | 7.341 | 6.132 |
| Required polygon/catalog | 12.291 | 11.152 |
| Ready dependencies, including scheduling | 1,470.378 | 1,879.862 |
| ObjectBox directory / open / schema | 0.426 / 2.054 / 1.651 | 0.421 / 3.809 / 0.762 |
| Preferences / tile-cache initialization | 0.020 / 16.425 | 0.048 / 38.445 |
| Provisioned peak import/backfill check/load | 200.461 | 230.267 |
| Provisioned track import/backfill check/load | 625.723 | 757.579 |
| Dashboard local-data loading | 826.604 | 988.322 |
| Unrelated worker graph bootstrap | 57,209.314 | 67,929.723 |

Clock correlation retained the Dart before/after brackets
**555683654673…555683706580 / 561479903198…561479945770 µs**, native samples
**292832077416 / 298628310875 µs**, and correlated qualifying raster finish
**292835157544 / 298631951117 µs**. Native delegate entry was
**292831827583 / 298627588125 µs**. Kernel-birth correlation uncertainty was zero
at the recorded microsecond resolution; method-channel uncertainty is included
in each total upper bound. Frame build/raster durations were
**54.812/11.456 ms** and **49.841/13.364 ms**.

All required local dependencies succeeded; no failed-dependency marker qualified
via fallback. Current dashboard content and Settings navigation were captured on
MacBook. Native/Flutter startup is included; compilation/tool startup/debugger
attachment is excluded. Raster finish is not exact WindowServer scanout. Item 09's
earlier **3,985.827 / 3,690.190 ms** pair remains dated evidence, not a substitute
for this new failed disconnected run or a claim of universal startup acceptance.

Exact primary P1/P2/P3 and repetitions remain those in the fixed route workload;
first lazy graph/DEM use occurs inside P2, P3 is the accumulated repeat. Geometry
and statistics match: P2 **132 m / 13 vertices**, 695→689 m, ascent/descent **0/6 m**;
P3 **353 m / 20 vertices**, 695→675 m, **0/20 m**.

| Condition | Ordinary start | First-lazy P2, complete frame | Accumulated P3, complete frame | Maximum subsequent |
| --- | ---: | ---: | ---: | ---: |
| Online process-cold | **58.784 ms** | **719.952 ms** | **318.892 ms** | **719.952 ms** |
| Disconnected repeated process | **55.655 ms** | **869.549 ms** | **290.008 ms** | **869.549 ms** |

Required **≤100 ms** start and **≤1,000 ms** complete-update ceilings pass for
these samples. **500 ms** desired first-lazy target is not met in this recheck;
Item 10's earlier **432.103 ms** is not relabelled as the new maximum. These are
accepted click → rasterized committed geometry **and current elevation/ascent/
descent**, not marker or worker-completion timing.
New first-lazy placements still logged event-loop gaps of **474.564 ms online**
and **638.130 ms disconnected**; P3 had no logged gap over 100 ms. These gaps are
retained as responsiveness findings, not described as zero-jank/no-blocking passes.

After reconnection, separate warm secondary checks in the latter process:
Straight-line start **95.693 ms**, P2 **210.163 ms**, P3 **283.040 ms**, expected
128/299 m, 2/3 geometry vertices and 0/6 then 1/19 m ascent/descent. Route-to-peak
button **815.091 ms**, expected 409 m / 31 vertices / 440→490 m / 50/0 m. Its start
was (-42.91887976120306,147.2739384660455), approximately centimetres different
from Item 10's recorded start; this is a separate secondary-mode check, not an
identical-input primary sample. Test drafts were canceled, never saved.

Initial multi-GB synchronization/profile validation and mini first-time local
initialization are separate operating events. They were not newly benchmarked as
pure transfer/import throughput. Item 08 retains original stage/receipt timestamps;
do not subtract a mixed maintenance/upgrade wall interval and call it transfer speed.
No new off-screen widget construction or remote-tile requirement was added.

## Verification executed for Item 11

Raw logs, screenshot captures and read-only summaries remain in local temporary
operator evidence, outside source roots. No database/GPX/private defines or full
settings payload is published. Exact public commands/results:

- `flutter analyze --no-pub`: **no issues**.
- `caffeinate -i flutter test --no-pub --reporter expanded`: **2,282 passed,
  5 existing skips, 8m40s**. Skips remain unverified.
- `caffeinate -i python3 -B -m unittest discover -s tool/tests -v`:
  **115 passed, 59.021s**. Printed negative fixture readiness diagnostics are
  expected assertions, not failures of the real sessions.
- `python3 -B -m unittest discover -s tool/tests -p 'test_mapping_*.py' -v`:
  MacBook **85 passed, 22.793s**; mini **84 passed, 1 skipped, 9.523s** using
  `/Users/adrian/.local/bin/python3.15` in the mirrored project. Mini lacks the
  controlling Mutagen executable on the tested PATH; its disposable real-session
  case was skipped there and passed on MacBook. Do not install a second controller
  merely to erase this skip.
- `flutter test --no-pub --reporter expanded` with
  `test/services/mapping_runtime_startup_test.dart`,
  `test/services/mapping_runtime_selection_test.dart`,
  `test/services/mapping_replica_records_test.dart`,
  `test/widget/startup_shell_test.dart`,
  `test/robot/mapping_runtime_startup_journey_test.dart`,
  `test/widget/dashboard_readiness_test.dart`,
  `test/providers/route_elevation_mapping_test.dart`,
  `test/robot/map/map_route_journey_test.dart`,
  `test/robot/route_graph_mapping_journey_test.dart`: **67 passed, 22s**.
- Both hosts: `flutter build macos --release --no-pub
  --dart-define-from-file=dart_defines.local.json
  --dart-define=MEASURE_PERFORMANCE=true` passed (MacBook timed build also sets
  `--dart-define=MEASUREMENT_TRANSPORT=local-apfs`). Workload-only build separately
  adds `--dart-define=MEASURE_WORKLOAD=true`. Existing ObjectBox/Xcode notices remain.
  The mini's CocoaPods checksum/version-only shared lockfile rewrite was inspected
  and reverted to the pre-existing agreed lockfile, not committed as a dependency change.
- Documentation checks: **12 affected Markdown files / 85 existing relative links**,
  balanced fences, exact new evidence/16 checked and 4 unchecked acceptance criteria,
  post-login identity/endpoint preservation and restoration of the prior absent
  MacBook configuration passed. `git diff --check` passed. No source-code changes
  were needed for this evidence/documentation slice; full suites above were not
  rerun merely for subsequent prose edits.

Coverage includes publication/capture exclusion and crashed writers, incomplete/
malformed incoming with fresh hashes, full native tiny-raster profile, independent
capture, activation/fallback, Retry/Quit/keyboard/enlarged text, withheld ObjectBox,
ready-initialization failure without Mapping rollback, old-session lazy/native
reads after another selection, crash/native/session locks, concurrent cleanup,
low-space preservation, lost receipts/bounded exports, source-checkout unavailability,
old/new installed helpers, incompatible rejection and timeout/unknown reconciliation.
These use disposable/controlled seams. They are not fabricated live faults on the
operator's canonical dataset or personal database.

### Journey Verification
- Journey: Unavailable replica → failed/pending/successful Retry → current Dashboard; callback Quit
- Verification command(s): focused Flutter command above; full suite
- Required seams/selectors: controlled readiness/repositories/preferences; startup Retry/Quit keys and dashboard stable keys; fake external services
- Result: `pass`
- Remaining risk: reversible live configuration checks also executed above, but a long native invalid-config diagnostic capture has glyph artifacts and repeat synthetic input was unreliable after login. Candidate activation/keyboard/enlarged-text use deterministic/disposable coverage.

### Journey Verification
- Journey: Route draft → pending work → committed geometry/current statistics → undo/redo/Cancel; local-source failure → Dismiss/Retry
- Verification command(s): focused route provider/robot files above; fixed native live runs separately
- Required seams/selectors: controlled planner/elevation futures, fake basemaps, existing loading/name/ascent/descent/history/Cancel keys
- Result: `pass`
- Remaining risk: fixture timing does not prove native ceilings; new native timings and unmet startup/stretch results are reported separately.

## Remaining commissioning gates

1. **Startup ceiling remains unmet in disconnected repetition 2** by **91.930 ms**.
   Preserve that sample and workload/clock evidence; diagnose before claiming
   release acceptance. Do not discard it in favor of earlier passing launches.
2. A genuinely changed completed update activating at a later launch, running
   session keeping its old generation through late imports/lazy reads, app launch
   during transfer/rejected update, and associated live multi-generation recovery
   have deterministic coverage but no new changed-production-generation drill here.
   Do not edit canonical bytes or trusted eligibility to manufacture one.
3. No reliable new operator observation of the route spinning cursor was returned
   during the offline drill. Frame/input/heartbeat evidence is available; cursor
   absence is not inferred from screenshots that omit the pointer. Item 10's
   earlier no-wheel observations remain dated evidence.
   First-lazy event-loop gaps above remain measured responsiveness limitations.
4. Long invalid-config native diagnostic readability needs rechecking; the live
   capture's glyph artifacts cannot be called a clean visual pass. Repeat synthetic
   input after login was unreliable; operator Retry did restore the normal app.
5. Physical power loss and a true active-developer switch to mini were not performed.
   Flush/rename/process faults and source-pause/readiness are the executed surfaces.

Early failed attempts remain explicit: unsupported `space --stage commissioning`
was corrected to documented `refresh`; a remote build invoked from the SSH home
directory found no pubspec and was rerun with the exact project cwd; the initial
offline watcher expired before observing disconnection and never launched an app.
The successful retry recorded a new process and the network-state checks above.
No failure was interpreted as validation, receipt or ownership-release evidence.
