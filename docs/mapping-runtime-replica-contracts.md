# Mapping runtime replica: inventory and pipeline contracts

Source: [Spec 0063](../ai_specs/peak-lists/0063-macbook-local-mapping-runtime-replica/spec.md),
Item 01. Contract revision: **1**, 2026-10-11.

## Review and execution gates

**Revision 1 approved by the maintainer on 2026-10-11.** The implementation-session
review explicitly approved the validation matrix (including full band-1 DEM
decoding and its limitations), metadata/compatibility formats, ownership/recovery
protocol and bounded-wait policy. The maintainer separately confirmed that the
publisher register is complete, with no additional publisher workflows.
Eligibility implementation may consume this reviewed contract. Automatic export
must still wait for Item 03 to guard every registered publisher.
The audit tool does not provision, export, publish eligibility, or change runtime
root selection. The shipped app currently still uses the fixed Mapping root.

## Reproducible read-only inventory

```sh
dart run tool/mapping_runtime_inventory.dart
# The same production rules against a disposable/local dataset:
dart run tool/mapping_runtime_inventory.dart --root /absolute/dataset/root
```

The JSON report has `auditVersion: 1`, observation time, canonical root, file
count, total bytes, stale peak fingerprint region keys, and a lexically ordered
`files` array. Each file records `path`, `size`, `sha256`, `startupCheck`,
`startupContent`, `startupReaders`, `liveRuntime`, `importUpdate`, and
`latencySensitive`. Startup booleans describe **preflight/catalog loading**;
conditional ready-app bootstrap content reads are described in the table below.
The tool exits nonzero on unreadable/invalid inputs or stale fingerprints; it
reports stale fingerprints without repairing the manifest. Output is a report,
never pipeline completion or eligibility evidence.

Derivation is `MappingDataStoreCore.preflight()` →
`loadCatalogFromPreflight()` → `MappingCatalog.authorizedPaths`. Thus the real
schema, required polygon inclusion, coverage members, segmented manifest priority,
region rules and path containment remain authoritative. The manifest pair,
regional peaks/highways/polygons, coverage polygons, catalogs, **every declared
DEM**, and display-only polygons are included exactly once. No globs, historical
counts, or tool-manifest permissions derive the app set. Required polygon content
is parsed without a geometry cache; display-only content is hashed/read but its
geometry is not parsed by this diagnostic. Resolver checks reject tool-manifest
reads and escaping symlinks. Trusted raw-byte/hash adapters live in the existing
filesystem owner and are called only by `MappingStoreReadResolver.open`.

SHA-256 streams each file; a size/mtime change during its read fails. Manifest
text changes between catalog reads or by the end of the audit fail too. This
detects common concurrent changes, **not** a coherent publication transaction:
unlocked writers, replacement races, or deliberately preserved timestamps can
escape an observational audit. This is why `coordinatedCapture` is always false.
Item 03 must capture under publication coordination and validate the captured
bytes; do not promote this report into a source-completion record.

Fresh per-path bytes/digests: [2026-10-11 observation](mapping-runtime-audit-2026-10-11.md).
Historical baseline remains **25 files, 4,255,657,108 bytes (3.963 GiB)**,
audited on 2026-10-10. The 2026-10-11 interview retained the path set without
remeasuring sizes/integrity. The linked observation is a separate executed audit.

## Runtime access classification

All references in the fresh observation require startup existence/readability.
Future display-only references are structurally checked at startup but opened
lazily; nevertheless they are required replication inputs. Existing ObjectBox
data never bypasses preflight or required geometry loading.

