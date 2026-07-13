---
type: Work Item
title: Locked Slovenia Crawl and Success-Path Export
parent: ../spec.md
---

## What to build
Add the standalone repo-local Dart CLI and callable tool seam for the Slovenia `Hribi source peak list` success path. Freeze the 10 configured Slovenia ranges from `Appendix A`, crawl their `hribi.net` range and detail pages, confirm peaks using the `vrh` type rule, apply the approved `Name` / `Alt Name`, `Country`, `Mountain Range`, and numeric normalization rules on successful fetches, and write the visible versioned CSV plus deterministic state JSON without touching ObjectBox or app runtime data.

## Required context
- Follow the existing CLI and callable seam pattern in `tool/peak_prominence_csv.dart` and the tool-level test style in `test/tool/peak_prominence_csv_test.dart`.
- Preserve exact glossary terminology from `GLOSSARY.md`, especially `Hribi source peak list` and `Repair list`.
- The configured range set, exact `Mountain Range` labels, and translated range references are frozen in `spec.md` under `Appendix A: Locked Slovenia Range Configuration`; do not rediscover or translate them at runtime.
- Keep the implementation outside app/ObjectBox mutation paths. This slice is a standalone extraction tool, not an import flow.
- Build the crawl, parse, normalization, and write logic behind directly testable seams so later repair and cache work can reuse the same success-path behavior.

## Acceptance criteria
- [x] A standalone CLI under `tool/` runs without mutating ObjectBox or app runtime state and exposes a callable tool seam suitable for tool-level tests.
- [x] The tool uses only the 10 frozen Slovenia ranges from `Appendix A` in the listed order and does not perform live range discovery.
- [x] Successful range/detail crawls include only rows whose `hribi.net` detail page confirms `vrh` in the source type, and every exported row writes `Type` as exactly `Peak`.
- [x] The visible CSV header is exactly `Name,Alt Name,Country,Mountain Range,Altitude,Latitude,Longitude,Popularity,Type` with no extra columns such as `osmId` or source URLs.
- [x] Success-path naming follows the approved source matrix, including `Slovenia`-only and `Italy` or multi-country rows when both source pages are usable.
- [x] `Country` normalization uses a tool-owned English mapping with preserved source order and duplicate removal, and `Mountain Range` uses the exact frozen `hike.uno` label for the configured source range.
- [x] `Altitude`, `Latitude`, `Longitude`, and `Popularity` are normalized to the exact stored formats required by the Spec.
- [x] A successful meaningful run writes a versioned main CSV and matching state JSON under `assets/peaks/`, with deterministic merged ordering based on configured range order then in-range source order.
- [x] Unit, service, and tool-level tests cover the locked range configuration, peak confirmation, success-path naming rules, country and numeric normalization, deterministic ordering, and versioned success-path artifact naming without hitting live upstream services.

## Covers
- User Stories: 1, 2, 4
- Requirements: 1-9, 15, 17-18
- Technical Decisions: 1-4
- Testing Strategy: 1-2, 4.1, 4.4, 5, 7
- Interview Ledger: L1-L7, L10-L11

## Blocked by
None - ready to start
