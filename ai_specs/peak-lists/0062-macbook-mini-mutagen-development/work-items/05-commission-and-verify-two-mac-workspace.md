---
type: Work Item
title: Commission and verify the real two-Mac workspace
parent: ../spec.md
---

## What to build

Execute the reviewed migration and setup on the real MacBook and mini, then verify the complete three-project workspace, local builds/tests, Git ownership, synchronization/reconnection, and MacBook offline rebuilding. Produce a commissioning record with explicit passed/failed/pending evidence and permit ordinary mini development only once migration, setup, and required verification are complete.

## Required context

- Read the parent Spec, `../interview-ledger.md`, and all four prerequisite Work Items' implementation artifacts and verification results.
- Exact corresponding roots:

  | Project | MacBook Git checkout | Mini working-file mirror |
  | --- | --- | --- |
  | Peak Bagger | `~/Development/mapping/peak_bagger` | `/Volumes/Development/mapping/peak_bagger` |
  | Trip Routing | `~/Development/mapping/trip_routing` | `/Volumes/Development/mapping/trip_routing` |
  | Flutter Map Tile Caching | `~/Development/mapping/flutter_map_tile_caching` | `/Volumes/Development/mapping/flutter_map_tile_caching` |

- SSH must work MacBook-to-mini for Mutagen and mini-to-MacBook for Git. Discover/validate aliases and existing credentials without exposing secrets. An absent external volume or unreachable machine is an actionable prerequisite failure; do not create substitute empty roots or repositories.
- Earlier inspection found both Trip Routing copies clean at `7491846` and FMTC copies at `022bbe0` with identical tracked diffs. Reinspect commits/branches/stashes/staged/unstaged/untracked work now; historical inspection does not establish migration safety.
- Preserve unique work and mini Git metadata outside all synchronization roots; preserve excluded machine-local credentials/database/service data in place while seeding. Use only disposable source probes for real-session propagation checks; never provoke conflicts in live source or databases.
- Consult the operational guide for source-write freeze and readiness procedures. Mini migration writes and disposable setup probes are permitted during setup; ordinary mini development is not.

## Acceptance criteria

- [ ] Both SSH directions, exact external volume mounts/permissions, sibling roots, and required installed Mutagen support are validated. Missing prerequisites identify the affected step/project and block its setup without substitute directories or Git fallback.
- [ ] Current mini repository and working-file state is inspected for unique commits, branches, stashes, staged/unstaged/untracked changes; unique work is preserved outside every root or deliberately reconciled into the MacBook baseline. Mini Git metadata is moved outside all roots as recoverable backups before ordinary mirroring.
- [ ] Edits are saved and all source writers on both machines across all three projects are stopped before final reconciliation/seeding. The freeze lasts through matching in-scope path/content verification, activation, and the first successful three-session flush/status check. Stale mini-only source cannot return as new additions; excluded local content remains intact.
- [ ] Exactly one intended SSH `two-way-safe` session is active per project with Work Item 02's effective configuration. Reapplying unchanged setup reuses matching sessions without duplicates; any drift stops the affected project for deliberate reconciliation rather than silently replacing sessions.
- [ ] Every real session propagates a disposable change MacBook-to-mini and mini-to-MacBook, then propagates probe removal with cleanup confirmed. `.git` remains only on MacBook roots; keys, live database files, caches, Local Topo generated payloads, and FMTC's installed test libraries do not propagate.
- [ ] MacBook controlling-daemon login startup and session persistence are exercised. Connection-loss status is clear, offline edits remain local, and synchronization catches up automatically on reconnect. Conflict outcomes are supported by disposable verification rather than conflicting user files; there is no automatic winner/reset to suppress conflicts.
- [ ] Real handover readiness checks cover all three sessions and require no pending changes/conflicts/connection errors/other problems. Writers remain stopped through the check, resume only on the receiving machine after success, and stay stopped on the outgoing machine. A failed/unavailable member is named and blocks handover.
- [ ] Mini-initiated Git is verified to target each corresponding MacBook repository. Unreachable-MacBook behavior reports Git unavailable without creating a mini repository. File-replacement and staging/commit procedures retain Work Item 03's flush/freeze gates, supported by its disposable Git verification; user work is not reset merely to demonstrate them.
- [ ] Work Item 01's machine-local API-key procedure is applied without exposing values: seed an absent mini file once over SSH, preserve a usable existing file, and report an invalid file for deliberate correction. The example remains shared and later local-key edits remain local.
- [ ] SDK/package/platform dependencies and caches are installed/generated locally on both machines; stale relocation caches are recreated. Peak Bagger's tracked dylib treatment is confirmed compatible on both Macs, and FMTC ObjectBox `test/lib/` readiness is checked locally before relevant tests on each machine.
- [ ] Package resolution, appropriate Flutter/Dart analysis, existing relevant tests for the three projects, and a Peak Bagger macOS build on both machines are recorded with commands/outcomes. Required native-library tests are not called successful without their prerequisites; installed native test libraries remain excluded.
- [ ] After online provisioning, a MacBook macOS rebuild succeeds with the external development drive absent and all network access unavailable, including mini access. A saved disposable source change requiring compilation demonstrates rebuilding rather than launching an existing binary; the exact provisioning/build procedure and result are recorded, and the probe is cleaned up.
- [x] Work Item 04's SMB runtime access and startup evidence are included in the commissioning record. Offline-build success is not described as offline full-app startup; no local Mapping replica or personal-data synchronization is introduced.
- [x] The record identifies evidence, remaining unique-work backups, and every incomplete environmental check as pending, not passed. Failed bootstrap/readiness blocks ordinary development; source writers resume only on the selected machine after successful initial readiness, and ordinary mini development remains gated on completion of migration, setup, and required verification.

