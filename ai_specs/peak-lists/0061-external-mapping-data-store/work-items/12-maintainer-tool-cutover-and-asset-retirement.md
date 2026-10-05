---
type: Work Item
title: Cut Over Maintainer Tools and Retire Mapping Assets
parent: ../spec.md
---

## What to build

Migrate every inventoried first-party maintainer tool to the tool-manifest resolver, then complete the runtime asset cutover. Remove the generated region-manifest runtime catalog, all migrated repository Mapping datasets, non-UI `pubspec.yaml` asset declarations, and unused `assets/mountain.png`; retain only called Flutter UI assets and no directory-wide SVG registration for uncalled SVGs.

## Required context

- Use `docs/mapping-data-store.md` as the authoritative inventory. Update manifest/fingerprint, routing/peak-list, DEM, Local Topo, and boundary conversion tools, including non-Dart tools classified as store-isolated or invoked only with resolver-validated paths.
- Delete `tool/generate_region_manifest_catalog.dart` and its tests only after all runtime consumers use injected `MappingCatalog`.

## Acceptance criteria

- [ ] Every first-party Dart Mapping-store tool loads `tool_manifest.json` before resolver use, uses only declared Mapping data inputs/outputs, and retains only explicitly declared overrides. Every non-Dart inventory entry is store-isolated or receives only resolver-validated Mapping-store paths.
- [ ] Update route-graph peak-list, regional fingerprint, peak source, DEM acquisition/preparation, Local Topo named DEM resolution, and every other inventoried tool to use manifest-backed paths. Retain local Overpass only as a documented maintainer snapshot source.
- [ ] Remove `tool/generate_region_manifest_catalog.dart`, generated runtime catalog imports/references, and repository Mapping-data contracts including retired `veneto.poly` and peak-prominence CSV inputs. Add a source-level guard permitting generated-catalog references only in explicitly named deletion/migration locations.
- [ ] `pubspec.yaml` declares only runtime-called UI assets; it declares no highways, region manifest, peaks, polygons, TasMap CSV, or broad unused SVG directory. Remove `assets/mountain.png` and migrated mapping datasets from the repository.
- [ ] Update README and Settings/user-facing copy so no runtime description identifies non-UI Mapping data as `assets/...`; user offline tiles remain an app-support cache outside the Mapping data store.
- [ ] Add regression tests for every inventory tool default/override, resolver-only subprocess paths, absence of runtime Overpass, no Mapping `assets/...` contracts in `pubspec.yaml` or user-facing copy, and no runtime generated-catalog dependency.
- [ ] Run `flutter analyze`, `flutter test`, and `flutter build macos --release`. Inspect the release app for absent app sandbox entitlement and absent bundled GDAL/PROJ libraries/data, then perform the Spec's mounted-store macOS verification with the exact packaged bundle.

## Execution status — 2026-10-05

**Blocked before implementation by Work Item 02's incomplete runtime catalog
integration.** Its checklist is checked, but its required replacement of global
generated-catalog behavior is not complete. See that Work Item's prerequisite
review for the reproducible provider failure and affected consumers.

`peakListRegionFilterOptionsProvider` ignores an injected empty `MappingCatalog`
and returns four generated regions. Runtime map layers also still resolve tile
URLs from the generated global catalog. The condition in Required context—every
runtime consumer uses injected `MappingCatalog` before deleting the generator
and its tests—is therefore unmet.

No tool migrations or asset deletions were performed. Resume this Work Item
after the runtime catalog integration is completed and verified. Its acceptance
criteria remain open; full-suite/build/mounted-store verification has not run.

## Covers

- User Stories: 1, 3
- Requirements: 1-2, 9-10, 13, 22-23, 28
- Technical Decisions: 5-6, 12-13
- Testing Strategy: 4-5, 16
- Interview Ledger: L1, L3, L4, L6, L8-L10

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
05-manifest-backed-peak-reconciliation.md
06-transactional-tasmap-updates.md
07-natural-features-mapping-store-refresh.md
08-coverage-qualified-route-graphs.md
09-lazy-polygon-display-failures.md
10-manifest-resolved-route-elevation.md
11-tool-manifest-resolver-and-bootstrap.md
