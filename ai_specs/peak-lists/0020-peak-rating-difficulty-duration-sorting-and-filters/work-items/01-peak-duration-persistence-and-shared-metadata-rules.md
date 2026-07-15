---
type: Work Item
title: Peak Duration Persistence And Shared Metadata Rules
parent: ../spec.md
---

## What to build

Extend the persisted `Peak` contract with `durationMinutes` and `durationLabel`, keep both fields aligned across the ObjectBox model, generated bindings, schema guard coverage, and generic admin/schema inspection surfaces, and add shared app-owned metadata logic for this feature's non-UI rules. The shared logic must cover `Peak duration` parsing and formatting, `Rating` display rounding to the nearest half star without changing numeric source-of-truth behavior, map `Rating` threshold matching, map `Duration` filter matching, and region-aware `Peak difficulty` ordering and exact-match filter grouping semantics.

## Required context

- `lib/models/peak.dart`, `lib/objectbox-model.json`, and `lib/objectbox.g.dart` are the canonical persistence surfaces that must stay aligned for new `Peak` fields.
- `lib/services/objectbox_schema_guard.dart` and `test/services/objectbox_schema_guard_test.dart` already assert the persisted `Peak` surface. Extend that existing schema-guard seam instead of creating a second schema contract.
- `lib/services/objectbox_admin_repository.dart` and `test/services/objectbox_admin_repository_test.dart` already define how generic admin/schema tooling exposes and reconstructs `Peak` fields. Keep `durationMinutes` and `durationLabel` inspectable there.
- Keep the new non-UI rules in shared app-owned logic reused later by ranked CSV import, admin editing, `My Peak Lists`, and map metadata filters.
- Follow the Spec's behavior-first TDD expectation for the new non-UI rules with focused unit or service-level coverage before widget wiring.

## Acceptance criteria

- [ ] `Peak` persists both `durationMinutes` and `durationLabel`, where `durationMinutes` is the numeric source of truth and `durationLabel` preserves the user-facing wording.
- [ ] ObjectBox schema artifacts, generated bindings, and schema-guard coverage all include the new `Peak` duration fields so schema drift is detected deterministically.
- [ ] Generic admin/schema tooling can inspect both `durationMinutes` and `durationLabel` on `Peak` rows.
- [ ] Shared duration parsing accepts only exact clock format `H:MM` such as `0:30` and `4:15`, hour ranges in the form `<int>-<int> hour` or `<int>-<int> hours` such as `4-5 hours`, and day ranges in the form `<int>-<int> day` or `<int>-<int> days` such as `2-3 days`.
- [ ] For hour and day ranges, shared duration parsing uses the upper bound as `durationMinutes`.
- [ ] The supported `Peak duration` domain covered by the shared logic and tests includes at least 15 minutes through about 20 days.
- [ ] Shared duration formatting can derive a display string from `durationMinutes` for UI paths that need a fallback when `durationLabel` is blank.
- [ ] Shared `Rating` display logic rounds the stored numeric rating to the nearest half star for display only and does not replace numeric sort or filter behavior.
- [ ] Shared map `Rating` filter matching uses `peak.rating >= selectedThreshold` for the exact thresholds `3.0`, `3.5`, `4.0`, and `4.5`, and excludes peaks with missing ratings whenever the selection is not `Any`.
- [ ] Shared map `Duration` filter matching supports exactly `Any`, `4h`, `8h`, `12h`, `2d`, `5d`, `10d`, and `2d+`, where `4h`, `8h`, `12h`, `2d`, `5d`, and `10d` match peaks where `durationMinutes <= threshold`, `2d+` matches peaks where `durationMinutes >= 2880`, and peaks with missing duration are excluded whenever the selection is not `Any`.
- [ ] Shared `Peak difficulty` ordering remains region-aware and app-owned, using Tasmania `Easy < Medium < Hard < Very Hard`, Italy administrative regions `T < E < EE < EEA < EAI`, and `slovenia` and `croatia` `T1 < T2 < T3 < T4 < T5 < T6`, with alphabetical fallback for regions without a configured ladder.
- [ ] Shared mixed-region `Peak difficulty` sorting behavior orders by region first, then that region's difficulty order, then peak name, and does not invent or expose a global normalized difficulty scale.
- [ ] Shared mixed-region `Difficulty` filter support groups values by region and matches one exact `(region, difficulty)` pair at a time.
- [ ] Focused unit or service-level tests cover valid exact durations, valid hour and day ranges, blank values, invalid duration text, `Rating` threshold matching, `Duration` threshold matching, and region-aware `Peak difficulty` ordering/grouping rules under deterministic local seams only.

## Covers

- User Stories: 3-4
- Requirements: 1-3, 16-19, 21-22
- Technical Decisions: 1-3, 6
- Testing Strategy: 1-2
- Interview Ledger: L1-L3, L5-L7, L9

## Blocked by

None - ready to start
