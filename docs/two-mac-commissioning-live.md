# Two-Mac live commissioning — 2026-10-11

This is the latest execution evidence for [Work Item 05](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/work-items/05-commission-and-verify-two-mac-workspace.md),
superseding the historical checks in the [commissioning record](two-mac-commissioning.md).
**Completed:** migration, live synchronization, both-Mac tests/builds, fully
disconnected MacBook recompilation and actual logout/login passed. All Work Item
05 acceptance criteria are satisfied. Final readiness releases development to the
selected **MacBook**; mini writers remain stopped until a subsequent handover.

## Freeze and verified recovery

The operator confirmed all edits saved and other source writers stopped across
**all three projects on both Macs**, selecting **MacBook** as receiver. Freeze
checkpoint: **2026-10-11T06:33:03Z**. Only migration/provisioning/disposable
verification writes occurred through seeding, baseline, activation and the first
successful three-session readiness check. Mini ordinary development has not begun.

Fresh preflight passed strict/noninteractive SSH both ways, exact physical writable
roots, attached mini APFS Development volume, all three owner Git destinations,
Mutagen **0.18.1**, both usable existing private defines, matching Flutter
**3.47.7 / Dart 3.13.5**, mini Xcode **27.0 / 27A266a** first-launch completion and
CocoaPods. MacBook Peak Bagger was clean on `main` at **c0828c4**, mini at
**b38ad9a** with modified/untracked work. Trip Routing remained clean at **7491846**;
FMTC at **022bbe0** with matching four tracked modifications. All staged diffs
were empty. Current commits, refs, stashes and untracked inventories were inspected.

**Retain the private mini recovery folder:**

```text
/Users/adrian/MigrationBackups/mapping-20261011T063303Z/
  peak_bagger/
  trip_routing/
  flutter_map_tile_caching/
```

Each project contains a full `ditto` **`worktree/`** snapshot (including local
credentials, ignored/untracked content and Git/index metadata), **`all-refs.bundle`**,
status/log/ref/stash inventories, binary staged/unstaged patches,
`verification.json`, and the relocated **`original-dot-git/`**. This mode-private
location is outside every sync root. Approximately **721 GiB** was available on
mini internal storage for approximately **15 GiB** of project snapshots. These
private backups must not be published as source or issue evidence.

- All bundles passed `git bundle verify`.
- Complete snapshot/original path/content/type/executable/symlink manifests
  matched: **125,852 / 175 / 490 entries** for Peak Bagger/Trip Routing/FMTC.
- Copied Git refs, stashes, status, binary diffs and staged/index-visible state
  matched recorded originals; originals were rechecked before relocation.
- All **15 / 5 / 30** mini ref objects respectively exist on the owner; Peak
  Bagger's three stash IDs match the owner inventory. FMTC binary diffs match.
- Mini Peak Bagger's modified `run_local_maps.sh`, untracked migration docs and
  `tool/tests/test_docker_mini_migration.py` differ from current owner versions.
  They remain recoverable for deliberate review rather than automatic merging.
  Its other listed untracked files match the owner. No mini-only in-scope path
  was present; disposable regression coverage still verifies stale-file removal.
- Only after all three backups verified were original root `.git` directories
  moved into `original-dot-git/`. No mini mirror retains root Git metadata.

## Seeding, session identities and live probes

Executed the reviewed sequence under the same freeze:

```bash
python3 tool/mutagen_workspace.py seed --project peak_bagger --writers-stopped --mini-work-preserved
python3 tool/mutagen_workspace.py seed --project trip_routing --writers-stopped --mini-work-preserved
python3 tool/mutagen_workspace.py seed --project flutter_map_tile_caching --writers-stopped --mini-work-preserved
python3 tool/mutagen_workspace.py baseline
python3 tool/mutagen_workspace.py setup-paused
python3 tool/mutagen_workspace.py setup-paused
python3 tool/mutagen_workspace.py activate --writers-stopped
python3 tool/mutagen_workspace.py ready --writers-stopped
```

**PASS:** complete baselines matched at **2,039 / 36 / 380 entries**, including
SHA-256 contents, types, executable bits and symlink targets. Temporary one-way
bootstrap sessions retired only after verification. Second setup reused all IDs;
activation and the first three-project readiness check passed.

| Session | Persistent ID |
| --- | --- |
| `mapping-peak-bagger` | `sync_uhAjaUqlb5jeMKsCPt25SkiTzEDdek58rrwnojpAAGJ` |
| `mapping-trip-routing` | `sync_EMJKn9D065aLABqmobB624yhqhGMVX8tvHVDZI6kKk8` |
| `mapping-flutter-map-tile-caching` | `sync_MfAmzzirsHHfeywLyLXfFjk4YBKc0xm6v8HlgFbPrO4` |

