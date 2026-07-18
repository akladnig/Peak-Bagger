---
type: Spec
title: Peak List Membership Performance And Export Responsiveness
---

## Problem

Peak-list membership is still stored as JSON inside `PeakList.peakList`, so common membership operations decode and rewrite whole list payloads instead of updating structured membership rows. The current peak-list add flow can also save selected peaks one-by-one, compounding the cost of repeated full-list rewrites. At the same time, `Export Peak Lists` already uses the app's `Background job` surface, but the app still becomes unresponsive during export, which breaks the existing responsive handoff contract. Peak-list edits also currently await map reload work even when `Map` is not visible, making common add and delete flows feel much slower than necessary. [L1] [L2] [L3]

## Proposed Outcome

Peak-list membership becomes a relational ObjectBox model backed by persisted `PeakListItem` rows, and all peak-list mutation, lookup, and export paths use that relational source of truth after migration. Common peak-list edits feel near-instant in normal local use, bulk add persists as one logical list update while preserving the current partial-success user experience, and `Export Peak Lists` hands off immediately to the existing `Background job` UI without freezing `Settings` or blocking shell navigation. Existing user-visible peak-list behavior and unsupported-legacy guidance stay intact unless this Spec explicitly changes them. [L1] [L2] [L3] [L4]

## User Stories

1. As a user maintaining `My Peak Lists`, I can add or remove a peak and see the current list update quickly instead of waiting tens of seconds for a simple edit. [L1] [L2] [L3]
2. As a user bulk-adding peaks to a list, I can save my selected peaks in one update while preserving the chosen points values. [L2]
3. As a user starting `Export Peak Lists`, I can keep using `Settings` or navigate elsewhere in the shell immediately after start while the export continues through `Background Jobs`. [L1] [L2]
4. As an existing user with older JSON-backed peak lists, I keep usable migrated lists and get clear unsupported-state handling for any legacy list that cannot be converted safely. [L1] [L4]

## Requirements

