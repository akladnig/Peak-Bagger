---
type: Work Item
title: Deliver automatic Mutagen refresh with bounded single-flight recovery
parent: ../spec.md
---

## What to build

Integrate installed source preparation, persistent one-way Mutagen transfer, independent local capture/validation, eligibility, durable receipt, and cleanup into an automatically scheduled MacBook controller. Setup is idempotent and drift-aware; scheduled and maintainer invocations share one mutation owner and recoverable operation identities.

Deliver bounded, noninteractive execution and reconciliation after timeout/interruption, preserving healthy multi-gigabyte work across ticks and surviving remote/local operations. App startup remains entirely independent of this runner.

## Required context

- Project-root-relative `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS). No pending dimensions affect controller/installation/metadata work.
- Read the parent Spec and ledger plus the completed export/capture/retention/release contracts in Items 03, 04, 06, and 07. Automatic export is gated on the complete publisher compliance/recovery inventory from Item 01/03.
- `tool/mutagen_workspace.py`, `tool/mutagen_scope.py`, `tool/mutagen-workspace.json`, `tool/tests/test_mutagen_workspace.py`, and `tool/tests/test_mutagen_operations.py` contain existing inspection/drift/disposable-endpoint conventions. Do not append dataset replication to the three source sessions or their handover gate.
- `docs/two-mac-mutagen-bootstrap.md`, `docs/two-mac-mutagen-operations.md`, and `docs/two-mac-mapping-runtime.md` describe existing source roots and historical runtime behavior. The dedicated session is a deliberate superseding runtime contract, not authorization for broader Services replication.
- Use existing SSH alias **`mini`** with normal authentication. Consult installed Mutagen/macOS LaunchAgent behavior and actual executable dependency paths; scheduled jobs execute Item 07's installed versioned releases.
- New nondeterministic seams should be narrow: process, transport, lock, clock, transfer status, filesystem/space, and operation ownership/completion inspection. Existing startup injection proves the app never dispatches/waits for this runner. Consult `pubspec.yaml` only if Dart dependencies change.

## Acceptance criteria

- [x] Create/reuse a dedicated persistent session named exactly **`mapping-runtime-replica`**, prepared mini export as **alpha**, MacBook incoming staging as **beta**, effective mode **`one-way-replica`**. The source is the prepared manifest-derived export, not the entire canonical `/Volumes/Services/Mapping` tree.
- [x] Synchronization writes only incoming staging, never captured candidates/active generations. Configuration, local validation/selection/protection records, retained generations, and logs live outside beta, which `one-way-replica` may overwrite/remove destination-only content.
- [x] Maintainer setup idempotently manages a MacBook **user LaunchAgent** invoking the controller at login and every **60 seconds** while the user is logged in. Source preparation runs over existing SSH alias **`mini`**, using installed pinned releases on both machines.
- [x] Inspect existing intended sessions and runner installations before reuse; verify effective roots, direction, scope, mode, installed release identities, and schedule. Matching setup reuses installations without duplicates; drift is an actionable failure, not silent replacement or an additional overlapping session.
- [x] Keep the existing three source-workspace sessions, their ownership/exclusions, and handover gate separate. Runtime refresh pause/resume is independent of source handover. Do not synchronize personal ObjectBox databases, GPX, API-key files, settings, tile caches, Docker/Overpass state, or Local Topo payloads.
- [x] Orchestrate coherent source completion → completed transfer → independent capture → source-inventory integrity and reviewed dataset validation → durable eligible publication. Mutagen idle alone or timing out never authorizes completion/eligibility. Preserve all declared files even when rarely read interactively.
- [x] Reuse unchanged completed exports/generations; a scheduled tick does not produce another dataset generation. Resume transfer progress after reconnect and retry confirmed failed stages on subsequent scheduled runs without app startup involvement.
- [x] Expose source-preparation, transfer, validation, eligibility, activation, and cleanup status/errors through maintainer tooling/logs, including selected/installed generation and release identities. Activation remains Item 05's launch transaction; the runner does not switch a running app's root.
- [x] Enforce **one mutation-owning controller invocation per replica pipeline** across scheduled ticks, maintainer commands, and initial provisioning. Later conflicting invocations defer/report busy while healthy work owns the pipeline rather than duplicating preparation/capture/publication.
- [x] The **60-second** schedule is a trigger interval, not a completion deadline. Healthy multi-gigabyte preparation/transfer/capture/validation may span ticks; progress-aware status distinguishes healthy ongoing work from hung/unavailable stages.
- [x] Define and document bounded, noninteractive limits for SSH/process calls, publication/controller lock acquisition, and transfer-status polling. Do not invent successful completion when a bound expires; surface stage, limits, progress/availability, and recovery diagnostics.
- [x] On timeout, interruption, or unknown outcome, durably record stage and recoverable operation identity, preserving Mutagen progress, active/recovery/live-session data, and capture/export protection. Never interpret timeout as completion, integrity, eligibility, or ownership-release evidence.
- [x] Before conflicting retries, use bounded inspection and operation ownership/completion evidence to reconcile any still-running remote preparer or local child. Local controller exit or SSH-client termination alone does not prove remote work ended. An unresolved outcome blocks conflicting mutation while later runs may inspect/reconcile it.
- [x] Surviving work retains its installed release, helpers, and capture/export protection until ownership actually ends. Recovery must not start duplicate preparation, release another operation's protection, erase transfer progress, or clean protected generations. Confirmed failure/completion authorizes only the appropriate safe retry/continuation.
- [x] Integrate Item 06 space and retention checks and durable-receipt acknowledgement. Insufficient space preserves protected data; unacknowledged export production is bounded, and source cleanup cannot invalidate an ongoing transfer.
- [x] Interrupted transfer, mini disconnect, source-read failure, corrupt candidate, and local publication failure leave the previous validated replica usable; candidates are rejected/reported rather than merged into active payloads. Bulk copy/hashing/export remains background work; the app never dispatches/waits for the runner or probes remote freshness.
- [x] Initial provisioning uses the same ownership, preparation, transfer, integrity, eligibility, and activation rules as refresh. Document actual setup/inspection, login/schedule, pause/resume, recovery, noninteractive wait limits, drift resolution, and installed-version procedures without embedded credentials.
- [x] Behavior-first red/green/refactor tests use disposable directories and fake process/status/clock/transport/lock responses plus disposable real Mutagen endpoints where meaningful. Cover direction/scope/effective mode, incoming-only writes, setup reuse/drift, unchanged reuse, login/60-second scheduling, reconnect catch-up, failed-stage retry, and controller restart.
- [x] Deterministic execution/recovery tests cover healthy work across ticks, overlapping scheduled/maintainer/provisioning calls, busy deferral, hung/unavailable stages, and all bounded waits. Exercise controller/SSH interruption with remote preparer or local child still alive, bounded reconciliation, unresolved blocking, valid continuation, and retained release/helper/data protection through real ownership release.
- [x] Test source edits/partial delivery, paused source sessions, handover, compatible upgrade pinning, and incompatible artifact rejection with retained active/recovery data intact. Timeouts never publish completion/eligibility or erase progress. Do not edit the live canonical store to manufacture failures; tests require no user Mapping files/credentials/API keys. Run focused controller/runner/Mutagen and relevant activation/retention regressions and record results.

## Covers

- User Stories: 3, 4.
- Requirements — Canonical ownership and local runtime access: 1, 3, 5–6 (pipeline separation).
- Requirements — Automatic synchronization and activation: 1–3, 7–10.
- Requirements — Coordinated source capture and validation: 1–3 (compliance gate and orchestration).
- Requirements — Generation retention and cleanup: 1–4 (scheduled integration, especially receipt-bound source cleanup).
- Technical Decisions: 2–5, 7; non-secret configuration/normal SSH authentication.
- Blocking Decisions and Execution Gates: inventoried publishers coordinated before automatic export.
- Testing Strategy — Deterministic automated coverage: TDD default; synchronization/runner tests; controller execution/recovery tests; retention integration.
- Testing Strategy — Live performance and operating evidence: installed pipeline and bounded single-flight recovery procedures (live evidence in Item 11).
- Interview Ledger: L3, L4, L5.

## Blocked by

- [03-coordinate-publication-and-source-exports.md](03-coordinate-publication-and-source-exports.md)
- [06-protect-retention-and-durable-receipt.md](06-protect-retention-and-durable-receipt.md)
- [07-install-versioned-pipeline-releases.md](07-install-versioned-pipeline-releases.md)

## Implementation and verification — completed 2026-10-14

- `tool/mapping_controller.py`: durable version-1 single-flight controller phases,
  nonblocking mutation ownership shared by scheduled/maintainer/provisioning calls,
  recorded identities before uncertain dispatch, bounded status/reconciliation,
  independent capture/eligibility, exact durable receipt, retention/space integration,
  idempotent drift-aware user LaunchAgent setup and independent pause/resume.
- `tool/mapping_transport.py`: installed pinned local/SSH alias `mini` dispatch,
  bounded noninteractive process/status/alias calls, intended/overlapping-session
  inspection, exact prepared-alpha/incoming-beta one-way-replica and asynchronous
  flush/status polling. No source handover gate, canonical bypass or app dispatch.
- Source transfer pins survive controller exit and protect exports through receipt;
  only exact acknowledged independent receipt authorizes release. Generic free-lock
  reconciliation cannot clear them. Installed release reconciliation fences missing
  dispatch identities so delayed SSH cannot start an operation already retried.
- Two live prerequisite defects were diagnosed and corrected without altering peak
  payloads/fingerprints or relaxing validation: the external Slovenia script lacked
  its assumed shell shebang; composite Italy validation incorrectly rejected NE/NW
  overlaps. Guarded publication recovery completed and publisher enablement passed.
  Repeated allowed Natural Feature skips also produced 58 MB validation metadata;
  exact-count aggregation retains all distinct diagnostics, and capture rejects
  oversized final evidence before eligible publication under the existing 16 MiB
  reader bound. Regression tests demonstrated each defect before its correction.
- ADS-1.0 and Desktop wide apply; no Flutter foundation replacement, UI/layout
  change, dimension-dependent work or proposed shared-rule exception. Native handles
  and session protection remain Item 05/06 owners; activation remains app launch.
- [Controller setup/recovery/limits](../../../../docs/mapping-runtime-controller.md),
  source publication, installed releases, access inventory and two-Mac operating
  links document exact implemented commands and the distinct source/runtime scopes.

### Verification

- Focused five-file Flutter validation/I/O/retention/selection/startup run: **46 passed**.
  Final diagnostic aggregation/validation/I/O run: **24 passed**.
- Full `python3 -B -m unittest discover -s tool/tests`: **115 passed**, including
  **14** controller cases and the new never-dispatched release-fence regression.
  Covers recorded timeout/restart, healthy ownership across ticks, busy deferral,
  confirmed-failure retry, surviving local child/unresolved remote evidence,
  fake-clock stalled/unavailable diagnostics, low-space preservation, receipt/pin
  ordering, unchanged reuse, schedule/drift, and real disposable Mutagen catch-up.
  Existing source/capture/retention/release tests cover payload corruption,
  publication faults, actual inherited child locks, compatibility rejection,
  protected active/recovery/session/native data and checkout-unavailable helpers.
- `flutter analyze --no-pub`: **no issues**.
- Final full `caffeinate -i flutter test --no-pub --reporter expanded`:
  **2,259 passed**, **5 existing skips**, **13m58s**. Skips remain unverified.
- Formatting and `git diff --check` passed. New automated cases use fixture/
  disposable data, not live Mapping files, SSH credentials, keys or user databases.

### Installed machine evidence

- Both release bases remain `/Users/adrian/.local/share/peak-bagger-mapping-releases`.
  Final complete pinned controller is **`8918ed0f-54a0-4dd8-b54f-ae3147af3942`**
  (8 artifacts, 1,172 dependency identities); mini source preparer is
  **`dfe2a953-e4fb-4902-8da6-4b8e37f7fdaf`** (20 artifacts, 1,057 dependencies).
  All previous installed/development IDs remain explicitly compatible under schemas
  1, profile `mapping-runtime-v1` and the existing app reader. Old immutable artifacts
  were retained, not patched. The paused explicit compatible upgrade reused the
  same incoming bytes, source pin, completed generation, session and LaunchAgent.
- Session **`mapping-runtime-replica`**, ID
  **`sync_LoJOvzKX3HDbPatMplTGRyoRjuGaeCg6BCN8han8lAT`**, is effective
  **one-way-replica**, alpha
  `mini:/Users/adrian/.local/share/peak-bagger-mapping-source/prepared`, beta
  `/Users/adrian/Library/Application Support/com.example.peakBagger/MappingRuntimeReplica/incoming`.
  Repeat setup reused it. No three-source session/handover change was made.
- User agent **`com.peakbagger.mapping-runtime-replica`** is installed and loaded
  under `gui/501`; `launchctl print` confirms installed dispatcher arguments,
  `runatload` and **run interval 60 seconds**. Initial automatic source dispatch
  occurred on load. Repeated scheduled/maintainer observations retained the original
  source UUID across healthy multi-GB work. An overlapping installed inspection
  hit the bounded 5-second dispatcher lock and reported busy without changing state.
- Initial export generation **`2be1ef1d-0f92-41a7-ae7d-722142dee4d1`** is the complete
  **25-file, 4,255,657,108-byte** app set. Source operation
  **`561fda9e-8cb4-4567-9c8e-872388bc3398`** passed full profile/integrity validation;
  transfer pin **`2f3abf39-d905-4fbd-8a5f-e22d9be7c250`** retained its bytes across the
  compatible upgrade. Transfer progressed through staging and a completed cycle,
  and local capture operation **`29db75c0-d1b9-4b21-b595-378bf156345c`** uses the final
  controller/validator. Local validation finished at **2026-10-13T21:37:01Z** UTC;
  the immutable **7,804-byte** report passes the reader's size bound. Quiet-stage
  expiry had recorded `outcome-unknown` while the actual validator stayed CPU-active;
  the controller retained the same operation/helpers/candidate/source pin until its
  verified success and real ownership release, without a duplicate capture.
- Durable receipt **`2ab31b16-f029-44d4-b39d-3177c619c62f`** was acknowledged by the
  mini at **21:38:12Z** UTC. Its exact source completion/local report binding was
  confirmed; the transfer pin was then released. Local/source cleanup completed
  with no unresolved operations, retaining this newest pending/current export.
  Installed `eligible` inspection confirms the complete generation; activation is
  **pending next app launch**, not performed by the runner.
- Follow-up source operations **`b2362d1b-3281-43a8-a1b5-7132aaf1a127`** and
  **`27f0c339-9c30-4506-96c6-1ea8d0413153`** reused the exact same completed/eligible
  generation and existing receipt, with **no new capture operation or generation**.
  The second completed through both cleanup stages. Loaded agent inspection reached
  **38 scheduled runs**, last exit **0**, retaining `runatload`/60-second scheduling.
- Capture space accounting observed **120,436,305,920 bytes available**, full
  independent capture **4,255,657,108 bytes** plus **67,108,864-byte reserve**, and
  incoming **4,255,660,940 logical / 4,255,719,424 allocated bytes**, 27 files
  including completion/integrity metadata. Source audit recorded **730,163,175,424
  bytes available** before export capture; protected backups/validation scratch are
  accounted separately. These are actual pipeline observations, not performance
  acceptance measurements or guarantees of future disk availability.
- Actual logout/login, live handover/disconnect/destructive fault drills, physical
  power-loss, app activation and startup/route performance are Item 11/09/10
  commissioning evidence, not claims made by automated fixture tests.
