---
type: Spec
title: ObjectBox Admin Entity Selector Resilience
---

## Problem

The ObjectBox Admin `Entity` selector can receive duplicate `ObjectBoxAdminEntityDescriptor` values. Flutter requires exactly one matching `DropdownMenuItem` for the selected value, so the screen throws while building and its body overflows as a consequence. The ObjectBox Admin screen becomes unusable despite duplicate schema descriptors representing the same stored entity. [L1]

## Proposed Outcome

ObjectBox Admin treats duplicate descriptors as one entity in its `Entity` selector. The current entity remains selected by canonical entity name after a refresh, and the screen continues to show the existing schema/data controls and selected entity rows without a dropdown assertion or resulting layout overflow. [L1]

## User Stories

1. As an ObjectBox Admin user, I can open the admin screen even when the schema source supplies duplicate descriptors for an entity.
2. As an ObjectBox Admin user, I retain my selected entity when the admin state refreshes with newly constructed or duplicate descriptors for that same entity.

## Requirements

1. The ObjectBox Admin `Entity` selector must render exactly one dropdown option for each canonical descriptor `name`. The option continues to use that descriptor's existing `displayName`. [L1]
2. When entity descriptors are loaded or refreshed, select the descriptor whose `name` matches the current selection whenever it remains available. The state passed to the dropdown must use that canonical descriptor instance. [L1]
3. If the current entity name is absent after normalization, retain the existing fallback behavior of selecting the first available entity; if no entities are available, show no selection and do not build an invalid dropdown value. [L1]
4. Duplicate descriptors must not change the currently selected schema/data mode, search query, sort order, selected-row lifecycle, row loading behavior, or ObjectBox Admin actions. [L1]
5. The screen must not throw Flutter's `DropdownButton` exactly-one-item assertion or cause its cascading `RenderFlex` overflow when duplicate descriptors are supplied. [L1]

## Technical Decisions

1. Treat `ObjectBoxAdminEntityDescriptor.name` as the canonical entity identity for selector normalization and selection restoration. `displayName` remains presentation-only. [L1]
2. Normalize entity descriptors at the existing `ObjectBoxAdminNotifier` state boundary, before `ObjectBoxAdminState` is exposed to `ObjectBoxAdminControls`. This preserves the current repository's name-based de-duplication while making the UI safe for any repository implementation or refresh result. [L1]
3. Reuse the existing Riverpod `objectboxAdminProvider`, `ObjectBoxAdminRepository.getEntities`, and `TestObjectBoxAdminRepository` injection seam. This UI/state repair requires no ObjectBox schema change, migration, network dependency, background job, API key, or new persistence layer.

## Testing Strategy

1. Use behavior-first TDD for the notifier normalization and selection-restoration behavior. Add focused coverage that supplies duplicate descriptors through the existing repository seam and proves the canonical name list contains one entry per entity and selection falls back only when its name is absent. [L1]
2. Extend existing ObjectBox Admin widget coverage using `TestObjectBoxAdminRepository` and provider overrides. Pump the admin screen with duplicate descriptor values, assert it builds without an exception, opens an Entity menu with one option per name, and continues to load the canonical entity's rows. [L1]
3. Add a refresh scenario that selects an entity, supplies fresh duplicate descriptors with the same name, and verifies the Entity selector retains the selection and uses a value present exactly once in its items. Do not use a live ObjectBox native library, network service, API key, or robot journey for this focused state/UI regression.
4. Preserve existing stable `objectbox-admin-entity-dropdown` selector usage. Add no selector unless a new focused assertion cannot otherwise address the widget state.
5. Run `flutter analyze`, the focused ObjectBox Admin provider/widget tests, and `flutter test` before completion.

## Out of Scope

1. Renaming ObjectBox entities, changing `displayName` values, or altering ObjectBox model metadata.
2. Changing ObjectBox Admin navigation, schema/data modes, search, sorting, row selection, editing, export, deletion, or map handoff behavior.
3. Adding a general duplicate-data repair flow, persistent de-duplication, ObjectBox migrations, or schema regeneration.
4. Layout redesigns unrelated to the failed dropdown build.
