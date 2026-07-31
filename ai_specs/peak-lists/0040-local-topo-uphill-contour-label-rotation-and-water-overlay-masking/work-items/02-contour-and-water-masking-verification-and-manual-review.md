---
type: Work Item
title: Contour And Water-Masking Verification And Manual Review
parent: ../spec.md
---

## What to build
Extend deterministic verification for `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, and `local_topo/tasmania/styles/local-topo/openstreetmap.json` so `local_topo/tasmania/tests/style.test.mjs` asserts the explicit uphill-facing contour-label rotation rule for both `50 m` and `100 m` contour label layers, verifies the style-structure contract for the targeted pond, lake, and reservoir polygon fills covering contour lines and contour labels while associated water name labels remain above the fill, and proves any river or waterway layering changes do not introduce contour-label suppression along line paths. Update the committed manual cartography review fixture and the relevant Local Topo maintainer guidance so the supported `tasmania-openstreetmap-contours-martin` review path confirms uphill-facing contour labels and the absence of contour lines or contour labels inside overlapping targeted standing-water polygons, without adding Flutter widget, robot, navigation, persistence, or external-service tests.

## Required context
- Deterministic style assertions, preview-style registration checks, and OpenStreetMap comparison parity checks already live in `local_topo/tasmania/tests/style.test.mjs`.
- Manual cartography review seams already live in `local_topo/tasmania/fixtures/cartography-review.json`, `local_topo/tasmania/scripts/review_cartography.mjs`, `local_topo/tasmania/tests/review_cartography.test.mjs`, `local_topo/tasmania/README.md`, and `local_topo/tasmania/styles/local-topo/README.md`.
- Keep `tasmania-openstreetmap-contours-martin` as the supported manual verification path and preserve the exact Spec contracts for representative zoom review expectations, targeted water masking behavior, and out-of-scope MapTiler variants.
- Keep this item focused on verification artifacts for the approved style-cartography slice; do not create separate test-infrastructure work unless a seam is independently valuable or blocks multiple slices.

## Acceptance criteria
- [ ] `local_topo/tasmania/tests/style.test.mjs` adds deterministic coverage for `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, and `local_topo/tasmania/styles/local-topo/openstreetmap.json` that asserts the contour label layers carry the explicit uphill-facing rotation rule required by this slice rather than only the prior downhill-facing line-direction behavior.
- [ ] The deterministic style coverage proves both `50 m` and `100 m` contour label layers do not allow viewport-upright auto-flipping to override the uphill-facing rule.
- [ ] The deterministic style coverage adds style-structure assertions proving the verified pond, lake, and reservoir polygon fill layers render above contour lines and contour labels, while associated water name labels remain above the water fill, for the canonical style and both OpenStreetMap comparison styles.
- [ ] The deterministic style coverage also asserts that any river or waterway layering changes do not introduce contour-label suppression along line paths.
- [ ] The verification keeps the two OpenStreetMap comparison preview styles aligned with the canonical style for the approved contour and water-masking behavior and preserves the existing local glyph contract where applicable.
- [ ] `local_topo/tasmania/fixtures/cartography-review.json` is updated so the committed `tasmania-openstreetmap-contours-martin` review path includes representative review expectations confirming uphill-facing contour labels and the absence of contour lines or contour labels inside overlapping targeted standing-water polygons.
- [ ] Touched maintainer docs explain the supported manual verification path through `tasmania-openstreetmap-contours-martin` and call out the representative review checks for uphill-facing contour labels, contour-free targeted standing-water polygon interiors, and preserved on-land contour visibility up to the shoreline.
- [ ] Manual cartography verification remains runnable against `tasmania-openstreetmap-contours-martin` without changing Flutter app navigation, basemap picker behavior, persistence, routes, or other user flows.
- [ ] No new Flutter widget, robot, navigation, persistence, or external-service tests are added because the Spec confines this slice to local-topo style cartography and its existing verification seams.

## Covers
- User Stories: 1-3
- Requirements: 1-11
- Testing Strategy: 1-4
- Technical Decisions: 1-6
- Interview Ledger: L1-L3

## Blocked by
- `01-local-topo-uphill-label-rotation-and-standing-water-masking.md`
