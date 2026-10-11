---
type: Spec
title: MacBook and Mac Mini Mutagen Development
---

## Problem

Peak Bagger has working copies under both `~/Development` and `/Volumes/Development`. The MacBook's home-directory copy is current, and the external development and services volumes are moving to the Mac mini. The user needs unfinished development work available on either Mac, with local editing, builds, and tests and the MacBook remaining the primary development machine. [L1, L2]

Two independently managed Git working trees cannot safely be treated as one continuously synchronized workspace. Peak Bagger also declares two package dependencies through absolute external-volume paths, which would prevent the intended local offline-build workflow after the drive moves. Its external Mapping data store is a runtime dependency and must be handled separately from source synchronization. [L2, L3, L5]

## Proposed Outcome

Provide one Mutagen working-file session for each of `peak_bagger`, `trip_routing`, and `flutter_map_tile_caching`. Each MacBook directory owns its Git repository; the corresponding mini directory is a source mirror with local dependencies and build outputs. Use automatic `two-way-safe` synchronization over SSH, explicit conflict handling, and a flush/check handover procedure. [L1, L2, L5, L6]

Use relative sibling package paths and local API-key configuration. Keep runtime Mapping access through SMB in the short term. Record the measured data footprint needed for later independent offline runtime without implementing that runtime change now. [L3, L4, L5, L7]

## User Stories

1. As the primary MacBook developer, I can work in the current home-directory checkouts, including offline editing and builds, after the development drive moves to the mini. [L1, L4, L5]
2. As a developer switching Macs, I can continue with the same saved unfinished source edits after synchronization finishes. [L2, L6]
3. As a developer on the mini, I can build and test locally and initiate Git operations against the MacBook-owned checkout over SSH when the MacBook is reachable. [L2]
4. As a developer working through network outages, I retain local edits, receive automatic synchronization on reconnect, and see incompatible changes reported for explicit resolution. [L6]
5. As a developer using keyed basemaps, I can build on both Macs with machine-local API-key files without having their values copied by ongoing source synchronization. [L7]
6. As a user preparing future offline runtime, I know exactly which current Mapping files are required and how much space they occupy, while using the mini's SMB share now. [L3, L4]

## Requirements

### Workspace layout and initial migration

1. Support these corresponding synchronization roots. `~` denotes the MacBook user's home directory; the external-volume paths are on the mini after relocation. [L1, L5]

   | Project | MacBook Git checkout | Mini working-file mirror |
   | --- | --- | --- |
   | Peak Bagger | `~/Development/mapping/peak_bagger` | `/Volumes/Development/mapping/peak_bagger` |
   | Trip Routing | `~/Development/mapping/trip_routing` | `/Volumes/Development/mapping/trip_routing` |
   | Flutter Map Tile Caching | `~/Development/mapping/flutter_map_tile_caching` | `/Volumes/Development/mapping/flutter_map_tile_caching` |

2. Seed synchronized working files from the current MacBook copies before enabling ordinary bidirectional synchronization. Treat this bootstrap authority as a migration rule, not a permanent preference for MacBook edits. [L1, L5, L6]
   - Before final bootstrap reconciliation and seeding, save edits and stop other source-writing activity in all three projects on both machines, including background agents, formatters, and code generators. Keep those writers stopped through baseline verification, session activation, and the first successful three-session flush/status check using the same readiness conditions required for handover. Migration operations may write the working files during this freeze. If verification or readiness fails, do not begin ordinary development; after success, resume source writers only on the selected development machine, subject to the remaining setup checks. [L1, L5, L6]
   - After inspecting and preserving unique mini work, establish the agreed in-scope baseline from the current MacBook copies. Keep preserved unique work outside the synchronization roots unless deliberately reconciled into the MacBook copies before final seeding. Account explicitly for stale mini-only source files, including files deleted on the MacBook, so they cannot propagate back as new additions. Verify matching in-scope paths and file contents at both endpoints before enabling ordinary bidirectional synchronization, while preserving excluded machine-local content. An additive copy alone does not establish this baseline. [L1, L2, L3, L5, L7]
