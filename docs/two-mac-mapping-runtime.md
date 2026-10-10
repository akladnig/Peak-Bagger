# Two-Mac Mapping runtime: SMB access and offline planning

Peak Bagger requires the **Mapping data store** at exactly
`/Volumes/Services/Mapping` on both Macs. The mini uses its directly attached
Services volume; the MacBook mounts the mini's **Services** share over SMB.
Current offline support covers source editing and locally provisioned builds.
Independent offline app runtime is a separate follow-up.

This implements the documentation and inspection portion of
[Work Item 04](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/work-items/04-smb-runtime-access-and-offline-inventory.md),
following [the Spec and L3/L4](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/spec.md)
and the [Mapping data store contract](mapping-data-store.md).
**Live MacBook SMB access/startup remains pending administrator share setup.**

## Existing setup inspected — 2026-10-10

| Surface | Observation and role |
| --- | --- |
| Mini SSH | Existing `mini` alias reaches `MacMini` at `mac-mini.local` as `adrian`; SSH provides inspection/source transport, not an SMB mount |
| Mini volumes | `/Volumes/Services` is a local APFS mount (`/dev/disk5s3` at inspection); `Mapping` exists and the manifest-referenced files open for reading as `adrian` |
| Mini sharing | `/usr/sbin/sharing -l` lists only the public-folder share, **no Services share**; TCP 445 listens locally and is reachable from the MacBook, which alone does not prove share access |
| MacBook mounts | `mount` shows no Services mount; unrelated NAS Time Machine SMB access does not provide the Mapping root |
| Automounter | Both Macs' `/etc/auto_master` contain the standard home/fstab/static entries; no Services-specific map or `/etc/fstab` entry was found |
| Launch agents/daemons | Inspected user and `/Library` launch directories on both Macs; no Services sharing/mount job found; mini has no user `LaunchAgents` directory |
| Other automation | Both `~/.hammerspoon/init.lua` files contain editor/window/clipboard bindings, no sharing/mount actions; MacBook background/login registration inspected with `sfltool dumpbtm` contains no Services mount item |
| Administrative access | Mini `sudo -n /usr/sbin/sharing -l` reports a password is required; authenticated administrative share creation and SMB account enablement are pending |

No reusable Services mount automation was found in these inspected locations.
The selected setup is macOS File Sharing plus a Finder/Keychain-backed MacBook
mount, with a login item after the exact path has been verified. SSH credentials
do not authenticate an SMB session. Passwords belong in macOS authentication/
Keychain prompts, never URLs, shell arguments, docs or project artifacts.

## Publish and mount Services

### Mini: administrator setup

1. Verify `mount` still shows a **local** Services volume at `/Volumes/Services`,
   and `Mapping/region_manifest.json` and `Mapping/Polygons/manifest.json` are
   readable. An absent disk is a missing prerequisite; do not create a replacement
   directory under `/Volumes`.
2. In **System Settings → General → Sharing → File Sharing**, add
   `/Volumes/Services` with SMB share name **Services**, enable SMB in Options,
   and enable the intended existing account for Windows/SMB sharing. Authenticate
   in the system prompt. Grant that account read access to the Mapping files.
3. For the app's read-only access, publish the SMB share read-only and disable
   guest access. Direct mini maintainer access continues to use its local disk.
   The inspected `sharing` CLI supports the following equivalent share creation
   in a terminal **on the mini**, after confirming Services is not already shared:

   ```bash
   /usr/sbin/sharing -l
   # Only for an absent Services share, with the real disk mounted:
   sudo /usr/sbin/sharing -a /Volumes/Services -n Services -S Services -s 001 -g 000 -R 1
   /usr/sbin/sharing -l
   ```

   Account SMB enablement remains a system-settings step. If a Services share
   already exists, inspect its path/name/access rather than creating a duplicate
   or replacing unrelated share settings. Confirm the final record maps
   **Services → /Volumes/Services**, SMB enabled, guest disabled, read-only.

### MacBook: authenticated mount and path gate

