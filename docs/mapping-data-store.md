# Mapping Data Store Contract Inventory

Recovered from `nas-migration` commit `a1222df` (Work Item 01), with resolver
authorization from Work Item 11 and the maintainer/runtime cutover from Work Item 12.

## Ownership and rules

The **Mapping data store**, `/Volumes/Services/Mapping`, is the canonical,
app-read-only owner of non-UI regional peaks, highways, polygons, TasMap,
Natural Features and DEMs. The **Mapping data manifest** is
`region_manifest.json`; `Polygons/manifest.json` is the required polygon
authority. The shipped app must never query Overpass and never loads
`tool_manifest.json`, which authorizes only maintainer tools.

`assets/` is reserved for UI assets. Legacy mapping paths recorded below are
retired contracts, not allowed aliases. ObjectBox and `~/Documents/Bushwalking`
are **user data**. Offline basemap tiles are a user-managed app-support **cache**
sourced from tile services. The app-support geometry **cache** retains parsed
geometry only; it is invalidatable, never a Mapping-source authority.
Resolver staging, extracted archives and build scratch space are **temporary
data**. Logs, previews, review CSVs and metadata are **reports**. Raw ELVIS,
theLIST, Geofabrik, Hribi, Nominatim and local Overpass are **maintainer-only
external sources**. These classifications do not grant Mapping-store writes.

The **Northeast Alps routing coverage** is FVG, Veneto and Slovenia, including
the required `Highways/slovenia-highways.json` source.

## Runtime entrypoints

All Mapping reads below receive validated catalog references; no runtime
Mapping writes are permitted.

| Entrypoint | Mapping inputs and non-store ownership |
| --- | --- |
| `lib/main.dart` <!-- inventory:lib/main.dart --> | Startup manifest pair, immutable catalog, ready-only user ObjectBox and tile cache. |
| `lib/services/peak_region_asset_import_service.dart` <!-- inventory:lib/services/peak_region_asset_import_service.dart --> | Regional `peaks` references; peaks and fingerprint records are user ObjectBox data. |
| `lib/services/route_graph_coverage_resolver.dart` <!-- inventory:lib/services/route_graph_coverage_resolver.dart --> | Coverage-qualified `highways` references; route-graph rows are user ObjectBox data. |
| `lib/services/polygon_asset_repository.dart` <!-- inventory:lib/services/polygon_asset_repository.dart --> | Lazy display reads from `Polygons/manifest.json`; parsed geometry is cache. |
| `lib/services/natural_feature_refresh_service.dart` <!-- inventory:lib/services/natural_feature_refresh_service.dart --> | `naturalFeatures.catalog = Features/tasmania_natural_features.json`; feature records are user data. |
| `lib/services/tasmap_repository.dart` <!-- inventory:lib/services/tasmap_repository.dart --> | `tasmap.catalog = Maps/tasmap50k.csv`; sheet records are user data. Legacy explicit CSV reads are non-store import adapters. |
| `lib/services/route_elevation_sampler.dart` <!-- inventory:lib/services/route_elevation_sampler.dart --> | `demSources.elvisRuntime = DEM/Elvis/elvis_runtime_10m.tif`; GDAL dataset open is a trusted opaque binary adapter; host GDAL/PROJ probes are non-store dependency checks. |
| `lib/services/tile_cache_service.dart` <!-- inventory:lib/services/tile_cache_service.dart --> | User offline tile cache only, no Mapping I/O. |
| `lib/services/import_path_helpers.dart` <!-- inventory:lib/services/import_path_helpers.dart --> | Bushwalking user paths only. The home-directory DEM helper is retired. |

The former `lib/services/overpass_service.dart` is retired. The generated
catalog tool/output are also retired; the validated manifest pair is the only
runtime authority.

