# Staged Docker migration to the Mini

This records the earlier staged Docker migration. For the selected two-Mac
development arrangement, keep Development and Services attached to the mini:
MacBook source uses its home-directory checkouts and Mapping runtime access uses
the Services SMB share. The historical drive-return step below is superseded by
[the Mutagen operations guide](two-mac-mutagen-operations.md) and
[the SMB runtime guide](two-mac-mapping-runtime.md). Live source commissioning
remains pending; Docker data migration is separate from source synchronization.

## Audited prerequisites (7 October 2026)

- Both Macs: Apple Silicon; Docker Desktop **4.94.0**, Engine **29.8.2**.
- Mini: SSH alias **`mini`** works; Apple Silicon; **48 GiB RAM**;
  approximately **831 GiB free internally** at the latest check; macOS **27.0.1**.
- Docker Desktop is installed and its engine responds on the Mini.
- Mini's `LocalHostName` is **`mac-mini`**; the script requires this target for
  `copy`, `restore`, and `start`. Its SSH alias remains **`mini`**.
- `/Volumes/Services` and `/Volumes/Development` share the same external 4 TB SSD.
- Docker's disk is `/Volumes/Services/docker/DockerDesktop/Docker.raw`.
  It occupies about **35 GiB**, with a logical size of approximately **460 GiB**.
- The running topo stack is
  `/Volumes/Development/mapping/peak_bagger/local_topo/tasmania` (about **4.3 GiB**).
- Its PostGIS named volume is inside `Docker.raw` (about **1.34 GB**).
- Overpass is currently stopped. Its bind-mounted databases occupy about
  **5.7 GiB** under `/Volumes/Services/Mapping/overpass-data`.

The script is `tool/migrate_docker_to_mini.sh`. Run it with Bash; it does not need
an executable bit. `preflight` and `verify` are read-only diagnostics. Other
commands print a plan unless `--execute` is supplied.

## 1. Prepare the Mini

Both Macs now have **Apple Silicon Docker Desktop 4.94.0** installed. Match
versions for the initial VM-disk restoration, and fully quit Docker Desktop on
the Mini before copying/restoring its disk.
The source VM currently has about **16 GiB RAM** allocated; the Mini has capacity
to use the same allocation. Docker Desktop's host settings are separate from
`Docker.raw`, so configure that allocation in the Mini's settings if desired.

Use its default internal disk-image location, or select another internal location
in Docker Desktop settings. The script reads the configured location without
editing Docker settings. It refuses to restore onto external storage and retains
any existing target VM disk under a timestamped backup name.

Read-only checks can be run from the MacBook:

```bash
bash tool/migrate_docker_to_mini.sh preflight
ssh mini /bin/bash -s -- preflight < tool/migrate_docker_to_mini.sh
```

## 2. Stop the source on the MacBook

```bash
bash tool/migrate_docker_to_mini.sh stop-source
bash tool/migrate_docker_to_mini.sh stop-source --execute
```

This stops **all running containers in the local Docker Desktop engine**, then
stops Docker Desktop. Close Peak Bagger, editors, terminals, and other applications
using the external drive. Eject the drive through macOS and attach it to the Mini.
Confirm the volumes mount as `/Volumes/Services` and `/Volumes/Development`.

The script cannot eject the drive safely on your behalf or physically transfer it.

## 3. Copy to the Mini's internal SSD

Run these commands **on the Mini**, in the external-drive repository:

```bash
bash tool/migrate_docker_to_mini.sh copy
bash tool/migrate_docker_to_mini.sh copy --execute
```

To execute from the MacBook after moving the drive, use SSH with the script's
absolute remote path:

```bash
ssh mini 'bash /Volumes/Development/mapping/peak_bagger/tool/migrate_docker_to_mini.sh copy --source-version 4.94.0 --execute'
```

