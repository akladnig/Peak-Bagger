---
type: Work Item
title: Natural Result Map Navigation
parent: ../spec.md
---

## What to build

Add the focused `MapNotifier` navigation path for selecting a Natural search result and dispatch it from the map screen's result selection handling. The path must use the same default-zoom camera request as the ObjectBox Admin Natural Feature map action while clearing ordinary Search-result selection and any selected-location marker, then closing the Search popup without creating any Natural Feature selection or details state.

Extend the existing AppBar Search robot journey with a deterministic Natural Feature fixture and the exact Natural result selector. Complete the targeted and full verification required by the Spec after this end-to-end behavior is in place.

## Required context

- `../spec.md` and `../interview-ledger.md` define the exact navigation behavior, forbidden Natural Feature UI/state, selector contract, and verification commands.
- `../../../../GLOSSARY.md` defines `Search popup`, `Natural Feature`, and `OSM feature identity`.
- Work Item 01 establishes the Natural `MapSearchResult` variant, category-set behavior, injected repository seam, and result selector required here.
- Follow selection and camera conventions in `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, and `lib/screens/objectbox_admin_screen.dart`. The ObjectBox Admin Natural Feature action is the default-zoom camera reference, not a new UI behavior to copy.
- Extend the existing deterministic test conventions in `test/harness/test_map_notifier.dart`, `test/providers/map_provider_search_selection_test.dart`, `test/robot/map/appbar_search_robot.dart`, and `test/robot/map/appbar_search_journey_test.dart`; use `NaturalFeatureRepository.test(InMemoryNaturalFeatureStorage(...))` rather than ObjectBox, network services, API keys, or external secrets.

## Acceptance criteria

- [x] Selecting a Natural result clears the existing ordinary Search-result selection and any existing selected-location marker before map navigation.
- [x] Selecting a Natural result closes the Search popup and centers the map at that Natural Feature coordinate using the normal map zoom, matching the existing ObjectBox Admin Natural Feature map action's default-zoom camera request.
- [x] Natural-result selection does not create a Natural Feature information popup, selected-location marker, persistent selection, saved object, or new map overlay; no Natural-specific selection state remains to clean up.
- [x] Provider/notifier coverage verifies selection-state clearing, selected-location-marker clearing, default-zoom camera request, popup closure, and absence of Natural-specific persisted selection or detail state.
- [x] The AppBar Search robot journey supplies a deterministic Natural Feature repository fixture, verifies default category visibility on open, locates the row through exactly `map-search-result-natural-<osmType>-<osmId>`, and verifies that selection closes Search, clears a pre-existing selected-location marker, centers at the feature coordinate, and creates neither a detail popup nor persistent selection.
- [x] Run the targeted service, provider, widget, and robot tests; `flutter analyze`; and the full `flutter test` suite.

## Covers

- User Stories: 3 (Natural-result map navigation)
- Requirements: 7
- Technical Decisions: 4
- Testing Strategy: 5-6
- Interview Ledger: L4

## Blocked by

01-multi-category-search-and-natural-results.md