The TasMap CSV retains the canonical `Parent` header, but its values may be
blank and are stored as an empty `parentSeries`. Reconciliation matches sheets
by trimmed, case-insensitive `(Series, Name)`: unchanged rows are not written,
changed rows retain their ObjectBox IDs, new rows are inserted, and rows absent
from the authoritative CSV are deleted. Clearing a previously populated parent
counts as a content change.

Natural Features retains Spec 0058's distinction between eligible tagged features
and geometry dependencies. A tagged feature repeated as an untagged skeleton is
accepted when its geometry agrees, in either source order. Matching repeated
dependency nodes, ways, and relations do not create additional features or count
as skipped candidates. Geometry comparison uses coordinates, ordered node
references, or ordered member type/reference/role tuples; absent and empty roles
are equivalent. Duplicate eligible features and conflicting or invalid repeated
geometry fail the operation before ObjectBox writes.

Well-formed non-multipolygon Natural Feature relations whose members are all
valid, resolvable nodes are skipped as unsupported centroid geometry. Each
increments the refresh's skipped count and emits a diagnostic containing its
OSM identity, name, and reason; existing OSM and Manual rows for that identity
are retained. Missing/invalid members or nodes, node-only multipolygons, and
broken supported geometry still fail before writes. No averaged node position
or centroid fallback is introduced.

## Maintainer tool contracts

Approved source precedence is explicit and narrow:

- Peak source ownership follows **NE over NW** and **NE over Slovenia over
  Croatia**. NW and Slovenia validate their full sources against current NE
  sources; Croatia validates against current NE and Slovenia sources. Skip
  overlapping identities once per losing region, independently of import order.
  Existing OSM-owned losing rows transfer to a preferred owner with their IDs and
  user fields preserved; retain them until that succeeds. User-owned/unowned rows
  and unrelated-region conflicts remain protected. The shared
  `preferredPeakSourceRegions` policy governs both filtering and transfers.
  Source snapshots are not changed to implement this policy.
- Within Northeast Alps, **FVG wins over Slovenia** for conflicting complete OSM
  elements, including ways and supporting nodes. This is independent of source
  order, retains Slovenia-only elements, and emits conflict-resolution diagnostics.
  Conflicting repeats within one region and conflicts involving Veneto or other
  regions still fail. Validate retained selected geometry before graph writes.
  The hash payload includes `sourceMergePolicy: fvg-over-slovenia-v1` and every
  full source snapshot. Usable bootstrap still reads no highway source; manual
  refresh resolves current snapshots with this policy.

Each Mapping tool ID is declared in the v1 `tool_manifest.json` fixture. Named
capabilities are loaded before Mapping source reads or publication. Required
inputs are validated before source processing or subprocess execution. External/user
overrides listed here are handled by explicit non-store adapters, not by
relaxing Mapping-store resolver rules. Mapping overrides are safe relative
paths targeting one declared placeholder only.

