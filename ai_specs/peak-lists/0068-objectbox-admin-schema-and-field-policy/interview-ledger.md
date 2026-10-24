---
type: Interview Ledger
parent: spec.md
---

## Records

### L17

Status: current

Source: explicit user request, 2026-10-21: "there are too many theme related tests. update the specs/tests etc. so that testing is only carried on my seed colour and dark mode only - do not test with other colours."

Decision: Future automated, native and visual verification uses only My Seed Colour
(`#7E47EB`, `baseColor`, `MyTheme.dark`) in dark mode. Remove alternate theme/seed
matrices while retaining distinct behaviour/failure/scale/resize coverage. This
changes verification scope, not runtime theme support, earlier answers or dated
test/evidence records. Apply the app profile's theme testing scope across this
Spec and its Work Items.

### L1

Status: current

Question: Is the intended outcome a clearer ObjectBox Schema view rather than changes to persisted entities and fields?

Recommended Answer:
- Improve schema presentation without migrating the database or changing stored values.
- Replace raw type codes with understandable types and accurate field attributes.

Answer: "yes"; the user cited the template's `int`, `PK · Generated`, `Required` and `Read-only` presentation, then confirmed the proposed read-only schema table with "that sounds good".

Decision: Replace the existing Schema list presentation with a read-only `Field / Type / Attributes` table. Preserve the actual database schema, model identity and stored content.

Answer History:
- The initial proposal was display-only.
- L6 subsequently extends UI scope to enforcement of field-edit policy in existing Admin forms, without authorising schema changes or new mutation capabilities.

### L2

Status: current

Question: Should the same approach be adopted in the starter template as part of this work?

Answer: "I think the same approach should be used in the template but I want to implement that separately."

Decision: Scope this Spec to Peak Bagger. Keep the template implementation as a separate follow-up, with no template edits or required shared package in this feature.

### L3

Status: current

Question: Should Peak Bagger use model-backed discovery plus explicit field metadata instead of the template's completely handwritten schema list?

Recommended Answer:
- ObjectBox metadata determines persisted entity/field coverage and available storage attributes.
- Structured Peak Bagger descriptors supply additional Dart type, nullability, display-name, validation and Admin edit-policy information.
- Keep nullability separate from validation requirements; never infer either from existing records.
- Check descriptor coverage against the generated model in tests.

Answer: "yes"

Decision: Combine actual-model discovery with structured app metadata. Derive visible attribute strings from metadata rather than making preassembled strings the source of truth.

### L4

Status: current

Question: Should the Schema table cover every persisted entity, including entities with no records?

Recommended Answer:
- Use all-persisted-entity schema coverage, not Peak-only or a selected schema subset.
- Include persisted properties and relationships; exclude non-persisted members.
- Do not expand Data-mode editing or deletion.

Answer: "yes"

Decision: Cover every entity in the actual generated model, including empty and maintenance entities. Schema coverage does not grant mutation capabilities.

Source: The final source audit of `lib/objectbox.g.dart` and `test/services/objectbox_admin_repository_test.dart` identifies 18 persisted entities.

Answer History:
- The interview recommendation mistakenly enumerated 14 entities based on row-loader dispatch.
- The final model audit identified four more: `RouteGraphImportMetadata`, `TrackReplacementRecoveryIssue`, `PeakRegionFingerprint`, and `TrackDateMigrationMetadata`. The approved all-persisted-entity intent governs; 14 is not a coverage limit.
- The assistant corrected its overly broad exclusion of computed getters: a getter/setter persisted in the generated model, such as `Route.gpxRouteJson`, remains included. Only non-persisted getters and transient members are excluded.

### L5

Status: current

Question: Should nullability be distinguished explicitly from required Admin input?

Recommended Answer:
- `Nullable / Non-nullable` describe the Dart value's ability to hold null.
- `Required` describes an existing unconditional requirement for that individual Admin input.
- Do not mark every non-nullable field Required or translate grouped/conditional validation into individual requirements.
- Preserve validation, including optional empty strings and grouped Contact-name requirements.

Answer: "agreed"

Decision: Model and display nullability separately from required input. For example, `Peak.name` is `Name · Non-nullable · Required`, `Peak.altName` is `Non-nullable`, and `Peak.peakbaggerPid` is `Nullable` with type `int?`. `Contact.firstName` is not individually Required.

Answer History:
- An early recommendation used Required as a synonym for non-nullable.
- Source inspection exposed optional non-nullable strings and grouped validation. The final distinction above replaces that recommendation.

### L6

Status: current

Question: Should one explicit Admin field-edit policy govern both Schema labels and existing Admin forms?

