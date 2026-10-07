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
- [x] Run `flutter analyze`, `flutter test`, and `flutter build macos --release`. Inspect the release app for absent app sandbox entitlement and absent bundled GDAL/PROJ libraries/data, then perform the Spec's mounted-store macOS verification with the exact packaged bundle.

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

## Remaining source diagnosis and startup/elevation acceptance — 2026-10-06

### Italy North West: valid records, conflicting region ownership

A complete read-only scan found **9,697 elements, all eligible peaks**, with no
missing/invalid required fields or duplicate identities within that source.
A production-service probe with an isolated in-memory repository successfully
parsed, derived MGRS, and reconciled all 9,697 peaks. After importing the real
Italy North East source (**9,683 peaks**) into a separate isolated repository,
the same NW operation fails with:

`Bad state: OSM identity 498481565 cannot be imported for italy-nord-ovest.`

The exact rejected record is **Costone delle Cornelle**, with valid coordinates
`45.880936, 10.493754`, elevation `2201`, and `alt_name=Cima Valleselle`. It occurs
at NW `/elements/1435` (ID line **18361**) and NE `/elements/572` (ID line
**8047**). Both source records are identical. Four identities overlap:

| OSM node ID | Name | NW element | NE element |
| --- | --- | --- | --- |
| 498481565 | Costone delle Cornelle | 1435 | 572 |
| 523391640 | Corno della Vecchia | 1976 | 635 |
| 673011812 | Thurwieserspitze - Punta Thurwieser | 2847 | 976 |
| 13100307781 | Cresta Pisage, Nord | 9567 | 9540 |

This is requirement 18's explicit rejection of an incoming identity already
owned by another source region, implemented in `PeakRepository.reconcileOsmRegion`.
The probe confirmed that failure preserves every NE record and fingerprint and
writes no NW rows or marker. Historical importer `7d8b50f` permitted reassignment;
the stricter current behavior is an intentional Spec 0061 contract change,
not malformed NW source content or an accidental parser regression. Successful
combined seeding requires either maintainer-approved disjoint source ownership
and republished fingerprints, or an explicitly approved Spec/policy revision.
No ownership rule or mounted snapshot was changed.

### Northeast Alps: inconsistent source generations

A full identity scan of the three mounted files found **52 conflicting
identities**, all shared by FVG and Slovenia: **7 ways** with differing ordered
node geometry (one also differs in tags), and **45 nodes** with differing
coordinates. FVG and Veneto have no internal conflicts and no mutual conflicts.

The first rejected identity is **`way:62263719`**, at FVG `/elements/1021`
(ID line **95704**) and Slovenia `/elements/27193` (ID line **806782**).
Slovenia calls it **Mangart Italian Normal Route**; its node sequence, difficulty,
and other tags differ from FVG's record. Source timestamps are FVG
`2026-08-01T07:33:51Z`, Veneto `2026-08-01T08:46:31Z`, and Slovenia
`2026-09-27T20:06:28Z`.

This violates the retained canonical-JSON identity merge rule. The same rule is
present in pre-migration resolver `8e8ccaa`; a probe of the exact first pair
reproduces the conflict before graph import. These are real geometry differences,
not compatible tagged/skeleton duplicates. Refresh the overlapping snapshots
from a consistent upstream dataset before retrying; do not choose one conflicting
geometry silently or remove Slovenia from the coverage. No mounted file was
repaired. The rebuilt package still presents the Northeast Alps bootstrap failure
with all three source paths.

Read-only source hashes:

- NW peaks: `17c8820c686125f06ba8dbf8979c2c76743ed24e353e0a1ca22e8f517fb290bd`.
- NE peaks: `2bbee51c74151c78920dc44178cbd1c9c38c7f631043d95d8118e9bed5a924f8`.
- FVG highways: `8f738e72547263a7802a0a2acf07a572f3deb9dc52eac66af3c5fb62495d0d91`.
- Veneto highways: `952a44fd6ce56350df70f0c611a8cdcc6d245b239a70f4cdcea049a8140aabab`.
- Slovenia highways: `7fdf867d10e849ce54f6bcb8ba695065cb08e1aad3b51b2099c2d1a14353c035`.