1. Inspect `mount` and `/Volumes` first. Resolve any existing local/remote
   Services mount deliberately; stop apps using it before ejecting. A stale
   directory or another mounted Services volume can cause Finder to choose
   `Services-1`. Do not rename a live mount, add a symlink, or accept a suffix.
2. Use Finder **Go → Connect to Server** with `smb://mac-mini.local/Services`,
   or invoke the same UI:

   ```bash
   open 'smb://mac-mini.local/Services'
   ```

   Choose the enabled registered SMB account in the prompt. Save authentication
   in the MacBook Keychain if desired; no password is embedded in this address.
3. Inspect `mount` and verify the Services entry is **smbfs from the mini**
   mounted at **/Volumes/Services**. Then check both manifests:

   ```bash
   mount
   test -r /Volumes/Services/Mapping/region_manifest.json &&
     test -r /Volumes/Services/Mapping/Polygons/manifest.json
   ```

   These two checks alone are not full preflight; run the current-reference audit
   below and launch the app. `Services-1`, a mount of Mapping alone, a symlink or
   a mount at another root does not satisfy this setup.
4. After a successful mount, add the mounted Services volume to **General →
   Login Items & Extensions → Open at Login** on the MacBook if login mounting
   is wanted. Verify again after login and sleep/reconnect. A login item requests
   mounting; it is not a guarantee of network/disk availability or the exact path.
   If mounting fails, reconnect using Finder, recheck the mount, then use startup
   Retry. No project daemon or app-level fallback is required.

## Runtime startup and failure verification

`lib/main.dart` constructs `MappingDataStore()` at the fixed root.
`MappingStoreStartupCoordinator` in `lib/startup_shell.dart` first preflights
the manifest pair, checks existence/readability of **every region-manifest dataset
reference**, and loads required regional/basemap polygon geometry. Only then does
it call the initializer that prepares/opens the local ObjectBox store and
constructs the normal app. An existing ObjectBox database or geometry cache
does not bypass preflight. All three declared DEMs are required even though
Tasmania elevation sampling selects **ELVIS runtime DEM**.

After completing the SMB path gate:

1. Launch from the MacBook checkout using the locally provisioned configuration:
   `flutter run -d macos --no-pub --dart-define-from-file=dart_defines.local.json`.
   Record successful preflight, ObjectBox initialization and normal UI through
   the SMB mount. Also confirm mini direct-disk startup independently.
2. Quit the app before disconnecting/ejecting **only the MacBook SMB mount**.
   Relaunch with the existing local database present. Expect **Mapping data store
   unavailable**, affected paths, and **Retry / Quit** before normal UI.
3. Reconnect the same share at the exact path, use Retry and confirm normal UI.
   In a separate failed launch verify Quit exits. Do not delete/modify Mapping
   files or change share permissions to manufacture a failure.

Existing deterministic Test Seams check the contract without a live store:

```bash
flutter test --no-pub test/services/mapping_data_store_test.dart test/widget/startup_shell_test.dart --reporter expanded
```

These test manifest/path failures, required geometry, withheld ready UI, Retry
handoff and Quit callbacks. Filesystem injection supplies failure cases elsewhere
in the existing suite. Code inspection confirms preflight precedes database
initialization; deterministic tests are not evidence of an actual SMB launch.
`test/widget/mapping_store_failure_dialog_test.dart` covers the separate in-app
**Retry / Dismiss** flow, not startup **Retry / Quit**.

## Source synchronization and personal data

[The three configured Mutagen roots](two-mac-mutagen-bootstrap.md) are project
directories under `~/Development/mapping` and `/Volumes/Development/mapping`.
`/Volumes/Services/Mapping` is outside every session. Do not add a Services session,
copy Mapping into a project, or synchronize Docker/container state. Generated
Local Topo service payloads are excluded from the Peak Bagger session.

Each Mac keeps its own ObjectBox database under its application-support directory
(resolved by `lib/services/objectbox_store_directory.dart`); `data.mdb` and
`lock.mdb` are explicit Mutagen ignores even if found in a project. ObjectBox
model metadata/generated Dart source remain shared source. Personal settings,
GPX files and tile caches are not replicated by the project sessions.

