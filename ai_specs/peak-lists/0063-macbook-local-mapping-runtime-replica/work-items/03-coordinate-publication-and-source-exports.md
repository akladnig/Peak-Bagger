---
type: Work Item
title: Coordinate canonical publication and prepare complete validated source exports
parent: ../spec.md
---

## What to build

Implement coordinated mini-local canonical publication and validated source export preparation using Item 01's reviewed contracts and complete publisher inventory. Wrap related multi-file/multi-command maintainer updates in one guarded maintenance transaction, including manual updates, and capture the complete manifest-derived app set under the same publication lock.

Publish complete immutable source exports outside both the canonical Mapping dataset and source-workspace synchronization roots. Export preparation is background maintainer work; the Flutter app does not publish canonical datasets or prepare exports at startup.

## Required context

- Read the parent Spec, ledger, and Item 01's reviewed validation matrix, source-completion/integrity/recovery formats, ownership contracts, and inventoried publisher/transaction list.
- `docs/mapping-data-store.md`, `lib/services/mapping_tool_resolver.dart`, `lib/services/mapping_tool_manifest.dart`, `lib/services/mapping_store_resolver.dart`, and `tool/mapping_tool_support.dart` preserve resolver authority and each tool's existing dataset-write capability.
- Audit the identified publishers rather than assuming `tool/elvis_dem.dart`, `tool/publish_thelist_dem.sh`, or `tool/mapping_store.dart` are the whole list. Include their scripts/helpers and current maintenance instructions.
- Reuse production parsing/preflight/fingerprint checks in `lib/services/mapping_store_core.dart` and dataset consumers; include the additional reviewed format checks from Item 01.
- Tests: `test/services/mapping_data_store_test.dart`, `test/tool/mapping_tool_resolver_test.dart`, `test/tool/mapping_tool_cutover_test.dart`, `test/tool/mapping_data_store_inventory_test.dart`, fixture manifests, and disposable process/filesystem/lock seams. Read `pubspec.yaml` before any dependency addition.
- This preparer will be installed/version-pinned by Item 07 and invoked over `mini` by Item 08. Preserve operation identities, bounded-call integration, and export protection for surviving preparation work; do not tie invocation behavior to source-workspace readiness.

## Acceptance criteria

- [x] Introduce a mini-local publication lock outside `/Volumes/Services/Mapping`. Every inventoried maintainer publisher honors it across app-required payload publication and related manifest/fingerprint changes, retaining its existing dataset-write authority.
- [x] Related multi-command updates have one coordinated maintenance transaction with no unlocked gaps. Manual maintenance follows the same guarded procedure; document exact implemented entry points and recovery steps. Automatic export cannot be enabled while any inventoried publisher remains noncompliant.
- [x] Export preparation takes the same lock while capturing the complete manifest-derived app set, excluding concurrent publication and partial multi-file states. Interrupted publication cannot become eligible for capture merely because the writer exited or the lock became free; establish completion/recovery evidence before capture resumes.
- [x] Failed/incomplete publication or preparation is reported with operation/dataset context and never publishes a completed export. Preserve recoverable operation identity/ownership and capture protection when remote preparation remains alive after an SSH/client interruption; integrate bounded lock/process calls without interpreting a timeout as completion.
- [x] Capture only the manifest pair and all current app-required references using production path rules. Include all declared DEMs/display polygons and catalogs; exclude raw ELVIS/topo-build data, tool-only datasets, unrelated Services data, personal app data, and Local Topo service payloads.
- [x] Every export has a generation identity and integrity inventory containing every required store-relative path, byte size, and **SHA-256** digest, including `region_manifest.json` and `Polygons/manifest.json`. Perform hashing and expensive validation in the background pipeline, not app launch or click handlers.
- [x] Apply the reviewed source validation matrix: production manifest/path checks, required polygon parsing, declared regional peak fingerprints, and the documented additional format checks for peaks, highways, Natural Features, TasMap, display polygons, and DEMs. Preserve the distinction between byte integrity and dataset validity; do not claim undocumented semantic guarantees.
- [x] Publish a versioned completion record and expose the prepared export to synchronization only after capture and source validation succeed. Payloads are immutable after completion; coordination metadata and logs remain separate. Reuse unchanged completed exports rather than creating a generation merely because another invocation/tick occurs.
- [x] Exports remain protected from mutation/cleanup through capture, preparation ownership, transfer, and durable-receipt requirements. Define the receipt-bound cleanup integration consumed by Item 06; publication must not replace/delete bytes supporting an ongoing transfer.
- [x] Maintain mini canonical authority at `/Volumes/Services/Mapping`; a snapshot preparer receives only narrowly scoped authorized reads and non-store export publication capabilities. Update tool/access inventory and direct-I/O guard coverage rather than bypassing resolver boundaries or broadly relaxing allowlists.
- [x] Behavior-first red/green/refactor tests use fixture/disposable data to cover publisher/capture exclusion, related multi-command transactions, writer crash/incomplete recovery, failed source validation, required references, peak fingerprint mismatches, malformed payloads under the matrix, completion publication failure, and unchanged export reuse. Never alter the live canonical store to manufacture failures; no automated test needs SMB, SSH credentials, API keys, or real Mapping datasets.
- [x] Run affected source/tool/service tests and inventory/direct-I/O guards; record results and update coordinated-maintenance/source-export operating docs with status/error and recovery guarantees.