Full conflicting records and pointers are retained in
`remaining-mapping-source-diagnosis.json` and
`remaining-peak-source-diagnosis.json` under
`/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode`.
`remaining_mapping_probe_test.dart` there records the three successful diagnostic
probes; these live-source probes are not part of the deterministic committed suite.

### Complete tool contract review

The mounted `tool_manifest.json` is **`{}`**, so **all 13 v1 tool capabilities are
missing**, including `mapping-store-provision`. The real `provision-or-verify`
command fails with `Undeclared Mapping-store tool: mapping-store-provision`.
Direct read-only use of the shared contract verifier reports exactly those 13
missing tool entries and no runtime-pair mismatches. A projected verification
using fixture tools with the real mounted region/polygon manifests reports
**zero differences**. That projection does not provision or verify an installed
tool contract. Explicit reviewed provisioning instructions are now in
`docs/mapping-data-store.md`; the mounted manifest remains unchanged.

### Startup correction and exact-package verification

Production `runApp` mounted `StartupShell` directly, but its startup `Scaffold`s
had no `MaterialApp` ancestor. Existing tests supplied that ancestor externally,
masking the release `Directionality.of` null-check failure. The shell now owns a
non-router `MaterialApp` for startup states and replaces it with the ready app
only at readiness. A new production-root widget journey first reproduced
`No Directionality widget found`, then passed through checking, initializing,
unavailable, Retry, and ready with no framework exception and exactly one
`MaterialApp` after handoff.

- `flutter analyze --no-pub`: **no issues**.
- Startup widget group: **8 passed**.
- `flutter test --no-pub --reporter=failures-only`: **2,150 passed, 5 skipped**.
- `flutter build macos --release --no-pub`: **success**, **64.8 MB**.
- Exact tested bundle: `build/macos/Build/Products/Release/peak_bagger.app`.
- Native executable SHA-256:
  `1fb1e320413b3f9457ab15d3ef56e311030a3ae51166fa6d898dd647b5e91fc4`.
- AOT `App.framework/App` SHA-256:
  `496f6cf60b1f7152cfd0a611fe9128a7607a7839360c5bf6d9676c29a75e75d8`.
- Entitlements still have **no app sandbox**. Full bundle filename inspection and
  `otool` checks of the executable and all four frameworks found **no bundled
  GDAL/PROJ libraries/data or linked GDAL/PROJ dependencies**. Only four called
  UI SVGs are present beneath the bundled `assets` path.

Packaged runs used a copy of the previously isolated verification database/cache
under `peak-bagger-remaining-acceptance`, with temporary `CFFIXED_USER_HOME` and
`HOME`. Normal, missing-GDAL, incompatible-GDAL, and access-denial startup logs
contain no `Directionality.of` or null-check exception. As before, this does not
isolate the shared system preference profile. No production database or Mapping
source file/permission was changed, and all verification processes were quit.

**Packaged elevation checks passed using this same AOT bundle**:

- Normal host GDAL **3.10.0**: a straight route near kunanyi/Mount Wellington shows
  **2.5 km 2D / 2.8 km 3D, 1 m ascent, 958 m descent**, with a nonzero elevation
  profile. Screenshot: `route-elevation-normal.png`.
- Missing library: launch with `GDAL_LIBRARY_PATH` pointing to a nonexistent
  temporary file. Startup succeeds; route sampling then displays exactly
  **Tasmania elevation data is unavailable on this device**, preserving route
  geometry. Screenshot: `route-elevation-missing-gdal.png`.
- Incompatible library: launch with `GDAL_LIBRARY_PATH=/usr/lib/libSystem.B.dylib`,
  a loadable native library without GDAL symbols. Startup succeeds; sampling
  displays the same feature-specific error. Screenshot:
  `route-elevation-incompatible-gdal.png`.

