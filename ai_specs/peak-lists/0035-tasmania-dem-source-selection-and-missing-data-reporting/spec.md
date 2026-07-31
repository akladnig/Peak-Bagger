---
type: Spec
title: Tasmania DEM Source Selection And Missing-Data Reporting
---

## Problem

The current Tasmania elevation contract assumes ELVIS is the runtime source of truth and treats `Local Topo` DEM selection as a separate per-run maintainer choice. That contract breaks down when ELVIS has large missing-data gaps, because route elevation sampling produces unacceptable missing elevation behavior and `Local Topo` loses contour coverage. The repo needs an interim way to switch both normal runtime elevation and normal `Local Topo` rebuilds onto `theLIST 25m DEM`, while also giving maintainers concrete diagnostics about unresolved DEM coverage gaps. [L1] [L2] [L5] [L8] [L9] [L10]

## Proposed Outcome

Add a shared maintainer-managed `Tasmania DEM source` contract that both Flutter runtime elevation and normal `Local Topo` rebuilds follow, using the exact key `PEAK_BAGGER_TASMANIA_DEM_SOURCE` with supported values `elvis` and `thelist`, defaulting to `elvis`. When `thelist` is selected, runtime elevation and normal `Local Topo` rebuilds both resolve the prepared statewide `theLIST 25m DEM` from `<tasmania-dem-root>/thelist_25m/tasmania_dem_25m.tif`. `Local Topo` keeps `--dem-source` only as a one-off rebuild override, runtime elevation preserves the Tasmania-only region gate and existing user-visible unavailable messages, route sampling stops converting DEM `NoData` to false `0m` elevations, and DEM acquisition or derivation workflows write per-run `DEM missing-data report` artifacts instead of relying on a vague import log. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8] [L9] [L10] [L11]

## User Stories

1. As a maintainer, while ELVIS missing-data gaps are still being investigated, I can select one shared `Tasmania DEM source` so normal runtime elevation and normal `Local Topo` rebuilds both use the same prepared Tasmania DEM family. [L1] [L2] [L3] [L4] [L5] [L6]
2. As a Flutter route-planning user, Tasmania route elevation keeps using the selected Tasmania DEM source without inventing false `0m` samples for in-dataset gaps, while non-Tasmania routes still show the existing region-unavailable behavior. [L2] [L7] [L11]
3. As a maintainer, I can still run a one-off `Local Topo` rebuild with an explicit `--dem-source` override without changing the shared source that runtime elevation and normal rebuilds use. [L4]
4. As a maintainer, I receive a machine-readable `DEM missing-data report` from DEM acquisition and derivation workflows so I can judge whether ELVIS is good enough to keep using or whether I should switch the shared source to `thelist`. [L8] [L9] [L10]

## Requirements