## Covers

- User Stories: 3, 4.
- Requirements — Canonical ownership and local runtime access: 1, 4–5.
- Requirements — Automatic synchronization and activation: 2–4, 7, 9–10 (source-stage contracts and integration; installed/scheduled orchestration in Items 07–08).
- Requirements — Coordinated source capture and validation: 1–4.
- Requirements — Generation retention and cleanup: 4 (source protection and durable-receipt integration).
- Technical Decisions: 2–3, 5, 7.
- Blocking Decisions and Execution Gates: publisher compliance/completion recovery before automatic export; reviewed validation matrix before eligibility.
- Testing Strategy — Deterministic automated coverage: TDD default; service/unit publisher/capture, incomplete publication, source validation, and recovery tests.
- Interview Ledger: L3, L4.

## Blocked by

- [01-audit-runtime-dependencies-and-contracts.md](01-audit-runtime-dependencies-and-contracts.md)

## Implementation and verification — completed 2026-10-12

- `tool/mapping_source.py`: detached, single-flight source supervision; mini-local
  publication/capture/release locks; durable journals/backups/plan progress;
  finish/rollback recovery, explicit publisher compliance and external Slovenia
  cwd guard installer; immutable completed exports and bounded unchanged reuse.
- Canonical resolver writes require a live outer lease; child permissions retain
  exact original output/override authority. Added exact manual promotion and
  original-capability restoration; no generic store-write shell or app writes.
- `mapping_source_dataset.dart` reuses production catalog/read/fingerprint/polygon
  checks and shared pure peak, coverage/generation, Natural Feature and TasMap
  parsing. Read-only GTiff/BigTIFF validation decodes every band-1 block and closes
  native resources. All expensive copying/hashing/validation stays in maintainer work.
- Versioned inventory/completion/validation/operation records use generation and
  release UUIDs. Independent payloads are read-only after publication. Failed or
  unknown work remains protected; a timeout/client exit is never completion evidence.
- Item 06 consumes `receipt_cleanup_scope`, with exact durable receipt binding and
  frozen live transfer/operation pins. New exports block behind an outstanding
  unacknowledged export; this item does not delete protected exports.
- [Operating procedure](../../../../docs/mapping-source-publication.md) documents
  exact plans, source preparation, publisher enablement, bounded status/inspection,
  recovery and later installed-release/retention integration. Inventory/direct-I/O
  guards cover the narrowly scoped adapters and the new 14-tool fixture.
- Red/green cycles began with missing coordinator/parser/capture APIs, then
  unfinished writer recovery, missing publication lease, immutable/reuse behavior,
  outstanding receipt bounds, full-band DEM validation and unknown completion
  rejection. Additional disposable regression cases cover process crash, inherited
  child locks, pending-command resumption and completion publication failure.
- Focused 13-file Mapping/source/tool/service run: **193 passed**, one old tool-ID
  inventory expectation failed after adding the exact manual capability; repaired
  expectation and reran cutover/inventory guards: **18 passed**. All affected checks
  subsequently passed in the full suite.
- `flutter analyze --no-pub`: **no issues**.
- `python3 -m unittest discover -s tool/tests -v`: **45 passed**.
- Full `caffeinate -i flutter test --no-pub --reporter expanded`: **2,211 passed,
  5 skipped**, **12m36s**. The first attempt hit the shell's 10-minute deadline
  after 1,302 passes; rerun with a longer deadline completed successfully. Skipped
  existing checks remain unverified.
- Native validation used a disposable compressed 17×17 GeoTIFF (four decoded
  blocks), not real Mapping rasters. No live canonical dataset, external script,
  exporter enablement, Mutagen session or scheduled runner was changed/commissioned.
  Installed/version-pinned artifacts and live operating evidence remain Items 07–11.
