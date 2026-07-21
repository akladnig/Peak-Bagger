---
type: Work Item
title: Shared HTTP Delivery Contract For Static And On Demand Local Topo
parent: ../spec.md
---

## What to build
Extend the Tasmania `Local Topo tile source` delivery stack so both backend modes preserve one public HTTP contract while separating their operational roles: production serves pre-rendered static `XYZ` PNG tiles, and developer or maintenance workflows retain explicit on-demand rendering for preview and spot checks. This slice must keep `GET /capabilities` and `/tasmania/local-topo/{z}/{x}/{y}.png` unchanged from the app's perspective and must not introduce runtime mixed availability or automatic per-tile fallback between static and on-demand sources.

## Required context
- `local_topo/tasmania/server/app.mjs`, `local_topo/tasmania/fixtures/capabilities.json`, `local_topo/tasmania/tests/server.test.mjs`, and `local_topo/tasmania/scripts/smoke.mjs` are the existing seams for the public HTTP contract and deterministic server-side verification.
- `local_topo/tasmania/docker-compose.yml`, `local_topo/tasmania/config/tileserver-config.json`, and `local_topo/tasmania/scripts/start_stack.sh` already separate stack startup concerns from the Flutter app. Preserve that external boundary.
- The Spec treats missing supported production tiles as defects rather than normal runtime behavior. Do not design automatic runtime fallback from static tiles to on-demand rendering.

## Acceptance criteria
- [ ] `GET /capabilities` remains required and continues to return the existing shared `Local Topo` contract without adding max-zoom fields or any other public schema change that would force the app to distinguish static versus on-demand delivery.
- [ ] Tasmania `Local Topo` tiles remain publicly addressed as `/tasmania/local-topo/{z}/{x}/{y}.png` in both backend modes.
- [ ] Production delivery serves pre-rendered static PNG tiles under the deterministic production layout `tasmania/local-topo/{z}/{x}/{y}.png` as the only production path behind the existing public contract.
- [ ] Developer and maintenance workflows can still run explicit on-demand rendering for style iteration and spot checks without changing the app-facing contract.
- [ ] This slice does not require runtime mixed availability or automatic per-tile fallback between static and on-demand sources, and missing supported production tiles fail as defects rather than falling back to on-demand rendering.
- [ ] Deterministic server-side coverage proves the shared HTTP contract in both delivery modes, including `GET /capabilities`, Tasmania tile-route resolution, static production serving, and explicit developer-mode on-demand serving, without depending on live LAN or upstream source availability.

## Covers
- User Stories: 1, 3-4
- Requirements: 3-5, 20
- Technical Decisions: 1-3
- Testing Strategy: 1
- Interview Ledger: L3-L4, L6, L13

## Blocked by
None - ready to start
