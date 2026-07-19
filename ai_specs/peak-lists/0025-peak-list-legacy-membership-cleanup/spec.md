---
type: Spec
title: Peak List Legacy Membership Cleanup
---

## Problem

After `0024 Peak List Membership Performance And Export Responsiveness` lands, the app is still expected to carry temporary compatibility code for legacy JSON-backed membership. That likely includes the persisted `PeakList.peakList` field, JSON encode and decode helpers, migration-only startup logic, migration markers, and admin or integrity paths that exist only to bridge the old format. Leaving those temporary paths in place long term keeps the schema broader than necessary, preserves dead or risky code paths, and weakens the relational source-of-truth contract.

## Proposed Outcome

Peak-list membership is represented only by relational ObjectBox data in steady state. Temporary legacy JSON membership storage and migration-only code paths are removed after the relational migration has been verified against real existing user data. App-owned membership reads, writes, imports, admin views, maintenance flows, and integrity paths operate only on relational membership. `PeakList.peakList` and `PeakList.membershipState` are removed from the Dart model and ObjectBox schema entirely, and ObjectBox schema plus generated artifacts match that final design.

## User Stories

1. As a user maintaining `My Peak Lists`, I keep the same visible list behavior after the migration cleanup without regressions caused by leftover legacy compatibility paths.
2. As a maintainer working on peak-list features, I have one clear relational source of truth instead of temporary dual-format or migration-only code paths.
3. As an admin or support user inspecting peak-list data, I can inspect membership through relational data instead of a raw legacy JSON payload.

## Requirements

1. Treat this slice as follow-up cleanup after `ai_specs/peak-lists/0024-peak-list-membership-performance-and-export-responsiveness/spec.md` has been implemented, verified against real existing user data, and confirmed to have successfully migrated all 7 peak lists.
2. Remove `PeakList.peakList` from the `PeakList` Dart model and ObjectBox schema entirely; this slice must not keep the field as dead persisted debug or fallback data.
3. Remove migration-only membership state from `PeakList`, including `PeakList.membershipState`, from the Dart model and ObjectBox schema entirely.
4. Remove JSON membership helpers such as `encodePeakListItems` and `decodePeakListItems`, plus any app-owned call sites that still use JSON membership payloads for active behavior.
5. No steady-state app-owned membership producer or consumer may depend on legacy membership JSON after this cleanup completes. That includes membership read, write, lookup, import, export, dashboard summary, visibility or region filtering, `Tassy Full` maintenance, admin, duplicate-resolution, and delete-guard paths.
6. Remove migration-only branching, startup migration triggers, persisted migration markers, and migration-only loading or disabled states that are no longer needed once cleanup starts from the verified fully migrated state.
7. Remove unsupported-legacy peak-list guidance, warnings, and related blocked-action UI because no unsupported legacy peak lists remain at cleanup start.
8. Update `ObjectBox Admin` peak-list presentation to use relational membership data and stop exposing raw legacy `peakList` JSON.
9. Regenerate and commit any required ObjectBox schema artifacts, including `lib/objectbox.g.dart` and `lib/objectbox-model.json`, plus any schema-guard expectations that must change when the legacy field is removed.
10. Preserve existing user-visible peak-list behavior, labels, CSV output, and `Background job` behavior unless this Spec explicitly changes them.

## Technical Decisions

1. Reuse the relational membership contract established by `0024` as the only steady-state design for peak-list membership.
2. Prefer removing legacy compatibility code outright rather than leaving dormant fallback branches once the cleanup prerequisites are met.
3. Start cleanup only from the verified state where the previous slice has already migrated all 7 peak lists successfully, so this slice removes migration-only fallback UX and markers rather than preserving another legacy safety window.
4. Keep cleanup scoped to membership storage and its direct consumers; do not use this slice to redesign `My Peak Lists`, export UX, or ObjectBox Admin beyond what is needed to remove legacy membership storage.

## Testing Strategy

1. Add repository or service coverage proving no active membership path still requires `PeakList.peakList` JSON once cleanup is complete.
2. Add regression coverage for peak-list membership lookups, import, `Tassy Full` maintenance, duplicate resolution, delete guards, summary or visibility derivation, export preparation, and admin presentation using only relational membership data.
3. Add schema and codegen regression coverage for removal of the legacy membership field, removal of migration-only membership state including `PeakList.membershipState`, and corresponding schema-guard updates.
4. Preserve or extend widget and journey coverage where admin, `My Peak Lists`, or `Export Peak Lists` presentation changes as part of removing migration loading or unsupported-legacy UI.
5. Prefer existing fakes, provider overrides, in-memory repositories, and deterministic local seams. Automated coverage must not require live filesystem dialogs, network calls, or secrets.

## Verification

1. Run `dart run build_runner build --delete-conflicting-outputs`.
2. Run `flutter analyze`.
3. Run `flutter test test/services/peak_list_repository_test.dart test/services/peak_list_csv_export_service_test.dart test/services/objectbox_schema_guard_test.dart test/services/objectbox_admin_repository_test.dart test/services/peak_delete_guard_test.dart test/services/peak_list_coverage_backfill_service_test.dart`.
4. Run `flutter test test/providers/map_provider_peak_bootstrap_test.dart`.
5. Run `flutter test test/widget/peak_lists_screen_test.dart test/widget/peak_list_csv_export_settings_test.dart test/widget/objectbox_admin_shell_test.dart`.
6. Run `flutter test test/robot/peaks/peak_lists_journey_test.dart test/robot/objectbox_admin/objectbox_admin_journey_test.dart`.

## Out of Scope

1. Peak-list UI redesign or new list-management affordances.
2. New export CSV columns, ordering changes, or format redesign.
3. Reworking the `Background job` system beyond any direct cleanup needed to remove legacy membership storage.
4. A new migration of unrelated app-owned data models.

## Notes

1. Likely implementation surfaces include `lib/models/peak_list.dart`, `lib/services/peak_list_repository.dart`, `lib/services/peak_repository.dart`, `lib/services/peak_list_import_service.dart`, `lib/services/tassy_full_peak_list_sync_service.dart`, `lib/services/peak_list_summary_service.dart`, `lib/services/peak_list_visibility.dart`, `lib/services/peak_delete_guard.dart`, `lib/services/objectbox_admin_repository.dart`, `lib/providers/map_provider.dart`, `lib/providers/peak_list_selection_provider.dart`, `lib/screens/settings_screen.dart`, `lib/screens/peak_lists_screen.dart`, `lib/services/objectbox_schema_guard.dart`, `lib/objectbox.g.dart`, and `lib/objectbox-model.json`.
2. Parent migration work is defined in `ai_specs/peak-lists/0024-peak-list-membership-performance-and-export-responsiveness/spec.md`.