3. Before replacing stale mini-side files or moving its Git metadata, inspect for unique commits, branches, stashes, and working-file changes. Preserve discovered unique work for deliberate reconciliation; do not silently discard it. Move mini-side `.git` directories outside all synchronization roots as recoverable migration backups rather than immediately deleting them. [L1, L2]
4. Do not overwrite mini-local credentials, databases, or service runtime state while seeding source mirrors. Generate each machine's dependencies and build outputs locally. Recreate stale Flutter/Xcode caches after relocating a project. [L3, L7]
5. Provide persistent, inspectable configuration for the three named sessions and document creation, inspection, flush, pause, resume, and conflict recovery. Reapplying setup must identify existing intended sessions rather than create duplicate active synchronization sessions for the same roots. Reuse a session only after comparing its project identity, effective endpoint roots, synchronization mode, and required exclusions with the intended configuration; recognizing its name alone is insufficient. If configuration differs, report the mismatch and stop setup for that project without silently replacing the session or creating a duplicate. Document deliberate reconciliation before replacement, preserving endpoint work and unresolved conflicts. Mutagen captures ignore settings at session creation; editing a configuration file alone does not update existing sessions. [L5, L6]
6. No development edits are made on the mini until migration, setup, and verification are complete. Migration operations and disposable verification probes remain part of setup; ordinary mini-side development begins only after completion.

### Git ownership and machine handover

1. Git repositories remain active only in the MacBook synchronization roots. Explicitly exclude `.git`, including Git metadata files used by worktrees, from all project sessions. Never synchronize repository internals. [L2, L5]
2. Commits, branch changes, resets, merges, and rebases execute in the corresponding MacBook checkout. The mini must not retain or recreate an independent Git repository inside a continuously synchronized mirror. [L2]
3. Document how to invoke Git from the mini over SSH to the corresponding MacBook checkout. If the MacBook is unreachable, report that Git is unavailable; local editing/building/testing remains possible, but there is no mini-side Git fallback. [L2]
4. Before switching development machines, save edits and stop source-writing activity in the mirrored workspace on both machines, including background agents, formatters, and code generators. Flush all three sessions and inspect their status. The handover is ready only when there are no pending synchronized changes, conflicts, connection errors, or other synchronization problems. A failed or unavailable session must be clearly identified; if readiness fails, do not hand over development. Keep source-writing activity stopped through the readiness check, then resume development only on the receiving machine, leaving the outgoing machine's source writers stopped. [L6]
5. Before Git operations that replace working files, such as checkout, reset, merge, or rebase, save edits and stop other source-writing activity in the mirrored workspace on both machines. Flush all three sessions so mini-originating edits reach the MacBook, and confirm the same readiness conditions required for handover; if readiness fails, do not proceed with the Git operation. Execute the operation in the MacBook checkout, then flush all three sessions and confirm readiness again before resuming development. Keep other source writers stopped through the Git operation and the subsequent flush/status check. This is a documented procedure and does not require a new locking system. Do not attempt to align a second Git branch or index on the mini. [L2, L6]
6. This arrangement supports sequential handover of one logical working-file workspace, not concurrent development of different branches in the mirrored roots. Mini editor/agent features requiring local repository metadata are not provided by the mirror. [L2]
7. After setup, before staging or committing mini-originating work over SSH, save edits, stop source-writing activity in the mirrored workspace on both machines, flush all three sessions, and confirm the same readiness conditions required for handover. If readiness fails, do not proceed with staging or committing. Keep source-writing activity stopped until the Git operation finishes; this is a documented procedure and does not require a new locking system. Read-only Git commands such as `status`, `diff`, and `log` may run without a mandatory flush, but document that they describe the MacBook checkout and may omit pending mini edits. Flush/check first when an up-to-date view of those edits is required. [L2, L6]
8. Provide an operational guide describing MacBook-owned Git, mini-to-MacBook SSH Git commands, and the source-write freeze and flush/status procedures. When producing that guide, add a short supersession note or link in `docs/mac-mini-development-drive-migration.md`: preserve its historical discussion, but identify its mini-owned Git example and ownership questions as superseded by L1/L2 and this Spec. [L1, L2, L6]

