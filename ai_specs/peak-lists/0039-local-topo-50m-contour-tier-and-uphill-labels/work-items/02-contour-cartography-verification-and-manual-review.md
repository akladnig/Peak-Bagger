---
type: Work Item
title: Contour Cartography Verification And Manual Review
parent: ../spec.md
---

## What to build
Extend deterministic contour-cartography verification for the canonical `tasmania-local-topo` style and both OpenStreetMap comparison preview styles, `tasmania-openstreetmap-contours-martin` and `tasmania-openstreetmap-contours`, then add the committed manual-review fixture and maintainer guidance for the supported verification path. This item must update `local_topo/tasmania/tests/style.test.mjs`, add a `local_topo/tasmania/fixtures/cartography-review.json` review entry for `tasmania-openstreetmap-contours-martin`, and update the relevant maintainer docs so manual cartography verification checks representative zoom `12` and zoom `13` terrain tiles for emphasized `50 m` and `100 m` tiers, delayed `minor contour line` visibility, and contour labels that follow line direction instead of staying viewport-upright.

## Required context
- Deterministic style assertions already live in `local_topo/tasmania/tests/style.test.mjs`, with preview-style registration and comparison-style parity checks in the same file.
- Manual cartography review seams already live in `local_topo/tasmania/fixtures/cartography-review.json`, `local_topo/tasmania/scripts/review_cartography.mjs`, `local_topo/tasmania/tests/review_cartography.test.mjs`, `local_topo/tasmania/README.md`, and `local_topo/tasmania/styles/local-topo/README.md`.
- Preserve the existing local glyph contract where applicable and keep `tasmania-openstreetmap-contours-martin` as the supported manual verification path called out by the spec.
- Keep this item focused on verification artifacts for the approved contour-cartography slice; do not broaden into MapTiler preview restyling or unrelated app-facing tests.

## Acceptance criteria
- [ ] `local_topo/tasmania/tests/style.test.mjs` adds deterministic coverage for `tasmania-local-topo`, `tasmania-openstreetmap-contours-martin`, and `tasmania-openstreetmap-contours` that asserts the presence and filters of the dedicated `50 m contour` tier, the retained `100 m contour` tier, the delayed `minor contour line` visibility threshold, the presence of both `50 m` and `100 m` contour label layers, and the intended stronger `100 m` styling relative to `50 m`.
- [ ] The deterministic style coverage proves the contour label layers follow existing contour feature direction and disable viewport-upright auto-flip rather than leaving contour label orientation to default upright behavior.
- [ ] The deterministic style coverage keeps the two OpenStreetMap comparison preview styles aligned for contour-layer behavior and preserves the existing local glyph contract where applicable.
- [ ] `local_topo/tasmania/fixtures/cartography-review.json` includes a committed review entry for `tasmania-openstreetmap-contours-martin` that supports manual cartography verification at representative zoom `12` and zoom `13` terrain tiles.
- [ ] Touched maintainer docs explain the supported manual verification path through `tasmania-openstreetmap-contours-martin` and call out the zoom `12` and zoom `13` checks for emphasized tiers, the `minor contour line` threshold, and non-upright line-direction contour labels.
- [ ] Manual cartography verification is runnable against `tasmania-openstreetmap-contours-martin` without requiring changes to the app-facing basemap drawer behavior, routes, persistence, or other Flutter user flows.
- [ ] No new Flutter widget, robot, navigation, persistence, or external-service tests are added because the spec keeps this slice confined to style cartography and its local-topo verification seams.

## Covers
- Requirements: 1-8
- Testing Strategy: 1-4
- Interview Ledger: L1-L5

## Blocked by
- `01-local-topo-50m-and-100m-contour-cartography.md`