| Entrypoint / command | Inputs, outputs, retained overrides and write policy |
| --- | --- |
| `tool/convert_osm_boundary_to_poly.sh --polygon <veneto\|fvg\|emilia-romagna\|trentino-alto-adige\|all>` <!-- inventory:tool/convert_osm_boundary_to_poly.sh --> | Retired `assets/polygons/osm-boundaries/{veneto_poly.geojson,fvg.geojson.gz,emilia-romagna.geojson.gz,taa.geojson.gz}`. External snapshots default to `/Volumes/Development/overpass_turbo/exports/osm-boundaries`; explicit `--source-dir` is non-store. `build/polygon-conversion/<polygon>` is review/report output. Retain `--output-dir`, simplification/buffer settings, `--keep-work`. Both operands are checked through `non_store_paths.dart`, including source symlinks, before use. No Mapping writes. **Non-Dart: store-isolated**; store promotion needs a separate declared output. |
| `dart run tool/route_graph_peak_list.dart` <!-- inventory:tool/route_graph_peak_list.dart --> | ID `route-graph-peak-list`: regional/polygon manifests, `Highways/*.json`, `Polygons/*.poly`. Default `--region tasmania`; user input `~/Documents/Bushwalking/Features/peaks.csv`; user output `~/Documents/Bushwalking/Peak_Lists/<canonical-region>-route-graph-peak-list.csv`. Retain `--region`, `--output`; no Mapping writes. |
| `./peak_prominence_csv.sh validate\|import [--dry-run] --csv-path PATH` <!-- inventory:tool/peak_prominence_csv.dart --> | ID `peak-prominence-csv`: retired `assets/all-peaks-sorted-p100.csv`; an explicit non-store user CSV or positional CSV is required. Preview `tool/peak-prominence-objectbox-preview.csv` and `logs/prominence*.log` are reports; ObjectBox is user data. **Dart: store-isolated**, no Mapping reads/writes; user path guard runs before access. |
| `dart run tool/update_region_peak_fingerprints.dart` <!-- inventory:tool/update_region_peak_fingerprints.dart --> | ID `update-region-peak-fingerprints`: `region_manifest.json`, `Peaks/*-peaks.json`; the shared regional parser validates the manifest before hashing. Only Mapping write is atomic replacement of `region_manifest.json` through the in-process output capability. No CLI overrides. |
| `dart run tool/validate_region_peak_fingerprints.dart` <!-- inventory:tool/validate_region_peak_fingerprints.dart --> | ID `validate-region-peak-fingerprints`: same manifest and peak inputs, shared parser; no writes/overrides. |
| `tool/region_peak_fingerprint_support.dart` <!-- inventory:tool/region_peak_fingerprint_support.dart --> | Shared support, no standalone command. Retire `assets/region_manifest.json` reads/writes; use the invoking fingerprint tool's capability. |
| `dart run tool/slovenia_hribi_source_peak_list.dart` <!-- inventory:tool/slovenia_hribi_source_peak_list.dart --> | ID `slovenia-hribi-source-peak-list`: manifest pair and declared polygon geometry drive canonical region correlation; Hribi pages are external, user CSV defaults to `/Users/adrian/Documents/Bushwalking/Features/peaks.csv`. Retired `assets/peaks` output; default reports are `build/slovenia-peak-reports`. Ranked/review/repair/state files are reports, web results are cache. Retain `--output-dir`, `--peaks-csv`, `--source-of-truth`, `--repair-list`, `--refresh-cache`, `--tie-window-meters` (default `10m`). User/report/cache targets reject Mapping paths, including symlinks. No Mapping writes. |
| `dart run tool/sync_peakbagger_csv.dart [CSV]` <!-- inventory:tool/sync_peakbagger_csv.dart --> | ID `sync-peakbagger-csv`: `peak-bagger-peak-data.csv`, sibling `-lat-lon.csv` and ObjectBox are user data; `logs/import.log`/`PEAKBAGGER_PROGRESS_FILE` are reports; PeakBagger lookup is external. Retain positional CSV, `--create-unmatched-peaks`, `--name`, `--elevation`, `--tolerance`, `--rows`. **Dart: store-isolated**, every selected CSV/report operand is checked as non-store before I/O. |
| `dart run tool/rank_fvg_peaks.dart` <!-- inventory:tool/rank_fvg_peaks.dart --> | ID `rank-fvg-peaks`: manifest pair, `Peaks/*-peaks.json`, `Polygons/*.poly`; retire all `assets/peaks/...`/`assets/polygons/veneto.poly` inputs. `.cache/<region>-peak-ranker` is cache; `<region>-top-peaks.{json,csv}`/`lesser_<region>_peaks.csv` are reports. DuckDuckGo/Jina/Nominatim are external. Retain `--region-key` (default `fvg`), `--top`, `--max-candidates`, `--delay-ms`, `--cache-dir`, `--output-json`, `--output-csv`, `--output-lesser-csv`, `--second-pass-only`, `--offline`, `--refresh-cache`; no Mapping writes. |
| `dart run tool/download_tasmania_thelist_dem.dart` <!-- inventory:tool/download_tasmania_thelist_dem.dart --> | ID `download-tasmania-thelist-dem`: external theLIST manifest/ZIPs; workspace defaults to `build/dem/thelist_25m`, checked as non-store. `raw_zips/`, `extracted/`, `rasters.txt`, VRT are temporary/cache. Only Mapping write is atomic `DEM/tasmania_dem_25m.tif`; GDAL receives a typed, resolver-expanded staged output. Retain `--output-dir`, `--list-only`, `--skip-merge`, and store-relative `--output-file`. The command descriptor is the GDAL publication step; orchestration prepares the external VRT first. |
| `./elvis_dem.sh validate-source\|build-runtime\|build-topo\|build-all [--validate]` <!-- inventory:tool/elvis_dem.dart --> <!-- inventory:elvis_dem.sh --> | IDs `elvis-dem-runtime`, `elvis-dem-topo`. Raw source is `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif` (external). Preparation, metadata, previews and reports default to checked non-store `build/dem/elvis`. Mapping writes: streaming resolver-owned staging then atomic `DEM/Elvis/elvis_runtime_10m.tif` and snapshot `DEM/Elvis/elvis_topo/elvis_topo_5m.tif`. Legacy home DEM root and `tool/elvis_dem_manifest.json` are retired. Binary environment override only; source/workspace/publisher injection is test-only. **Non-Dart wrapper: store-isolated**, delegates to named Dart capabilities from repository cwd. |
| `tool/mapping_tool_support.dart` <!-- inventory:tool/mapping_tool_support.dart --> | Shared named-capability and catalog assembly, no standalone command. Uses the production schema parser, declared reads, and repository-root cwd. No additional permissions. |
| `dart run tool/local_topo_rebuild.dart` <!-- inventory:tool/local_topo_rebuild.dart --> | IDs `local-topo-rebuild` / `local-topo-rebuild-external`; selected Mapping inputs are resolver-expanded only. Named `thelist` and `copernicus` use `demSources`; default `elvis-topo` uses the tool's `dem` declaration. `--dem-path` is store-relative; `--external-dem-path` is a distinct absolute non-store adapter. Worker flags are parsed/whitelisted; no Mapping writes. |
| `tool/non_store_paths.dart PATH...` <!-- inventory:tool/non_store_paths.dart --> | Store-isolated validation bridge for shell external/cache/report operands. Reads only path metadata through the shared boundary, grants no Mapping content or write permissions, and needs no tool-manifest entry. |
| `tool/publish_thelist_dem.sh` <!-- inventory:tool/publish_thelist_dem.sh --> | **Non-Dart: resolver-validated paths only**. Internal GDAL publication worker receives the staged Mapping output as its first operand and a checked non-store VRT as its second (default `build/dem/thelist_25m/tasmania_dem_25m.vrt`). No Mapping input or final-target path construction; PAM sidecars are disabled. |
| `dart run tool/mapping_store.dart provision-or-verify` <!-- inventory:tool/mapping_store.dart --> | ID `mapping-store-provision`: shared parser reads runtime pair and named `tools` input `tool_manifest.json`; fixtures are version-controlled non-store input. No Mapping writes. Bootstrap is a separate restricted capability. |

