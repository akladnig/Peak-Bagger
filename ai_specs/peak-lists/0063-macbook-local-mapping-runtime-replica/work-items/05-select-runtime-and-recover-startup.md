---
type: Work Item
title: Deliver machine-local runtime selection, transactional activation, and startup recovery
parent: ../spec.md
---

## What to build

Deliver the Flutter startup vertical slice from machine-local configuration through generation readiness, atomic selection/session pinning, ready dependency initialization, and retryable unavailable UI. Use the concrete selected generation through `MappingCatalog.rootPath` for every Mapping-dependent startup, import/update, and live-runtime read.

A ready MacBook session is independent of SMB, the mini, and synchronization. Candidate arrival does not redirect a running session; activation happens at launch or a retry boundary while normal initialization is still withheld.

## Required context

- Read the parent Spec, ledger, Item 01's versioned eligibility/selection/ownership contracts, and Item 04's independent validated generations. Preserve their exact metadata version compatibility and generation binding.
- `lib/main.dart` constructs `MappingStoreStartupCoordinator` before ready dependencies. `lib/startup_shell.dart` defines preflight/catalog ordering, state transitions, ready builder, unavailable controls, platform gate, and quit callback.
- `lib/services/mapping_data_store.dart` exposes Application Support cache resolution and Flutter adaptation; `lib/services/mapping_store_core.dart` accepts `rootPath`; `MappingCatalog.rootPath` and `lib/services/mapping_store_resolver.dart` feed validated consumers. `lib/services/objectbox_store_directory.dart` illustrates machine-local support storage, not a replica payload location to reuse indiscriminately.
- Inspect all catalog consumers, especially lazy `lib/services/route_elevation_sampler.dart` opens, peak imports, route-graph coverage/import coordinators, Natural Features, and TasMap updates. Maintainer tools keep canonical-source authority independently of app configuration.
- Test anchors: `test/widget/startup_shell_test.dart`, `test/services/mapping_data_store_test.dart`, `test/providers/route_elevation_mapping_test.dart`, `test/harness/route_elevation_fixture.dart`, `test/robot/mapping_store_failure_robot.dart`, and `test/robot/route_graph_mapping_journey_test.dart`. The in-app `Retry / Dismiss` failure dialog is distinct from startup `Retry / Quit`.
- Preserve existing stable startup keys where appropriate, using deterministic configuration/filesystem/activation/startup/quit seams and fake external services for robot journeys. Consult `pubspec.yaml` if dependencies change.
- Item 06 adds controller cleanup; establish process-lifetime session/native ownership here so cleanup can honor it. Item 07 installs readers/writers with version compatibility; do not require app startup to install or dispatch the controller.

## Acceptance criteria

