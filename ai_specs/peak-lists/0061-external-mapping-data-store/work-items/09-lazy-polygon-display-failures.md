---
type: Work Item
title: Load Optional Polygons Lazily from Mapping Store
parent: ../spec.md
---

## What to build

Replace bundled polygon-display loading with lazy reads through the polygon-manifest allowlist. Optional entries must not block startup; their display operations report typed Mapping-store failures while retaining the map selection surface and existing usable geometry.

## Required context

- Preserve `polygon_geometry.dart` as the display parser. Catalog-required geometry is already handled by Work Item 02.
- Update `polygon_asset_repository.dart`, `polygon_assets_provider.dart`, map layers, and map-selection widget/robot seams.

## Acceptance criteria

- [x] Resolve an optional polygon only from a validated safe store-relative entry in `Polygons/manifest.json`, then canonically revalidate it immediately before opening/reading/parsing. A missing, unreadable, malformed, or outside-root target is a polygon-display Mapping failure.
- [x] Additional polygon-manifest entries are eligible only for lazy display, are never opened during preflight/catalog construction, and are validated for readability only when their display operation reads them.
- [x] Key polygon-display operations by the canonical validated store-relative path. Identical pending requests share one read and failure; distinct paths remain independent FIFO failures.
- [x] After dialog dismissal, retain the map-selection unavailable state with `map-selection-mapping-unavailable` and `map-selection-mapping-unavailable-retry`; retry rereads and reparses the same path and does not report availability before success.
- [x] Add parser/provider/widget/robot tests proving allowlist enforcement, laziness, revalidation after a symlink change, path-key single-flight behavior, state preservation, and retry.

## Covers

- User Stories: 1, 2
- Requirements: 3, 6, 9, 24-26
- Technical Decisions: 4, 9, 23-24
- Testing Strategy: 4, 10, 15
- Interview Ledger: L3, L5

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md

## Implementation notes

- The immutable ready-scope catalog carries the validated polygon-manifest allowlist. `PolygonAssetRepository` uses `MappingStoreOperationFileAccess` to revalidate each target immediately before its display read; it has no bundled manifest or silent-skip fallback.
- Per-path display operations preserve previously parsed geometry, retain failure reasons independently of dialog dismissal, and update that same feature state when either the dialog or selection-surface Retry succeeds. Distinct allowlisted filenames retain distinct operation keys, including meaningful filename whitespace.
- GPX destination lookup uses catalog-required geometry in the ready scope rather than opening optional display files. Existing import/export test seams now use explicit store-relative polygon paths.
- `polygon_geometry.dart` remains the parser and rejects non-finite/out-of-bounds coordinates. Geometry cache schema version is now 2 so geometry accepted under the older parsing semantics is rebuilt.

## Verification

- Focused parser, provider, widget, robot, resolver, and coordinator tests passed.
- `flutter test`: 2,050 passed, 5 skipped.
- `flutter analyze`: no new diagnostics; the existing 2 warnings and 7 informational diagnostics remain in track-import and route-graph code.
- `git diff --check`: passed.

### Journey Verification
- Journey: Enable polygon display, select a map location, dismiss a malformed-source failure, repair the fake store, and retry while retaining selection and usable geometry.
- Verification command(s): `flutter test test/robot/map/polygon_display_mapping_journey_test.dart`
- Required seams/selectors: injected catalog-backed polygon repository and filesystem; `show-polygons-switch`, `asset-polygon-layer`, `mapping-store-failure-dismiss`, `map-selection-mapping-unavailable`, and `map-selection-mapping-unavailable-retry`.
- Result: `pass`
- Remaining risk: Mounted-store and packaged macOS visual verification are not covered by this deterministic widget journey.
