---
type: Spec
title: Peak List Colours
---

## Problem

Unticked peaks currently share one reddish marker colour, so users cannot distinguish peak-list membership on the map when multiple lists are visible. The same lack of colour identity also leaves the map app bar and Select Peaks drawer without a shared visual connection to list-coloured markers. [L1] [L2]

## Proposed Outcome

Peak Bagger stores a persistent `PeakList.colour` accent colour for each peak list and uses that stored colour consistently across unticked map markers and related peak-list controls on the map route. Ticked peaks remain green. Unticked peaks that belong to multiple visible lists use the visible matching list with the lowest `peakListId`. The implementation reuses current Riverpod-owned peak-list selection and pinning state, adds one persisted list-colour source of truth with deterministic fallback for legacy `colour == 0` rows, and extends the existing map marker and peak-list control rendering paths without changing map-route entry, exit, back, or drawer-opening behavior. [L1] [L2]

## User Stories

1. As a map user, I want unticked peaks from different visible peak lists to use different colours so I can distinguish list membership at a glance without losing the existing green ticked cue.
2. As a map user, I want the same peak-list colour identity to appear in the map app bar and Select Peaks drawer so the controls match the list-coloured peaks on the map.
3. As a map user, I need peaks that belong to multiple visible lists to use a clear, non-ambiguous visual contract by taking the visible matching list colour with the lowest `peakListId`.
4. As an admin user, I want `PeakList.colour` to be visible and editable in ObjectBox Admin with the same `Colour` field contract used for `Route.colour` so I can override default list colours without changing normal peak-list flows.

## Requirements

1. Preserve the current green colour meaning for ticked peaks. This feature changes the unticked peak colour contract only. [L1]
2. Add a persisted `PeakList.colour` `int` field as the stored source of truth for list accent colour. The default and fallback palette, in order, is `0xFF4C8BF5`, `0xFF12B886`, `0xFF6347EA`, `0xFFE67E22`, `0xFFD6336C`, `0xFF0EA5E9`, `0xFFA16207`, and `0xFF7C4DFF`. New peak lists and imported peak lists must save a non-zero ARGB colour value using `palette[(peakListId - 1) % palette.length]` after the persisted `peakListId` is known when no non-zero colour is already provided. Existing rows that load with `colour == 0` must use the same deterministic fallback rule until an admin save sets an explicit non-zero value. [L1]
3. Replace the current single unticked marker colour with per-peak-list colouring for unticked peaks on the main map. If an unticked peak belongs to multiple visible lists, use the visible matching list with the lowest `peakListId`. [L1]
4. Apply the same peak-list colour identity to map-route peak-list controls, including the map app bar summary row and the Select Peaks drawer rows. Selected list controls use a full list-colour background with contrast-aware foreground text and icons derived from the fill colour. Unselected list controls use a neutral control background with a list-colour accent. `All Peaks` and `None` remain neutral and never use a list colour. [L2]
5. Do not change how the map route is entered, how the peak-lists drawer opens or closes, or how back and cancel behavior work for this flow.
6. Preserve the current marker shape, current white triangle outline, and current map interactions unless a blocker resolution explicitly changes one of those contracts. [L1]
7. Preserve current peak-list selection, pinning, and visible-region behavior; this feature changes visual styling, persisted `PeakList.colour`, and any derived colour metadata, not the ownership of those state machines. [L2]
8. Add admin-only peak-list colour editing in ObjectBox Admin using a dedicated `PeakList` details pane with the same read-only-to-edit entry pattern used by `Route`. In this feature, only `colour` is editable; `peakListId`, `name`, `region`, and `peakList` remain read-only. The `Colour` field uses the same contract as `Route`: it is stored as an integer, displayed as a hex string, and validated with the same integer-or-hex parsing rules. Admin-entered colours remain unrestricted integer or hex values and are not clamped to the default palette. Do not add regular user-facing colour editing to the standard peak-list screens, create dialog, or import dialog.
9. On peak-list repository load failure, preserve the existing drawer unavailable-state copy exactly: title `Peak lists unavailable` and subtitle `Using current selection until lists reload.` On unreadable individual peak-list payloads, exclude that list from decoded membership-dependent marker colouring, hide it from the Select Peaks drawer, and keep it visible in the map app bar summary row only when it is already selected or pinned, using a neutral control treatment with no list-colour styling. Keep other valid peak lists and the rest of the map route working without crashes.
10. The visual contract must remain legible on desktop and mobile layouts, and the map app bar and drawer controls must remain readable and usable at default text scale and `TextScaler.linear(2.0)`.
11. The feature must not require network calls, secrets, or user-managed configuration to resolve colours at runtime.

## Technical Decisions

