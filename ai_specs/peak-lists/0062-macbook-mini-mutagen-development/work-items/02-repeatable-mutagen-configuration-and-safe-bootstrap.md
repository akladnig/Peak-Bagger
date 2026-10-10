---
type: Work Item
title: Provide repeatable Mutagen configuration and safe bootstrap
parent: ../spec.md
---

## What to build

Provide persistent, inspectable configuration and repeatable setup procedures for the three named Mutagen working-file sessions. Define a recoverable MacBook-authoritative bootstrap that preserves unique mini work and excluded machine-local content, establishes matching in-scope trees, and only then enables ordinary `two-way-safe` synchronization.

Verify the configuration and migration procedures in disposable endpoints. Live migration and session activation belong to Work Item 05.

## Required context

- Read the parent Spec and `../interview-ledger.md`; use Work Item 01's ObjectBox library treatment when defining source scope.
- Intended roots are MacBook `~/Development/mapping/{peak_bagger,trip_routing,flutter_map_tile_caching}` and mini `/Volumes/Development/mapping/{peak_bagger,trip_routing,flutter_map_tile_caching}`. Expand these into one session per project over SSH with the MacBook controlling daemon.
- Inspect all three projects and their examples, not just Peak Bagger's root `.gitignore`. Mutagen does not inherit Git ignore rules; required lockfiles and generated source may be Git-ignored but still in synchronization scope.
- `local_topo/tasmania/.gitignore` excludes generated payloads but retains `input/.gitignore`, `output/.gitignore`, and `runtime/.gitignore`. Preserve these source-controlled placeholders.
- ObjectBox model metadata/generated Dart are shared source; live `data.mdb`/`lock.mdb` are local runtime data. FMTC's installed `test/lib/` libraries are separate machine-local test dependencies.
- Discover configuration placement and login-start support from the installed Mutagen version and existing setup. SSH aliases are discovered and validated during implementation; do not embed credentials or invent working hostnames.
- An absent volume or unreachable SSH endpoint is a setup failure. Do not create substitute empty roots under `/Volumes`.

## Acceptance criteria

- [x] Persistent configuration names all three projects, their exact effective roots, SSH transport, and `two-way-safe` mode. MacBook login startup and persisted-session inspection/setup instructions are provided; the mini needs Remote Login and Mutagen's remote agent rather than another controlling daemon.
- [x] Explicit exclusions cover `.git` directories and worktree metadata files; Dart/Flutter dependency/build/cache/plugin artifacts; coverage; Python caches; `node_modules`; platform dependencies/ephemeral output in roots and examples; Xcode user state and machine-local SDK paths; live ObjectBox files; logs/PIDs/temp files/`.DS_Store`; FMTC session-relative `test/lib/`; and `dart_defines.local.json`.
- [x] Peak Bagger Local Topo generated `input`, `output`, `runtime`, and temporary test-output payloads are excluded while source-controlled placeholders remain shared. Source/configuration/styles/tests, UI assets, workflow documents, relevant lockfiles, and required generated source/model metadata remain in scope. The tracked dylib follows Work Item 01's inspected treatment.
- [x] Setup checks existing sessions against project identity, effective endpoint roots, mode, and required exclusions before reuse. Unchanged setup reuses the intended sessions without duplicate active sessions. Drift reports the affected project and stops its setup without replacing the session or creating a duplicate.
- [x] Deliberate session reconciliation/replacement instructions preserve endpoint work and unresolved conflicts and explain that changing a configuration file does not change ignores captured by an existing session.
- [x] Bootstrap instructions inspect unique mini commits, branches, stashes, staged/unstaged/untracked work before replacement; preserve unique work outside every synchronization root unless deliberately reconciled into the MacBook baseline; and move mini Git metadata outside all roots as recoverable backups.
- [x] Final reconciliation/seeding happens after saving edits and stopping source writers on both Macs in all three projects, including agents, formatters, and generators. The freeze lasts through baseline verification, activation, and the first successful three-session flush/status check. Failed baseline or readiness checks block ordinary development.
- [x] Seeding explicitly reconciles stale mini-only in-scope paths, including files deleted on the MacBook, rather than performing an additive copy. Both endpoints' in-scope path sets and file contents match before bidirectional activation; excluded credentials, live databases, service payloads, and local outputs remain intact.
- [x] Disposable migration verification includes a stale mini-only source file, a differing shared file, unique recoverable work, and excluded machine-local files. It demonstrates matching baselines, no stale-source resurrection, recoverable unique work, and preserved/non-propagating exclusions.
- [x] Disposable synchronization verification covers representative source, workflow/docs/assets, required generated source/model metadata, relevant lockfiles, excluded keys/database/cache/native-test files, ordinary deletions, and same-file/edit-delete conflicts where detected. Incompatible offline edits in disposable endpoints are retained and explicitly reported as conflicts on reconnect, without a winner or reset to suppress them.
- [x] Disposable configuration-drift checks exercise wrong roots, wrong mode, and missing required exclusions while preserving endpoint work/conflicts. Verification records the freeze/readiness sequence and failed-readiness behavior; no live user source or database is used to provoke conflicts.
- [x] Configuration scope is limited to the three project roots; Mapping data, unrelated projects, Docker/container state, and personal app data are not included.

