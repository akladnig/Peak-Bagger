## Overview
My Ascents dashboard card. Pure summary seam first, then card wiring, then robot journey coverage.

**Spec**: `ai_specs/my-ascents-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first; `lib/services`, `lib/providers`, `lib/widgets/dashboard`, `test/...`
- **State management**: Riverpod
- **Reference implementations**: `./lib/widgets/dashboard/my_lists_card.dart`, `./lib/widgets/dashboard/latest_walk_card.dart`, `./lib/providers/dashboard_layout_provider.dart`
- **Assumptions/Gaps**: explicit revision providers needed for ascent/peak refresh; bump them at existing mutation entry points

## Plan

### Phase 1: Summary + refresh seam

- **Goal**: grouped ascent rows; deterministic invalidation
- [x] `./lib/services/my_ascents_summary_service.dart` - pure rows: join peaks by OSM id, group by year, sort, skip null dates, fallback display text
- [x] `./lib/providers/my_ascents_summary_provider.dart` - derived view model; watch peak/bagged revisions + repos
- [x] `./lib/providers/peak_provider.dart` - add peak revision signal; bump on peak write paths
- [x] `./lib/providers/peak_list_provider.dart` - add bagged-ascent revision signal; bump on bagged write paths
- [x] `./lib/providers/map_provider.dart` / `./lib/screens/objectbox_admin_screen.dart` - increment revisions at peak refresh/save/delete and bagged sync/rebuild points
- [x] `./test/services/my_ascents_summary_service_test.dart` - TDD: group/sort/tie-break/null-date skip/missing metadata/repeated ascents
- [x] `./test/providers/my_ascents_summary_provider_test.dart` - TDD: reacts to revision bumps; empty state stable
- [x] Verify: `flutter analyze && flutter test test/services/my_ascents_summary_service_test.dart test/providers/my_ascents_summary_provider_test.dart`

### Phase 2: Card + dashboard slot

- **Goal**: compact table card; slot migration
- [x] `./lib/widgets/dashboard/my_ascents_card.dart` - table UI, empty state, year headers, sort toggle, internal scroll, stable keys
- [x] `./lib/screens/dashboard_screen.dart` - render `MyAscentsCard` in `my-ascents`; preserve drag/reorder wiring
- [x] `./lib/providers/dashboard_layout_provider.dart` - register `my-ascents`; replace default `top-5-walks`; keep legacy migration
- [x] `./test/widget/my_ascents_card_test.dart` - TDD: title, columns, year headers, sort toggle, empty state, null-date skip, wide/narrow sanity
- [x] `./test/widget/dashboard_screen_test.dart` - TDD: `my-ascents` slot visible; order preserved; legacy id migration; drag still works
- [x] Verify: `flutter analyze && flutter test test/widget/my_ascents_card_test.dart test/widget/dashboard_screen_test.dart`

### Phase 3: Robot journey coverage

- **Goal**: stable dashboard journey; fake data path
- [x] `./test/robot/dashboard/dashboard_robot.dart` - add selectors for `my-ascents` card, table, rows, sort toggle, year headers
- [x] `./test/robot/dashboard/dashboard_journey_test.dart` - open dashboard; verify card; assert grouped rows; toggle sort; confirm migrated layout order
- [x] Add/adjust deterministic fake fixtures for `PeakRepository`, `PeaksBaggedRepository`, shared prefs
- [x] Verify: `flutter analyze && flutter test test/robot/dashboard/dashboard_journey_test.dart`

## Risks / Out of scope

- **Risks**: revision bumps missed at one mutation entry point; default order migration can break first-launch layout if stale ids remain
- **Out of scope**: ascent editing, navigation, map interactions, persisted sort preference, new storage layer
