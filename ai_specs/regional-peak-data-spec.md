<goal>
Load bundled peak data for every seedable region listed in `./assets/region_manifest.json`.
Stop rewriting every stored peak to Tasmania, and make peak refresh accept an explicit region plus query bounds so non-Tasmanian data stays region-correct.
</goal>

<background>
The app currently bootstraps peaks from a Tasmania-default Overpass query path, and the region-aware `OverpassService` / `PeakRefreshService` API already exists.
`./assets/region_manifest.json` already lists peak assets per region, but the app does not yet read those peak files.
First-launch seeding should import bundled peaks only when the local DB is empty; existing installs keep their stored peaks untouched during the empty-marker bootstrap step.
Later launches should compare the manifest's seedable regions against locally recorded imports, import any newly added seedable regions, and re-import any seedable regions whose manifest fingerprints changed.
Files to examine:
- `./assets/region_manifest.json`
- `./assets/peaks/*.json`
- `./lib/main.dart`
- `./lib/models/peak.dart`
- `./lib/services/overpass_service.dart`
- `./lib/services/peak_refresh_service.dart`
- `./lib/providers/map_provider.dart`
- `./test/services/peak_refresh_service_test.dart`
- `./test/harness/test_peak_overpass_service.dart`
</background>

<user_flows>
Primary flow:
1. App starts with bundled peak data for all seedable regions.
2. Imported peaks keep their source region.
3. First launch seeds only when the DB is empty.
4. Peak refresh can query a specific region using explicit bounds.
5. Later launches import any newly added seedable regions from the manifest and re-import any seedable regions whose manifest fingerprints changed.

Alternative flows:
- Existing Tasmania-only refresh still works when called without arguments.
- Non-Tasmanian peaks already stored in ObjectBox keep their region value.
- Existing installs with stored peaks but no import markers bootstrap only the legacy `tasmania` marker fingerprint when Tasmania peaks are already present, then import any other missing seedable regions.
- Existing installs with stored peaks but no import markers do not retroactively reconcile historical bundled-data changes for already-present Tasmania data during that bootstrap pass.

Error flows:
- Missing peak asset or malformed JSON: fail the import path cleanly and log the failure.
- Refresh called without bounds for a non-default region: fail fast with a clear argument error.
</user_flows>

<requirements>
**Functional:**
1. Bundle `./assets/region_manifest.json` and `./assets/peaks/` as committed app assets so the app can read shipped regional peak data.
2. Add `./assets/region_manifest.json` and `./assets/peaks/` to `pubspec.yaml` asset declarations.
3. Remove `./assets/peaks` from `.gitignore` so bundled peak JSON is versioned with the app.
4. Add a `composite: true` field to manifest region entries that are not seedable.
5. Add a manifest-driven peak import path that loads each seedable region’s peak JSON and assigns `Peak.region` from the manifest region key.
6. Enrich imported peaks with MGRS fields using the same converter/backfill path the app already uses for refreshed peaks.
7. Import bundled peaks only when the local DB is empty on first launch.
8. Add a `fingerprint` field to each seedable region entry in `./assets/region_manifest.json`.
9. Persist the last imported region fingerprints in `SharedPreferences` as one JSON-encoded map keyed by region key.
10. Compute each seedable-region fingerprint as a SHA-256 hash of the raw bytes of that region’s listed peak asset files, in manifest order.
11. Add a tool under `./tool/` that recomputes and updates manifest fingerprint fields for all seedable regions before shipping.
12. Add a validation command that fails when any seedable region's stored manifest fingerprint does not match the SHA-256 hash of its listed peak asset files.
13. On later launches, import any newly added seedable regions and re-import any seedable region whose manifest fingerprint has changed by replacing only matching stored peaks whose `sourceOfTruth == OSM`, adding new bundled peaks, and leaving stale stored OSM peaks untouched.
14. Remove `await peakRepository.backfillRegion(Peak.defaultRegion);` from startup so preloaded non-Tasmanian peaks are not rewritten.
15. Generalize `OverpassService` to accept a region plus bounds and query peaks for the provided bounding box.
16. Generalize `PeakRefreshService` to accept the same region/bounds inputs and pass them through to `OverpassService`.
17. Keep the existing no-arg Tasmania refresh path working for current UI flows.
18. Preserve stored peak regions during refresh and merge operations.
19. Treat bundled peak assets as raw Overpass JSON with a top-level `elements` array; import `node` records via `Peak.fromOverpass()` and skip malformed records.
20. Write the per-region import marker only after that region’s peaks are fully saved successfully.
21. If the import-marker store is empty on startup and the peak repository already contains peaks, initialize only the legacy `tasmania` marker fingerprint when Tasmania peaks are already present, without inferring any other region imports from free-form `Peak.region` values.
22. After that bootstrap, import only seedable regions that are still missing from the marker store; if the peak repository is empty, perform the full first-launch seed pass and then write each imported region's manifest fingerprint.
23. The empty-marker bootstrap pass does not retroactively detect or reconcile historical bundled-data changes for already-present Tasmania data; fingerprint-based re-import applies only after marker fingerprints exist.
24. Run the seed/diff logic from `./lib/providers/map_provider.dart::_loadPeaks()` before peak state is published to the UI.
25. When a bundled import matches an existing peak and the stored peak has `sourceOfTruth == OSM`, replace the stored peak with the bundled peak while preserving the existing ObjectBox `id`, `altName`, and `verified` fields.

