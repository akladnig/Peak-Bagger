---
type: Work Item
title: Repair Reruns, Cache, and Versioned Snapshot Rewrite
parent: ../spec.md
---

## What to build
Finish the tool by adding reusable on-disk HTTP cache behavior, `--refresh-cache`, and the `--repair-list` workflow against the latest versioned baseline. Repair reruns must retry only unresolved rows, preserve last-known-good visible rows when retries still fail, rewrite the full artifact snapshot deterministically, and suppress no-op versions when the logical main CSV and repair CSV are unchanged.

## Required context
- Build directly on the success-path export seams from `01-locked-slovenia-crawl-and-success-path-export.md` and the repair sidecar generation from `02-partial-output-and-repair-artifact-generation.md`.
- Follow `## Repair Snapshot Semantics` in `spec.md` exactly for baseline loading, last-known-good row preservation, replacement of recovered range rows, repair-file carry-forward, and version suppression.
- Keep raw HTTP cache artifacts separate from `assets/peaks/`, and prefer reparsing cached source pages over introducing a hidden structured store.
- The missing-repair-file error string is fixed by the Spec and must remain exact: `No repair file found. Run a normal crawl first.`

## Acceptance criteria
- [x] Successful `hribi.net` and `monti.uno` fetches are cached on disk outside `assets/peaks/` and reused by default on later normal and repair runs.
- [x] `--refresh-cache` ignores cached content only for the URLs targeted by the current run and refetches them before parsing.
- [x] `--repair-list` loads the latest prior versioned CSV, repair CSV, and state JSON as one baseline snapshot and retries only the unresolved range and peak entries from that latest repair file.
- [x] If no prior repair file exists, `--repair-list` prints exactly `No repair file found. Run a normal crawl first.` and exits non-zero without creating a new versioned artifact set.
- [x] A successfully retried `Kind=range` entry rebuilds that configured range end-to-end and replaces the baseline rows from that range in the rewritten snapshot.
- [x] If a previously exported confirmed peak still fails during a repair run, the rewritten main CSV preserves its last-known-good row from the prior version while the unresolved entry remains in the next repair CSV.
- [x] The next repair CSV contains only entries still unresolved after the current run and removes any successfully repaired range or peak rows.
- [x] A meaningful repair or normal run writes the next versioned CSV, repair CSV, and state JSON snapshot, while a no-op run with unchanged logical main CSV and repair CSV does not create a new version.
- [x] Tool and service tests cover cache reuse, `--refresh-cache`, missing repair baseline handling, recovered range reruns, last-known-good preservation, repair-file carry-forward, full-snapshot rewrite behavior, and no-new-version suppression without hitting live upstream services.

## Covers
- User Stories: 1-4
- Requirements: 13-20
- Technical Decisions: 1, 3-6
- Testing Strategy: 1, 3.4-3.5, 4.2-4.6, 5, 7
- Interview Ledger: L8-L13

## Blocked by
- `01-locked-slovenia-crawl-and-success-path-export.md`
- `02-partial-output-and-repair-artifact-generation.md`
