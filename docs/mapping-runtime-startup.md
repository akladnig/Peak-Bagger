# Machine-local Mapping runtime selection and startup

Spec 0063 Item 05 implements the app reader for the approved
[revision-1 metadata contracts](mapping-runtime-replica-contracts.md) and
[independent capture/eligibility](mapping-replica-capture.md). The mini remains
the canonical source. The macOS app defaults to a local replica and does not
contact SMB, SSH, Mutagen or a controller during startup.

## Machine-local configuration

The app reads `<Application Support>/mapping-runtime.json` before Mapping
preflight and before ObjectBox/ready dependencies. Application Support is the
directory returned by macOS `path_provider.getApplicationSupportDirectory()`
for this app (typically `~/Library/Application Support/<bundle identifier>`;
sandbox/container installations can differ). This file is separate from
`dart_defines.local.json`, which development provisioning may copy between Macs.
The app reads configuration; maintainer setup owns creating/editing it.

Absent configuration selects replica mode at
`<Application Support>/MappingRuntimeReplica`. An explicit replica override is:

```json
{
  "schemaVersion": 1,
  "mode": "replica",
  "replicaBase": "/absolute/local/MappingRuntimeReplica"
}
```

On the mini, explicitly select its attached canonical store:

```json
{
  "schemaVersion": 1,
  "mode": "canonical",
  "canonicalRoot": "/Volumes/Services/Mapping"
}
```

Version 1 accepts exactly those three fields for each mode. Unknown fields,
versions, duplicate JSON keys, relative paths, user-created symlink aliases,
nonlocal storage and state below canonical Mapping/source-sync roots fail closed.
Only canonical mode accepts the exact canonical root. Darwin
`getmntinfo(MNT_NOWAIT)`/`MNT_LOCAL` rejects SMB without opening its dataset files.
Canonical symlink aliases are rejected. Configuration/replica storage stays
outside `peak_bagger`, `trip_routing`, `flutter_map_tile_caching` and their known
home/mini workspace locations. System `/var` and `/tmp` aliases are accepted;
arbitrary state aliases are not. Maintainer tools retain canonical capabilities
independently of this app configuration.

## Launch, retry and selection

Replica launch takes `<base>/locks/selection-retention.lock` with bounded
**5-second** acquisition. Darwin `flock` interoperates with the Python controller.
Hold it through readiness, session publication and activation; controller cleanup
must use this exact coordination boundary.

1. Recover/check complete `selection.json`/`selection-transaction.json` tuples.
   Unsupported version/fields/identities fail closed. Prepared intent carries the
   entire prior and next records; committed intent supplies complete next state.
   An already complete old/new record is accepted whole, never field-by-field.
2. Remember active/recovery identities. Among other eligibility records, consider
   only the newest pending generation later than retained selected generations,
   ordered by UTC eligibility time then UUID. Superseded old eligibility cannot
   reactivate as a fresh update.
3. Verify exact schema/profile/release and small metadata bindings: canonical
   inventory, persisted source completion bytes, passed report bytes, external
   eligibility bytes, and the report-selected `operations/<operationId>.json`
   successful durable publication witness. Diagnostic `operation.json` is not
   eligibility authority. Require symlink-free, regular, readonly, independent
   generation boundaries on local storage. No launch-time payload hashing.
4. Run production preflight then required-polygon/catalog loading; require exact
   catalog/inventory path-set equality. All declared DEMs, manifest pair,
   coverage/display paths, schemas and fingerprints remain authoritative.
   ObjectBox/geometry caches cannot bypass source checks.
5. Acquire a unique session lock and publish its metadata before selection.
   Persist prepared intent, atomic complete selection, then committed intent.
   Increment revision and retain prior active as recovery. Publication failure
   rejects/reports the attempt and restores the complete old selection where
   possible; the journal protects old/new if restoration itself fails.
6. Pending eligibility/readiness/publication failure tries existing active,
   then retained recovery. Ready dependencies wait until a permitted generation
   passes. Pin `generations/<UUID>/payload` through `MappingCatalog.rootPath`.

Publication flushes a temporary sibling, renames on the same filesystem, flushes
the parent, then uses Darwin `F_FULLFSYNC` for the file durability boundary.
Fault tests cover old/new recovery and interrupted publication, not physical
disk power loss. Retain journal references until safely resolved/replaced.

Retry rereads configuration and repeats this transaction. Coordinator and widget
both suppress duplicate pending attempts and show progress. ObjectBox/other ready
initialization failures retain exact **`Initialization failed`**, Mapping selection
and session protection; no dataset rollback or second ready initialization.

## Process and native lifetime

Successful launch publishes `<base>/sessions/<sessionId>.json` and holds
`<base>/locks/session-<sessionId>.lock`. Records carry generation/inventory/app-reader
identities plus host, kernel boot UUID, actual PID, native process start time and
random token. The **held OS lock** is liveness authority, not a stale record/PID.
`O_CLOEXEC` descriptors release on process death and are not inherited by unrelated
subprocesses. Never unlink/replace lock inodes to recover ownership.

