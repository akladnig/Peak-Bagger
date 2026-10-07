---
type: Work Item
title: Update TasMap Transactionally from Mapping Store
parent: ../spec.md
---

## What to build

Replace asset-backed TasMap loading with manifest-backed bootstrap and the exact transactional `Update Map Data` journey. Parse the CSV as quoted RFC 4180 and reconcile ObjectBox rows atomically without clearing usable map state on any read or parse failure.

## Required context

- Update `csv_importer.dart`, `tasmap_repository.dart`, `tasmap_provider.dart`, map state, Settings, and TasMap robot/widget tests.
- Existing selection and tile-cache/map state must rehydrate after a successful update; route all source faults through the shared Mapping failure coordinator.

## Acceptance criteria

- [x] Render exactly `Update Map Data`, subtitle `Update TasMap sheets from Mapping data store`, confirmation title `Update Map Data?`, primary action `Update`, and renamed stable controls `update-map-data-*` instead of `reset-map-data-*`.
- [x] Require only the named canonical headers `Series`, `Name`, `Parent`, `MGRS`, `eastingMin`, `eastingMax`, `northingMin`, `northingMax`, `mgrsMid`, `eastingMid`, `northingMid`, and `p1` through `p12`; allow blank `Parent` values; reject duplicate or unknown non-empty headers, header-only files, malformed nonblank rows, and all invalid text/integer/point contracts.
- [x] Accept a contiguous 4, 6, 8, 10, or 12 normalized 12-character point polygon beginning at `p1` through `p4`, with only contiguous optional `p5` through `p12`; ignore blank rows and trailing empty header columns.
- [x] After full successful parsing, reconcile by unique `(series.trim().toLowerCase(), name.trim().toLowerCase())`: insert new rows, update changed rows in place, perform no write for unchanged rows, retain ObjectBox IDs, delete omitted rows, and clear selection when its identity is removed.
- [x] Before reconciliation, collapse duplicate stored identities: retain the lowest positive ObjectBox ID, update that survivor, delete duplicates in the same transaction, retarget a selected deleted duplicate to its survivor, and clear selection when the identity is absent from CSV.
- [x] A read or parse failure writes nothing, preserves rows, selection, and revision, and reports operation `TasMap update`; successful reconciliation rehydrates a surviving selection by ObjectBox ID and refreshes dependent map/tile-cache state.
- [x] Bootstrap reads only when the TasMap table is empty and is unavailable while pending/failed rather than silently empty. Map-selection unavailability uses `map-selection-mapping-unavailable` and `map-selection-mapping-unavailable-retry` after dialog dismissal.
- [x] Add unit/repository/widget/robot tests for RFC 4180 quoting, all validation conditions, duplicate migrations, no-write unchanged rows, selection behavior, exact UI keys/text, and retry/preservation behavior.

## Covers

- User Stories: 1, 2
- Requirements: 9, 12, 16-17, 24-26
- Technical Decisions: 4, 9, 15
- Testing Strategy: 3-4, 7-8
- Interview Ledger: L1, L5

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
