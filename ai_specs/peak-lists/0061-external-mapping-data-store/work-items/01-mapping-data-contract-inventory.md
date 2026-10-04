---
type: Work Item
title: Inventory Mapping Data Store Contracts
parent: ../spec.md
---

## What to build

Create `docs/mapping-data-store.md` as the reviewable, blocking inventory before any Mapping data migration implementation. Derive it from a repository-wide search for `assets/` mapping-data contracts, Mapping-store and other absolute roots, and `File`, `Directory`, `RandomAccessFile`, `Process`, and path-resolver use in Mapping-aware runtime and tool code.

For every discovered runtime and maintainer tool, record its command, manifest usage, exact default inputs and outputs, permitted Mapping-store writes or no-store-write status, retained CLI overrides, and classify every input/output as Mapping-store data, user data, temporary data, cache, report, or maintainer-only external source. Record local Overpass services from `/Volumes/Development/overpass_turbo/README.md` as maintainer-only snapshot sources with health prerequisites, manifest coverage, and snapshot outputs; the shipped app must never query them.

## Required context

- Use the terminology in `GLOSSARY.md`, particularly Mapping data store, Mapping data manifest, routing coverage, and Northeast Alps routing coverage.
- Inventory current contracts in `tool/`, `local_topo/tasmania/scripts/`, `elvis_dem.sh`, and Mapping-aware `lib/` code. The inventory is an implementation prerequisite for every later Work Item, not a retrospective document.

## Acceptance criteria

- [x] `docs/mapping-data-store.md` identifies `/Volumes/Services/Mapping` as the canonical app-read-only owner of all non-UI mapping data; ObjectBox, Bushwalking user data, app-support geometry cache, and user offline basemap tiles are classified separately.
- [x] The inventory records each tool's exact command, Mapping data manifest, polygon manifest, or tool-manifest use, all default Mapping-store paths, every declared write, and every retained override; no Mapping-data input/output remains repository-owned or `assets/...`-based.
- [x] Every maintainer-used local Overpass service is classified as a tool-only source and records its health prerequisite and snapshot output. The document explicitly prohibits shipped-app Overpass access.
- [x] The inventory records the generated region-manifest catalog tool, `veneto.poly`, and the peak-prominence CSV as retired contracts to remove or migrate in the later cutover.
- [x] Add a regression test or reviewable inventory validation that fails when a discovered Mapping-aware entrypoint is absent from the inventory classification.

## Covers

- User Stories: 3
- Requirements: 1, 9, 22, 28
- Technical Decisions: 5
- Testing Strategy: 4, 12, 13
- Interview Ledger: L1, L3, L6, L8, L9, L10

## Blocked by
None - ready to start