### Synchronization behavior and scope

1. Use one `two-way-safe` session per project over SSH. Start the controlling Mutagen daemon automatically at MacBook login and retain the configured sessions across restarts. The mini needs reachable SSH/Remote Login and Mutagen's remote agent, not a second controlling daemon for these sessions. [L5, L6]
2. Saved, in-scope changes from either endpoint propagate while connected. During disconnection, changes remain in the local working tree. Synchronization resumes automatically when connectivity returns. Do not claim an offline edit has reached the other endpoint. [L6]
3. Propagate ordinary in-scope deletions. Report incompatible edits, including edit/delete conflicts where Mutagen detects them, for explicit resolution; never automatically select a winner or reset a session to suppress a conflict. Unconflicted paths may continue synchronizing according to Mutagen behavior. [L6]
4. Synchronize source, tests, documentation, workflow documents, UI assets, shared configuration examples, relevant lockfiles, and generated source files required by the checked-in code. In particular, ObjectBox model metadata and generated Dart source are source-workspace content; they are not live database files. [L5, L7]
5. Configure explicit Mutagen ignore rules. Do not assume Mutagen interprets `.gitignore`, and do not blanket-exclude every Git-ignored path: a locally needed lockfile or development source can still belong in the shared working-file workspace. [L5, L6]
6. Exclude machine-local/generated dependency and runtime artifacts as applicable in all three projects, including: [L3, L5, L6, L7]
   - `.git`, `.dart_tool`, `build`, coverage output, `.pub`, `.pub-cache`, `.cache`, Python caches, `node_modules`, and Flutter-generated machine-local plugin metadata.
   - Platform dependency/build directories such as `macos/Pods`, `macos/Flutter/ephemeral`, equivalent directories in examples, Xcode user state, and machine-local SDK paths.
   - Live ObjectBox `data.mdb`/`lock.mdb` files, logs, process identifiers, temporary files, and `.DS_Store`.
   - Separately installed ObjectBox test libraries under `flutter_map_tile_caching`'s session-relative `test/lib/`; these are machine-local native dependencies.
   - Peak Bagger Local Topo generated payloads under `local_topo/tasmania/input`, `output`, `runtime`, and temporary test-output directories; keep their source-controlled directory placeholders where applicable.
   - `dart_defines.local.json`.
7. Keep Local Topo source/configuration/styles/tests in source scope, while leaving generated service payloads owned by the mini's service environment. Do not synchronize Docker/container storage, the Mapping data store, or unrelated projects through these sessions. [L3, L5]

### Local builds and API-key configuration

1. Replace Peak Bagger's package paths with exactly `../trip_routing` and `../flutter_map_tile_caching`. Preserve sibling layout on both Macs. Package resolution must no longer require `/Volumes/Development` on the MacBook. [L5]
2. Install SDKs, packages, native dependencies, and caches on each machine. Offline builds are supported after dependencies have been installed locally; installing missing dependencies still requires their normal network/source availability. Document the online provisioning steps and the build command needed to reproduce the verified MacBook offline build. [L4, L5]
3. Keep `dart_defines.local.json` excluded from both Git and Mutagen. If the mini lacks a usable copy, seed it once from the MacBook over SSH. Preserve an existing usable mini copy; report an invalid existing copy for deliberate correction rather than overwrite it automatically. [L7]
4. Synchronize `dart_defines.example.json` with its `TRACESTRACK_API_KEY`, `TRACESTRACK_REFERER`, and `MAPY_CZ_API_KEY` field examples. Do not print real key values in commands' diagnostic output, docs, or configuration artifacts. [L7]
5. Inspect and document the role and compatibility on both Macs of Peak Bagger's Git-tracked `lib/libobjectbox.dylib` before deciding whether it remains synchronized or requires machine-local provisioning. Do not remove it or blanket-exclude native libraries without this inspection. Independently install the ObjectBox libraries required by `flutter_map_tile_caching/test/general_test.dart` under that package's `test/lib/` on each Mac; `pub get` alone does not supply this test prerequisite. Keep those installed test libraries excluded from Mutagen and verify native-library readiness before running the relevant tests on either machine. [L5]

