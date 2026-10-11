# Two-Mac workspace commissioning record

**Status: prerequisites verified; live commissioning pending. Ordinary mini
development is not ready.** This is the live
record for [Work Item 05](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/work-items/05-commission-and-verify-two-mac-workspace.md).
Initial inspection: **2026-10-11 local time** (command timestamp
`2026-10-10T19:30:04Z`). Reinspect mutable state before resuming.

**Latest recheck:** both SSH directions and all three owner Git destinations,
private defines, the shared placeholder example, matching Flutter/Dart versions,
mini Xcode first-launch setup, CocoaPods and the FMTC native library now pass.
Explicit SSH toolchain PATHs were verified. The operator's source-write freeze,
preservation/migration, session activation and required build/runtime verification
remain pending. The initial failures and first recheck below are historical.

The four prerequisite Work Items are complete. Their preparation/disposable
results do not establish live commissioning completion. Procedures remain in
[bootstrap](two-mac-mutagen-bootstrap.md),
[operations](two-mac-mutagen-operations.md),
[local builds](two-mac-local-builds.md), and
[Mapping runtime](two-mac-mapping-runtime.md).

## Initial blockers

1. **Mini-to-MacBook SSH fails.** The MacBook's discovered LocalHostName is
   `Adrians-MacBook`; the mini's noninteractive probe to
   `adrian@Adrians-MacBook.local` reports **connection refused on port 22**.
   Enable/validate MacBook Remote Login and the allowed account. Mini `~/.ssh`
   contains only `authorized_keys`, with no configuration or identity file;
   establish the intended reverse authentication and host trust using the user's
   chosen credentials. Successful TCP access alone will not prove authentication.
2. **Mini macOS build provisioning is incomplete.** `xcodebuild -version` fails
   because the selected developer directory is
   `/Library/Developer/CommandLineTools`; `/Applications/Xcode.app` is absent.
   Install/select full Xcode and complete its setup. Flutter, Dart and Mutagen
   are unavailable on the inspected noninteractive PATH; no Flutter SDK was
   found at the checked home or direct `/Volumes/Development/flutter` locations.
   Discover an existing SDK or provision the pinned Flutter/Dart versions from
   the local-build guide. The mini needs Mutagen's remote agent, not a second
   controller. Its FMTC `test/lib/libobjectbox.dylib` is absent.
3. **Both existing local defines files fail validation.** The reviewed validator
   reports invalid/unreadable configuration on both Macs. Correct each existing
   file deliberately in a private editor and rerun validation. Both copies were
   preserved; the validators emit status only and no seed was attempted. Shape
   validation does not prove provider acceptance.
4. **The two-machine source-write freeze has not been established.** The operator
   must save buffers and stop source writers across all three projects on both
   Macs before final preservation/reconciliation/seeding. No `--writers-stopped`
   attestation was made for live endpoints. Select the eventual receiving machine
   and keep outgoing writers stopped after successful readiness.
5. **The shared defines example needs review.** The existing user modification to
   `dart_defines.example.json` replaces API-key placeholders with non-placeholder
   values. Restore examples deliberately and keep real credentials only in the
   excluded local file before seeding/synchronizing. This modification was not
   staged or altered; no key values are included in this commissioning artifact.

## Initial live evidence