## Local Topo non-Dart classification

Local Topo outputs are cache/temporary/report data, served by its separate
service, not Mapping inputs for the app. Named DEM selection must use the
resolver; no `LOCAL_TOPO_*_DEM_TIF` or `~/DEM/Tasmania` Mapping fallback.

| Entrypoint | Defaults, overrides and classification |
| --- | --- |
| `local_topo/tasmania/scripts/rebuild_stack.sh` <!-- inventory:local_topo/tasmania/scripts/rebuild_stack.sh --> | **Resolver-validated paths only**, ID `local-topo-rebuild`: default `DEM/Elvis/elvis_topo/elvis_topo_5m.tif`; `--dem-path` may substitute only its declared input. Named source choices use `demSources`/tool declaration; an explicit non-store external override is a separate adapter. Defaults manual mode, `elvis-topo`, prerender enabled. Retain `--mode`, `--dry-run`, `--skip-prerender`, `--force-source-refresh`, `--dem-source`. Geofabrik/local OSM is external; stack MBTiles/contours/hillshade/static tiles/source metadata are cache/report. No Mapping writes. |
| `local_topo/tasmania/scripts/rebuild_stack_worker.sh` <!-- inventory:local_topo/tasmania/scripts/rebuild_stack_worker.sh --> | **Resolver-validated paths only**. Internal argv worker; reads only the selected canonical DEM operand passed by the Dart resolver, checks prepared EPSG:28355 data, and writes stack-local cache/report outputs. No named-source environment or home-directory fallback. |
| `local_topo/tasmania/scripts/manual_refresh.sh` <!-- inventory:local_topo/tasmania/scripts/manual_refresh.sh --> | **Resolver-validated paths only**, wrapper forwarding rebuild options with `--mode manual`. |
| `local_topo/tasmania/scripts/scheduled_refresh.sh` <!-- inventory:local_topo/tasmania/scripts/scheduled_refresh.sh --> | **Resolver-validated paths only**, wrapper forwarding rebuild options with `--mode scheduled`. |
| `local_topo/tasmania/scripts/_common.sh` <!-- inventory:local_topo/tasmania/scripts/_common.sh --> | **Resolver-validated paths only** for named DEMs. Stack-local `runtime`, `input`, `output`, `input/osm/tasmania-latest.osm.pbf`, Planetiler/PostGIS/MBTiles/tile/metadata paths are cache/temporary/report; retain non-store `LOCAL_TOPO_*` overrides. |
| `local_topo/tasmania/scripts/start_stack.sh` <!-- inventory:local_topo/tasmania/scripts/start_stack.sh --> | **Store-isolated**. `--mode preview\|static`, default preview; `LOCAL_TOPO_STYLE=tasmania-openstreetmap-contours-martin`, `LOCAL_TOPO_TILESERVER=martin`; cache MBTiles/static tiles or temporary smoke fixtures, container lifecycle. |
| `local_topo/tasmania/scripts/stop_stack.sh` <!-- inventory:local_topo/tasmania/scripts/stop_stack.sh --> | **Store-isolated** container stop; no overrides. |
| `local_topo/tasmania/scripts/prepare_smoke_fixture.sh` <!-- inventory:local_topo/tasmania/scripts/prepare_smoke_fixture.sh --> | **Store-isolated** temporary PNG/MBTiles fixtures; no overrides. |
| `local_topo/tasmania/scripts/prerender_tiles.mjs` <!-- inventory:local_topo/tasmania/scripts/prerender_tiles.mjs --> | **Store-isolated**. Local Topo HTTP -> PNG cache; `LOCAL_TOPO_PRERENDER_*`, default zooms 0–16/concurrency 8. |
| `local_topo/tasmania/scripts/review_cartography.mjs` <!-- inventory:local_topo/tasmania/scripts/review_cartography.mjs --> | **Store-isolated**. `node scripts/review_cartography.mjs --style-id <id>`, default `runtime/review/cartography`, `http://127.0.0.1:8090`, `LOCAL_TOPO_REVIEW_*`; fixture/service reads and review PNG reports. |
| `local_topo/tasmania/scripts/smoke.mjs` <!-- inventory:local_topo/tasmania/scripts/smoke.mjs --> | **Store-isolated**. `node scripts/smoke.mjs [base-url]`, default `http://127.0.0.1:8090`; capabilities fixture and service response reads. |

