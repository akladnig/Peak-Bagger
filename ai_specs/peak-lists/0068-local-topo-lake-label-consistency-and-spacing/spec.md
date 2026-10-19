---
type: Spec
title: Local Topo Lake Label Consistency And Spacing
---

## Problem

Tasmania Local Topo repeats the same lake name unnecessarily at higher zooms: the supplied zoom-15 screenshot shows two “Lake Perry” labels on one small lake. Other lakes, including Hartz Lake at zooms 13 and 14, lack readable names. The desired fix distinguishes genuinely large lakes, where spaced repeats improve identification while panning, from small lakes, which should not accumulate repeated names as the user zooms in. [L1] [L7] [L8]

The current default preview style combines MBTiles `water_name` labels with Martin `water` polygon labels. This is implementation evidence to investigate, not a confirmed diagnosis of either reported defect. A styling-only change is not presumed sufficient. [L4]

## Proposed Outcome

Make lake naming consistent in the default Martin-backed Tasmania Local Topo preview at native zooms 13–18: small lakes get one stable interior label position, while lakes with actual surface area of at least 1 km² may use repeated interior labels separated by at least 512 logical map pixels. Keep lake names readable without overlapping lake-name text, demonstrate the Lake Perry and Hartz Lake fixes, and preserve the app-facing raster contract and excluded styles. [L1] [L2] [L3] [L4] [L5] [L7] [L8] [L9]

## User Stories

1. As a user viewing a small lake such as Lake Perry, I see one lake name rather than unnecessary repeated occurrences at higher zooms. [L1] [L2] [L8]
2. As a user viewing Hartz Lake at zooms 13 and 14, I can read its name even when nearby contour or road/path labels compete for space. [L1] [L3]
3. As a user panning over a large lake, I can encounter appropriately spaced repeated names without duplicate labels crowding tile seams. [L5] [L7] [L8]
4. As a maintainer, I can verify label counts, spacing, and readability through controlled automated fixtures and live cartography review without changing the Flutter app or unrelated styles. [L4] [L6]

## Requirements

