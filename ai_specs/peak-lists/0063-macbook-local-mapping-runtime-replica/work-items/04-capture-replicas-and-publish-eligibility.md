---
type: Work Item
title: Capture incoming replicas independently and publish generation-bound eligibility
parent: ../spec.md
---

## What to build

Implement independent local capture and validation of received completed exports, publishing generation-bound eligibility only after transfer integrity and dataset validity both pass. Incoming staging is the transport's writable destination; captured candidates and eligible generations are distinct immutable directories outside it.

Deliver this pipeline stage with deterministic transport/process/filesystem seams and fixture/disposable data. Persistent Mutagen setup and automatic orchestration belong to Item 08; local activation belongs to Item 05.

## Required context

- Read the parent Spec, ledger, Item 01's reviewed source/local validation matrix and metadata formats, and Item 03's coherent completed exports and ownership/completion evidence.
- Reuse `lib/services/mapping_store_core.dart` and authorized resolver boundaries for manifest/path/polygon/fingerprint validation. Replication publication requires narrowly scoped non-store capabilities, not arbitrary Mapping writes.
- Existing test anchors: `test/services/mapping_data_store_test.dart`, `test/tool/mapping_data_store_inventory_test.dart`, fixture manifests, and injected filesystem conventions. Read `pubspec.yaml` if hashing/capture validation needs dependency changes.
- Keep the entire manifest-required set; ordinary ObjectBox-backed browsing or infrequent interactive reads do not authorize omitting datasets.
- Record generation identity, source-completion/inventory version, producing/validating operation identity and protection, and durable receipt integration for Items 05–08. Configuration, eligibility/selection/session metadata, and logs are outside immutable payload directories and the transport destination.

## Acceptance criteria

- [x] Require a coherent completed source export, completed transfer, and successful validation of an independent local capture before eligibility. Mutagen idle/status alone, arrival of a manifest alone, or a timeout is never sufficient evidence.
- [x] Incoming writes remain confined to staging. Capture into a distinct generation directory outside that writable destination using independent copies or copy-on-write clones; do not use writable hard links to incoming files.
- [x] Validate captured bytes against that completed source generation's inventory: exact required paths, byte sizes, **SHA-256** digests, and manifest pair. Detect missing/truncated files, digest mismatch, invalid/escaping references, inconsistent captures, and interruptions.
- [x] Independently validate dataset semantics according to Item 01's reviewed matrix: production manifest/path rules, required polygon parsing, declared regional peak fingerprints, and agreed additional peaks/highways/Natural Features/TasMap/display-polygon/DEM checks. Matching hashes of malformed upstream content do not make a dataset valid.
- [x] Publish versioned local eligibility atomically only after successful captured-byte validation, bound to the exact generation and integrity inventory. App readers can check eligibility without repeating multi-gigabyte hashes at launch while retaining normal preflight and source-read validation.
- [x] Eligible payloads are never modified; later content creates another generation. Incoming writes during/after validation cannot alter captured bytes or make stale eligibility valid. Interrupted, inconsistent, or changed captures remain ineligible.
- [x] Reuse an unchanged completed/validated generation rather than create another one solely for a scheduled tick. Preserve generation/operation protection until its producer/validator actually releases ownership; do not confuse controller/client exit with surviving child completion.
- [x] Interrupted transfer, mini disconnection, source-read failure, corrupt candidate, and local publication failure leave previous validated data usable. Reject/report the candidate with stage, operation, dataset, and affected local paths; never partially merge it into active data or silently fall back to SMB.
- [x] Independent durable receipt evidence is produced only after successful capture/validation and durable local publication under the reviewed contract; source cleanup cannot infer receipt from transfer idle. Integrate receipt acknowledgement and retention/space policy through Items 06 and 08.
- [x] Replication remains read-only toward canonical Mapping datasets. Keep configuration, local validation/selection records, retained generations, protection, and logs outside the destination that `one-way-replica` may overwrite/remove. Update narrowly scoped access inventory/direct-I/O guards for new ownership boundaries.
- [x] Use behavior-first red/green/refactor with disposable data and deterministic filesystem/transport/process seams. Cover incomplete transfer, missing/truncated files, digest/peak-fingerprint mismatch, invalid references, malformed payloads for every documented matrix category, interrupted capture/publication, unchanged reuse, and eligibility bound to exact captured contents.
- [x] Explicitly test incoming modification during and after validation: previously captured eligible bytes remain unchanged, independent capture is demonstrated, and changed/inconsistent captures cannot reuse stale validation metadata. Failure cases preserve the prior validated generation. Automated tests require no user Mapping files, live SMB, SSH credentials, or API keys.
- [x] Run focused capture/validation and existing manifest/inventory guard tests; document eligibility/integrity guarantees, failure diagnostics, and handoffs for activation, cleanup, and controller integration.