### Mapping runtime access and offline inventory

1. Mount the mini's Services share over SMB so the MacBook retains the exact runtime path `/Volumes/Services/Mapping`. The mini reads its directly attached store. Keep Mapping source data outside project Mutagen sessions and keep each machine's ObjectBox database local. [L3]
2. Preserve the current app startup and failure behavior. Preflight reads the manifest pair, checks every region-manifest dataset reference for existence/readability, and loads required regional/basemap polygon geometry. If unavailable, the app reports affected paths and offers `Retry` and `Quit` before opening the normal ObjectBox-backed UI. An existing local database does not bypass this preflight. [L3, L4]
3. Short-term offline support covers source editing and builds, not launching the full app without its Mapping store. Do not create a local Mapping replica or add a configurable store path in this change. [L4]
4. Preserve the inventory below as a measured planning baseline, with bytes as the authoritative size units. These are the 25 files referenced by the inspected manifests, totaling **4,255,657,108 bytes (3.963 GiB)**. Copying directories wholesale is not equivalent: they contain additional maintainer data. [L4]

   | Store-relative file | Bytes |
   | --- | ---: |
   | `region_manifest.json` | 12,819 |
   | `Polygons/manifest.json` | 288 |
   | `Polygons/italy-nord-est.poly` | 28,225 |
   | `Polygons/friuli-venezia-giulia-mainland.poly` | 3,319 |
   | `Polygons/friuli-venezia-giulia-islet.poly` | 127 |
   | `Polygons/italy-nord-ovest.poly` | 15,515 |
   | `Polygons/new-south-wales.poly` | 27,887 |
   | `Polygons/slovenia.poly` | 10,462 |
   | `Polygons/croatia.poly` | 17,654 |
   | `Polygons/tasmania.poly` | 271 |
   | `Peaks/tasmania-peaks.json` | 247,376 |
   | `Peaks/new-south-wales-peaks.json` | 468,342 |
   | `Peaks/italy-nord-est-peaks.json` | 2,520,279 |
   | `Peaks/italy-nord-ovest-peaks.json` | 2,706,776 |
   | `Peaks/slovenia-peaks.json` | 2,391,123 |
   | `Peaks/croatia-peaks.json` | 2,758,502 |
   | `Highways/tasmania-highways.json` | 223,487,946 |
   | `Highways/friuli-venezia-giulia-highways.json` | 96,506,727 |
   | `Highways/veneto-highways.json` | 123,275,043 |
   | `Highways/slovenia-highways.json` | 706,365,113 |
   | `Features/tasmania_natural_features.json` | 82,695,273 |
   | `Maps/tasmap50k.csv` | 9,856 |
   | `DEM/Elvis/elvis_runtime_10m.tif` | 2,322,234,062 |
   | `DEM/tasmania_dem_25m.tif` | 284,292,791 |
   | `DEM/cop30_hh.tif` | 405,581,332 |

5. Communicate transfer feasibility: the full runtime set is practical to transfer, non-DEM files total approximately 1.16 GiB, and the non-highway/non-DEM subset is approximately 89.6 MiB. The MacBook had approximately 120 GiB available at inspection. These subsets alone do not satisfy startup while omitted files remain declared in the manifests. [L4]
6. Later independent offline runtime must address access to a local copy at the app's accepted root, offline basemap tiles, personal app data/settings and needed GPX files, and locally installed GDAL/PROJ for elevation sampling. A mini-only Local Topo HTTP service is unavailable while disconnected. The raw ELVIS source tree, topo-build DEM, raw theLIST inputs, Overpass service data, and Docker state are not part of the current app runtime file set. [L4]

