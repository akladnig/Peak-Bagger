# Two-Mac Mutagen configuration and safe bootstrap

This is the configuration/bootstrap procedure for [Work Item 02](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/work-items/02-repeatable-mutagen-configuration-and-safe-bootstrap.md).
Live migration, login registration and session activation have now been executed
in **Work Item 05**; see the [live record](two-mac-commissioning-live.md) for
passed checks, including actual logout/login and final readiness. The disposable
verification below exercises the procedure separately.
Use [local build provisioning](two-mac-local-builds.md) for SDKs, native libraries
and private defines. The MacBook owns Git; the mini becomes a working-file mirror.
For ongoing development use the [handover, SSH Git and conflict-recovery
guide](two-mac-mutagen-operations.md).

At the **2026-10-11 prerequisite checkpoint**, the mini Development volume and all
three roots pass preflight, and both SSH directions are verified. Earlier missing
volume/SSH observations below are historical. See the
[current commissioning record](two-mac-commissioning.md) for evidence and remaining
live migration/verification gates. The checkpoint was subsequently superseded by
the live execution record; exactly three ordinary sessions are now active.

## Persistent configuration and effective roots

`tool/mutagen-workspace.json` is the inspectable, version-controlled configuration.
`tool/mutagen_workspace.py` translates it into explicit native Mutagen CLI options;
it does not use experimental `mutagen project start`, which would not provide the
required configuration-drift checks. Run commands here from the **MacBook Peak
Bagger checkout** with Python 3 and the inspected **Mutagen 0.18.1** on PATH.

| Session name | Alpha: MacBook Git checkout | Beta: mini SSH mirror |
| --- | --- | --- |
| `mapping-peak-bagger` | `/Users/adrian/Development/mapping/peak_bagger` | `mini:/Volumes/Development/mapping/peak_bagger` |
| `mapping-trip-routing` | `/Users/adrian/Development/mapping/trip_routing` | `mini:/Volumes/Development/mapping/trip_routing` |
| `mapping-flutter-map-tile-caching` | `/Users/adrian/Development/mapping/flutter_map_tile_caching` | `mini:/Volumes/Development/mapping/flutter_map_tile_caching` |

The alpha parent expands from `~/Development/mapping` using the controlling
MacBook user's home. All ordinary sessions use **`two-way-safe`**. Session labels
`mapping-project=<project>` record project identity. Global `~/.mutagen.yml`
defaults are explicitly disabled when creating sessions so they cannot silently
change this scope. Mutagen stores session definitions and reconciliation history
in its own `~/.mutagen` data directory; keep that state local to the MacBook and
do not edit it by hand. Configuration is read only when creating a session.

The existing `~/.ssh/config` supplies **`mini`**, resolving to `mac-mini.local`
as user `adrian`. A noninteractive SSH hostname probe reached `MacMini` on
2026-10-10. Credentials remain in the existing SSH configuration/keychain; they
are not in the workspace config. Recheck after relocation:

```bash
ssh -G mini
ssh -T -o BatchMode=yes -o ConnectTimeout=8 mini hostname
python3 tool/mutagen_workspace.py inspect
python3 tool/mutagen_workspace.py preflight
```

`preflight` requires existing pubspecs, physical endpoint paths, and an attached
Development volume on a different filesystem from the mini's startup volume.
It creates no directories. An unavailable SSH endpoint, absent volume, missing
project or substituted/symlink root is a setup failure. The actual mini
Development volume was **absent during the initial disposable verification**;
preflight correctly failed with the project/root identified. Live commissioning
now validates the attached volume and all three exact roots.
Reverse SSH for mini-initiated Git is covered by Work Item 03/05.

## Source and machine-local boundary

Mutagen never reads `.gitignore`. The ordered rules in the JSON were reviewed
against Peak Bagger (including macOS and Local Topo), Trip Routing's source
example, FMTC, its Flutter Android/Windows example and standalone `tile_server`.

- `.git` is a basename exclusion for **both directories and worktree metadata
  files**, at every depth. Other VCS metadata is excluded too.
- Dart/Pub/Flutter dependency caches, build/coverage output, plugin metadata,
  Python caches/virtual environments, `node_modules`, platform dependencies and
  ephemeral output are excluded at roots and nested examples. Android local SDK
  and signing paths, iOS generated machine-path configuration, Xcode user state,
  Gradle/Swift caches and editor swap/temp/log/PID files stay local. SDKs should
  be installed outside all three source roots.
