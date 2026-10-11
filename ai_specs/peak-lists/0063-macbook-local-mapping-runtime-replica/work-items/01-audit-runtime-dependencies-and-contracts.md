---
type: Work Item
title: Audit runtime dependencies and define validation/metadata contracts
parent: ../spec.md
---

## What to build

Produce a reproducible, maintainer-readable inventory of the complete manifest-required app dataset and all operations publishing those files. Define and review the source/local payload-validation matrix and versioned pipeline metadata contracts that subsequent export, eligibility, activation, installation, and cleanup slices consume.

This is the contract/diagnosis gate, not replica provisioning. Recheck current sizes and content integrity read-only before provisioning; preserve historical measurements as historical evidence. Identify the frequent or latency-sensitive source reads that a local Mapping runtime replica addresses.

## Required context

- Read `../spec.md`, `../interview-ledger.md`, and repository-root `GLOSSARY.md`. The mini owns the canonical Mapping data store; the MacBook owns only a downstream Mapping runtime replica.
- `docs/mapping-data-store.md` contains the runtime/tool access inventory and capability boundaries. `docs/two-mac-mapping-runtime.md` contains the 2026-10-10 inventory and historical SMB commissioning evidence. The parent Spec supersedes its SMB-only runtime restrictions, not its historical observations.
- `lib/services/mapping_store_core.dart`, `lib/services/mapping_store_resolver.dart`, `lib/services/mapping_tool_manifest.dart`, and `lib/services/mapping_tool_resolver.dart` define production parsing, containment, and authorized read/write boundaries; `lib/services/mapping_data_store.dart` is the Flutter adapter.
- Inspect current import/parser consumers, including peak imports, route-graph imports, `lib/services/tasmap_repository.dart`, Natural Feature import paths, polygon loaders, and `lib/services/route_elevation_sampler.dart`. Reuse real parsers/checks rather than inventing weaker duplicate schemas.
- `tool/mapping_store.dart`, `tool/mapping_tool_support.dart`, `tool/elvis_dem.dart`, `tool/publish_thelist_dem.sh`, the inventoried maintainer tools, and their operating docs are starting points for a complete publisher audit, not an exhaustive publisher list.
- Test conventions: `test/services/mapping_data_store_test.dart`, `test/tool/mapping_data_store_inventory_test.dart`, `test/tool/mapping_tool_resolver_test.dart`, and `test/fixtures/mapping_store/`. Consult `pubspec.yaml` if implementation requires dependency changes.

## Acceptance criteria

- [x] Derive the set from current `region_manifest.json` and `Polygons/manifest.json` using production schema/path rules. Include the manifest pair, all referenced regional peaks/highways/polygons, basemap coverage polygons, Natural Features and TasMap catalogs, every declared DEM, and display-polygon references. Deduplicate references; neither directory globs nor historical counts are the authority.
- [x] The reproducible inventory records each store-relative path, current byte size, accessing code, startup existence/readability checks, startup content reads, live-runtime reads, and import/update reads. Distinguish Mapping sources from local ObjectBox records/caches and identify frequent/latency-sensitive reads.
- [x] Record the historical baseline exactly as **25 files, 4,255,657,108 bytes (3.963 GiB)**, audited on 2026-10-10; the 2026-10-11 interview retained the path set without remeasuring sizes/integrity. Record fresh read-only size/integrity evidence and deviations, or an explicit missing-access prerequisite; do not claim a fresh audit from those earlier figures.
- [x] Preserve source schema, region/coverage resolution, declared regional peak fingerprints, containment, preflight, and ordering. All declared DEMs remain required, including `DEM/Elvis/elvis_runtime_10m.tif`, `DEM/tasmania_dem_25m.tif`, and `DEM/cop30_hh.tif` when still declared. Existing ObjectBox data does not bypass readiness checks.
- [x] Scope remains the complete app set, excluding raw ELVIS inputs, ELVIS topo DEM, tool-only datasets, Overpass/container state, unrelated Services content, and Local Topo service payloads. Personal ObjectBox databases, GPX files, API-key files, settings, and tile caches are not replication inputs.
- [x] Inventory every publisher of app-required files and related manifest/fingerprint changes, including shell/Dart tools, manual maintenance, and multi-command updates. Identify transaction boundaries and the required guarded maintenance entry points for Item 03. Automatic export remains disabled until every inventoried publisher complies.
- [x] Define and review a validation matrix for peaks, highways, Natural Features, TasMap, required/display polygons, and DEMs: exact production parsers/checks, additional payload-format checks, corruption/semantic guarantees, and limitations. Enforce production manifest/path rules, required polygon parsing, and declared regional peak fingerprints. Distinguish received-byte transfer integrity from dataset validity; SHA-256 alone does not prove valid upstream content. Do not claim guarantees beyond the matrix.
- [x] Define versioned source-completion/integrity and publication completion/recovery formats, durable-receipt records, local eligibility/selection records, and supported controller/source-preparer/app-reader combinations. Integrity records contain generation identity and every required store-relative path, byte size, and **SHA-256** digest; eligibility binds the exact validated generation and inventory and is checkable without repeating multi-gigabyte hashes at launch.
- [x] Contracts separate immutable payloads from configuration, coordination, eligibility/selection/session metadata, and logs. Describe independent capture, transactional old/new selection recovery, process-lifetime protection, durable receipt, and recoverable operation identity/ownership evidence needed after controller/SSH interruption. A free lock alone is not publication completion, and local client exit alone is not remote-operation completion.
- [x] Identify narrowly scoped owners/capabilities for snapshot reads, non-store export/replica publication, coordination, and local selection/session metadata. Plan inventory/direct-I/O guard updates without broadening dataset-write authority, bypassing resolvers, broadly relaxing allowlists, or importing tool manifests into shipped runtime.
- [x] Behavior-first red/green/refactor covers any new derivation/validation logic using fixture manifests: complete set, all DEMs/display polygons, deduplication, invalid/escaping references, and preserved fingerprint behavior. Automated tests require no real Mapping files, SMB, SSH credentials, or API keys; run focused affected tests and record results.
- [x] Save reviewed contracts and inventory in maintainer-readable project documentation, including review evidence and unresolved guarantees. Report environmental blockers instead of fabricating source measurements or silently enabling later stages.

