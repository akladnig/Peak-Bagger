---
title: Shared AppBar theme lane
date: 2026-04-20
work_type: feature
tags: [flutter, app-bar, navigation]
confidence: high
references: [ai_specs/001-app-bar-spec.md, ai_specs/001-app-bar-plan.md, lib/router.dart, lib/widgets/map_action_rail.dart, test/widget/gpx_tracks_shell_test.dart, test/widget/objectbox_admin_shell_test.dart, test/robot/objectbox_admin/objectbox_admin_robot.dart]
---

## Summary

Built one shared shell `AppBar` for all top-level routes, with navigation and titles driven by a single destination model.
Kept the theme action in the `AppBar` on every route, but aligned its right-side lane to the Map route FAB column without turning it into a FAB.

## Reusable Insights

- Use one branch-indexed destination model as the shell source of truth: route path, label, title, icon, stable key.
- Keep selector contracts explicit and stable: `nav-dashboard`, `nav-map`, `nav-peak-lists`, `nav-objectbox-admin`, `nav-settings`.
- Attach destination keys to the actual tap targets in both wide and compact layouts; keep one migration alias only when needed (`side-menu-objectbox-admin`).
- Preserve wide/compact consistency by rendering the same ordered destination list in both layouts.
- When a control must feel “aligned” with another lane, prefer padding/leading-width/row placement in the `AppBar` over changing the control type or moving it into the content area.
- For the Map route, keep the theme control in the `AppBar` and use the Map FAB column as a horizontal positioning reference only.
- Wide `AppBar` alignment mattered: home icon centered in the same lane as the side-nav icons, title left-aligned, and title wrapped in a keyed wrapper for stable descendant assertions.
- Compact layout needed a different contract: menu trigger in `AppBar.leading`, home action in the title row, drawer closes on active-destination tap.

## Decisions

- Prefer codebase consistency over abstract best-practice purity: `StatefulShellRoute.indexedStack` + branch index stayed the core navigation identity.
- Keep the shared theme toggle visible in the `AppBar` on every route; do not convert the Map route theme control into a FAB.
- Keep `themeModeProvider` behavior unchanged: system loads as default, toggle flips only dark/light.

## Pitfalls

- Route-local AppBar titles in Settings/ObjectBox Admin had to be removed or the shared header duplicated.
- Map route overlays and the action rail can exceed the default test viewport; tight vertical spacing and geometry assertions help catch regressions.
- Existing tests used icon-based or legacy keys; moving them to shared destination keys avoided brittle selector drift.

## Validation

- `flutter analyze`
- `flutter test`
- Widget assertions that proved useful:
  - `shared-app-bar` exists on all routes
  - `app-bar-title` can be matched as a keyed wrapper, not just raw `Text`
  - `nav-*` keys render in the shared order
  - Map theme action stays inside `shared-app-bar` and aligns horizontally with the map FAB lane

## Follow-ups

- If more shell controls are added, give them shared keys up front and attach them to the real tap target.
- If a new route needs special alignment, document the lane relationship explicitly instead of hard-coding a second control placement.
