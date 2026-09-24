---
type: Work Item
title: Natural Feature ObjectBox Admin
parent: ../spec.md
---

## What to build

Add the Natural Feature-specific ObjectBox Admin read, search, details, coordinate-edit, save, and confirmed-delete vertical slice. Extend the existing entity-specific row-loading, display resolution, search, details-pane, save, and deletion seams; the generic fallback is insufficient. Do not add an `Add Natural Feature` button.

Model the details interaction on Peak coordinate editing, but implement a Natural Feature editor that uses the record's derived grid zone for MGRS-only input rather than Peak's fixed `55G` parser. Preserve the exact Natural Feature validation and source-of-truth behavior, and disable every Natural Feature mutation while a `refreshNaturalFeatures` Background job runs.

## Required context

- `lib/services/objectbox_admin_repository.dart`, `lib/screens/objectbox_admin_screen.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/screens/objectbox_admin_screen_table.dart`, and `lib/screens/objectbox_admin_screen_controls.dart` are the entity-specific Admin extension points.
- `lib/services/peak_admin_editor.dart` and `test/services/peak_admin_editor_test.dart` define the Peak-style form behavior to match, except its fixed-`55G` parser must not be reused.
- `03-background-job-settings-refresh.md` supplies the `refreshNaturalFeatures` busy state that this slice must observe.
- Extend `test/robot/objectbox_admin/objectbox_admin_robot.dart` and its journey tests with stable Natural Feature selectors and deterministic repository/background-job seams.

## Acceptance criteria

- [x] ObjectBox Admin displays the collection as `Natural Features`, uses the selected `name` as the details title with `{osmType} {osmId}` only when no name is available, and retains current ID-based ascending and descending table sorting.
- [x] Search is case-insensitive across only `name`, `altName`, `tag`, `osmType`, and decimal `osmId`; it does not search country, county, region, coordinates, MGRS fields, or source of truth.
- [x] The details form exposes every Natural Feature field except `id`, `osmType`, `osmId`, and derived `gridZoneDesignator`; those identity fields and the grid zone are read-only.
- [x] Saving trims all editable text, requires non-empty `name` and `tag`, accepts only `OSM` or `Manual` for `sourceOfTruth`, rejects an `altName` equal to `name` after trimming and case-insensitive comparison, and retains the existing inline-validation, cancellation, and persistence-failure form behavior.
- [x] Latitude/longitude input recalculates all MGRS fields including the derived grid zone. MGRS-only input parses against the currently stored derived grid zone and cannot change zones. The form otherwise matches Peak coordinate validation, calculation, save, and cancellation behavior without Peak/HWC provenance semantics.
- [x] The details pane lets an administrator change `sourceOfTruth` between exactly `OSM` and `Manual`; changing to `OSM` restores next-refresh eligibility.
- [x] Natural Feature deletion requires the existing confirmed-delete interaction, removes the local row without a tombstone or suppression store, and allows a later matching source refresh to recreate it as `OSM`.
- [x] During a running Natural Feature refresh, every Natural Feature mutation action is disabled, including Save on an already open form and delete.
- [x] Unit, widget, and robot coverage verifies non-`55G` MGRS behavior, read-only identity/grid-zone fields, edit/save validation, search boundaries, confirmed deletion, absence of Add Natural Feature, and mutation disablement with stable selectors.
- [x] Run the ObjectBox schema guard, targeted Natural Feature unit/widget/robot tests, `flutter analyze`, and the full `flutter test` suite.

## Covers

- User Stories: 2, 4
- Requirements: 7, 10, 12, 15-17
- Technical Decisions: 4-5
- Testing Strategy: 3, 5-6
- Interview Ledger: L6, L8, L10, L11

## Blocked by

- `01-objectbox-entity-foundation.md`
- `03-background-job-settings-refresh.md`