| Role | Startup content and accessing code | Live runtime / imports and updates | Local-copy benefit |
| --- | --- | --- | --- |
| Manifest pair | `mapping_store_core.dart`: schema/preflight, reread for geometry-cache identity | Catalog remains in memory; maintainer derivation/fingerprint validation reads the pair | Startup metadata/text round trips |
| Required regional and coverage `.poly` | `mapping_store_core.dart`, `polygon_geometry.dart::parsePolygonText`; source text/metadata/hash still read with a geometry cache | Catalog geometry drives region/coverage resolution; `polygon_asset_repository.dart` loads display geometry; GPX import uses that repository | Startup source checks and lazy overlay loading |
| Display-only `.poly` | No startup content/open (only manifest structure); later resolver open | `PolygonAssetRepository.loadPolygons/loadPolygon` → `parsePolygonAsset` | Lazy map overlays; complete future imports |
| Regional peaks | No preflight content; `peak_region_asset_import_service.dart` conditionally seeds/reconciles after ready startup through peak providers | Same service on explicit regional update; preferred-source overlap reads NE/NW/Slovenia/Croatia as needed. Normal browsing reads local ObjectBox peaks/fingerprints | Bootstrap and explicit update source reads, not every peak click |
| Highways | No preflight content; `route_graph_import_coordinator.dart`/`route_graph_coverage_resolver.dart` load missing/stale local coverage at bootstrap/ensureCoverage | Explicit refresh resolves snapshots, merges and validates; ordinary planning uses the imported ObjectBox graph/chunk caches | Graph bootstrap/first coverage load; no per-point source JSON read when graph usable |
| Natural Features | No preflight content; Natural Feature availability/bootstrap triggers `natural_feature_refresh_service.dart` if needed | Refresh parses source in isolate, reconciles local ObjectBox; ordinary browsing uses records | Bootstrap/explicit refresh |
| TasMap | No preflight content; `tasmap_provider.dart::bootstrapFromMappingStore` → `TasmapRepository.reconcileFromMappingStore` | `csv_importer.dart::importFromContents`, explicit update/reconciliation; normal sheet queries read ObjectBox | Catalog bootstrap/reconciliation (including nonempty local store) |
| `DEM/Elvis/elvis_runtime_10m.tif` | Readability check only; GDAL open deferred | `route_elevation_sampler.dart`: `RegionAwareRouteElevationSampler` opens through the resolver and caches native dataset futures; synchronous band reads for geometry-point samples, densified summary and route saving | **Frequent, click-latency-sensitive native raster I/O**; localizing it does not prove UI-isolate CPU/native work is harmless |
| `DEM/tasmania_dem_25m.tif`, `DEM/cop30_hh.tif` | Readability check only | Not selected by current Tasmania sampler; remain required while declared | Startup readiness; no claimed current interactive sampling benefit |

Paths above are under `lib/services/` unless a provider is named. Ordinary
start-point placement performs no segment sampling; subsequent placements
sample geometry and recompute a densified summary. No timings or proven SMB
causality are claimed by the inventory. Item 02 owns instrumented workloads.

ObjectBox records, route-graph chunks, settings, GPX files and tile/parsed-geometry
caches are local data/cache, not Mapping source authority. Raw ELVIS, ELVIS topo
DEM, undeclared files (including other TasMap CSVs/spreadsheets), tool-only data,
Overpass/container state, unrelated Services content, Local Topo payloads,
personal databases, API-key files and private configuration are excluded.

## Publisher register and Item 03 transaction boundaries

Audited surfaces: all repository Dart tools and shell/Python wrappers, tool
manifest fixture, runtime consumers, operating docs, mini
`/Volumes/Development/overpass_turbo/{README.md,slovenia-highways.sh}`, and the
canonical store's dataset-directory names (names are not dependency authority).
No app consumer writes Mapping payloads. The repo's declared payload writers are
fingerprints, theLIST DEM and ELVIS; all other canonical promotions below are
manual maintenance, which must be registered rather than assumed lock-aware.