- `data.mdb`, `lock.mdb`, `dart_defines.local.json`, private seed temporaries and
  signing keys are excluded at any depth. ObjectBox generated Dart and model
  JSON **remain shared**. Peak Bagger's tracked universal
  `lib/libobjectbox.dylib` **remains shared**, following Work Item 01's inspected
  treatment. No blanket native-library or generated-source exclusion is used.
- FMTC's session-relative `/test/lib` and `/test/download` exclude its separately
  installed native test library and installer staging. They do not exclude Peak
  Bagger's shared `lib/`, or examples' source `lib/` directories.
- Local Topo's `input/*`, `output/*`, `runtime/*` payloads are excluded, then each
  direct `.gitignore` placeholder is re-included. Their parent directories must
  **not** be excluded: Mutagen does not traverse an ignored directory. `.tmp-*`
  test-output trees stay local. Sources, scripts, configuration, styles, fonts,
  sprites, fixtures and tests remain shared.
- The inspected Git-ignored bulk DEM/spreadsheet artifacts under Peak Bagger's
  `assets/` are local outputs, explicitly excluded by path; UI assets remain
  shared. No general `assets`/`doc`/JSON exclusion is used.
- Workflow documents, documentation, shared editor configuration, tests,
  `dart_defines.example.json`, `pubspec.lock` (including Git-ignored package
  locks), example lockfiles, `Podfile.lock`, `package-lock.json` and required
  generated source remain shared. Git's library lockfile policy does not define
  this development-workspace policy. Gradle wrapper/project files remain source.

These sessions cover only the three named projects. `/Volumes/Services/Mapping`,
other projects, Docker/container state and personal application data are outside
the roots. Generated service payloads inside Local Topo are excluded. A backup
must also be outside **every** synchronization root.

## MacBook login startup and persisted-session inspection

Mutagen 0.18.1 provides `daemon register` on macOS (marked experimental). It writes
`~/Library/LaunchAgents/io.mutagen.mutagen.plist`, using the executable's resolved
path and `KeepAlive`. Registration requires the daemon to be stopped. During
commissioning, with writers frozen and existing sessions inspected:

```bash
mutagen version
mutagen sync list --long
mutagen daemon stop
# Wait for the stopped daemon to exit before registration; stop can return early.
mutagen daemon register
mutagen daemon start
plutil -lint "$HOME/Library/LaunchAgents/io.mutagen.mutagen.plist"
launchctl print "gui/$(id -u)/io.mutagen.mutagen"
mutagen sync list --long
```

After logout/login, inspect the same session IDs/configurations and run the
three-session readiness check below. Session persistence is provided by the
daemon's stored state, not by creating new sessions on login. After changing
the installed executable path/version, stop and inspect registration, re-register
deliberately if required, and reverify the CLI/API before updating the pinned
version. Do not register a second controller on the mini. The mini needs Remote
Login enabled, SSH authentication, Python 3 for baseline hashing and Mutagen's
automatically deployed matching **remote agent** (normally under `~/.mutagen`).

Login registration, launch-agent restart/persistent IDs, actual logout/login and
post-login readiness passed Work Item 05. Disposable tests own a
foreground `mutagen daemon run` process with a private data directory and do not
use registered `daemon start/stop`, which on macOS select the user's launch job
regardless of that data-directory override. They register no launch agent.

## Recoverable bootstrap: preserve first, then reconcile

### 1. Establish the source-write freeze on both Macs

Save all editor buffers in **all three projects on both machines**. Stop agents,
auto-save/refactoring tasks, formatters, code generators, watchers and other
source writers. Stop apps/tests/services if needed for a coherent private-data
backup. Record who is responsible for each endpoint and the freeze start time.
Do not make ordinary development edits on the mini during setup.

**The freeze lasts through final inspection/reconciliation, seeding, matching
baseline verification, bidirectional activation and the first successful
three-session flush/status check.** Migration commands may write source during
this freeze. There is no new distributed locking system: command flags are an
operator attestation, not a mechanism that stops processes. On failure keep
writers stopped; investigate/recover before restarting ordinary development.

Inspect any existing sessions and pause only the identified project session IDs
before preservation. Do not seed over a conflicted or drifted session.

