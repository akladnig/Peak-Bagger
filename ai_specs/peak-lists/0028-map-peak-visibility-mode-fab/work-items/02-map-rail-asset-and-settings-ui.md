---
type: Work Item
title: Add Peak Visibility Mode Rail FAB And Remove Old Settings UI
parent: ../spec.md
---

## What to build

Add the new icon-only `Peak visibility mode` FAB to `lib/widgets/map_action_rail.dart` above the existing `Select Peak List` FAB in the `View` group, using the existing left-tooltip FAB pattern and a new stable selector for direct test targeting. The control must surface the exact tooltip and semantics labels `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`, use the required per-state icons, and keep icon-colour treatment aligned with the current FAB contract. Keep `Select Peak List` as a separate drawer-opening control with exact tooltip and semantics label `Select Peak List`, preserve `Key('show-peaks-fab')` for that drawer control, change its icon to `Icons.collections`, bundle the custom slashed landscape SVG under `assets/svg`, and remove the Settings-screen `Show Map Peak Clusters` row while preserving unrelated settings such as `Show Peak Ownership Rings` and `Show Peak List Mini-Map Clusters`.

## Required context

- `lib/widgets/map_action_rail.dart` already groups icon-only `View` actions and uses `LeftTooltipFab` for tooltip placement. Keep the new FAB in that existing rail structure and ordering style.
- `lib/screens/settings_screen.dart` currently contains the `Show Map Peak Clusters` tile alongside unrelated settings that must remain present.
- `assets/svg/` is already registered in `pubspec.yaml`, so the new slashed landscape asset should be added there without changing the asset-registration pattern.
- Existing rail and settings coverage lives in `test/widget/map_action_rail_grouping_test.dart`, `test/widget/tasmap_display_mode_test.dart`, and `test/widget/settings_screen_peak_cluster_test.dart`.
- Existing stable selectors already anchor map tests and robots, including `Key('show-peaks-fab')` for the `Select Peak List` drawer control. Preserve that selector and add one new stable selector for the new `Peak visibility mode` FAB.

## Acceptance criteria

- [ ] The `View` rail group renders a new small icon-only `Peak visibility mode` FAB above `Select Peak List` using the same left-tooltip FAB pattern as the rest of the rail.
- [ ] The new FAB exposes the exact tooltip and semantics strings `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`, and shows no persistent text label on the button itself.
- [ ] The new FAB uses the same icon as the Settings-screen `Show Peak Ownership Rings` control for `Show Peak Clusters`, `Icons.landscape` for `Show Peaks`, and the app-owned slashed landscape SVG asset for `Hide Peaks`.
- [ ] The custom slashed landscape SVG is saved under `assets/svg` and is available to widget and robot tests through the existing asset-registration contract.
- [ ] `Select Peak List` remains a separate drawer-opening FAB with exact tooltip and semantics label `Select Peak List`, preserves `Key('show-peaks-fab')`, and changes its icon to `Icons.collections`.
- [ ] The rail ordering, tooltips, and semantics remain usable on both desktop and compact viewports covered by the existing rail tests.
- [ ] The Settings screen no longer shows `Show Map Peak Clusters`, while `Show Peak Ownership Rings` and `Show Peak List Mini-Map Clusters` remain available and unchanged.
- [ ] Widget coverage proves the new FAB ordering, exact copy, icon contract, stable selector contract, `Select Peak List` icon change, and Settings-screen non-regression without relying on tooltip text alone where a stable selector exists.

## Covers

- User Stories: 1-3
- Requirements: 2, 4-5, 8, 10, 15-17, 19
- Technical Decisions: 2, 6-7
- Testing Strategy: 2, 4-5
- Interview Ledger: L1, L3-L4, L6

## Blocked by

- 01-mapprovider-peak-visibility-mode-state-machine.md