1. Preserve current peak-list UI behavior, labels, confirmations, and CSV column set unless this Spec explicitly changes them for correctness. This slice is a performance and responsiveness fix, not a peak-list UI redesign. [L1]
2. Persist peak-list memberships as relational `PeakListItem` rows linked to `PeakList` and `Peak`, carrying integer `points`. `PeakListItem.position` or another membership-order field is out of scope for this slice. After migration, these relational rows become the source of truth for peak-list membership reads, writes, lookups, exports, and peak-list-derived metadata. [L1] [L4]
3. No new steady-state code path may read or write `PeakList.peakList` JSON for active membership behavior after a list has been migrated successfully. Legacy JSON may exist only as migration input or unsupported legacy evidence until the final cleanup removes it. [L1] [L4]
4. Single-peak add, delete, or points-edit operations in a normal existing peak list must complete in about 1 second or less in local use, and must avoid whole-list rewrite behavior for small membership changes. [L2]
5. Multi-add from the peak picker must persist as one logical list update rather than one full save per selected peak, while preserving the per-peak points values chosen in the picker and the current partial-success UX: valid additions remain saved, failed additions remain selected, and the dialog reports the failed peaks without discarding successful adds. [L2]
6. Starting `Export Peak Lists` must return control to the app immediately, with the started snackbar and jobs entry appearing within about 250 ms, while `Settings` remains responsive and the user can still navigate between shell destinations during the in-app export. [L2]
7. This slice must preserve the existing `Background job` contract from `ai_specs/peak-lists/0011-background-jobs-import-export-progress/spec.md` for `Export Peak Lists`, including in-app-only execution, no user cancellation, and no new promise of OS-level background execution. [L2]
8. After a peak-list membership edit, the initiating peak-list surface must update immediately, including current list details, visible member count, points values, and current add or delete affordances. If the edited list is currently selected, the selection state must remain consistent immediately. [L3]
9. If `Map` is currently visible when a peak-list membership edit completes, peak-list-dependent map rendering must refresh immediately. If `Map` is not currently visible, the app must not block the mutation completion waiting for a full map marker reload; instead, the map-dependent peak-list state may refresh when `Map` next becomes active or resumes. [L3]
10. `Export Peak Lists` must not trigger unrelated map refresh work. [L3]
11. Before peak-list edit and export flows depend on relational memberships, run a one-time automatic migration for existing JSON-backed peak lists during app startup. [L4]
12. Startup remains non-blocking while that one-time migration runs. Until migration finishes, membership-dependent surfaces must not fall back to stale JSON-backed reads for active behavior; instead, they must show deterministic loading or disabled states for peak-list membership actions, `Export Peak Lists`, map peak-list selection surfaces, and other membership-dependent affordances that would otherwise depend on incomplete relational state. [L4]
13. For each list whose legacy JSON payload migrates successfully, the resulting relational `PeakListItem` rows become the only source of truth for that list's membership behavior. [L4]
14. The migration must use the app's existing one-time startup backfill pattern with a persisted completion marker so successfully migrated lists are not re-migrated on every launch. If startup migration cannot read one or more legacy payloads, the app must still finish startup, mark successful migrations complete, and leave unreadable lists in the unsupported legacy state. [L4]
15. If a legacy peak-list payload is malformed or unreadable, keep that peak-list row visible by name and deletable in `My Peak Lists`, but block add, remove, and edit actions for that affected list. Global `Export Peak Lists` must continue to run for supported lists, skip unsupported affected lists, and report those skips through the existing warning and completion semantics. Map peak-list selection surfaces must omit unsupported affected lists. If an unsupported affected list was selected or pinned previously, reconcile that map selection state automatically to a supported fallback without blocking navigation. Show the existing unsupported-state guidance instructing the user to delete and re-import the list, and surface a one-time non-blocking warning that some peak lists could not be migrated. [L4]
16. The migration path must not silently drop members, guess missing rows, or create partial migrated lists from malformed legacy payloads. [L4]
17. Peak-list export must preserve the existing CSV column set, warning semantics, and destination behavior while resolving membership from relational rows rather than decoding list JSON blobs. When unsupported migrated-failure lists exist, export supported lists only and report skipped unsupported lists as warnings rather than failing the whole export job. Exported list files must be processed alphabetically by peak-list name, and rows within each exported CSV must be sorted by peak name ascending with `Peak.osmId` ascending as the deterministic secondary key. [L1] [L2] [L4]
18. This slice must move app-owned peak-list membership reference paths to the relational source of truth, not only the visible peak-list edit and export surfaces. That includes membership lookups, peak-reference integrity paths such as duplicate resolution or peak delete guards, and other app-owned reads or writes that currently depend on `PeakList.peakList` JSON for active behavior. [L1] [L4]
19. Relational memberships must also drive peak-list-derived metadata such as region and stored bounds so migration and later membership mutations keep list-level derived fields consistent with the current relational memberships. [L1] [L3] [L4]
20. ObjectBox Admin peak-list membership presentation must be updated in this slice so it no longer implies `PeakList.peakList` JSON remains the authoritative membership source after migration. [L1] [L4]

## Technical Decisions

1. Reuse the project's canonical `Background job` terminology and existing shell-owned export jobs surface. The export portion of this slice fixes an implementation gap in responsiveness rather than redesigning the background-jobs feature. [L1] [L2]
2. Use the relational peak-list membership direction already described in `ai_specs/objectbox-admin/objectBox-fix.md`, `ai_specs/peak-lists/011-peak-lists-spec.md`, and related peak-list specs as the persistence source of truth for this work, but treat any earlier ordering or `PeakListItem.position` guidance as superseded by this Spec. During the migration window, legacy JSON-backed membership is migration input or unsupported legacy evidence only, not a long-term dual-write format. [L1] [L4]
3. Restructure peak-list mutation APIs around batch membership writes and direct membership queries so bulk add can persist one transaction or equivalent single logical update, and so membership lookups, integrity paths, and exports do not repeatedly decode full list payloads. [L2]
4. Keep off-screen map refreshes out of the synchronous mutation critical path. Reuse the current peak-list revision and map refresh seams where helpful, but do not require every peak-list mutation to await a full off-screen `Map` reload before returning success. [L3]
5. Treat export responsiveness as a user-visible contract rather than prescribing one concurrency mechanism. The implementation may use an isolate, chunked yielding, or another deterministic Flutter/Dart seam, but it must preserve responsive shell interaction and real `Background job` progress updates while export work runs. [L2]
6. Reuse the existing unsupported legacy-list behavior already present in peak-list specs for migration failures, rather than inventing silent repair or a new destructive migration UI. [L4]
7. Reuse the app's existing startup backfill and migration-marker patterns for the one-time peak-list membership migration rather than inventing a parallel migration trigger or persistence mechanism, and keep startup non-blocking while peak-list-dependent surfaces wait on deterministic loading or disabled states. [L4]

