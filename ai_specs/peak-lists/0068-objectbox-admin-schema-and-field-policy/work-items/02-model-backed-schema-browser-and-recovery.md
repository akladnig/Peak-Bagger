---
type: Work Item
title: Deliver accurate model-backed Schema browsing and recovery
parent: ../spec.md
---

## What to build

Deliver the read-only Field / Type / Attributes browser from actual persisted-model discovery plus complete structured app metadata. Define the authoritative Admin field-edit policy for later form integration. Keep Schema available independently of Data reads and add schema-specific discovery Retry/recovery without changing mutation coverage.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before affected feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, amendment 2026-10-19.
- `ai_specs/app-profile.md` — Desktop wide, local domain/date conventions and approved supported range.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/spec.md` — R1–R5, R8.2, Technical Decisions 1–4/6 and Testing Strategy 1/2/4/12.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/interview-ledger.md`.
- `AGENTS.md`, `GLOSSARY.md`, `README.md` for native-library prerequisites if a temporary-store regression is genuinely needed.
- `lib/services/objectbox_admin_repository.dart`, `lib/providers/objectbox_admin_provider.dart`, `lib/models/`, `lib/objectbox.g.dart`, `lib/objectbox-model.json` — generated/model files are read-only evidence.
- `lib/screens/objectbox_admin_screen.dart`, `lib/screens/objectbox_admin_screen_states.dart`, `lib/screens/objectbox_admin_screen_controls.dart`, `lib/theme.dart`.
- `lib/services/peak_admin_editor.dart`, `lib/services/natural_feature_admin_editor.dart`, `lib/services/contact_admin_editor.dart`, `lib/services/route_admin_editor.dart`, `lib/services/peak_list_admin_editor.dart` and existing hand-built forms as validation/editability evidence.
- `test/harness/test_objectbox_admin_repository.dart`, `test/services/objectbox_admin_repository_test.dart`, `test/providers/objectbox_admin_provider_test.dart`, `test/widget/objectbox_admin_browser_test.dart`, `test/widget/objectbox_admin_shell_test.dart`.
- `ai_specs/peak-lists/0056-objectbox-admin-entity-selector-resilience/spec.md` — canonical-name normalization/restoration and fallback.

## Acceptance criteria

