---
type: Spec
title: ObjectBox Admin Peak Metadata Editing
---

## Problem

ObjectBox Admin exposes a dedicated `Peak` edit form, but nine already-persisted metadata fields can only be inspected or modified through indirect import and maintenance paths. An admin cannot fully correct a Peak record in one place, and hidden values are retained without an explicit way to review, replace, or clear them. [L1]

## Proposed Outcome

The existing ObjectBox Admin Peak form exposes the nine missing persisted metadata fields in both Add Peak and Edit Peak modes. The form preserves the current save, cancellation, inline-validation, and failure-feedback behavior while applying a clear contract for optional numeric and text values. No ObjectBox schema or provenance behavior changes. [L1] [L2] [L3] [L4]

## User Stories

1. As an ObjectBox Admin user, I can enter or correct all requested shared Peak metadata when editing an existing Peak. [L1] [L3]
2. As an ObjectBox Admin user, I can create a complete Peak record, including the requested metadata, without a follow-up edit. [L4]
3. As an ObjectBox Admin user, I receive field-specific validation feedback for invalid PeakBagger PID, prominence, or rating values and can correct the form without losing the entered values. [L2]
4. As an ObjectBox Admin user, I can deliberately clear optional numeric or text metadata rather than silently retaining an inaccessible stored value. [L2]

## Requirements

1. Extend only the existing ObjectBox Admin `_PeakEditForm` and its `PeakAdminFormState`/`PeakAdminEditor` persistence path. Add fields for exactly `peakbaggerPid`, `prominence`, `country`, `county`, `range`, `rating`, `difficulty`, `viaFerrata`, and `notes`. Do not add a separate maintenance surface. [L1]
2. Show the new controls in this exact order: `PeakBagger PID` immediately after `osmId`; `Prominence`, `Country`, `County`, `Range`, and `Rating` immediately after `Elevation`; and `Difficulty`, `Via ferrata`, and `Notes` immediately after `Peak duration`. Keep the existing coordinates, verification, and provenance controls after this sequence in their current order. [L3]
3. The existing Peak edit flow must prefill every new control from the selected `Peak`. The Add Peak flow must show the same controls with empty optional values. [L4]
4. `PeakBagger PID` is an optional positive integer. A blank input persists `null`; a zero, negative, or non-integer value shows an inline field error and blocks Save. [L2]
5. `Prominence` is an optional decimal. A blank input persists `null`; a non-numeric value shows an inline field error and blocks Save. Do not impose a new range restriction. [L2]
6. `Rating` is an optional decimal in the inclusive range `0.0` through `5.0`. A blank input persists `null`; an out-of-range or non-numeric value shows an inline field error and blocks Save. Persist a valid value rounded to one decimal place. [L2]
7. `Country`, `County`, `Range`, `Difficulty`, and `Via ferrata` are optional single-line text inputs. An empty input persists an empty string. `Notes` is an optional multiline text input and an empty input persists an empty string. [L2] [L3]
8. Invalid new-field input must use the form's existing inline validation behavior: do not submit a persistence operation, retain all entered values, and leave the form editable so the admin can correct it. [L2]
9. On a successful Add Peak or Edit Peak save, persist all nine new values through the existing Peak repository path and retain the current ObjectBox Admin success feedback and app-wide Peak refresh behavior. On a persistence failure, retain the existing error feedback and entered form values. [L4]
10. Preserve the existing edit entry point, read-only details view, close/cancel behavior, coordinate calculations, `id` and grid-zone read-only treatment, verification control, and `sourceOfTruth` behavior. In particular, this change must not alter the current provenance overwrite behavior. [L1]

## Technical Decisions

1. Use the existing persisted `Peak` fields as the sole source of truth. The fields already exist in the ObjectBox model and `peakFromAdminRow`; this work must thread them through `PeakAdminFormState`, normalization, validation, and `validateAndBuild` rather than adding schema fields or duplicate storage. [L1] [L4]
2. Keep controllers and form state within `_PeakAdminDetailsPaneState`, following the existing edit form lifecycle. Add and dispose controllers for the new inputs alongside the current controllers. [L3] [L4]
3. Reuse the existing ObjectBox Admin repository, mutable in-memory peak repository, provider overrides, and refresh seams. This feature requires no network call, API key, background job, or new persistence dependency.
4. Keep validation in `PeakAdminEditor` so both Add Peak and Edit Peak share parsing, normalization, inline errors, and persistence output. Reuse the existing app-owned rating contract of `0.0` to `5.0` rounded to one decimal place; do not introduce a second rating representation. [L2] [L4]
5. Add stable `objectbox-admin-peak-*` keys for the new controls and any new error assertions, matching the current robot/widget selector convention. [L3]
6. `PeakBagger PID` is the canonical user-facing label for `peakbaggerPid`; `GLOSSARY.md` defines the term and distinguishes it from OSM ID. [L3]

## Testing Strategy

1. Use behavior-first TDD for the editor changes. Extend `test/services/peak_admin_editor_test.dart` to cover normalization, valid persistence output, blank clearing, and rejected values for PeakBagger PID, prominence, and rating. Verify rating rounding and that all text fields, including multiline notes, persist correctly. [L1] [L2]
2. Extend the existing ObjectBox Admin widget or robot seam using `TestObjectBoxAdminRepository`, `_MutablePeakRepository`, and provider overrides. Do not require a live ObjectBox native library, network service, or API key.
3. Extend `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` and its robot helpers with stable selectors to prove a prefilled Peak can edit and save all nine values, then assert the values in both the fake repository and refreshed map Peak state. Include a separate Add Peak journey that saves the values and a clearing scenario that persists nullable numeric fields as `null` and text fields as empty strings. [L2] [L4]
4. Add focused widget coverage only where needed for the exact label/order, `Notes` multiline configuration, and inline error presentation. Preserve the existing cancellation, saving, and persistence-failure tests rather than duplicating unrelated flow coverage. [L2] [L3]
5. Run focused editor, ObjectBox Admin widget/robot, and affected Peak repository tests, followed by `flutter analyze` and the full `flutter test` suite before completion.

## Out of Scope

1. Changing the existing `sourceOfTruth` overwrite behavior or adding a provenance selector. [L1]
2. Editing `id` or `gridZoneDesignator`, changing coordinate/MGRS rules, or changing verification behavior. [L1]
3. Adding or migrating ObjectBox schema fields, regenerating ObjectBox artifacts, or changing CSV import/export contracts.
4. Changing regular Peak List popup metadata editing, map metadata filters, or any non-admin Peak editing surface.
5. Introducing a difficulty dropdown, a new difficulty scale, automatic metadata lookup, network integration, or background work.
