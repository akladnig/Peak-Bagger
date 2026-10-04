---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What is the canonical owner of Peak Bagger's non-UI mapping datasets?

Answer: The Mapping data store is the canonical source for every non-UI mapping dataset. Flutter assets retain only UI icons.

Decision: `/Volumes/Services/Mapping` is the app-read-only Mapping data store; do not keep bundled or duplicated runtime mapping data in the Flutter repository.

### L2

Status: current

Question: How should the app behave when the Mapping data store is unavailable at launch?

Answer: Show a blocking startup screen titled `Mapping data store unavailable`, naming `/Volumes/Services/Mapping`, with `Retry` and `Quit`. Do not open the main app in a partially available state.

Decision: Successful preflight of the Mapping data store is required before the main app can open.

### L3

Status: current

Question: What manifest and path contract should the external store use?

Answer: Use one Mapping data manifest at `/Volumes/Services/Mapping/region_manifest.json` with store-relative paths and no `assets/...` compatibility layer.

Decision: Store-relative paths such as `Peaks/tasmania-peaks.json`, `Highways/tasmania-highways.json`, and `Polygons/tasmania.poly` are the sole runtime path contract.

### L4

Status: current

Question: Which platforms must support the Mapping data store migration?

Answer: macOS only, with no bundled-data or cross-platform fallback.

Decision: Non-macOS targets are out of scope and must fail clearly rather than run a partial data mode.

### L5

Status: current

Question: How should the app behave if the Mapping data store disappears after launch?

Answer: Retain already loaded data. The operation that needs an unreadable file shows `Mapping data store unavailable` and offers `Retry`; it must not reset the UI or delete ObjectBox data.

Decision: Mid-session loss is operation-scoped, preserves loaded and persisted state, and is retryable.

### L6

Status: current

Question: May the Flutter app write, download, or repair Mapping data?

Answer: No. Maintainer tools prepare the Mapping data store; the app only reads it.

Decision: The Mapping data store is read-only to the app. User data remains in ObjectBox and existing Bushwalking folders.

### L7

Status: current

Question: What automated verification is required for the external filesystem dependency?

Answer: Use injected filesystem and store-root seams. Cover the startup screen, retry, exact missing-path copy, and mid-session loss without depending on the real mounted volume.

Decision: Require unit, widget, and provider/service coverage with fakes; do not require a real `/Volumes/Services/Mapping` mount in automated tests.

### L8

Status: current

Question: Must physical migration of data files be complete for this change?

Answer: Yes. The six regional peak JSON files, region manifest, and TasMap CSV have been moved out of the project assets and into the Mapping data store.

Decision: File migration is required acceptance criteria. The Flutter project must not retain non-UI mapping datasets under `assets/`.

### L9

Status: current

Question: How should the Mapping data manifest cover TasMap, DEM, and unused highway sources?

Answer: The one manifest defines TasMap and named DEM sources. Keep Tasmania and Northeast Alps highway declarations, but remove currently unused New South Wales, Italy North East, Italy North West, Italy aggregate, and Croatia highway declarations.

Decision: The manifest defines `Maps/tasmap50k.csv`, `DEM/Elvis/elvis_runtime_10m.tif`, `DEM/tasmania_dem_25m.tif`, and `DEM/cop30_hh.tif`; it contains only required highway references.

### L10

Status: current

Question: How should Northeast Alps routing coverage handle Slovenia?

Answer: Preserve FVG, Veneto, and Slovenia coverage. Treat `Highways/slovenia-highways.json` as an available required source.

Decision: The external data preflight requires the Slovenia highway export for Northeast Alps routing coverage.