## Local Overpass snapshot sources

`/Volumes/Development/overpass_turbo/README.md` defines operations. Prerequisites:
Docker Desktop running, `/Volumes/Services` bind mounts available, selected
service `healthy` in `docker compose -f "$OVERPASS_COMPOSE" ps`. These are
tool-only sources; the shipped app must never access any Overpass API.

| Service / endpoint | Coverage and declared snapshot targets |
| --- | --- |
| `tasmania`, `http://localhost:8091/api/` | Tasmania peak/highway snapshots. |
| `new-south-wales`, `http://localhost:8092/api/` | New South Wales peak snapshot. |
| `italy-nord-est`, `http://localhost:8093/api/` | Italy North East/FVG/Veneto/Trentino Alto Adige/Emilia Romagna snapshots; FVG/Veneto highways participate in Northeast Alps. |
| `italy-nord-ovest`, `http://localhost:8094/api/` | Italy North West peak snapshot. |
| `slovenia`, `http://localhost:8095/api/` | Slovenia peaks and `Highways/slovenia-highways.json`. |
| `croatia`, `http://localhost:8096/api/` | Croatia peak snapshot. |

`overpass-data/<service>` databases are maintainer cache, not manifest inputs.
The inventory does not grant hypothetical snapshot tools any write capability;
they require their own named declarations before they can publish.

