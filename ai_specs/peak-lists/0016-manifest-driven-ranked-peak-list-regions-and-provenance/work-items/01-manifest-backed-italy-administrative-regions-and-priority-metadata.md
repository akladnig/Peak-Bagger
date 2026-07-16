---
type: Work Item
title: Manifest-Backed Italy Administrative Regions and Priority Metadata
parent: ../spec.md
---

## What to build
Extend the manifest-backed region model so this slice can treat the needed `Italy administrative region` entries as real manifest-backed regions while keeping `italy-nord-est` and `italy-nord-ovest` as `Italy aggregate region` unions only. Add the shared manifest utilities this slice needs for exact display-name resolution and `Manifest priority` parsing and comparison so later ranked-import and Slovenia-tool work can consume one authoritative manifest-backed contract instead of hard-coded region tables or manifest file order.

## Required context
- `assets/region_manifest.json`, `tool/generate_region_manifest_catalog.dart`, `lib/services/region_manifest_catalog.dart`, and `lib/generated/region_manifest_catalog.g.dart` define the manifest-backed runtime contract. Regenerate generated catalog output through the existing tool flow instead of hand-editing generated files.
- Follow canonical terminology from `GLOSSARY.md`, especially `Italy administrative region`, `Italy aggregate region`, and `Manifest priority`.
- Relevant prior slices are `ai_specs/peak-lists/0006-ranked-peak-list-import-and-italy-north-east-subregions/spec.md` and `ai_specs/peak-lists/0014-slovenia-ranked-peak-list-correlation-tool/spec.md`; this item replaces their region exceptions and broad-Slovenia assumptions with a shared manifest-backed foundation.
- Existing unit coverage starting points are in `test/unit/region_manifest_catalog_test.dart`. Keep validation deterministic and fixture-backed.
- This slice must not broaden startup asset seeding. Check existing startup or asset-import paths such as `lib/services/peak_region_asset_import_service.dart` before wiring any new region metadata into app boot behavior.

## Acceptance criteria
- [x] The manifest adds only the `Italy administrative region` entries currently needed by the app's data, polygon, or ranked-import flows in this slice, including `fvg`, `veneto`, `trentino-alto-adige`, `emilia-romagna`, and any north-west administrative peers that are actually needed now; it does not model unused ISO 3166-2:IT first-level subdivisions preemptively.
- [x] `italy-nord-est` and `italy-nord-ovest` remain manifest-backed `Italy aggregate region` entries for grouping and filter roll-up only, not the canonical stored `Peak.region` contract for ranked imports or canonicalization.
- [x] Shared manifest lookup support resolves ranked `region` values from exact manifest display names after surrounding-whitespace trimming. Internal keys such as `slovenia`, `fvg`, `veneto`, or `italy-nord-est` are not treated as display-name matches.
- [x] Every manifest-backed region that participates in canonicalization defines a required `priority` value in 1 to 3 dot-separated numeric segments such as `2`, `2.1`, or `2.1.3`; missing or malformed values fail deterministically before canonicalization or ranked-region resolution can proceed.
- [x] Shared `priority` comparison is numeric segment by numeric segment, not lexical, and a longer path that strictly extends the same prefix outranks its parent, such as `2.1` over `2` and `2.1.3` over `2.1`.
- [x] Aggregate regions such as `italy`, `italy-nord-est`, and `italy-nord-ovest` cannot outrank a matching more specific child region because of manifest entry order or fallback ordering.
- [x] Newly added Italian administrative manifest regions are available for search, ranked import, and canonicalization in this slice, but they do not trigger startup peak-region asset seeding or automatic startup imports unless a later slice adds the required seed assets and boot behavior explicitly.
- [x] Unit coverage proves exact display-name resolution, required-priority validation, numeric comparison, longer-prefix specificity, and deterministic rejection of malformed priorities without relying on manifest file order, live network data, or external services.

## Covers
- User Stories: 1, 2
- Requirements: 1-4, 11-13
- Technical Decisions: 1-3, 7
- Testing Strategy: 3, 4, 10
- Interview Ledger: L1-L3, L7-L8

## Blocked by
None - ready to start