## Technical Decisions

- Use native Mutagen sessions and their status/flush operations as the synchronization boundary; do not introduce application-level source synchronization or a second Git authority. Use discoverable persistent session names identifying each project. [L2, L5, L6]
- Use the MacBook as the controlling endpoint and Git owner. SSH connections to the mini and, for mini-initiated Git, back to the MacBook are prerequisites to validate during setup. An absent volume or SSH connection is an actionable setup/synchronization failure, not an invitation to create a substitute empty directory or repository. [L1, L2, L3]
- Maintain explicit project-aware exclusions, preserving required generated source and lockfiles while excluding runtime data and machine-local caches. Check all three projects and their examples when applying exclusions. [L3, L5, L7]
- The current Mapping startup contract is stricter than an optional elevation feature: all three declared DEMs must be readable even though `route_elevation_sampler.dart` currently selects the ELVIS runtime source for Tasmania. Do not remove declared files to shrink the offline footprint without a separately approved runtime-contract change. [L4]
- Configuration-file placement, login-start mechanism, and SSH aliases may follow the installed Mutagen version and existing user setup. They must support the documented paths, three sessions, repeatable setup, and automatic reconnection without embedding secrets. [L5, L6, L7]

## Testing Strategy

- Prefer temporary local endpoint directories as the Test Seam for synchronization verification. Test representative working files, required generated source, excluded API-key/database/cache files, ordinary deletions, and a same-file conflict under `two-way-safe`. Never use a live database or user source file to provoke a conflict. [L3, L5, L6, L7]
- In disposable endpoints, verify initial migration from a stale mini tree containing a mini-only source file previously deleted on the MacBook, a shared file with differing contents, unique work requiring preservation, and excluded machine-local files. Confirm unique work is recoverable outside the roots or deliberately reconciled into the MacBook baseline, in-scope paths and contents match before session activation, stale files do not return to the MacBook, and excluded local files remain intact and do not propagate. Verify other source writers remain stopped through final reconciliation, seeding, activation, and the first successful three-session flush/status check; failed baseline verification or readiness must block ordinary development. [L1, L2, L3, L5, L6, L7]
- For each real session, verify a disposable source-workspace change propagates MacBook to mini and mini to MacBook, then remove the probe and confirm cleanup. Confirm `.git` stays local to the MacBook and that excluded machine-local files do not propagate. [L2, L5, L6, L7]
- Verify that reapplying unchanged setup reuses sessions with matching effective configuration and creates no duplicates. Exercise configuration drift in disposable sessions and confirm that setup identifies mismatched roots, synchronization mode, or required exclusions and stops the affected project without replacing the session or losing endpoint work/conflict state. [L5, L6]
- Verify login startup/persistent sessions, connection-loss status, offline edits retained on the source endpoint, and automatic catch-up after reconnect. Exercise incompatible offline edits in disposable endpoints and confirm explicit conflict reporting without an automatic winner. Record incomplete environmental checks as pending, not passed. [L6]
- Verify that handover flush/status checks cover all three sessions and fail readiness if any session is disconnected or conflicted. Verify that source writers remain stopped through the handover readiness check and resume only on the receiving machine after success. Verify mini-initiated Git targets the MacBook repository and reports an unavailable MacBook without creating a local repository. In disposable endpoints and a temporary Git repository, verify that a mini-originating edit reaches the Git-owning endpoint before remote staging/commit and before a file-replacing Git operation, such as checkout. Confirm failed readiness prevents those operations, and keep other source writers stopped through the file-replacing operation and its subsequent three-session flush/status check before resuming development. Keep this verification separate from user repositories. [L2, L6]
- Run package resolution and appropriate Flutter/Dart analysis, existing tests, and a macOS build on both machines after dependency-path changes. Verify native ObjectBox library readiness, including FMTC's locally installed `test/lib/`, before running the relevant tests on each Mac. Confirm that FMTC's installed test libraries do not propagate and record the compatibility check and chosen synchronization/provisioning treatment for Peak Bagger's tracked dylib. Reuse existing package tests; do not add widget tests for an operational synchronization setup. [L4, L5]
- After online provisioning of SDK artifacts, Dart packages, and native dependencies, verify a MacBook macOS build with the external development drive absent and all network access unavailable, including access to the mini. Use a saved source change requiring compilation to demonstrate a rebuild rather than merely launching an existing app; retain locally installed dependencies and caches. Record the provisioning steps, build command, and outcome without exposing API-key values. This checks offline building, not full app startup without the Mapping store. If the environmental check cannot be completed, record it as pending, not passed. [L4, L5, L7]
- Verify online runtime startup through the expected SMB path and preserve the existing unavailable-store `Retry`/`Quit` behavior. Existing Mapping filesystem injection and `test/services/mapping_data_store_test.dart` / `test/widget/startup_shell_test.dart` provide Test Seams if startup behavior must be regression-checked; runtime changes and new tests are not required by this Spec. `test/widget/mapping_store_failure_dialog_test.dart` covers the separate in-app operation-failure `Retry`/`Dismiss` dialog, not the startup contract. [L3, L4]
- Recheck referenced files and sizes before any later offline copy. Verify the inventory count and byte sum without copying the entire Mapping store or treating a staged subset as an independently runnable app. [L4]