1. This Spec is an interim Tasmania DEM follow-up to `ai_specs/peak-lists/0032-elvis-tasmania-dem-derivation-and-adoption/spec.md`. It changes source-selection behavior while unresolved ELVIS missing-data gaps remain, without introducing a new blended-source or gap-fill contract in this slice. [L1] [L5]
2. Introduce one shared maintainer-managed `Tasmania DEM source` contract for normal runtime elevation and normal `Local Topo` rebuilds. The exact configuration key is `PEAK_BAGGER_TASMANIA_DEM_SOURCE`. Supported values are exactly `elvis` and `thelist`. When the key is unset, behavior defaults to `elvis`. [L2] [L3]
3. Flutter runtime elevation must read `PEAK_BAGGER_TASMANIA_DEM_SOURCE` through `String.fromEnvironment`. For Flutter startup in this repository, the key must be documented and supported through the existing Dart-define file workflow: touched maintainer startup guidance must update `dart_defines.example.json` expectations and document setting the key in `dart_defines.local.json`, while Flutter launch helpers such as `run_local_maps.sh` continue passing that file through `--dart-define-from-file` rather than introducing a separate helper-specific configuration path in this slice. Maintainer shell workflows that do not start Flutter may read the same key directly through the shell environment. This slice must not add an in-app DEM picker, user-facing DEM file setting, or any other runtime UI for choosing the DEM source. [L2] [L3]
4. Normal runtime elevation and normal `Local Topo` rebuilds must follow the shared `Tasmania DEM source`. `Local Topo` `--dem-source` remains available only as an explicit one-off rebuild override, using the existing supported override values `elvis-topo`, `thelist`, `copernicus`, and `custom`. Using that override must not mutate the shared `Tasmania DEM source` or runtime elevation behavior. [L4]
5. The selected `Tasmania DEM source` is exclusive for normal behavior in this slice. If the selected source is `thelist`, normal runtime elevation and normal `Local Topo` rebuilds use only `theLIST 25m DEM`. If the selected source is `elvis`, they use only the ELVIS-derived artifacts already defined by the repo. This slice must not silently switch, blend, or gap-fill between ELVIS and `theLIST`. [L5]
6. When `PEAK_BAGGER_TASMANIA_DEM_SOURCE=thelist`, runtime elevation and normal `Local Topo` rebuilds both resolve the prepared `theLIST 25m DEM` from `<tasmania-dem-root>/thelist_25m/tasmania_dem_25m.tif`, where `<tasmania-dem-root>` uses the existing Tasmania DEM root convention. For normal `Local Topo` rebuilds, the named `thelist` source resolves from that canonical prepared artifact path and this slice does not preserve `LOCAL_TOPO_THELIST_DEM_TIF` as a normal named-source configuration seam. Maintainers who need a one-off non-canonical `theLIST`-derived GeoTIFF must use `--dem-source=custom --dem-path=...` instead. If that file is missing or unreadable, the affected workflow must fail clearly rather than switching sources. [L6]
7. When `PEAK_BAGGER_TASMANIA_DEM_SOURCE=elvis`, runtime elevation keeps resolving the prepared `ELVIS runtime DEM`, and normal `Local Topo` rebuilds keep resolving the ELVIS-backed topo source through the existing `elvis-topo` prepared-artifact contract unless a one-off rebuild override is supplied. [L3] [L4] [L5]
8. Runtime elevation must preserve the existing Tasmania-only region gate. A DEM is resolved only when every route point resolves within Tasmania. Non-Tasmania routes still resolve to `dem=none`, and the interactive route elevation UI must keep the existing exact region-unavailable message `Elevation unavailable for this region`. This slice must not add raster-footprint probing outside the existing Tasmania region seam. [L11]
9. When the resolved route region is Tasmania but the selected DEM artifact is missing, unreadable, or cannot be opened, the interactive route elevation UI must keep the existing exact message `Tasmania elevation data is unavailable on this device`. Selecting `thelist` changes the DEM source path, not the user-visible Tasmania unavailable copy. [L2] [L6] [L11]
10. Runtime route sampling must stop converting in-dataset DEM `NoData` samples into `0m`. For route summaries and elevation profiles, internal missing sampled runs must be interpolated between the nearest valid sampled elevations on both sides of the run. Leading missing sampled runs must use the first later valid sampled elevation, and trailing missing sampled runs must use the last earlier valid sampled elevation. For interactive route elevation, the displayed elevation profile and the route summary metrics must apply the same missing-sample handling rules and must stay consistent for the same route geometry. Interpolated profile elevations do not need to expose a separate public API, but the user-visible profile must not continue to show raw unresolved gaps where the same route summary has already interpolated them. If a route has no valid sampled elevations at all from the selected Tasmania DEM source, the interactive route flow must surface the existing Tasmania unavailable error rather than inventing zero-valued elevation metrics. [L7]
11. Best-effort non-interactive point-sampling flows such as route-save point elevation sampling and GPX route export sampling must keep unresolved points as `null` when no valid sample can be resolved from the selected Tasmania DEM source. Imported-route enrichment may preserve pre-existing GPX-file elevations for points where DEM sampling remains unresolved, but it must not synthesize `0m` as a fallback value for unresolved samples. [L7]
12. Use the canonical term `DEM missing-data report` for maintainer-facing coverage diagnostics. This slice must not rely only on a generic append-only `import log` for DEM gap reporting. [L8]
13. `DEM missing-data report` generation belongs to DEM acquisition and derivation workflows, not to every app route-sampling run. The following commands must write a report for each run that generates or validates the canonical prepared artifact they own:
    - `./elvis_dem.sh build-runtime`
    - `./elvis_dem.sh build-topo`
    - `./elvis_dem.sh build-all`
    - `dart run tool/download_tasmania_thelist_dem.dart` as the canonical maintained `theLIST` entrypoint for this slice, but only for invocation paths that validate or produce the canonical merged artifact at `<tasmania-dem-root>/thelist_25m/tasmania_dem_25m.tif`

    Normal Flutter route sampling and normal `Local Topo` rebuilds do not create a second independent report unless they become the workflow deriving or merging the DEM artifact itself. Non-merge or intermediate-only `theLIST` runs such as `--skip-merge` are out of scope for this report contract in this slice. [L9]