## Resolver, bootstrap and retained-contract verification

```sh
dart run tool/mapping_store.dart bootstrap-tool-manifest
dart run tool/mapping_store.dart provision-or-verify
```

Bootstrap parses the version-controlled v1 fixture and atomically publishes
only an absent `tool_manifest.json`, using macOS exclusive rename publication
(`RENAME_EXCL`, without requiring hard-link support on the NAS).
A matching existing manifest is verified without a write; any conflict fails.
Provision-or-verify runs preflight and the shared parsers for both mounted and
fixture manifests. Only existing regional fingerprints may differ. Every allowed
difference is printed with its JSON Pointer and both values. Other differences,
including tool commands/permissions, fail. It never overwrites Mapping data.
Both commands use the fixed mounted root and work in standalone Dart.

An existing tool manifest with stale IDs/permissions must be reviewed against the
v1 fixture and provisioned by the maintainer before cutover verification. Bootstrap
never overwrites it. `provision-or-verify` reports the discrepancy and does not
repair or mutate source data.

If the existing manifest is an empty `{}` placeholder, review and explicitly
provision the **complete** `test/fixtures/mapping_store/v1/tool_manifest.json`.
It declares 13 named tools; adding only `mapping-store-provision` is insufficient
for retained-contract verification. Keep a backup outside Mapping and stage the
replacement beside its target for a same-filesystem atomic rename:

```sh
# Run from the repository root, after reviewing the fixture's capabilities.
cp /Volumes/Services/Mapping/tool_manifest.json /tmp/peak-bagger-tool_manifest.before.json
cp test/fixtures/mapping_store/v1/tool_manifest.json /Volumes/Services/Mapping/.tool_manifest.json.reviewed
mv /Volumes/Services/Mapping/.tool_manifest.json.reviewed /Volumes/Services/Mapping/tool_manifest.json
dart run tool/mapping_store.dart provision-or-verify
```

This is an explicit maintainer replacement of a reviewed existing contract;
bootstrap still refuses to overwrite a conflicting file. The app ignores this
manifest. Source snapshots and the runtime manifest pair are not replaced by
these commands. If verification reports another mismatch, inspect that mismatch
before provisioning any further file.

Tool `command` contains `executable` and string-array `arguments`. Only exact
`{input:id}`/`{output:id}` arguments expand. `inputs` have `id`, `path`, `kind`,
`required`; `outputs` additionally require boolean `replace` and `atomic`.
`permittedWrites` names declared output IDs. Each override is
`{"flag":"--name","inputId":"id"}` or the corresponding `outputId`.
Overrides replace only that declaration's placeholder. Globs support `*`, `?`,
and whole-component `**`, producing lexical argv. Arguments go directly to the
executable with the repository root as cwd and a captured inherited environment.
File outputs are staged siblings and published atomically. Directory outputs
are validated staged snapshots, reject symlinks, atomically publish each file,
then delete stale files. There is no whole-directory atomicity guarantee.