| Publisher / promotion | App targets / related changes | Required guarded transaction |
| --- | --- | --- |
| `tool/update_region_peak_fingerprints.dart` + `region_peak_fingerprint_support.dart` | `region_manifest.json`; SHA-256 of concatenated regional peak bytes in **declared order**, not sorted paths or concatenated digests | Enclose peak promotion(s) plus fingerprint regeneration and validation in one outer maintenance transaction; standalone fingerprint repair also guarded |
| Manual Overpass Turbo/export or curl snapshot promotion, all six regional peak sources | `Peaks/*-peaks.json` referenced by the manifest; dependent manifest fingerprint | Prepare outside Mapping; named exact-file promotion capability, then fingerprint update, validate whole resulting app set before completion |
| Manual highway exports; mini `slovenia-highways.sh` | All four referenced highway JSONs. The inspected script only fetches `slovenia-highways.json` to its **cwd**, with no final promotion/lock/validation | Guard final promotion, including if invoked with Mapping/Highways as cwd. Multi-region FVG/Veneto/Slovenia updates must hold one transaction across commands and final coverage validation. Script cwd is not authorization |
| Manual Natural Feature export/promotion | `Features/tasmania_natural_features.json`; dependency geometry is part of the same JSON | Guard complete-file promotion plus parser checks; Overpass API/container replication itself does not publish app files |
| `tool/download_tasmania_thelist_dem.dart` → `tool/publish_thelist_dem.sh` | `DEM/tasmania_dem_25m.tif`, retained `--output-file` substitutions that target any app reference | External preparation can be unlocked; resolver staging/commit and related manifest updates share outer transaction. Internal shell worker only accepts staged typed output; no new raw final-target writes |
| `elvis_dem.sh` → `tool/elvis_dem.dart build-runtime/build-all` | Runtime TIFF; build-all additionally promotes excluded topo derivative | Runtime promotion/validation/related manifest edits guarded; one outer transaction for build-all, retain existing separate output capabilities. build-topo-only is outside app set unless combined with an app update |
| Manual Copernicus preparation/promotion (no dedicated publisher found) | `DEM/cop30_hh.tif` | Exact declared target capability + full raster validation; related declaration edits in same transaction |
| Manual TasMap spreadsheet/CSV maintenance | `Maps/tasmap50k.csv` (sibling `.xlsx` is preparation, not app input) | Prepare and parse CSV outside store; guard exact-file publication and any catalog declaration edit |
| Manual polygon editing/promotion, boundary conversion review output | All required/display `.poly`, `Polygons/manifest.json`, regional `poly`/basemap `coveragePoly` declarations | One transaction covering geometry and both manifest changes. `tool/convert_osm_boundary_to_poly.sh` writes non-store review output only; it gains no Mapping authority implicitly |
| Manual region/coverage/basemap/DEM/catalog manifest edits | `region_manifest.json`, `Polygons/manifest.json`, fingerprints and added/replaced payloads | Validate pair and full resulting dataset, including removed references; no unlocked editor/save/cp/mv gaps |
| Tool manifest bootstrap/manual reviewed replacement | Tool-only `tool_manifest.json`, not replicated | Retain restricted bootstrap capability. Coordinate capability changes affecting payload publishers with their maintenance transaction; never make this an app dependency |

`rank_fvg_peaks`, Hribi tools, prominence/PeakBagger CSV sync, route-graph report
tools, and Local Topo rebuilds write reports/user data/cache, not canonical app
payloads. Manual promotion of their outputs, if ever used as app sources, is a
new registered guarded publisher with exact authorization and format validation.

Item 03 must provide mini-local `maintenance begin/run/complete/recover` entry
points (names here are the required interface roles, not existing commands).
The outer transaction supplies an ownership token to children, preventing nested
lock deadlock or child completion of the outer operation. Hook the existing
resolver publication boundary for targets intersecting the derived app set;
retain every tool's exact output authority. Provide separate exact-target named
capabilities for manual promotions, not a wildcard store-write shell. Update
all operating procedures and the external script/promotion procedure before
automatic export is enabled. Unregistered publishers block that gate.

Completion requires validation of the post-publication complete set, journaled
commit of all related changes, and durable success evidence. Interrupted writers
leave `publishing`/`recovery-required` evidence even when their OS lock is free.
Recovery must validate/finish the intended set or restore backed-up old payloads
and manifests and record `rolled-back`; capture cannot infer completion from a
free lock. The maintainer confirmed this register covers their actual manual
and external commands during revision 1 review; new publisher workflows must be
registered and guarded before use. Inspection alone cannot certify private scripts.

## Source/local validation matrix — profile `mapping-runtime-v1`

Both source **independent capture** and local candidate run the same profile.
Validation never imports/reconciles into a personal ObjectBox store. Production
parsers that are currently coupled to persistence must expose pure parse/plan
entrypoints in Item 04; reuse their implementations, do not duplicate schemas.
Warnings/skips and counts belong in the validation report with paths and parser
revision; allowed production skips are not converted silently into stronger
semantic guarantees.

