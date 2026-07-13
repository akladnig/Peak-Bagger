---
type: Work Item
title: Route Dashboard My Lists Rows To Map With List Selection And Failure Handling
parent: ../spec.md
---

## What to build

Change the dashboard `My Peak Lists` row journey so tapping `my-lists-row-<peakListId>` activates the tapped list in existing map provider state, navigates to `/map` instead of `My Peak Lists`, and triggers the queued bounds-fit camera behavior for that list. Preserve the existing `My Lists` dashboard card layout, summary math, and stable row keys, keep Tasmania-only lists on the same path as every other list, and if the tapped list has no resolvable member peak coordinates keep the user on the dashboard and show a concise `SnackBar` message that the list has no mappable peaks rather than navigating away.

## Required context

- `lib/widgets/dashboard/my_lists_card.dart` owns the current dashboard row tap behavior and stable row keys such as `my-lists-row-<peakListId>`.
- `lib/router.dart` owns the shared shell navigation, including `/map`, and existing shell tests already use keys such as `nav-map`.
- `lib/providers/my_lists_summary_provider.dart` and `lib/services/peak_list_summary_service.dart` feed the dashboard card; preserve the current summary math and list ordering behavior while changing only the navigation outcome.
- `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/dashboard_journey_test.dart`, `test/widget/my_lists_card_test.dart`, and map-route entry tests already provide stable selectors and deterministic shell navigation patterns for this journey.
- Reuse the queued camera and selected-list seams from the preceding Work Items instead of introducing live map gesture assertions or a second dashboard-only navigation path.

## Acceptance criteria

- [x] Tapping a dashboard `My Peak Lists` row navigates to `/map` instead of `My Peak Lists` and makes the tapped list the active selected peak list through existing map provider state rather than through a new route argument or query parameter.
- [x] The tapped dashboard list triggers the queued bounds-fit camera behavior derived from that list's member peak coverage, including mixed-region lists and Tasmania-only lists following the same navigation path.
- [x] If the tapped list's derived bounds are missing or unusable, the dashboard flow computes bounds from current member peak rows on demand, persists them, and then continues navigation to `/map`.
- [x] If the tapped list has no resolvable member peak coordinates, the app stays on the dashboard and shows a concise `SnackBar` message that the list has no mappable peaks instead of navigating away.
- [x] The existing `My Lists` dashboard card layout, summary math, and stable row keys including `my-lists-row-<peakListId>` remain unchanged so existing selectors continue to work.
- [x] Widget or app-shell coverage verifies the primary journey by tapping `my-lists-row-<peakListId>`, asserting navigation to `/map`, asserting the tapped list becomes active, and asserting the map route receives and consumes the expected queued camera-fit intent.
- [x] Failure-path coverage proves that a list with no resolvable member peak coordinates stays on the dashboard and surfaces the concise `SnackBar` message rather than navigating away.
- [x] Dashboard robot or journey coverage is updated from the previous `My Peak Lists` destination expectation to the new `/map` journey using existing stable selectors and deterministic navigation seams.

## Covers

- User Stories: 1-3
- Requirements: 1-3, 12-16
- Technical Decisions: 3
- Testing Strategy: 5-7, 10
- Interview Ledger: L1, L4

## Blocked by

- 1. `work-items/01-persist-peak-list-coverage-bounds-and-mixed-region-classification.md`
- 2. `work-items/02-support-mixed-region-map-selection-and-queued-bounds-fit-camera-intents.md`