## Covers

- User Stories: 3, 4.
- Requirements — Canonical ownership and local runtime access: 1, 4–6.
- Requirements — Automatic synchronization and activation: 3–5, 7.
- Requirements — Coordinated source capture and validation: 3–4.
- Requirements — Generation retention and cleanup: 2, 4 (operation protection and receipt integration; cleanup in Item 06).
- Technical Decisions: 2–5.
- Testing Strategy — Deterministic automated coverage: TDD default; service/unit integrity, fingerprint, matrix, incomplete transfer, independent capture, and exact-generation eligibility tests.
- Interview Ledger: L3, L4, L5.

## Blocked by

- [03-coordinate-publication-and-source-exports.md](03-coordinate-publication-and-source-exports.md)

## Implementation and verification — completed 2026-10-13

- `tool/mapping_replica.py`: synchronous/detached incoming-only capture owner,
  exclusive independent copies, completed-inventory SHA-256/size/path checks,
  shared production profile, immutable generation publication, external versioned
  eligibility/receipts, bounded lifetime locks, status and identity reconciliation.
- Captured bytes are rechecked after validation; incoming metadata is checked
  before/after and its exact raw bytes retained. Changed generation identity or
  captured bytes cannot retain eligibility; unchanged valid captures are reused.
- Local publication requires a durable successful per-operation commit witness
  after generation/eligibility/receipt flushes. Small-metadata readers reject
  interrupted/failed outcomes and avoid payload hashing. Item 05 consumes this
  chain before normal preflight/catalog loading and transactional activation.
- Process/release/generation protection survives inherited validator children;
  controller exit or budget expiry does not prove completion. Abandoned candidates
  remain ineligible until ownership reconciliation and Item 06 cleanup. Failure
  reports identify stage, operation/generation, dataset and local paths.
- Receipt output binds the validating operation, inventory, exact source completion
  and local report. Items 06/08 consume it through source receipt acknowledgement;
  capture checks space plus a 64 MiB reserve and never deletes good generations.
- Reused production parsers and native full-band validation; added TasMap path
  context to failures and flushes frozen file permissions in the shared source
  adapter. Access inventory/direct-I/O guards cover the narrowly scoped local owner.
- [Operating guarantees and handoffs](../../../../docs/mapping-replica-capture.md)
  describe commands, strict metadata, reader/receipt integration and recovery.
- Red/green cycles demonstrated absent capture/validator APIs, stale candidate and
  metadata acceptance, missing unchanged reuse, incomplete publication eligibility,
  symlink/local-namespace escape, overlapping ownership, crash reconciliation,
  strict completion, low-space and interrupted-copy handling, receipt identity,
  and missing TasMap dataset diagnostics before their implementations.
- `python3 -m unittest discover -s tool/tests -v`: **67 passed**, including **22**
  new disposable replica cases. Existing Mutagen tests use disposable endpoints.
- Focused seven-file capture/source/preflight/inventory/resolver/cutover run:
  **119 passed**. End-to-end Python → Dart → GDAL uses generated tiny rasters and
  rejects fresh-hash malformed payloads for every reviewed matrix category,
  invalid references and stale fingerprints while preserving prior valid data.
- `flutter analyze --no-pub`: **no issues**. `git diff --check`: passed.
- Full `caffeinate -i flutter test --no-pub --reporter expanded`: **2,214 passed,
  5 skipped**, **12m20s**. Existing skipped checks remain unverified.
- No user Mapping files, live SMB/SSH credentials/API keys or canonical mutations
  were used by the new tests. Persistent runtime transport/controller installation,
  activation, retention policy, physical power-loss and live performance/space
  commissioning remain the specified later work items.