## Covers

- User Stories: 2, 4, 5.
- Requirements — Workspace layout and initial migration: 1–5 (configuration, safe procedure, and disposable verification; live execution in Work Item 05).
- Requirements — Git ownership and machine handover: 1–2.
- Requirements — Synchronization behavior and scope: 1–7 (configuration and disposable verification; login/reconnect evidence on real machines in Work Item 05).
- Requirements — Local builds and API-key configuration: 3–5 (source/exclusion boundary).
- Testing Strategy: temporary-endpoint synchronization; stale-tree/bootstrap preservation and freeze; setup reapplication/configuration drift; explicit conflict behavior.
- Interview Ledger: L1, L2, L3, L5, L6, L7.

## Blocked by

- [01-portable-dependencies-and-local-build-configuration.md](01-portable-dependencies-and-local-build-configuration.md)

## Implementation and verification — 2026-10-10

Completed configuration, safe-bootstrap tooling/procedures and disposable
verification. Operational instructions and the detailed evidence matrix are in
[`docs/two-mac-mutagen-bootstrap.md`](../../../../docs/two-mac-mutagen-bootstrap.md).

- Persistent `tool/mutagen-workspace.json` defines exactly three named SSH
  sessions and explicit common/project-aware exclusions. Root expansion on this
  MacBook produces `/Users/adrian/Development/mapping/<project>`; mini roots remain
  `/Volumes/Development/mapping/<project>`.
- `tool/mutagen_workspace.py` provides inspect/preflight, drift-safe pre-paused
  setup, explicit recoverable-bootstrap seeding, baseline verification,
  activation and a strict three-session flush/readiness check. Setup does not
  reset/replace sessions or select conflict winners. Failed seeds retain their
  temporary session paused for inspection; retries refuse overlapping sessions.
- `tool/mutagen_scope.py` independently compares in-scope path sets, SHA-256
  contents, file types, executable bits and symlink targets on both endpoints.
  Ordinary activation verifies all baselines before resuming any paused session.
- All three project ignore files and relevant nested examples were inspected.
  Required generated Dart/ObjectBox metadata, relevant Git-ignored locks and
  Peak Bagger's tracked dylib stay shared. Local Topo's three direct placeholders
  stay shared while generated payload/test-output trees are excluded. FMTC's
  `/test/lib` and `/test/download` remain machine-local.
- Actual Mutagen **0.18.1** disposable integration verification: **7 tests
  passed**, covering stale migration, recoverable temporary Git work, excluded
  preservation/non-propagation, source propagation/deletion, three-session
  activation/readiness, same-file offline conflicts, edit/delete behavior,
  drift/overlap/override rejection, and failed-bootstrap preservation.
- Important measured behavior: Mutagen 0.18.1 `two-way-safe` reports differing
  same-file edits as conflicts and retains both. A plain edit versus deletion
  preserves/restores the modified source automatically, rather than reporting
  that case as a conflict. Documentation records this native non-data-losing
  behavior and does not promise a conflict for every edit/delete combination.
- `ruff check` on the three new Python files and `python3 -m py_compile`: passed.
  Full `python3 -m unittest discover -s tool/tests -v`: **26 passed**, including
  existing defines and disposable Docker-migration checks.
- `flutter analyze --no-pub`: no issues. Required full Peak Bagger suite with
  `caffeinate -i flutter test --no-pub --reporter expanded`: **2,173 passed,
  5 skipped** in 2m57s. No application/native-library code was changed here.
- Existing `mini` SSH alias resolves to `mac-mini.local`/`adrian`; noninteractive
  hostname probe reached `MacMini`. **The mini's Development volume is absent**:
  real read-only preflight correctly fails naming the project and required root.
  No substitute roots, live sessions, Git metadata moves, seeding or login
  registration were performed. Tests used a separate daemon/data directory.

### Explicit pending checks for Work Item 05

- Attach/validate the mini Development volume and all three existing project
  roots; revalidate SSH and Remote Login/remote-agent/Python readiness.
- Perform live unique-work inspection/preservation, metadata relocation, final
  frozen reconciliation/seeding/baseline verification and ordinary activation.
- Register the controlling MacBook daemon at login; verify real logout/login,
  persisted session IDs/configuration and physical disconnect/reconnect.
- Verify real bidirectional probes/exclusions and all three readiness checks
  before ordinary mini development. Reverse Git SSH, machine-local provisioning,
  credentials and remaining commissioning checks stay with Work Items 03/05.
