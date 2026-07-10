---
title: Peak list relational schema spec alignment
date: 2026-06-24
work_type: refactor
tags: [specs, objectbox, peak-lists, schema]
confidence: high
references:
  - ai_specs/objectbox-admin/objectBox-fix.md
  - ai_specs/peak-lists/011-peak-lists-spec.md
  - ai_specs/peak-lists/011-peak-lists-enhancements-spec.md
  - ai_specs/peak-lists/peak-list-selector-spec.md
  - ai_specs/settings/csv-export-lists-spec.md
  - ai_specs/objectbox-admin/06-objectbox-peak-admin-spec.md
  - ai_specs/peaks/010-peak-info-spec.md
---

## Summary

This session aligned the peak-list spec set around a relational ObjectBox model instead of `PeakList.peakList` JSON storage. The reusable outcome is a clear contract: `PeakList` holds list metadata, `PeakListItem` holds ordered membership rows, and every membership call site should query relational rows rather than decode or rewrite JSON blobs.

## Reusable Insights

- When changing a storage model, update the whole spec surface, not just the primary schema note. In this repo, peak-list membership assumptions also lived in selector, export, peak-info, dashboard, and admin specs.
- Preserve user-visible ordering explicitly when moving from serialized arrays to relational rows. Here that means adding `PeakListItem.position` rather than assuming ObjectBox row order will match import or UI order.
- Keep the boundary between list metadata and membership data explicit:
  - `PeakList`: identity, name, region, list-level metadata
  - `PeakListItem`: relation to `PeakList`, relation to `Peak`, `points`, `position`
- Once memberships point at `Peak` by relation, `Peak.osmId` changes should not require peak-list rewrites. That lets `PeaksBagged.peakId` stay the only `osmId` cascade concern in the peak-admin save flow.
- Legacy JSON-backed lists should be treated as migration leftovers, not as a first-class long-term format. Future specs should describe them only as temporary unreadable/unsupported legacy cases.

## Decisions

- Updated the specs to require migration of all peak-list membership call sites, not just the entity model.
- Treated zero-item lists as zero `PeakListItem` rows instead of an initialized empty JSON payload.
- Kept warnings about legacy JSON only where a migration window still matters, such as export or filtering behavior during partial rollout.

## Pitfalls

- It is easy to change the core data-model spec and leave adjacent specs contradicting it. The main drift points here were:
  - import/create flows still initializing `encodePeakListItems([])`
  - selector/filter specs still decoding `PeakList.peakList`
  - export specs still talking about malformed JSON payloads as the main failure mode
  - peak-admin specs still describing `osmId` rewrites across list payloads
- If order preservation is not called out in the spec, a relational migration can silently lose list ordering semantics even if every row is preserved.

## Validation

- Updated the relevant `*-spec.md` files to use consistent relational terminology.
- Ran targeted repository diff review across the edited specs to confirm they now describe:
  - `PeakList` as metadata
  - `PeakListItem` as ordered membership storage
  - legacy JSON as migration-only context

## Follow-ups

- Some historical `*-plan.md` files still mention the older JSON implementation as completed work. If these plans are still used operationally, they should be swept separately so they do not read like current design guidance.
- When the code migration starts, use this same contract to drive repository APIs first: list item queries, ordered writes, duplicate handling, and migration visibility for unreadable legacy rows.
