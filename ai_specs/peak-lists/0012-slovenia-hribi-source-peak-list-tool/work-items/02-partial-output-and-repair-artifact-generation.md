---
type: Work Item
title: Partial-Output and Repair Artifact Generation
parent: ../spec.md
---

## What to build
Extend the CLI crawl/export flow so normal runs tolerate missing range pages, failed peak detail pages, and missing non-type fields while still producing partial main CSV output, deterministic repair rows, and human-readable error summaries. This slice should cover the repair sidecar contract and the missing-enrichment fallback behavior, but not yet repair-only reruns, cache refresh behavior, or full repair snapshot rewriting.

## Required context
- Reuse the crawl, normalization, and visible CSV/state seams from `01-locked-slovenia-crawl-and-success-path-export.md` instead of creating a parallel repair-specific export path.
- Keep the visible CSV source-agnostic: unresolved work belongs in the repair sidecar and state artifact, not in extra visible CSV columns.
- Preserve the approved fallback behavior for missing `monti.uno` enrichment: confirmed rows stay in the main CSV with the confirmed `hribi.net` name where specified, blanks for missing enrichment fields, and matching repair metadata.
- The repair sidecar columns and `Kind` values are fixed by the Spec and must remain stable for later `--repair-list` support.

## Acceptance criteria
- [x] A normal run that fails to fetch a configured range page still completes, writes any successful CSV rows, emits a repair entry with `Kind=range`, and includes a human-readable summary of the range failure.
- [x] A peak detail page failure before `vrh` type confirmation keeps the unresolved item out of the main CSV and writes a `Kind=peak` repair row with the available range/detail/name context.
- [x] A confirmed peak with missing or unparsable non-type fields still writes a main CSV row with blanks for the missing values and also remains in the repair CSV with `MissingFields` metadata.
- [x] Missing or unusable `monti.uno` enrichment follows the approved fallback matrix for both `Slovenia`-only and `Italy` or multi-country rows, including blank `Alt Name` handling and repair tracking.
- [x] The repair sidecar written by a normal run uses exactly `Kind,RangeUrl,DetailUrl,Name,MissingFields,LastError`, with `Kind=range` and `Kind=peak` only.
- [x] Partial-output runs preserve the same visible CSV ordering rules as the success path for all written rows.
- [x] Service and tool-level tests cover failed range pages, failed peak detail pages before confirmation, confirmed peaks with missing fields, missing enrichment fallback behavior, and partial-run stdout/stderr summaries without hitting live upstream services.

## Covers
- User Stories: 3, 4
- Requirements: 5-6, 10-12, 18
- Technical Decisions: 3-4
- Testing Strategy: 1, 3.1-3.3, 4.6, 5, 7
- Interview Ledger: L2, L4, L8-L9, L11

## Blocked by
- `01-locked-slovenia-crawl-and-success-path-export.md`