A separate host `sandbox-exec` profile denied Mapping reads for the verification
process only. The **exact packaged app** rendered the blocking startup screen
with the fixed root, `Polygons/manifest.json`, `region_manifest.json`, and root
failure `.`; exposed Retry/Quit; returned to unavailable after keyboard activation
of Retry while denial remained; and exited after keyboard activation of Quit.
Its log contains only widget-binding initialization, with **no ObjectBox open or
ready-dependency initialization**. This verifies controlled startup access failure,
not physical unmount/reconnect or successful same-process Retry after reconnection.
The startup screenshots, four launch logs, `native-dependencies.txt`, and
`acceptance-evidence.json` are retained under
`/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode/peak-bagger-remaining-acceptance`.

**Keep the final acceptance criterion open.** Remaining prerequisites are explicit
tool-manifest provisioning, approved ownership for the four overlapping peaks,
consistent Northeast Alps source snapshots, and actual disconnect/reconnect with
successful same-process Retry. `/Volumes/Services` is currently a local APFS
volume (`/dev/disk5s3`), not an independently removable NAS Mapping mount; a user
debug app is active against it. Coordinate the real disconnect rather than
unmounting that whole Services volume during the user's active session. Then
repeat successful source operations and reconnect acceptance with the final exact
release bundle before claiming completion.

## Approved precedence and successful packaged graph cutover — 2026-10-07

The user confirmed tool-manifest provisioning and approved L11: **NE owns shared
NE/NW peaks; skip NW**, and **FVG wins over Slovenia highway identities**. Spec
requirements 31–32 and the Work Item 05/08 follow-ups record these narrow policy
exceptions. They supersede the previously diagnosed blockers for those exact
source pairs; no mounted peak/highway snapshot was rewritten.

### Manifest and deterministic verification

- Real `dart run tool/mapping_store.dart provision-or-verify`: **success, zero
  allowed differences**. The mounted tool manifest now matches the complete v1
  fixture, including every named capability. Both have SHA-256
  `6eafe5688c2b63d0aa060d19553a94baa8cf6f1a660cccb1e509d25804653b1a`.
- NE/NW precedence uses current validated NE sources even when NW imports first.
  It validates NW before skipping overlaps, reports skip counts, preserves skipped
  existing NW rows until NE reconciliation, and preserves IDs/user fields during
  the permitted OSM-owned NW-to-NE transfer. Other ownership protections remain.
- Both highway resolver modes share a provenance-aware complete-element merger.
  It chooses FVG independent of source order, keeps Slovenia-only elements,
  rejects inconsistent repeats within a source region or a conflict involving
  Veneto, and validates retained selected geometry before graph writes. The hash
  payload includes `sourceMergePolicy: fvg-over-slovenia-v1` and all snapshots.
- Focused precedence/mapping-contract group: **29 passed**.
- `flutter analyze --no-pub`: **no issues**.
- Full suite: **2,160 passed, 5 skipped**.
- `flutter build macos --release --no-pub`: **success**, **64.8 MB**.

The full unchanged-source probe reconciled **9,683 NE and 9,693 NW peaks**, with
**4 NW skips** and **19,376 unique identities**. Repeated NW/NE refresh retained
every ObjectBox ID. The full Northeast Alps probe resolved **8,343,986 elements**,
verified all **52 conflicts** retained the exact FVG record, and imported a usable
ObjectBox generation with **4,081 chunks, 7,780,038 nodes, 558,284 ways/edges**.
Resolve/import took approximately **6 minutes** in that Flutter-test process.

Temporary probe databases are `peak-precedence-probe-8tSAoH` and
`graph-precedence-probe-uoTHgh` beneath the previously recorded `T/opencode`
directory. `mounted_precedence_acceptance_test.dart` contains the source probes;
live mounted data is not a dependency of the committed automated suite.

### Exact packaged bootstrap and manual graph refresh

