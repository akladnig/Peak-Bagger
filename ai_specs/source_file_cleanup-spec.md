<goal>
Refactor the three highest-priority oversized Dart source files into smaller, cohesive files so implementation code is easier to navigate, review, test, and extend.

This cleanup matters because `./lib/providers/map_provider.dart`, `./lib/screens/map_screen.dart`, and `./lib/services/gpx_importer.dart` currently mix multiple responsibilities in ways that increase change risk and make future feature work slower. The outcome should preserve current app behavior while creating clearer boundaries between state/models, UI, parsing, orchestration, and persistence helpers.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, `flutter_map`, `latlong2`, `xml`, `crypto`, and existing widget/unit/robot tests.

Project constraints:
- Preserve current behavior, provider entry points, route behavior, stable widget keys/selectors, and user-visible flows.
- Do not add packages.
- Do not change ObjectBox schema or generated files.
- Keep the refactor feature-local and minimal; avoid introducing broad new architecture layers.
- Safe deduping is allowed only where the refactor exposes existing duplication clearly, especially the repeated GPX processing-result-to-model mapping.

Files to examine:
- @pubspec.yaml
- @lib/providers/map_provider.dart
- @lib/screens/map_screen.dart
- @lib/services/gpx_importer.dart
- @lib/services/gpx_track_statistics_calculator.dart
- @lib/services/gpx_track_filter.dart
- @lib/models/gpx_track.dart
- @test/gpx_track_test.dart
- @test/widget/tasmap_map_screen_test.dart
- @test/widget/gpx_tracks_summary_test.dart
- @test/widget/peak_refresh_settings_test.dart
- @test/services/gpx_importer_filter_test.dart
- @test/robot/gpx_tracks/gpx_tracks_journey_test.dart
- @test/robot/tasmap/tasmap_journey_test.dart

Output paths:
- Keep `./lib/providers/map_provider.dart` as the stable provider entry point.
- Create `./lib/providers/map_state.dart` for `MapState` and closely related enums/value types.
- Create `./lib/providers/map_grid_reference_parser.dart` for grid-reference and MGRS parsing logic now embedded in `MapNotifier`.
- Create `./lib/providers/map_track_operations.dart` for track import/reset/recalculation orchestration owned by the map domain.
- Create `./lib/providers/map_position_storage.dart` for position persistence and MGRS conversion helpers.
- Keep `./lib/screens/map_screen.dart` as the stable route/screen entry point.
- Create `./lib/screens/map_screen_layers.dart` for map layer composition helpers.
- Create `./lib/screens/map_screen_panels.dart` for goto, search, and info popup widgets.
- Create `./lib/screens/map_screen_interactions.dart` for keyboard/pointer interaction helpers.
- Keep `./lib/services/gpx_importer.dart` as the stable importer entry point.
- Create `./lib/services/gpx_importer_parser.dart` for GPX parsing and segment extraction.
- Create `./lib/services/gpx_importer_processor.dart` for filtering/statistics processing and any shared processing-result application helper.
- Create `./lib/services/gpx_importer_file_organizer.dart` for filename normalization, file placement, and import-log behavior.
</background>

<user_flows>
These are regression flows to preserve, not new behavior to invent.

Primary flow:
1. User opens the map screen.
2. User pans/zooms, hovers/selects tracks, toggles layers, or uses goto/search overlays.
3. The screen behaves exactly as it does today, with the same keys, focus behavior, and visible states.

Alternative flows:
- Track maintenance flow: user resets track data or recalculates track statistics from settings, and the same status/warning/error paths remain available.
- Grid reference flow: user enters a map name, MGRS reference, or coordinate variant, and the same parse/selection/zoom behavior remains intact.
- Import flow: watched folders are scanned, GPX files are organized, warnings are logged, and stored tracks are refreshed without a user-visible regression.

Error flows:
- Invalid grid reference: the same validation and visible error behavior must remain intact.
- GPX parse or processing failure: the same warning/error accounting and fallback behavior must remain intact.
- Track recovery issue: existing recovery-state behavior, disabled actions, and messages must remain intact.
</user_flows>

<discovery>
Before implementation, confirm:
- `mapProvider`, `MapScreen`, and `GpxImporter` are the only in-scope large files for this cleanup pass.
- Existing tests already cover the most sensitive behaviors for map interaction, GPX import/filtering, and track journeys.
- Stable widget keys and provider names used by widget/robot tests are known before any extraction starts.
- The duplicated GPX processing-result mapping in `./lib/providers/map_provider.dart` and `./lib/services/gpx_importer.dart` can be centralized without changing model semantics.
- No extracted helper needs to become a new public API beyond what existing imports and tests already require.
</discovery>

