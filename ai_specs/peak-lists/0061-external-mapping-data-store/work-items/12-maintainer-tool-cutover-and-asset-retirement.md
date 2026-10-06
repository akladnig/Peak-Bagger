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

- [x] Every first-party Dart Mapping-store tool loads `tool_manifest.json` before resolver use, uses only declared Mapping data inputs/outputs, and retains only explicitly declared overrides. Every non-Dart inventory entry is store-isolated or receives only resolver-validated Mapping-store paths.
- [x] Update route-graph peak-list, regional fingerprint, peak source, DEM acquisition/preparation, Local Topo named DEM resolution, and every other inventoried tool to use manifest-backed paths. Retain local Overpass only as a documented maintainer snapshot source.
- [x] Remove `tool/generate_region_manifest_catalog.dart`, generated runtime catalog imports/references, and repository Mapping-data contracts including retired `veneto.poly` and peak-prominence CSV inputs. Add a source-level guard permitting generated-catalog references only in explicitly named deletion/migration locations.
- [x] `pubspec.yaml` declares only runtime-called UI assets; it declares no highways, region manifest, peaks, polygons, TasMap CSV, or broad unused SVG directory. Remove `assets/mountain.png` and migrated mapping datasets from the repository.
- [x] Update README and Settings/user-facing copy so no runtime description identifies non-UI Mapping data as `assets/...`; user offline tiles remain an app-support cache outside the Mapping data store.
- [x] Add regression tests for every inventory tool default/override, resolver-only subprocess paths, absence of runtime Overpass, no Mapping `assets/...` contracts in `pubspec.yaml` or user-facing copy, and no runtime generated-catalog dependency.
- [ ] Run `flutter analyze`, `flutter test`, and `flutter build macos --release`. Inspect the release app for absent app sandbox entitlement and absent bundled GDAL/PROJ libraries/data, then perform the Spec's mounted-store macOS verification with the exact packaged bundle.

## Initial prerequisite review — 2026-10-05 (resolved)

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

## Implementation and verification — 2026-10-06

**Implementation complete; final mounted-store acceptance remains blocked.**
The original Work Item 02 catalog-integration blocker is resolved, with permanent
behavioral coverage and ready-scope fixture injection throughout widget/robot
harnesses. No runtime generated-catalog dependency remains.

- Fingerprint tools validate the shared regional schema and read only named
  inputs; writes use atomic resolver publication. Ranking and Hribi correlation
  obtain source paths and geometry from the parsed manifest pair.
- Route-graph peak-list generation uses resolver reads and a shared pure-Dart
  app-owned CSV format, avoiding Flutter dependencies in its standalone CLI.
- theLIST preparation uses a checked external workspace and a resolver-staged
  GDAL worker. ELVIS prepares externally and streams into its declared file or
  directory snapshot. Metadata/previews/reports remain non-store.
- Local Topo wrappers enter the Dart resolver, with named DEM choices derived
  from manifest metadata, a store-relative input override, and a separately
  checked external adapter. Worker argv and publication paths are resolver-owned.
  The subprocess boundary enforces the command executable/declared argv prefix
  and rejects input/output role substitution or appended Mapping operands.
- User/report/cache adapters cannot authorize Mapping paths. The transitional
  I/O list is retired; explicit non-store sites and all non-Dart classifications
  are recorded in `docs/mapping-data-store.md` and enforced by source guards.
- Retired the unused mountain image and uncalled SVGs, the generator/output,
  legacy Overpass runtime service and refresh implementation, their obsolete
  tests, home DEM fallback, repository polygon/CSV defaults, and broad SVG
  registration. Four called UI SVGs remain. Repository Mapping datasets had
  already been physically migrated and none remain under `assets/`.

Automated verification:

- `flutter analyze --no-pub`: **no issues**.
- `flutter test --no-pub --reporter=failures-only`: **2,136 passed, 5 skipped**.
- Resolver/cutover/inventory regression group: **75 passed**.
- `flutter build macos --release`: **success**, reported bundle size **64.8 MB**.
- Shell syntax checks pass for changed wrappers/workers. Standalone Dart smoke
  checks pass for Hribi/theLIST help, Local Topo help via its wrapper, ranking
  help, and route-graph invalid-option handling without a Flutter engine.

Packaged verification used exactly
`build/macos/Build/Products/Release/peak_bagger.app`:

- `codesign` entitlement inspection: **no `com.apple.security.app-sandbox`**.
- Bundle filename walk and native/AOT `otool` dependency inspection: **no bundled
  GDAL/PROJ libraries or data**. The asset tree contains only the four UI SVGs;
  leftover incremental-build Mapping directory names contain no files.
- Native executable SHA-256:
  `62fae593db3b0fa73b9ba15a096dbaa0e4a73d95238cb5f1613b7d11a1ee5ca7`.
- AOT `App.framework/App` SHA-256:
  `ad98c9b208bd68737546b04007b6ce11cf1b441a8cd01fa6fc4c2b228f1d91c7`.
