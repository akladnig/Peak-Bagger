# Two-Mac local builds and provisioning

Work Item 01 of [the two-Mac Spec](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/spec.md)
prepares portable source dependencies and local builds. Real mini commissioning,
credential seeding, and the disconnected MacBook rebuild belong to Work Item 05.
The verification record below distinguishes completed checks from pending checks.

## Sibling layout and local artifacts

Use the existing roots; do not create substitute directories for an absent volume.
Set this in a **Bash** terminal on the machine being provisioned:

```bash
# MacBook
MAPPING_ROOT="$HOME/Development/mapping"
# Mini: use this assignment instead, after validating the attached volume
# MAPPING_ROOT="/Volumes/Development/mapping"

for project in peak_bagger trip_routing flutter_map_tile_caching; do
  test -f "$MAPPING_ROOT/$project/pubspec.yaml" || exit 1
done
```

Peak Bagger uses exactly `../trip_routing` and `../flutter_map_tile_caching`.
Resolve each checkout locally; `.dart_tool/package_config.json` must point to
that machine's siblings. Dependencies must not resolve through the external
development volume on the MacBook.

For Work Item 02, synchronize source, tests, assets, docs, required generated
Dart/ObjectBox model files, shared configuration examples, and relevant
lockfiles, including locally needed Git-ignored `pubspec.lock` files. Keep
`.dart_tool`, `build`, Flutter plugin metadata, platform dependency directories
(including examples), Xcode user state, SDK paths, and package caches local.
Git ignore rules alone do not configure Mutagen.

## Online provisioning on each Mac

1. Install Flutter **3.47.7** stable with its bundled Dart **3.13.5** outside all
   synchronized project roots. The observed framework revision is `abaf9c5237`.
   Use the Flutter SDK archive or that release's Git tag rather than upgrading
   dependencies during commissioning. Put this machine's SDK `bin` on `PATH`.
   The project requires Dart `^3.12.0`; a stale installation is insufficient.
2. Install full Xcode, select its developer directory, and complete first-launch
   setup/licensing and any macOS platform downloads **while online**. The
   verified MacBook has Xcode **27.0 / 27A266a**, macOS **27.0.1**, arm64.
   Install CocoaPods (MacBook **1.16.2**, mini **1.17.0**) with a working Ruby
   environment, and Python 3 for the configuration helper. Check `flutter --version`,
   `dart --version`, `xcodebuild -version`, `xcode-select -p`, `pod --version`,
   and `flutter doctor -v`. Android/iOS SDKs are only needed for those separate
   targets; their absence did not prevent the verified macOS build.
3. Save edits and stop running apps and code generators before relocation-cache
   cleanup. In each intended root, run the following while online. Do not copy
   dependency/build output from the other machine:

   ```bash
   flutter precache --macos
   for project in trip_routing flutter_map_tile_caching peak_bagger; do
     (cd "$MAPPING_ROOT/$project" && flutter clean && flutter pub get) || exit 1
   done
   ```

   `pub get` populates the local Pub cache and package configuration; it also
   resolves Flutter examples. Check any standalone nested package separately
   if it is used (FMTC's `tile_server` is not part of Peak Bagger's macOS build).
   Flutter may automatically edit older analysis options or generated platform
   files: inspect those source diffs rather than blindly syncing or committing.
   Preserve the agreed lockfiles so the two Macs resolve the same versions.
4. Recreate stale `macos/Pods` locally if retained from a previous path. With
   writers stopped, remove **only that generated dependency directory**, then
   perform the online build below. `flutter clean` regenerates `.dart_tool`,
   `build`, and `macos/Flutter/ephemeral` but should not be assumed to remove Pods.
   The build runs `pod install`, populates CocoaPods caches and local Pods, and
   installs/builds the Flutter macOS plugin dependencies. Keep `macos/Podfile`
   and `macos/Podfile.lock` shared; do not delete the lockfile to fix paths.
   ObjectBox uses CocoaPods fallback: `objectbox_flutter_libs` 5.3.2 does not
   support Swift Package Manager yet. Its warning is not a failed build.
5. Install FMTC's native **test** prerequisite separately, as described below.
   Configure/check the machine-local defines file, then run an online build of
   the exact target/mode that will later be rebuilt offline. This warms the SDK,
   Dart, CocoaPods, and Xcode artifacts actually required for that build.