### 2. Inspect unique mini work before changing files or Git metadata

On the mini, run read-only Git inventory for each existing checkout and preserve
the outputs privately. Use a new backup directory on its internal disk, for
example `~/MigrationBackups/mapping-<timestamp>`; verify available space first.
Do not put it inside `~/Development/mapping` or `/Volumes/Development/mapping`.
The following commands are in a **Bash** terminal on the mini after preflight:

```bash
ROOT=/Volumes/Development/mapping
BACKUP="$HOME/MigrationBackups/mapping-$(date +%Y%m%d-%H%M%S)"
umask 077
mkdir -p "$BACKUP"
for project in peak_bagger trip_routing flutter_map_tile_caching; do
  checkout="$ROOT/$project"
  recovery="$BACKUP/$project"
  mkdir "$recovery" || exit 1
  git -C "$checkout" status --porcelain=v1 --untracked-files=all > "$recovery/status.txt" || exit 1
  git -C "$checkout" log --all --oneline --decorate > "$recovery/log.txt" || exit 1
  git -C "$checkout" for-each-ref > "$recovery/refs.txt" || exit 1
  git -C "$checkout" stash list > "$recovery/stashes.txt" || exit 1
  git -C "$checkout" diff --binary > "$recovery/unstaged.patch" || exit 1
  git -C "$checkout" diff --cached --binary > "$recovery/staged.patch" || exit 1
  git -C "$checkout" rev-parse --absolute-git-dir --git-common-dir > "$recovery/git-locations.txt" || exit 1
  git -C "$checkout" bundle create "$recovery/all-refs.bundle" --all || exit 1
  git -C "$checkout" bundle verify "$recovery/all-refs.bundle" || exit 1
  ditto "$checkout" "$recovery/worktree" || exit 1
done
```

The full private `ditto` snapshot includes staged/unstaged/untracked files and
local credentials/outputs: allow sufficient space and never attach it to issue
logs or a source session. For a genuinely empty Git repository, bundle creation
has no refs to include; record that fact and verify the complete worktree/metadata
snapshot instead of treating a failed bundle as success. If a project is already
a mirror with no `.git`, review its source snapshot and session history rather
than running Git commands in an ancestor repository.

Compare branches/commit IDs with the **MacBook** inventory using `git log`,
`for-each-ref`, and bundle inspection in a separate recovery checkout. Inspect
stashes, both diffs and the untracked inventory. Decide explicitly which mini
work is unique and how to recover it. Either retain it in these backups or
deliberately reconcile it into the MacBook baseline **before** final seeding.
Do not merely save a patch: patches omit untracked files, private refs and
uncommitted binary/index context. Verify recovery by inspecting selected files,
refs, stash and diffs from the backup. Do not print private config contents.

For a worktree `.git` **file**, additionally copy the referenced Git directory
and common Git directory reported in `git-locations.txt` to the private backup.
A file pointing at shared metadata is not a self-contained backup. Preserve
these before moving the pointer; do not move shared common metadata still needed
by unrelated worktrees. If referenced metadata lies inside any sync root, move
or reconcile it outside that scope deliberately before proceeding.

### 3. Move mini Git metadata outside every synchronization root

Only after inspection and verified preservation, on the mini:

```bash
for project in peak_bagger trip_routing flutter_map_tile_caching; do
  test ! -e "$BACKUP/$project/original-dot-git" || exit 1
  mv "$ROOT/$project/.git" "$BACKUP/$project/original-dot-git" || exit 1
done
```

This moves a directory or worktree pointer file, never deletes it. Check that
the mini roots have no active `.git` and do not recreate repositories there.
Nested Git metadata remains explicitly excluded and machine-local; review any
nested checkouts separately before migration. The MacBook metadata stays intact.

### 4. Seed the agreed MacBook baseline, including stale-source removal

After preservation and deliberate reconciliation, from the MacBook:

```bash
python3 tool/mutagen_workspace.py preflight
for project in peak_bagger trip_routing flutter_map_tile_caching; do
  python3 tool/mutagen_workspace.py seed --project "$project" \
    --writers-stopped --mini-work-preserved || exit 1
done
python3 tool/mutagen_workspace.py baseline
```

