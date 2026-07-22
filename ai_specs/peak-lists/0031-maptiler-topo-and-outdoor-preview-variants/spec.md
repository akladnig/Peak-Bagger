---
type: Spec
title: MapTiler Topo And Outdoor Preview Variants
---

## Problem

The Tasmania `Local Topo` stack already supports one canonical committed style plus one alternate preview style, and the repo documents how to download MapTiler styles as starting material, but it does not yet define how MapTiler `Topo` and `Outdoor` should be integrated into the project-managed local preview workflow. The app also needs durable terminology for a later phase that adds these styles as separate user-facing basemaps without overloading the existing `Local Topo` contract. [L1] [L2] [L3] [L4] [L6]

## Proposed Outcome

Add two committed Tasmania preview style variants derived from MapTiler `Topo` and `Outdoor`, rewritten onto the repo's local Tasmania sources so preview stays fully project-managed, and selectable through the existing preview-stack startup mechanism. Keep the current `Local Topo` app contract unchanged in phase 1, while reserving `MapTiler Topo` and `MapTiler Outdoor` as the canonical future basemap names for a later picker-facing phase. [L1] [L2] [L3] [L4] [L5] [L6]

## User Stories

1. As a maintainer, I can take MapTiler `Topo` and `Outdoor` style JSON as source material, rewrite each one onto the existing Tasmania local preview sources, commit the result, and preview each variant without introducing a new live external tile dependency. [L1] [L4]
2. As a maintainer reviewing cartography, I can switch the Tasmania preview stack between the canonical `Local Topo` style, `MapTiler Topo`, and `MapTiler Outdoor` at startup and compare representative tiles while keeping the app-facing preview route unchanged. [L1] [L5] [L6]
3. As a future `Peak Bagger` user, I can eventually see `MapTiler Topo` and `MapTiler Outdoor` as distinct basemaps in the app picker rather than ambiguous variants of `Local Topo`. [L2] [L3]

## Requirements

1. Phase 1 is limited to preview-mode style integration. It must not add `MapTiler Topo` or `MapTiler Outdoor` to the current app basemap picker, generated `Basemap` enum, or `GET /capabilities` output yet. `Local Topo` remains the sole current app-facing basemap label and capability contract in this slice. [L2] [L6]
2. Preserve the existing preview route and app-facing local-topo contract in phase 1. Preview requests must continue to flow through `/tasmania/local-topo/{z}/{x}/{y}.png`, and the capability contract must remain one logical `localTopo` basemap labeled `Local Topo`. [L2] [L6]
3. Reserve the future app-facing basemap terms `MapTiler Topo` and `MapTiler Outdoor` as the canonical picker labels for the later user-facing phase. Reserve `maptilerTopo` and `maptilerOutdoor` as the future internal basemap keys for that phase. [L3]
4. Add two preview style ids aligned with those future names: `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor`. Register them in `local_topo/tasmania/config/tileserver-config.json` beside the existing preview styles. [L3] [L6]
5. Treat downloaded MapTiler `Topo` and `Outdoor` style JSON as source material only. The committed preview variants must be rewritten onto the repo's local Tasmania sources already supported by the preview stack rather than depending on MapTiler-hosted vector tiles at runtime. [L1] [L4]
6. The rewritten styles must target the existing local preview source contract and stay compatible with the current TileServer GL stack, including the committed local source names already aligned with `local_topo/tasmania/config/tileserver-config.json`. [L4]
7. The rewritten variants must preserve the current `Local Topo` glyph contract and use committed local sprite assets only. Phase 1 must not introduce a remote glyph dependency, a remote sprite dependency, or a committed secret-bearing asset URL. The new variants must reuse the committed sprite bundle under `local_topo/tasmania/sprites/`, localize their style `sprite` base to the committed local `sprite` path, and keep both the `sprite` and `sprite@2x` pairs committed so standard- and high-DPI clients stay local. Surviving text layers in the new variants must use the committed local glyph contract with `Roboto Regular` as the phase 1 font family. If a MapTiler layer depends on unsupported fonts, unsupported source layers, or other upstream behavior that the local Tasmania stack cannot support, the rewrite must restyle that layer as text-only, drop it, or otherwise document the exception rather than keep a live external dependency. [L4] [L5]
8. Treat the phase 1 rewrites as close visual ports of the downloaded MapTiler styles within the limits of the local Tasmania sources. Preserve original layer ordering, paint, and layout rules where they map cleanly; allow source remapping, committed local sprite-base localization, text-only rewrites, missing-layer drops, and small label substitutions where the local data or committed local assets lack equivalent support. [L5]
9. Each rewritten variant must include a committed machine-readable per-style port-decision artifact as a JSON sibling of the variant style JSON, using the same basename plus `.port-decisions.json`. The artifact records only non-trivial upstream-to-local rewrite exceptions for that style rather than every unchanged layer. Each record must identify the `upstreamLayerId`, an `issueType` from `source_remap`, `font_rewrite`, `text_only`, `dropped`, `unsupported_layer`, or `other`, the chosen `action`, and a short `reason`; optional freeform `notes` may add context. Localizing the remote MapTiler sprite base onto the committed local `sprite` path, with the committed `sprite@2x` pair present for high-DPI loading, is a required style-wide contract that tests must assert directly and does not need per-layer duplication unless a specific layer needs extra explanation.
10. Keep the preview-switching mechanism startup-scoped in phase 1. Developers must select the active variant only through `LOCAL_TOPO_PREVIEW_STYLE_ID=... npm run stack:up:preview`, not through in-app runtime switching, not through multiple capability-advertised local-topo styles, and not through a user-editable style chooser. `TILESERVER_STYLE_ID` remains an internal implementation seam rather than a maintainer-facing contract. [L6]
11. Phase 1 must keep the existing static production stack and canonical `Local Topo` app contract intact. Adding the new preview variants must not, by itself, redefine the production style, the prerender output path, or the current `Local Topo` user-facing behavior. [L2] [L6]
12. Update the local style documentation so maintainers can:
    - download MapTiler style JSON with a local-only key
    - rewrite the styles to local Tasmania sources
    - localize the sprite base to the committed local `sprite` path while keeping both `sprite` and `sprite@2x` assets and keeping glyphs local
    - run each preview variant by style id
    - understand that the later basemap-picker work is a separate phase

    The committed repo state must not require a MapTiler API key after the rewrite is complete. [L1] [L4] [L6]