14. Each `DEM missing-data report` must be one timestamped JSON file per run. ELVIS commands write reports under `<tasmania-dem-root>/elvis_reports/`. The `theLIST` merge workflow writes reports under `<tasmania-dem-root>/thelist_25m/reports/`. Timestamped filenames must stay in UTC and use the existing report naming shape `<command>-YYYYMMDDTHHMMSSZ.report.json`. [L9] [L10]
15. Each `DEM missing-data report` must use a stable JSON object shape with explicit field names rather than positional arrays. Each report must record, at minimum:
    - command name
    - source family: `elvis` or `thelist`
    - generated or validated artifact path
    - UTC report timestamp
    - `raster` object with `widthPixels`, `heightPixels`, and `crs`
    - detected `NoData` value
    - total pixel count
    - valid pixel count
    - missing pixel count
    - missing percentage
    - aggregate missing coverage under `missingCoverage.datasetBounds` and `missingCoverage.wgs84Bounds`
    - whether aggregate missing coverage touches any dataset edge

    The workflow should also print a concise console summary that includes the missing percentage and report path. [L10]
16. Each `DEM missing-data report` must also include a machine-readable largest-first list of contiguous missing regions. For each region include:
    - `ordinalId`
    - pixel count
    - percentage of total raster
    - `datasetBounds` object with `minX`, `minY`, `maxX`, and `maxY`
    - `wgs84Bounds` object with `minLongitude`, `minLatitude`, `maxLongitude`, and `maxLatitude`
    - whether the region touches any dataset edge

    `regions` must sort by descending `pixelCount`; ties must then sort by ascending `ordinalId`. This slice must not require full polygon vectorization of missing-data regions. [L10]
17. Detecting missing-data regions and writing a `DEM missing-data report` must not fail the workflow on its own. The workflow still succeeds and leaves the generated artifact usable when gaps are reported. Failure remains reserved for missing inputs, unreadable rasters, invalid metadata, or command-execution errors. [L10]
18. Maintainer-facing docs and startup guidance touched by this slice must document the shared `Tasmania DEM source` contract, the exact `PEAK_BAGGER_TASMANIA_DEM_SOURCE` key, the supported values `elvis` and `thelist`, that Flutter startup in this repo uses the existing Dart-define file workflow by documenting the key in `dart_defines.local.json` and `dart_defines.example.json`, how Flutter launch helpers pass that file through `--dart-define-from-file`, the default `theLIST` artifact path, the continued absence of an in-app DEM picker, that normal named-source `thelist` rebuilds now resolve only from the canonical prepared artifact path rather than `LOCAL_TOPO_THELIST_DEM_TIF`, the preserved one-off `Local Topo` override values `elvis-topo|thelist|copernicus|custom`, and the existence of `DEM missing-data report` outputs for canonical artifact-generation or validation runs. [L2] [L3] [L4] [L6] [L8] [L9] [L10]

## Technical Decisions

1. Use a startup-scoped maintainer configuration seam instead of new Flutter UI state. Reading `PEAK_BAGGER_TASMANIA_DEM_SOURCE` through `String.fromEnvironment` aligns the app-side contract with the repo's existing Dart-define file workflow when Flutter launch helpers continue forwarding `dart_defines.local.json` through `--dart-define-from-file`, while shell environment reads keep non-Flutter maintainer workflows script-friendly. [L2] [L3]
2. Keep the shared `Tasmania DEM source` separate from the existing one-off `Local Topo` `--dem-source` override. This preserves the current rebuild seam and lets maintainers test or repair a single `Local Topo` rebuild with the existing explicit override values `elvis-topo|thelist|copernicus|custom` without accidentally changing runtime elevation behavior. [L4]
3. Reuse the existing GDAL-backed runtime sampling seam that already transforms WGS84 route points into the dataset CRS at sample time, so `theLIST` runtime support does not require a new Flutter-side source-CRS normalization contract. The stricter `EPSG:28355` requirement remains a `Local Topo` rebuild-input rule rather than a runtime-elevation rule.
4. Keep source selection exclusive for this slice. A future ELVIS-plus-`theLIST` gap-fill strategy could exist later, but this follow-up deliberately chooses deterministic whole-source switching over hidden blended behavior while ELVIS coverage issues are still being assessed. [L5]
5. Treat `DEM missing-data report` artifacts as maintainer diagnostics that support source-selection decisions rather than as hard validation blockers. This preserves useful interim ELVIS artifacts and merged `theLIST` artifacts even when they still contain holes. [L8] [L9] [L10]

## Testing Strategy