## Covers

- User Stories: 3, 6.
- Requirements — Dependency inventory and diagnosis: 1–3.
- Requirements — Canonical ownership and local runtime access: 1, 4–6 (inventory and contracts; runtime delivery in Item 05).
- Requirements — Automatic synchronization and activation: 3–5, 9–10 (metadata and ownership contracts; implementation in later items).
- Requirements — Coordinated source capture and validation: 1–4 (publisher inventory and reviewed contracts).
- Technical Decisions: 1–3, 5–7 (contract boundaries and documentation).
- Blocking Decisions and Execution Gates: before eligibility implementation; publisher inventory before automatic export.
- Testing Strategy — Deterministic automated coverage: TDD default; service/unit tests (dependency derivation, production rules, validation contract).
- Interview Ledger: L2, L3, L4.

## Blocked by

None - ready to start

## Blocking decisions

- Define and review the payload-validation matrix and metadata contracts before eligibility implementation. Audit/design work in this item may proceed; obtain the required review rather than treating an unreviewed proposed matrix as an approved eligibility guarantee.

## Implementation and review — completed 2026-10-11

- Reproducible command: `dart run tool/mapping_runtime_inventory.dart [--root PATH]`.
  Derives from production preflight/catalog and uses resolver-authorized streamed
  SHA-256/raw-byte reads in the existing filesystem owner. No Mapping writes or
  new direct-I/O guard exemptions. Source schema and shipped runtime ordering are
  unchanged; this item delivers diagnosis/contracts only.
- [Reviewed revision 1](../../../../docs/mapping-runtime-replica-contracts.md):
  per-format source/local matrix, exact metadata formats/digest identity,
  compatibility, publisher transactions, capability boundaries, selection/session
  lifetime, receipts, single-flight/bounded recovery and retention contracts.
- Maintainer explicitly selected **Approve revision 1** for the matrix (including
  full band-1 DEM decoding and limitations), metadata/compatibility,
  ownership/recovery and wait policy; separately selected **Register is complete**
  for repo/external/manual publishers. This resolves this item's review gate.
  Automatic export remains gated on Item 03 publisher compliance.
- [Fresh observation](../../../../docs/mapping-runtime-audit-2026-10-11.md):
  completed 2026-10-11T10:54:12.244501Z over MacBook SMB. **25 files,
  4,255,657,108 bytes**, no path/size deviations; SHA-256 for each path; production
  preflight/required polygons and declared peak fingerprints passed. An unlocked
  read-only audit is not coherent export evidence or full matrix validation.
- TDD: first inventory test failed compilation before implementation; manifest
  drift and reader-role assertions failed before their implementation. Coverage,
  display/deduplication, escaping-path/symlink and ordered raw-byte fingerprint
  tests confirmed reused production behavior without new parsers.
- Focused six-file Mapping/tool/fingerprint regression command: **99 passed**.
- `flutter analyze --no-pub`: **no issues**.
- `caffeinate -i flutter test --no-pub --reporter expanded`: **2,178 passed,
  5 skipped**, 2m51s. Existing skipped tests remain unverified.
- `python3 -m unittest discover -s tool/tests -v`: **30 passed**.
- `git diff --check`: passed. No fresh performance/space commissioning or full
  payload-profile validation is claimed; those belong to subsequent items.