Launched exactly `build/macos/Build/Products/Release/peak_bagger.app` with a **fresh
temporary database/cache home**, `peak-bagger-precedence-release`, beneath
`/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode`.
The startup log confirms no legacy temporary database existed and a new ObjectBox
store was opened there. It contains no Directionality/null-check exception.
System preferences remain shared; this setup isolates database/cache ownership,
not the preference profile.

- Native executable SHA-256 remains
  `1fb1e320413b3f9457ab15d3ef56e311030a3ae51166fa6d898dd647b5e91fc4`.
- Current AOT SHA-256:
  `ed4f8a0652ece6447dd96ce3df61fb8da34b14b458ec98675a2034b7720791fe`.
- Entitlement inspection: **no app sandbox**. Full bundle filename and native
  executable/framework dependency inspection: **no GDAL/PROJ libraries/data**;
  four called UI SVGs only. `bundle-evidence.json` records hashes and source
  digests; `native-dependencies.txt` records the native inspection.
- Initial bootstrap completed both routing coverages and NE/NW peak seeding.
  The packaged bootstrap also persisted **75 TasMap rows** and **2,933 Natural
  Features** from the mounted sources.
- Settings **Refresh Route Graph**, with its **Refresh** confirmation, completed
  successfully. `graph-refresh-result.png` shows exactly **Route Graph Refreshed**
  and **Refreshed: tasmania, northeast-alps.** Both full-source packaged graph
  operations took several minutes; no performance optimization is claimed.
- After quitting the verification app, `packaged_precedence_readback_test.dart`
  confirmed both coverages are usable. Northeast Alps has generation **2**,
  **4,081 chunks**, **7,780,038 nodes**, **558,284 ways/edges**, **1,161,290
  way-index rows**, and **51,740 display chunks**. It retains all three source
  regions and source hash
  `e9dddc684c1fe0a94553029037b39e4315631fab94fa50384911776476420710`.
  Stored way `62263719` retains FVG's `sac_scale=demanding_mountain_hiking` and
  `name:sl=Italijanska pot`, rather than the conflicting Slovenia tags.
- Packaged peak readback confirms **9,683 NE, 9,693 NW**, unique identities, NE
  ownership of all four boundary overlaps, and the current NW fingerprint.
  The four successfully seeded regions contain **22,422 peaks** in total
  (Tasmania 1,032; NSW 2,014; NE 9,683; NW 9,693). No production database or mounted
  source was changed. The verification app was quit.

Screenshots, startup log, `bundle-evidence.json`, and `database-readback.json`
remain in `peak-bagger-precedence-release`.

### Newly exposed peak blocker and final acceptance

The fresh packaged run exposed a separate **Slovenia peak ownership failure**:
`OSM identity 421008446 cannot be imported for slovenia.` The record is
**Dreiländereck / Peč / Ofen / Monte Forno**, present at NE `/elements/440` and
Slovenia `/elements/90` with identical source contents. It is already NE-owned
when Slovenia seeding runs. The approved NE/NW rule does not authorize changing
NE/Slovenia ownership.

A complete read-only cross-source scan found **9 NE/Slovenia overlaps** and
**2 Slovenia/Croatia overlaps**, in addition to the four resolved NE/NW overlaps.
The Slovenia/Croatia identities are **8295309638, Brezova gora**, and
**10136061100, Bricljeva gora**. A sequential diagnostic probe with explicit
per-region calls reproduces Slovenia's error and confirms Croatia's source
parses/imports independently. The packaged seed sequence stops at Slovenia, so
neither Slovenia nor the later Croatia region has source rows/fingerprints in
this new packaged database. Earlier successful regions remain intact; this is
not successful all-region first-run acceptance.

All records/pointers are in `all-peak-overlaps.json`; per-region results are in
`all-region-seeding-diagnosis.json` beneath `T/opencode`. Additional ownership
policy for these pairs remains a user decision. Do not silently broaden the
approved exceptions or mark failed regions current.

