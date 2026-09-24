---
type: Work Item
title: ObjectBox Entity Foundation
parent: ../spec.md
---

## What to build

Add independent singular `NaturalFeature` and `Contact` ObjectBox entities plus their ObjectBox-facing storage and repository seams. Both entities must use ObjectBox-generated `id` values and must not introduce relations to existing app entities.

`NaturalFeature` must persist exactly `id`, `name`, `altName`, `tag`, `country`, `county`, `region`, `latitude`, `longitude`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, numeric `osmId`, `osmType`, and `sourceOfTruth`. Its future admin label is `Natural Features`. `Contact` must persist exactly `id`, `firstName`, `surname`, and `nickname`; its future admin label is `Contacts`.

Generate and commit the ObjectBox bindings and model metadata, preserve compatibility for existing persisted data, wire production and test provider/repository construction, and extend the ObjectBox schema guard for both entities and every required persisted field.

## Required context

- `lib/models/peak.dart` demonstrates the project ObjectBox entity convention.
- `lib/services/objectbox_schema_guard.dart` and `test/services/objectbox_schema_guard_test.dart` define the schema-signature contract.
- `lib/main.dart` and existing repositories, including `lib/services/waypoints_repository.dart`, show production and in-memory repository/provider wiring.
- `pubspec.yaml` contains the existing ObjectBox and generation dependencies; do not add a dependency unless implementation proves one is required.

## Acceptance criteria

- [x] `NaturalFeature` is a singular Dart/ObjectBox entity with an ObjectBox-generated `id` and exactly the persisted fields required by the Spec; no synthetic remapped OSM key or ObjectBox uniqueness constraint replaces the composite OSM feature identity.
- [x] `Contact` is an independent Dart/ObjectBox entity with an ObjectBox-generated `id` and exactly `firstName`, `surname`, and `nickname`; it has no relations to Peaks, Tracks, Routes, or other current entities.
- [x] Production storage/repository seams and deterministic in-memory or temporary-store test seams exist for both entities without altering existing entity behavior.
- [x] ObjectBox generation updates the generated bindings and model metadata, and existing persisted-data schema compatibility is preserved.
- [x] The ObjectBox schema guard and its tests assert that both entities and every required field are present.
- [x] Repository tests verify generated IDs for both entities and that Contact records can exist without relations.
- [x] Run ObjectBox generation, the ObjectBox schema guard, targeted entity/repository tests, `flutter analyze`, and the full `flutter test` suite.

## Covers

- User Stories: 2-3
- Requirements: 1, 3
- Technical Decisions: 1, 6
- Testing Strategy: 3, 6
- Interview Ledger: L1, L9, L11

## Blocked by

None - ready to start
