---
type: Work Item
title: Implement protected retention, space checks, and durable-receipt cleanup
parent: ../spec.md
---

## What to build

Implement background-controller-owned generation cleanup and space checks using the activation/session contracts from Item 05 and independent captures from Item 04. Protect active, recovery, live-session/native-handle, and still-owned capture/export data, and prune only eligible unprotected material.

Add durable independent receipt acknowledgement and mini export cleanup that cannot disrupt a transfer or allow unbounded unacknowledged export production. Item 08 integrates these policies into scheduled and maintainer orchestration.

## Required context

- Read the parent Spec and ledger, Item 01's reviewed receipt/ownership/selection contracts, Item 03's export protection, Item 04's independent captures, and Item 05's concrete generation/session pinning.
- Reuse the pipeline's narrowly scoped non-store metadata/capture owners and authorized snapshot read boundaries. `docs/mapping-data-store.md` and `test/tool/mapping_data_store_inventory_test.dart` govern access/inventory guards.
- Native dataset ownership starts at `lib/services/route_elevation_sampler.dart`; follow actual cache/handle lifetime and worker ownership rather than assuming widget disposal releases every reader.
- Existing startup/service seams and tests provide conventions; use disposable directories with deterministic filesystem/space/process-lifetime/lock/clock/transport seams for cleanup and race coverage. Read `pubspec.yaml` if dependencies change.
- Operation protection must survive local controller/SSH-client exit while remote preparers or local children continue. Cleanup may not infer ownership ended from an absent controller PID/flag alone; Item 08 reconciles recorded operation identities.

## Acceptance criteria

- [x] Only the background controller owns cleanup; app launch may select/pin metadata but does not bulk-prune datasets. Protect the active generation, **one previous validated recovery generation**, and every generation pinned by any live app session or native handle.
- [x] Retain at most **one additional eligible pending generation**, the newest complete one. Superseded unpinned eligible candidates may be removed only when no producer/validator/native/session protection remains; a newer pending generation cannot displace another session's data.
- [x] Coordinate cleanup with transactional selection/pinning so overlapping app launches and cleanup cannot delete another session's selected directory. A running session's root and open DEM remain immutable and available through later imports/lazy reads.
- [x] Session protection is process-lifetime protection releasing after a crash, not permanent flag files indefinitely asserting a live session. Explicitly document native handle/cache/worker ownership and release, including handles that outlive UI ownership.
- [x] Remove superseded candidates and incomplete/abandoned captures only after producing/validating operations have actually released them. Surviving remote/local operations retain capture/export and installed-release/helper protection through reconciliation; timeout, interruption, or client exit is not ownership release.
- [x] Audit space for incoming data, independent capture, protected generations, and mini exports before initial provisioning and refresh. Record actual sizes/space needs rather than assuming historical 3.963 GiB covers simultaneous storage requirements.
- [x] Insufficient space reports the failed stage with operation/dataset/local path context and preserves active, recovery, and live-session/native-handle generations. Never delete protected data to force publication; failed captures remain ineligible.
- [x] Implement versioned MacBook acknowledgement of **durable independent receipt** bound to the completed source generation and validated local capture. Transfer idle/completion alone is not receipt; delayed/lost acknowledgement cannot prematurely release source protection.
- [x] Mini prepared exports cannot be deleted before durable-receipt acknowledgement or while a transfer/preparation owner still needs them. Bound unacknowledged export production: complete the existing transfer/receipt or report a blocked pipeline instead of publishing further exports without bound.
- [x] Receipt/cleanup retry and reconnect are idempotent under reviewed metadata contracts and preserve evidence needed for recovery. Cleanup/status logs expose protected identities, pruning decisions, receipt state, space failures, and blocked source production.
- [x] Use behavior-first red/green/refactor for new publication/async-result logic and disposable deterministic tests for active/recovery protection, newest-pending pruning, concurrent launches/cleanup, live native/session ownership, crash-released protection, owned versus abandoned captures, and low-space preservation.
- [x] Test durable acknowledgement, failed acknowledgement/reconnection, ongoing-transfer source protection, bounded unacknowledged exports, and unresolved surviving work. Automated tests never depend on or destructively modify live canonical data, SMB, SSH credentials, API keys, or personal databases.
- [x] Run focused retention/selection/capture tests and access guards. Document storage accounting, receipt/cleanup policy, process/native ownership, and actionable blocked/low-space recovery steps for controller integration and commissioning.

## Covers

