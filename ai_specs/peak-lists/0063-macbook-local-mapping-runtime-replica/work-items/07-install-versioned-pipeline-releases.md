---
type: Work Item
title: Install versioned pipeline releases independent of source workspaces
parent: ../spec.md
---

## What to build

Provide installation/inspection/upgrade/recovery tooling for complete versioned controller and source-preparation releases on their respective machines. Executable artifacts, helpers, and dependencies live outside changing source-workspace synchronization roots and are pinned for each invocation.

Implement atomic release selection and supported metadata-version combinations so upgrades preserve retained generations and in-flight work. Item 08 installs scheduled execution using these release primitives; this item does not need automatic refresh to validate installed-artifact lifetime and compatibility.

## Required context

- Project-root-relative `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS). No pending dimensions affect this installation/metadata work.
- Read the parent Spec, ledger, and Item 01's reviewed metadata/ownership compatibility contracts. Use Item 03's source preparer and Item 04's capture/validation implementation as installed executable stages.
- `tool/mutagen_workspace.py`, `tool/mutagen-workspace.json`, `docs/two-mac-mutagen-bootstrap.md`, `docs/two-mac-mutagen-operations.md`, and `docs/two-mac-local-builds.md` document the three source sessions and existing setup/provisioning conventions. Reuse suitable inspection patterns without consulting their handover gate during refresh.
- The installed source preparer is reached through existing SSH alias **`mini`**. Local paths/SSH/session configuration are non-secret, but credentials remain in normal SSH authentication, never in release files/logs/artifacts.
- App reader compatibility applies to Item 05's eligibility/selection/preflight path. Do not require app startup to execute/check remote pipeline binaries or install dependencies.
- Inspect executable dependencies actually used by each stage; repository-relative imports, fixture reads, package/runtime resolution, and helpers cannot reach back into a changing checkout during installed invocations. Consult `pubspec.yaml` and tool dependency declarations when packaging Dart/Flutter-dependent stages.
- Tests: disposable installed release trees and deterministic process/ownership/selection seams; `tool/tests/test_mutagen_workspace.py` and `tool/tests/test_mutagen_operations.py` provide existing tooling-test conventions. Retention integration must support operations that survive controller/SSH-client exit, not just a parent invocation PID.

## Acceptance criteria

- [x] Install complete versioned controller artifacts on the MacBook and source-preparer artifacts on the mini, including their executable dependencies, outside all source-workspace synchronization roots and canonical Mapping payloads. Document actual installed paths and prerequisites.
- [x] Scheduled/maintainer invocations execute installed releases and resolve helpers/dependencies from those releases or stable documented machine dependencies; never execute code or resolve executable dependencies from changing working-file checkouts.
- [x] Install/upgrade uses atomic release selection. Pin the selected release and helpers for the entire invocation; a pointer change cannot mix old/new helper versions within that invocation.
- [x] Retain each release/helper set while an invocation or surviving remote preparer/local child owns it. Controller exit, SSH-client termination, source transfer, or a new selected release does not authorize deleting another operation's binaries; ownership ends only through valid completion/reconciliation evidence.
- [x] Source edits, partial source delivery, paused source sessions, and machine handover do not interrupt installed refresh stages or require the existing source-workspace readiness/handover gate. Keep source session identity/scope/ownership intact.
- [x] Expose installed controller/source-preparer release identities through setup/inspection and stage logs, including the identity pinned to an in-flight operation and any selected upgrade.
- [x] Version source-completion/integrity, durable-receipt, and local eligibility/selection records under Item 01's reviewed contracts. Verify and document supported controller/source-preparer/app-reader combinations before applying new artifacts.
- [x] Compatible upgrades preserve readability of retained active/recovery generations and recoverable operations. Incompatible artifacts fail closed with actionable version diagnostics and cannot mutate or delete active/recovery generations; do not silently rewrite protected old generations into a new format.
- [x] Setup/inspection is repeatable for matching installed releases, reports drift/incomplete installation, and preserves the last usable atomic selection on failed publication. No required metadata/dependency is placed inside Mutagen incoming staging.
- [x] Use behavior-first red/green/refactor for new installation publication/selection/async-result logic. Disposable tests cover partial installation, failed atomic upgrade, old/new invocation pinning, helper/dependency versions, release retention during surviving children, and supported/unsupported metadata combinations.
- [x] Test installed stages while their checkout is edited, partially delivered, or unavailable and source sessions are paused/handed over. Tests demonstrate no source-workspace-gate consultation and no dependency resolution into a changing checkout, with retained generations readable after compatible upgrades and intact after incompatible rejection.
- [x] Automated tests use disposable data/fake process transport and normal test seams, not live canonical mutations, SSH credentials, API keys, or user Mapping files. Run focused release/compatibility tests and record results.
- [x] Document compatible installation, upgrade, inspection, release retirement, interruption recovery, and safe rollback/reselection procedures; include how operation ownership protects installed versions until real completion.

## Covers

- User Stories: 3.
- Requirements — Automatic synchronization and activation: 9–10 (installed version lifetime and ownership integration; single-flight scheduling in Item 08).
- Technical Decisions: 3, 5–7.
- Testing Strategy — Deterministic automated coverage: TDD default where applicable; synchronization/runner installed-artifact, upgrade, pinned-dependency, metadata compatibility, and source-handover tests; surviving-operation release protection.
- Testing Strategy — Live performance and operating evidence: installed version/upgrade procedures (live commissioning in Item 11).
- Interview Ledger: L4.

## Blocked by

- [04-capture-replicas-and-publish-eligibility.md](04-capture-replicas-and-publish-eligibility.md)

## Implementation and verification — completed 2026-10-13

- `tool/mapping_releases.py`: complete required-stage manifests, AOT/native-helper
  packaging, dependency/artifact SHA-256 inspection, external immutable installation,
  compatible peer/retained-record preflight, atomic old/new selection recovery,
  invocation lease inheritance, explicit reconciliation and safe retirement.
- `tool/mapping_release_launcher.py`: stable installed manager dispatch, verification
  and pre-import lifetime pinning. Source bridge/local validator select installed
  AOT commands and propagate the invocation flock through detached supervisors and
  native children. Publisher fixtures/shim/scratch are independent of checkouts.
- `MappingReplicaRecords` reads strict local v1 reader registration through the
  existing metadata I/O owner. No new app direct I/O, remote probe, binary execution,
  payload hashing or ObjectBox/Riverpod/GoRouter substitution. ADS-1.0 and Desktop
  wide apply; no layout change depends on pending dimensions or proposes exceptions.
- [Installation/upgrade/recovery guide](../../../../docs/mapping-pipeline-releases.md),
  source operations/build links and narrowly scoped access inventory/guard updated.
- Behavior-first failures demonstrated missing install/selection/pin/reconciliation/
  packaging APIs, unsupported retained schemas, checkout-dependent detached capture,
  post-rename interruption, missing required artifacts and app UUID-registration
  rejection before their implementations. Eleven disposable release tests cover
  independent helpers (v1/v2), dependency drift, child lifetime and real detached
  capture. Source unavailability/partial delivery stands in for paused/handover
  source transport; no live source sessions or readiness gate were manipulated.
- The real AOT validator/GDAL test uses generated tiny rasters and all reviewed
  malformed-payload categories. Retained generations survive compatible upgrades
  and byte-for-byte incompatible rejection. Automated tests use no live canonical
  data, SSH credentials or API keys.
- Focused release suite: **11 passed**; three-file installed validator/reader/I/O
  guard Flutter run: **19 passed**. Full Python tooling suite: **100 passed**.
- `flutter analyze --no-pub`: **no issues**. Full
  `caffeinate -i flutter test --no-pub --reporter expanded`: **2,254 passed,
  5 skipped**, **3m17s**. Existing skipped checks remain unverified.
  `git diff --check`: passed.

### Actual machine installation

Both machines use `/Users/adrian/.local/share/peak-bagger-mapping-releases`, outside
the three source roots, canonical Mapping and incoming payloads. Stable dispatchers
are installed at `<base>/mapping_release_launcher.py`; current immutable releases:

| Machine/role | Selected release | Payload and host dependency inventory |
| --- | --- | --- |
| MacBook controller | `c741996a-6c8b-434a-8290-cd48e87845bd` | **6** artifacts, **1,172** dependency identities; Python **3.13.9** at `/opt/homebrew/anaconda3/bin/python3.13`; existing GDAL **3.13.3_3**, PROJ **9.9.0** |
| mini source preparer | `a8ad8ef2-5939-443e-8e32-37e73c56ad42` | **18** artifacts (including eight AOT executables), **1,057** dependency identities; existing uv Python **3.15.0** via `/Users/adrian/.local/bin/python3.15`; installed GDAL **3.13.3_5**, PROJ **9.9.0** and dependencies |

- MacBook data base is
  `/Users/adrian/Library/Application Support/com.example.peakBagger/MappingRuntimeReplica`;
  mini source state/export base is `/Users/adrian/.local/share/peak-bagger-mapping-source`.
  Initial replica transfer/eligibility is not claimed. Metadata/profile remain v1;
  mutual release support and app reader `e442ea38-fc1d-4ca0-b07d-223b01df6c35` verified
  before selection. Installed inspection reports both selections complete.
- Source bundle delivered through alias `mini`, sealed against the mini's actual
  dependencies and installed atomically. Missing GDAL/PROJ initially failed closed;
  `brew install gdal proj` supplied local prerequisites. Python 3.9 at `/usr/bin`
  was not used. Use `-B` for uninstalled bundle commands to prevent extra bytecode
  caches; unexpected generated caches correctly fail exact artifact-set inspection.
- Installed status commands passed on both hosts, exposing pinned release/operation
  identities and no source-workspace gate. Ended read-only inspection leases were
  explicitly reconciled only after ownership/dispatch locks were free.
- Mini installed AOT/shim execution works: ELVIS usage retains its existing exit-1
  unsupported-`--help` contract; `non_store_paths /tmp` succeeds. Compiled
  `mapping_store provision-or-verify` resolves **installed fixtures** and reaches
  the canonical verifier, but reports the existing canonical `tool_manifest.json`
  missing `mapping-maintenance-promote`. No canonical mutation was made to mask it.
  **Before Item 08 enables preparation**, complete the guarded Item 03 live tool
  contract/publication/publisher-compliance setup. The source status currently has
  no publication or exports. This is a canonical setup prerequisite, not missing
  installed executable dependencies or an approved capability bypass.
- A first mini `gdalinfo --version` exceeded its 30-second inspection budget; bounded
  process inspection found no surviving probe, and a later bounded probe returned
  GDAL 3.13.3. No timeout was treated as completion or dataset evidence.
- Live source pause/handover, scheduled multi-gigabyte refresh/receipt, power-loss
  durability, and app/performance commissioning remain Items 08/11. This item
  installs release primitives and verifies their disposable lifetime/compatibility
  contracts; it does not install the LaunchAgent or change source sessions.
