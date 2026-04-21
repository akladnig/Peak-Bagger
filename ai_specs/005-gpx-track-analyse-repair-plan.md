## Overview

GPX segment-gap repair; persist repaired XML; reuse existing import/recalc pipeline.
Approach: minimal vertical slice first; then widen edge cases + recalc + admin surface.

**Spec**: `ai_specs/005-gpx-track-analyse-repair-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/models`, `lib/services`, `lib/providers`, `test/`
- **State management**: Riverpod
- **Reference implementations**: `lib/services/gpx_importer.dart`, `lib/services/gpx_track_statistics_calculator.dart`, `lib/providers/map_provider.dart`
- **Assumptions/Gaps**: no open spec gaps; no robot lane needed; service/integration focused

## Plan

### Phase 1: Repair Slice

- **Goal**: raw GPX -> repair result -> persisted repaired field -> import path proof
- [ ] `lib/models/gpx_track.dart` - add `gpxFileRepaired`; include `toMap`/`fromMap`
- [ ] `lib/services/gpx_track_repair_service.dart` - create repair service + `RepairResult`; constructor thresholds
- [ ] `lib/services/gpx_importer.dart` - run repair before `processTrack(...)`; persist `gpxFileRepaired`; feed repaired-or-original XML into processing path
- [ ] `test/gpx_track_test.dart` - add service-level and import integration coverage for repaired import path
- [ ] TDD: single-segment GPX returns no repair and empty repaired field
- [ ] TDD: gap > threshold + distance > threshold inserts interpolated segment and persists repaired XML
- [ ] TDD: import path uses repaired-or-original XML as input to existing processing pipeline
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Recalc And Correlation

- **Goal**: recalc path parity; peak correlation on repaired input; admin visibility
- [ ] `lib/providers/map_provider.dart` - recalc uses `gpxFileRepaired` when present; otherwise repair raw GPX first; keep peak correlation on same repaired-or-original input
- [ ] `lib/services/objectbox_admin_repository.dart` - expose `gpxFileRepaired` in GPX admin rows
- [ ] `test/gpx_track_test.dart` - add recalc-path coverage for repaired-vs-raw selection and peak correlation input
- [ ] TDD: recalc prefers persisted repaired XML when available
- [ ] TDD: recalc repairs raw GPX first when repaired field empty, then processes/correlates from same XML
- [ ] TDD: already-repaired GPX skips re-repair and preserves repaired source
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Edge Cases

- **Goal**: harden repair logic; warnings; malformed inputs
- [ ] `lib/services/gpx_track_repair_service.dart` - handle no timestamps, invalid XML, genuine pauses, multiple gaps, already-repaired detection
- [ ] `lib/services/gpx_importer.dart` - log/surface repair warnings consistently with current import warning path
- [ ] `test/gpx_track_test.dart` - expand edge/error coverage for no timestamps, invalid XML, large-gap-small-distance, multiple gaps
- [ ] TDD: no timestamps skips repair and returns warning
- [ ] TDD: invalid XML fails gracefully with no repair result corruption
- [ ] TDD: large time gap but small distance does not insert interpolated segment
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: XML rewrite fidelity around namespaces/order; repaired-vs-filtered pipeline interaction; existing GPX import warnings may need wording tweaks
- **Out of scope**: UI changes; robot/widget journeys; changing GPX filter behavior beyond repaired-input integration
