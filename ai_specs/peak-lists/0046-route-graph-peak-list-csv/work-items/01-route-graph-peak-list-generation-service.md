---
type: Work Item
title: Build Route-Graph Peak List Generation Service
parent: ../spec.md
---

## What to build

Build the injectable, test-first Dart service that produces one app-owned peak-list CSV from the canonical 25-column peak source and the selected region's effective route-graph highway files. It must validate all inputs before replacing an output, parse raw Overpass geometry rather than `RouteGraphWayIndex`, perform two-dimensional 50 m segment matching, and remain read-only with respect to ObjectBox.

## Required context

- `lib/services/peak_list_csv_export_service.dart` defines the exact 22-column app-owned export header, MGRS fallback, value formatting, lowercase boolean values, and name-then-numeric-`osmId` sort order.
- `lib/services/route_graph_import_service.dart` defines accepted route-graph ways: a non-null `highway` tag excluding `area=yes` and `place=square`.
- `lib/services/track_peak_correlation_service.dart` contains the existing finite-segment spatial approach to reuse without its elevation criterion.
- Keep manifest, peak-source, highway-source, file-system, output, and stdout/stderr boundaries replaceable with deterministic fakes. Do not read real highway assets, open ObjectBox, require API keys, or use the network in tests.

## Acceptance criteria

- [ ] Start with focused Flutter unit/service tests using small fake manifest, Overpass JSON, peak-source CSV, directory, and file-system inputs.
- [ ] Resolve canonical selected regions to effective `highways` paths from their own non-empty declaration or by repeatedly removing the final segment of their manifest `priority` until an ancestor supplies one; fail unknown keys and keys with no such ancestor.
- [ ] For a non-composite selection, filter normalized source `region` values by the selected key and its `peakListFilterAliases`, including selections such as `fvg` that inherit highway paths. For a composite selection, union keys and aliases of non-composite regions whose non-empty effective paths are included in its effective paths. Preserve each normalized source-region value in output.
- [ ] Parse selected highway files relative to the repository root. Accept eligible route-graph ways with the exact exclusions, ignore malformed top-level nodes, break `way.nodes` into contiguous valid point runs without bridging unresolved or unusable references, skip individual ways without a two-point run, and fail a highway file with no usable eligible segments.
- [ ] Require the exact ordered 25-column peak-source schema and reject the entire source for every invalid required, optional numeric, coordinate, or `verified` value defined in Requirement 6. Accept invalid or blank MGRS components so the app-owned MGRS fallback is used.
- [ ] Select each eligible peak once when its latitude/longitude is within or exactly at 50 m of an eligible segment, without requiring or synthesizing highway elevation. Cover inclusive-boundary, outside-threshold, duplicate-match, multi-file, casing, aliases, composite union, direct declaration, and ancestor-fallback cases.
- [ ] Encode exactly one app-owned 22-column CSV using `PeakListCsvExportService` rules, write `1` to every `points` column, sort by case-insensitive name then numeric `osmId`, and produce a header-only CSV for zero matches.
- [ ] With no output override, use `~/Documents/Bushwalking/Peak_Lists/<canonical-region>-route-graph-peak-list.csv`; with an override, use exactly that path. Require an existing parent directory and never create one.
- [ ] Construct all rows before using a temporary sibling file and rename to atomically replace the target. On peak-source, highway, directory, writing, or rename failures, write actionable detail with the relevant path and selected region where required, return failure to the caller, preserve any existing target, and remove the temporary sibling.

## Covers

- User Stories: 2, 3
- Requirements: 2, 4-14
- Technical Decisions: 1-3, 5
- Testing Strategy: 2-5
- Interview Ledger: L1-L12, L14, L16-L17

## Blocked by

None - ready to start