`seed` refuses any existing session touching either root, including drifted or
previous bootstrap sessions. It creates a **temporary**, pre-paused
`<ordinary-name>-bootstrap` session with the same ignores and **`one-way-replica`**,
resumes it, flushes, checks synchronization problems, independently hashes the
in-scope trees, and retires that temporary session only on verified success.
This mode deliberately replaces differing shared files and removes stale
mini-only source, including MacBook deletions; it is **not an additive copy**.
It must never be used to resolve ordinary bidirectional conflicts or applied
before the mini's unique work is safely preserved. The MacBook-authoritative
rule applies only to this initial bootstrap.

Excluded credentials, live database files, service payloads, native test
dependencies and local outputs remain intact. If an in-scope directory removal
would also remove excluded local contents, Mutagen can report a transition
problem; stop and preserve/reconcile that layout explicitly, never delete the
directory wholesale to force success.

`baseline` uses `tool/mutagen_scope.py` on both endpoints (the reviewed source is
sent over SSH, with only root/ignore metadata on stdin). It compares **complete
in-scope path sets, file SHA-256, types, executable bits and symlink targets**.
It excludes the same ordered Mutagen-rule subset, does not follow symlinks and
refuses in-scope filesystem boundaries. It reports mismatched relative paths
without printing contents. An unsupported path or failed hash blocks activation.
New ignore syntax requires rechecking the manifest implementation and disposable
tests against actual Mutagen behavior.

On a seed failure, the helper pauses and retains its temporary session for
inspection. If pausing also fails, keep all source writers stopped and inspect
the daemon/session directly before doing anything else. Do not blindly replay
seeding. Inspect session status, preserve any additional endpoint work outside
the roots, determine whether partial transitions occurred, and deliberately
retire/retry the temporary session under the same freeze only after review.

### 5. Create/reuse ordinary sessions and activate after baseline agreement

```bash
python3 tool/mutagen_workspace.py setup-paused
python3 tool/mutagen_workspace.py setup-paused
python3 tool/mutagen_workspace.py inspect
python3 tool/mutagen_workspace.py activate --writers-stopped
python3 tool/mutagen_workspace.py ready --writers-stopped
```

`setup-paused` checks **all** existing session names, project labels and overlapping
roots before creating anything. Reuse requires matching effective endpoints,
SSH/local transport, mode, explicit ignore syntax, and exact ordered exclusions;
endpoint overrides, extra negations, missing exclusions or mismatched identity
fail closed. SSH aliases resolving to the same destination are considered when
finding overlapping sessions, but a differently expressed configuration is
reported for deliberate review rather than assumed equivalent. Reapplication
retains the session ID, pause state and conflicts. New sessions start paused;
existing active sessions are not silently paused or resumed by setup.

`activate` checks all three configurations, endpoint preflights and matching
baselines **before resuming any paused ordinary session**. It then flushes all
three. `ready` requires each flush to complete and every session to be connected,
scanned, idle (`watching`) with a successful cycle and **no conflicts, last
error, scan/transition problems, truncated problems or staging in progress**.
It waits for a clean status snapshot after flush with a bounded timeout. A
missing/paused/offline/problematic session identifies the affected project and
fails readiness. No successful flush alone implies readiness.

Only after the **first successful three-session readiness check** and Work Item
05's remaining commissioning checks may ordinary development start. Resume
writers only on the selected development machine. If baseline/activation/ready
fails, keep the freeze; preserve/inspect rather than selecting a winner/resetting.

## Inspection, pause/resume, and deliberate replacement

```bash
mutagen sync list --long
mutagen sync list --template '{{json .}}'
mutagen sync monitor mapping-peak-bagger
mutagen sync pause mapping-peak-bagger mapping-trip-routing mapping-flutter-map-tile-caching
# After inspecting configuration/problems and saving edits/stopping writers:
mutagen sync resume mapping-peak-bagger mapping-trip-routing mapping-flutter-map-tile-caching
python3 tool/mutagen_workspace.py ready --writers-stopped
```

Prefer exact IDs from inspection when duplicate names/drift exist. An edited
configuration file **does not update the ignores stored in an existing session**.
If replacement is intentional:

1. Freeze writers on both Macs/all three projects. Inspect and record the old
   session ID, endpoints, stored configuration, status and conflicts outside the
   roots. Pause the exact affected ID. Preserve both endpoint versions, including
   newly ignored/unignored paths, in private backups outside every root.
