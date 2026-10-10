---
type: Work Item
title: Prepare portable dependencies and machine-local build configuration
parent: ../spec.md
---

## What to build

Make Peak Bagger's package resolution independent of the external development volume by using relative sibling paths. Inspect its tracked ObjectBox native library and document the chosen synchronization or machine-local provisioning treatment. Prepare reproducible online provisioning and local build/test instructions for both Macs, including machine-local API-key configuration and the later offline rebuild check.

This item prepares source changes, MacBook build readiness, and provisioning instructions. Real mini provisioning, one-time credential seeding, both-Mac compatibility confirmation, and the fully disconnected MacBook rebuild are completed in Work Item 05.

## Required context

- Read the parent Spec and `../interview-ledger.md`, especially L4, L5, and L7.
- MacBook siblings live under `~/Development/mapping/`; mini siblings live under `/Volumes/Development/mapping/`. Both layouts must preserve the three project names.
- `pubspec.yaml` currently declares `/Volumes/Development/mapping/trip_routing` and `/Volumes/Development/mapping/flutter_map_tile_caching`.
- Inspect `lib/libobjectbox.dylib`, its consumers, package/native-library versions, and architecture support before deciding its treatment. Record evidence rather than removing it or blanket-excluding native libraries.
- `../flutter_map_tile_caching/test/general_test.dart`, relative to the Peak Bagger project root, documents a separate ObjectBox installation into that package's `test/lib/`. Package resolution alone does not provide those libraries.
- `.gitignore` already excludes `/dart_defines.local.json`; `dart_defines.example.json` contains the three required field examples. Do not read or print real key values into diagnostics or workflow artifacts.
- Current caches may refer to pre-relocation paths. Recreate stale Flutter/Xcode caches locally rather than copying dependency/build output between machines.

## Acceptance criteria

- [x] Peak Bagger declares exactly `../trip_routing` and `../flutter_map_tile_caching` for its two path dependencies; package resolution from the MacBook checkout resolves to its home-directory siblings.
- [x] Local package resolution, appropriate Flutter/Dart analysis, existing relevant tests, and a macOS build are exercised on the MacBook with results recorded. Native-library readiness is checked before relevant ObjectBox tests run; environmental gaps are explicitly pending.
- [x] The tracked Peak Bagger dylib's role, version/architecture compatibility evidence, and chosen synchronized or locally provisioned treatment are documented. Any unverified mini compatibility is a named commissioning check for Work Item 05.
- [x] Online provisioning instructions cover locally installed SDK artifacts, Dart packages, platform/native dependencies, and FMTC's separate ObjectBox test libraries under session-relative `test/lib/` on each Mac. Installed test libraries are designated machine-local for Work Item 02's exclusions.
- [x] `dart_defines.local.json` remains Git-excluded and is designated Mutagen-excluded. Instructions validate configuration without revealing values, securely seed an absent mini file once over SSH, preserve an existing usable copy, and report an invalid existing copy for deliberate correction instead of automatically overwriting it.
- [x] The synchronized example retains `TRACESTRACK_API_KEY`, `TRACESTRACK_REFERER`, and `MAPY_CZ_API_KEY` examples without real credentials.
- [x] Instructions record the exact build command, including use of the local defines file where needed, and the online provisioning needed to reproduce Work Item 05's MacBook offline rebuild. They distinguish cached/provisioned offline builds from installing missing dependencies.
- [x] Mini verification and the external-drive-absent, fully disconnected rebuild remain explicitly pending until exercised in Work Item 05; offline source/build support is not presented as full offline app runtime.

## Covers

- User Stories: 1, 5.
- Requirements — Workspace layout and initial migration: 4 (local dependency/build-output preparation).
- Requirements — Local builds and API-key configuration: 1–5 (source changes, provisioning instructions, MacBook checks; mini execution and final offline evidence in Work Item 05).
- Testing Strategy: package resolution, analysis/tests/builds and ObjectBox readiness; online provisioning and preparation for the MacBook offline rebuild.
- Interview Ledger: L4, L5, L7.

## Blocked by

None - ready to start

## Implementation and verification — 2026-10-10

Completed this preparation slice. Detailed commands, native-library evidence,
online provisioning, credential handling, and commissioning handoff are in
[`docs/two-mac-local-builds.md`](../../../../docs/two-mac-local-builds.md).

- `pubspec.yaml` now declares the exact relative paths. Fresh local package
  resolution points to `/Users/adrian/Development/mapping/` siblings.
- Retain/synchronize the tracked universal x86_64/arm64 ObjectBox dylib: it
  exports C API 5.3.2/core 5.3.2-2026-05-05 and satisfies the resolved Dart
  package minima. The locally built app's linked framework also loads and
  exports the required C API; actual mini compatibility remains pending.
- Provisioned FMTC's separate native test library locally under `test/lib/`;
  checked architecture/load/version before its tests. Work Item 02 must exclude
  that directory and the installer's machine-local `test/download/` staging.
- Peak Bagger and Trip Routing `flutter analyze --no-pub`: no issues. FMTC's
  package analysis reports one existing warning and one info; broad analysis
  additionally finds unresolved standalone tile-server dependencies/example
  diagnostics. These are recorded, not presented as a clean analyzer pass.
- Peak Bagger full suite: **2,173 passed, 5 skipped** with
  `caffeinate -i flutter test --no-pub --reporter expanded`; earlier harness
  timeouts were superseded by this completed retry. Focused native/startup
  tests: **72 passed**. Trip Routing: **11 passed**. FMTC: **59 passed**.
- Added status-only `tool/development_defines.py` validation and absent-only,
  atomic mode-0600 SSH-stdin receiving, with **7 passing fake-configuration
  tests**. Existing valid/invalid copies are preserved. Git excludes both the
  local defines file and private seed temporaries; their explicit Mutagen
  exclusion is designated for Work Item 02. The shared example is unchanged.
- `flutter build macos --debug --no-pub --dart-define-from-file=dart_defines.local.json`
  succeeded after local cache regeneration and `pod install`.

### Explicit pending checks for Work Item 05

- The existing MacBook defines file failed shape validation and was preserved
  without value disclosure; deliberate correction is needed before final
  keyed-basemap commissioning. Compilation success is not a credential check.
- Actual mini provisioning, version/architecture/native-test/build compatibility,
  local configuration validation/absent-file SSH seed, and real synchronization
  exclusion verification.
- External-development-drive-absent, fully disconnected MacBook recompilation
  using a saved disposable source change. No offline build or full offline
  runtime success is claimed here.
- Disposition of FMTC's existing analyzer diagnostics and existing skipped-test
  coverage; all evidence must stay explicit in the commissioning record.
