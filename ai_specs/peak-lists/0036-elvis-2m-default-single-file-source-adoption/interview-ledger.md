---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Your glossary and docs currently use `ELVIS DEM` for the canonical raw Tasmania source, but your request introduces `Elvis 2m` as a distinct dataset. Which meaning should this Spec use?

Recommended Answer:
- Make `Elvis 2m DEM` the canonical raw-source term for the new statewide dataset at `/Volumes/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics`.
- Treat the older `ELVIS DEM` wording as legacy or avoided wording for the former source tree, not the new default.
- Keep `ELVIS runtime DEM` and `ELVIS topo DEM` as the names of the derived prepared artifacts.

Answer: agreed

Decision: Use `Elvis 2m DEM` as the canonical raw-source term for the new statewide dataset, while keeping `ELVIS runtime DEM` and `ELVIS topo DEM` as the derived artifact names.

### L2

Status: current

Question: Should `./elvis_dem.sh` fully switch to the new `Elvis 2m DEM` source contract, or keep any legacy fallback to the old raw ELVIS tree?

Recommended Answer:
- Switch the tool fully to `Elvis 2m DEM` as the only normal raw source.
- Use `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics` as the default source root.
- Remove the old mixed-source assumption and build derivatives only from the single `Elvis 2m DEM` source.
- If the new source root is missing or unreadable, fail clearly instead of searching older ELVIS locations.

Answer: agreed

Decision: `./elvis_dem.sh` must switch fully to `Elvis 2m DEM` as its only normal raw source and must not fall back to `/Volumes/Elvis/tas-elvis` or another alternate raw ELVIS location.

Negative Requirements:
- No fallback to the old ELVIS source tree.
- No cross-dataset merge behavior.

### L3

Status: current

Question: Should this change be scoped only to the raw-source build tool, or also change the downstream consumers?

Recommended Answer:
- Scope this slice to `./elvis_dem.sh` and the maintainer docs that describe its raw-source workflow.
- Keep downstream defaults unchanged.
- Flutter runtime keeps using the prepared `ELVIS runtime DEM`.
- `Local Topo` rebuilds keep using the prepared `ELVIS topo DEM`.

Answer: agreed

Decision: This slice changes the raw input behind the prepared ELVIS artifacts, but does not change the downstream consumer contracts for Flutter runtime elevation or `Local Topo` rebuilds.

### L4

Status: current

Question: The current code requires the frozen manifest to match the raw source root exactly, so what should the new single-file contract do about manifest validation?

Recommended Answer:
- Remove the manifest requirement from the normal `Elvis 2m DEM` workflow.
- Treat the raw source as the single canonical file `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif`.
- Change `validate-source` to validate that one TIFF directly.
- Build commands use that single TIFF directly and no longer depend on manifest contents.
- The old checked-in manifest can remain in the repo as legacy unreferenced material.

Answer: agreed

Decision: The active `Elvis 2m DEM` workflow must not require a manifest; it validates and builds directly from one canonical TIFF file, while the old checked-in manifest may remain only as legacy material.

### L5

Status: current

Question: With the `Elvis 2m DEM` contract no longer using a manifest, what should happen to the `bootstrap-manifest` subcommand?

Recommended Answer:
- Remove `bootstrap-manifest` from the active CLI contract.
- Support only `validate-source`, `build-runtime`, `build-topo`, and `build-all`.
- Update maintainer docs and help text to the new single-file validation flow.

Answer: agreed

Decision: `bootstrap-manifest` is removed from the active `./elvis_dem.sh` CLI contract.

### L6

Status: current

Question: Should the active `Elvis 2m DEM` contract be the exact canonical TIFF file, or a directory that the tool scans to find it?

Recommended Answer:
- Make the exact canonical TIFF file the active source contract: `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif`.
- `validate-source` should validate that exact file, not scan a directory.
- Build commands should consume that exact file directly.
- If that file is missing, unreadable, or replaced with a different filename, fail clearly instead of scanning the directory for alternatives.

Answer: agreed

Decision: The active `Elvis 2m DEM` contract is the exact canonical statewide TIFF file, not a directory-scanning workflow.

Negative Requirements:
- No directory scan for alternate source files.
- No alternate filename discovery.

### L7

Status: current

Question: Should `Elvis 2m DEM` behave like an already-prepared statewide source TIFF, or should `./elvis_dem.sh` preserve the old ELVIS-style discovery, VRT, and merge pipeline anyway?

Recommended Answer:
- Treat `Elvis 2m DEM` as an already-prepared statewide source TIFF.
- `validate-source` checks that one canonical TIFF directly.
- `build-runtime` and `build-topo` derive their outputs from that one TIFF, using only the transform or resample steps needed to create the existing prepared artifacts.
- Remove the old raw-source directory scan, multi-file discovery, projection-group handling, VRT merge, and cross-tile merge assumptions from the active ELVIS workflow.

Answer: agreed

Decision: The active ELVIS workflow must treat `Elvis 2m DEM` as one already-prepared statewide TIFF and must drop the old multi-file merge assumptions from the raw-source contract.

Reason: There is no longer any need to merge different DEMs before deriving the runtime and topo outputs.
