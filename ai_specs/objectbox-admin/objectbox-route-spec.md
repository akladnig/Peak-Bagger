<goal>
Add a new ObjectBox entity named `Route` and make it visible in the existing ObjectBox Admin viewer.
The entity must store route metadata plus a transient `List<LatLng>` backed by a persisted JSON string so route geometry can be saved and inspected without custom ObjectBox converters.
This supports app code that persists routes and maintainers who need to inspect local data.
</goal>

<background>
Current ObjectBox entities live in `./lib/models/gpx_track.dart`, `./lib/models/peak.dart`, `./lib/models/peak_list.dart`, `./lib/models/peaks_bagged.dart`, and `./lib/models/tasmap50k.dart`.
Generated ObjectBox metadata is checked in at `./lib/objectbox.g.dart` and `./lib/objectbox-model.json`.
ObjectBox Admin discovery and row loading are implemented in `./lib/services/objectbox_admin_repository.dart`.
Schema drift protection is implemented in `./lib/services/objectbox_schema_guard.dart`.
Relevant tests live in `./test/services/objectbox_admin_repository_test.dart`, `./test/services/objectbox_schema_guard_test.dart`, `./test/harness/test_objectbox_admin_repository.dart`, and the ObjectBox Admin widget tests.
The entity class name is `Route`, so any file that imports the model alongside Flutter routing types must use explicit imports or aliases to avoid symbol collisions.
</background>

<discovery>
Before coding, confirm the exact persisted field names that ObjectBox will generate for the new entity and verify the generator output includes `Route`.
Update any existing tests that assert exact entity ordering so they use membership checks, or update the asserted order to explicitly include `Route`.
</discovery>

<requirements>
**Functional:**
1. Create `./lib/models/route.dart` with `@Entity() class Route`.
2. Use `@Id()` with `int id = 0;` so ObjectBox assigns the primary key automatically.
3. Persist these values exactly: `name`, `gpxRouteJson`, `displayRoutePointsByZoom`, `colour` (`int`), `distance2d`, `distance3d`, `ascent`, `descent`, `startElevation`, `endElevation`, `lowestElevation`, and `highestElevation`.
4. Initialize the persisted JSON and display-cache strings with valid empty defaults, such as `gpxRouteJson = '[]'` and `displayRoutePointsByZoom = '{}'`, keep numeric fields initialized to `0`, and set `colour` to `0` by default.
5. Expose route geometry as a transient `List<LatLng> gpxRoute = [];` backed by the persisted JSON string property `gpxRouteJson`.
6. `gpxRouteJson` must encode route points as `[[latitude, longitude], ...]` and decode the same shape back into `gpxRoute`.
7. Add the new entity to `./lib/objectbox-model.json` and `./lib/objectbox.g.dart` by regenerating ObjectBox output, not by hand-editing generated files.
8. Make `Route` discoverable in ObjectBox Admin by updating `./lib/services/objectbox_admin_repository.dart` so `getEntities()` includes it, `loadRows()` can load it, and the row mapper exposes its persisted fields.
   - Route browsing should search by `name` and sort by `id`, matching the existing admin repository convention of primary-name search plus primary-key sort.
9. Update `./lib/services/objectbox_schema_guard.dart` so the stored schema signature includes `Route.name`, `Route.gpxRouteJson`, `Route.displayRoutePointsByZoom`, and `Route.colour` markers.
10. Update `./test/harness/test_objectbox_admin_repository.dart` so widget tests can seed a `Route` entity without extra setup.

**Error Handling:**
11. Decode invalid, empty, or non-list `gpxRouteJson` values as an empty transient route list.
12. Skip malformed coordinate pairs inside otherwise valid JSON instead of failing the whole decode.
13. Keep ObjectBox Admin browsing read-only; do not add create, edit, delete, or import actions for `Route`.

**Edge Cases:**
14. Preserve coordinate order as latitude then longitude.
15. Support an empty route, a single-point route, and a long route JSON payload.
16. Keep `displayRoutePointsByZoom` as a raw persisted string with a valid empty default and do not model it as a relation or nested object.
17. Do not introduce a type conflict with Flutter’s `Route`; use aliases or narrow imports where needed.

