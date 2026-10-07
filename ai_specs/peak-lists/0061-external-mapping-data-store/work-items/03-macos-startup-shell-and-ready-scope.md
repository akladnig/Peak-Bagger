---
type: Work Item
title: Add macOS Startup Shell and Ready Scope
parent: ../spec.md
---

## What to build

Replace eager `main.dart` startup with a non-router startup shell that owns platform validation, Mapping-store preflight, catalog construction, and ready-only dependency initialization. Only the `ready` state creates the `ProviderScope` and router; inject the router, ready dependencies, and `MappingCatalog` into the ready app.

## Required context

- Refactor `lib/main.dart`, `lib/app.dart`, and `lib/router.dart`; current startup opens ObjectBox and the global router too early.
- Ready-app tests and robots must pump the ready app with injected dependencies, catalog, and router. Startup tests pump the shell with a fake coordinator.

## Acceptance criteria

- [x] Render exactly the `checking`, `unavailable`, `unsupportedPlatform`, `initializing`, `initializationFailed`, and `ready` startup states. `checking` is non-interactive and no router or main map surface exists before `ready`.
- [x] On non-macOS, show a clear unsupported-platform state stating Peak Bagger requires macOS and expose `unsupported-platform-quit`; do not attempt a partial mode, root selector, bookmark, environment override, bundled-data mode, download, or repair.
- [x] On preflight failure, show title `Mapping data store unavailable`, root `/Volumes/Services/Mapping`, exact displayed path failures in a scrollable `mapping-store-unavailable-path-list`, and reachable `mapping-store-unavailable-retry` and `mapping-store-unavailable-quit` controls at increased text scale.
- [x] `Retry` reruns preflight against the same root without opening or clearing ObjectBox. A required catalog-geometry read failure after preflight closes attempt dependencies, returns to `unavailable`, and retry runs preflight then catalog construction.
- [x] After successful preflight/catalog construction, initialize ObjectBox, Local Topo, tile cache, repositories, map providers, and ready scope. A non-Mapping initialization failure reports diagnostic text with `startup-initialization-failed-quit`, closes every opened dependency including ObjectBox, and never becomes Mapping-store unavailable.
- [x] Retain unsandboxed macOS runtime behavior and do not bundle GDAL or PROJ libraries/data. The host GDAL library remains lazily evaluated by the elevation operation.
- [x] Add widget and robot coverage for unavailable startup, repair of the fake store, retry to ready app access, unsupported platform, initialization cleanup/failure, exact text/keys, scrolling, injectable quit, and no-router-before-ready behavior.

## Covers

- User Stories: 1, 2
- Requirements: 8, 13-14, 17
- Technical Decisions: 3
- Testing Strategy: 2, 4, 5, 8
- Interview Ledger: L2, L4, L7

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