1. Target only preview style `tasmania-openstreetmap-contours-martin`, currently defined by `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, using the default Martin-backed preview path. Apply the fix generally to named lakes in that path, not through Lake Perry or Hartz Lake overrides. [L2] [L4]
2. Apply the new label behavior at native zooms 13, 14, 15, 16, 17, and 18. Preserve the existing output at zooms 12 and below. Do not change native zoom limits or prerender zoom ranges. [L2] [L4]
3. Use actual lake surface area to classify size. A lake below 1,000,000 m² (1 km² or 100 hectares) is small; a lake with area equal to or above that threshold is large. Classification must not change merely because the lake occupies more screen space at a higher zoom. [L8]
4. A small lake has one stable interior label position, with at most one visible occurrence of its name across the rendered map at a given native zoom. It must not gain an additional independent label from another source layer, a tile fragment, or zooming in. Collision suppression or an offscreen anchor may leave no visible occurrence; this does not waive the specific Hartz Lake regression requirement. [L2] [L3] [L5] [L8]
5. A large lake may have multiple interior label positions. Every pair of visible repeat-label centres for that lake must be at least 512 logical map-display pixels apart at the current native zoom, including positions in different tiles. Additional positions are permitted only where the geometry, spacing, and non-overlap constraints fit; large-lake classification does not force a minimum of two labels. [L7] [L8] [L9]
6. The spacing is fixed map-display spacing, not a fraction of the current app viewport. It must be interpreted independently of PNG pixel density, including the existing `@2x` preview rendering scale. Do not introduce Flutter viewport reporting or assume a 1024-pixel-wide supported window. [L4] [L7]
7. Keep label anchors inside the corresponding lake geometry. Allow multiline wrapping and allow text to extend beyond the shoreline, particularly for small lakes. Do not change the lake's source name or introduce hardcoded label text for the reported examples. [L1] [L2] [L3] [L4]
8. Prefer lake names over competing contour-elevation and road/path labels. Retain collision detection between lake names: neither separate lakes nor repeated names within a large lake may be forced into overlapping text. The 512-pixel repeat spacing is not permission to overlap longer text. [L3] [L7] [L9]
9. Placement must be lake-based rather than independently regenerated for each tile or requested viewport. Tile boundaries must not create duplicate small-lake labels or violate large-lake repeat spacing. Preserve distinct identities for separate lakes with the same name rather than deduplicating solely by label text. [L5] [L7]
10. Lake Perry must remain in the small-lake category and show one name when its label position is visible at zooms 15–18. Its zoom-15 output must no longer reproduce the two-name defect in the supplied screenshot. [L1] [L6] [L8]
11. Hartz Lake must have a readable name at zooms 13 and 14 in representative map views containing the lake. Establish the actual source-feature and property cause of its missing label instead of assuming that a font-size adjustment alone fixes it. [L1] [L3] [L6]
12. Preserve river/stream naming, unrelated map styling, standing-water contour masking, terrain relief, and contour geometry/tier behavior. Local collision priority changes needed by requirement 8 are allowed; do not globally remove road/path or contour labels to achieve lake readability. [L3] [L4] [L6]
13. Necessary lake-label source, import, derived-data, and rebuild changes are allowed. Use the existing selected Tasmania OSM source rather than lake-specific names or identity overrides. Do not require rebuilding unrelated contours or terrain relief as part of applying this fix. Preserve existing staged preview publication and failure protection if import or publication code is touched. [L4]
14. Preserve the app-facing `Local Topo` label, `/tasmania/local-topo/{z}/{x}/{y}.png` route, `GET /capabilities`, base-URL configuration, and basemap controls. No Flutter application changes are part of this slice. [L4]
15. Leave legacy preview style `tasmania-openstreetmap-contours`, MapTiler Topo/Outdoor variants, and canonical/static-bake style behavior unchanged. Shared source changes must not alter those excluded outputs. [L4]
16. Completion requires both fixture-based automated regression coverage and live visual verification, including adjacent-tile views. A successful fixture download or structural JSON assertion alone does not establish rendered label count, spacing, or readability. [L6] [L7] [L8]

## Technical Decisions

1. Adopt the project-local App Development Standard revision **ADS-1.0** in `ai_specs/coding-rules.md` and the **Desktop wide, macOS-only** profile in `ai_specs/app-profile.md`. This is server-side cartography/data work, not window or UI layout work: preserve the app's wide/maximised-launch target without introducing narrow/iOS obligations. Minimum usable width/height, supported resize range, native full-screen choice, and affected wide-layout thresholds remain named `Pending` decisions in the profile; this work does not depend on or resolve them. ObjectBox, Riverpod, and GoRouter remain unchanged. Domain cartography colours remain domain styling, not a request to restyle Flutter controls. [L4]
2. Verify the actual Lake Perry and Hartz Lake source features, geometries, classification properties, and active label layers before selecting the smallest reliable implementation. Current `Lakeline labels` and `Water labels` read MBTiles `water_name`, while `Natural water labels` reads Martin `water` with a `class == water` filter. These competing paths are investigation targets, not proof of the root cause. Confirm both reported lakes use the intended generalized path. [L1] [L4]
3. Compute physical size and lake-level placement from the full source lake geometry, before tile clipping. Use a ground-area calculation rather than treating Web Mercator square metres as uncorrected surface area. Preserve polygon holes and source feature identity; tile fragments must not become separate lakes. The precise data representation, placement algorithm, and retained/rewired label layers are implementation choices constrained by the required rendered behavior. [L5] [L7] [L8]
4. Keep position generation independent of viewport dimensions and per-tile fragment centres. Normalize repeat spacing to logical map-display pixels so higher-density raster output does not silently halve or double the intended display separation. Small lakes retain one stable anchor; large-lake repeat density may respond to native zoom while respecting the area threshold and spacing. [L5] [L7] [L8]
5. Extend the existing Node fixture/test seams rather than requiring production data or live services in ordinary automated tests. Prefer the style loader/assertions in `tests/style.test.mjs`, controlled shell-command workspaces in `tests/rebuild_scripts.test.mjs`, injected `fetchImpl` and `outputRoot` in `scripts/review_cartography.mjs`, and style-keyed fixtures in `fixtures/cartography-review.json`. Where actual placement behavior lacks a callable deterministic seam, add the smallest boundary needed to exercise the production placement rules with controlled geometry rather than testing a disconnected duplicate algorithm. [L6]
6. Update existing Martin-versus-legacy parity assertions only for the intentional lake-label divergence. Earlier Spec 0037 restricted the initial migration to compatibility edits; this later, explicitly accepted cartography change supersedes that restriction for the affected Martin lake-label path only. Earlier Spec 0040 aligned contour masking across three styles; this Spec does not change that contour contract or extend the lake-label fix into those other styles. Retain unrelated parity and masking assertions. No general shared-foundation exception is requested or inferred. [L4]
7. Retain existing preview data preparation/publication boundaries: preparation belongs in an explicit maintainer rebuild/refresh operation, not tile requests or startup. If new prepared label data is needed, document the bounded way to prepare and activate it without regenerating DEM products. Reuse existing active/staged dataset protection and clear failure reporting rather than publishing partial label data or silently falling back to an excluded style. [L4]

## Testing Strategy

1. Add deterministic behavior tests for lake-area classification immediately below, exactly at, and above 1,000,000 m². Verify that zoom changes do not reclassify small lakes and that classification uses whole-lake physical area, not clipped fragments or apparent screen size. Include controlled closed-way and relation/multipolygon cases where supported by the affected production source path. [L6] [L8]
2. Exercise the production placement rules with controlled small and large lake fixtures across native zooms 13–18. Verify one stable small-lake anchor, interior placement including holes, permitted wrapping, large-lake repetition only where it fits, and at least 512 logical map-display pixels between repeat-label centres. Include a large lake that cannot fit a second label without violating the constraints. [L2] [L5] [L6] [L7] [L8] [L9]
3. Test adjacent tile requests and their combined results: no independently generated duplicate anchor at a seam, no two repeat centres below the spacing threshold, and no same-name merging of separate lakes. Verify repeat spacing for normal and `@2x` raster scales without changing the physical-area classification. [L5] [L6] [L7] [L8]
4. Extend deterministic style/configuration assertions for lake-name priority over contour and road/path labels, retained lake-name collision handling, enabled applicable label paths at zooms 13 and 14, and removal or filtering of competing lake labels at zooms 13–18. Preserve checks for lower-zoom behavior, river/stream labels, masking, and excluded style outputs. Structural assertions complement, but do not replace, placement tests and visual checks. [L2] [L3] [L4] [L6]
5. If preparation or publication changes, extend existing controlled command/workspace tests to cover the lake-label input/output selection, explicit rebuild boundary, preservation of active data on failure, and absence of unrelated contour/relief regeneration. Ordinary automated tests require no Docker Compose, live PostGIS/Martin, downloads, credentials, or personal mapping datasets. [L4] [L6]
6. Extend the Martin style's committed cartography-review fixtures and relevant maintainer guidance. Capture Lake Perry at zooms 15, 16, 17, and 18 and Hartz Lake at zooms 13 and 14. Select a verified large lake of at least 1 km², with Lake St Clair as a candidate, and inspect repeat spacing and readability across adjacent rendered tiles and while panning. Confirm separate nearby lake names do not overlap. [L1] [L3] [L6] [L7] [L8]
7. Compare zoom-12-and-below reference output and representative river/stream labels before and after the change. Verify contour masking, shoreline-adjacent land contours, terrain relief, and excluded styles remain unchanged apart from the explicitly permitted local collision-priority effects in the affected zoom range. [L2] [L4] [L6]
8. Run focused affected Node tests during implementation and the complete `npm test` suite from `local_topo/tasmania` before completion. For live visual verification use the existing preview and review entrypoints:
   ```bash
   LOCAL_TOPO_STYLE=tasmania-openstreetmap-contours-martin LOCAL_TOPO_TILESERVER=martin npm run stack:up:preview
   npm run review:cartography -- --style-id=tasmania-openstreetmap-contours-martin
   ```
   Prepare any changed lake-label data through the documented bounded preparation path first. Review current tiles rather than stale cached imagery, record style/zoom/tile or map-view context and results, and distinguish captured PNGs from actually inspected visual outcomes. Live services are required for this separate visual acceptance step, not for ordinary automated tests. No Flutter widget, robot, platform build, or persistence migration verification is added because Flutter behavior and code remain unchanged. [L4] [L6]

## Out of Scope

1. Exact quarter-viewport spacing, Flutter viewport reporting, app-side lake-label overlays, and new basemap controls or routes. [L4] [L7]
2. Lake naming changes at zooms 12 and below; changing river/stream labels, unrelated cartography, or contour/DEM generation. [L2] [L4] [L6]
3. Updating legacy preview, MapTiler Topo/Outdoor, or canonical/static-bake styles; static rerendering or altered prerender zoom ranges. [L4]
4. Lake-specific source-name overrides or special-casing Lake Perry/Hartz Lake to make the examples pass. [L4]
5. Forcing repeats for lakes smaller than 1 km², forcing two labels onto a large lake without sufficient room, overlapping lake-name text, or guaranteeing a visible name in every possible partial-lake viewport. [L3] [L5] [L7] [L8]
6. Defining new macOS window dimensions, changing mandatory application foundations, or adding compact/iOS support. [L4]

## Notes

1. Required project context: `AGENTS.md`, `.act/workflow.md`, `.act/config.yaml`, `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`, and this Spec's sibling `interview-ledger.md`. Relevant historical context includes Specs 0037 and 0040; inspect actual source rather than treating historical implementation assumptions as current facts.
2. Likely implementation evidence and touchpoints include `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, `local_topo/tasmania/config/osm2pgsql/preview-flex.lua`, the actual preview SQL/configuration and rebuild entrypoints, `local_topo/tasmania/tests/style.test.mjs`, `local_topo/tasmania/tests/rebuild_scripts.test.mjs`, `local_topo/tasmania/fixtures/cartography-review.json`, and `local_topo/tasmania/scripts/review_cartography.mjs`. These are investigation locations, not a preselected implementation or Work Item breakdown.
3. `~/Desktop/lp15.png` was inspected during the interview and establishes the reported two-label zoom-15 defect. It is user-provided local evidence, not a portable automated-test dependency; create controlled regression fixtures rather than requiring that Desktop file on other machines. [L1] [L6]
4. No product Blocking Questions remain. The exact root causes, placement/data implementation, and representative large-lake review coordinates require implementation investigation and verification; they are not approval to relax the accepted area, spacing, readability, or scope contracts.