13. The later app-facing phase must surface `MapTiler Topo` and `MapTiler Outdoor` as separate basemap entries rather than reusing the `Local Topo` label for them. [L2] [L3]

## Technical Decisions

1. Keep one logical `Local Topo` app contract in phase 1 and model the new styles as TileServer preview variants only. This preserves the existing Flutter runtime, capability parsing, and preview route while the cartography work is explored. [L2] [L6]
2. Use `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` as preview style ids now so the preview naming already aligns with the future picker-facing basemap names and keys. [L3] [L6]
3. Rewrite the downloaded styles onto the existing local Tasmania preview sources rather than preserving live MapTiler-hosted assets. This keeps preview fully project-managed and avoids carrying external tile dependencies or secrets into the committed workflow. [L4]
4. Reuse the committed local sprite bundle already checked into `local_topo/tasmania/sprites/` for the new MapTiler-derived variants, and localize the style `sprite` base to the committed local `sprite` path while keeping the committed `sprite@2x` pair available for high-DPI loading. Normalize surviving label layers onto the existing local glyph workflow with `Roboto Regular` rather than preserving upstream `Open Sans` or `Noto Sans` dependencies. [L4] [L5]
5. Treat the MapTiler styles as close visual reference ports, not strict pixel-parity clones. This allows the repo to preserve recognizable styling intent while staying honest about differences in source layers, icon availability, label data, and committed local asset coverage. [L5]
6. Record only non-trivial upstream-to-local rewrite exceptions in a committed per-style JSON port-decision artifact so the local ports remain reviewable and testable without forcing bookkeeping for unchanged layers. [L4] [L5]
7. Keep preview selection as an environment-driven stack startup choice rather than a new Flutter-side state-management path. This is the smallest correct bridge between the current preview workflow and the later basemap-picker phase. `LOCAL_TOPO_PREVIEW_STYLE_ID` is the maintainer-facing contract; `TILESERVER_STYLE_ID` is internal stack wiring. [L6]

## Testing Strategy