Recommended Answer:
- Yes: eligibility for an editable field must be explicitly enabled in structured metadata; absent policy must not accidentally enable an input.
- PKs and explicitly system-managed generated fields have no direct editable inputs.
- Assignable ObjectBox IDs do not automatically permit Admin editing.
- Preserve currently supported editable fields, existing validation and existing domain actions.
- Keep hand-built forms; do not introduce a general automatic form generator.

Answer: "yes"

Decision: Use one authoritative field-edit policy for schema `Read-only` attributes and direct editor eligibility. Generated status, primary-key status and Admin editability are distinct concepts. This is an explicit extension of the original display-only UI scope.

### L7

Status: current

Question: Should read-only values remain visible in edit forms as labelled selectable text instead of disabled text fields?

Recommended Answer:
- Retain visible read-only values and labels, including IDs, with copy/select support.
- Create no `TextField` or `TextFormField` for those values, including disabled fields.
- For a new record's generated value that has not been assigned, show `Not yet assigned`.
- Preserve supported editable inputs.

Answer: "agreed"

Decision: Present read-only values as labelled selectable content, not disabled or read-only text-field widgets. Do not hide existing read-only form information merely to remove its input widget.

### L8

Status: current

Question: When a stored relationship field name differs from its Dart name, should Schema show both without duplicating the field?

Recommended Answer:
- Retain the actual stored name in Field; show the Dart relationship type in Type.
- Include the Dart alias and target in Attributes.
- Show each persisted property/relationship once.
- Do not infer an ObjectBox relationship solely from an `Id` suffix.

Answer: "agreed"

Decision: For example, show `peakListId | ToOne<PeakList> | Dart field: peakList · → PeakList · Read-only`. Keep `PeaksBagged.peakId` as `int`, because it is an ordinary stored integer, not an ObjectBox `ToOne`.

### L9

Status: current

Question: Should the feature settle the project's window dimensions or retain them as Pending?

Recommended Answer:
- Keep minimum usable macOS width, height and supported resize range Pending in this feature Spec.
- Metadata, edit-policy and other non-layout logic may proceed independently.
- Block dependent table/form layout implementation and size-specific acceptance until the supported window range is resolved.
- Do not invent dimensions or add compact/iOS layouts.

Answer: "agreed"

Decision: Carry the named project-profile Pending values as explicit blockers for affected layout work. This Spec does not approve observed native dimensions or historical feature-specific dimensions as current app-wide targets.

Answer History:
- The subsequent explicit minimum-size decision in L14 resolves the minimum usable width/height as 1280 × 960 logical points. L15 then resolves the supported resize range as this minimum and larger, with no fixed maximum. L16 resolves this feature's thresholds: retain one wide layout with wrapping/scrolling and no additional breakpoints. The original answer above is retained as history, not a competing unresolved layout target.

### L10

Status: current

Question: Does the five-line scrolling limit apply to all field values, including record details, read-only form values and editable multiline text?

Recommended Answer:
- Apply a maximum viewport of five rendered lines to all long field values in those surfaces, not only current Route/GPX exceptions.
- Measure against wrapping width, active text style and text scale; independently scroll each value without truncating content.
- Keep read-only values selectable/copyable; short values use only their needed height.
- Keep ordinary single-line inputs single-line and stored content unchanged.
- Schema field names, types and attributes wrap normally; they are not value editors.

Answer: The user first requested "also confirm that the 5 line scrolling limit for all fieldswill be implemented", then answered "yes" to the clarified scope above.

Decision: Implement the five-line maximum consistently across all Admin record-detail values, read-only edit-form displays and existing editable multiline text fields. Verify scrolling/selecting content beyond line five; do not rely on `SelectableText(maxLines: 5)` alone.

### L11

Status: current

Question: Should the pending-Save navigation lock cover leaving Admin even when the shell keeps its editor mounted, with permitted idle departure discarding the draft without a write?

Recommended Answer:
- While saving, block all navigation away from Admin, including side-menu/shell destination changes, supported keyboard navigation and programmatic navigation, even if the retained shell branch is not disposed.
- When idle, permitted departure discards unsaved edits without writing; preserve existing re-entry/refresh behaviour rather than introducing cross-destination draft retention.
- Verify these paths through the real routed shell, not only local Cancel/Close tests.

Answer: "yes"

Decision: Treat departure from the retained Admin shell branch as dismissal for the save-lock policy. Enforce the lock at authoritative action/navigation boundaries, including callbacks retained before a rebuild. Preserve permitted idle draft-discard and existing re-entry/refresh behaviour. Implement and verify in Spec R8.1 and Testing Strategy 10.