**Validation:**
26. Add unit coverage for region-aware refresh input propagation.
27. Add unit coverage that proves stored peak regions are not overwritten by startup backfill.
28. Add unit coverage for first-launch seeding, manifest region assignment, MGRS enrichment, and empty-DB skip behavior on existing installs.
29. Add unit coverage for manifest-diff migration: newly added seedable regions import once, already imported regions do not duplicate, composite regions stay excluded.
30. Add unit coverage for re-importing a seedable region when its manifest fingerprint changes.
31. Add unit coverage for the Overpass JSON parse contract and malformed-record skipping.
32. Add unit coverage that failed or partial region imports do not mark the region imported.
33. Add unit coverage for empty-marker-store bootstrap of legacy Tasmania installs without modifying stored peaks, plus fingerprint writes.
34. Add unit coverage that the empty-marker bootstrap does not infer non-Tasmania imports from free-form `Peak.region` values and does not retroactively reconcile already-present Tasmania data.
35. Add coverage for the fingerprint update tool so stale manifest fingerprints are rewritten deterministically.
36. Add coverage for the fingerprint validation command so stale manifest fingerprints fail deterministically.
37. Add unit coverage that OSM-sourced stored peaks are replaced by bundled imports while preserving `id`, `altName`, and `verified`; stale stored OSM peaks are preserved; and non-OSM peaks are preserved.

**Out of scope:**
38. No UI for selecting a refresh region yet.
39. No server-side change.
40. No change to how composite regions are displayed or used for basemap lookup.
</requirements>

<implementation>
Keep the existing region/bounds-aware refresh API in `./lib/services/overpass_service.dart`, `./lib/services/peak_refresh_service.dart`, and `./lib/providers/map_provider.dart` intact while adding bundled peak import behavior.
Add a manifest-driven asset importer for bundled peak JSON under `./lib/services/` or the existing repository layer.
Add a small local import-marker store so startup can diff manifest seedable regions against previously imported regions.
Add a fingerprint update tool under `./tool/` that recalculates and writes manifest fingerprint fields for seedable regions.
Add a fingerprint validation command under `./tool/` or the dev/test workflow that fails when manifest fingerprint fields are stale.
For populated repositories with an empty marker store, bootstrap only the legacy Tasmania marker fingerprint before importing any other missing seedable regions.
Update test harnesses under `./test/harness/` and add focused `./test/services/peak_refresh_service_test.dart` coverage for a non-default region plus first-launch seeding.
</implementation>

<done_when>
Bundled peaks for every seedable region can be loaded without clobbering region metadata.
Changed seedable regions are re-imported when their manifest fingerprints change.
A fingerprint update tool exists for seedable regions.
A fingerprint validation command fails when manifest fingerprint fields are stale.
Peak refresh accepts region/bounds and still supports the current Tasmania-only flow.
No startup code rewrites all stored peaks to Tasmania.
</done_when>