1. Add deterministic server-side style coverage under `local_topo/tasmania/tests/` proving that `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` are registered in `config/tileserver-config.json`, load committed local style JSON files, use the expected local glyph contract, localize the style `sprite` base to the committed local `sprite` path, keep the committed `sprite` and `sprite@2x` pairs available locally, and do not retain remote `sources`, `sprite`, or `glyphs`. [L4] [L6]
2. Add deterministic style-structure checks for the rewritten variants that verify the expected local Tasmania sources are referenced, the style `sprite` field resolves to the committed local `sprite` base, the committed `sprite` and `sprite@2x` pairs exist locally for standard- and high-DPI loading, surviving `text-font` entries resolve to the committed `Roboto Regular` local glyph contract, and documented rewrite exceptions match their committed per-style port-decision artifacts. Prefer JSON assertions over live network rendering. [L4] [L5]
3. Add deterministic checks proving each new variant has the required committed per-style JSON port-decision artifact, that every artifact record uses the allowed exception categories and required fields, and that documented exceptions are reflected in the localized style JSON where directly assertable. [L4] [L5]
4. Extend the preview-stack coverage so startup with each new `LOCAL_TOPO_PREVIEW_STYLE_ID` still serves the unchanged `/tasmania/local-topo/{z}/{x}/{y}.png` route through the selected style backend. If lower-level server routing is tested directly, treat `styleId` or `TILESERVER_STYLE_ID` as an internal test seam only. [L2] [L6]
5. Add or update manual cartography review guidance for representative low-, mid-, and high-zoom Tasmania tiles for both new variants. Represent those review expectations in a variant-scoped fixture keyed by preview style id, even when multiple variants reuse the same tile coordinates. Review runs must write captures under `runtime/review/cartography/<styleId>/` or an equivalently variant-scoped output layout so captures for `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` do not overwrite each other, and the guidance must include variant-specific expectation notes for those representative tiles. Review should confirm the variants read as close visual ports of MapTiler `Topo` and `Outdoor` while remaining source-limited Tasmania-local styles. [L5] [L6]
6. Phase 1 does not require new Flutter widget or robot coverage because the app basemap picker behavior is intentionally unchanged. The later picker-facing phase should add widget and robot coverage for the new basemap entries using the existing stable basemap option selectors. [L2] [L3]
7. Keep automated tests free of live MapTiler API keys and real MapTiler network calls. Prefer committed JSON fixtures, local style files, and existing server test seams. [L1] [L4]

## Out of Scope

1. Adding `MapTiler Topo` or `MapTiler Outdoor` to the current app basemap picker in phase 1. [L2] [L3]
2. Changing the current `GET /capabilities` schema or advertising multiple local-topo style choices from the server in phase 1. [L2] [L6]
3. In-app runtime preview switching, user-editable style selection, or a developer UI for style ids in phase 1. [L6]
4. Keeping MapTiler-hosted vector tiles, glyphs, or sprites as a live runtime dependency after the rewrite is complete. [L4]
5. Exact pixel-for-pixel cartographic parity with upstream MapTiler rendering when the local Tasmania sources do not expose matching data or assets. [L5]

## Follow-Ups

1. Add `MapTiler Topo` and `MapTiler Outdoor` as separate app-facing basemap entries in a second phase using the reserved keys `maptilerTopo` and `maptilerOutdoor`. [L2] [L3]
2. Define how the later picker-facing phase should source tile URLs, attribution, cache participation, and region availability for those new basemap entries without weakening the existing `Local Topo` contract. [L2] [L3]

## Notes

1. Likely phase 1 touchpoints include `local_topo/tasmania/config/tileserver-config.json`, `local_topo/tasmania/styles/local-topo/README.md`, `local_topo/tasmania/styles/local-topo/`, `local_topo/tasmania/scripts/start_stack.sh`, and `local_topo/tasmania/tests/style.test.mjs`.
2. The existing `tasmania-openstreetmap-contours` preview variant predates the asset policy in this Spec and is not the contract to copy for the new MapTiler-derived variants.
3. Existing project terminology now reserves `MapTiler Topo` and `MapTiler Outdoor` in `GLOSSARY.md` so later picker work can stay distinct from `Local Topo`.