| Format | Exact production checks to reuse | Additional v1 payload checks required before eligibility | Guarantees and limitations |
| --- | --- | --- | --- |
| Manifest pair and all paths | `validateMappingManifestPair`, `MappingDataStoreCore.preflight/loadCatalogFromPreflight`, `MappingStoreReadResolver` | Derive inventory again from captured manifests; exact path-set equality to integrity record; all files regular/readable and contained; no symlinks in published payloads (stricter than contained source symlinks) | Preserves schema, priorities, hardcoded required catalog/DEM paths, routing members and startup ordering. Does not certify geographic truth |
| Peaks | `_loadCatalogRegionSource/_parseCatalogPeak` in `PeakRegionAssetImportService`, including MGRS enrichment; source overlap policy preserved separately | Pure parser extraction; valid UTF-8 JSON object/elements array with object entries, validate accepted peak node ID/name/finite bounded coordinates and enrichment. `findStaleSeedableRegionFingerprints` / `computeSeedableRegionFingerprints` with **raw bytes in declared source order** must match every declared seedable-region fingerprint | Malformed accepted peaks and stale bytes fail; production ineligible elements and absent/invalid optional elevation are still skipped/null. No completeness, recency or elevation-accuracy claim; must not rewrite fingerprints to make a candidate pass |
| Highways | `RouteGraphCoverageResolver.resolveCoverage`, `_decodeOverpass`, `_CoverageElementMerger`, `validateSelectedRouteGraphWays` | Parse every source JSON envelope and merge every declared coverage using current policy; require object entries and positive type/ID identities, validate selected ways against merged support nodes. Use the pure generation builder for chunk preparation without database writes | Detects conflicting duplicates except explicit FVG-over-Slovenia policy, malformed tags/selected-way references and coordinate failures. Skipped nonselected elements remain allowed. No graph connectivity, routing accuracy or OSM freshness guarantee; graph source hash keeps merge-policy marker and full snapshots |
| Natural Features | `buildNaturalFeatureRefreshPlan` and its `_NaturalFeatureSource`/geometry routines; production `PeakMgrsConverter.fromLatLng` for planned centroids | Valid UTF-8 JSON object/elements array; object entries; execute pure plan and MGRS conversion, record skipped identities/reasons | Same eligible-feature duplicate/conflicting dependency and supported geometry checks. Identical tagged/skeleton repeats allowed. Valid unsupported node-only relations skipped and reported. No new centroid fallback, completeness, topology or geographic-accuracy claim |
| TasMap | `CsvImporter.importFromContents` (also used by `TasmapRepository.reconcileCsvContents`) | Strict UTF-8 text + entire parser before publication | RFC 4180, exact unique required headers, nonempty data, normalized unique `(Series, Name)`, required values/integers, contiguous 4/6/8/10/12 MGRS point strings. `Parent` header required, value may be empty. Integer parsing/string shape is not proof of real-world bounds or correct sheet geometry |
| Required and display polygons | `parsePolygonText`; display `parsePolygonAsset` wraps it | Parse **every** polygon, not just startup geometry; reject failed parse even if an old geometry cache exists | Finite bounded coordinates, at least 3 distinct normalized vertices, first-ring end, no unsupported extra rings. No self-intersection/orientation/real-world-boundary proof; preserve accepted production polygon syntax |
| All three DEMs | Resolver readability; `GdalDemDataset.open`/`GdalDemDatasetOpener` for production band/transform access; ELVIS preparation validation in `tool/elvis_dem.dart` is source-specific | Read-only GDAL GTiff/BigTIFF open; positive dimensions, numeric band 1, finite invertible geotransform, usable CRS and WGS84 transform; **decode every band-1 block**, not just headers/probes, reject GDAL decode errors/nonfinite non-NoData samples; record dimensions, CRS, NoData, block counts. Close all native resources on success/failure | Detects malformed/truncated required raster and unreadable compressed blocks in sampled band. No universal NoData coverage/vertical-datum/terrain-accuracy guarantee, no hardcoded universal CRS or resolution assumption (theLIST/Copernicus differ). Sidecar writes disabled (`GDAL_PAM_ENABLED=NO`); ambient sidecars must not supply validity. Fresh audit below did not run this full check |

Transfer integrity: received/captured file length and **SHA-256 of every raw byte**
must equal a completed source inventory. This proves equality to that export,
not validity of upstream content. Dataset validity is only the matrix's stated
checks. Missing/truncated/digest-mismatched files, invalid manifest/reference,
required/display geometry errors, stale peak fingerprints, or failed profile
checks prohibit eligibility. Both ends must use this profile revision; no
"preflight-only" or "digest-only" success can be accepted.

## Versioned metadata contracts

