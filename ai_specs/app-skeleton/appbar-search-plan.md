## Overview

Shared AppBar search for map shell. Peak/track/route/map search; popup-shell UI; type-specific selection wiring.

**Spec**: `ai_specs/app-skeleton/appbar-search-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `widgets/`, `providers/`, `services/`, `models/`
- **State management**: Riverpod `Notifier`; shared map state in `lib/providers/map_provider.dart`
- **Reference implementations**: `lib/router.dart`, `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/core/widgets/popup_shell.dart`, `test/widget/map_screen_peak_search_test.dart`
- **Assumptions/Gaps**: region `name` added in manifest; regenerate region catalog before UI consumption

## Plan

### Phase 1: Vertical Slice

- **Goal**: centered AppBar trigger -> popup -> peak search/select path
- [x] `lib/router.dart` - restructure AppBar: left title block, centered search trigger, right actions block
- [x] `lib/providers/map_provider.dart` - replace peak-only popup state with shared search-popup state; keep minimal peak slice first
- [x] `lib/services/map_search_service.dart` - add service skeleton + peak query slice only; constructor-injected repos/resolvers
- [x] `lib/widgets/map_search_popup.dart` - build popup with `PopupShell`; search field, close, results header, stable keys
- [x] `lib/widgets/map_search_results_list.dart` - render mixed-result row shell; implement peak row first
- [x] `lib/screens/map_screen.dart` - open/close shared popup; focus handoff; peak select uses existing peak path
- [x] TDD: peak query returns capped, case-insensitive peak matches; empty query -> empty results; no matches -> empty state
- [x] TDD: AppBar trigger opens popup; `Cmd+F` opens same popup; close restores focus/shortcut readiness
- [x] TDD: selecting a peak result closes popup and follows existing peak selection behavior
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Search Domain Expansion

- **Goal**: add tracks/routes/maps; anchor projection; labels
- [x] `lib/services/map_search_service.dart` - add track, route, map queries; unify result model, sort, type filter, region filter
- [x] `lib/models/map_search_result.dart` - typed result payloads + anchor/summary contract
- [x] `lib/services/map_name_resolution.dart` - extend/reuse point-based map label resolution for result summaries if needed
- [x] `lib/services/gpx_storage_destination_resolver.dart` or adjacent runtime helper - expose reusable point->region resolution for search, not importer-private flow
- [x] `lib/providers/map_provider.dart` - add map-specific atomic selection helper; wire track/route selections to existing `showTrack` / `showRoute` paths with derived marker anchor
- [x] `lib/screens/map_screen.dart` - route selection callbacks for map/track/route result types
- [x] `lib/services/region_manifest_catalog.dart` - surface region display name from manifest data
- [x] `lib/generated/region_manifest_catalog.g.dart` - regenerate from source inputs; no manual edits
- [x] TDD: first runtime geometry point projects anchor for track/route results; missing geometry excludes result
- [x] TDD: map result selection updates `selectedMap`, `selectedLocation`, `selectedMapFocusSerial`; track/route selection uses type-specific focus serials
- [x] TDD: track/route rows defer metric formatting to existing helpers from panel conventions
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Full Popup Controls

- **Goal**: entity buttons, filter/sort menus, placeholders, cleanup
- [x] `lib/widgets/map_search_popup.dart` - add All / Peaks / Tracks-Routes / Natural / Roads / Maps buttons; selected-button theme; disabled placeholders
- [x] `lib/providers/map_provider.dart` or `lib/providers/map_search_provider.dart` - add search UI state: entity filter, region filter, name sort, reset-on-close
- [x] `lib/services/map_search_service.dart` - apply type filter, region filter, name asc/desc ordering, 20-result cap
- [x] `lib/screens/map_screen.dart` - dismiss competing overlays on open; remove/delegate old peak-only popup path and rail trigger behavior
- [x] TDD: default state = All + no region + name asc + empty query
- [x] TDD: entity button exclusivity; disabled Natural/Roads inert; filter/sort update results live
- [x] TDD: region menu uses manifest `name` labels while filtering by canonical keys
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Journey Coverage

- **Goal**: robust user-flow coverage; selector contract
- [x] `test/widget/map_screen_appbar_search_test.dart` - widget coverage for AppBar layout, popup shell, controls, empty states, per-type result rendering
- [x] `test/widget/map_screen_keyboard_test.dart` - `Cmd+F`, close/escape, focus restoration, overlay dismissal interactions
- [x] `test/robot/map/appbar_search_robot.dart` - robot API for trigger, query, filters, result taps, selectors
- [x] `test/robot/map/appbar_search_journey_test.dart` - critical journeys: open from AppBar, open from `Cmd+F`, peak select, track/route select, map select
- [x] TDD: robot happy path one assertion at a time; add only keys/seams needed for declared journeys
- [x] Robot journey tests + selectors/seams for critical flows: `app-bar-search-trigger`, popup root, field, entity buttons, filter/sort buttons, result rows; deterministic fake repos + `TestTasmapRepository`/`TestMapNotifier`
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: region catalog regeneration path may need tool/source update; AppBar center layout may collide with long title/summary strip; track/route anchorless records may reduce visible results
- **Out of scope**: Natural/Roads data sources; mobile/compact layout; route-graph trail search