Exactly these three sessions use committed identities, exact roots, SSH beta,
`two-way-safe` and ordered exclusions. No bootstrap/duplicate sessions remain.

- **PASS:** each real SSH session propagated a uniquely named disposable source
  MacBook-to-mini, a mini edit back, and deletion. Cleanup and baselines verified.
- **PASS:** all pre-seed excluded content remained unchanged immediately after
  seeding: **115,785 / 21 / 65 entries** respectively, excluding deliberately
  relocated root `.git`. Credentials, databases, service payloads and native
  test libraries survived. Local caches were later recreated deliberately.
- **PASS:** independent fake sentinels from each endpoint did not propagate for
  `.git` pointer content, private-defines basename, live-database basenames,
  build/Dart/cache directories, Local Topo input/output/runtime, or FMTC test
  libraries/installer staging. Real keys/databases/libraries were not probe-edited.
  All owned sentinels were removed; Git remains only on MacBook roots.
- **PASS:** mini-initiated owner readiness reports all three READY; read-only Git
  resolves each exact home-directory owner checkout. A background mini watcher
  observed the physical MacBook outage: owner SSH Git **exit 255 for all three**,
  with every mini root `.git` absent and no fallback created.
- **PASS:** real readiness succeeds for all three under freeze and fails naming
  every project during the physical outage. The rerun disposable SSH Git suite
  verifies pre-commit/file-replacement gates, failed-member prevention, post-checks
  and explicit conflict recovery. User work was not reset to demonstrate these.

## Login registration and operational regression

**PASS, limited:** native `daemon register` installed valid
`~/Library/LaunchAgents/io.mutagen.mutagen.plist`. `launchctl print` showed
`/opt/homebrew/bin/mutagen daemon run` running with KeepAlive. Initial registration
hit an asynchronous-stop race; verified the old daemon had exited before retrying.
A real launch-agent `kickstart -k` retained all recorded IDs/configuration and
passed readiness. Mini runs only matching remote agents, not another controller.

**PASS:** operator completed actual MacBook logout/login. Before invoking any
Mutagen start command, `launchctl print` showed the automatically started job
running as PID **91788**, new GUI login session **101147**, with three remote SSH
agents. Recorded session IDs and effective configurations were unchanged;
`setup-paused` reused all three without changing their active state, and all-three
readiness passed locally and via mini-initiated reverse SSH.
Pre-logout checkpoint: launch job running as PID **85650**, GUI domain **501** /
session **100002**; all three recorded sessions READY, and evidence changes saved
and synchronized. The new GUI session/PID above establish the actual login cycle.

Registration exposed a regression-fixture bug: macOS Mutagen registered
`daemon start/stop` select launchctl independently of `MUTAGEN_DATA_DIRECTORY`.
Disposable fixture startup and its SSH-wrapper restart now directly own a
foreground daemon, wait for its private socket and stop only that process.
Final full suite with real registration enabled: **30 tests passed in 21.334s**.
Ruff passed. Earlier failed attempts are superseded, not counted as passes.
Real IDs/configurations/readiness remained intact after the successful suite.

## Both-Mac local provisioning, tests and builds

Each Mac ran `flutter precache --macos`, then locally ran `flutter clean` and
`flutter pub get --enforce-lockfile` in Trip Routing, FMTC and Peak Bagger. FMTC's
example resolved too. Stale mini `macos/Pods` was preserved as
`peak_bagger/relocated-Pods/` in the recovery folder before fresh installation.
Package configurations point to the respective exact siblings; no dependency or
build caches were copied between machines.

On each arm64 Mac, Peak Bagger's tracked dylib and FMTC's separately installed
`test/lib/` dylib both load, have universal x86_64/arm64 slices, export C API
**5.3.2** and core **5.3.2-2026-05-05**, and have SHA-256
`1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751`.
These satisfy freshly resolved Peak Bagger **5.3.2** and FMTC **5.3.1** native
minimums; full suites exercise native persistence. Keep the tracked library shared
and installed test libraries excluded. Both valid existing private defines were
preserved; no absent-file seed was necessary. No credential values were disclosed.

| Verification | MacBook | Mini |
| --- | --- | --- |
| Trip Routing `flutter analyze --no-pub` | **PASS**, no issues | **PASS**, no issues |
| Trip Routing full Flutter suite | **11 passed** | **11 passed** |
| FMTC `dart analyze lib test` | **Exit 2:** existing warning + info | **Exit 2:** same warning + info |
| FMTC full suite, native prerequisite checked first | **59 passed** | **59 passed** |
| Peak Bagger `flutter analyze --no-pub` | **PASS**, no issues | **PASS**, no issues |
| Peak Bagger full suite | **2,173 passed, 5 skipped**, 175.7s | **2,173 passed, 5 skipped**, 79.4s |
| Peak Bagger macOS debug build | **PASS**, 38.6s | **PASS**, 60.4s |

