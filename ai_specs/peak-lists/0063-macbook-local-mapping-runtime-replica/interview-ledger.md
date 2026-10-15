---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What happens during the route-point delay, and does it affect start or subsequent route points?

Answer: The app becomes unresponsive and shows the macOS spinning wheel. After restarting and retesting, initialization takes approximately 40+ seconds, the start route point is almost instantaneous, and subsequent route points take 20–30 seconds.

Decision: Use the corrected post-restart reproduction: slow startup and subsequent route-point updates, preserving the already-fast start route point and eliminating UI freezes.

Answer History:
- Initial report: placing a route point takes well over 10 seconds rather than the previous small delay.
- Initially reported both start and subsequent route points freezing.
- Retest after restart: start point is almost instantaneous; subsequent points take 20–30 seconds; initialization takes approximately 40+ seconds.

Constraints:
- User-reported timings are reproduction evidence, not instrumented benchmark results.

### L2

Status: current

Question: Should this change address both slow startup and subsequent route-point placement, and investigate the relationship to the mini migration?

Recommended Answer:
- Investigate both performance regressions and the shared Mapping data access path.
- Preserve elevation accuracy and existing initialization checks.

Answer: "yes. This all started happening after the migration to the mini, so i think identifying which files are on the Services Volume which are needed whilst the app is running and which are needed for initialisation and would benefit from copying or mutgen to the macbook"

Decision: Audit Mapping files by startup, live-runtime, and import/update usage, measure the regressions, and provide local MacBook access to the needed dataset.

Reason: The user suspects elevation reads from the mini's ELVIS runtime DEM. The inspected MacBook Services mount is SMB, and GDAL sampling performs synchronous native reads, but the exact bottlenecks have not been profiled.

### L3

Status: current

Question: Should the mini remain the authoritative Mapping data store, with the MacBook app reading a local Mapping runtime replica refreshed one-way from the mini?

Recommended Answer:
- The mini retains canonical source ownership at `/Volumes/Services/Mapping`.
- The MacBook replica contains the complete manifest-required app dataset.
- Local startup, elevation sampling, and data updates use the replica.

Answer: yes

Decision: Introduce a MacBook-local Mapping runtime replica, with the mini as its sole upstream authority. Copy the complete manifest-derived app set, rather than only the ELVIS runtime DEM.

Constraints:
- The previously measured set is 25 files and approximately 3.963 GiB; current references and sizes must be rechecked.
- The glossary distinguishes the canonical Mapping data store from the Mapping runtime replica.

### L4

Status: current

Question: Should the replica refresh automatically or only through an explicit refresh command?

Recommended Answer:
- Use a dedicated one-way Mutagen session, mini → MacBook.
- Transfer into staging and activate only a complete, validated dataset.
- Activate completed updates on the next app launch; never replace an open elevation dataset mid-session.
- Startup reads local data without waiting for the mini or synchronization.
- When the mini is unavailable or a transfer fails, use the last validated replica.

Answer: agreed

Decision: Automatically synchronize a staged runtime dataset in one direction and activate validated updates at launch, retaining the previous valid replica through transfer or validation failures.

### L5

Status: current

Question: If no valid local replica exists, should startup show an explanatory screen rather than fall back to SMB?

Recommended Answer:
- Show `Mapping runtime replica unavailable`, affected local paths, and `Retry / Quit`.
- Explain that the initial synchronization must complete.
- `Retry` rechecks local readiness.
- A failed refresh does not prevent using an older validated replica.

Answer: yes

Decision: Withhold the normal app when no valid replica is available, retain the explicit local-readiness recovery flow, and never silently revert the MacBook app to SMB Mapping reads.

### L6

Status: current

Question: What subsequent route-point response time is acceptable?

Answer: "subsequent route points should be within 1 sec and ideally 500ms"

Decision: The required ceiling is 1 second for representative short Tasmania route-point updates, with 500 ms as the desired target.

Answer History:
- Initial answer: subsequent points should be within 2 seconds, ideally 500 ms.
- Immediately revised to within 1 second, ideally 500 ms. This supersedes the 2-second ceiling.

Constraints:
- The 5-second provisioned-startup and 100 ms start-point targets were recommended defaults, not explicitly confirmed numerical requirements.

### L7

Status: current

Question: Should the route-point target include the complete update or only readiness to place the next point?

Recommended Answer:
- Include the drawn snapped route segment and refreshed elevation, ascent, and descent for representative short Tasmania segments.
- Show immediate click feedback and keep the UI responsive throughout.

Answer: yes

Decision: Measure click-to-complete-update latency, including route geometry and elevation/ascent/descent refresh, against L6. Marker appearance alone does not satisfy the performance requirement.