The source volumes must actually be attached to the Mini. Merely running `copy`
in a MacBook terminal copies to the MacBook's SSD; the updated script refuses
that operation. If the Mini is renamed, confirm its `scutil --get LocalHostName`
and pass the new name with `--target-hostname` on subsequent commands.

The default internal bundle is `~/Services/peak-bagger`:

```text
peak-bagger/
  docker/Docker.raw
  topo/tasmania/       # Complete stack, including generated data and hidden files
  migration-version.txt
```

To include the stopped Overpass deployment, add `--with-overpass` to `copy`.
This adds `overpass/docker-compose.yml` and `overpass/overpass-data`; it does not
copy the complete 375 GiB Mapping directory or start Overpass.
The Overpass data copy disables rsync's special-file/device copying
(`--no-specials --no-devices`). Unix dispatcher sockets such as
`db/osm3s_osm_base` and FIFOs are runtime communication endpoints, not database
content; Overpass recreates its sockets when started. Trying to archive them with
macOS openrsync can produce `mkstempsock: Invalid argument` and exit 23.
Regular database files, directories, permissions, and symlinks are still copied.

Copying uses macOS's `rsync -aS --partial` to preserve sparse regions, permissions,
symlinks, and interrupted files for retry. It leaves all source files intact. It copies into a `.partial` bundle,
checks the VM disk's size and source modification timestamp, then marks the bundle
complete. These are completion checks, not full cryptographic verification.
The preflight now reserves the **full logical VM-disk size** plus the other
copied files and **10 GiB headroom**—roughly **475 GiB** for the current topo
bundle. The source's 35 GiB allocated size does not guarantee the destination or
rsync's temporary file will use the same space. The Mini's approximately 831 GiB
free space is sufficient; the MacBook's approximately 66 GiB is not. Actual final
allocation may be lower because of sparse copying; inspect the printed size.

A completed destination is never overwritten. After an interruption or failure,
rerun `copy` with the **same destination and options**. The script reuses the
existing `.partial` bundle, skips files whose size and modification time already
match, and recopies missing or changed files. An interrupted individual file may
be recopied from the beginning; this is not a guarantee of byte-offset resumption.
It does not delete existing staging files. The same conservative free-space check
still applies on retry. No new destination or manual rename is needed:

```bash
bash tool/migrate_docker_to_mini.sh copy --execute --with-overpass
```

Copy failures report the failed stage and exit status, and leave the bundle partial.
`restore` still refuses it until all requested copies and VM-disk checks succeed.
Use the same destination in every subsequent command.

## 4. Restore and start on the Mini

Keep Docker Desktop stopped during restoration:

```bash
bash tool/migrate_docker_to_mini.sh restore --execute
bash tool/migrate_docker_to_mini.sh start --execute
```

`restore` moves the staged VM disk into Docker's configured internal disk-image
location. A pre-existing disk is renamed as a backup. The staged disk therefore
does not occupy a second permanent copy after restoration.

`start` starts Docker Desktop and invokes the existing preview startup script
from the internal stack copy. It keeps Compose project name **`tasmania`** to reuse
the restored PostGIS volume, and recreates the four topo containers so their bind
mounts use the internal copy. It uses the existing default Martin-backed preview
configuration and port **8090**. The script does not pull updated images explicitly.
Restored Overpass containers have their target restart policies disabled and are
stopped: their old `unless-stopped` policies could otherwise restart them when
Docker launches. If needed later, start Overpass deliberately from its copied
Compose definition, which specifies the original restart policy.

The host does not need Node/npm for this startup command; the gateway runs Node
inside its container. Rebuilding datasets has additional host prerequisites and
DEM input paths that must be configured separately.

Verification checks all four containers are running, rejects bind mounts under
`/Volumes`, and requests capabilities plus sample topo, relief, and contour tiles.
You can rerun it with:

```bash
bash tool/migrate_docker_to_mini.sh verify
```

If needed, the script's `--source-disk`, `--source-topo`, and `--source-mapping`
options accommodate different external mount names. `--source-version` must match
the Docker Desktop version that last used the source VM disk.