All records are UTF-8 JSON objects with `kind`, integer `schemaVersion: 1`,
and no duplicate keys. Required fields below are mandatory; unknown versions,
invalid enums/IDs, unexpected paths and unsupported profiles fail closed.
Unknown fields at v1 are rejected (future additions require an explicit schema
revision). IDs are lowercase UUIDs; SHA-256 strings are 64 lowercase hex digits;
sizes are nonnegative JSON integers. Times are UTC ISO-8601 diagnostics, never
lock/liveness evidence. Record paths are constructed from IDs by their owner,
not accepted as arbitrary absolute paths from a peer. Atomic publication means
write temporary sibling, flush file, same-filesystem rename, flush parent; retain
recovery records until commit is durable. Later implementation must verify the
platform's flush/lock semantics with fault tests rather than assume Dart rename
alone provides power-loss durability.

The integrity object has ordered keys `kind`, `schemaVersion`, `generationId`,
`files`; `files` is lexically sorted by exact store-relative `path`, with unique
entries having ordered keys `path`, `size`, `sha256`. `inventorySha256` is SHA-256
of `utf8.encode(jsonEncode(integrityObject))`, compact JSON without BOM/newline,
preserving this key order and without escaping `/`. No sums-of-digests substitute
for file hashing. Exact derived path-set equality is mandatory; no tool manifest
or destination-only metadata appears in this list.

| `kind` / record | Required fields in addition to envelope | Meaning / failure recovery |
| --- | --- | --- |
| `mapping-integrity` | `generationId`, `files: [{path,size,sha256}]` | Complete immutable app payload identity, including manifest pair |
| `mapping-source-completion` | `generationId`, `inventorySha256`, `operationId`, `publicationId`, `sourcePreparerRelease`, `validationProfile`, `validatedAtUtc` | Published last after captured-byte/source matrix validation; bind successful canonical publication evidence. No completion record for a partial export |
| `mapping-publication` | `publicationId`, `operationId`, `owner`, `state`, `priorInventorySha256` (nullable initial), `intendedPaths`, `backupId`, `resultInventorySha256` (nullable until complete), `startedAtUtc`, `finishedAtUtc` (nullable) | States `publishing`, `recovery-required`, `complete`, `rolled-back`; old backup evidence and per-target progress in separate same-ID journal. Only complete/validated rollback unblocks capture |
| `mapping-publication-journal` | `publicationId`, `operationId`, `steps: [{path,priorSha256,nextSha256,state}]` | Nullable prior digest only for previously absent target; `state` = `prepared`, `published`, `restored`; retain backups until complete durable record or validated rollback |
| `mapping-operation` | `operationId`, `parentOperationId` (nullable), `owner`, `releaseId`, `stage`, `state`, `generationId` (nullable), `publicationId` (nullable), `protectedExportIds`, `protectedGenerationIds`, `startedAtUtc`, `progressAtUtc`, `outcomeRecordSha256` (nullable) | Stages prepare/transfer/capture/validate/receipt/cleanup; states running/outcome-unknown/succeeded/failed. Pin release/helpers/data until ownership proven ended |
| `mapping-durable-receipt` | `receiptId`, `operationId`, `generationId`, `inventorySha256`, `sourceCompletionSha256`, `localValidationReportSha256`, `controllerRelease`, `storedAtUtc` | Durable independent local capture + completed local validation. Does not require app activation. Source persists verified same identity acknowledgement before export cleanup; lost acknowledgement is retried idempotently |
| `mapping-validation-report` | `generationId`, `inventorySha256`, `operationId`, `validationProfile`, `validatorRelease`, `state`, `checks`, `diagnostics`, `validatedAtUtc` | State passed/failed; `checks` = array of `{path,checkId,result}` with result passed/failed/skipped, `diagnostics` = string array. Required profile checks cannot be skipped; explicitly allowed content skips reported. Check IDs/profile algorithm revisions fixed by installed release |
| `mapping-eligibility` | `generationId`, `inventorySha256`, `sourceCompletionSha256`, `validationReportSha256`, `controllerRelease`, `validationProfile`, `eligibleAtUtc` | Stored outside payload after immutable capture, exact inventory match and successful local profile validation. Never written inside incoming. Failed/interrupted captures get no eligibility |
| `mapping-selection` | `selectionId`, `active`, `recovery` (nullable), `revision`, `selectedAtUtc` | `active`/`recovery` = `{generationId,inventorySha256,eligibilitySha256}`; revision monotonic positive integer. One coherent old/new tuple, not independent mutable pointers |
| `mapping-selection-transaction` | `operationId`, `priorSelection` (nullable), `nextSelection`, `state` | Full selection objects; states prepared/committed. Durable intent + prior copy precede atomic next selection. On restart choose proven complete old or new tuple; never merge fields |
| `mapping-session` | `sessionId`, `owner`, `generationId`, `inventorySha256`, `appReaderRelease` | Informational identity paired with a held OS process-lifetime lock; stale file/PID alone does not imply a live pin |