- [x] Read a separate per-machine app configuration under the app's Application Support directory before preflight and ready dependency initialization. Support **replica** mode selecting a local replica base directory and **canonical** mode selecting the mini's directly attached `/Volumes/Services/Mapping`. Exact filenames may follow conventions; document the actual schema/paths without putting this configuration in `dart_defines.local.json`.
- [x] Absent configuration defaults to replica mode under local Application Support. Invalid configuration yields a local configuration diagnostic with `Retry / Quit` and its configuration path; it never authorizes canonical/SMB fallback. Configuration and replica directories remain outside source synchronization roots.
- [x] Replica mode requires local storage. Canonical mode must not authorize MacBook SMB runtime access; explicit mini canonical selection retains the attached-store behavior and maintainer tool source authority is unchanged.
- [x] Remember the existing active selection. Check a pending candidate's generation-bound eligibility/version support and normal local preflight/catalog loading before committing it; only then atomically select and pin its concrete immutable directory. Do not repeatedly resolve a mutable pointer as the runtime root.
- [x] Candidate eligibility/preflight/catalog failure or selection-publication failure rejects/reports that candidate and attempts the existing active generation. If active readiness fails, attempt the retained recovery generation when present. Withhold normal ready/ObjectBox initialization until one permitted generation passes readiness.
- [x] Interrupted selection recovers a complete old or new record, never partially written metadata; retain enough local recovery state for the previous valid selection. Pinning/selection coordination cannot expose an unprotected generation to concurrent launch/cleanup races.
- [x] Pin the concrete generation for the full app session, including later imports and lazy DEM opens. Use process-lifetime protection that releases after a crash, with explicit native dataset/handle ownership and release. Any native handle still in use protects its generation; pending candidates cannot mutate/delete/replace the running session's DEM or root.
- [x] Propagate the concrete directory through `MappingCatalog.rootPath` and existing read boundaries to all Mapping-dependent startup, live sampling, and app import/update reads. Runtime does not probe canonical SMB for readiness/freshness, dispatch/wait for synchronization, or silently fall back when replica data is absent/invalid.
- [x] Preserve source schema, region/coverage resolution, declared fingerprints, containment, manifest pair/all declared dataset checks, required polygon geometry, and startup ordering. Existing ObjectBox/caches do not bypass preflight; all declared DEMs remain required.
- [x] When no permitted replica passes readiness, show exact heading **`Mapping runtime replica unavailable`**, affected local paths, and **`Retry` / `Quit`**. Display the selected local root, or configuration path when selection fails, instead of hard-coded `/Volumes/Services/Mapping`. Explain unfinished initial synchronization only when that is the cause; distinguish configuration and validation failures.
- [x] `Retry` rereads local configuration and executes the same transactional launch/readiness sequence. A newly complete validated candidate can activate at this boundary and continue normal initialization; failed retry remains on the explanatory screen with updated diagnostics/paths. `Quit` invokes the existing startup-shell callback.
- [x] Retry/checking work is visibly in progress with no duplicate concurrent startup attempts. Path lists remain scrollable; controls are keyboard-accessible and reachable at enlarged text scale using established widget conventions. Preserve the macOS-only platform gate.
- [x] A valid active replica starts despite unavailable mini, disconnected Mutagen, or a rejected pending update. Do not claim the replica contains the latest upstream data. Canonical mini failures retain **`Mapping data store unavailable`** behavior.
- [x] ObjectBox or other ready-initialization failures retain exact **`Initialization failed`** behavior and do not automatically roll back Mapping selections. Keep configuration, eligibility/selection/session records, protection, and logs separate from immutable dataset payloads; the app may write local metadata but not Mapping contents.
- [x] Use behavior-first red/green/refactor for configuration, selection, publication, startup state, and async-result logic. Unit/coordinator tests cover absent/invalid config, canonical mode, exact eligibility binding, candidate/preflight/publication fallback, active→recovery, interrupted atomic selection, concurrent pinning, no premature ready/ObjectBox work, and no generation rollback on ready-initialization failure.
- [x] Widget tests assert exact UI text/paths, pending/no duplicate retry, failed/recovered retry, callback Quit, keyboard actions, enlarged-text scrollability, and platform/error preservation. An existing valid replica starts with all remote access configured to fail.
- [x] Provider tests assert the selected generation reaches the DEM opener and late imports, including after another generation becomes pending/selected for another session. Keep source errors visible/retryable without hidden SMB reads. Reuse `FakeDemFileSystem`, `FakeDemDatasetOpener`, and `LookupDemDataset`.
- [x] Extend stable-key robot/widget journeys for unavailable startup → synchronization-ready retry → normal UI using deterministic fixtures/seams and fake basemap/external services. Run focused startup/service/provider/robot tests and access inventory/direct-I/O guards; document local configuration, selection, and failure recovery.

## Covers

- User Stories: 1, 4, 5.
- Requirements — Canonical ownership and local runtime access: 1–4, 6.
- Requirements — Automatic synchronization and activation: 4, 6–7 (launch eligibility, pinning, and failure behavior).
- Requirements — Generation retention and cleanup: 1–2 (session/native protection; controller cleanup in Item 06).
- Requirements — Startup and recovery behavior: 1–6.
- Requirements — Route-point behavior and performance: 5 (selected-source error preservation).
- Technical Decisions: 1–5.
- Testing Strategy — Deterministic automated coverage: TDD default; atomic selection service/unit tests; startup widget/coordinator coverage; selected-path provider/elevation tests; late-import/lazy-open generation tests; startup journey coverage.
- Interview Ledger: L2, L3, L4, L5.