Source: Individual finding discussion during the subsequent refinement on 2026-10-19. The user later explicitly approved applying the focused changes and requested "also update the ledger". This record appends a refinement decision; it does not rewrite L1–L10 or resolve the Pending layout gates in L9.

### L12

Status: current

Question: Should schema-discovery failures have an explicit Retry interaction with canonical entity-selection recovery, separate from Data loading/errors?

Recommended Answer:
- An initial discovery failure shows a schema-specific error with Retry, not an empty or complete-looking table.
- After a failed metadata refresh, retain the previous canonical entity name for recovery but show the schema error rather than presenting stale metadata as current.
- Retry rediscovers metadata without writing records. Restore the same entity by canonical name when available; otherwise use the existing first-entity/no-selection fallback.
- Keep Data loading/errors separate and verify initial and refresh failure→recovery deterministically.

Answer: "yes"

Decision: Add the labelled Retry recovery contract for initial metadata-discovery and metadata-refresh failures. Successful recovery restores the prior canonical entity using the normalized descriptor when available, otherwise the first available entity or no selection for an empty discovered entity list. Repeated failure retains error/Retry. Keep this separate from Data state and the runtime fallback for unavailable app metadata. Implement and verify in Spec R8.2 and Testing Strategy 12.

Source: Individual finding discussion during the subsequent refinement on 2026-10-19; artifact updates were explicitly approved afterward. This record supplements the model-discovery and canonical-identity contracts without changing earlier answers.

### L13

Status: current

Question: May read-only selectable content use Flutter-managed selection internals while retaining the ban on TextField/TextFormField and text mutation?

Recommended Answer:
- Continue prohibiting TextField and TextFormField for read-only values.
- Permit Flutter-managed read-only selection internals, including EditableText(readOnly: true) inside SelectableText.
- Require no app-owned TextEditingController solely for display.
- Test that values cannot be changed, expose no text-editing action, and remain selectable/copyable, including beyond line five, rather than asserting blanket EditableText absence.

Answer: "yes"

Decision: Clarify L7's widget ban without extending it to framework-managed read-only selection internals. Preserve non-mutation, accessible label/value association and selection/copy; expose no text-mutation accessibility action. Verify behaviour rather than requiring all EditableText descendants to be absent. Implement and verify in Spec R6.2, Technical Decision 5 and Testing Strategy 5–6.

Source: Individual finding discussion during the subsequent refinement on 2026-10-19; artifact updates were explicitly approved afterward. L7's historical answer remains unchanged; this record clarifies its implementation and verification meaning.

### L14

Status: current

Question: What minimum usable macOS width and height should the feature support?

Answer: "ok make it 1280 x 960", following discussion of the observed native minimum and the current display's available maximised area.

Decision: Adopt 1280 × 960 logical points as the minimum usable macOS content size: width 1280, height 960. This is not a fixed launch frame or a physical-pixel resolution. Retain maximised launch; this planning update does not change native runtime configuration. Resolve the minimum-size portion of L9 in the app profile and Spec R1.3/Testing Strategy 7; leave the supported resize range, separate native full-screen choice and any required feature-specific thresholds Pending.

Source: User's explicit dimension selection during continued Spec 0068 refinement on 2026-10-19. No upper resize bound or feature breakpoint was selected.

Answer History:
- L15 subsequently resolves the supported resize range; the minimum-size decision and historical answer above are unchanged.

### L15

Status: current

Question: Should resizing be allowed at the minimum 1280 × 960 logical-point content size and larger, with no fixed maximum?

Answer: "yes"

Decision: Support content width ≥1280 and height ≥960 logical points, with no fixed app-defined maximum; larger window sizes depend on the available display area. Retain maximised launch and the wide-only profile. This resolves L9's resize-range question in the app profile and Spec R1.3/Testing Strategy 7. Native full-screen and any required feature-specific thresholds are not selected by this answer. No runtime window configuration is changed by this documentation update.

Source: User's explicit approval during continued Spec 0068 refinement on 2026-10-19.

### L16

Status: current

Question: Use the same wide layout throughout the supported range, with wrapping/scrolling rather than additional breakpoints?

Answer: "yes"

Decision: For Spec 0068, retain the same wide layout across content width ≥1280 and height ≥960 logical points, with no fixed app-defined maximum. Use wrapping and scrolling against actual constraints; no additional feature-specific threshold or breakpoint is required. Preserve the draft and selection through resizing, with five-line value viewports recalculated as specified in L10. This resolves the feature's last layout question in Spec R1/Testing Strategy 7 and the app profile. It does not add compact/iOS support, choose native full-screen, change runtime window configuration or settle other features' thresholds.

Source: User's explicit approval during continued Spec 0068 refinement on 2026-10-19, after the minimum-size and resize-range decisions in L14–L15.