1. Extend deterministic app-side tests around `lib/services/route_elevation_sampler.dart` and related runtime DEM-resolution seams using TDD for the resolver and interpolation logic. Cover `PEAK_BAGGER_TASMANIA_DEM_SOURCE=elvis`, `PEAK_BAGGER_TASMANIA_DEM_SOURCE=thelist`, unset-default-to-`elvis`, Tasmania-only route gating, missing selected-artifact behavior, and the exact existing interactive error messages. Prefer fake region resolvers, fake dataset openers, and file-existence seams over real DEM files. [L2] [L3] [L6] [L7] [L11]
2. Add deterministic runtime-sampling tests that prove in-dataset `NoData` no longer becomes `0m`, internal gaps interpolate from neighboring valid samples, leading gaps use the next valid sampled elevation, trailing gaps use the prior valid sampled elevation, the interactive elevation profile stays consistent with the route summary for the same route geometry, all-missing routes surface the existing Tasmania unavailable error, and best-effort point-sampling flows preserve `null` for unresolved DEM samples. Add caller-level coverage where needed so imported-route enrichment preserves pre-existing GPX-file elevations when DEM sampling returns `null`. [L7]
3. Extend `local_topo/tasmania/tests/rebuild_scripts.test.mjs` so normal rebuilds follow the shared `PEAK_BAGGER_TASMANIA_DEM_SOURCE` when no one-off override is passed, while explicit `--dem-source` still overrides only that rebuild and preserves the existing override values `elvis-topo|thelist|copernicus|custom`. Cover normal named-source `thelist` resolving from `<tasmania-dem-root>/thelist_25m/tasmania_dem_25m.tif` without relying on `LOCAL_TOPO_THELIST_DEM_TIF`, clear failure on missing selected artifacts, one-off non-canonical `theLIST`-derived paths going through `--dem-source=custom --dem-path=...`, and the absence of silent source switching. [L3] [L4] [L5] [L6]
4. Add deterministic tool coverage for `tool/download_tasmania_thelist_dem.dart` as the canonical maintained `theLIST` entrypoint for this slice and the ELVIS build-report seam so each required canonical artifact-generation or validation workflow writes a timestamped JSON `DEM missing-data report` in the correct directory with the expected object-shaped aggregate fields, per-gap region records, dataset and WGS84 bounds field names, and largest-first ordering with ascending-`ordinalId` tie-breaks, while still succeeding when missing-data regions are present. Use synthetic rasters or faked report-generation seams instead of live statewide datasets. Non-merge `theLIST` runs such as `--skip-merge` do not require this report coverage in this slice. [L8] [L9] [L10]
5. Update maintainer-doc or helper-script coverage where such assertions already exist so touched docs or startup helpers prove the exact `PEAK_BAGGER_TASMANIA_DEM_SOURCE` contract, supported values, defaulting behavior, the repo-standard Flutter startup path through `dart_defines.local.json`, `dart_defines.example.json`, and `--dart-define-from-file`, the canonical normal `theLIST` path contract without `LOCAL_TOPO_THELIST_DEM_TIF` as a normal named-source seam, preserved one-off `Local Topo` override values, and `DEM missing-data report` terminology. Robot or widget journey coverage is not required for this slice because no new end-user screen or interactive control is introduced beyond existing route-elevation error messaging. [L2] [L3] [L4] [L8]

## Out of Scope

1. Building a blended or gap-filled ELVIS-plus-`theLIST` DEM artifact for runtime elevation or `Local Topo`. [L5]
2. Adding any in-app Settings control, file picker, or user-facing DEM-source chooser. [L2] [L3]
3. Expanding runtime DEM resolution beyond the existing Tasmania-only region gate. [L11]
4. Failing ELVIS or `theLIST` derivation runs solely because a `DEM missing-data report` recorded gaps. [L10]
5. Reworking the broader `Local Topo` contour-generation policy beyond making normal rebuilds follow the shared source selection. [L4] [L6]

## Follow-Ups

1. If ELVIS missing-data gaps are later repaired satisfactorily, consider whether the repo should switch the shared default back to ELVIS-only behavior everywhere or keep the shared source toggle as a permanent maintainer seam. [L1] [L3]
2. If source-switching alone proves insufficient, evaluate a later separate Spec for explicit ELVIS-plus-`theLIST` gap-fill derivation rather than expanding this slice into blended-source behavior. [L5]

## Notes

1. Likely implementation surfaces include `lib/core/constants.dart`, `lib/services/route_elevation_sampler.dart`, caller logic that preserves imported GPX elevations when DEM samples are unresolved, `local_topo/tasmania/scripts/_common.sh`, `local_topo/tasmania/scripts/rebuild_stack.sh`, `tool/download_tasmania_thelist_dem.dart`, `README.tasmania-elvis-local-topo.md`, `local_topo/tasmania/README.md`, and any helper that launches Flutter with `--dart-define` values such as `run_local_maps.sh`.
2. `GLOSSARY.md` now includes `Tasmania DEM source` and `DEM missing-data report` as canonical project terminology for this work.