**The final acceptance criterion remains open** for those peak ownership
decisions, actual reconnect-and-successful-same-process-Retry, and completion of
all acceptance flows with the final exact bundle. Prior elevation/GDAL evidence
belongs to the earlier AOT bundle and must be repeated when selecting the final
acceptance bundle. The old tool-manifest, NW peak, and FVG/Slovenia highway blockers
are resolved by this verification.

## All-region peak precedence and final-bundle verification — 2026-10-07

The user approved L12: **NE over Slovenia**, and **Slovenia over Croatia**.
Together with L11, source ownership is NE > NW and NE > Slovenia > Croatia.
The shared app-owned `preferredPeakSourceRegions` policy now controls both
validated source exclusion and permitted OSM ownership transfers. A three-source
overlap resolves to NE, with one skip per losing source. Existing IDs/user fields,
malformed-source atomicity, and user-owned/unowned protections are retained.
The prior NE/Slovenia and Slovenia/Croatia ownership blockers are resolved.

Verification:

- Peak source/repository regression group: **20 passed**, covering both pairwise
  orders, all six three-source orders, transfers preserving IDs/user state,
  protected user records, and missing/malformed/duplicate preferred inputs.
- `flutter analyze --no-pub`: **no issues**.
- Full suite: **2,165 passed, 5 skipped**.
- The combined analyze/test/build command timed out during the build. A separate
  `flutter build macos --release --no-pub` retry **succeeded**, **64.8 MB**. The
  timeout did not invalidate the passing analysis or full-suite result.
- Real provision-or-verify and regional fingerprint validator both succeed:
  **zero retained-contract differences; all source fingerprints current**.

The unchanged mounted sources reconcile as follows:

| Source region | Imported peaks | Overlap skips |
| --- | ---: | ---: |
| Tasmania | 1,032 | 0 |
| New South Wales | 2,014 | 0 |
| Italy NE | 9,683 | 0 |
| Italy NW | 9,693 | 4 |
| Slovenia | 10,833 | 9 |
| Croatia | 12,721 | 2 |
| **Total** | **45,976 unique peaks** | **15** |

A real temporary ObjectBox source probe verified all 15 preferred owners and
all six committed fingerprints. Refreshing every region in reverse order retained
every ID and a deliberately populated border peak's user-maintained note/rating.
The probe report is `all-region-peak-precedence-success.json`, and its temporary
database is `all-peak-precedence-probe-DhwevW` beneath `T/opencode`.

### Exact release and isolated verification data

All checks below use exactly
`build/macos/Build/Products/Release/peak_bagger.app`:

- Native executable SHA-256:
  `1fb1e320413b3f9457ab15d3ef56e311030a3ae51166fa6d898dd647b5e91fc4`.
- AOT `App.framework/App` SHA-256:
  `18b7c67bfc3f605271f26e4cc346021ac33112e19e52f7881e66fb5a070b592b`.
- Entitlements: **no app sandbox**. Bundle walk and all native framework dependency
  checks: **no bundled/linked GDAL/PROJ libraries/data**; four called UI SVGs.
- `bundle-evidence.json` verifies the previous source hashes remain unchanged,
  including every regional peak source, both manifests, all highway sources,
  TasMap, Natural Features, and the completed tool manifest.

The test home is
`/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode/peak-bagger-all-peak-release`.
It began as a copy of the previously isolated prepared-graph database/cache.
Only that copied database's Peak/fingerprint tables were emptied to exercise
conditional automatic peak seeding. Prepared graphs, TasMap and Natural Features
remained populated; this is empty-peak-table acceptance, not a claim that the
whole database was initially empty. `CFFIXED_USER_HOME` and `HOME` direct packaged
ObjectBox/cache ownership to this test home. The system preference profile remains
shared. **No verification refresh writes the production ObjectBox database**, and
no Mapping source or permission was changed.

### Packaged results

- Automatic empty-table peak seeding succeeds for all six regions: **45,976
  unique peaks**, all 15 preferred owners, six current fingerprints. Readback is
  `automatic-seeding-readback.json`.
