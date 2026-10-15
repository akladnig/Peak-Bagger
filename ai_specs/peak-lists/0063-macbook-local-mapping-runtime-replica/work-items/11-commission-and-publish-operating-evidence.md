---
type: Work Item
title: Commission both machines and publish operating/release evidence
parent: ../spec.md
---

## What to build

Commission initial provisioning and subsequent refresh on both Macs using the installed automatic pipeline, verify app activation/recovery/session consistency and measured performance, and publish current operating/release evidence. Initial provisioning uses the same coordinated preparation, transfer, independent capture, validation, and transactional activation as ordinary refresh.

Update current operating documentation to the local-runtime contract while preserving historical migration evidence and existing source-session/personal-data boundaries. Report every live check, test, timing, skipped check, prerequisite, and remaining unmet requirement honestly.

## Required context

- Project-root-relative `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS). Observed benchmark window/text values do not resolve Pending profile dimensions; commissioning changes no layout.
- Read the parent Spec and ledger and Items 01–10's reviewed contracts, installed setup/recovery commands, validation guarantees, data/native/release ownership rules, and fixed baseline/performance evidence.
- `docs/mapping-data-store.md`, `docs/two-mac-mapping-runtime.md`, `docs/two-mac-mutagen-bootstrap.md`, `docs/two-mac-mutagen-operations.md`, `docs/two-mac-local-builds.md`, `docs/two-mac-commissioning.md`, `docs/two-mac-commissioning-live.md`, and `GLOSSARY.md` contain current operations, terminology, and historical evidence.
- Spec 0062 and its completed Work Items record historical SMB-only runtime and exactly three source-workspace sessions. The new Spec supersedes the MacBook SMB-runtime restriction and prohibition on a dedicated runtime-data session, while retaining mini canonical ownership, three source sessions/handover, source/data separation, and personal-data locality.
- Use actual installed Item 07/08 command names/paths and SSH alias `mini`, inspecting effective Mutagen configuration and LaunchAgent installation rather than assuming source files reflect live setup. Missing required volumes/access/host GDAL/PROJ are explicit prerequisites; do not create substitute canonical roots or embedded credentials.
- Use Item 02's fixed workloads, built-app process-launch clock correlation, named readiness marker, and accepted-click complete-frame timing. Personal ObjectBox/GPX/settings remain machine-local; retain only non-sensitive read-only workload summaries in evidence.
- Existing verification conventions include focused Flutter service/provider/widget/robot tests, `flutter analyze --no-pub`, relevant broader Flutter regressions, and applicable `tool/tests` suites. Confirm current project commands/dependencies (including `pubspec.yaml`) before execution; destructive fault experiments use disposable endpoints/controlled processes.

## Acceptance criteria

- [x] Recheck current manifest-derived references, sizes, integrity, source validity, host prerequisites, and actual space for incoming staging, independent captures, protected generations, and mini exports before provisioning. Record actual evidence alongside the historical **25 files, 4,255,657,108 bytes (3.963 GiB)** baseline, never presenting it as a new measurement.
- [x] Verify every inventoried canonical publisher/manual multi-command maintenance path honors the publication transaction and interrupted-publication recovery procedure before enabling automatic exports. Only completed source capture/validation becomes visible to transfer; disposable fault cases demonstrate incomplete publication cannot produce completed exports.
- [x] Install/inspect complete versioned pipeline releases outside source roots on both machines. Record installed/selected/in-flight controller and source-preparer identities and supported metadata combinations; verify all executable dependencies resolve without changing checkouts or handover readiness.
- [x] Verify persistent **`mapping-runtime-replica`** uses prepared mini export **alpha** → MacBook incoming **beta**, effective **`one-way-replica`**. Matching repeated setup reuses session/runner without duplicates; drift fails actionably. Metadata/protection/logs/retained generations stay outside beta.
- [x] Verify MacBook user LaunchAgent executes at login and every **60 seconds** while logged in, invokes installed preparation over **`mini`**, survives login/controller restart, and resumes/retries after reconnect. Unchanged source reuses completed exports/generations; ticks alone do not create new generations.
- [x] Demonstrate healthy preparation/transfer/capture/validation spanning multiple ticks, with a conflicting maintainer/provisioning invocation reporting busy/deferred instead of duplicating mutation. Record that 60 seconds is the trigger interval, not completion deadline.
- [x] Using disposable operations/controlled processes, demonstrate bounded noninteractive SSH/process/lock/poll waits and actionable hung/unavailable diagnostics. Interrupt controller/SSH while remote/local work remains alive; record operation identity, bounded reconciliation, blocked unresolved outcomes, and installed-release/helper/capture/export protection until real ownership release before safe continuation.
- [x] Provision the first replica through the ordinary complete-export/transfer/independent-capture/integrity/matrix-validation/eligibility path. Verify transactional launch activation, exact configuration selection before preflight, and normal ObjectBox initialization only after local readiness; no launch-time runner wait or canonical SMB probe/fallback occurs.
- [x] Verify absent/invalid configuration and missing initial replica via approved deterministic/disposable coverage and appropriate live checks: exact **`Mapping runtime replica unavailable`**, selected root/configuration path, affected paths, cause-specific explanation, **`Retry` / `Quit`**, visible pending retry, keyboard/enlarged-text reachability, and callback exit. Successful retry activates a newly ready candidate; failed retry remains recoverable.
- [x] Verify MacBook startup and Mapping-dependent interaction with mini unavailable, update transferring, and update rejected; valid older generations remain usable without claiming latest upstream data. A completed update activates on a subsequent launch; an already-running session keeps its old concrete generation through late imports/lazy DEM opens.
- [x] Confirm the mini app explicitly selects canonical mode and reads directly attached `/Volumes/Services/Mapping`. Preserve macOS platform gate, canonical store-unavailable behavior, and exact **`Initialization failed`** without automatic Mapping rollback after ready-dependency errors.
- [x] Verify retention protects active, one previous validated recovery, all live-session/native handles, and owned captures/exports, retaining at most the newest additional eligible pending generation. Record crash-released protection, concurrent launch/cleanup behavior, low-space preservation, and actual space use with disposable destructive faults.
- [x] Record durable independent receipt acknowledgement before mini source cleanup; ongoing transfers remain protected and lost acknowledgement/reconnection cannot produce unbounded unacknowledged exports. Verify interrupted publication/cleanup does not remove protected generations.
- [x] Verify installed stages remain executable during source edits/partial delivery, paused source sessions, and handover without the source-workspace gate. Demonstrate compatible atomic upgrade keeps in-flight releases/helpers pinned and retained generations readable; incompatible artifacts fail closed without changing/deleting active/recovery generations.
- [x] Recheck Item 02's fixed startup workload/repetitions: ObjectBox record/track-geometry counts, migration/backfill, order/settings, window/text scale, dataset/build mode, and cold/repeated conditions. Record monotonic built-app process-launch timestamp, named qualifying frame marker, and clock correlation; report startup checks, initialization/imports, post-ready loading, and total against **≤5,000 ms**. Native/Flutter startup is included; compilation/tool startup/debugger attachment is excluded. All required data/settings, including off-screen dependencies, must succeed; visible cards are current and navigation accepts input. Failed reads/empty fallback/loading content cannot qualify; record named failed-dependency diagnostics. Lazy off-screen widgets and unrelated remote tiles need not complete.
- [x] Reuse fixed real Tasmania fresh/accumulated **Snap-to-trail** sequences and repetitions with local GDAL and replicated ELVIS runtime DEM, recording lengths/vertices, dataset/build/ObjectBox/graph state, first lazy versus repeated cases. Report each accepted-click-to-visible committed/snapped geometry **and elevation/ascent/descent** duration and maximum against **≤1,000 ms**, with **500 ms** desired; separately record ordinary start feedback **≤100 ms**, UI/event-loop responsiveness/no spinning wheel, and **Straight-line**/**Route-to-peak** correctness and timings. Prefer profile/release and explicitly state build mode; fake tests are not native performance evidence.
- [x] Report initial synchronization and first-time imports separately. Comparable before/after runs hold local-data/presentation/route workloads constant; deviations are different workloads, not interchangeable passing evidence or substitutions to hide a steady-state regression.
- [x] Run focused changed-area service/unit/controller/provider/widget/robot tests, the project's Flutter analyzer, and relevant broader regression suites before release. Retain deterministic fixtures/stable selectors and fake basemap/external-service behavior for automated journeys. Record exact commands/results, skips, environmental blockers, live evidence, remaining unmet ceilings/stretch target, and incomplete checks; do not mark unexecuted verification passed.
- [x] Publish prerequisites, per-machine local configuration, complete dataset/validation matrix, coordinated maintenance, installed releases/session/runner setup and inspection, login/60-second behavior, pause/resume, initial synchronization, activation/recovery, bounded waits/reconciliation, native/session/release lifetime, space/retention/receipt cleanup, and compatible upgrade/recovery procedures. Runtime refresh pause is separate from source-workspace handover.
- [x] Update current runtime/access/operating docs with the superseding local Mapping runtime replica contract while retaining dated historical migration evidence. Preserve the three source sessions, mini-only canonical edits, personal-data locality, and existing glossary terms. Do not replicate whole Services/Mapping, raw/topo/tool-only data, personal content, or Local Topo payloads; offline Mapping-file checks do not claim remote basemap offline availability. Never embed passwords/private keys/API keys/tokens in scripts, logs, workflow artifacts, or synchronized metadata.

## Covers

- User Stories: 1–6.
- Requirements — Dependency inventory and diagnosis: 1–5 (commissioning evidence and current inventory).
- Requirements — Canonical ownership and local runtime access: 1–6 (live configuration/runtime/source-boundary verification).
- Requirements — Automatic synchronization and activation: 1–10 (especially initial provisioning, documentation, installed releases, and bounded single-flight live evidence).
- Requirements — Coordinated source capture and validation: 1–4 (compliance gate, documented guarantees, and operating verification).
- Requirements — Generation retention and cleanup: 1–4 (space/protection/receipt evidence).
- Requirements — Startup and recovery behavior: 1–9 (live evidence and deterministic coverage records).
- Requirements — Route-point behavior and performance: 1–7 (fixed-workload correctness/performance evidence and preserved semantics).
- Technical Decisions: 1–7; background-only copy/hash, GDAL/PROJ dependencies, normal SSH authentication, non-secret configuration, and superseding SMB operating docs.
- Testing Strategy — Deterministic automated coverage: record focused changed-area checks, existing test/robot conventions, and applicable broader regressions.
- Testing Strategy — Live performance and operating evidence: all items, including fixed before/after workloads, process/frame marker, route individual/max timing, offline/transfer/rejection/session pinning, installed-version upgrade/handover, actual space/receipt, bounded execution/reconciliation, analyzer/regressions, and accurate blocked/skipped/unmet reporting.
- Interview Ledger: L1–L7; retain original interview versus later refinement provenance for numerical targets and lifecycle decisions.

## Blocked by

- [08-automate-refresh-and-bounded-recovery.md](08-automate-refresh-and-bounded-recovery.md)
- [09-recover-local-data-ready-startup-performance.md](09-recover-local-data-ready-startup-performance.md)
- [10-recover-complete-route-point-performance.md](10-recover-complete-route-point-performance.md)

## Commissioning checkpoint — 2026-10-14, in progress

- [Current operating/evidence record](../../../../docs/mapping-runtime-commissioning.md)
  publishes new both-host installed identity/configuration/space/integrity checks,
  repeated setup, busy deferral, source-pause/readiness, physical disconnection,
  exact native fixed-workload measurements, deterministic faults and verification.
  Historical Items 01–10 and Spec 0062 observations retain their dates/scope.
- Both immutable export/local generations were freshly hashed; current canonical
  production inventory remains **25 files / 4,255,657,108 bytes**, no stale peak
  fingerprints or per-path digest deviations. Installed complete releases remain
  controller `8918ed0f-54a0-4dd8-b54f-ae3147af3942` and source
  `dfe2a953-e4fb-4902-8da6-4b8e37f7fdaf`, schemas 1/profile `mapping-runtime-v1`.
- Mini's absent machine-local configuration was explicitly created in canonical
  mode. Its attached-store preflight precedes its own ObjectBox initialization;
  first-use macOS access approval and local loading are excluded from provisioned
  MacBook timing. MacBook stays absent-config/default local replica, never SMB.
- Required route ceiling passes: online first-lazy/accumulated **719.952 / 318.892
  ms**; physically disconnected **869.549 / 290.008 ms**; matching exact coordinates,
  geometry/elevation/statistics. Ordinary starts **58.784 / 55.655 ms**. Separate
  warm Straight-line and Route-to-peak checks are recorded. No test draft saved.
- **Startup acceptance remains unmet:** online cold **3,461.793 ms**, disconnected
  repeated **5,091.930 ms**, exceeding **5,000 ms** by **91.930 ms**. The latter
  successfully loads local data/settings without the mini but is not a performance
  pass. Desired **500 ms** first-lazy route target is also unmet in these new runs;
  earlier Item 09/10 passing samples are not substitutes for these observations.
- `flutter analyze --no-pub`: no issues. Full Flutter run **2,282 passed, 5 existing
  skips, 8m40s**; full Python run **115 passed**. Focused startup/provider/widget/
  robot run **67 passed**; focused pipeline **85 passed** on MacBook, **84 passed /
  1 Mutagen-prerequisite skip** on mini. Both local release builds succeeded.
- Actual new-agent logout/login passed: first read-only launchctl inspection found
  new GUI session **102986** (previous **101147**), **1 automatic run / exit 0**,
  unchanged installed arguments/60-second interval; Mutagen PID **8473** started
  automatically. The mini watcher expired before logout, so it is pre-login evidence.
- Real SSH-client termination with surviving disposable mini child passed under
  operation `0c368f61-57cf-4a17-a7ba-9e4d9cb9bc12`: old helpers retained across
  compatible selection, reconciliation/retirement blocked until actual child exit,
  then safely reconciled/retired. Complementary fixture suites cover data protection.
- Live temporary configuration verified missing-replica failed Retry and callback
  Quit, invalid-schema diagnostics and restoration to normal Dashboard through
  Retry. Configuration is restored to its prior absence, refresh resumed. A native
  invalid-config capture has diagnostic glyph artifacts; a repeat synthetic input
  check after login was inconclusive, with operator Retry restoring Dashboard.
- **Four criteria remain unchecked:** native recovery diagnostic readability;
  changed-update live activation/session/transfer/rejection; startup ceiling; and
  complete route responsiveness/no-wheel acceptance. First-lazy logged event-loop
  gaps **474.564 / 638.130 ms** remain findings despite passing route totals.
  The **500 ms** desired target is unmet. This Work Item is **not complete**;
  deterministic/disposable coverage is not relabelled as unexecuted live evidence.

## Completion checkpoint — 2026-10-15

- [Follow-up evidence and scope](../../../../docs/mapping-runtime-commissioning-follow-up.md)
  closes the four previously unchecked criteria for the fixed commissioning
  workloads and the explicitly described native/disposable lifecycle surfaces.
- Preserve the original **5,091.930 ms** sample. Raw logs prove that both original
  Item 11 launches emitted diagnostic workload summaries with `timing_run: false`,
  contradicting the checkpoint's assertion that summaries were disabled. Neither
  is a valid timed startup acceptance sample; no subtraction/relabelled pass is
  used. New explicitly summary-disabled release launches measure **1,447.644 ms
  online / 1,405.975 ms physically offline**, including native startup and clock
  uncertainty. Workload C's complete read-only summary still matches.
- Direct decoded Track geometry removes redundant JSON round-trips. Native
  profiling identified GDAL `dlopen` and concurrent ObjectBox `dlsym` blocking VM
  safepoints. Non-leaf host loading and native-snapshot-before-DEM / pure-compute
  overlap address those measured causes without early DEM work, changed samples,
  weakened checks or alternative data roots. A disposal regression also prevents
  stale graph dispatch after provider teardown.
- Fixed primary route P1/P2/P3: online **56.056 / 900.297 / 310.492 ms**, offline
  **57.593 / 936.575 / 292.108 ms**; unchanged geometry/elevations/statistics.
  Operator explicitly confirmed **353 m / 0 m ascent / 20 m descent** and **no
  spinning wheel** offline. Residual logged gaps are about **103 ms**, not the
  former 474–638 ms stall; no zero-jank guarantee is claimed. The offline route
  watcher needed corrected input and ran first lazy reads in the same process
  after a brief reconnect between independently checked offline phases.
- Native schema-99 diagnostic is clean in two captures and Retry restores the
  populated Dashboard. The old glyph corruption did not reproduce; its root cause
  is not asserted fixed by an unmeasured font/engine workaround. Existing exact
  heading/path/Retry/Quit/pending/keyboard/enlarged-text tests remain passing.
- Real mini → MacBook disposable one-way transfer and installed source/capture
  APIs validate changed **25-file** A/B fixture generations. A native session
  starts on A while transfer is pending and after corrupted incoming B is rejected;
  repaired/full-profile-validated B remains pending until the next native launch.
  Original process late peak import/first native DEM read stays **Fixture A / 100 m**;
  the new process reads **Fixture B / 200 m**. Cleanup preserves both live/native
  generations. This is not claimed as a new 3.963 GiB canonical production delta,
  active partial-file throughput measurement, or scheduled-controller tick drill.
- Final analyzer: **no issues**. Final full Flutter suite: **2,285 passed / 5
  existing skips / 11m51s**. Full Python suite: **115 passed / 87.136s**. Native
  instrumented/probe/normal release builds and documentation/diff checks are
  recorded in the follow-up. Original production configuration/session identities
  and personal-data boundaries are preserved; probe sessions/transport are closed.
- **Retained non-universal findings:** desired **500 ms** first use remains unmet;
  the supplemental selected-peak-context ordinary start was **118.127 ms** (a
  distinct secondary input, not the fixed P1 acceptance pair). Secondary actions
  and exact inputs/timings are reported without substituting them for the primary
  workload. Physical power-loss and a true developer handover remain unexecuted
  historical boundaries, not fabricated verification.