## 5. Return the drive and test from the MacBook

Close applications using the external drive on the Mini, eject it, and reconnect
it to the MacBook. Keep the MacBook's Docker Desktop stopped.

From the MacBook:

```bash
curl --fail http://mini.local:8090/capabilities
```

Use the Mini's actual LAN hostname/IP if `mini.local` does not resolve. The SSH
alias `mini` does not automatically make `mini` an HTTP-resolvable hostname.

In Peak Bagger settings, save the Mini's URL in **Local tile server base URL**.
Test map rendering and the relief/contour overlays. Rerun server verification
after the drive has been detached from the Mini to demonstrate storage independence.

Peak Bagger still directly requires `/Volumes/Services/Mapping` on the MacBook.
Returning the drive preserves that access for this first stage. Before permanently
moving the drive to the Mini, resolve the MacBook's Mapping-store and source-code
access separately.

## Follow-up and rollback

- Configure Docker Desktop startup and topo restart policies for always-on service.
- Keep the source VM disk and data as the fallback until the Mini is proven.
- The source copy becomes stale once the Mini accepts data changes; rollback must
  account for those changes before starting the source again.
- The script keeps Overpass stopped and does not diagnose its prior exit code 137.
- Later external-storage relocation should use Docker Desktop's supported disk
  location setting and separately update/recreate the topo bind mounts.

Docker documents whole-VM restoration at:
<https://docs.docker.com/desktop/settings-and-maintenance/backup-and-restore/>.

## Script verification

```bash
/bin/bash -n tool/migrate_docker_to_mini.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s tool/tests -p 'test_docker_mini_migration.py' -v
```

The checks cover an actual sparse fixture-bundle copy, hidden/generated file
retention, retrying empty/legacy partial bundles, an injected Overpass-copy failure
followed by a same-destination retry, unsafe partial-path rejection, refusal to
overwrite a completed bundle, copying databases while skipping real Unix sockets
and FIFOs, wrong-host rejection, and budgeting a sparse VM disk
by its logical size. Fixture-copy checks skip on a Mac with Docker Desktop running.
These checks do not perform production VM restoration or service cutover.

At the 2026-10-11 PR checkpoint, the current **12 Docker migration fixture tests**
passed as part of the full **30-test** operational Python suite. Both shell scripts
passed Bash syntax checks. This does not establish a new production migration.

After the wrong-host and space-budget fixes, all **eight tests passed on the
MacBook**. On the Mini, **seven passed and one skipped** because Docker Desktop
was running; the skipped check performs the fixture-bundle copy.

## Failed MacBook copy

An initial copy attempt ran on the MacBook and exhausted its internal free space.
The old script checked only that the destination was internal; it did not enforce
the target Mac and estimated space from source allocation. Both checks are fixed.
rsync removed its failed temporary VM disk. The inspected
`~/Services/peak-bagger.partial` directory on the MacBook was empty (0 bytes), and
the original external-drive VM disk remained intact.

### Correct retry sequence

1. Fully quit Docker Desktop on the Mini. Docker on the MacBook was already
   stopped at the time of the failed-copy audit; keep it stopped.
2. Close applications using the external drive, eject it from the MacBook, and
   attach it to the Mini.
3. Confirm `/Volumes/Services` and `/Volumes/Development` are mounted on the Mini.
4. From a MacBook terminal, execute the copy on the Mini over SSH:

   ```bash
   ssh mini 'bash /Volumes/Development/mapping/peak_bagger/tool/migrate_docker_to_mini.sh copy --source-version 4.94.0 --execute'
   ```

This writes to the **Mini's** `/Users/adrian/Services/peak-bagger`. Do not rerun
the original `copy --execute` command locally on the MacBook; the updated script
rejects that operation. The Mini has enough space for the conservative copy
budget. Once copying succeeds, continue with **Restore and start on the Mini**.