1. Keep source-of-truth ownership split across existing layers: `mapProvider` continues to own selected and pinned peak-list state, while `PeakList.colour` becomes the persisted colour source of truth read through existing peak-list repository/provider layers and consumed by `peak_list_selection_provider`, `MapPeakListsDrawer`, `PeakListSelectionSummaryStrip`, `PeakMarkerGlyph`, and `MapScreenPeakLayer`. [L1] [L2]
2. Introduce one reusable peak-list colour resolver or view model so map markers and peak-list controls consume the same mapping rather than duplicating colour-selection logic. The resolver must prefer stored `PeakList.colour` when non-zero and otherwise return the deterministic default or fallback palette entry `palette[(peakListId - 1) % palette.length]`. [L1] [L2]
3. Extend the current unticked marker rendering path to carry list-colour metadata while preserving current ticked/unticked ordering, cluster behavior, hit-testing, and hover behavior unless a blocker resolution explicitly changes the marker contract. Multi-list membership is resolved by deriving visible matching peak-list ids from existing peak-list content and current visible selection, then choosing the lowest `peakListId`. [L1]
4. Treat this feature as client-side presentation plus one persisted `PeakList` field. It should not add a new external API boundary or move peak-list ownership out of the existing Flutter client.
5. Follow the existing `Route` admin-editing pattern for colour editing by adding a dedicated `PeakList` ObjectBox Admin details pane with explicit edit mode, save handling, and success or failure feedback. In this feature, only the `Colour` field is editable; the remaining `PeakList` fields stay read-only, and no new normal user-facing edit surface is added.
6. Allow the minimal ObjectBox and repository work needed to add `PeakList.colour`, regenerate schema code, preserve backward-compatible reads of legacy `colour == 0` rows, and keep deterministic colour behavior without a separate migration wizard or background sync workflow.

## Testing Strategy

1. Use vertical-slice TDD for `PeakList.colour` storage and defaulting, list-colour resolution logic, derived presentation state, ObjectBox Admin colour editing, and widget rendering changes.
2. Add unit or provider coverage for stored-colour precedence, deterministic `colour == 0` fallback, same-list same-colour stability, unreadable-data fallback, and the lowest-`peakListId` multi-membership winner rule used by marker rendering.
3. Add widget coverage for the map app bar summary row, Select Peaks drawer rows, and marker rendering paths so selected, unselected, pinned, unreadable-data, `TextScaler.linear(2.0)`, and constrained-width cases are exercised.
4. Prefer extending existing peak-list test seams such as `test/widget/map_peak_list_selection_test.dart`, `test/providers/peak_list_selection_provider_test.dart`, `test/providers/map_peak_list_selection_state_test.dart`, `test/providers/map_peak_list_selection_persistence_test.dart`, and adjacent map widget coverage rather than creating parallel harnesses. For admin colour editing, add adjacent ObjectBox Admin service and widget coverage following the existing `Route` colour-editing pattern.
5. If the final implementation changes a critical map-shell journey or introduces a new actionable colour indicator, extend `test/robot/map/peak_list_pins_journey_test.dart` and `test/robot/map/peak_list_pins_robot.dart` with stable app-owned selectors so the drawer and app bar can be verified together. Do not require marker-colour robot assertions unless the implementation also adds stable app-owned marker selectors.
6. Prefer in-memory repositories, Riverpod overrides, and existing app-owned seams over real network calls, real external services, or secrets in automated tests.
7. If full map-layer painting is difficult to assert directly in widgets, expose a small deterministic seam around the colour resolution or marker presentation model instead of relying on nondeterministic gesture-driven map assertions.
8. Add coverage for ObjectBox schema/model/repository updates, including new-list default colour assignment, imported-list default colour assignment, and legacy rows that load with `colour == 0`.
9. Verify ObjectBox schema updates with `dart run build_runner build --delete-conflicting-outputs`, then run `flutter analyze`, `flutter test test/services/peak_list_admin_editor_test.dart`, `flutter test test/providers/peak_list_selection_provider_test.dart`, `flutter test test/widget/map_peak_list_selection_test.dart`, and `flutter test test/widget/objectbox_admin_shell_test.dart`.

## Out of Scope

1. User-defined custom colour picking or palette editing in normal peak-list user flows.
2. Replacing the green ticked marker contract.
3. Changing peak-list selection, pinning, or visible-region business rules beyond what is needed to carry visual colour identity.
4. Broad non-map-route redesigns.
5. Adding regular non-admin peak-list colour editing to the standard peak-list screens, create dialog, or import dialog.

## Notes

1. Current ticked and unticked colours are defined in `lib/theme.dart` as `tickedColour` and `untickedColour`.
2. Current map markers only receive `ticked` state in `lib/widgets/peak_marker_glyph.dart` and `lib/screens/map_screen_peak_layer.dart`, so per-list colour work will require an expanded marker presentation model.
3. Current map-route peak-list controls use shared outlined-button styling in `lib/widgets/peak_list_selection_summary.dart`, `lib/widgets/map_peak_lists_drawer.dart`, and `lib/widgets/drawer_outline_button.dart`.
4. `PeakList` currently has no `colour` field, while `Route` already persists `colour` and edits it through the ObjectBox Admin `Colour` field contract.
5. `PeakList` is currently read-only in ObjectBox Admin, so this feature must add a dedicated `PeakList` details pane and save path rather than only adding one extra field to an existing edit form.