## Testing Strategy

1. Use behavior-first TDD for the relational membership migration and peak-list mutation logic before wiring the final UI refresh paths.
2. Add unit or service coverage for migration behavior, including successful JSON-to-relational migration with preserved points, malformed legacy payload handling that produces unsupported legacy behavior without partial membership writes, and persisted completion-marker behavior. [L4]
3. Extend repository or service coverage so automated tests prove membership reads, writes, lookups, integrity paths, and export preparation resolve from relational rows after migration rather than from `PeakList.peakList` JSON. [L1] [L4]
4. Add deterministic coverage for bulk add and common mutation paths so tests can assert that multi-add uses one logical list update path, preserves the current partial-success dialog behavior, and that single add, remove, and points-edit operations no longer depend on repeated full-list rewrites. [L2]
5. Extend export and background-job coverage, likely around `peakListCsvExportBackgroundRunnerProvider`, `background_jobs_provider`, and related Settings tests, to prove that `Export Peak Lists` starts immediately, leaves `Settings` responsive, allows shell navigation while progress continues through `Background Jobs`, skips unsupported migrated-failure lists with warning-bearing completion instead of failing the whole export job, processes lists alphabetically by peak-list name, and sorts exported rows by peak name ascending with `Peak.osmId` ascending as the deterministic secondary key. [L2] [L4]
6. Extend provider or widget coverage for peak-list edit side effects so the initiating peak-list surface refreshes immediately, `Map` refreshes immediately only when visible, off-screen peak-list mutations do not wait on a full map reload before returning success, and list-level derived metadata stays consistent with relational memberships after migration and mutation. [L3] [L4]
7. Add migration coverage for the startup trigger and persisted completion marker so tests prove successful lists migrate once, unreadable lists remain unsupported without blocking startup, membership-dependent surfaces use deterministic loading or disabled states until migration completes, and the one-time warning behavior is deterministic. [L4]
8. Prefer existing provider overrides, fake repositories, fake file writers, deterministic progress callbacks, and other local Test Seams. Automated coverage must not require live file-system dialogs, network calls, or secrets.
9. Add provider or widget coverage for unsupported migrated-failure lists so tests prove those lists remain visible with delete-and-reimport guidance in `My Peak Lists`, are omitted from map-selection surfaces, and selected or pinned unsupported lists reconcile to a supported fallback automatically. [L4]
10. Add ObjectBox Admin coverage so peak-list membership presentation reflects the relational source of truth and no longer implies `PeakList.peakList` JSON is authoritative after migration. [L1] [L4]
11. If service and widget tests alone cannot safely prove the cross-shell export responsiveness contract, add or extend a robot or journey test that starts `Export Peak Lists`, navigates away while it runs, and verifies durable `Background job` progress without an unresponsive app shell. [L2]

## Out of Scope

1. Peak-list UI redesign, copy changes, or new list-management affordances beyond the performance and responsiveness changes in this Spec. [L1]
2. New export CSV columns or other format changes unrelated to fixing the current performance path beyond the alphabetical export sorting defined in this Spec. [L1]
3. Platform background execution, user cancellation, retry queues, or a broader redesign of the existing `Background job` system. [L2]
4. Silent repair, guessed recovery, or partial salvage of malformed legacy peak-list payloads. [L4]

## Notes

1. Relevant current implementation surfaces include `lib/models/peak_list.dart`, `lib/services/peak_list_repository.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `lib/services/peak_list_csv_export_service.dart`, `lib/providers/peak_list_csv_export_provider.dart`, `lib/providers/background_jobs_provider.dart`, `lib/providers/map_provider.dart`, `lib/providers/peak_list_provider.dart`, `lib/providers/peak_list_selection_provider.dart`, and `lib/screens/settings_screen.dart`.
2. Related peak-list and background-job references include `ai_specs/objectbox-admin/objectBox-fix.md`, `ai_docs/solutions/cross-cutting/011-peak-list-relational-schema-alignment.md`, `ai_specs/peak-lists/011-peak-lists-spec.md`, `ai_specs/peak-lists/011-peak-lists-enhancements-spec.md`, `ai_specs/peak-lists/peak-list-selector-spec.md`, and `ai_specs/peak-lists/0011-background-jobs-import-export-progress/spec.md`.
3. Removing the legacy JSON field, migration-only code paths, and other temporary compatibility code is expected as a follow-up cleanup slice after the relational migration has been verified against real existing user data.