## Measured runtime inventory

**Planning baseline from the Spec, measured before relocation: 25 files,
4,255,657,108 bytes (3.963 GiB).** Bytes are authoritative. The mini's current
manifest-derived set was remeasured read-only over SSH on 2026-10-10: all 25 files
opened for reading and every byte count below matched. This is direct mini access,
not an SMB validation or a guarantee that future manifests/files stay unchanged.

| Store-relative file | Bytes |
| --- | ---: |
| `region_manifest.json` | 12,819 |
| `Polygons/manifest.json` | 288 |
| `Polygons/italy-nord-est.poly` | 28,225 |
| `Polygons/friuli-venezia-giulia-mainland.poly` | 3,319 |
| `Polygons/friuli-venezia-giulia-islet.poly` | 127 |
| `Polygons/italy-nord-ovest.poly` | 15,515 |
| `Polygons/new-south-wales.poly` | 27,887 |
| `Polygons/slovenia.poly` | 10,462 |
| `Polygons/croatia.poly` | 17,654 |
| `Polygons/tasmania.poly` | 271 |
| `Peaks/tasmania-peaks.json` | 247,376 |
| `Peaks/new-south-wales-peaks.json` | 468,342 |
| `Peaks/italy-nord-est-peaks.json` | 2,520,279 |
| `Peaks/italy-nord-ovest-peaks.json` | 2,706,776 |
| `Peaks/slovenia-peaks.json` | 2,391,123 |
| `Peaks/croatia-peaks.json` | 2,758,502 |
| `Highways/tasmania-highways.json` | 223,487,946 |
| `Highways/friuli-venezia-giulia-highways.json` | 96,506,727 |
| `Highways/veneto-highways.json` | 123,275,043 |
| `Highways/slovenia-highways.json` | 706,365,113 |
| `Features/tasmania_natural_features.json` | 82,695,273 |
| `Maps/tasmap50k.csv` | 9,856 |
| `DEM/Elvis/elvis_runtime_10m.tif` | 2,322,234,062 |
| `DEM/tasmania_dem_25m.tif` | 284,292,791 |
| `DEM/cop30_hh.tif` | 405,581,332 |

### Validate this baseline against the Spec

Run from the repository root; this reads only the two documents:

