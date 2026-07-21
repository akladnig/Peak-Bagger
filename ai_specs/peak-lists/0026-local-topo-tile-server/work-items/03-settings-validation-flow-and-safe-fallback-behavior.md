---
type: Work Item
title: Settings Validation Flow And Safe Fallback Behavior
parent: ../spec.md
---

## What to build
Add the persisted `Local tile server base URL` Settings flow to the Flutter app with the exact visible validation states, actions, and fallback behavior required by the Spec. This slice must let the user save one `http` or `https` base URL, perform live capability validation only on save and explicit retry, restore the last successful snapshot on launch without probing, keep the saved value and current validation state visible in every state, and immediately fall back to `Tracestrack Topo` whenever clearing or failed revalidation removes an active `Local Topo` configuration.

## Required context
- `lib/screens/settings_screen.dart` already contains user-facing Settings flows and is the natural surface for the exact label `Local tile server base URL` plus the save, retry, and clear actions.
- `lib/providers/map_provider.dart` already owns active basemap selection, so any required immediate fallback to `Basemap.tracestrack` when `Local Topo` becomes invalid should be coordinated through that existing seam rather than a new map-selection owner.
- Persistence and restore patterns elsewhere in the app use `SharedPreferences` with deterministic tests; follow those conventions for the saved URL, validation state, and restored snapshot presentation.
- Existing widget and provider coverage around Settings and map state should be extended with fake HTTP or fixture seams rather than real network calls.

## Acceptance criteria
- [x] Settings exposes one persisted field labeled exactly `Local tile server base URL` that stores only an `http` or `https` base URL and never stores region-specific tile path segments as part of the saved setting.
- [x] The Settings surface shows the explicit states `Empty`, `Invalid URL syntax`, `Validating`, `Live validated`, `Restored snapshot`, and `Validation failed`, and the saved URL plus the current validation state remain visible in every state.
- [x] The setting is considered configured only after both validations pass: syntactically valid `http` or `https` base URL parsing and a successful live capability response identifying a compatible `Peak Bagger` local topo service.
- [x] `Save` and `Retry` are disabled while validation is in flight, `Retry` is enabled only when a persisted non-empty URL exists, and `Clear` removes `Local Topo` availability and returns the app to existing basemap-only behavior.
- [x] Saving a different non-empty URL persists that new URL immediately, deactivates any snapshot tied to the previous saved URL immediately, and does not keep `Local Topo` available from the previous host while the new URL is in `Validating`.
- [x] App launch restores the last successful capability snapshot for the currently saved URL without triggering an automatic live validation request, and the restored state is presented as `Restored snapshot` rather than as a live reachability guarantee.
- [x] Validation requests are sent only when the user saves the Settings value and when the user explicitly retries validation; the app does not continuously probe the local tile server in the background.
- [x] If `Local Topo` is currently selected when the setting is cleared or a revalidation attempt fails, the app immediately switches the active basemap to `Tracestrack Topo`.
- [x] `Local Topo` does not become available in the basemap drawer while the setting is in `Empty`, `Invalid URL syntax`, or `Validation failed`, and any active snapshot is only valid for the currently saved URL.
- [x] Deterministic widget or provider coverage proves the exact Settings states, enabled or disabled actions, save or retry or clear behavior, persisted snapshot restore, no-auto-probe launch behavior, and safe fallback to `Tracestrack Topo` without live LAN dependencies.

## Covers
- User Stories: 1-2
- Requirements: 6-8, 15-16
- Technical Decisions: 1, 3, 5, 7
- Testing Strategy: 2, 4
- Interview Ledger: L3-L4, L8, L11

## Blocked by
- 02-app-local-topo-contract-persistence-and-runtime-url-resolver.md