<requirements>
**Functional:**
1. Split `./lib/providers/map_provider.dart` into smaller files that separate state/value types, grid-reference parsing, track operations, and position persistence helpers.
2. Keep `mapProvider` and the externally consumed `MapNotifier` behavior stable after the split.
3. Split `./lib/screens/map_screen.dart` into a thin screen entry point plus extracted files for interactions, layer composition, and overlay/panel UI.
4. Keep the route-facing `MapScreen` type, current widget keys, and current user-visible behavior stable after the split.
5. Split `./lib/services/gpx_importer.dart` into orchestration plus parser, processor, and file-organization helpers.
6. Keep `GpxImporter` as the stable public entry point used by existing callers and tests.
7. Centralize the duplicated GPX processing-result application logic into one shared implementation owned by the importer/processing area.
8. Limit deduping to already-proven duplication exposed by this refactor; do not turn this task into a broader redesign.

**Error Handling:**
9. Preserve current invalid-grid-reference error behavior, including parse failures, range validation, and goto-field feedback.
10. Preserve current GPX import warning/error accounting, fallback behavior, import-log behavior, and rollback behavior.
11. Preserve current track recovery behavior, including disabled actions and state flags.
12. If extraction introduces a new helper seam, surface errors through the same existing public paths instead of swallowing them or creating silent fallbacks.

**Edge Cases:**
13. Preserve current handling for map-name-only input, mixed map-name-plus-coordinate input, raw numeric coordinate input, MGRS square input, and legacy MGRS-style input.
14. Preserve current behavior for empty tracks, missing GPX points, malformed GPX XML, duplicate logical matches, and filter fallback cases.
15. Preserve current behavior when map focus, hover state, selected track state, and popup state change concurrently during map interaction.
16. Avoid extracting tiny one-method files; each new file must represent a coherent responsibility, not arbitrary line-count slicing.

**Validation:**
17. Require stage-by-stage verification so each target file is split and stabilized before moving to the next priority file.
18. Maintain or improve existing automated coverage for logic/business rules, UI behavior, and critical map/track journeys.
19. If the refactor exposes a behavioral gap not covered today, add the smallest public-interface test needed to lock that behavior before or during the refactor.
20. Do not update tests merely to fit a new internal structure; only update tests when selectors or expectations need explicit preservation or when a genuine regression gap is found.
</requirements>

<boundaries>
Edge cases:
- Existing giant files may still remain moderately sized after the first extraction pass: prefer a few cohesive files over over-fragmentation.
- Existing private helpers may move between files: this is acceptable only if public behavior and stable entry points remain intact.
- Shared code between map provider and importer may be deduped once: do not continue into unrelated cleanup beyond the duplicated processing-result path.

Error scenarios:
- If an extraction breaks a stable selector or robot path, restore compatibility rather than rewriting the journey around a new structure.
- If a proposed extraction requires changing provider names, route names, ObjectBox schema, or generated code, stop and keep that change out of scope.
- If a helper cannot be extracted without widening API surface materially, prefer leaving it in the current entry file for this pass.

Limits:
- No new dependencies.
- No generated-file edits except required regeneration already proven necessary by a schema change, which is out of scope here.
- No behavioral redesign of map interaction, GPX import semantics, search behavior, or settings UX.
</boundaries>

<implementation>
Implementation style:
- Use small, feature-first extractions.
- Keep orchestration at the existing entry files where that preserves stable imports and discoverability.
- Prefer moving cohesive blocks with minimal signature churn over inventing new abstractions.

File-specific expectations:
- `./lib/providers/map_provider.dart`: reduce it to the Riverpod entry point, high-level notifier orchestration, and only the glue that still needs direct access to `ref` and top-level state transitions.
- `./lib/providers/map_state.dart`: own `Basemap`, `TasmapDisplayMode`, `MapState`, and pure value/state-copy concerns.
- `./lib/providers/map_grid_reference_parser.dart`: own parsing and validation for the current grid-reference formats now handled in `parseGridReference()`.
- `./lib/providers/map_track_operations.dart`: own track import/reset/recalculation workflows, correlated-peak refresh helpers, and track-operation status/warning assembly.
- `./lib/providers/map_position_storage.dart`: own map position persistence, MGRS formatting/conversion, and nearby-map/peak lookup helpers that do not need to stay inline with notifier orchestration.
- `./lib/screens/map_screen.dart`: reduce to the route widget, controller ownership, and composition of extracted map-screen pieces.
- `./lib/screens/map_screen_interactions.dart`: own keyboard handling, pointer/hover handling, scroll helpers, and track-hover candidate building.
- `./lib/screens/map_screen_layers.dart`: own tile/layer/polygon/marker/polyline construction.
- `./lib/screens/map_screen_panels.dart`: own peak search panel, goto panel, info popup, and compact display widgets.
- `./lib/services/gpx_importer.dart`: reduce to importer orchestration and stable public methods.
- `./lib/services/gpx_importer_parser.dart`: own XML parsing, first-point extraction, segment extraction, track-name extraction, and related GPX parsing helpers.
- `./lib/services/gpx_importer_processor.dart`: own `processTrack()`, processing-result types, and the single shared mapping from processing result to `GpxTrack` fields.
- `./lib/services/gpx_importer_file_organizer.dart`: own filename normalization, canonical naming, destination resolution, route/tasmania sorting, replacement moves, and import-log helpers.

