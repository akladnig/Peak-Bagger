---
type: Work Item
title: Remove Legacy Readiness Ux And User-Facing Membership Fallbacks
parent: ../spec.md
---

## What to build
Remove migration-only and unsupported-legacy user-facing behavior from `My Peak Lists`, map peak-list selection and visibility flows, summary derivation, and export-facing list behavior now that cleanup starts from a verified fully migrated state. Keep the current user-visible peak-list behavior, labels, CSV output, and `Background job` behavior unless this Spec explicitly changes them, but delete migration loading states, unsupported-legacy guidance, blocked-action UI, and any JSON-backed fallback membership reads that still drive app behavior.

## Required context
- `lib/screens/peak_lists_screen.dart`, `lib/widgets/map_peak_lists_drawer.dart`, `lib/providers/peak_list_selection_provider.dart`, `lib/providers/map_provider.dart`, `lib/services/peak_list_summary_service.dart`, and `lib/services/peak_list_visibility.dart` currently contain the readiness, unsupported-legacy, summary, and selection behavior that should be simplified to the post-cleanup steady state.
- `lib/screens/settings_screen.dart`, `lib/providers/peak_list_csv_export_provider.dart`, and `lib/services/peak_list_csv_export_service.dart` are the export-facing surfaces that must preserve current CSV and `Background job` behavior while no longer depending on legacy readiness or unsupported-list branches.
- Preserve existing stable widget keys, provider overrides, and robot seams used by `test/providers/map_provider_peak_bootstrap_test.dart`, `test/widget/peak_lists_screen_test.dart`, `test/widget/peak_list_csv_export_settings_test.dart`, and `test/robot/peaks/peak_lists_journey_test.dart`.

## Acceptance criteria
- [x] `My Peak Lists`, map peak-list selection, visibility, and summary behavior no longer expose migration loading or unsupported-legacy membership states once this cleanup starts from the verified fully migrated baseline.
- [x] Unsupported-legacy guidance, warnings, and related blocked-action UI are removed because no unsupported legacy peak lists remain at cleanup start.
- [x] User-facing membership consumers covered by this slice no longer fall back to removed JSON membership payloads for summary derivation, visibility filtering, selection reconciliation, or export preparation.
- [x] `Export Peak Lists` preserves the existing CSV output, warning semantics that still apply after cleanup, and `Background job` behavior while no longer depending on migration-only readiness or unsupported-legacy branches.
- [x] Existing peak-list labels and other preserved user-visible behavior remain unchanged except where this Spec explicitly removes migration-only or unsupported-legacy behavior.
- [x] Provider, widget, and robot regression coverage proves the steady-state post-cleanup user behavior across `My Peak Lists`, export settings, and peak-list journey flows using deterministic existing seams only.

## Covers
- User Stories: 1-2
- Requirements: 5-7, 10
- Technical Decisions: 1-4
- Testing Strategy: 2, 4-5

## Blocked by
- `01-remove-legacy-membership-schema-and-cleanup-scaffolding.md`
