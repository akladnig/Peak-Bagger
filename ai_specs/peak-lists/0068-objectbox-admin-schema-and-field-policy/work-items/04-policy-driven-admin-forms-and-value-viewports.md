---
type: Work Item
title: Apply field policy and value presentation to all five editors
parent: ../spec.md
---

## What to build

Integrate the shared structured field policy into the existing Peak, Natural Feature, Contact, Route and PeakList hand-built forms. Replace read-only text fields with labelled selectable values and apply five-line viewports to existing editable multiline inputs while preserving every approved editable capability, validation rule, stored field and draft. Work Item 05 completes the shared Cancel / Save and retained-shell departure baseline.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before affected feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, amendment 2026-10-19.
- `ai_specs/app-profile.md` — Desktop wide, local domain/formatting contracts and approved supported range.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/spec.md` — R3 validation meanings, R5–R7, R8 and Testing Strategy 3/5/6.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/interview-ledger.md`.
- `AGENTS.md`, `GLOSSARY.md`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/screens/objectbox_admin_screen.dart`, `lib/services/objectbox_admin_repository.dart`, `lib/providers/objectbox_admin_provider.dart` and the metadata/value components delivered by Work Items 02/03.
- `lib/services/peak_admin_editor.dart`, `lib/services/natural_feature_admin_editor.dart`, `lib/services/contact_admin_editor.dart`, `lib/services/route_admin_editor.dart`, `lib/services/peak_list_admin_editor.dart`, affected `lib/models/` sources and existing repository/provider action boundaries.
- `test/services/peak_admin_editor_test.dart`, `test/services/natural_feature_admin_editor_test.dart`, `test/services/contact_admin_editor_test.dart`, `test/services/route_admin_editor_test.dart`, `test/services/peak_list_admin_editor_test.dart`.
- `test/widget/natural_feature_admin_details_test.dart`, `test/widget/objectbox_admin_shell_test.dart`, `test/widget/objectbox_admin_browser_test.dart`, `test/harness/test_objectbox_admin_repository.dart` and other existing affected form/robot tests.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks.
Runtime support and dated evidence are unchanged. See `ai_specs/app-profile.md`.

- [x] The same structured policy used for Schema `Read-only` governs eligibility to create direct editable controls in all five existing hand-built forms. Explicit eligibility is required; missing metadata fails closed. Do not parse displayed Attributes, infer editability from names/record values or add a general automatic form generator.
- [x] Preserve exactly these existing direct editable fields and their intended input/control types, with no new entity editor or create flow:
  - `Peak`: `name`, `altName`, `osmId`, `peakbaggerPid`, `elevation`, `prominence`, `country`, `county`, `range`, `rating`, `durationLabel`, `difficulty`, `viaFerrata`, `notes`, `latitude`, `longitude`, `region`, `mgrs100kId`, `easting`, `northing`, `verified`.
  - `NaturalFeature`: `name`, `altName`, `tag`, `country`, `county`, `region`, `latitude`, `longitude`, `mgrs100kId`, `easting`, `northing`, `sourceOfTruth` through the existing **OSM / Manual** selector.
  - `Contact`: `firstName`, `surname`, `nickname`.
  - `Route`: `name`, `desc`, `visible`, `colour`, `distance2d`, `distance3d`, `ascent`, `descent`, `startElevation`, `endElevation`, `lowestElevation`, `highestElevation`.
  - `PeakList`: `colour`.
- [x] All other persisted fields have no direct Admin field editor. PKs (including assignable IDs) and explicitly system-managed generated values are non-editable. Policy does not revoke supported editable fields because their names look calculated, deny legitimate service writes or suppress distinct domain actions: retain Peak **Mark as HWC**, coordinate alternatives/calculation/conversions, duration parsing/derivation and Natural Feature identity/source-key maintenance.
- [x] Replace every read-only `TextField`/`TextFormField` in affected forms with labelled selectable content, not hidden information or disabled/read-only text fields. Retain appropriate scalar/boolean formatting/semantics, accessible label/value association and copy/select without text mutation or text-mutation accessibility actions. No app-owned `TextEditingController` exists solely for display; framework-managed read-only selection internals including `SelectableText`'s `EditableText(readOnly: true)` remain permitted.
- [x] Show exact **Not yet assigned** only for a new record's genuinely unassigned generated value. Preserve valid stored zero/empty values and other existing missing-value presentation. Do not change ID assignment, create behaviour or write placeholders/presentation strings back to records.
- [x] Existing validators remain unchanged: `Peak.name` is unconditionally required, optional non-nullable strings remain optional, nullable inputs retain their rules, and Contact accepts any one of first name/surname/nickname rather than making firstName individually Required. Retain grouped/conditional validation, coordinate alternatives and existing error timing/transformation/save boundaries.
- [x] Read-only form values reuse the shared component from Work Item 03: complete selectable/copyable content, independently scrollable cap of five rendered lines measured from active style/line metrics/wrapping width/text scale, recalculated on resize/theme/scale. Short values use needed height; labels/inline errors are outside the value cap. Read-only text-field widgets remain absent even when selection uses framework-managed internals.
- [x] Existing editable multiline fields, including Peak notes and Route description, retain the complete draft and independent scrolling within a measured maximum of five rendered content lines. Short content takes needed height; empty multiline controls retain their normal one-line minimum, not a forced three/five-line body. Ordinary single-line controls stay single-line. Retain draft text/selection and save/validation through scrolling, measurement, rebuild and resizing; no ellipsis/substrings/content loss or implicit save/cancel.
- [x] Editable controls inherit the prerequisite's amended central decoration without conflicting local overrides, field-associated tooltips, magnifying-glass prefixes on ordinary fields or individual submit buttons. Preserve visible labels, wrapping inline errors, accessible names, visible focus/traversal, Cmd+C, pointer affordances and pending/disabled/error states.
- [x] Existing save paths preserve unchanged/hidden persisted fields when rebuilding records. Unit tests through all five editor services verify editable outcomes plus unchanged PK/generated/read-only fields, duration/coordinate derivations and source-of-truth operations. Recoverable Save failure retains values and the draft for retry; no record writes occur during rendering or read-only interaction.
- [x] Deterministic widget tests cover all five editors, correct supported controls, fail-closed policy eligibility, labelled read-only selection and absence of `TextField`/`TextFormField` for those values, valid placeholder cases and non-mutation semantics. Do not assert blanket `EditableText` absence. Exercise long wrapped paragraphs/newlines, short/empty multiline values, independent scrolling to and selecting/copying a sentinel beyond line five, and complete text through Save. Preserve existing selectors where their meaning survives widget-type changes; verify controller/record identity cleanup on record/mode/route changes.
- [x] Verify both themes and a non-default seed, default/enlarged text scale, minimum content 1280 × 960 and representative larger widths/heights including height 960. Support width ≥1280 and height ≥960 with no fixed app-defined maximum using the same wide layout, wrapping/scrolling and reachable labels/errors/actions. Resize with an unsaved draft without losing selection or content. No compact/iOS layout, extra breakpoint, reduced text scale, native window/full-screen change or template parity claim; native full-screen Pending remains non-blocking.
- [x] Run the five `test/services/*_admin_editor_test.dart` files listed in Required context, focused affected Admin widget tests, `flutter analyze` and full `flutter test`; perform affected macOS runtime checks and record failures/blockers. Use existing mutable in-memory repositories/Riverpod overrides without network, credentials, mapping volumes, template checkout or user databases. Dispose owned resources; temporary Stores, if genuinely required, follow README native prerequisites and close before temporary-data deletion. Reuse affected robot regressions; no new robot framework or mandatory red-green process is required.
- [x] Preserve ObjectBox/Riverpod/GoRouter, existing data/service boundaries, `/objectbox-admin` and existing actions, deletion/confirmation, exports and map handoff. No model/generated edits, schema migration, new validation, preference or persistence boundary. Broader Admin capability gaps remain reported separately rather than becoming implicit exceptions or extra scope.

## Covers

- User Stories: 3, 4.
- Requirements: R1; R3.5–6 validation/date semantics; R5–R7; applicable R8 style/accessibility/draft safeguards, with cancellation/departure completed by Work Item 05.
- Technical Decisions: 2, 4–7.
- Testing Strategy: 3, 5–9.
- Interview Ledger: L3, L5–L7, L10, L13–L16.

## Blocked by

- [02-model-backed-schema-browser-and-recovery.md](02-model-backed-schema-browser-and-recovery.md)
- [03-selectable-five-line-detail-values.md](03-selectable-five-line-detail-values.md)

## Implementation evidence

Completed 2026-10-20; prerequisites Work Items 02 and 03 are complete. All 14 acceptance criteria are verified. See [Work Item 04 verification](../implementation-04-verification.md) for the five-editor policy/presentation audit, measured multiline/full-copy/draft tests, service retention, complete suite, existing robot journeys and 160 native macOS configurations. Work Item 05 retains cancellation/footer/retained-shell navigation scope.
