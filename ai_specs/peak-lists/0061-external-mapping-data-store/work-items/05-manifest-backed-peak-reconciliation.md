---
type: Work Item
title: Reconcile Peaks from Mapping Store Sources
parent: ../spec.md
---

## What to build

Replace asset-backed peak seeding and shipped-app Overpass refresh with manifest-backed automatic seeding and the exact Settings `Update Peak Data` flow. Add `PeakRegionFingerprint` ObjectBox persistence and migrate valid legacy `peak_region_import_fingerprints_v1` markers transactionally without source reads.

## Required context

- Update `peak_region_asset_import_service.dart`, `peak_region_import_marker_store.dart`, `peak_refresh_service.dart`, `overpass_service.dart`, peak/map providers, Settings, ObjectBox models, and generated ObjectBox files.
- Use the Mapping failure coordinator for source faults; preserve current app-owned peak fields and user-owned non-OSM rows.

## Acceptance criteria

- [x] Automatic seeding runs only when ObjectBox has no `Peak` records; manual update reads only fingerprint-changed seedable regions, including unmarked regions in a populated store. A no-op update reads no source file. Composite regions with retained `peaks` are never seeded or refreshed.
- [x] Render exactly `Update Peak Data`, subtitle `Update peaks from Mapping data store`, confirmation title `Update Peak Data?`, and primary action `Update`; remove all shipped-app Overpass refresh UI, provider, service, and runtime requests.
- [x] Parse each source as an Overpass-style JSON object with `elements`. Only OSM `node` elements with `tags.natural == peak` are eligible; well-formed ways, relations, and other ineligible records are diagnostic-only skips.
- [x] Validate each complete nonblank source before any write: eligible records require positive integer `id`, non-empty trimmed name, and finite in-range latitude/longitude; invalid eligible records, non-object entries, and duplicate source identities fail only that region with no region write.
- [x] Reconcile by globally unique positive `Peak.osmId`: source rows are owned by the importing `regionKey`; delete only missing rows owned by that source region; preserve ObjectBox IDs and `peakbaggerPid`, `rating`, `durationMinutes`, `durationLabel`, `difficulty`, `viaFerrata`, `notes`, `verified`, and non-OSM `sourceOfTruth` values.
- [x] Reject an incoming identity owned by another region, an unowned legacy OSM row, or a non-OSM user-owned row without changing that region's peaks or fingerprint, except Spec requirement 31's approved NE-over-NW and NE-over-Slovenia-over-Croatia source policies. Skip identities present in a preferred source; permit OSM-owned losing rows to transfer to a winner with IDs/user fields intact. Never claim, update, delete, or reassign an unowned legacy or user-owned row.
- [x] Commit each successful region's peaks and fingerprint atomically; preserve prior successful regions if a later region fails. Retry only the failed region with the original canonical `regionKey`.
- [x] Migrate only non-empty legacy fingerprints for current seedable regions into unique `PeakRegionFingerprint.regionKey`/`fingerprint` rows in one transaction, then remove the SharedPreferences key only after success.
- [x] Add focused parser/repository/provider/widget/robot coverage for every source predicate, malformed and identity case, transaction behavior, no-source-read no-op, exact Settings text, and Mapping-unavailable state `peak-search-mapping-unavailable` with `peak-search-mapping-unavailable-retry`.

## Approved NE/NW precedence — 2026-10-07

L11 resolves the four mounted boundary-peak overlaps in favor of NE. NW reads and
validates the current declared NE source before excluding overlapping identities,
counts those as skips, and retains a skipped legacy NW row until NE reconciliation
can transfer it without losing its ID or user fields. The repository permits only
the OSM-owned NW-to-NE transition; unrelated-region and user-owned/unowned conflicts
still fail. Source files and the ObjectBox schema remain unchanged.

Regression coverage verifies both import/refresh orders, preservation of existing
NW IDs and user fields, malformed/duplicate shadowed candidates and preferred
sources, exact-path missing-source failures, and protected ownership. The unchanged
mounted sources reconciled into temporary ObjectBox storage: **9,683 NE, 9,693 NW,
4 NW skips, 19,376 unique peaks**. Repeating NW then NE retained every ObjectBox ID.
Packaged final acceptance evidence is recorded in Work Item 12.

## Approved NE/Slovenia/Croatia precedence — 2026-10-07

L12 extends the peak policy to NE > Slovenia > Croatia. A shared app-owned
`preferredPeakSourceRegions` map controls both current-source filtering and
permitted ownership transfers. Each losing source validates its own and declared
preferred inputs before excluding overlaps, counts each skip once, and retains
skipped old rows until successful winner reconciliation. Direct Croatia-to-NE
transfers preserve user state in three-source overlaps; unrelated ownership
conflicts and user-owned/unowned records remain protected.

Regression coverage includes both pairwise import/refresh orders, all six
three-source import orders, retained IDs/user fields, protected user rows, and
missing/malformed/duplicate preferred-source failures before writes.

All unchanged mounted peak sources now reconcile successfully into temporary
ObjectBox storage: **1,032 Tasmania; 2,014 NSW; 9,683 NE; 9,693 NW; 10,833
Slovenia; 12,721 Croatia**, totaling **45,976 unique peaks**. Losing sources skip
**4 NW, 9 Slovenia, 2 Croatia** identities. Repeated reverse-order refresh retains
all IDs and user fields; all six current fingerprints are committed. Packaged
verification is recorded in Work Item 12.

## Covers

- User Stories: 1-3
- Requirements: 9, 15, 18, 25-26, 29, 31
- Technical Decisions: 7, 9, 15, 20, 31
- Testing Strategy: 3-4, 6-7, 10, 12-13, 17
- Interview Ledger: L1, L5, L6, L11-L12

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