In-process writers (fingerprints and ELVIS) invoke their CLI directly and use
`writeOutputs`; `execute` rejects a writer without output placeholders before
dispatch so a nested self-publishing process cannot bypass outer staging. GDAL
publication uses typed `MappingToolOutputPath` operands; Local Topo uses typed
`MappingToolInputPath` operands. Literal, option-assignment, and file-URI arguments
are checked as non-store before subprocess dispatch. The resolver owns argv,
cwd, inherited environment, canonical path checks, streaming copy, and publication.
Subprocess adapters also enforce the declared command executable and argv prefix:
typed inputs cannot occupy output slots or be appended as implicit write targets.
Only inventory-whitelisted, checked non-store orchestration literals follow that
prefix (for example Local Topo mode flags or the external preparation VRT).

## Direct-I/O boundary and cutover gate

Resolver owners: `mapping_store_core.dart` (runtime filesystem, manifest/parser,
geometry-cache boundary) and `mapping_tool_resolver.dart` (tool/bootstrap I/O and
process construction). `mapping_store_resolver.dart` provides read capabilities.
Production runtime readers receive only validated manifest/catalog references.

Explicit **non-store adapter allowlist** (does not authorize Mapping paths):

- `tool/mapping_store.dart::_fixture`: version-controlled fixture reads only.
- `route_elevation_sampler.dart`: host GDAL/PROJ existence probes; dataset opens
  only through the opaque resolver opener.
- `tasmap_repository.dart::loadFromCsvIfEmpty` and `clearAndReloadFromCsv`: explicit
  legacy user CSV imports, not the Mapping catalog source.
- `import_path_helpers.dart`, `tile_cache_service.dart`: user paths/cache.
- `gpx_importer.dart`: user GPX file reads, managed moves and import logs;
  Mapping polygons are read through `PolygonAssetRepository` only.
- `map_provider.dart::_placeFileInManagedStorage`: Bushwalking user GPX moves.
- `route_graph_peak_list_generation_service.dart`: user peak CSV and report I/O.
- `slovenia_hribi_source_peak_list_service.dart`, `peak_prominence_preview_export_service.dart`,
  `peakbagger_csv_sync_service.dart`: user CSV/report/web-cache adapters.
- `tool/peak_prominence_csv.dart`: guarded explicit user CSV only.
- `tool/sync_peakbagger_csv.dart`: guarded user CSV and report paths only.
- `tool/rank_fvg_peaks.dart`: checked cache/report files only; Mapping sources
  always use resolver reads.
- `tool/download_tasmania_thelist_dem.dart`: checked external preparation workspace;
  GDAL publication goes through the resolver's output subprocess adapter.
- `tool/elvis_dem.dart`: checked external raw source, preparation workspace,
  provenance/preview/report operations; the resolver streams prepared artifacts
  into the declared Mapping outputs.
- `tool/slovenia_hribi_source_peak_list.dart`: construction of a checked non-store
  report directory only; catalog geometry reads go through the resolver.

There is no transitional Mapping I/O allowlist. Source guards permit only these
named non-store adapters, freeze their direct-I/O call sites, and reject Mapping
contracts or generated-catalog dependencies in runtime/tools. The generator,
generated output, `veneto.poly` ranking input, and peak-prominence default CSV are
retired. Veneto ranking fails explicitly until its region has declared geometry;
it never opens the retired repository polygon. Local Overpass remains snapshot-only.

Retire every `assets/highways`, `assets/peaks`, `assets/polygons`,
`assets/region_manifest.json`, `assets/tasmap50k.csv`, `veneto.poly`, and
`assets/all-peaks-sorted-p100.csv` contract. Inventory markers are enforced by
`test/tool/mapping_data_store_inventory_test.dart`; resolver contracts and modes
are tested without the mounted store or live services.