GDAL/PROJ are separate runtime host dependencies, opened lazily for elevation
sampling. Provision them locally (for example with Homebrew `gdal` and `proj`)
if testing that runtime feature. Mapping datasets, Docker, and the mini's Local
Topo service are not required to compile this macOS app and are not provisioned
by package resolution. Full runtime still needs the accepted Mapping root.

### Pre-migration SDK checkpoint — 2026-10-11

Both Macs now report Flutter **3.47.7 / Dart 3.13.5**. The mini SDK is at
`~/develop/flutter`; CocoaPods **1.17.0** and Xcode **27.0** with completed
first-launch checks are available. Its independently installed FMTC test library
loads and reports ObjectBox C API **5.3.2**. Both existing local defines files pass
validation, and the shared example contains placeholder keys again.

MacBook provisioning/test/build results below were collected on **3.47.5 / Dart
3.13.4** and remain historical. Fresh post-migration local resolution, native
minimum checks, analysis/tests, both-Mac builds and disconnected recompilation on
3.47.7 remain pending. See the [current commissioning record](two-mac-commissioning.md).

For noninteractive commands on the mini, explicitly supply its installed tools:

```bash
export PATH="$HOME/develop/flutter/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

## ObjectBox treatment and readiness

**Keep Peak Bagger's tracked `lib/libobjectbox.dylib` synchronized.** It is a
source-workspace native dependency for Dart tools and Flutter-hosted tests,
not a live database or generated build output. Do not blanket-exclude dylibs.

Evidence gathered on 2026-10-10:

| Check | Evidence |
| --- | --- |
| Git ownership | `git ls-files lib/libobjectbox.dylib` lists the library |
| Architectures | `file` / `lipo -archs`: universal `x86_64 arm64` |
| C API / core version | Exported `obx_version_string`: `5.3.2`; `obx_version_core_string`: `5.3.2-2026-05-05 (lmdb, VectorSearch)` |
| SHA-256 | `1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751` |
| Dependencies | `otool -L`: `@rpath/libobjectbox.dylib`, system `libc++` and `libSystem`; no external development-volume dependency |
| Peak Bagger resolution | `objectbox`, `objectbox_flutter_libs`, `objectbox_generator`: **5.3.2** |
| Native minimum | Resolved `objectbox-5.3.2/lib/src/native/bindings/bindings.dart` requires C API **5.3.2** and core **5.3.2-2026-05-05** or newer |
| Flutter app provisioning | `objectbox_flutter_libs-5.3.2/macos/objectbox_flutter_libs.podspec` and the app Pod lock require **ObjectBox CocoaPod 5.3.0**; CocoaPod and C API versions are distinct |
| Built app framework | arm64 framework loads locally; C API **5.3.2**, core **5.3.2-next-2026-05-16 (lmdb, VectorSearch)**; `otool -L` confirms the plugin links `@rpath/ObjectBox.framework/Versions/A/ObjectBox` |
| FMTC standalone resolution | Its retained local lock resolves Dart ObjectBox packages **5.3.1**; its minimum C API is **5.3.0**, core **5.3.0-2026-03-23** |

ObjectBox's Dart loader first looks for linked process symbols; otherwise on
macOS it prefers the current directory's `lib/libobjectbox.dylib`, then fallback
locations including `/usr/local/lib`. Root-run Peak Bagger tests and Dart tools
use the tracked dylib. The built Flutter app links the locally installed
ObjectBox framework through the plugin/CocoaPods, rather than relying on the
checkout dylib at runtime. Existing non-skipped persistence tests verify the
tracked library against the resolved Dart API on the arm64 MacBook.

Before native tests, check the **specific** library rather than assuming a
global fallback is suitable. From Peak Bagger's root:

```bash
file lib/libobjectbox.dylib
lipo -archs lib/libobjectbox.dylib
otool -L lib/libobjectbox.dylib
python3 - <<'PY'
import ctypes
lib = ctypes.CDLL('lib/libobjectbox.dylib')
for name in ('obx_version_string', 'obx_version_core_string'):
    function = getattr(lib, name)
    function.restype = ctypes.c_char_p
    print(name, function().decode())
