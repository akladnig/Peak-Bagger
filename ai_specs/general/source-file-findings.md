# Findings
1. lib/providers/map_provider.dart:38-1538 is the highest-priority split candidate. At 1,538 lines it mixes state definition, persistence, peak refresh, track import/recalc, MGRS/grid parsing, search, and UI toggle state. The clearest first extraction is parseGridReference() in :798-1304; after that, split MapState/enums (:34-228), track lifecycle/import logic (:306-649), and map position/MGRS persistence (:665-797) into separate files.
2. lib/screens/map_screen.dart:257-1115 is effectively several widgets in one file. The build() tree owns keyboard handling (:283-390), map/layer composition (:401-544), peak search UI (:582-669), goto UI (:670-761), info popup (:762-860), and track polyline rendering (:1064-1114). This should become a thin screen shell plus extracted overlay/layer widgets.
3. lib/services/gpx_importer.dart:63-927 has too many responsibilities for one service. It combines GPX parsing (:185-443), filename/path normalization (:329-415), import orchestration (:445-685), processing/filtering/stat calculation (:687-747), and file organization/logging (:768-927). I’d split this into parser, processor, and file-organization helpers, leaving GpxImporter as orchestration only.
4. lib/screens/objectbox_admin_screen.dart:300-840 is already internally decomposed into multiple widgets, but they are all trapped in one file. This is a good low-risk mechanical split: move _AdminControls (:300-429), schema widgets (:482-530), data-grid widgets (:532-768), and _DetailsPane (:770-840) into separate files and keep the screen state/lifecycle in the root file.
5. lib/screens/settings_screen.dart:42-765 mixes screen state, action tiles, dialogs, and settings sections. The natural splits are top action tiles (:48-166), result/failure dialogs (:376-556), track filter section (:558-667), and peak correlation section (:670-713). That would leave SettingsScreen as a coordinator instead of a 700+ line file.
6. lib/services/gpx_importer.dart:725-747 and lib/providers/map_provider.dart:587-609 duplicate the same “apply processing result onto GpxTrack” mapping. If you split the importer, use that refactor to centralize this logic so future schema/stat changes are not updated in two places.
7. lib/services/geo.dart:1-652 is large, but it is comparatively cohesive and appears adapted from external geo utilities. I would not prioritize splitting it unless you expect ongoing feature work there; size alone is not enough reason.
8. lib/services/gpx_track_statistics_calculator.dart:48-522 and lib/services/gpx_track_filter.dart:21-517 are borderline-large, but both are still mostly single-purpose algorithm files. I’d leave them alone for now unless more behavior gets added, then split parser/helpers from calculation/filter pipelines.

## Size Snapshot
lib/objectbox.g.dart is large but generated, so I excluded it from recommendations.
Largest actionable source files in lib/:
1. lib/providers/map_provider.dart — 1538
2. lib/screens/map_screen.dart — 1115
3. lib/services/gpx_importer.dart — 927
4. lib/screens/objectbox_admin_screen.dart — 840
5. lib/screens/settings_screen.dart — 765
6. lib/services/geo.dart — 652
7. lib/services/gpx_track_statistics_calculator.dart — 522
8. lib/services/gpx_track_filter.dart — 517

## Recommendation
1. Split now: map_provider.dart, map_screen.dart, gpx_importer.dart.
2. Split next: objectbox_admin_screen.dart, settings_screen.dart.
3. Leave for now: geo.dart, gpx_track_statistics_calculator.dart, gpx_track_filter.dart.

## Current Status
- [ ] map_provider.dart
- [x] map_screen.dart
- [ ] gpx_importer.dart
- [ ] objectbox_admin_screen.dart
- [i] settings_screen.dart
- [ ] geo.dart
- [ ] gpx_track_statistics_calculator.dart
- [ ] gpx_track_filter.dart



# Finding 5: Tasmap key quirks
This is the smallest issue, but it’s the kind of thing a cleanup refactor can accidentally “improve” and break tests.
What’s quirky today
There are a couple of existing key behaviors that are a bit odd but currently stable:
- tasmap-label-layer
  - used in two mutually exclusive branches in MapScreen
  - one for selected-map labels
  - one for overlay labels
- tasmap-layer
  - used for the overlay polygon layer
  - also used inside the selected-map outline path via TasmapOutlineLayer
Those are not elegant, but they are part of current finder-visible behavior.
