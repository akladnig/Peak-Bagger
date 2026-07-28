---
type: Work Item
title: Preview-Default Startup And Maintainer Workflow
parent: ../spec.md
---

## What to build
Make `npm run stack:up` start preview mode by default, preserve the explicit preview alias `npm run stack:up:preview`, add or align the explicit static startup command `npm run stack:up:static`, enforce the startup-scoped selector contracts `LOCAL_TOPO_STYLE` and `LOCAL_TOPO_TILESERVER` with supported values and defaults exactly as specified, fail fast when preview prerequisites are missing or unhealthy, and align touched maintainer helpers and documentation such as `./run_local_maps.sh` with the preview-default behavior. Preserve the unchanged app-facing raster route `/tasmania/local-topo/{z}/{x}/{y}.png` and unchanged `GET /capabilities` contract while ensuring the OSM-backed preview backend selector only retargets the OSM-backed comparison paths.

## Required context
- Current startup scripts and tests live in `local_topo/tasmania/package.json`, `local_topo/tasmania/scripts/start_stack.sh`, `local_topo/tasmania/scripts/_common.sh`, `local_topo/tasmania/tests/server.test.mjs`, and `local_topo/tasmania/README.md`.
- Touched maintainer guidance should stay consistent with `README.tasmania-elvis-local-topo.md`, `local_topo/tasmania/styles/local-topo/README.md`, and any repo-standard helper such as `run_local_maps.sh` if that helper is updated by this slice.
- This item depends on the style ids and internal runtime wiring established in `01-martin-preview-style-and-runtime-contract.md`.

## Acceptance criteria
- [x] `npm run stack:up` starts preview mode by default.
- [x] `npm run stack:up:preview` remains available as an explicit preview alias.
- [x] `npm run stack:up:static` exists as the explicit static startup command for the previous behavior.
- [x] Any touched repo-standard maintainer startup helper, including `./run_local_maps.sh`, aligns with preview-default behavior rather than preserving a separate implicit static-default path.
- [x] `LOCAL_TOPO_STYLE` is the maintainer-facing preview-style selector in this slice with supported values exactly `tasmania-openstreetmap-contours-martin`, `tasmania-openstreetmap-contours`, `tasmania-maptiler-topo`, and `tasmania-maptiler-outdoor`, and the default preview style is exactly `tasmania-openstreetmap-contours-martin`.
- [x] Static startup mode ignores `LOCAL_TOPO_STYLE` because static prerender delivery does not select an on-demand preview style.
- [x] `LOCAL_TOPO_TILESERVER=martin|tileserver` is the startup-scoped OSM-backed preview backend selector, defaulting to `martin`, and `LOCAL_TOPO_TILESERVER=tileserver npm run stack:up` remains a supported comparison path.
- [x] `LOCAL_TOPO_TILESERVER` applies only to the OSM-backed preview styles in this slice and does not retarget `tasmania-maptiler-topo` or `tasmania-maptiler-outdoor`.
- [x] The default startup path fails fast when preview prerequisites are missing or unhealthy and does not silently fall back to static prerendered tiles or deterministic smoke fixtures.
- [x] The gateway continues serving raster PNGs from `/tasmania/local-topo/{z}/{x}/{y}.png`, and `GET /capabilities` remains unchanged for the Flutter app.
- [x] Touched docs, tests, commands, and helpers use `LOCAL_TOPO_STYLE` and `LOCAL_TOPO_TILESERVER` only; this slice replaces previous maintainer environment variable names rather than supporting both in parallel.
- [x] Deterministic server-side coverage proves that `npm run stack:up` enters preview mode by default, defaults `LOCAL_TOPO_STYLE` to `tasmania-openstreetmap-contours-martin`, defaults `LOCAL_TOPO_TILESERVER` to `martin`, fails fast rather than silently falling back when preview prerequisites are missing, and keeps the unchanged raster route and unchanged `GET /capabilities` contract while `LOCAL_TOPO_TILESERVER=martin|tileserver` selects the expected internal OSM-backed preview path.

## Covers
- User Stories: 1-2
- Requirements: 1, 4-7, 17, 22-23
- Technical Decisions: 1, 4-5, 8
- Testing Strategy: 1-3, 6-7
- Interview Ledger: L1, L5, L11-L14

## Blocked by
- 01-martin-preview-style-and-runtime-contract.md
