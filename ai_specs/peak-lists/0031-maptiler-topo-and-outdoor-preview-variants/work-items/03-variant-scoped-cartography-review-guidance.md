---
type: Work Item
title: Variant-Scoped Cartography Review Guidance
parent: ../spec.md
---

## What to build
Add variant-scoped manual cartography review guidance for `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` so maintainers can compare representative low-, mid-, and high-zoom Tasmania tiles for each preview style without capture outputs overwriting one another.

## Required context
- Phase 1 does not require new Flutter widget or robot coverage because the app basemap picker is intentionally unchanged.
- Reuse the existing cartography review fixture and review command conventions under `local_topo/tasmania/`, but expand them to carry per-style expectations instead of a single shared expectation list.

## Acceptance criteria
- [x] Manual cartography review guidance covers representative low-, mid-, and high-zoom Tasmania tiles for both `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor`.
- [x] The review expectations are represented in a variant-scoped fixture keyed by preview style id, even when multiple variants reuse the same tile coordinates.
- [x] Review runs write captures under `runtime/review/cartography/<styleId>/` or an equivalently variant-scoped output layout so captures for `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` do not overwrite each other.
- [x] The guidance includes variant-specific expectation notes confirming that both variants read as close visual ports of upstream MapTiler `Topo` and `Outdoor` while remaining source-limited Tasmania-local styles.

## Covers
- User Stories: 2
- Requirements: 8, 12
- Technical Decisions: 5, 7
- Testing Strategy: 5-6
- Interview Ledger: L5-L6

## Blocked by
- 01-localized-maptiler-preview-styles.md
