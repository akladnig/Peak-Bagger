---
type: Work Item
title: Individual Peak Ownership Ring Setting And Presentation
parent: ../spec.md
---

## What to build

Add the main-map individual `Peak ownership ring` slice end to end. Extend the existing peak presentation seam so individual markers can describe equal-segment ownership-ring membership, clockwise segment order, and fallback triangle colour without relying on pixel-only assertions. On the main map route, individual peaks must show a `Peak ownership ring` only when `Show Peak Ownership Rings` is enabled and more than one currently selected app-bar peak list owns the peak; single-list and zero-list peaks must remain plain triangles. Keep ticked individual peaks green, allow the green triangle to carry the equal-segment ownership ring when enabled and more than one currently selected app-bar peak list owns the peak, preserve the Tasmania fallback precedence `Abels`, `HWC Peak Baggers`, `Poimenas`, `Tassy Full` when the setting is off, preserve the existing non-Tasmania lowest-`peakListId` fallback when the setting is off, and add the persisted `Show Peak Ownership Rings` control to `SettingsScreen` using the app's existing Riverpod plus `SharedPreferences` settings pattern.

## Required context

- `lib/services/peak_cluster_engine.dart` already owns the projected individual marker data consumed by the main map and is the best place to extend the deterministic presentation seam before painter-only rendering.
- `lib/screens/map_screen_peak_layer.dart` is the current main-map marker and cluster painter path. Preserve the current triangle shape, white outline, and existing interactions while adding individual `Peak ownership ring` rendering metadata.
- `lib/providers/peak_marker_info_settings_provider.dart` and `lib/providers/peak_map_cluster_display_settings_provider.dart` show the existing Riverpod plus `SharedPreferences` boolean settings pattern to follow for the new `Show Peak Ownership Rings` preference.
- `lib/screens/settings_screen.dart` already hosts similar persisted display controls and should keep the new toggle readable on desktop, mobile, and large text settings using the existing constrained-width Settings patterns.
- Reuse the current peak-list colour and selected-list membership sources of truth instead of introducing new colour ownership logic. Relevant existing paths include `lib/services/peak_list_colour_resolver.dart`, `lib/providers/map_provider.dart`, and `lib/providers/peak_list_selection_provider.dart`.
- Existing focused test patterns live in `test/services/peak_cluster_engine_test.dart`, `test/providers/peak_marker_info_settings_provider_test.dart`, and widget tests around main-map marker behavior. Keep deterministic seam assertions first and avoid screenshot-only testing.

## Acceptance criteria

- [ ] Behavior-first TDD drives the individual marker ownership-ring presentation seam, Tasmania fallback resolver behavior, and the `Show Peak Ownership Rings` preference state before implementation is finalized.
- [ ] The canonical term remains `Peak ownership ring`, and the main map preserves the current individual peak triangle shape, current white triangle outline, existing peak interactions, and the current green meaning for ticked individual peaks.
- [ ] An individual peak renders a `Peak ownership ring` only when all of these are true: the persisted `Show Peak Ownership Rings` setting is enabled, the peak is visible on the main map route, and the peak belongs to more than one currently selected app-bar peak list.
- [ ] Individual `Peak ownership ring` segments are equal per currently selected owning peak list and are not sized by peak counts, points, prominence, or list order.
- [ ] If an individual peak belongs to exactly one visible owning peak list, it shows only the triangle and no individual ring.
- [ ] If an individual peak belongs to no visible owning peak lists, it shows only the triangle and no individual ring.
- [ ] Ticked individual peaks remain green regardless of region or the individual-ring setting, and when a ticked individual peak has more than one currently selected owning list while `Show Peak Ownership Rings` is enabled, the green triangle may still carry the equal-segment ownership ring around it.
- [ ] When `Show Peak Ownership Rings` is off, unticked individual peaks in Tasmania use this exact visible-list precedence when more than one visible list applies: `Abels`, `HWC Peak Baggers`, `Poimenas`, `Tassy Full`.
- [ ] When `Show Peak Ownership Rings` is off outside Tasmania, unticked individual peaks use the visible matching list colour with the lowest `peakListId`, preserving the existing non-Tasmania visible-list precedence rule.
- [ ] For individual peaks, segment order starts at 12 o'clock and proceeds clockwise, applying the current app-owned list-priority contract so Tasmania uses `Abels`, `HWC Peak Baggers`, `Poimenas`, `Tassy Full` and non-Tasmania falls back to ascending `peakListId`.
- [ ] Individual ring segments are built only from peak lists that are currently selected in the app bar for the active map state; hidden, unselected, pinned-only, or otherwise inactive lists do not contribute segments.
- [ ] `SettingsScreen` adds a persisted control with the visible label `Show Peak Ownership Rings`, and preference load or save failure keeps the last in-memory value or default without blocking map rendering.
- [ ] The new Settings control remains readable and usable on desktop and mobile layouts and at large text scale by following the existing Settings patterns rather than introducing a new route or dialog.
- [ ] Unit or provider tests cover no individual ring for zero currently selected owning lists, no individual ring for exactly one currently selected owning list, equal-segment individual ring generation for multi-list currently selected ownership, ticked green triangle plus enabled ring overlay behavior, Tasmania precedence when the setting is off, non-Tasmania lowest-`peakListId` fallback when the setting is off, and deterministic 12 o'clock clockwise ordering.
- [ ] Widget tests cover the `SettingsScreen` toggle, its persisted rebuild behavior, and the main-map marker path showing no ring for single-list individual peaks and a ring for multi-list individual peaks through stable deterministic assertions rather than pixel-diff-only checks.

## Covers

- User Stories: 1, 3
- Requirements: 1-11, 18-23
- Technical Decisions: 1, 3-5
- Testing Strategy: 1, 2.1-2.6, 2.8, 4.1, 4.3, 6
- Interview Ledger: L1-L3

## Blocked by

None - ready to start