| Check | Result and scope |
| --- | --- |
| MacBook-to-mini SSH | **PASS:** existing `mini` alias reaches `MacMini`, arm64; Python 3.9.6 and Git are available remotely |
| Mini external Development volume | **PASS:** local APFS `/dev/disk5s2` mounted at exactly `/Volumes/Development`, distinct from startup storage; approximately 2.3 TiB available |
| Exact three-project roots | **PASS:** `python3 tool/mutagen_workspace.py preflight` exits zero for every project; root/pubspec/physical-path checks succeed; all three mini roots pass `test -w` |
| Installed controller/config inspection | **PASS:** MacBook Mutagen 0.18.1 matches the pinned configuration; helper inspection reports all intended roots and `two-way-safe` |
| Live sessions | **PENDING:** `mutagen sync list --long` reports no synchronization sessions, before and after disposable tests; no live setup/seed/activation was attempted |
| Reverse owner Git | **FAIL:** mini-to-MacBook port 22 refuses connection; owner Git and noninteractive owner-command PATH remain unverified |
| Local defines | **FAIL:** existing invalid/unreadable files on both Macs, preserved for deliberate correction |
| Mini tracked ObjectBox library | **PASS, limited:** actual mini loads Peak Bagger's universal x86_64/arm64 dylib; C API `5.3.2`, core `5.3.2-2026-05-05 (lmdb, VectorSearch)`; retain its shared-source treatment |
| Mini native-test readiness | **PENDING:** FMTC's separate native library is absent; fresh package/minimum-version checks and native persistence tests remain required |
| MacBook external Development drive | **PASS, limited:** `/Volumes/Development` is absent; this alone is not a disconnected rebuild |
| SMB runtime access | **PASS:** current MacBook `mount` shows `mac-mini.local/Services` at `/Volumes/Services` using `smbfs`; both manifests are readable. Mini share still maps Services to its attached volume, SMB enabled, guest disabled, read-only |

Read-only commands included:

```bash
python3 tool/mutagen_workspace.py inspect
python3 tool/mutagen_workspace.py preflight
mutagen version
mutagen sync list --long
scutil --get LocalHostName
ssh -T -o BatchMode=yes -o ConnectTimeout=8 mini hostname
ssh -T -o BatchMode=yes -o ConnectTimeout=8 mini \
  'ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=8 adrian@Adrians-MacBook.local hostname'
python3 tool/development_defines.py
# Execute the reviewed validator remotely without copying credentials or source:
ssh -T -o BatchMode=yes -o ConnectTimeout=8 mini \
  '/usr/bin/python3 - --file /Volumes/Development/mapping/peak_bagger/dart_defines.local.json' \
  < tool/development_defines.py
```

## Repository/work inventory and preservation gate

On each endpoint, inspected `rev-parse`, current commit, `status
--porcelain=v1 --untracked-files=all`, `for-each-ref`, stash IDs, unstaged diff
statistics, and cached diff statistics. This is preliminary inspection, not
completed unique-work reconciliation or a recoverable migration backup.

| Project | MacBook state | Mini state / implication |
| --- | --- | --- |
| Peak Bagger | Branch `mutagen`, `400e8da`; existing tracked/untracked development changes | Branch `main`, `b38ad9a`; modified `run_local_maps.sh` and untracked Specs, migration docs/scripts/tests. Every displayed mini ref exists with the same ID on the MacBook, including backup branches and three stashes; MacBook additionally has the `mutagen` branch. Preserve mini working files independently before replacing them |
| Trip Routing | `7491846`, clean, no stashes | Same commit, displayed refs, clean status, no stashes; still preserve original metadata before migration |
| Flutter Map Tile Caching | `022bbe0`; four tracked modified files, local untracked `test/download/` | Same commit/refs; same four tracked changes, no stashes. Full binary-diff SHA-256 matches on both endpoints: `2cef03a930d50f0654f7672eb0bc47d27112631d9a22760a51e8f3d4dfcf31ab` |

Cached diffs on all six repositories are empty at inspection. Mini Peak Bagger
untracked files and its script changes have not been proved equivalent to the
MacBook copies. No unique work may be discarded on this evidence.

**Remaining migration backups: none created in this attempt.** All original
mini `.git` directories and working files remain in place. Under the confirmed
freeze, re-inventory, create/verify private worktree snapshots and all-ref bundles
outside every synchronization root, review unique work, then move each original
`.git` into that recovery location following the bootstrap guide. Record the
actual backup paths and recovery checks here before seeding.

## Regression and inherited runtime evidence

Fresh full operational Python suite:

```bash
python3 -m unittest discover -s tool/tests -v
```

