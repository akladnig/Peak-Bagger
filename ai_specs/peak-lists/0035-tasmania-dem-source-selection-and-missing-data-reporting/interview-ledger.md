---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: While unresolved ELVIS gaps remain, should selecting `theLIST 25m DEM` make both runtime elevation and `Local Topo` use `theLIST` instead of ELVIS?

Recommended Answer:
- Use `theLIST 25m DEM` for both runtime elevation and `Local Topo` when it is the selected Tasmania DEM source.
- Treat this as an interim source-selection change while ELVIS missing data is still under investigation.

Answer: agreed

Decision: The Spec must let maintainers select `theLIST 25m DEM` as the active Tasmania DEM source for both runtime elevation and normal `Local Topo` rebuilds while ELVIS missing data remains unresolved.

Reason: Large ELVIS gaps currently make missing contour lines and missing elevation data unacceptable.

### L2

Status: current

Question: Should runtime elevation keep its current ELVIS-only contract, or should it follow a shared maintainer-managed `Tasmania DEM source` with no in-app DEM picker?

Recommended Answer:
- Runtime elevation and normal `Local Topo` rebuilds should both follow one shared maintainer-managed `Tasmania DEM source`.
- Do not add an in-app DEM picker or user-facing DEM file setting.

Answer: agreed

Decision: Runtime elevation must stop being ELVIS-only and instead follow the shared maintainer-managed `Tasmania DEM source`, with no user-facing selector.

Negative Requirements:
- No in-app DEM picker.
- No user-facing file chooser.

### L3

Status: current

Question: How should the shared `Tasmania DEM source` be configured?

Recommended Answer:
- Use one shared key named `PEAK_BAGGER_TASMANIA_DEM_SOURCE`.
- Allowed values are exactly `elvis` and `thelist`.
- When unset, default to `elvis`.
- Flutter reads the key with `String.fromEnvironment`.
- Maintainer shell workflows read the same key from the environment.

Answer: agreed

Decision: The shared `Tasmania DEM source` is configured with `PEAK_BAGGER_TASMANIA_DEM_SOURCE`, using values `elvis` or `thelist`, defaulting to `elvis`, with Flutter and maintainer shell workflows reading the same key through their normal startup/config seams.

### L4

Status: current

Question: Should `Local Topo` keep its per-run `--dem-source` override once a shared `Tasmania DEM source` exists?

Recommended Answer:
- Use the shared `Tasmania DEM source` as the source of truth for runtime elevation and normal `Local Topo` rebuilds.
- Keep `Local Topo` `--dem-source` only as an explicit one-off maintainer override.
- A one-off override changes that rebuild only and must not change the shared source.
- Runtime elevation always follows the shared source, never a one-off topo override.

Answer: agreed

Decision: Normal runtime elevation and normal `Local Topo` rebuilds follow the shared `Tasmania DEM source`, while `Local Topo` keeps `--dem-source` only as a one-off rebuild override.

### L5

Status: current

Question: When the shared `Tasmania DEM source` is set to `thelist`, should runtime elevation or normal `Local Topo` rebuilds mix ELVIS in anywhere?

Recommended Answer:
- Treat the shared `Tasmania DEM source` as exclusive for normal behavior.
- If the source is `thelist`, runtime elevation uses only the prepared `theLIST 25m DEM`.
- If the source is `thelist`, normal `Local Topo` rebuilds use only the prepared `theLIST 25m DEM`.
- Do not silently fall back or blend ELVIS and `theLIST` in this slice.

Answer: agreed

Decision: The selected `Tasmania DEM source` is exclusive for normal runtime elevation and normal `Local Topo` rebuilds; this slice does not mix, gap-fill, or silently fall back between ELVIS and `theLIST`.

Negative Requirements:
- No silent switch from `thelist` to ELVIS.
- No silent switch from `elvis` to `thelist`.
- No blended-source or gap-fill behavior in this slice.

### L6

Status: current

Question: If the shared `Tasmania DEM source` is `thelist`, what path should runtime elevation and normal `Local Topo` rebuilds use?

