# Work Item 02 verification

Date: 2026-10-20. Scope: [Work Item 02](work-items/02-model-backed-schema-browser-and-recovery.md), ADS-1.0 amendment 2026-10-19, Desktop wide.

## Implementation

- Discovery remains `ObjectBoxAdminRepository.getEntities()` over the injected `getObjectBoxModel()`. All **18 entities / 221 persisted members** are covered without sampling records or requiring a Store. Entity display labels, canonical-name de-duplication and model member order are retained.
- `lib/services/objectbox_admin_field_policy.dart` supplies reviewed Dart types/nullability, actual display-name designation, unconditional individual-input requirements, explicit generated facts and direct-input kinds. `ObjectBoxAdminFieldDescriptor.canEdit` combines that explicit policy with model PK/generated restrictions. Work Item 04 should consume this predicate and the metadata input kind in its hand-built forms; this item does not change forms or service write permissions.
- PK/assignable/unique facts, relationship targets and `ToOne` Dart aliases come from the model. `PeakListItemEntity.peakListId` remains one row with `ToOne<PeakList>`, its `peakList` alias and target; `GpxTrack.peaks` is `ToMany<Peak>`; ordinary integer IDs do not manufacture relationships. Persisted getter/setter values such as `Route.gpxRouteJson` remain included.
- Schema's semantic **Name** fact is independent of the legacy `isPrimaryName` Data-column-placement flag. Existing maintenance Data primary columns/details remain unchanged, without inventing Name attributes on keys or readiness state. Independent regression expectations cover this distinction.
- Metadata is structured, not parsed from Attributes. Unknown future mappings retain actual names/storage types, disclose **App metadata unavailable** and fail closed for editing/nullability/Required. Unknown storage codes retain their numeric value. `metadataCoverageIssues()` reports missing/stale members; coverage tests require zero issues for the current model.
- The read-only Schema table has exactly **Field / Type / Attributes** columns, shared `DataGridTheme` typography/padding/gaps/dividers, aligned proportional columns, wrapping/selectable complete metadata and an owned scroll controller. It adds no row actions, fake selection, schema editor or action column.
- Schema availability precedes Data loading/error rendering. Initial/refresh discovery errors use a separate schema error with **Retry**; stale descriptors are hidden, while the prior canonical name is retained privately for recovery. Retry restores its normalized descriptor, otherwise the first available entity, otherwise no selection. Data errors/retry remain separate. A row-read generation guard plus Riverpod disposal checks reject obsolete/disposed completions; failures retain diagnostic logging.

## Deterministic verification

- Repository tests check all model members/order, exact coverage, stale/missing metadata, independent semantic examples, all five exact editable sets, selector/boolean kinds, generated/assignable IDs, uniqueness, aliases, calendar-day versus timestamp meaning and numeric storage fallback. No new persistence regression was needed; existing repository tests continue to use their temporary Stores, closed before temporary-directory deletion.
- Provider tests cover initial/repeated discovery failure, refresh failure, canonical normalized recovery, first/no-entity fallback, pending/failing Data, stale row results and disposal. Fakes expose controlled discovery errors and pending row futures through the existing repository override.
- Routed browser tests exercise visible Retry, repeated failure, canonical selector recovery with duplicate descriptors, actual Schema columns/attributes, pending/failing Data, Data Retry, empty maintenance Schema and unavailable-app-metadata disclosure without a discovery error. Surviving Entity/mode/route/action selectors remain intact.
- Rendered Schema checks traverse every entity and access the last member. Representative relationship/maintenance tables run through light/dark, default/custom teal expressive seed, 1×/2× text, **1280 × 960**, **1600 × 960** and **1920 × 1200**. Full metadata remains selectable/wrapped without max-line truncation; normal focus traversal remains available. No compact layout, breakpoint or reduced text scale is introduced.
- Existing Admin shell, editor, map/export/delete/navigation and robot regressions are reused, not replaced by a new journey framework.

## Native macOS verification

- Command: `flutter run -d macos -t test/harness/verify_admin_schema.dart`.
- **PASS:** 32 supported size/theme/scale configurations: **1280 × 960 → 1600 × 1000 → 1600 × 960 → 1280 × 960**, default/custom light/dark and 1×/2× text. Actual controls and Schema remain in bounds. All 18 model-backed entities render, including maintenance types; long schemas scroll to their final persisted member and native focus traversal works without framework errors.
- The isolated fixture uses actual model discovery/components, no production startup, Store, Mapping volume, network, credentials or external checkout. Its controllers are disposed. It temporarily resizes only its own native window via existing macOS Accessibility/osascript access and restores the original frame; it does not change native window source, app minima, maximisation or full-screen policy.
- Initial fixture attempts exposed native window availability and occluded-vsync timing: one could not yet find window 1, one inspected a previous layout frame, and an unbounded end-of-frame wait timed out. The runner now waits boundedly for its window and schedules a fixture warm-up frame with a bounded frame timeout. The final native run printed all 32 configuration passes and the all-entity/focus/scrolling PASS. These were harness failures, not accepted app failures or visual-parity evidence.
- Flutter reports ObjectBox's existing Swift Package Manager fallback warning (see README). No generated/model/native-window/lockfile changes are included.

## Commands and outcomes

- `flutter test test/services/objectbox_admin_repository_test.dart test/providers/objectbox_admin_provider_test.dart --reporter expanded`: **pass, 33 tests** at that checkpoint.
- Final focused repository/provider/browser/shell/existing Admin robot run: **pass, 92 tests** (2:49); command uses `TZ=Australia/Hobart` and `test/robot/objectbox_admin` alongside the four required test files.
- Final `flutter analyze`: **pass, no issues**.
- Final complete `TZ=Australia/Hobart flutter test --reporter expanded`: **pass, 2708 tests, 7 skips** (24:48), including the Data-column-preservation regression and unavailable-metadata browser check. The earlier complete run also passed (2707 tests, 7 skips; 17:05).
- Earlier combined widget run exceeded the command timeout; the excessive entity × theme × size cross-product was reduced to all entities once plus representative tables across the full layout matrix. A subsequent test-only failure compared an in-flight animated theme with its target; the deterministic layout fixture now disables theme animation. The focused layout rerun passed.
- `git diff --check` and local Work Item/verification document links: **pass**. Generated/model/entity/native files have no diff.

## Boundaries and remaining alignment

No entity annotations, generated bindings, model UIDs/history, stored records, row loaders, delete handlers, editor capabilities or persistence boundaries change. ObjectBox/Riverpod/GoRouter ownership remains intact. All-entity Schema coverage is **not** all-entity mutation compliance.

Work Items 03–05 still own five-line values, policy-driven form integration and Cancel/Save/navigation locking. Broader Admin mutation-coverage gaps and the pre-existing explicit-submit Search/live-search alignment gap remain visible, not approved exceptions. Template work is separate; there are no template edits, shared package or external read dependency. Native full-screen remains Pending and non-blocking.