- Launched the inspected bundle against the real fixed mount with a temporary
  `CFFIXED_USER_HOME`/`HOME`. Verified its ObjectBox, parsed geometry cache, and
  offline tile cache were created under that temporary application-support
  directory, outside Mapping. The system preference profile was still readable;
  this is evidence of isolated database/cache storage, not a separate preference
  profile. The app reached the main router/dashboard and Settings. Host GDAL
  tooling reports **GDAL 3.10.0**; startup did not require a DEM open.
- Captured exact `Update Peak Data?` and `Update Map Data?` confirmations with
  `Update` actions. Natural Features retained its background-job flow.
- Mounted operations displayed typed operation/path feedback for Northeast
  Alps route-graph bootstrap (all three highway paths), Italy North West peak
  update (`Peaks/italy-nord-ovest-peaks.json`), Natural Features refresh
  (`Features/tasmania_natural_features.json`), and TasMap update
  (`Maps/tasmap50k.csv`). Natural Features job details explicitly report
  `FormatException: Duplicate source OSM feature identity`. Dismissal preserved
  the initiating UI. No successful reconciliation/import is claimed for these
  failing sources, and no Mapping source was repaired or overwritten.
- Quit the verification app after the checks. Temporary databases/cache and
  screenshots remain at
  `/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode/peak-bagger-release-HhYkE9`.

### Remaining blocker and follow-up

`dart run tool/mapping_store.dart provision-or-verify` cannot complete because
the mounted `tool_manifest.json` lacks `mapping-store-provision`. The installed
tool contract must be reviewed/provisioned by the maintainer; bootstrap must not
overwrite an existing conflicting manifest. Mounted source-operation failures
listed above also prevent claiming successful first-run/bootstrap/refresh flows.

Keep the last acceptance criterion open. After provisioning the retained
contract and valid source snapshots, repeat successful first-run peak seeding,
per-coverage graph bootstrap, peak refresh, Natural Features refresh, and TasMap
update with this exact packaged bundle. Store-disconnect/reconnect startup and
real packaged DEM sampling (including missing/incompatible host GDAL) have not
been manually completed; deterministic automated coverage is not a substitute
for those remaining mounted-store checks. Do not clear production user data or
change Mapping source permissions/files to manufacture a successful result.

## Mounted TasMap retry and Natural Features diagnosis — 2026-10-06

The TasMap source failure above is resolved by `3e13603`
(`fix(tasmap): allow blank parent values`). The canonical `Parent` header remains
required, but blank values are accepted. The mounted CSV parses into **75 sheets,
10 with blank parents**. Real-source reconciliation against temporary ObjectBox
storage succeeded; a repeated import reported `changed == false` and retained
every ID. Correcting a deliberately stale parent in that temporary database
retained every ID, and the next identical import again reported no changes.

Rebuilt `build/macos/Build/Products/Release/peak_bagger.app`, launched with
temporary `CFFIXED_USER_HOME`/`HOME`, and completed Settings **Update Map Data**
with its **Update** confirmation. The UI displayed
**Map data updated successfully!** After quitting the verification app, a database
readback confirmed **75 persisted TasMap rows and 10 blank parents**. The production
database and mounted source files were not modified. Screenshots, startup logs,
and the temporary packaged database remain at
`/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode/peak-bagger-tasmap-retry-ukMV6n`.
Startup logs also contain a `Directionality.of` null-check exception before the
ready UI; this retry does not resolve or claim clean startup logging.

- Native executable SHA-256:
  `1fb1e320413b3f9457ab15d3ef56e311030a3ae51166fa6d898dd647b5e91fc4`.
- AOT `App.framework/App` SHA-256:
  `7426e2cdc7c860c902a87703ae60feada7c534e4260f714eea607e61546e69b3`.
- Mounted TasMap CSV SHA-256:
  `3a59e442cadda3827363d497963732af4d1e5e2971cc841599ebaaf119bd1cb6`.

The mounted Natural Features JSON contains **630,521 elements**, **630,344 unique
OSM identities**, and **177 duplicated identities**, all ways appearing twice.
For every pair, type, ID, and ordered node geometry are identical; only `tags`
differs: a tagged feature is repeated later as an untagged skeleton. These are
duplicate export records, not conflicting geometry or evidence of duplicate
production ObjectBox rows. At the time of this diagnosis, the source parser rejected any repeated
identity before reconciliation and reproduced the exact `FormatException`.
The first repeat encountered is **`way:1527474295`, Bishop Islet**, at
`/elements/2598` and `/elements/625540` (ID fields at source lines **204523** and
**3971393**). Full pair records and a compact inventory of all 177 pairs are in
`natural-feature-duplicate-report.json` and `natural-feature-duplicate-summary.json`
under `/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode`.
Natural Features source SHA-256:
`75565dfe512ec39da4d3e6e240a8599aadfd757a1c3873a02d97a14264f36158`.