`MappingSessionProtection` retains the pin for pending native opens/datasets.
Session close releases only after final native-owner closure.
`RegionAwareRouteElevationSampler.dispose()` awaits opens, closes GDAL resources
and releases ownership; provider disposal invokes it. Error invalidation closes
abandoned cache entries. Native close failures are logged and retain protection
until process exit. Dataset/transforms/spatial references close explicitly on
success/failure; PAM writes and ambient sidecar discovery are disabled.

Candidate arrival/another launch cannot replace a session catalog. Late peaks,
coverage refreshes, Natural Features, TasMap, polygon overlays and lazy DEM opens
retain its concrete root through existing resolver boundaries. Runtime roots
never repeatedly resolve a mutable pointer.

### Controller cleanup — Item 06

Cleanup takes `selection-retention.lock`, protects active/recovery **and both full
tuples of a retained transaction**, probes session locks nonblockingly and retains
all held session/native generations. Retain journal references conservatively
until safe replacement/resolution. Capture/validation owners remain protected
under the controller pipeline lock. Never infer liveness from flags/PIDs or
delete locks. [Implemented controller retention](mapping-runtime-retention.md)
retires only a validated committed journal matching current selection, retaining
unresolved old/new tuples. The app itself never prunes datasets.

### Compatibility handoff — Item 07

Current `app-reader-v1` identity: `e442ea38-fc1d-4ca0-b07d-223b01df6c35`.
Supported records/profile: schema 1/`mapping-runtime-v1`. Default development
source/controller identities: `36363ecc-d359-5591-ba2a-a6a7ffff0e60` and
`fb5e6371-026c-5381-8994-eb5d74a17321` respectively. `MappingReplicaRecords`
accepts explicit compatibility sets for installed-release integration. Unknown
releases/profile/schema fail closed. Item 07 registers installed compatibility
without regenerating eligibility or making retained generations unreadable.

## Unavailable diagnostics and recovery

- No initial validated generation: **`Mapping runtime replica unavailable`**,
  local base/path list, unfinished-initial-synchronization explanation, **Retry / Quit**.
- Failed initial capture/validation or unknown outcome: stage/operation/report
  paths and distinct validation/selection diagnostic. A failed pending refresh
  cannot prevent an older valid generation starting.
- Invalid configuration: replica-unavailable heading, exact configuration path
  and diagnostic; never canonical fallback.
- Invalid eligible/selected data: concrete local paths/parser/identity errors,
  active/recovery fallback or retryable unavailable UI.
- Attached canonical readiness failure: **`Mapping data store unavailable`**.
- Ready-initialization failure: **`Initialization failed`**.

Quit uses the existing callback. Paths/heading/diagnostics scroll while Retry/Quit
remain reachable at enlarged text scale. Buttons support keyboard focus/Enter.
The macOS-only gate precedes configuration/readiness. Rejection logs identify
generation/operation/local paths; retained data is not advertised as latest upstream.

Recover validation/publication through pipeline inspection. Do not edit trusted
digests, merge incoming into active payloads, delete protected generations or
point the MacBook at SMB to bypass a failure. Changing local configuration then
Retry is permitted while startup is unavailable. Restart a running app to use a
new selection; another session cannot redirect its reads.

## Verification coverage

Disposable service fixtures cover configuration, eligibility, fallback, atomic
activation, concurrent pinning and recovery. Actual Python capture → production
Dart matrix → tiny GDAL rasters → app metadata reader verifies interoperability.
Separate-process tests verify Python/Dart locks and crash release. Widget tests
cover exact copy/paths, keyboard actions, pending/failed/recovered retry and text
scaling. Provider tests exercise old-session imports/DEM opens after activation
elsewhere. Role-specific direct-I/O guards prohibit transport and payload writes.

### Journey Verification
- Journey: Unavailable replica → synchronized readiness → normal dashboard
- Verification command(s): `flutter test --no-pub test/robot/mapping_runtime_startup_journey_test.dart`
- Required seams/selectors: controlled readiness, in-memory dashboard repositories/preferences, `mapping-store-unavailable-retry`, `mapping-store-unavailable-quit`, `dashboard-card-elevation`; empty tracks avoid external tiles
- Result: `pass`
- Remaining risk: Journey readiness is deterministic; native filesystem/activation is verified separately. Installed transport, physical power loss and live performance remain later-item commissioning.

### Journey Verification
- Journey: In-app route-source failure → dismiss → coverage retry
- Verification command(s): `flutter test --no-pub test/robot/route_graph_mapping_journey_test.dart`
- Required seams/selectors: existing fake coverage/planner and stable failure/route-planning keys
- Result: `pass`
- Remaining risk: In-app Retry / Dismiss is separate from startup Retry / Quit; widget tests do not measure native route performance.