- To verify actual manual source reads rather than a fingerprint no-op, only the
  copied database's six markers were made stale and a border note/rating was set.
  Settings **Update Peak Data? → Update** reports exactly **Peak Data Updated**,
  **45,976 Peaks updated**, **15 peaks skipped**. Post-quit readback confirms all
  IDs and user fields survive and all six fingerprints return to current. See
  `peak-update-confirmation.png`, `peak-update-result.png`, and
  `manual-refresh-readback.json`.
- Settings **Update Map Data? → Update** succeeds. The status is **Map data
  updated successfully!**, captured in `map-update-result-bottom.png`.
- Settings **Refresh Natural Features** completes its background job with
  **0 created, 2933 updated, 0 protected, 1 skipped**, captured in
  `natural-refresh-completed.png`.
- Settings **Refresh Route Graph? → Refresh** reports **Route Graph Refreshed**
  and **Refreshed: tasmania, northeast-alps.**, captured in
  `graph-refresh-success.png`. Both coverages remain usable and retained way
  `62263719` still has FVG's `sac_scale=demanding_mountain_hiking`.
- Normal host GDAL **3.10.0** opens the mounted ELVIS runtime DEM and samples a
  Tasmania draft route: **1.1 km 2D / 1.2 km 3D**, **0 m ascent, 460 m descent**,
  with a nonzero elevation profile. See `route-elevation-normal.png`.
- Missing-library and incompatible-library launches both reach the ready app.
  The existing `GDAL_LIBRARY_PATH` override points respectively to a nonexistent
  temporary file and `/usr/lib/libSystem.B.dylib`. Route sampling then displays
  exactly **Tasmania elevation data is unavailable on this device**, retaining
  the draft route. See `route-elevation-missing-gdal.png` and
  `route-elevation-incompatible-gdal.png`.
- Controlled startup read denial for the test process renders the blocking
  unavailable screen, retries to unavailable while denial persists, and exits
  through Quit. Its log has **no ObjectBox open**. All tested startup logs have
  no Directionality/null-check exception. This remains a process-local host
  access-denial check, not real volume disconnect/reconnect.

A cold Northeast Alps bootstrap with this same exact bundle **succeeded** after
removing only that coverage's rows/manifest from the copied temporary database.
The preparatory readback proved Northeast Alps had no usable generation while
Tasmania remained usable. The packaged app then imported the unchanged highway
sources and committed generation **3**, source hash
`e9dddc684c1fe0a94553029037b39e4315631fab94fa50384911776476420710`, **4,081 chunks,
7,780,038 nodes, and 558,284 ways**. Post-quit readback verifies both coverages
usable, retained FVG tags, all **45,976 peaks** and six fingerprints, **2,933
unique Natural Features** without an invented Sisters Hills position, and **75
TasMap sheets**, including **10 blank parents**. See `final-flows-readback.json`.
The cold run took approximately **18 minutes** under the current host workload;
its final window screenshot could not be captured, so the committed database and
startup log are the cold-bootstrap evidence. No performance optimization or
successful screenshot capture is claimed. All verification processes were quit.

**Keep the final acceptance criterion open for real mounted disconnect/reconnect
and successful same-process Retry.** The user asked whether these refreshes affect
production ObjectBox and was told they affect only the temporary database; that
question is not authorization to unmount the whole local `/Volumes/Services`
volume. Coordinate the actual volume check separately. The source-operation,
tool-manifest, startup Directionality, and host-GDAL blockers are resolved.

## Real volume reconnect and final acceptance — 2026-10-07

**All Work Item 12 acceptance criteria are complete.** The user explicitly
authorized the real `/Volumes/Services` unmount/re-mount. Normal unmount initially
reported an idle WezTerm shell, then Microsoft Excel as dissenters; the user
cleared those blockers. No forced unmount or termination of those applications
was used. Preliminary evidence-capture attempts restored the mount before
retrying; the completed cycle below is the final acceptance evidence.

The final cycle used the same exact release bundle and populated isolated test
home documented above. Both executable hashes were checked before launch and
match the final-bundle hashes recorded in the previous section.

