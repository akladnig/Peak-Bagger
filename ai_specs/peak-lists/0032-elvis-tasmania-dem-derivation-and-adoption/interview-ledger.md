---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should `ELVIS` mean the canonical Tasmania higher-detail DEM source for both `Local Topo` rebuilds and app elevation workflows, or only for one path?

Recommended Answer:
- Treat `ELVIS DEM` as the canonical higher-detail Tasmania DEM input stored outside git at `/Volumes/Media/Elvis/tas-elvis`.
- Use it in both places through repo-managed derivatives.
- Keep the Flutter app from reading `/Volumes/Media/Elvis` directly at runtime.

Answer: agreed

Decision: `ELVIS DEM` is the canonical higher-detail Tasmania DEM input for both `Local Topo` rebuilds and app elevation workflows, but runtime consumers must use derived artifacts rather than direct reads from `/Volumes/Media/Elvis`.

### L2

Status: current

Question: Should the repo treat ELVIS as one statewide artifact reused everywhere, or one external source tree with separate derived outputs per workflow?

Recommended Answer:
- Keep one external ELVIS source tree.
- Generate separate repo-managed derivatives for Flutter/runtime and `Local Topo`.
- Keep raw ELVIS tiles out of git.

Answer: agreed

Decision: The repo uses one external ELVIS source tree with separate derived outputs for Flutter/runtime elevation and `Local Topo` rebuilds.

### L3

Status: current

Question: Should partial ELVIS coverage be usable immediately, or must ELVIS stay blocked until the full `260 GB` Tasmania dataset is available?

Answer: require the full 260 GB Tasmania dataset before ELVIS can be used

Decision: ELVIS must not be used until the full Tasmania raw dataset is present.

Reason: The user expects the full source to become available shortly and wants ELVIS adoption gated on complete source availability rather than partial coverage fallbacks.

### L4

Status: current

Question: Which repo consumers should the Spec require ELVIS-derived data for once the full dataset is available?

Recommended Answer:
- `Local Topo` rebuilds for contours and terrain relief shading.
- Flutter route elevation sampling through derived runtime assets.
- Shared repo DEM tooling used by both paths.
- Exclude retroactive stored peak-elevation rewrites and non-Tasmania workflows.

Answer: agreed

Decision: ELVIS-derived data is required for Tasmania `Local Topo` rebuilds, Flutter route elevation sampling, and shared repo DEM tooling, while stored peak-elevation rewrites and non-Tasmania elevation workflows remain out of scope.

### L5

Status: current

Question: Should the Flutter app keep using bundled DEM assets for Tasmania, or switch to a repo-managed external ELVIS-derived runtime DEM?

Recommended Answer:
- Change the app contract to use a repo-managed external Tasmania runtime DEM generated from ELVIS.
- Keep raw ELVIS out of the app package.
- Do not bundle a statewide ELVIS derivative into the app.

Answer: agreed

Decision: Tasmania runtime elevation sampling must use an external ELVIS-derived runtime DEM rather than bundled Tasmania DEM assets.

### L6

Status: current

Question: After ELVIS adoption, should Tasmania elevation workflows fail fast when ELVIS-derived artifacts are missing or stale, or silently fall back to `theLIST 25m DEM`?

Recommended Answer:
- Treat ELVIS-derived artifacts as required.
- Fail clearly when they are missing, stale, or invalid.
- Do not silently switch Tasmania back to `theLIST 25m DEM`.

Answer: agreed

Decision: After ELVIS adoption, Tasmania elevation workflows fail fast on missing or invalid ELVIS-derived artifacts and do not silently fall back to `theLIST 25m DEM`.

### L7

Status: current

Question: Should the raw ELVIS source stay canonical at `/Volumes/Media/Elvis/tas-elvis`, while generated artifacts live under the Bushwalking DEM root?

Recommended Answer:
- Keep raw source at `/Volumes/Media/Elvis/tas-elvis`.
- Store generated artifacts under `~/Documents/Bushwalking/DEM/Tasmania/`.
- Do not create a second full-data mirror under `~/Documents/Bushwalking`.

Answer: agreed

Decision: The canonical raw ELVIS source stays at `/Volumes/Media/Elvis/tas-elvis`, while generated artifacts live under `~/Documents/Bushwalking/DEM/Tasmania/` with no second full-data mirror.

### L8

Status: current

Question: Should the repo reuse one ELVIS-derived DEM for all consumers, or generate separate runtime and topo derivatives?

Recommended Answer:
- Generate a separate `ELVIS runtime DEM` for Flutter elevation sampling.
- Generate a separate `ELVIS topo DEM` for `Local Topo` contours and terrain relief workflows.

Answer: agreed