PY
```

Run the same checks on the mini in Work Item 05, including its actual host
architecture, dylib load, resolved Dart minima, native persistence tests, and
macOS build. Universal slices are compatibility evidence, not proof that an
uninspected mini is ready. Future ObjectBox upgrades must recheck these minima
and deliberately update the shared library if needed.

### FMTC's separate `test/lib/`

`flutter_map_tile_caching/test/general_test.dart` changes its working directory
to `test/` before opening ObjectBox. Neither Peak Bagger's tracked library nor
`pub get` supplies FMTC's expected `test/lib/libobjectbox.dylib`.

Install independently **on each Mac** from that machine's FMTC `test/` directory:

```bash
cd "$MAPPING_ROOT/flutter_map_tile_caching/test"
bash <(curl -fsSL https://raw.githubusercontent.com/objectbox/objectbox-c/v5.3.2/download.sh) --quiet 5.3.2
file lib/libobjectbox.dylib
lipo -archs lib/libobjectbox.dylib
```

This is the pinned C downloader underlying the Dart `install.sh` referenced by
the test; it installs release **5.3.2** locally without changing `/usr/local/lib`.
Check exported versions using the same Python readiness command above while
still in `test/`. The MacBook installation has the same universal slices,
versions, and SHA-256 as Peak Bagger's tracked library. Only after readiness:

```bash
cd "$MAPPING_ROOT/flutter_map_tile_caching"
flutter test --no-pub --reporter expanded
```

FMTC's session-relative **`/test/lib/` must be Mutagen-excluded** in Work Item 02
(already Git-ignored). The downloader also creates **`/test/download/`**;
designate that download/extraction staging directory machine-local and exclude
it too, or remove it after installation. Do not synchronize installed tests'
native dependencies. Keep generated model metadata/Dart source in scope.

## Machine-local API configuration

`dart_defines.example.json` is shared and retains `TRACESTRACK_API_KEY`,
`TRACESTRACK_REFERER`, and `MAPY_CZ_API_KEY` examples only. Create an absent local
file from the example with a private editor and enter the real values locally.
Do not replace an existing file automatically.

From the Peak Bagger root on either machine:

```bash
python3 tool/development_defines.py
```

The helper prints status only and exits nonzero for absent, unreadable, invalid
JSON, missing/empty fields, example key placeholders, non-HTTP(S) Referer, or a
symlink. It checks configuration shape, not whether a provider accepts the keys.
It never prints values or JSON parser exception text. Correct invalid existing
configuration deliberately in a private editor; an error is not permission to
overwrite it. Validation itself does not change a file or its permissions.

For Work Item 02, explicitly Mutagen-exclude both **`/dart_defines.local.json`**
and **`/.dart_defines.local.json.seed-*`** in Peak Bagger; both are Git-excluded.
The latter covers the helper's private temporary publication file. Do not use
shell tracing, verbose Flutter commands, command-line key values, or commit
generated defines/build output to collect diagnostics.

### One-time SSH seed in Work Item 05

First validate the existing mini root, the reviewed helper there, and the actual
SSH alias. The placeholder `MINI_SSH_ALIAS` below is not a discovered hostname.
Run from the MacBook Peak Bagger root after local validation succeeds:

```bash
python3 tool/development_defines.py &&
ssh -T MINI_SSH_ALIAS \
  'cd /Volumes/Development/mapping/peak_bagger && python3 tool/development_defines.py --receive' \
  < dart_defines.local.json
```

SSH encrypts stdin. No real value appears in the command or status output.
The receiver preserves a usable existing copy, reports an invalid existing
copy for deliberate correction, and seeds **only an absent file**, atomically
with mode `0600`. It also refuses to replace a file created concurrently.
Run the read-only validator on the mini afterward. Local edits never propagate
through ongoing synchronization. Actual SSH seeding has not been executed here.

## Analysis, tests, and build commands

Run from each named project's own root after local resolution:

```bash
# Peak Bagger and Trip Routing
flutter analyze --no-pub
flutter test --no-pub --reporter expanded

# FMTC: package scope; broad analysis also scans its example/tile_server
dart analyze lib test
flutter test --no-pub --reporter expanded
```

Existing ObjectBox tests with unconditional skips remain skipped, not passed.
For a focused Peak Bagger native/startup check, the exercised command is:

```bash
flutter test --no-pub --reporter expanded \
  test/services/objectbox_admin_repository_test.dart \
  test/services/route_graph_repository_test.dart \
  test/services/natural_feature_repository_test.dart \
  test/services/track_derived_data_persistence_test.dart \
  test/services/mapping_data_store_test.dart \
  test/widget/startup_shell_test.dart
python3 -m unittest tool.tests.test_development_defines
```

The exact macOS build command, from Peak Bagger's root, is:

```bash
flutter build macos --debug --no-pub --dart-define-from-file=dart_defines.local.json
```

This builds `build/macos/Build/Products/Debug/peak_bagger.app`. Keep the local
defines file available for the build. `--no-pub` avoids implicit package
resolution; it does not make missing SDK/CocoaPods artifacts available offline.

### Fully disconnected rebuild procedure (pending Work Item 05)

1. Complete the online provisioning and a successful build using the exact
   command above. Correct invalid local configuration deliberately before final
   commissioning. Retain the local SDK, Pub cache, `.dart_tool`, Pods/CocoaPods
   cache, ephemeral output, and build artifacts. Do not upgrade SDK/packages or
   run a clean/dependency installation as part of this cached rebuild check.
2. Save work and stop source writers. Confirm all dependency paths resolve to
   home-directory siblings. Disconnect/remove the external development drive
   and disable **all** network access (Wi-Fi, Ethernet, VPN/tethering), including
   access to the mini. Record those conditions; `--no-pub` alone is not evidence
   of disconnection.
3. Make a saved, disposable source change to an actually used UI string that
   requires recompilation. Record the path and diff without secrets. Run the
   exact build command above and record its exit/result and rebuilt artifact.
   Restore only the disposable change, preserving unrelated work.
4. Record pass/fail/pending in Work Item 05. If dependencies are missing,
   reconnect deliberately, provision them online, and repeat the disconnected
   check. Installing missing dependencies requires their normal network/source
   availability; a cached build is a different claim.

This proves offline source/build support, not full offline app runtime.
Startup still needs `/Volumes/Services/Mapping` and its complete preflight
contract; an existing ObjectBox database does not bypass it. The mini-only
Local Topo HTTP service is unreachable when disconnected.

## MacBook verification record — 2026-10-10

| Check | Result |
| --- | --- |
| Local cache recreation/provisioning | `flutter clean`, `flutter precache --macos`, and `flutter pub get` succeeded; `pub get` succeeded in both siblings and resolved FMTC's example |
| Portable package resolution | Fresh `.dart_tool/package_config.json` resolves both dependencies to `/Users/adrian/Development/mapping/` siblings; exactly two dependency sources changed |
| Peak Bagger / Trip Routing analysis | `flutter analyze --no-pub`: no issues in each |
| FMTC package analysis | `dart analyze lib test`: one existing `invalid_return_type_for_then` warning at `internal.dart:159`, one `parameter_assignments` info at `internal.dart:122`; nonzero, not a clean pass |
| FMTC broad analysis | `flutter analyze --no-pub`: 42 diagnostics including missing `dart_console`/`jaguar` resolution in standalone `tile_server` and example deprecations; not a clean pass |
| Native readiness | Both explicit libraries load on arm64 and report the recorded versions; FMTC native test library installed separately and Git-excluded |
| Trip Routing suite | 11 passed |
| FMTC suite | 59 passed, including native `general_test.dart` |
| Peak Bagger focused native/startup tests | 72 passed |
| Peak Bagger full suite | **2,173 passed, 5 skipped**, completed in 2m29s with `caffeinate -i flutter test --no-pub --reporter expanded`. Two earlier runs hit 120/600-second harness limits; the longer interrupted run reached 1,222 passes/2 skips and emitted shutdown errors on termination. The completed retry supersedes those incomplete results; skipped tests remain unverified |
| Credential helper | 7 disposable fake-configuration tests passed; existing MacBook configuration failed shape validation and was preserved. No values inspected in diagnostic output; deliberate correction pending |
| macOS debug build | Exact command above succeeded after local `pod install`, despite the configuration-shape failure. Compilation success does **not** prove all three keyed-basemap fields are usable |
| Upstream build warnings | ObjectBox SwiftPM fallback, geolocator CoreLocation deprecations, and always-run Flutter Assemble script; build succeeded |

### Commissioning handoff

- **Work Item 02:** retain the shared tracked dylib; explicitly exclude FMTC
  `/test/lib/` and installer `/test/download/`; exclude local defines and private
  seed temporaries; keep required lockfiles/generated source in scope.
- **Work Item 05 — pending:** actual mini SDK/package/native provisioning,
  architecture/version/load and tests/build confirmation; existing mini defines
  validation and absent-file SSH seed; deliberate MacBook defines correction;
  FMTC analyzer diagnostics disposition and existing skipped-test coverage;
  both-Mac resolution/build evidence; external-drive-absent, fully disconnected
  MacBook rebuild with a source-compilation probe.
- No real mini compatibility, credential seed, synchronization exclusion check,
  or fully disconnected rebuild has been marked passed by this work item.
