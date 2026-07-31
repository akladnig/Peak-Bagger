---
type: Work Item
title: Route Rule Artifact Alignment And Legacy Doc Conflict Cleanup
parent: ../spec.md
---

## What to build

Align the route-rule artifacts and bounded legacy route docs with the resolved future-state contract in this follow-up Spec without rewriting current-behavior baseline facts. Update `ai_specs/routes/route-rules.md` and any bounded legacy route docs that still imply automatic generic turnaround or loop waypoint persistence so they no longer conflict with the explicit rule that `Out and Back` and `Close Loop` are geometry transforms, not implicit semantic-waypoint creation paths. Preserve `ai_specs/routes/route-rules.md` as the descriptive current-behavior baseline, keep the line-125 manual recheck outcome explicit, and keep route terminology aligned with `GLOSSARY.md`.

## Required context

- `GLOSSARY.md` defines the canonical distinction between draft-only numbered route points, plain route points, and semantic saved waypoints.
- `ai_specs/routes/route-rules.md` must remain the descriptive baseline for current behavior; only its inconsistency or proposal notes should change where needed.
- `ai_specs/routes/route-out-and-back-spec.md`, `ai_specs/routes/route-loop-spec.md`, and `ai_specs/routes/route-edit-spec.md` are the bounded legacy docs most likely to conflict with the resolved contract.
- `ai_specs/peak-lists/0033-current-route-creation-and-editing-ruleset/work-items/*.md` show the nearby artifact style for route-rule documentation work.

## Acceptance criteria

- [ ] `ai_specs/routes/route-rules.md` continues to describe current route-draft behavior accurately while no longer leaving the line-210 turnaround or loop waypoint persistence conflict unresolved.
- [ ] Any bounded legacy route docs that still imply automatic generic turnaround or loop waypoint persistence are updated or explicitly marked as superseded where they conflict with the follow-up Spec's plain-route-point versus semantic-waypoint contract.
- [ ] Route-rule terminology remains aligned with `GLOSSARY.md`, especially the distinction between draft-only numbered route points, plain route points, and semantic saved waypoints.
- [ ] The manual recheck outcome for the line-125 baseline note remains explicit so later implementation work does not rely on stale uncertainty.
- [ ] This slice is documentation-only and does not introduce app code, persistence, or test behavior changes.

## Covers

- User Stories: 10
- Requirements: 1, 20-22
- Technical Decisions: 1, 3, 8
- Testing Strategy: 8
- Interview Ledger: L3, L5, L10

## Blocked by

None - ready to start