Decision: The repo must generate separate `ELVIS runtime DEM` and `ELVIS topo DEM` artifacts.

### L9

Status: current

Question: What resolutions should the derived ELVIS artifacts use?

Recommended Answer:
- Use a `10m` runtime DEM for Flutter elevation sampling.
- Use a finer `5m` topo DEM for `Local Topo` contour and hillshade workflows.

Answer: agreed

Decision: The `ELVIS runtime DEM` is `10m`, and the `ELVIS topo DEM` is `5m`.

### L10

Status: current

Question: The current code defines `ELVIS` as a bundled asset alias of `assets/cop30_hh.tif`. Should the code be changed to follow the new ELVIS contract?

Recommended Answer:
- Yes.
- `ELVIS` must no longer point at a bundled app asset.
- For Tasmania, ELVIS must resolve to the external `ELVIS runtime DEM`.
- Keep `Copernicus GLO-30` distinct rather than using it as an ELVIS stand-in.

Answer: agreed

Decision: The code must replace the current bundled-asset ELVIS alias with the external Tasmania `ELVIS runtime DEM` contract.

### L11

Status: current

Question: Should ELVIS derivation be a separate maintainer workflow, or should `Local Topo` refresh scripts derive ELVIS artifacts inline during refresh?

Recommended Answer:
- Make ELVIS derivation a separate maintainer workflow.
- Produce prepared runtime and topo artifacts ahead of time.
- Keep routine topo refresh scripts as consumers of those prepared artifacts.

Answer: agreed

Decision: ELVIS derivation is a separate maintainer workflow that prepares runtime and topo artifacts ahead of `Local Topo` refreshes.

### L12

Status: current

Question: Before derivation runs, how should the tool decide that the raw ELVIS source is complete enough to proceed?

Recommended Answer:
- Fail unless a checked-in completeness manifest passes.
- Require the canonical raw root to exist.
- Require all expected files to be present, readable, and non-zero.
- Require total file count and total byte size to match expectations.
- Write a machine-readable validation report.

Answer: agreed

Decision: ELVIS derivation must be gated by a checked-in completeness manifest that validates the canonical raw root, expected files, expected totals, and produces a machine-readable validation report.

### L13

Status: current

Question: Should the new ELVIS tool follow the repo's root shell-wrapper pattern, and what command shape should it expose?

Recommended Answer:
- Add a Dart CLI `tool/elvis_dem.dart`.
- Add a root shell wrapper `./elvis_dem.sh` that auto-builds a macOS binary when sources change.
- Expose `bootstrap-manifest`, `validate-source`, `build-runtime`, `build-topo`, and `build-all` subcommands.
- Print artifact and report paths, and fail non-zero on errors.

Answer: agreed

Decision: The ELVIS workflow uses a Dart CLI under `tool/` plus a root shell wrapper `./elvis_dem.sh` with explicit subcommands and auto-build behavior matching existing maintainer wrappers.

### L14

Status: current

Question: Should the completeness manifest support future raw-source updates, or treat the ELVIS source as one frozen immutable contract?

Answer: I cannot see any reason to ever update the raw source

Decision: The ELVIS raw-source contract is frozen and immutable rather than part of a normal source-refresh workflow.

Reason: Unexpected raw-source changes should fail validation rather than trigger an update path.

### L15

Status: current

Question: For the frozen completeness manifest, should validation require only expected file paths plus byte sizes, or also per-file checksums?

Recommended Answer:
- Require expected file paths, byte sizes, and per-file checksums.
- Fail validation on missing, unreadable, wrong-sized, or checksum-mismatched files.

Answer: agreed

Decision: The frozen completeness manifest requires explicit file paths, byte sizes, and per-file checksums.

### L16

Status: current

Question: Should the Flutter app treat the `ELVIS runtime DEM` path as a fixed maintainer-managed path, or expose a Settings UI so users can choose the DEM file?

Recommended Answer:
- Resolve the runtime DEM from a fixed canonical path.
- Do not add a Settings UI for DEM file selection.
- Show a clear elevation error if the file is missing or invalid.

Answer: agreed

Decision: The Flutter app must resolve the `ELVIS runtime DEM` from a fixed maintainer-managed path with no user-facing DEM file setting.

### L17

Status: current

Question: Should the same ELVIS CLI include a one-time bootstrap command to generate the frozen completeness manifest from the completed source?

Recommended Answer:
- Include a one-time `bootstrap-manifest` command in the same CLI.
- Use it only after the full source is present.
- Require normal commands to refuse to proceed without the committed manifest.

Answer: agreed

Decision: The ELVIS CLI includes a one-time `bootstrap-manifest` command that generates the frozen completeness manifest, while normal commands consume the committed manifest.