```bash
python3 - <<'PY'
import pathlib
import re

def inventory(path):
    rows = re.findall(r'^\s*\| `([^`]+)` \| ([\d,]+) \|\s*$',
                      pathlib.Path(path).read_text(), re.MULTILINE)
    assert len(rows) == 25 and len({p for p, _ in rows}) == 25
    result = {p: int(n.replace(',', '')) for p, n in rows}
    assert sum(result.values()) == 4_255_657_108
    return result

baseline = inventory('docs/two-mac-mapping-runtime.md')
assert baseline == inventory(
    'ai_specs/peak-lists/0062-macbook-mini-mutagen-development/spec.md')
non_dem = sum(n for p, n in baseline.items() if not p.startswith('DEM/'))
small = sum(n for p, n in baseline.items()
            if not p.startswith(('DEM/', 'Highways/')))
assert non_dem == 1_243_548_923 and small == 93_914_094
print(f'{len(baseline)} files; {sum(baseline.values()):,} bytes; matches Spec')
print(f'Non-DEM: {non_dem:,} bytes; non-DEM/non-highway: {small:,} bytes')
PY
```

### Recheck current references before any future copy

Run this read-only audit **on the mini** against its attached disk, then on the
MacBook after mounting SMB. It measures the manifest-derived set, not whole
directories. It does not copy data or replace production parser/preflight checks:

```bash
python3 - <<'PY'
import json
import pathlib

root = pathlib.Path('/Volumes/Services/Mapping').resolve(strict=True)
manifest = json.loads((root / 'region_manifest.json').read_text())
paths = {'region_manifest.json', 'Polygons/manifest.json'}
paths.update(json.loads((root / 'Polygons/manifest.json').read_text()))
paths.update(manifest['demSources'].values())
paths.update(manifest[k]['catalog'] for k in ('tasmap', 'naturalFeatures'))
regions = [v for v in manifest.values() if isinstance(v, dict) and 'name' in v]
for region in regions:
    for key in ('poly', 'peaks', 'highways'):
        paths.update(region.get(key, []))
    for basemap in region.get('maps', []):
        paths.update(basemap.get('coveragePoly', []))
sizes = {}
for relative in sorted(paths):
    path = pathlib.PurePosixPath(relative)
    assert not path.is_absolute() and '..' not in path.parts, relative
    source = (root / relative).resolve(strict=True)
    assert source.is_relative_to(root) and source.is_file(), relative
    with source.open('rb'):
        pass
    sizes[relative] = source.stat().st_size
    print(f'{relative}\t{sizes[relative]}')
print(f'{len(sizes)} files; {sum(sizes.values()):,} bytes')
PY
```

Review additions/removals and changed sizes against the baseline before designing
a selective copy. Reinspect schema/reference fields if the manifest contract
changes; a historical hard-coded file list is not future source authority.

## Transfer feasibility and independent offline-runtime follow-up

| Planning set | Authoritative bytes | Approximate size |
| --- | ---: | --- |
| Complete 25-file runtime set | 4,255,657,108 | 3.963 GiB |
| All non-DEM files | 1,243,548,923 | 1.16 GiB |
| Excluding highways and DEMs | 93,914,094 | 89.6 MiB |

The MacBook had **approximately 120 GiB free at interview inspection**; a fresh
`df -h /` during this work reported approximately **132 GiB** available. The
complete set is practical to transfer given that capacity, subject to rechecking
free space, actual network throughput and current sizes. Transfer time has not
been benchmarked. The smaller subsets are planning options, **not runnable
startup sets while the omitted files remain declared**. Copying whole Mapping
directories includes unrelated maintainer data; the historical whole-directory
measurement was approximately **375 GiB**, not the 3.963 GiB app runtime set.

A separate approved independent-offline-runtime design must provide:

- A selective local Mapping copy at an accepted root, with ownership, refresh,
  stale-data and path-selection behavior defined. The currently accepted root is
  fixed; this work adds no configurable root, replica or automatic fallback.
- Offline basemap tiles for the intended regions/zoom levels and a local delivery
  option if Local Topo is needed. A **mini-only Local Topo HTTP service is
  unavailable while disconnected**; cached/prepared coverage needs its own design.
- Personal app data/settings and required GPX files on the MacBook, independent
  of the mini's separate ObjectBox store and source mirrors.
- Local **GDAL/PROJ** and their required data/native dependencies for elevation
  sampling, in addition to Flutter/build provisioning.

Raw ELVIS sources, **ELVIS topo DEM** (`elvis_topo` build derivative), raw theLIST
inputs, Overpass service data and Docker state are **not** part of this app
runtime inventory. Keep all three declared runtime DEMs in the required set;
removing declarations to shrink it requires a separate runtime-contract change.

## Verification status

Completed on 2026-10-10: mini direct APFS/readability and 25-file byte measurements;
SSH/SMB-port connectivity; sharing/automation inspection; baseline count/sum and
Spec equality; fixed-root/startup/database ordering and Mutagen-scope inspection;
existing Mapping/startup regression checks (**35 passed**); `flutter analyze
--no-pub` (**no issues**).

Both documented Python audit commands were executed successfully: baseline/Spec
equality and current mini reference/size equality. Full regression runs:
`caffeinate -i flutter test --no-pub --reporter expanded` — **2,173 passed,
5 skipped** (3m54s); `python3 -m unittest discover -s tool/tests -v` — **30 passed**.
Skipped Flutter tests remain unverified. `git diff --check` passed.

Pending: administrator publication of Services/account SMB enablement; MacBook
authentication and exact smbfs mount; online SMB preflight/normal UI; live
unavailable-store Retry/Quit and recovery with an existing local database;
mini direct-disk UI startup; login-item persistence/reconnect. A reachable SMB
port and readable files over SSH do not complete these environmental checks.