## Covers

- User Stories: 1–5; User Story 6's runtime evidence is integrated from Work Item 04.
- Requirements — Workspace layout and initial migration: 1–6 (live execution and completion gate).
- Requirements — Git ownership and machine handover: 1–7 (live ownership/access/readiness and adherence to Work Item 03's procedures).
- Requirements — Synchronization behavior and scope: 1–7 (live sessions, exclusions, persistence/reconnection, and explicit outcomes).
- Requirements — Local builds and API-key configuration: 1–5 (mini provisioning, both-Mac compatibility/build verification, credential seeding, and fully disconnected MacBook rebuild).
- Requirements — Mapping runtime access and offline inventory: 1–3 (integration of Work Item 04's runtime evidence and offline boundary).
- Testing Strategy: live bootstrap/freeze and baseline readiness; real-session bidirectional probes and cleanup; repeat setup; login/persistence/outage/reconnect; handover and remote Git; both-Mac package/analysis/test/build and native-library verification; fully disconnected MacBook recompilation; SMB runtime evidence integration.
- Interview Ledger: L1–L7.

## Blocked by

- [01-portable-dependencies-and-local-build-configuration.md](01-portable-dependencies-and-local-build-configuration.md)
- [02-repeatable-mutagen-configuration-and-safe-bootstrap.md](02-repeatable-mutagen-configuration-and-safe-bootstrap.md)
- [03-handover-remote-git-and-conflict-recovery.md](03-handover-remote-git-and-conflict-recovery.md)
- [04-smb-runtime-access-and-offline-inventory.md](04-smb-runtime-access-and-offline-inventory.md)

## Commissioning attempt — 2026-10-11

**Blocked; live migration and ordinary mini development are not ready.** The four
prerequisite Work Items are complete. Current evidence and the pending completion
checklist are in
[`docs/two-mac-commissioning.md`](../../../../docs/two-mac-commissioning.md).

- The mini Development volume is now attached at the exact APFS mount; all three
  roots pass helper preflight and are writable. MacBook-to-mini SSH works, and
  installed MacBook Mutagen 0.18.1 matches the reviewed configuration.
- Reverse SSH to the discovered MacBook hostname fails with port 22 connection
  refused. Mini reverse identity/configuration, owner Git and owner-command PATH
  remain unverified. Full Xcode is unavailable at the standard location and only
  Command Line Tools are selected; Flutter/Dart are unavailable on the inspected
  noninteractive PATH. FMTC's separate native test library is absent.
- Both existing machine-local defines files fail status-only validation and were
  preserved for deliberate correction. The user's modified shared defines example
  also needs deliberate restoration to placeholders before synchronization; no
  credential values are included in the commissioning artifacts.
- Current commits/refs/stashes/staged/unstaged/untracked inventories were inspected
  on both machines. FMTC tracked binary diffs match; Trip Routing is clean at the
  same commit. Mini Peak Bagger modified/untracked work still needs verified
  preservation/review. No migration backup or Git metadata relocation occurred.
- The operator's two-Mac/all-project writer freeze has not been established.
  No live sessions, seeding, activation, login registration or handover occurred.
  Remaining acceptance criteria stay unchecked until their real evidence exists.
- Mini's tracked Peak Bagger dylib loads on arm64 and exports the required recorded
  C API/core versions. Fresh package minima, native tests and both-Mac builds are
  pending. The fully disconnected source-recompilation check is pending.
- Current exact SMB mount/manifests and mini share settings were rechecked;
  Work Item 04's completed online startup/inventory evidence is incorporated.
- Fresh full Python operational suite: **30 passed** in 19.094 seconds, using
  isolated/disposable sessions. No real session readiness is inferred from those
  tests. Previous Flutter verification remains attributed to prerequisite records.

### Recheck after operator configuration updates

Both existing private defines files now pass status-only validation. MacBook
Remote Login is reachable, but reverse SSH fails strict host-key verification;
mini host trust/authentication and owner Git remain pending. Xcode now reports
27.0 / 27A266a with its full developer directory selected, while the operator
reports installation still underway. Flutter/CocoaPods remain unavailable on the
checked SSH and login-shell PATHs, and FMTC's test library is absent. The shared
defines example is now deleted and needs reconciliation before synchronization.
All three roots still pass preflight; no live sessions or migration were started.
Detailed updated evidence is appended to the commissioning record. The Work Item
remains blocked and its live acceptance criteria remain unchecked.
