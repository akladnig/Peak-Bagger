---
type: Work Item
title: Background Job Settings Refresh
parent: ../spec.md
---

## What to build

Expose the Natural Feature refresh service through an app provider and the existing in-app Background job flow. Add the import-classified `refreshNaturalFeatures` job kind, preserve the one-running-job contract, and add the macOS Settings action immediately below `Refresh Peak Data`.

The action title must be `Refresh Natural Features`; its subtitle must be `Import Tasmanian natural features from the local source file`; and activation must start immediately without a confirmation dialog. It is a macOS-only unsandboxed maintainer-build workflow with no file picker or configuration UI. Retain existing Background job progress, Settings maintenance busy-state, already-running feedback, and responsive navigation behavior. Do not add OS-level background execution or user cancellation.

## Required context

- `lib/providers/background_jobs_provider.dart` owns the one-running-job and interrupted-job recovery contracts.
- `lib/screens/settings_screen.dart` contains the existing Settings maintenance action order and busy state.
- `02-deterministic-natural-feature-refresh.md` provides the refresh runner and result/count contracts.
- Extend existing Background job and Settings test harnesses rather than creating standalone test infrastructure.

## Acceptance criteria

- [x] `refreshNaturalFeatures` is an import-classified Background job kind and an interrupted job of this kind recovers with exactly `Natural feature refresh cancelled when app was closed`.
- [x] `Refresh Natural Features` appears immediately below `Refresh Peak Data` with exactly the required subtitle and starts the refresh immediately without confirmation.
- [x] While the job runs, its progress indicator is shown and competing Settings maintenance actions are disabled through the existing busy-state behavior; navigation remains responsive.
- [x] When another Background job is running, the refresh does not start, the existing already-running feedback is retained, and persisted Natural Features remain unchanged.
- [x] A successful refresh reports exactly `Natural features refreshed: {created} created, {updated} updated, {protected} protected, {skipped} skipped.` using the service's ordered count classification.
- [x] Refresh failures show an error dialog and a status beginning exactly `Error refreshing natural features:` without changing persisted Natural Features.
- [x] Focused widget or robot coverage verifies tile order, immediate handoff, existing-job refusal, busy state, interrupted-job recovery, exact success feedback, failure feedback, and responsive navigation while the job runs.
- [ ] Run the ObjectBox schema guard, targeted Background job and Settings widget or robot tests, `flutter analyze`, and the full `flutter test` suite.

## Covers

- User Stories: 1
- Requirements: 4, 14
- Technical Decisions: 2
- Testing Strategy: 4, 6
- Interview Ledger: L3, L7, L11

## Blocked by

- `02-deterministic-natural-feature-refresh.md`
