---
type: Work Item
title: Add Route-Graph Peak List CLI and macOS Launcher
parent: ../spec.md
---

## What to build

Add the testable standalone Dart CLI entry point under `tool/` and its root-level macOS shell launcher. Wire the launcher to Work Item 1's generation service with the exact argument, help, stdout/stderr, exit-code, repository-root, release-build, source-freshness, and shared-executable target-identity behavior.

## Required context

- `tool/slovenia_hribi_source_peak_list.dart` and `test/tool/slovenia_hribi_source_peak_list_tool_test.dart` demonstrate the injectable CLI runner, captured stdout/stderr, and shell argument-forwarding test style.
- `slovenia_hribi_source_peak_list.sh` builds a macOS Flutter target to the shared `peak_bagger` executable. This launcher must additionally record and compare the exact target entry point, because that executable path is shared by multiple tools.
- The service from `01-route-graph-peak-list-generation-service.md` owns source parsing, matching, CSV generation, and file replacement; keep this Work Item focused on invocation and launcher behavior.

## Acceptance criteria

- [x] Start with Flutter unit coverage under `test/tool/` for argument parsing, defaults, invalid invocations, help, supported-region listing, service invocation, stdout/stderr, and exit-code behavior.
- [x] Support only `--region <manifest-key>`, `--output <path>`, `--help`/`-h`, and no positional arguments. Normalize region keys case-insensitively and default an omitted `--region` to `tasmania`; report invalid syntax and unknown or unresolvable keys to stderr with exit `1`.
- [x] Make `--help` exit `0` without reading the peak source or writing a file. It must describe the command, all supported options, default `tasmania`, default peak source `~/Documents/Bushwalking/Features/peaks.csv`, default output convention, and every canonical manifest key that resolves to effective highway paths directly or through an ancestor.
- [x] On a successful generation, print the output path and matched-peak count to stdout and exit `0`; preserve the service's actionable failure behavior and exit `1` for failures.
- [x] Add a root-level shell launcher that does not use plain `dart run`, establishes the repository root before invoking either an injected or built executable, builds a release macOS Flutter executable when relevant sources are newer, and forwards every argument unchanged.
- [x] Record the exact Dart target used to build the shared macOS `peak_bagger` executable and rebuild when the recorded target differs from this launcher's target, even when the tool sources are not newer.
- [x] Cover shell execution from outside the repository root through an injected executable, including forwarded arguments and repository-root working directory. Cover a current source timestamp paired with a different recorded target causing a rebuild.
- [x] Verify the focused CLI suite with `flutter test test/tool/` and the completed change with `flutter test`.

## Covers

- User Stories: 1-3
- Requirements: 1-3
- Technical Decisions: 4
- Testing Strategy: 1
- Interview Ledger: L13, L15, L17

## Blocked by

01-route-graph-peak-list-generation-service.md
