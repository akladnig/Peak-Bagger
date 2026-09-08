---
type: Work Item
title: Define Routing Coverages and Manifest-Resolved Imports
parent: ../spec.md
---

## What to build

Make `assets/region_manifest.json` the sole routing-coverage configuration source. Add its ordered top-level `routingCoverages` definitions: `tasmania` with `displayName` `Tasmania`, followed by `northeast-alps` with `displayName` `Northeast Alps`; assign `routingCoverage: "tasmania"` to Tasmania and `routingCoverage: "northeast-alps"` to FVG, Veneto, and Slovenia.

Implement injectable manifest coverage resolution and import-input preparation for non-composite source regions with `routingCoverage`. It must validate membership, source assets, deterministic ordering, canonical JSON, aggregate source hashing, and merged Overpass elements exactly as specified, with no fallback to, reference to, or bundled dependency on `assets/highway.json`.

## Required context

- Preserve the source-region manifest contract in `assets/region_manifest.json`, `tool/generate_region_manifest_catalog.dart`, and `lib/generated/region_manifest_catalog.g.dart`. Run `dart run tool/generate_region_manifest_catalog.dart` and check in the generated catalog; do not hand-edit it.
- Existing relevant consumers include `lib/services/peak_region_asset_import_service.dart`, `lib/services/route_graph_peak_list_generation_service.dart`, `tool/region_peak_fingerprint_support.dart`, and manifest-derived tests.
- Follow the existing injectable `RouteGraphAssetLoader` and small-fixture conventions in `lib/services/route_graph_import_service.dart` and `test/services/route_graph_import_service_test.dart`.

## Acceptance criteria

- [x] `routingCoverages` is the sole non-region top-level manifest entry and retains declaration order: `tasmania`, then `northeast-alps`; resolvers do not sort coverage keys.
- [x] Every manifest consumer that enumerates regions skips only the exact `routingCoverages` key before region validation, seedability, priority, polygon, peak, or highway logic; it rejects every other non-region top-level key. `routingCoverages` appears in no generated region catalog, peak import, fingerprint result, or supported route-graph peak-list region.
- [x] The resolver rejects a source-region `routingCoverage` with no matching coverage definition, imports only non-composite source regions with `routingCoverage`, and excludes composite and legacy entries without it even when they declare `highways`.
- [x] Each configured highway asset is an already-canonical Flutter asset key: it begins with `assets/`, uses only `/`, has no leading or trailing `/`, and has no empty, `.` or `..` segment. Reject non-canonical values rather than rewriting them.
- [x] Each source asset decodes only to an Overpass JSON object with an `elements` array; an invalid top-level shape fails that coverage import. Source regions are ordered by parsed segmented manifest priority, rejecting missing, malformed, and duplicate priorities within a coverage; source asset paths are ordered with Dart `String.compareTo`.
- [x] The coverage source hash is SHA-256 of UTF-8 canonical JSON for the exact `route-graph-v5` payload shape in Contract Clarification 6: recursively sort string-keyed object keys with Dart `String.compareTo`, preserve list order, normalize finite integral `double` values to integers, reject non-finite or unsupported values, exclude `displayName` and schema version, and preserve decoded `elements` order.
- [x] Deterministically merge elements by source-region order, source-path order, then source-element order. Equal `(type, id)` identities with equal canonical JSON deduplicate; equal identities with differing canonical JSON fail before child rows are written.
- [x] Test first with small fixture JSON, including literal expected SHA-256 coverage-hash digest, declared coverage order, display-name exclusion, source priority/path validation and ordering, reserved-key behavior in every enumerating consumer, Overpass validation, duplicate handling, accepted-way validation, and no accepted-way or prepared-chunk import failure.

## Covers

- User Stories: 1, 5
- Requirements: 1-3
- Contract Clarifications: 4, 6
- Technical Decisions: 4
- Testing Strategy: 1, 6
- Interview Ledger: L2, L3, L6

## Blocked by

None - ready to start
