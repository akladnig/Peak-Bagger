<goal>
Increase Tasmap polygon import capacity from 8 to 12 vertices so newer source data can be imported without truncation.
This matters because the bundled Tasmap dataset and any future re-imports need to preserve higher-resolution outlines for map bounds, labels, and polygon display.
</goal>

<background>
The import pipeline is in `./lib/services/csv_importer.dart`.
Polygon storage and helpers are in `./lib/models/tasmap50k.dart`.
Schema exposure for admin views is in `./lib/services/objectbox_admin_repository.dart`, with generated code in `./lib/objectbox.g.dart`.
The source fixture is `./assets/tasmap50k.csv`.
Current tests that lock the behavior are `./test/csv_importer_test.dart`, `./test/tasmap50k_test.dart`, and `./test/services/objectbox_admin_repository_test.dart`.
Files to examine: `./lib/services/csv_importer.dart`, `./lib/models/tasmap50k.dart`, `./lib/services/objectbox_admin_repository.dart`, `./assets/tasmap50k.csv`, `./test/csv_importer_test.dart`, `./test/tasmap50k_test.dart`, `./test/services/objectbox_admin_repository_test.dart`.
</background>

<user_flows>
Primary flow:
1. User runs the existing Tasmap re-import path.
2. The CSV importer reads polygon columns in order.
3. A row with 12 populated vertices is imported successfully.
4. The resulting map record is available to admin views and map rendering code.

Alternative flows:
- Rows with 4, 6, or 8 vertices continue to import unchanged.
- Rows with blank trailing point columns still import with only the populated vertices.
- Existing data with shorter polygons should not be rewritten or padded.

Error flows:
- A row with a gap in its point sequence is still rejected and logged.
- A row with more than 12 populated vertices is rejected.
- A row with malformed point text is skipped without stopping the batch import.
</user_flows>

<requirements>
**Functional:**
1. Extend `Tasmap50k` with stored fields for `p9` through `p12`.
2. Update `Tasmap50k.polygonPoints` to return all populated points in order up to 12.
3. Update `Tasmap50k.hasValidPolygonPointCount` to treat 12-point polygons as valid, while preserving the existing 4/6/8 cases.
4. Update `CsvImporter.parseRow` to read `p1` through `p12` from the CSV header/row data.
5. Keep the sequential-point rule intact: once a blank point is seen, later populated point columns in the same row still fail validation.
6. Update the CSV source/header in `./assets/tasmap50k.csv` so the schema explicitly carries `p9` through `p12`.
7. Update the ObjectBox admin row mapping so Tasmap entity metadata includes `p9` through `p12`.
8. Regenerate generated schema code as needed; do not hand-edit `./lib/objectbox.g.dart`.

**Error Handling:**
9. Preserve existing row-level warnings and skipped-row behavior for malformed data.
10. Keep parse failures localized to the row; one bad polygon row must not abort the whole import.
11. If a row has fewer than 12 populated vertices, import the available sequential points without padding or reordering.

**Edge Cases:**
12. A 12-point polygon must round-trip with identical point order from CSV to entity.
13. Existing fixtures that only populate `p1` through `p4` must still report the same polygon length and validity.
14. Empty `p9` through `p12` fields must remain harmless for older rows.

**Validation:**
15. Use TDD-style slices for the parser first: red on 12-point support, green on expanded field parsing, then refactor.
16. Add deterministic tests that cover 12-point parsing, sequential-gap rejection, and the preserved 4/6/8 import cases.
17. Add schema-level coverage that verifies ObjectBox admin metadata exposes `p9` through `p12`.
18. Keep existing UI or journey tests green; no new widget or robot coverage is required unless the importer screen text changes.
19. Baseline coverage must include logic tests for importer/model behavior and regression coverage for the bundled CSV import path.
</requirements>

<boundaries>
- Do not change the map screen rendering logic or polygon label placement as part of this work.
- Do not broaden validation to arbitrary polygon sizes; only add support for 12-point polygons on top of the current accepted counts.
- Do not alter non-polygon Tasmap fields or import warnings.
- Do not introduce a new import format or second CSV schema.
</boundaries>

<implementation>
- Update `./lib/models/tasmap50k.dart` first so the entity can represent 12 vertices.
- Update `./lib/services/csv_importer.dart` to parse and validate the expanded point range.
- Update `./lib/services/objectbox_admin_repository.dart` and regenerate ObjectBox code to keep schema metadata aligned.
- Update `./assets/tasmap50k.csv` so the header and sample data match the new polygon width.
- Add or update tests in `./test/csv_importer_test.dart`, `./test/tasmap50k_test.dart`, and `./test/services/objectbox_admin_repository_test.dart`.
- Avoid partial fixes that only expand the CSV importer without updating the entity schema, because that would lose data after import.
</implementation>

<stages>
Phase 1: Model and parser
1. Add the new Tasmap fields and expand CSV parsing.
2. Verify 12-point rows parse while existing shorter rows still pass.

Phase 2: Schema and source data
1. Update admin schema exposure and regenerate ObjectBox code.
2. Update the bundled CSV header and fixture rows.

Phase 3: Regression proof
1. Expand tests for 12-point support and rejected malformed rows.
2. Run the Tasmap import test suite and confirm existing behaviors still pass.
</stages>

<validation>
- Follow vertical-slice TDD for the parser/model changes: one failing test at a time, then the minimum code to pass.
- Required automated coverage:
  - `unit` or logic: `CsvImporter.parseRow`, `normalizePointValue`, `Tasmap50k.polygonPoints`, and `Tasmap50k.hasValidPolygonPointCount`.
  - `service/schema`: ObjectBox admin metadata exposes the new Tasmap fields.
  - `regression`: bundled `./assets/tasmap50k.csv` still imports successfully with the expanded schema.
- Prefer deterministic tests that instantiate `Tasmap50k` directly or call `CsvImporter.parseRow` instead of relying on UI harnesses.
- Add at least one test for each of these behaviors:
  - 12-point polygon accepted and preserved in order
  - blank trailing points still allow shorter polygons
  - gap in the point sequence still fails
  - schema metadata includes `p9` through `p12`
</validation>

<done_when>
The Tasmap import path accepts 12-vertex polygons end to end, the entity and admin schema can store and expose the extra vertices, the bundled CSV fixture matches the new width, and the updated tests prove the old shorter polygons still behave as before.
</done_when>
