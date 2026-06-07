## Overview

Bundled regional peak bootstrap + fingerprinted reimport; keep current region-aware refresh API.
Startup path in `MapNotifier._loadPeaks()`; asset importer + marker store + fingerprint tool.

**Spec**: `ai_specs/regional-peak-data-spec.md` (read this file for full requirements)

## Context

- **Structure**: service/provider-first under `lib/services/` + `lib/providers/`
- **State management**: Riverpod `Notifier`; startup work in `MapNotifier`
- **Reference implementations**: `lib/services/polygon_asset_repository.dart`, `lib/services/route_graph_import_service.dart`, `lib/services/migration_marker_store.dart`, `lib/services/peak_refresh_service.dart`, `lib/providers/map_provider.dart`
- **Assumptions/Gaps**: use dedicated region-import marker store backed by `SharedPreferences`; keep legacy bootstrap limited to Tasmania; no new UI beyond existing refresh flow; empty-marker bootstrap does not retroactively reconcile historical Tasmania asset drift

## Plan

### Phase 1: Bootstrap Slice

- **Goal**: empty-DB bundled seed path working end-to-end
- [x] `pubspec.yaml` - add `assets/region_manifest.json` and `assets/peaks/`
- [x] `.gitignore` - stop ignoring `assets/peaks`
- [x] `assets/region_manifest.json` - add `fingerprint` to seedable regions; keep `composite: true` entries excluded
- [x] `lib/services/peak_region_import_marker_store.dart` - JSON map store for region fingerprints in `SharedPreferences`
- [x] `lib/services/peak_region_asset_import_service.dart` - load manifest + Overpass-shaped peak assets + MGRS enrich + empty-DB seed
- [x] `lib/providers/map_provider.dart` - replace empty-DB `refreshPeaks()` bootstrap with bundled seed/diff entrypoint
- [x] TDD: empty repo seeds all seedable regions from bundled assets and writes fingerprint markers
- [x] TDD: bundled import assigns manifest region and MGRS fields
- [x] TDD: malformed asset rows are skipped; unreadable asset fails cleanly
- [x] Verify: `flutter analyze` && `flutter test test/services/peak_region_asset_import_service_test.dart test/services/peak_region_import_marker_store_test.dart`

### Phase 2: Existing Install Migration

- **Goal**: populated install bootstrap; no unintended rewrites
- [ ] `lib/services/peak_region_asset_import_service.dart` - empty-marker bootstrap for legacy Tasmania only; import only missing seedable regions after bootstrap
- [ ] `lib/providers/map_provider.dart` - run bootstrap/diff before publishing peaks; preserve existing non-empty repo flow
- [ ] `lib/models/peak.dart` - keep current model; no schema change beyond using existing `region` / `sourceOfTruth`
- [ ] TDD: populated repo + empty marker store writes only Tasmania fingerprint when Tasmania peaks exist
- [ ] TDD: bootstrap does not infer non-Tasmania imports from free-form `Peak.region`
- [ ] TDD: populated repo import leaves existing peaks untouched during bootstrap step
- [ ] TDD: bootstrap does not retroactively reconcile historical Tasmania bundled-data changes
- [ ] Verify: `flutter analyze` && `flutter test test/services/peak_region_asset_import_service_test.dart test/providers/map_provider_peak_bootstrap_test.dart`

### Phase 3: Fingerprint Reimport + OSM Policy

- **Goal**: changed region assets reconcile safely on later launches
- [ ] `lib/services/peak_region_asset_import_service.dart` - compare stored vs manifest fingerprints; reimport changed/missing regions
- [ ] `lib/services/peak_repository.dart` or importer-local merge path - preserve existing `id`, `altName`, `verified`; replace matching OSM peaks; preserve stale OSM + non-OSM peaks
- [ ] `lib/services/peak_refresh_service.dart` - keep current region/bounds refresh API intact; no startup regression
- [ ] TDD: changed fingerprint reimports region, replaces matching OSM rows, preserves `id`/`altName`/`verified`
- [ ] TDD: stale OSM rows remain; non-OSM rows remain
- [ ] TDD: failed region import does not update marker fingerprint
- [ ] Verify: `flutter analyze` && `flutter test test/services/peak_region_asset_import_service_test.dart test/services/peak_refresh_service_test.dart`

### Phase 4: Fingerprint Tooling

- **Goal**: deterministic manifest maintenance
- [ ] `tool/update_region_peak_fingerprints.dart` - recompute/write seedable-region fingerprints from listed peak asset bytes in manifest order
- [ ] `tool/validate_region_peak_fingerprints.dart` - fail when manifest fingerprint differs from recomputed hash
- [ ] `assets/region_manifest.json` - refresh fingerprints with tool output
- [ ] TDD: tool rewrites stale fingerprints deterministically
- [ ] TDD: validation command fails on stale fingerprints and passes on current manifest
- [ ] Verify: `flutter analyze` && `flutter test test/tool/update_region_peak_fingerprints_test.dart test/tool/validate_region_peak_fingerprints_test.dart`

## Risks / Out of scope

- **Risks**: legacy installs cannot retroactively detect historical Tasmania asset drift before first marker write; free-form `region` values from manual edits remain non-authoritative; large bundled imports may lengthen first startup
- **Out of scope**: refresh-region UI; server-side sync; composite-region import; removal of stale OSM peaks
