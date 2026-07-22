---
type: Work Item
title: Localized MapTiler Preview Styles
parent: ../spec.md
---

## What to build
Add `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` as preview-only TileServer style variants under `local_topo/tasmania/`. This slice must treat downloaded MapTiler `Topo` and `Outdoor` style JSON as source material only, rewrite both styles onto the committed Tasmania local preview sources, preserve the phase 1 `Local Topo` app contract unchanged, localize each style `sprite` base to the committed local `sprite` path with committed `sprite` and `sprite@2x` assets, keep `glyphs` on `{fontstack}/{range}.pbf`, and commit a machine-readable per-style `.port-decisions.json` artifact that records non-trivial upstream-to-local rewrite exceptions only.

## Required context
- Keep project terminology aligned with `GLOSSARY.md`, especially `Local Topo`, `MapTiler Topo`, `MapTiler Outdoor`, `Local Topo tile source`, and `terrain relief shading`.
- `local_topo/tasmania/config/tileserver-config.json` is the committed source of truth for style ids and local source names.
- Phase 1 is preview-only. Do not add `MapTiler Topo` or `MapTiler Outdoor` to the current app basemap picker, generated `Basemap` enum, or `GET /capabilities` output.
- The existing `tasmania-openstreetmap-contours` preview variant predates this Spec's asset rules and is not the contract to copy for the new MapTiler-derived variants.

## Acceptance criteria
- [x] `local_topo/tasmania/config/tileserver-config.json` registers `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` beside the existing preview styles and points each id at a committed local style JSON file.
- [x] The committed preview variants are rewritten onto the existing local Tasmania preview source contract already supported by the stack rather than retaining MapTiler-hosted vector tiles at runtime.
- [x] Each new style keeps the existing local glyph contract exactly as `{fontstack}/{range}.pbf` and localizes `sprite` to the committed local `sprite` base while relying only on committed `local_topo/tasmania/sprites/` assets, including both the `sprite` and `sprite@2x` pairs.
- [x] Surviving text layers in both styles use the committed `Roboto Regular` local glyph contract, and any unsupported upstream font, source-layer, or behavior dependency is restyled as text-only, dropped, or otherwise documented without leaving a live external dependency.
- [x] The rewrites remain close visual ports of upstream MapTiler `Topo` and `Outdoor` within the limits of the local Tasmania sources by preserving original layer ordering, paint, and layout rules where they map cleanly while allowing source remaps, sprite localization, text-only rewrites, missing-layer drops, and small label substitutions where needed.
- [x] Each style has a committed sibling `.port-decisions.json` artifact whose records use only `source_remap`, `font_rewrite`, `text_only`, `dropped`, `unsupported_layer`, or `other`, and each record includes `upstreamLayerId`, `issueType`, `action`, and `reason`, with optional `notes` only when needed.
- [x] The phase 1 app-facing contract remains one logical `localTopo` basemap labeled `Local Topo`, and this slice does not redefine the production style, prerender output path, or current user-facing basemap behavior.

## Covers
- User Stories: 1-3
- Requirements: 1-11, 13
- Technical Decisions: 1-7
- Testing Strategy: 1-3, 7
- Interview Ledger: L1-L6

## Blocked by
None - ready to start