## Out of Scope

- Independent Git repositories, offline commits on the mini, simultaneous different branches in these mirrors, and syncing Git metadata. [L2]
- Independent offline app runtime, local Mapping replication, store-root configuration changes, automatic SMB/local-store switching, or transferring the measured runtime dataset now. [L3, L4]
- Synchronizing or merging personal ObjectBox databases, app settings, GPX collections, tile caches, running containers, or bulk maintainer datasets. [L3, L4]
- Extending synchronization to all of `/Volumes/Development` or unrelated projects. [L5]
- Committing, pushing, creating Work Items, or implementing the setup as part of writing this Spec.

## Open Questions

- What SSH aliases and credentials should the existing machine configuration supply for mini access and reverse MacBook Git access? Discover and validate them during implementation; the ownership/layout decision is resolved.
- What SMB sharing/mount automation already exists for Services? Inspect it during implementation and preserve the exact required runtime mount path.

## Follow-Ups

- Design independent offline MacBook runtime separately: local Mapping snapshot placement and refresh ownership, offline tile coverage, and personal app-data availability. The measured 3.96 GiB runtime set makes a selective local replica feasible, but that future design must resolve runtime path selection and behavior when sources are stale or unavailable. [L4]

## Notes

- Relevant source/context: `docs/mapping-data-store.md`, `README.md`, `GLOSSARY.md`, `pubspec.yaml`, the three projects' `.gitignore` files, `local_topo/tasmania/.gitignore`, `lib/main.dart`, `lib/services/mapping_store_core.dart`, `lib/services/route_elevation_sampler.dart`, and `lib/services/objectbox_store_directory.dart`.
- `docs/mac-mini-development-drive-migration.md` records historical advice. Its mini-owned Git example and unresolved ownership questions are superseded by L1/L2 and this Spec's MacBook-owned arrangement; use the operational guide produced during implementation for the selected workflow.
- The actual Mapping manifests were inspected on the attached Services volume before relocation. Measurements reflect the files present at interview time; the entire Mapping directory occupied approximately 375 GiB, largely maintainer DEM data.
- Both inspected `trip_routing` copies were clean at commit `7491846`. Both `flutter_map_tile_caching` copies were at commit `022bbe0` with identical tracked working-tree diffs. This does not substitute for checking unique branches, stashes, staged work, or later changes before migration.
- No synchronization configuration, Git metadata relocation, package-path edits, SMB changes, or Mapping transfers were performed during the interview or Spec creation.
