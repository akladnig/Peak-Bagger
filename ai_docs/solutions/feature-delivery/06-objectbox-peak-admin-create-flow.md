---
title: Peak admin create flow in ObjectBox Admin
date: 2026-04-23
work_type: feature
tags: [flutter, objectbox, peak-admin, testing]
confidence: high
references:
  - ai_specs/06-objectbox-peak-admin-spec.md
  - ai_specs/06-objectbox-peak-admin-plan.md
  - lib/screens/objectbox_admin_screen.dart
  - lib/screens/objectbox_admin_screen_details.dart
  - lib/screens/objectbox_admin_screen_controls.dart
  - test/robot/objectbox_admin/objectbox_admin_robot.dart
  - test/robot/objectbox_admin/objectbox_admin_journey_test.dart
---

## Summary
Added Peak-only create support to ObjectBox Admin by reusing the existing Peak details pane in a create mode, rather than introducing a separate modal flow. The admin screen now exposes an `Add Peak` action, keeps non-Peak entities read-only, and preserves selection/refresh behavior after save.

## Reusable Insights
- Reuse the existing details pane for create mode when edit/create share the same form shape. A simple `createMode` flag kept the UI and validation logic concentrated in one place.
- Clear create state when the selected entity or view mode changes. Otherwise stale create state can leak across row selection and mode switches.
- For desktop-style Flutter widget tests, align the test surface size with the real layout. The Peak create journey only stabilized once the robot harness used a wider surface.
- In `flutter_test`, `enterText` is sensitive to what widget is targeted. When a `TextFormField` wrapper caused focus issues, typing through the robot helper needed to target the actual editable field path and use stable keys.
- Stable app-owned keys matter more than visual text in robot flows. The Peak create button and form fields were much easier to drive once keys were normalized and consistently named.

## Decisions
- Peak mutation behavior stayed isolated to `Peak`; all other ObjectBox entities remained browse-only.
- Save success refreshes the table and keeps the created Peak selected, which gives a clearer post-submit confirmation than clearing the pane immediately.

## Pitfalls
- Robot tests initially failed for reasons unrelated to business logic: the form field key mapping was inconsistent (`osmId` vs `osm-id`), and the test surface was too small for the create form layout.
- Visibility helpers like `scrollUntilVisible` can fail when duplicate matches or offscreen layout states confuse the finder. Direct key-based access was more stable here.

## Validation
- `flutter test test/widget/objectbox_admin_shell_test.dart`
- `flutter test test/widget/objectbox_admin_browser_test.dart`
- `flutter test test/robot/objectbox_admin/objectbox_admin_journey_test.dart`
- `flutter analyze`