2. Resolve each conflict deliberately, preserving both versions first. Agree the
   new scope and baseline. Do not run `reset`, switch to a resolving mode, or
   reseed to suppress conflicts. Ordinary same-file conflicts can be resolved by
   putting the agreed content on both endpoints; flush and check. Unconflicted
   paths can keep syncing while conflicts are reported.
3. Verify the full newly intended baseline at both endpoints. If retiring an old
   session, explicitly run `mutagen sync terminate <reviewed-id>` only after its
   endpoint work and conflict record are recoverable. Termination loses its
   reconciliation history; it is not a conflict-recovery operation.
4. Run `setup-paused`, inspect captured settings, `baseline`, `activate` and
   `ready` under the same freeze. Resume development only after all three are
   ready and commissioning is complete. An unchanged setup needs none of this.

With `two-way-safe`, incompatible **same-file edits** are retained at their
respective endpoints and reported as conflicts after synchronization reconnects.
Ordinary deletions propagate. In Mutagen 0.18.1 a **plain edit versus deletion**
is automatically reconciled by preserving/restoring the modification, rather
than reporting a conflict: this is the native non-data-losing behavior. Report
edit/delete conflicts where actually detected (for example more complex tree
changes); do not promise every deletion stays deleted against an offline edit.
The helper never chooses a conflict winner or resets to hide it. Retain offline
edits locally and do not claim delivery until reconnect/flush/readiness succeeds.

## Disposable verification record — 2026-10-10

Run from Peak Bagger:

```bash
python3 -m unittest tool.tests.test_mutagen_workspace -v
```

The integration tests create an **isolated controlling daemon/data directory**
and temporary local alpha/beta roots; there are no live source/database probes.
They use actual Mutagen 0.18.1 and the committed rules, with no login registration.
The tests stop their own daemon and remove their disposable sessions/endpoints.
All **7** focused tests passed. Full `python3 -m unittest discover -s tool/tests -v`
passed **26** tests; Ruff/static Python compilation passed. Required project
regression checks also passed: `flutter analyze --no-pub` reported no issues;
`caffeinate -i flutter test --no-pub --reporter expanded` completed with **2,173
passed, 5 skipped** (2m57s). Skipped tests remain unverified.

| Verification | Result |
| --- | --- |
| Stale migration | Differing shared file and stale mini-only source reconciled; stale source does not resurrect on alpha |
| Recoverable unique work | Temporary Git commit, branch, stash, staged/unstaged/untracked work copied outside roots; original Git metadata moved outside roots; stash/branch/index/file recovery asserted |
| Baselines | Matching path sets and SHA-256 content/type/executable manifests before ordinary activation, across all three projects |
| Machine-local preservation | Different fake defines, databases, dependency caches, platform outputs, Local Topo payloads and FMTC native-test files preserved at both endpoints; additional private probes do not propagate |
| Shared scope | Sources/tests, docs/workflows, UI assets, examples, package/Pod/npm locks, ObjectBox generated Dart/model JSON, tracked-dylib representative and Local Topo source/config/styles/tests/three placeholders propagate |
| Repeatability | Second setup reuses all three IDs; no duplicate session; existing conflicts retained on reapplication |
| Drift | Real wrong-root, wrong-mode, missing-database-exclusion sessions rejected; saved work and existing conflict state retained; overlapping/duplicate sessions and endpoint overrides rejected |
| Freeze/readiness sequence | Saved fixtures with no other writers; failed baseline prevents every activation; paused sessions fail readiness; first three successful flush/status checks precede permitted writer resumption |
| Ongoing synchronization | Mini-originating edit propagates; ordinary source deletion propagates |
| Offline conflicts | Paused local sessions simulate transport disconnection; differing same-file edits retained/reported in all three after resume; readiness fails and both versions remain; edit/delete preserves modified source on both endpoints |
| Error surfaces | Missing roots/Git pointer metadata block creation; disconnected/unscanned states, last errors and all problem/truncation/staging fields reject readiness |

Real SSH transport probes, login/restart/session persistence, physical connection
loss/reconnect, live mini preservation/seeding/activation, and live exclusions
remain **pending Work Item 05**. Pausing disposable local sessions does not prove
physical network behavior. Read-only inspection confirms no live sessions were
created. The missing mini volume remains a named commissioning prerequisite.