## Blocked by

- [04-capture-replicas-and-publish-eligibility.md](04-capture-replicas-and-publish-eligibility.md)

## Implementation and verification — completed 2026-10-13

- `MappingRuntimeLauncher` reads strict Application Support `mapping-runtime.json`
  before preflight/ready dependencies. Replica is the absent-config default;
  canonical requires the exact attached store. Kernel `MNT_NOWAIT` inspection
  rejects network mounts without dataset probing; invalid config reports its path.
- `MappingReplicaRecords` consumes Item 04's exact small-metadata chain, supported
  schema/profile/release identities and successful operation witness, readonly
  independent generation boundaries and exact catalog/inventory path equality.
  No bulk hashing, transport dispatch or payload writes are embedded in startup.
- `MappingRuntimeSelector` validates pending before atomic commit; rejects/reports
  pending failures and tries active/recovery. Complete old/new journals survive
  interruption; session publication and selection share the retained cleanup lock.
  Superseded eligibility cannot be reactivated as a new pending update.
- Darwin `flock` session protection interoperates with Python and releases on
  process death. Native GDAL opens/resources retain the same generation pin until
  explicit closure; provider disposal awaits pending opens. Late DEM/import tests
  keep the old concrete catalog root after another launch selects an update.
- Startup preserves macOS gating, exact replica/canonical/initialization headings,
  single-flight visible checking, reread-on-retry, callback Quit, keyboard actions,
  enlarged-text scrolling and readiness before ObjectBox. Initialization failure
  is terminal for that attempt and never rolls back Mapping.
- [Operating configuration, recovery and Item 06/07 handoffs](../../../../docs/mapping-runtime-startup.md)
  document actual paths/schemas/ownership, compatibility and journal protection.
  Runtime access inventory/direct-I/O guards cover only the new local metadata
  adapter; canonical maintainer authority remains independent.
- Red/green cycles demonstrated missing configuration/selector/ownership APIs,
  unsupported/stale record acceptance, publication/retry concurrency failures,
  post-rename interruption, mutable/linked generations, missing native release,
  superseded-candidate reactivation and enlarged-text overflow before fixes.
- Focused 14-file run: **109 passed**, native capture test hit its existing
  **3-minute timeout** during combined work. Isolated sleep-inhibited native
  Python → Dart → GDAL → app reader integration: **passed in 2m25s**.
- Full `caffeinate -i flutter test --no-pub --reporter expanded`: **2,249 passed,
  5 existing skips**, **10m33s**, including the native integration and both robot
  journeys. `flutter analyze --no-pub`: **no issues**. `git diff --check`: passed.
- New verification uses disposable data, fake/controlled external services and
  native process/lock fixtures, not user Mapping/SMB/SSH/API-key inputs. Real
  installations, controller pruning, physical power-loss testing and performance
  ceilings remain the explicitly scoped later work items.

### Journey Verification
- Journey: Unavailable replica → synchronized readiness → normal dashboard
- Verification command(s): `flutter test --no-pub test/robot/mapping_runtime_startup_journey_test.dart`
- Required seams/selectors: controlled readiness, in-memory repositories/preferences, stable startup Retry/Quit and `dashboard-card-elevation` keys; no external tiles with empty tracks
- Result: `pass`
- Remaining risk: Readiness is deterministic in the widget journey; native activation is covered separately. Installed transport and live performance remain commissioning work.

### Journey Verification
- Journey: In-app route-source failure → dismiss → coverage retry
- Verification command(s): `flutter test --no-pub test/robot/route_graph_mapping_journey_test.dart`
- Required seams/selectors: existing fake coverage/planner and stable failure/route-planning keys
- Result: `pass`
- Remaining risk: Native route performance is not measured by fake widget journeys; in-app Retry/Dismiss remains distinct from startup Retry/Quit.