## Implementation Acceptance

Completed 2026-10-19; evidence and exact live contexts are recorded in
[verification.md](verification.md).

- [x] Martin-preview-only lake path at native zooms 13–18; lower zooms, excluded styles, native limits and prerender ranges preserved. (Requirements 1–2, 15)
- [x] Whole-lake geography area with inclusive 1 km² classification; one stable small-lake anchor and interior large-lake repeats at least 512 logical pixels apart. (3–7, 9; L9 follow-up verified)
- [x] Wrapping, lake-name priority and retained lake-name collision handling; no source-name, example-identity or viewport overrides. (6–9)
- [x] Lake Perry visibly has one name at zooms 15–18; actual Hartz source/zoom cause established and readable names inspected at zooms 13–14. (10–11)
- [x] River/stream naming, relief, contour geometry/tiers/masking and unrelated styling preserved, with isolated lower-zoom and excluded-style comparisons. (12, 15)
- [x] Bounded prepared-label refresh and full-import integration preserve staging/failure protection without contour/relief regeneration. (13)
- [x] App-facing label, raster route, capabilities, configuration and controls unchanged; no Flutter changes. (14)
- [x] Deterministic fixtures, focused checks, complete Node suite and inspected live adjacent-tile/scale/pan outcomes recorded. (16; Testing Strategy 1–8)