### L18

Status: current

Question: What output format should the ELVIS tool produce for the derived DEM artifacts?

Recommended Answer:
- Produce single-file GeoTIFF outputs for the runtime and topo artifacts.
- Allow internal VRT or temp files, but keep the stable consumer contract as GeoTIFF.
- Write sidecar metadata beside each output.

Answer: agreed

Decision: The ELVIS tool must produce single-file GeoTIFF runtime and topo artifacts with sidecar metadata, even if internal derivation uses VRTs or temporary files.

### L19

Status: current

Question: Should each ELVIS-derived artifact be one statewide raster or multiple regional output files plus an index?

Recommended Answer:
- Use one statewide raster per artifact type.
- Keep one stable runtime path and one stable topo path for consumers.

Answer: agreed

Decision: Each ELVIS-derived artifact is a single statewide raster with one stable path per role.

### L20

Status: current

Question: Should the generated ELVIS artifacts and completeness manifest be checked into git, or only the tooling and small manifest files?

Recommended Answer:
- Commit the CLI, shell wrapper, and frozen completeness manifest.
- Do not commit generated GeoTIFFs, VRTs, caches, or local reports.

Answer: agreed

Decision: The repo commits only the ELVIS tooling and small manifest files, while generated DEM artifacts and local reports stay out of git.

### L21

Status: current

Question: What automated coverage should this ELVIS workflow require?

Recommended Answer:
- Add deterministic tool tests for manifest bootstrap, source validation, checksum and size failures, and artifact planning or metadata output.
- Add a runner test for the shell-wrapper pattern.
- Extend `local_topo/tasmania/tests/rebuild_scripts.test.mjs` to cover prepared-artifact consumption and clear missing-artifact failures.
- Use temp fixtures and fakes rather than the real `260 GB` source.

Answer: agreed

Decision: The ELVIS workflow requires deterministic tool tests, a shell-wrapper runner test, and `Local Topo` rebuild-script coverage using fixtures and fakes instead of the real raw source.

### L22

Status: current

Question: Once the ELVIS workflow lands, should the Tasmania bundled DEM path stay as a migration-only escape hatch, or be removed from normal Tasmania runtime use immediately?

Recommended Answer:
- Remove it from normal Tasmania use immediately.
- Use ELVIS-derived artifacts as the Tasmania source of truth.
- Fail clearly instead of switching Tasmania back to `theLIST 25m DEM`.

Answer: agreed

Decision: ELVIS-derived artifacts replace the bundled Tasmania DEM path for normal Tasmania runtime use immediately after adoption.

### L23

Status: current

Question: Should the new ELVIS CLI stop at producing the `ELVIS runtime DEM` and `ELVIS topo DEM`, or also generate `10m` contour artifacts itself?

Recommended Answer:
- Stop at producing DEM derivatives.
- Leave contour generation, contour MBTiles generation, terrain relief shading, and `source-metadata.json` ownership in the existing `Local Topo` rebuild scripts.

Answer: agreed

Decision: The ELVIS CLI stops at producing the runtime and topo DEM derivatives, while `Local Topo` rebuild scripts keep contour and terrain-relief generation responsibilities.

### L24

Status: current

Question: Should `Local Topo` refresh scripts invoke `./elvis_dem.sh` as a preflight dependency, or only consume the prepared `ELVIS topo DEM` and fail with instructions if it is missing?

Recommended Answer:
- Keep the refresh scripts as shell-script consumers of prepared artifacts.
- Do not rebuild ELVIS derivatives inline.
- Check the prepared topo DEM and fail fast with a clear command such as `./elvis_dem.sh build-topo` when it is missing.

Answer: agreed

Decision: `Local Topo` refresh scripts remain shell-script consumers of the prepared `ELVIS topo DEM` and fail with clear maintainer instructions when it is missing.

### L25

Status: current

Question: Should the frozen completeness manifest treat `.DS_Store` and similar OS metadata files as required source files?

Recommended Answer:
- Ignore transient OS metadata such as `.DS_Store`.
- Validate only the actual DEM payload files needed for derivation.

Answer: agreed

Decision: The frozen completeness manifest ignores transient OS metadata files such as `.DS_Store` and validates only ELVIS DEM payload files.

### L26

Status: current

Question: Should the frozen completeness manifest enumerate every raw DEM payload file explicitly, or allow wildcard or pattern-based expectations?

Recommended Answer:
- Enumerate every expected payload file explicitly.
- Store each file's relative path, byte size, and checksum, plus manifest-level totals.

Answer: agreed

Decision: The frozen completeness manifest enumerates every expected DEM payload file explicitly rather than using wildcard or pattern-based expectations.