What to avoid:
- Avoid barrel files or broad new package-style folder structures for this pass; colocate new files beside the current feature area.
- Avoid renaming stable public types, providers, routes, and widget keys/selectors unless a conflict makes it unavoidable.
- Avoid moving logic into widgets if it is currently domain/service logic.
- Avoid leaving duplicate GPX processing-result application code in both the provider and importer after the split.
</implementation>

<stages>
Phase 1: Prepare the refactor boundaries.
- Confirm stable imports, provider names, route entry points, and widget keys that must not change.
- Add the smallest missing regression tests first if any critical behavior is currently unprotected.

Phase 2: Split `./lib/providers/map_provider.dart`.
- Extract state/value types, grid-reference parsing, track operations, and position/persistence helpers into the planned files.
- Keep `mapProvider` and observable notifier behavior stable.
- Verify targeted map/provider tests before continuing.

Phase 3: Split `./lib/screens/map_screen.dart`.
- Extract interactions, layers, and panels into the planned files.
- Keep `MapScreen`, stable keys, and map interaction behavior unchanged.
- Verify widget and journey regression coverage before continuing.

Phase 4: Split `./lib/services/gpx_importer.dart`.
- Extract parser, processor, and file-organization helpers into the planned files.
- Centralize the duplicated processing-result application logic.
- Verify importer/filter/service tests before continuing.

Phase 5: Final sweep.
- Remove dead imports and leftover duplication.
- Confirm no out-of-scope files were broadened into redesign work.
- Run full analysis and tests.
</stages>

<illustrations>
Desired:
- `./lib/providers/map_provider.dart` still reads as the top-level map domain entry point, while detailed parsing and track workflows live in named adjacent files.
- `./lib/screens/map_screen.dart` shows screen composition clearly, with panel and layer details moved out.
- `./lib/services/gpx_importer.dart` reads as orchestration, not as a 900-line mix of XML parsing, path normalization, and processing rules.

Avoid:
- Splitting one large file into many tiny files that each contain only one private method.
- Renaming or moving stable public entry points so widely that downstream imports or tests need mechanical churn.
- Combining the cleanup with unrelated architecture rewrites, state-model redesign, or UX changes.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: keep or add public-interface tests around grid-reference parsing, track import/recalculation outcomes, GPX processing fallback behavior, and duplicated-processing-result mapping after centralization.
- UI behavior: keep or add widget regression coverage for `MapScreen` interaction surfaces and settings-driven track operation states that depend on the extracted map/provider logic.
- Critical user journeys: keep robot-driven regression coverage for existing map/track journeys, especially GPX track journeys and tasmap journeys that exercise map screen behavior touched by the split.

TDD expectations:
- Treat pure mechanical file moves as refactor work that can proceed under existing green coverage.
- If the split exposes an untested public behavior or the safe dedupe creates a new seam, lock it with one failing public-interface test slice before changing that behavior-sensitive area.
- Use vertical slices: add one focused failing test, make the smallest extraction or dedupe change to pass it, then refactor further only after green.
- Prefer fakes and existing test harness overrides over new mocks; mock only true external boundaries.

Robot/widget/unit split:
- Robot tests: existing critical happy-path journeys in `./test/robot/gpx_tracks/` and `./test/robot/tasmap/` remain green; add selectors only if an extracted widget otherwise makes the journey flaky.
- Widget tests: preserve or extend `MapScreen` and settings/widget regression tests that cover error states, cancel/close states, hover/selection state, and visible status messaging.
- Unit/service tests: preserve or extend importer and parsing tests for GPX parsing, filtering fallback, replacement handling, and centralized processing-result mapping.

Selectors and seams:
- Preserve existing app-owned `Key` selectors used by widget and robot tests.
- Keep deterministic test seams via existing Riverpod overrides, fake repositories/notifiers, and importer constructor injection paths.
- Do not require new async workarounds when an extracted seam can stay deterministic under the current harness.

Verification commands:
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- `./lib/providers/map_provider.dart`, `./lib/screens/map_screen.dart`, and `./lib/services/gpx_importer.dart` are each reduced to clear entry-point/orchestration roles with cohesive logic moved into the planned adjacent files.
- Public behavior, provider entry points, stable route/screen types, and stable widget keys/selectors are preserved.
- The duplicated GPX processing-result application logic exists in one shared implementation rather than two drifting copies.
- No out-of-scope architectural redesign, dependency additions, schema changes, or generated-file churn were introduced.
- `flutter analyze` and `flutter test` pass.
</done_when>