All full suites used `caffeinate -i flutter test --no-pub --reporter expanded`.
Builds used `flutter build macos --debug --no-pub --dart-define-from-file=dart_defines.local.json`.
Skips remain unverified. FMTC's `invalid_return_type_for_then` warning at
`internal.dart:159` and `parameter_assignments` info at `internal.dart:122` are
unchanged pre-existing diagnostics for separate maintenance; neither analyzer
run is a clean pass. Flutter doctor's missing Android/web/iOS-simulator targets
do not affect exercised macOS targets. ObjectBox SwiftPM fallback and upstream
native warnings remain in build logs.

Reviewed and reverted incidental Flutter analysis-option migrations and mini
CocoaPods checksum/version-only shared-lockfile changes, preserving agreed
dependency versions and the original four FMTC modifications. MacBook's agreed
lockfile also supported the offline builds below.

Private logs/outcomes: MacBook temporary
`$(getconf DARWIN_USER_TEMP_DIR)opencode/commission-macbook-20261011/`; mini
`~/MigrationBackups/mapping-20261011T063303Z/commission-evidence/`. Temporary
verification runners remain outside source roots, not installed workflow tooling.

## Fully disconnected source recompilation and reconnect

**PASS: 2026-10-11T07:28:56Z–07:29:50Z.** Following online provisioning/builds,
the operator disabled Wi-Fi/Ethernet/VPN/tethering and ran the local runner.
Before/after both builds it confirmed no configured IPv4/IPv6 network states,
no active network links, failed external IPv4/IPv6 TCP attempts, unavailable mini
SSH and absent `/Volumes/Development`. The operator additionally reported
`ping 8.8.8.8`: **No route to host**, 100% packet loss.

First two attempts stopped before source writes because the runner initially
expected different `scutil` wording and rejected a retained default route. The
successful check uses actual network state/link/reachability evidence; raw
route/interface diagnostics remain private. No earlier attempt is a build pass.

Saved `.commission-offline-20261011.txt` edits in all three owner roots stayed
local during the outage. Every real session reported disconnected mini endpoints
and **NOT READY**, naming all projects and preventing handover/Git readiness.

While still disconnected, the runner changed the used `lib/startup_shell.dart`
title from `Peak Bagger` to `Peak Bagger [offline commissioning 20261011]` and ran:

```bash
flutter build macos --debug --no-pub --dart-define-from-file=dart_defines.local.json
```

**Exit 0.** Built `flutter_assets/kernel_blob.bin` contains the unique title and
has a changed SHA-256, proving recompilation. Restored only the disposable change,
repeated that exact offline build **exit 0**, and confirmed the compiled marker
was absent. Source has no remaining probe diff; caches were retained for rebuilding.

After reconnection, direct mini reads verified all saved offline edits arrived
**automatically before any manual flush/resume**. Native status showed the same
IDs connected/scanned/watching with successful cycles, no conflicts/problems.
Removed the probes on MacBook, confirmed removal on both endpoints, and passed
all-three readiness and full matching baselines.

This proves offline source/build support, not full-app offline startup. Work Item
04's completed online SMB startup/inventory evidence is integrated in the parent
record. No Mapping replica, personal-data sync or runtime-root change was made.

## Final readiness and handover release

**PASS: 2026-10-11T07:42:19Z checkpoint.** After the operator's actual logout/login,
automatic startup, stored IDs and exact effective configuration verified. Both
local and mini-initiated all-three `ready --writers-stopped` checks passed with
no pending changes, conflicts, connection errors or other problems. Full baselines
matched at **2,040 / 36 / 380 entries** (one additional Peak Bagger commissioning
document). Both SSH directions and all owner Git destinations still work; original
mini Git backups remain outside roots, mirror `.git` and disposable probes remain
absent, local defines still validate, and both exact SMB Mapping manifests are
readable after login.

The operator's agreed freeze held through these checks. **Development is released
only to the selected MacBook.** Outgoing mini writers remain stopped. All required
commissioning gates are complete; a later switch to the mini uses the ordinary
both-Mac/all-project freeze and all-three readiness procedure in the
[operations guide](two-mac-mutagen-operations.md). Preserve the private backups
until their differing old versions have been deliberately reviewed.

Existing skipped tests, FMTC analyzer diagnostics and Work Item 04's optional
physical SMB failure/recovery/direct-mini-UI demonstrations remain explicitly
unverified follow-ups, not additional requirements passed by this commissioning.