`owner` in operation/publication/session records is
`{hostId,bootId,pid,processStartId,ownershipToken}`. Random ownership token and
boot/process-start identity prevent PID reuse and another process releasing a
lock. The installed operation supervisor owns the actual OS lifetime lock and
survives the controller/SSH client where necessary. A diagnostic heartbeat is
not authority to steal protection. Source completion/eligibility SHA fields bind
the exact persisted record bytes. Local launch checks these small metadata
digests/identities, inventory equality and retained-generation boundaries, then
normal preflight. It does **not** rehash multi-gigabyte payloads. This relies on
controller-owned immutable directories and no later payload writer; uncontrolled
edits require background revalidation and cannot retain eligibility.

## Layout, ownership and recovery protocol

Names below are contract roles; setup may select actual machine-local directories.
No coordination paths are under `/Volumes/Services/Mapping` or a source-workspace
sync root. Canonical configuration on mini and default replica Application Support
configuration on MacBook remain separate from `dart_defines.local.json`.

| Owner | Scope / permitted capability |
| --- | --- |
| Canonical publisher | Existing named `MappingToolResolver` exact outputs; coordination only wraps publication, does not widen authority |
| Source preparer | Snapshot-read capability from validated manifest set/`MappingStoreReadResolver`; write only its external capture/export area and completion records |
| Publication coordinator | Mini-local lock, publication journal/backups/operation metadata outside dataset; no general dataset writer. Recovery uses original publisher's exact capabilities |
| Replica controller | Incoming observation, independent copy/CoW clone, generation publication, validation/eligibility, receipts, retention and local operation metadata under configured replica base |
| App selection/session owner | Machine-local configuration read, local selection transaction/session metadata only; concrete generation read resolver; **zero Mapping payload writes** |
| Release installer | Versioned controller/source-preparer release directories, atomic release selection, invocation pins; no canonical data or active/recovery-generation mutation |

Add narrowly inventoried filesystem/process owners for these roles and scoped
direct-I/O tests when they are implemented. Keep the current guard's non-store
allowlist/callsite counts; do not globally permit replicas as arbitrary writable
paths or import tool manifests into shipped app runtime. Diagnostic inventory
uses the existing filesystem owner and adds no guard exemption.

Mini external layout: coordination/publication state, versioned installed
source-preparer releases, protected independent exports, and a completed export
publication surface. MacBook: installed controller releases; **Mutagen-writable
incoming only**; independent `generations/<generationId>/payload`; external
integrity/completion/validation/eligibility metadata; selection transaction,
process-lifetime sessions, operations/receipts, configuration and logs. Mutagen
alpha is mini prepared-export surface, beta incoming, name
`mapping-runtime-replica`, effective mode `one-way-replica`. Metadata must be
placed outside beta except the source's synchronized integrity/completion record.
Local-only records and retained generations must never be destination-only files
that Mutagen can remove.

1. Source capture takes the shared publication lock, reconciles publication
   completion/recovery, derives the entire set and independently copies it under
   that lock. Release canonical capture lock only after copying has finished;
   validate/hash the protected capture, publish a complete immutable export last.
   Hold export protection through synchronization/durable receipt. A changed
   scheduled tick does not by itself create a generation.
2. Transfer may span many 60-second ticks. Idle status is transport progress only.
   Controller independently captures incoming with copies/CoW clones, **never
   writable hard links**, checks source-completion/inventory identity before and
   after capture, runs hashes/profile against captured bytes, and only then
   publishes external eligibility. Later incoming mutations cannot change it.
3. Launch acquires selection coordination, remembers prior active selection,
   checks newest pending eligibility + normal local preflight/catalog, then
   atomically commits/pins the concrete generation. Failed candidate/preflight
   or selection publication falls back to active, then recovery. Pin before
   releasing coordination so concurrent cleanup/launch cannot remove it. Ready
   ObjectBox initialization occurs afterwards; initialization failure is not a
   dataset rollback. Retry repeats this launch boundary.
4. App holds a process-lifetime pin until exit **and until native handles/workers
   are closed/joined**. Current GDAL future cache retains native resources; any
   new worker/cache requires explicit ownership/disposal. Pending updates cannot
   switch late imports/lazy opens in a running app. Controller retains active,
   one previous validated recovery, newest eligible pending, every live session
   and every producing/validating operation's generation/export/release.
