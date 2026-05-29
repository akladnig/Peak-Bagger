## Overview

Extract the map-specific floating action buttons and the basemap drawer out of `lib/router.dart` so `lib/screens/map_screen.dart` owns the full map UI shell.

**Spec**: none; this is a minimal UI refactor plan.

## Context

- `router.dart` currently owns the top-right shell controls and the `endDrawer` content.
- `map_screen.dart` already owns map interaction state, so the map action rail and basemap drawer belong there.
- The `Basemaps` action must remain on the same `Scaffold` as the drawer so `openEndDrawer()` keeps working.
- Keep changes small by moving existing widgets instead of redesigning the layout.

## Plan

### Exact File Move List

- `lib/router.dart:17-69` -> `lib/widgets/map_basemaps_drawer.dart`
- `lib/router.dart:97-549` -> `lib/widgets/map_action_rail.dart`
- `lib/router.dart:678-733` -> `lib/widgets/left_tooltip_fab.dart`
- `lib/screens/map_screen.dart:265-266` -> add `endDrawer: const MapBasemapsDrawer()` to the existing `Scaffold`
- `lib/screens/map_screen.dart:374-575` -> add `const MapActionRail()` into the root `Stack` with the other top-level overlays
- `lib/router.dart:19-69` -> delete the shell `endDrawer` block after the extraction lands
- `lib/router.dart:97-549` -> delete the map FAB stack after the extraction lands
- `lib/router.dart:678-733` -> delete the private `_LeftTooltipFab` after the helper file lands

### Phase 1: Shared tooltip helper

- Add `lib/widgets/left_tooltip_fab.dart`.
- Move `_LeftTooltipFab` from `lib/router.dart` unchanged.
- Update `lib/router.dart` to import and use the shared helper for the theme FAB if needed by nearby controls.

### Phase 2: Basemap drawer extraction

- Add `lib/widgets/map_basemaps_drawer.dart`.
- Move the current `endDrawer` widget tree from `lib/router.dart` into `MapBasemapsDrawer` unchanged.
- Keep its `Consumer` + `mapProvider` behavior intact.

### Phase 3: Map action rail

- Add `lib/widgets/map_action_rail.dart`.
- Copy the current map-only FAB stack from `lib/router.dart` into a `ConsumerWidget`.
- Keep existing `heroTag`s, keys, and provider calls unchanged.
- Include the `Basemaps` FAB in this rail so it can open the drawer from `MapScreen`.
- Exclude the theme FAB from this rail.

### Phase 4: Map screen integration

- Update `lib/screens/map_screen.dart` to own `endDrawer: const MapBasemapsDrawer()` on its existing `Scaffold`.
- Insert `const MapActionRail()` into the root `Stack` near the other top-right overlays.
- Do not change map state logic, keyboard shortcuts, popup behavior, or existing map overlays.

### Phase 5: Router cleanup

- Remove the extracted map action column from `lib/router.dart`.
- Remove the `endDrawer` block from `lib/router.dart`.
- Keep only shell-level controls in `router.dart`, especially the theme FAB and navigation shell.

## Verification

- Run `flutter analyze`.
- Run `flutter test`.

## Risks

- `Basemaps` must remain inside the `MapScreen` scaffold or `openEndDrawer()` will break.
- If any tests assert the exact shell layout, update selectors only where necessary.