- [x] `ObjectBoxAdminRepository.getEntities()` and injected `getObjectBoxModel()` remain the discovery seam. Schema covers all 18 current persisted entities, even with no records or no Data row loader: `Peak`, `Tasmap50k`, `GpxTrack`, `PeakList`, `PeaksBagged`, `Route`, `RouteGraphChunk`, `RouteGraphManifest`, `RouteGraphWayIndex`, `RouteGraphTrailDisplayChunk`, `Waypoints`, `PeakListItemEntity`, `RouteGraphImportMetadata`, `TrackReplacementRecoveryIssue`, `Contact`, `NaturalFeature`, `PeakRegionFingerprint`, `TrackDateMigrationMetadata`. Widgets do not maintain a second replacement entity list.
- [x] Every persisted property and declared ObjectBox relationship, including PK and persisted getter/setter `Route.gpxRouteJson`, appears once in model member order. Exclude transient members/non-persisted getters, not model-persisted getters. Preserve entity display labels, canonical-name de-duplication, selector identity and Spec 0056 selection restoration.
- [x] The existing `Schema` mode renders read-only columns exactly **Field**, **Type**, **Attributes**, in that order. Preserve **Entity**, **Schema / Data**, `/objectbox-admin` and **ObjectBox Admin**. Metadata wraps/scrolls completely with the prerequisite's central metrics; no schema editing, record actions or artificial action column is added.
- [x] Readable Dart types include `int`, `double`, `bool`, `String`, nullable `?`, `DateTime` and actual collection/relationship types. Do not sample records or equate integer date storage to Dart `int`. Preserve `GpxTrack.trackDate` as a calendar day despite `dateUtc`, without shifting its day or relabelling it as an instant.
- [x] Structured facts compose the exact applicable attribute terms `PK`, `Generated`, `Assignable`, `Name`, `Nullable`, `Non-nullable`, `Required`, `Unique`, `Read-only`. Model facts supply PK/assignable/unique/relationship information where available; explicit app metadata supplies reliable Dart types/nullability, actual display-name designation and existing validation/edit policy. Generated status is explicit, not a synonym for read-only; Required means an existing unconditional requirement for that individual Admin input, not constructor `required`, non-nullability or grouped/conditional validation.
- [x] Independently verified examples include non-assignable IDs as `PK · Generated`, assignable `Peak.id` as `PK · Assignable` and Admin-read-only, `Peak.name` as `String` with `Name · Non-nullable · Required`, `Peak.altName` as `String` with `Non-nullable`, `Peak.peakbaggerPid` as `int?` with `Nullable`, and `Contact.firstName` as `String` with `Name · Non-nullable` but not individually Required. Do not invent a Name field on maintenance entities. Other independently accurate attributes may compose with these examples.
- [x] Keep generated backing names in Field. `PeakListItemEntity` includes `peakListId | ToOne<PeakList> | Dart field: peakList · → PeakList · Read-only`, with only independently accurate additional attributes and no duplicate alias row. `GpxTrack.peaks` shows its actual ToMany type/target; `PeaksBagged.peakId` stays an ordinary `int`. Non-nullable relationship-wrapper metadata does not imply a required target; an `Id` suffix does not manufacture a relation.
- [x] One structured edit policy defines explicit direct-input eligibility and Schema `Read-only`. All PKs, including assignable IDs, and explicitly system-managed generated values are non-editable; absent metadata fails closed. Encode exactly R5.3's existing editable field sets for Peak, NaturalFeature, Contact, Route and PeakList, including the `OSM / Manual` selector, for consumption by Work Item 04. No general form generator, additional mutable field/entity/editor/create flow, row loader or delete handler is added. Preserve distinct domain actions/derivations such as **Mark as HWC**, coordinate calculation, duration parsing and Natural Feature identity/source-key maintenance.
- [x] Complete reviewed app metadata covers every current model member. Future missing mappings retain actual names/storage types, disclose unavailable app metadata and never enable editing or guess nullability/Required; unknown storage codes have an intelligible numeric fallback. Coverage tests fail on missing/stale mappings even though runtime browsing remains usable. Unavailable app metadata is not a metadata-discovery failure.
- [x] With valid discovered metadata and an entity, Schema renders immediately during pending or failed `loadRows`, including empty maintenance entities and entity selection. Returning to Data preserves its distinct loading/error/recovery behaviour; records/network are not dependencies of metadata lookup. Preserve diagnostic logging and guard obsolete async/disposed completions from corrupting current state.
- [x] Initial metadata-discovery failure shows a schema-specific error and labelled **Retry**, not a Data error, empty-schema state or complete-looking table. Failed metadata refresh retains the previous canonical entity name for recovery but shows schema-error/Retry instead of stale metadata as current. Retry reruns discovery without record writes; repeated failure retains error/Retry. Success restores the same canonical name using its normalized descriptor, otherwise the first available entity, otherwise no selection for an empty list. Data errors/loading stay separate.
- [x] Extend repository, provider and browser/shell tests through the existing fakes/overrides: all entities/members, duplicate/stale coverage, source-independent semantic expectations, fail-closed fallback, pending/failing Data, initial/refresh discovery failures, visible Retry, repeated failure and all canonical recovery fallbacks. Preserve surviving stable selectors and existing Data/navigation/action semantics.
- [x] Verify light/dark and non-default seed, readable full metadata, keyboard traversal and enlarged text scale at 1280 × 960 and representative larger widths/heights (minimum height 960). Support width ≥1280 and height ≥960 with no fixed app-defined maximum, one wide composition and wrapping/scrolling; no compact/iOS layout, new breakpoint, native window/full-screen change, reduced text scale or template visual-parity claim. Native full-screen remains Pending and non-blocking.
- [x] Run `flutter test test/services/objectbox_admin_repository_test.dart`, `flutter test test/providers/objectbox_admin_provider_test.dart`, affected browser/shell regressions, `flutter analyze` and full `flutter test`; record affected macOS runtime checks/failures. Use model discovery without a production Store, controlled fakes and Riverpod overrides; no mapping volumes, network, credentials or template checkout. Dispose owned resources; if a temporary Store is needed, follow README prerequisites and close it before deleting temporary data. No mandatory red-green process/new robot framework; reuse affected robot regressions.
- [x] ObjectBox/Riverpod/GoRouter and existing service/data boundaries remain intact. Do not change entity annotations, model UIDs/history, `objectbox-model.json`, `objectbox.g.dart`, stored records or persistence boundaries. Template adoption remains a separate follow-up with no template edits/shared package/external read dependency. All-entity schema coverage is not all-entity mutation compliance; report broader baseline gaps without silently adding capabilities or approving exceptions.

## Covers

- User Stories: 1, 2, 5.
- Requirements: R1–R4; R5 policy definitions; R8.2 and applicable shared-style/accessibility integration.
- Technical Decisions: 1–4, 6–7.
- Testing Strategy: 1, 2, 4, 7–9, 12.
- Interview Ledger: L1–L6, L8, L9, L12, L14–L16. L2 is covered by explicit Peak Bagger-only scope and the separate template follow-up.

## Blocked by

- [01-shared-field-and-data-grid-styling.md](01-shared-field-and-data-grid-styling.md)

## Implementation evidence

Completed 2026-10-20; prerequisite Work Item 01 is complete. See [Work Item 02 verification](../implementation-02-verification.md) for metadata/policy ownership, Schema/Data recovery, preserved Data-column semantics, supported-size/native checks and command outcomes. All 15 acceptance criteria are verified; broader Admin alignment and Work Items 03–05 remain separately scoped.
