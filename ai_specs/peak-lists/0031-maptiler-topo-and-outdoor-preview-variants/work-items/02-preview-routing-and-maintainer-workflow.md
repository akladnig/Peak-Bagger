---
type: Work Item
title: Preview Routing And Maintainer Workflow
parent: ../spec.md
---

## What to build
Extend the deterministic preview-stack verification and maintainer workflow so both new MapTiler-derived preview variants keep the unchanged `/tasmania/local-topo/{z}/{x}/{y}.png` route, stay startup-selected only through `LOCAL_TOPO_PREVIEW_STYLE_ID=... npm run stack:up:preview`, and are documented as fully local preview styles that no longer require a MapTiler API key after the rewrite is committed.

## Required context
- Preserve the existing app-facing `GET /capabilities` contract and the single `Local Topo` basemap entry while proving preview selection only affects the internal TileServer style backend.
- Reuse the deterministic local-topo test seams under `local_topo/tasmania/tests/` and treat `styleId` or `TILESERVER_STYLE_ID` as internal test seams only.
- Documentation should cover the exact maintainer commands and configuration values defined by the Spec, including `LOCAL_TOPO_PREVIEW_STYLE_ID` and `npm run stack:up:preview`.

## Acceptance criteria
- [ ] Automated server-side style coverage under `local_topo/tasmania/tests/` proves that `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` are registered, load committed local style JSON files, keep the local glyph contract, localize the `sprite` base to the committed local `sprite` path, keep the committed `sprite` and `sprite@2x` pairs available locally, and do not retain remote `sources`, `sprite`, or `glyphs`.
- [ ] Automated preview-route coverage proves that startup with each of `LOCAL_TOPO_PREVIEW_STYLE_ID=tasmania-maptiler-topo` and `LOCAL_TOPO_PREVIEW_STYLE_ID=tasmania-maptiler-outdoor` still serves the unchanged `/tasmania/local-topo/{z}/{x}/{y}.png` route through the selected style backend.
- [ ] Preview switching remains startup-scoped only through `LOCAL_TOPO_PREVIEW_STYLE_ID=... npm run stack:up:preview`; this slice does not add in-app runtime switching, multiple capability-advertised local-topo styles, or a user-editable style chooser.
- [ ] The local style documentation explains how to download MapTiler style JSON with a local-only key, rewrite both styles onto local Tasmania sources, localize the `sprite` base while keeping `sprite` and `sprite@2x` assets committed and glyphs local, run each preview variant by style id, and understand that the later basemap-picker work is a separate phase.
- [ ] The committed repo state does not require a MapTiler API key after the localized preview rewrites are complete.

## Covers
- User Stories: 1-2
- Requirements: 2, 4, 7, 10-12
- Technical Decisions: 1-4, 7
- Testing Strategy: 1-4, 7
- Interview Ledger: L1, L4, L6

## Blocked by
- 01-localized-maptiler-preview-styles.md
