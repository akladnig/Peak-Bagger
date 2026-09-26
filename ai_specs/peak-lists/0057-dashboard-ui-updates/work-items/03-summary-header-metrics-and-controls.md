---
type: Work Item
title: Summary Header Metrics And Controls
parent: ../spec.md
---

## What to build

Update the reusable Dashboard Summary-card and header implementation shared by Distance, Elevation, and Peaks Bagged. Each header summary metric must render as a naturally spaced `label: value` pair with exactly one space, for example `Total: 74`. Remove only the fixed-width, right-justified value field; keep the entire metric group right-aligned and preserve its responsive truncation and scaling behavior.

Use `SystemMouseCursors.click` for enabled Summary controls across all three card types: the period dropdown trigger and menu entries, previous/next controls, and the line/column view control. Disabled previous/next controls retain the default cursor. Do not duplicate shared behavior per card.

## Required context

- `lib/widgets/dashboard/summary_card.dart` owns the reusable Summary controls and their existing keys: `summary-period-dropdown`, `summary-prev-window`, `summary-next-window`, and `summary-mode-fab`.
- `lib/screens/dashboard_screen.dart` owns `_DashboardCardHeaderMetrics` and the fixed-width, right-justified `_DashboardCardHeaderMetricPill` value field. Preserve its header layout, card reordering, and right-side alignment behavior.
- Distance, Elevation, and Peaks Bagged use the same `SummaryCard` implementation through `lib/widgets/dashboard/distance_card.dart`, `elevation_card.dart`, and `peaks_bagged_card.dart`; make the behavior reusable at that boundary.
- Extend `test/widget/dashboard_screen_test.dart` and the existing Summary-card/card widget tests. Reuse `DashboardRobot.summaryControl` and existing keys in `test/robot/dashboard/dashboard_robot.dart`; do not add selectors or a robot journey.

## Acceptance criteria

- [x] Distance, Elevation, and Peaks Bagged card headers render every summary metric label and value with exactly one separating space, such as `Total: 74`; no fixed-width, right-justified value field remains.
- [x] The complete summary-metric group remains right-aligned within every affected card header. At constrained card width and enlarged text scale, it remains visible without overflow while preserving the existing truncation and scaling behavior.
- [x] Every enabled Summary period dropdown trigger and menu entry, previous/next control, and line/column view control uses `SystemMouseCursors.click` for Distance, Elevation, and Peaks Bagged. Disabled previous/next controls retain the default cursor.
- [x] Existing Summary control keys, keyboard semantics, tooltips, period selection, window navigation, line/column switching, card layout, and card reordering remain unchanged.
- [x] Dashboard and Summary-card widget tests assert one-space metrics, preserved right-side grouping, constrained-width and enlarged-text-scale behavior, all scoped enabled cursors, and default disabled previous/next cursors using existing keys. Existing Dashboard robot journeys continue to pass.
- [x] Run `flutter analyze`, the focused service/widget/robot tests, and `flutter test` before completion.

## Covers

- User Stories: 3
- Requirements: 5, 7, 9
- Technical Decisions: 4-5
- Testing Strategy: 4-6
- Interview Ledger: L1, L3, L4

## Blocked by

None - ready to start
