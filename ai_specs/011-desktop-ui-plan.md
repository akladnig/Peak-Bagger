## Overview

Desktop-only Peak Lists body inside existing shell chrome.
Remove responsive swaps; keep default selection, import, delete, wrapping.

**Spec**: `ai_specs/011-desktop-ui-spec.md`

## Context

- **Structure**: feature-first screen + widget/robot tests.
- **State management**: Riverpod providers + local screen state.
- **Reference implementations**: `lib/screens/peak_lists_screen.dart`, `test/widget/peak_lists_screen_test.dart`, `test/robot/peaks/peak_lists_journey_test.dart`, `test/robot/peaks/peak_lists_robot.dart`, `lib/router.dart`.
- **Assumptions/Gaps**: `PeakListsScreen` validated in isolation; `PeakListsScreen` body width is the contract; widths below 1024px out of automated coverage; shell chrome unchanged.

## Plan

### Phase 1: Desktop body slice

- **Goal**: fixed desktop composition; no responsive swaps.
- [x] `lib/screens/peak_lists_screen.dart` - remove outer mobile/desktop branch; remove inner stacked-details branch; remove drag divider; keep desktop row composition, default selection, import, delete, sort.
- [x] `test/widget/peak_lists_screen_test.dart` - TDD: supported-floor render in isolation stays desktop-only.
- [x] `test/widget/peak_lists_screen_test.dart` - TDD: first visible list auto-selects on load and after selection loss.
- [x] `test/widget/peak_lists_screen_test.dart` - TDD: long-name fixture wraps summary/details rows.
- [x] `test/widget/peak_lists_screen_test.dart` - replace old 600px stack test with supported-floor assertion.
- [x] Verify: `flutter analyze` && `flutter test`.

### Phase 2: Journey coverage

- **Goal**: keep import/delete journeys stable on fixed desktop layout.
- [x] `test/robot/peaks/peak_lists_robot.dart` - keep key-first selectors aligned; no viewport logic.
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - TDD: import/update flow still lands on selected imported list.
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - TDD: delete flow still reselects next/previous row after targeted delete.
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - TDD: stable selectors for dialog actions and row actions remain valid.
- [x] Verify: `flutter analyze` && `flutter test`.

## Risks / Out of scope

- **Risks**: widths below 1024px may clip; unsupported widths not in automated coverage.
- **Out of scope**: `lib/router.dart`, `lib/widgets/side_menu.dart`, shell responsiveness, new responsive system.