Recommended Answer:
- Use the canonical merged downloader output path.
- Resolve `theLIST` from `<tasmania-dem-root>/thelist_25m/tasmania_dem_25m.tif` for both runtime elevation and normal `Local Topo` rebuilds.
- If that file is missing or unreadable, fail clearly instead of switching sources.

Answer: agreed

Decision: The shared `theLIST` source resolves from `<tasmania-dem-root>/thelist_25m/tasmania_dem_25m.tif` for both runtime elevation and normal `Local Topo` rebuilds.

### L7

Status: current

Question: How should runtime elevation treat in-dataset `NoData` samples from the selected Tasmania DEM source?

Recommended Answer:
- Do not convert in-dataset `NoData` samples to `0` metres.
- Interpolate isolated missing samples between the nearest valid route samples.
- If a route has no valid sampled elevations at all from the selected Tasmania DEM source, show the existing Tasmania unavailable error.
- For non-interactive best-effort point sampling flows, return `null` where no valid sample can be resolved rather than inventing `0`.

Answer: agreed

Decision: Runtime route summaries and profiles must stop treating `NoData` as `0`, interpolate isolated missing samples, and keep `null` for unresolved best-effort point sampling.

Reason: False `0m` samples create obviously wrong ascent, descent, and profile output.

### L8

Status: current

Question: Should missing-data diagnostics be an append-only `import log`, or a dedicated maintainer-facing report artifact?

Recommended Answer:
- Use the canonical term `DEM missing-data report`.
- Write a per-run machine-readable report instead of relying on an append-only shared text log.
- Keep it maintainer-facing and tied to DEM preparation workflows.

Answer: agreed

Decision: Missing DEM coverage diagnostics must be captured in a maintainer-facing per-run `DEM missing-data report`, not only in a shared append-only import log.

### L9

Status: current

Question: Which workflows should write a `DEM missing-data report`?

Recommended Answer:
- `./elvis_dem.sh build-runtime`, `build-topo`, and `build-all` write a `DEM missing-data report`.
- `tool/download_tasmania_thelist_dem.dart` also writes a `DEM missing-data report` for the merged `theLIST 25m DEM`.
- Normal Flutter route sampling does not write per-route reports.
- Normal `Local Topo` rebuilds do not create a second independent report unless they are the workflow deriving the DEM artifact.

Answer: agreed

Decision: `DEM missing-data report` generation belongs to DEM acquisition and derivation workflows, specifically the ELVIS build commands and the `theLIST` downloader workflow.

### L10

Status: current

Question: What should each `DEM missing-data report` contain, and should missing-data regions fail the workflow?

Recommended Answer:
- Write one timestamped JSON report per run.
- For ELVIS commands, write reports under `<tasmania-dem-root>/elvis_reports/`.
- For `theLIST`, write reports under `<tasmania-dem-root>/thelist_25m/reports/`.
- Include command name, source family, artifact path, UTC timestamp, raster size and CRS, detected `NoData` value, total pixel count, valid pixel count, missing pixel count, missing percentage, bounding box of missing coverage, whether missing coverage touches any dataset edge, and a machine-readable list of contiguous missing regions sorted largest-first.
- For each missing region include stable ordinal id, pixel count, percentage of total raster, dataset-coordinate bounding box, WGS84 bounding box, and whether it touches any dataset edge.
- Do not require full polygon vectorization in this slice.
- The workflow still succeeds and leaves the artifact usable even when missing-data regions are reported.

Answer: agreed

Decision: `DEM missing-data report` output is a timestamped JSON per run with both aggregate and per-gap coverage diagnostics, and missing-data findings alone do not fail the workflow.

### L11

Status: current

Question: Should the new `theLIST` runtime path preserve the Tasmania-only route gate or sample anywhere the raster covers?

Recommended Answer:
- Preserve the existing Tasmania-only gate.
- Runtime elevation resolves a DEM only when every route point is in Tasmania.
- Non-Tasmania routes still resolve to `dem=none` and keep the existing region-unavailable message.
- Do not add raster-footprint probing outside the current region seam in this slice.

Answer: agreed

Decision: The shared `Tasmania DEM source` changes which Tasmania DEM is used, but does not change the Tasmania-only runtime region gate.
