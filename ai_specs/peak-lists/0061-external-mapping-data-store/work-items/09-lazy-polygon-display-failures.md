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

- [ ] Resolve an optional polygon only from a validated safe store-relative entry in `Polygons/manifest.json`, then canonically revalidate it immediately before opening/reading/parsing. A missing, unreadable, malformed, or outside-root target is a polygon-display Mapping failure.
- [ ] Additional polygon-manifest entries are eligible only for lazy display, are never opened during preflight/catalog construction, and are validated for readability only when their display operation reads them.
- [ ] Key polygon-display operations by the canonical validated store-relative path. Identical pending requests share one read and failure; distinct paths remain independent FIFO failures.
- [ ] After dialog dismissal, retain the map-selection unavailable state with `map-selection-mapping-unavailable` and `map-selection-mapping-unavailable-retry`; retry rereads and reparses the same path and does not report availability before success.
- [ ] Add parser/provider/widget/robot tests proving allowlist enforcement, laziness, revalidation after a symlink change, path-key single-flight behavior, state preservation, and retry.

## Covers

- User Stories: 1, 2
- Requirements: 3, 6, 9, 24-26
- Technical Decisions: 4, 9, 23-24
- Testing Strategy: 4, 10, 15
- Interview Ledger: L3, L5

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