- `diskutil unmount /dev/disk5s3` succeeded. Disk Utility reported an empty mount
  point, and the fixed-root regional manifest was absent. This is an actual APFS
  volume unmount, not the previous process-local read-denial simulation.
- Launched the final release at **16:31:59**, process **66104**. While Services was
  unmounted, its blocking screen displayed exactly **Mapping data store
  unavailable**, **`/Volumes/Services/Mapping`**, root failure **`.`**, required
  paths **`Polygons/manifest.json`** and **`region_manifest.json`**, and **Retry /
  Quit**. The log contained only widget-binding initialization; ObjectBox and
  ready-only dependencies had not opened.
- `diskutil mount /dev/disk5s3` restored **`/Volumes/Services`**. Before Retry,
  the same process retained the blocking screen and still had not opened
  ObjectBox. Keyboard **Tab → Space** activated **Retry** at approximately
  **16:32:12**. Preflight succeeded, then ObjectBox opened only beneath the
  isolated test home. After initialization, the same **PID 66104** displayed
  the ready dashboard and main navigation, including Settings. The visible
  dashboard, not merely completion of a dependency-initialization log phase,
  is the readiness evidence.
- The release verification process was quit after that dashboard capture.
  Services remains mounted with volume UUID
  **`42933566-224A-4AB9-B490-E6F62E896736`**. The user's existing debug app was
  left running; verification never launched against production ObjectBox.
- A post-quit isolated database readback passed: **45,976 unique peaks**, all
  six source fingerprints current, every peak ID preserved, and the populated
  border peak's note/rating retained. Both route-graph coverages remain usable;
  Northeast Alps retains generation **3**, **4,081 chunks**, **7,780,038 nodes**,
  **558,284 ways**, and the previously verified source hash. **2,933 Natural
  Features** and **75 TasMap sheets** remain persisted. The reconnect startup log
  contains no Directionality or null-check exception.
- Re-hashed all **15** previously recorded Mapping source/manifest files after
  reconnection: every digest is unchanged. This verification changed only the
  temporary app database/cache and evidence; no Mapping source was rewritten.

Evidence remains under
`/var/folders/rb/c88n7kqx4r558_c17k24kk800000gn/T/opencode/peak-bagger-all-peak-release`:

- `real-reconnect-evidence.json` — successful normal unmount/remount, matching
  launch/ready PID, database-open ordering, and verification-process exit.
- `real-reconnect-unavailable.png`,
  `real-reconnect-remounted-before-retry.png`, and `real-reconnect-ready.png` —
  blocking, remounted-but-not-retried, and visible ready-dashboard states.
- Corresponding `real-reconnect-*-accessibility.txt` captures include native
  window/PID information and OCR of the screenshots; Flutter's native AX tree
  did not expose its content, so Retry used keyboard activation.
- `real-reconnect-launch.log`, `real-reconnect-readback.json`, and
  `real-reconnect-source-hashes.json` — initialization, persisted-data
  preservation, and unchanged mounted-source evidence.

The temporary `packaged_reconnect_readback_test.dart` passed **1 test**, checking
the real packaged database and evidence after process exit. It remains outside
the committed deterministic suite. The earlier final-bundle **clean analysis,
2,165 passing tests / 5 skips, release build, bundle inspection, source flows,
cold graph bootstrap, and host-GDAL checks** remain valid; no application code
was changed for this reconnect verification. Changes remain uncommitted.

## Covers

- User Stories: 1-3
- Requirements: 1-2, 8-10, 13-14, 22-23, 28, 31-32
- Technical Decisions: 5-6, 12-13, 31
- Testing Strategy: 4-5, 16-17
- Interview Ledger: L1, L3, L4, L6, L8-L12

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
05-manifest-backed-peak-reconciliation.md
06-transactional-tasmap-updates.md
07-natural-features-mapping-store-refresh.md
08-coverage-qualified-route-graphs.md
09-lazy-polygon-display-failures.md
10-manifest-resolved-route-elevation.md
11-tool-manifest-resolver-and-bootstrap.md
