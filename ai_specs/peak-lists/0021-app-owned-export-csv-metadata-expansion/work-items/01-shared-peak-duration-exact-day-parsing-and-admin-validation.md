---
type: Work Item
title: Shared Peak Duration Exact-Day Parsing And Admin Validation
parent: ../spec.md
---

## What to build

Extend the shared `Peak duration` rules in `lib/services/peak_metadata_rules.dart` so the parser accepts exact single-value day forms `1 day` and `<int> days` in addition to the existing `H:MM`, `<int>-<int> hour(s)`, and `<int>-<int> day(s)` forms, and keep the dedicated ObjectBox Admin peak editor aligned because it already reuses that shared parsing seam. Preserve the current exact-label behavior for supported inputs, keep unsupported forms such as `4 hours` invalid, and make the shared formatter produce parser-safe fallback values for sub-day and exact whole-day durations needed by later export work.

## Required context

- `lib/services/peak_metadata_rules.dart` and `test/services/peak_metadata_rules_test.dart` are the shared rule seam for `Peak duration` parsing and formatting.
- `lib/services/peak_admin_editor.dart` and `test/services/peak_admin_editor_test.dart` already reuse the shared parser for the dedicated ObjectBox Admin peak editor. Keep validation and error messaging aligned there instead of adding a second duration parser.
- Follow the Spec's behavior-first TDD expectation for non-UI contract changes by extending the shared-rule and admin-editor tests before wiring dependent export or import changes.

## Acceptance criteria

- [x] Shared `Peak duration` parsing accepts `H:MM`, `<int>-<int> hour(s)`, `<int>-<int> day(s)`, `<int> day`, and `<int> days` exactly, and still treats blank input as missing duration.
- [x] Shared `Peak duration` parsing preserves the exact trimmed supported label that was entered, including exact-day forms such as `1 day` and `2 days`.
- [x] Exact-day parsing uses the day count as the saved upper-bound duration in minutes, while existing range behavior continues to use the range upper bound.
- [x] Unsupported non-blank duration text such as `4 hours`, malformed clock values, or reversed ranges still throws a clear `FormatException` instead of being coerced.
- [x] Shared duration formatting returns `H:MM` for sub-day minute values and `1 day` or `<int> days` for exact whole-day minute values so later export code can derive parser-safe fallback text when `durationLabel` is blank.
- [x] The dedicated ObjectBox Admin peak editor accepts valid exact-day duration input through its existing duration field, persists the shared parsed result, and surfaces the updated invalid-duration validation message for unsupported values.
- [x] Focused deterministic tests in `test/services/peak_metadata_rules_test.dart` and `test/services/peak_admin_editor_test.dart` cover valid exact-day forms, retained clock and range support, blank values, and rejection of still-unsupported forms such as `4 hours` before dependent export/import wiring changes land.

## Covers

- User Stories: 1-2
- Requirements: 15
- Technical Decisions: 1, 3
- Testing Strategy: 1-3
- Interview Ledger: L3

## Blocked by

None - ready to start