**PASS: 30 tests, 19.094 seconds.** Actual Mutagen tests use isolated daemon data
and disposable endpoints; Git operations use disposable loopback SSH/repositories.
They verify preservation, source/exclusion propagation, drift rejection, conflict
retention/recovery, three-session gates and unavailable-owner behavior. Their
printed session IDs/READY lines are fixture evidence, not real workspace sessions.

Work Item 04's completed evidence is integrated from
[its runtime record](two-mac-mapping-runtime.md#smb-commissioning-completion--2026-10-10):
all 25 manifest-derived files opened through the exact SMB root and matched
**4,255,657,108 bytes**; built-app logs/window evidence showed normal Dashboard
startup after preflight/geometry and before/through local ObjectBox initialization.
Existing startup tests cover affected paths, Retry/Quit and no database bypass.
That historical live launch was not repeated in this blocked attempt. Physical
SMB failure/recovery, login remount and mini direct-disk UI remain pending.

Prerequisite MacBook Flutter analysis/tests/build results remain recorded in the
local-build guide (Peak Bagger 2,173 passed/5 skipped, Trip Routing 11 passed,
FMTC 59 passed; FMTC analyzer diagnostics remain explicit). Fresh both-machine
package resolution, analysis, relevant/full tests and macOS builds have **not**
been completed for this commissioning attempt. Skipped tests are not passed.

## Pending completion checklist

- Resolve the blockers above, then recheck SSH, volume/root permissions and local
  toolchains. Do not infer readiness from this earlier inspection.
- Establish/record the all-project, both-Mac freeze; preserve/review unique work,
  move original Git metadata into verified external recovery folders, reconcile
  stale source, seed and compare complete in-scope path/content baselines.
- Create exactly the three intended paused sessions; reapply unchanged setup and
  verify reused IDs/configuration; activate and obtain the first successful
  all-three flush/status gate under the same freeze.
- Exercise disposable bidirectional probes/removal and actual exclusions in each
  live session; confirm local credentials/databases/caches/payloads/native test
  libraries stay local and Git stays only on the MacBook roots.
- Register/exercise MacBook daemon login startup, persistent IDs, physical
  disconnect/offline retention/automatic reconnect; retain disposable conflict
  evidence without manufacturing conflicts in user source.
- Verify frozen three-session handovers and real mini-initiated owner Git for all
  corresponding roots, including unavailable-owner behavior. Use Work Item 03's
  disposable evidence for commit/file-replacement gates rather than resetting work.
- Provision local SDK/package/platform caches on both Macs and FMTC native test
  libraries separately; check library minima, run/record resolution, analysis,
  tests and a Peak Bagger macOS build on each. Validate private defines without
  disclosing values; preserve usable copies and seed only an absent mini copy.
- Complete the guide's saved-source recompilation probe with **all network access
  disabled** and the external Development drive absent; record exact provisioning,
  build/result and probe cleanup. Current SMB/SSH connectivity means this attempt
  supplies no fully disconnected build evidence.
- Record final readiness and the selected receiving machine; resume ordinary
  writers only there after all required commissioning checks succeed. Until then,
  ordinary mini development remains blocked. Offline-build success will not imply
  independent offline runtime; no Mapping replica or personal-data sync is added.

## Recheck after operator configuration updates

- **PASS:** `python3 tool/development_defines.py` on the MacBook and the reviewed
  validator executed over SSH against the mini's existing local defines file now
  both report **Local configuration is usable**. Neither file was overwritten or
  seeded. This resolves the earlier shape-validation failures, not provider access.
- **PASS:** all three exact roots still pass preflight. Inspection still reports
  no live sessions.
- **PARTIAL:** the reverse SSH probe now reaches MacBook SSH, replacing the earlier
  connection refusal with **host key verification failed**: the mini has no known
  ED25519 key for `Adrians-MacBook.local`. Its inspected SSH directory still contains
  only `authorized_keys`. Verify the MacBook host key and establish reverse host
  trust plus an intended mini identity/authorized public key; do not disable strict
  host checking. Actual authentication and owner Git remain pending.
- **PARTIAL:** mini `xcode-select -p` now selects
  `/Applications/Xcode.app/Contents/Developer`; `xcodebuild -version` reports
  **Xcode 27.0 / 27A266a**. The operator reports installation still in progress;
  completed first-launch/platform setup and actual build readiness are pending.
- **PENDING:** Flutter and CocoaPods were not found on either the noninteractive
  SSH PATH or the checked interactive-login shell PATH. The login shell finds
  `/opt/homebrew/bin/dart` and Homebrew, but a standalone Dart executable does not
  supply Flutter's pinned SDK. The login shell also reports existing missing shell
  dependencies; no shell configuration was changed. FMTC's required
  `test/lib/libobjectbox.dylib` remains absent.
- **PENDING:** `git status --short` now reports `dart_defines.example.json` deleted.
  The shared example must exist with the three required fields and placeholder
  keys before seeding; the operator's deletion was preserved pending reconciliation.
- **PENDING:** an explicit both-Mac/all-project save-and-stop freeze, unique-work
  backups, migration, live-session verification and offline recompilation remain
  unperformed. No ordinary mini development or handover readiness is claimed.

## Checkpoint before live migration — 2026-10-11

The operator completed the environment corrections. Current read-only verification:

| Prerequisite | Result |
| --- | --- |
| Both SSH directions | **PASS:** MacBook `mini` reaches the mini; mini `macbook` reaches `Adrians-MacBook.local` noninteractively with strict host-key checking |
| Remote owner Git | **PASS:** mini-initiated `rev-parse --show-toplevel` returns each exact `/Users/adrian/Development/mapping/<project>` MacBook root; no mini Git fallback |
| Exact source roots | **PASS:** all three helper preflights succeed; ordinary session inspection still reports no sessions |
| Private defines | **PASS:** reviewed status-only validation succeeds on each existing local file; no overwrite or SSH seed was needed |
| Shared defines example | **PASS:** restored file has both API-key placeholders and the Referer field; no real values are recorded here |
| Flutter / Dart | **PASS:** both Macs report Flutter **3.47.7**, revision `abaf9c5237`, bundled Dart **3.13.5** |
| Mini Xcode | **PASS:** selected `/Applications/Xcode.app/Contents/Developer`; **27.0 / 27A266a**; `-checkFirstLaunchStatus` exits zero |
| CocoaPods | **PASS:** MacBook **1.16.2**, mini **1.17.0** available; actual post-migration dependency resolution/builds remain pending |
| Mini FMTC native library | **PASS, limited:** independently installed `test/lib/libobjectbox.dylib` is universal x86_64/arm64, loads locally and exports C API **5.3.2**; fresh package-minimum/native-test checks remain pending |
| Remote controller tooling | **PASS:** explicit owner PATH finds `/opt/homebrew/bin/mutagen`, version **0.18.1**, and runs the reviewed helper's `inspect` over reverse SSH |

The MacBook Flutter upgrade preserved its original SDK lockfile diff in a stash
before upgrading. The upgrade-generated SDK lockfile diff is retained in a second
stash; the SDK checkout is clean. These SDK-local recovery stashes are outside the
project synchronization roots and are not mini unique-work backups. Existing
Flutter analysis/test/build evidence predates this upgrade; it does not establish
both-Mac commissioning success on 3.47.7.

Noninteractive SSH does not inherit the interactive toolchain PATH. Verified
environments for commands run on each destination are:

```bash
# Commands running on the MacBook via the mini's macbook alias:
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
# Commands running on the mini via the MacBook's mini alias:
export PATH="$HOME/develop/flutter/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

Use these inside the respective remote command, not merely on the initiating
machine. The operations guide's remote readiness function includes the owner PATH.

**Checkpoint only:** mini `.git` directories remain active in all three original
checkouts, no live Mutagen sessions exist, and no final source-write freeze,
verified unique-work backups, seeding, baseline comparison, handover, login/network
persistence check, both-Mac project builds/tests, or fully disconnected MacBook
source-recompilation probe has occurred. These remain required before ordinary
mini development. Reinspect repositories and endpoint state under the confirmed
freeze before migration; preparation is not Work Item 05 completion.