**Validation:**
18. Add unit tests in `./test/models/route_test.dart` that prove `gpxRouteJson` round-trips valid points and falls back to an empty list for malformed input.
19. Extend `./test/services/objectbox_admin_repository_test.dart` to verify `Route` appears in the discovered entity list, has `primaryKeyField == 'id'`, `primaryNameField == 'name'`, and exposes the expected persisted fields.
20. Extend `./test/services/objectbox_schema_guard_test.dart` so the schema signature includes `Route` markers.
21. Update `./test/widget/objectbox_admin_shell_test.dart`, `./test/widget/objectbox_admin_browser_test.dart`, and `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` to prove the `Route` entity can be selected and browsed in the admin screen.
22. Verify the regenerated ObjectBox artifacts compile cleanly and the affected test subset passes.
</requirements>

<boundaries>
Edge cases:
- Do not persist the transient `List<LatLng>` directly.
- Do not use `@Convert` for the route geometry.
- Do not rely on exact entity ordering in tests if generator ordering changes.
- Do not lose admin visibility for existing entities while adding `Route`.

Error scenarios:
- Corrupt route JSON in storage should not crash app startup or admin browsing.
- A missing or stale generated model should be fixed by regeneration, not by hand-authored metadata.

Limits:
- Keep the feature limited to the ObjectBox entity, generated metadata, schema guard, and admin inspection path.
- Do not add route editing UI or route import/export behavior unless a separate spec requires it.
</boundaries>

<implementation>
- Add `./lib/models/route.dart` and model the JSON codec with the same defensive style used in `./lib/models/gpx_track.dart`.
- Regenerate `./lib/objectbox-model.json` and `./lib/objectbox.g.dart` after adding the entity.
- Update `./lib/services/objectbox_admin_repository.dart` with a `Route` row mapper and a `loadRows()` branch for `Route`.
- Update `./lib/services/objectbox_schema_guard.dart` to include `Route` in `_currentSchemaSignature()`.
- Update `./test/harness/test_objectbox_admin_repository.dart`, `./test/services/objectbox_admin_repository_test.dart`, and `./test/services/objectbox_schema_guard_test.dart`.
- Keep the implementation minimal and deterministic; prefer pure codec helpers over any database-dependent test setup.
</implementation>

<stages>
Phase 1: Model and codec
- Add the entity model and JSON-backed route geometry property.
- Complete when the model compiles and unit tests can exercise the codec in isolation.

Phase 2: Generated metadata
- Regenerate ObjectBox outputs and confirm `Route` appears in the model.
- Complete when the generated files compile and the schema guard can see `Route`.

Phase 3: Admin visibility
- Add `Route` support to the ObjectBox Admin repository and test harness.
- Complete when the admin repository can discover and load `Route` rows.

Phase 4: Verification
- Update the schema guard test, repository test, and admin widget coverage.
- Complete when the affected test subset passes with `Route` included.
</stages>

<validation>
TDD expectations:
- Start with a failing unit test for `Route` JSON round-trip behavior.
- Add a failing repository or schema test for `Route` discovery and field exposure.
- Implement the minimum code to pass each slice before moving on.
- Prefer fakes or pure helpers over mocking ObjectBox internals.

Required automated coverage:
- Unit tests for encoding, decoding, malformed-input fallback, and coordinate ordering.
- Repository tests for `Route` entity discovery, primary key/name mapping, and persisted field exposure.
- Schema-guard tests for the new `Route` markers.
- Widget tests for the existing ObjectBox Admin screen showing `Route` in the entity dropdown and browsable rows.

Deterministic seams:
- Keep the JSON codec pure and callable without a `Store`.
- Seed the admin repository with a fake `Route` row through `TestObjectBoxAdminRepository`.
- Use stable `Key` selectors if any admin widget assertions need new coverage.

Success criteria:
- `Route` is persisted in ObjectBox with the requested fields.
- Route geometry survives round-trip through the JSON-backed transient list.
- ObjectBox Admin can discover and browse `Route`.
- Schema drift detection includes `Route`.
- Existing entity behavior remains unchanged.
</validation>

<done_when>
- `./lib/models/route.dart` exists and compiles.
- The generated ObjectBox metadata includes `Route`.
- ObjectBox Admin lists `Route` and can browse its rows.
- The schema guard includes `Route` in its signature.
- The updated tests pass.
</done_when>