5. Cleanup takes the same local selection/retention coordination, inspects held
   lifetime locks, and prunes only unprotected data. Insufficient space preserves
   protected data and reports a failed stage. Source retains the sole outstanding
   unacknowledged export; finish its receipt or block new export publication,
   never accumulate exports without bound or delete an ongoing transfer source.
6. One mutation-owning controller invocation spans scheduled/manual/provisioning
   calls. Busy ticks defer. Proposed bounded policy: lock acquisition ≤5 seconds;
   SSH connect ≤10 seconds with BatchMode, two unanswered 15-second keepalives;
   each status/inspection RPC ≤30 seconds; progress polling every 5 seconds,
   no-progress threshold 10 minutes, per-stage supervisor budget 2 hours. Healthy
   progress can cross ticks; a budget expiry is `outcome-unknown`, not completion
   or permission to launch duplicate work. Limits must be recorded/configured by
   installed release and adjusted explicitly for measured dataset workloads.
7. Before any conflicting retry, bounded inspection reconciles the same
   operation ID, supervisor ownership, installed release pins, stage/progress
   and durable outcome evidence. Local client exit/SSH termination alone says
   nothing about remote preparer completion. Retain protection on unresolved
   identity/ownership; expose blocked recovery, permit subsequent inspection.
   Confirmed failure/end permits cleanup/retry; proven durable success permits
   continuation. Never release another token's lock or assume a reused PID owns
   the original process.

## Compatibility and installed-release contract

This is a reviewed protocol version, not a claim of installed readers today.

| Source preparer | Controller | App reader | Permitted records/profile |
| --- | --- | --- | --- |
| `source-preparer-v1` | `controller-v1` | `app-reader-v1` | All above schemas 1, `mapping-runtime-v1`; required runtime manifest schema unchanged |
| Existing fixed-root app | Any proposed replica release | Existing reader | Does not consume replica selection/eligibility; replica mode not delivered yet |
| Unknown/unsupported major or profile | Any | Any | Reject before publication, activation, destructive cleanup or release selection; keep retained readable generations |

Release manifest includes `releaseId`, role, complete executable/helper artifacts
and SHA-256s, supported record versions/profile IDs, and pinned executable/native
dependency identities. Installed code cannot resolve imports/helpers from a
changing checkout. Source/controller invocation selects and lifetime-pins one
installed release before dispatch; children/surviving supervisor share that pin.
Atomic upgrades preflight both sides and every retained active/recovery record
against the compatibility table, then change future release selection; old
invocations continue their old artifacts. Compatible v1 fixes keep profile
semantics; a new validation guarantee requires a new profile and explicit support.
Incompatible upgrades fail before modifying old state. Recover by reselecting a
compatible retained release through the installer after inspecting live pins;
do not regenerate eligibility, edit versions by hand, or delete recovery data.
LaunchAgent (login and every 60 seconds), installers/controller implementation
and live version/durability fault evidence belong to later items.

## Review evidence and unresolved guarantees

- Inspected production schema/read/write boundaries, import parsers, routing
  merge/way validation, Natural Feature worker, CSV/polygon parsers, native GDAL
  open/sample path and named tool output contracts on 2026-10-11.
- Fixture audit tests exercise full set, all DEMs, coverage/display additions,
  deduplication, invalid/escaping references, display symlink escape, ordered
  raw-byte fingerprints, read-only behavior and manifest change rejection.
- Fresh byte/digest/preflight/fingerprint evidence is linked above; it is not
  full matrix validation, a performance benchmark or coherent export evidence.
- Maintainer review on 2026-10-11: selected **Approve revision 1** for the
  matrix/profile guarantees, full band-1 DEM decoding policy, metadata schemas,
  lifetime/recovery/compatibility and bounded-wait policy; separately selected
  **Register is complete** for external/manual publisher coverage. This is
  approval of the contract, not evidence that the later pipeline is implemented.
- Platform-level lock/supervisor identity, flush durability, native-resource
  cleanup, actual space/transfer costs, installed GDAL/PROJ dependencies and
  bounded-wait commissioning must be verified in later items. Geographic truth,
  freshness, graph connectivity, raster accuracy/NoData coverage, and protection
  from uncontrolled manual edits are not guaranteed by this matrix.