- User Stories: 3, 4.
- Requirements — Automatic synchronization and activation: 6–7, 10 (protected data and surviving ownership).
- Requirements — Generation retention and cleanup: 1–4.
- Requirements — Startup and recovery behavior: 5–6 (concurrent selection/recovery protection).
- Technical Decisions: 3–5.
- Testing Strategy — Deterministic automated coverage: TDD default where applicable; retention coverage; controller interruption protection integration.
- Interview Ledger: L3, L4, L5.

## Blocked by

- [05-select-runtime-and-recover-startup.md](05-select-runtime-and-recover-startup.md)

## Implementation and verification — completed 2026-10-13

- `mapping_retention.py` provides narrowly inventoried controller-only cleanup and
  storage accounting through the existing replica/source owners. Local pipeline
  and app `selection-retention` flock coordination protects active, one recovery,
  newest complete pending, live session/native and unresolved operation identities.
  Validated matching committed journals retire their extra prior recovery; prepared
  old/new tuples remain protected. App startup performs no bulk pruning.
- Cheap eligibility reads now reject missing/unexpected payload files and changed
  lengths, so an incomplete newest directory cannot displace a complete pending
  generation. No launch/background-reader payload hashing was added.
- Cleanup retains captures with unresolved/missing producer evidence, inherited
  child ownership and unresolved release/helper identities for Items 07–08. OS
  session locks release on crash; stale session records/PIDs assert no liveness.
  Python cleanup versus actual Dart launch/native-owner locks verifies cross-owner
  coordination and protection beyond UI-session closure.
- `Replica.acknowledge` consumes the validated schema-1 durable receipt, requires
  an exact persisted source response and retains local capture evidence until
  confirmation. Source acknowledgement and cleanup preserve current/unacknowledged/
  live-transfer exports, retry the same receipt after lost response or pruning and
  reject conflicting/unsupported/duplicate-key receipt metadata.
- Source preparation blocks a changed publication before another full capture
  while an export awaits durable receipt; acknowledged current exports remain
  reusable until a successor completes. Terminal abandoned captures may be pruned
  after ownership release. Surviving/unknown work is not inferred ended from client
  exit, timeout or a free lock alone.
- Space reports record current inventory bytes, incoming remainder/full capture
  plans, actual filesystem free space and occupied logical/allocated bytes by
  incoming/candidate/generation/export/release/backup identity, plus 64 MiB reserve.
  Both host capture bridges audit before copying; provisioning/refresh pretransfer
  audits are exposed for Item 08. Low-space failures preserve protected data.
- Durable cleanup intent/status is recorded before deletion. Interrupted removal
  can finish leftover eligibility cleanup on retry while retaining receipt and
  operation evidence. Status includes timestamped last cleanup/space/receipt/
  blocked-production observations; these logs are not liveness authority.
- [Operating policy, native/cache lifetime, accounting and blocked/low-space recovery](../../../../docs/mapping-runtime-retention.md)
  document the concrete APIs/commands, metadata paths and Items 07–08 handoffs.
  Direct-I/O guards freeze the shared helper's scoped destructive sites.

### Verification

- Behavior-first red/green cycles exposed missing cleanup/acknowledgement/space
  APIs, repeated blocked scratch production, unsupported-metadata pruning, missing
  file acceptance, lost/pruned receipt retry, remote unknown-outcome reuse,
  receipt symlink/duplicate-key acceptance and interrupted cleanup failures before
  their fixes. Fixtures use deterministic ordering/space/transport and disposable
  actual filesystem/process/lock ownership.
- `python3 -m unittest discover -s tool/tests -p test_mapping_retention.py`:
  **22 passed**, covering retention, crash/native/session/child protection,
  selection journals, unknown operations, low space on both hosts, receipt/cleanup
  faults and source production/transfer protection.
- `python3 -m unittest discover -s tool/tests`: **89 passed**.
- Focused seven-file Flutter selection/retention/record/native/provider/access-guard
  run: **57 passed**.
- Final three-file native capture/retention/access-guard run after the strict
  operation-stage check: **14 passed**, including the production GDAL matrix.
- `caffeinate -i flutter test --no-pub --reporter expanded`: **2,252 passed,
  5 existing skips**, **16m02s**, including the real Python → Dart profile → tiny
  GDAL capture integration and existing startup/source-failure robot journeys.
- `flutter analyze --no-pub`: **no issues**. Dart formatting and `git diff --check`
  passed.
- No live Mapping/SMB/SSH/API-key/personal-database input was used. Installed
  release pruning and bounded scheduled transport/reconciliation integration are
  Items 07–08; physical power-loss and real multi-gigabyte storage/operating
  evidence remain commissioning, not claims made by disposable tests.