The final acceptance criterion remains open for the tool-manifest discrepancy,
the other source failures, and the previously recorded reconnect/DEM checks.

## Natural Features compatibility correction and packaged retry — 2026-10-06

Review of Spec 0058 and `00f2591` confirmed that untagged geometry dependencies
were not eligible Natural Feature candidates. The broad rejection of supporting
duplicates introduced by `02e2254` was stricter than that distinction. The
correction documented in Work Item 07 accepts compatible tagged/skeleton pairs
while retaining candidate uniqueness and conflicting-geometry failure.

The unchanged mounted source now passes all 177 compatible way pairs. The next
failure is **`relation:8812595`, Sisters Hills**, with `type=site`,
`natural=mountain_range`, and seven node members but no way members. Its ID is at
source line **224752**, and its record spans lines **224750–224795**. The current
centroid contract ignores node members, so it cannot resolve this relation.
The mounted probe verified that this error occurs before any source-derived rows
are written and preserves the existing temporary Manual row and ObjectBox ID.

The rebuilt packaged app reproduced the same outcome through Settings
**Refresh Natural Features**, with its background job, operation-scoped dialog,
and the exact status cause:
`FormatException: Malformed Natural Feature geometry for relation:8812595`.
Screenshots `natural-refresh-started.png`, `natural-refresh-result.png`, and
`natural-refresh-details.png`, plus `natural-retry-launch.log`, are in the
temporary verification directory recorded above. The verification app was quit;
no production database or Mapping source was modified. The shared system
preference profile is not isolated by this temporary database/cache setup.

- `flutter analyze --no-pub`: **no issues**.
- Focused Natural Features suite: **46 passed**.
- Full suite: **2,145 passed, 5 skipped**.
- `flutter build macos --release --no-pub`: **success**.
- Native executable SHA-256:
  `1fb1e320413b3f9457ab15d3ef56e311030a3ae51166fa6d898dd647b5e91fc4`.
- Updated AOT `App.framework/App` SHA-256:
  `93e0c1f4e751a077cd366d453b1dc2af9f451e277718dce939de1c5db6fa58ab`.
- Natural Features source SHA-256 remains
  `75565dfe512ec39da4d3e6e240a8599aadfd757a1c3873a02d97a14264f36158`.

Natural Features end-to-end success remains blocked by the unresolved relation,
not the compatible repeated way skeletons. This correction does not change the
all-or-nothing malformed-selected-geometry policy or claim the final mounted-store
acceptance criterion complete.

## Successful Natural Features mounted acceptance — 2026-10-06

The user approved a diagnostic skip for well-formed unsupported node-only
relations. The implemented policy and malformed-input protections are documented
in Work Item 07 and Spec 0061. Sisters Hills is skipped without inventing a
position, and existing OSM/Manual rows for a skipped identity are retained.

The unchanged mounted source now succeeds: a temporary ObjectBox probe reported
**2,933 created, 0 updated, 0 protected, 1 skipped**, then
**0 created, 2,933 updated, 1 skipped** on repeat. Every ID and a pre-existing
Manual Bishop Islet row survived. Its log is
`/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode/natural-feature-full-source-retry.log`.
The full-source debug test needed a longer timeout; its two successful refreshes
took approximately **5 minutes 17 seconds** in total. This is verification
evidence, not a claim of optimized source-processing performance.

Launched the rebuilt release bundle against the same mounted source and the
temporary packaged database/cache directory recorded above. First-run Natural
Features bootstrap populated the previously empty table; the subsequent Settings
background-job refresh displayed exactly:
**Natural features refreshed: 0 created, 2933 updated, 0 protected, 1 skipped.**
`natural-skip-refresh-success.png` captures that status, and
`natural-skip-launch.log` records startup. After quitting the verification app,
database readback confirmed **2,933 persisted OSM features with unique source
record keys**, exactly one Bishop Islet, and no Sisters Hills row with a made-up
position. The production database and Mapping source were not modified; the
temporary database/cache setup does not isolate the system preference profile.

- Focused Natural Features suite: **50 passed**.
- Full suite: **2,149 passed, 5 skipped**.
- `flutter analyze --no-pub`: **no issues**.
- `flutter build macos --release --no-pub`: **success**.
- Native executable SHA-256:
  `1fb1e320413b3f9457ab15d3ef56e311030a3ae51166fa6d898dd647b5e91fc4`.
- Current AOT `App.framework/App` SHA-256:
  `7d0ff67436563fab18db940340520b2d17bda0042a18b7eb1befe13b723e0a96`.
- Mounted Natural Features source SHA-256 remains
  `75565dfe512ec39da4d3e6e240a8599aadfd757a1c3873a02d97a14264f36158`.

The TasMap and Natural Features source-operation blockers are now resolved.
Keep the final acceptance criterion open for the tool-manifest discrepancy,
Italy North West peaks, Northeast Alps highways, and the recorded reconnect/DEM
checks; this successful flow does not imply those checks succeeded.

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
