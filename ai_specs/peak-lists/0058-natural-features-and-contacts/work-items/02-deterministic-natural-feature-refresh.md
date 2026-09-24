---
type: Work Item
title: Deterministic Natural Feature Refresh
parent: ../spec.md
---

## What to build

Implement the deterministic local-source Natural Feature refresh service and its atomic ObjectBox persistence path. It must read only `/Volumes/Services/Features/tasmania_natural_features.json` through an injectable app-isolate file-reader seam, pass only raw JSON text and serializable values to a top-level isolate worker, and make no network request or supplementary OSM geometry lookup. The worker must parse, index nodes and ways before materializing candidates, calculate geometry and construct a serializable refresh plan. The app isolate must perform MGRS conversion and execute the completed plan in one ObjectBox write transaction through injectable conversion, persistence, and diagnostic-logging seams.

Implement the exact candidate, geometry, mapping, composite OSM feature identity, atomic-upsert, preservation, and count-classification contracts in Requirements 2 and 5-13. In particular, duplicate eligible candidate identities or duplicate stored identities must fail before the write transaction, commit no changes, and report no success counts; Manual protection takes precedence over geometry and MGRS resolution; source omissions remain stored; and a persistence failure after the write phase begins rolls back every change.

## Required context

- `lib/services/peak_refresh_service.dart`, `lib/services/peak_mgrs_converter.dart`, and `lib/services/peak_admin_editor.dart` provide the related refresh, MGRS, and coordinate-editing conventions. Do not reuse Peak's fixed-`55G` parsing behavior.
- `lib/models/natural_feature.dart` and its repository from `01-objectbox-entity-foundation.md` are the persistence target.
- Use small JSON fixtures under `test/fixtures/natural_features/`; tests must never read `/Volumes/Services/Features/tasmania_natural_features.json`.
- Use a real temporary ObjectBox store for transaction and rollback assertions, following the project's persistence tests.

## Acceptance criteria

- [x] Candidate parsing accepts only supported `node`, `way`, and `relation` source elements with both non-empty trimmed string `tags.name` and `tags.natural`; it ignores elements with neither required tag without counting them and counts all specified invalid candidates as skipped without inventing fallback names or tags.
- [x] The importer uses numeric JSON `id` only when it is an integer in `1..9,223,372,036,854,775,807`, stores `osmType` as exactly `node`, `way`, or `relation`, and matches only by `(osmType, osmId)`.
- [x] Source and stored duplicate identities are rejected before the write transaction with no persisted changes and no success counts.
- [x] Nodes use direct coordinates; closed ways use fixed Tasmania-local equirectangular area centroids; open ways use length-weighted centroids; multipolygons subtract valid inner rings from outer rings; other resolvable relations use length-weighted centroids. The calculation uses WGS84 mean Earth radius `6,371,008.8 m`, reference latitude `-42.0` degrees, reference longitude `146.0` degrees, `x = R * radians(longitude - 146.0) * cos(radians(-42.0))`, and `y = R * radians(latitude + 42.0)` before converting back to WGS84.
- [x] Geometry accepts only finite numeric WGS84 coordinates in the required latitude and longitude ranges, never recurses through relations, resolves only direct way members, follows the exact multipolygon roles and deterministic member-order tie-breaking rules, and skips malformed, disconnected, zero-length, or zero-area geometry. Touching or crossing inner-ring boundaries skip the relation and log the geometry error through the injected diagnostic seam.
- [x] Imported field mapping trims text; seeds `altName` only from string `tags.alt_name`; sets `country` to `Australia`, `region` to `Tasmania`, and `county` to empty; and applies the exact `natural=water` tag rule without a `water=` prefix.
- [x] Imported or recalculated coordinates derive `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` through the same conversion behavior as Peaks. A failed MGRS conversion skips that source element.
- [x] A matching `Manual` Natural Feature is protected before geometry or MGRS conversion; an eligible matching `OSM` row retains its ObjectBox `id`, preserves `altName`, `country`, `county`, `region`, and its stored `name` only when `altName` is non-empty, and replaces all other source-derived data. Unmatched eligible OSM identities insert a new row, and omitted stored rows remain.
- [x] The refresh is atomic for duplicate validation, file read, JSON parse, and persistence failures. An unavailable source file preserves all Natural Features and fails with exactly `Error refreshing natural features: source file is unavailable at /Volumes/Services/Features/tasmania_natural_features.json`.
- [x] Focused unit tests cover every fixture-driven parser, geometry, normalization, MGRS, and error contract named in Testing Strategy items 1-2; repository tests cover identity matching, duplicate failures, preservation, omission retention, rollback, Manual protection, and source recreation after deletion. A macOS maintainer-build integration or manual check confirms that the fixed path is readable.
- [x] Run ObjectBox generation, the ObjectBox schema guard, targeted Natural Feature unit and repository tests, `flutter analyze`, and the full `flutter test` suite.

## Covers

- User Stories: 1, 2, 4
- Requirements: 2, 5-9, 11-13
- Technical Decisions: 2-4
- Testing Strategy: 1-3, 6
- Interview Ledger: L2-L6, L11

## Blocked by

- `01-objectbox-entity-foundation.md`
