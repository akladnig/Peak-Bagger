# Two-Mac operations: handover, owner Git and conflict recovery

**The MacBook is the sole Git owner for all three projects.** The mini has local
working-file mirrors for editing, building and testing, with no active `.git`
directory or worktree pointer file. This implements [L1/L2/L6 and the selected
Spec](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/spec.md), with
disposable evidence for [Work Item 03](../ai_specs/peak-lists/0062-macbook-mini-mutagen-development/work-items/03-handover-remote-git-and-conflict-recovery.md).

This is one logical working-file workspace with **sequential machine handover**.
Concurrent development on different branches in these mirrors is unsupported.
Mini editor/agent features requiring local Git metadata are unavailable. Never
create a mini repository as a fallback or synchronize `.git`.

## Session identities and lifecycle

The dedicated Mapping runtime pipeline uses [installed release dispatch](mapping-pipeline-releases.md),
independently of the source handover gate below. Source pauses/handovers do not
release its invocation/helper locks or stop its installed stages. Runtime session
automation is managed separately by Spec 0063 Item 08.

Run controlling Mutagen commands on the **MacBook**. Helper examples assume its
Peak Bagger checkout is the current directory. Use Python 3 and Mutagen **0.18.1**;
the helper refuses a version differing from its inspected API.

| Project | Session | MacBook owner checkout | Mini working-file mirror |
| --- | --- | --- | --- |
| Peak Bagger | `mapping-peak-bagger` | `~/Development/mapping/peak_bagger` | `/Volumes/Development/mapping/peak_bagger` |
| Trip Routing | `mapping-trip-routing` | `~/Development/mapping/trip_routing` | `/Volumes/Development/mapping/trip_routing` |
| Flutter Map Tile Caching | `mapping-flutter-map-tile-caching` | `~/Development/mapping/flutter_map_tile_caching` | `/Volumes/Development/mapping/flutter_map_tile_caching` |

`tool/mutagen-workspace.json` defines SSH beta endpoints through the existing
MacBook alias **`mini`** (`mac-mini.local`, user `adrian`), `two-way-safe`, project
labels and explicit ordered ignores. `.git` directories/pointer files, private
defines, live databases, caches and outputs stay local. Required generated source,
lockfiles and documentation stay shared. See [configuration and safe
bootstrap](two-mac-mutagen-bootstrap.md) for the complete scope, preservation,
seeding, drift/replacement and login-start instructions. All Work Item 05 gates
passed in the [live commissioning record](two-mac-commissioning-live.md).
MacBook is the selected active developer; switch to mini only after the normal
all-project freeze/readiness handover below.

### Creation or reuse after preserved, verified initial seeding

Keep all source writers frozen as defined below through this sequence:

```bash
python3 tool/mutagen_workspace.py setup-paused
python3 tool/mutagen_workspace.py inspect
python3 tool/mutagen_workspace.py baseline
python3 tool/mutagen_workspace.py activate --writers-stopped
python3 tool/mutagen_workspace.py ready --writers-stopped
```

Run each step only if the previous one succeeds. `setup-paused` creates missing
sessions paused and reuses existing ones only after checking names, labels,
effective roots/SSH transport, mode and captured ordered exclusions. Existing
pause/conflict state is retained. Drift or overlaps stop setup; do not create a
duplicate to bypass them. `activate` verifies all three baselines before resuming
any paused session. **Do not seed or activate as an ordinary conflict fix.**
Changing the JSON does not change ignores captured by an existing session;
replacement requires the bootstrap guide's deliberate preservation/reconciliation.

### Inspection, flush, pause and resume

```bash
python3 tool/mutagen_workspace.py inspect
mutagen sync list --long
mutagen sync list --template '{{json .}}'
mutagen sync monitor mapping-peak-bagger
mutagen sync flush mapping-peak-bagger mapping-trip-routing mapping-flutter-map-tile-caching
```

`monitor` is an interactive inspection command; exit it before continuing. Native
flush forces synchronization cycles, but **flush success alone is not readiness**.
The frozen three-project gate is:

```bash
python3 tool/mutagen_workspace.py ready --writers-stopped
```

The helper checks the intended configuration, flushes **every** session, then
inspects native status. All three must have completed their flush and be connected,
scanned, idle (`watching`) with a successful cycle, no pending synchronized changes
or staging, conflicts (including truncated/excluded conflict counts), connection/
last errors, scan/transition problems (including truncated/excluded counts), or
other synchronization problems. A missing, paused, disconnected, timed-out or
otherwise unavailable session names its project and blocks readiness. A failure
is **NOT READY**, even if the other two sessions succeeded. Bounded waiting never
turns a failure into success. Do not narrow the gate to the project being edited;
the dependency projects are part of the same handover.

To pause/resume intentionally, first save/freeze source writers and inspect exact
IDs. With uniquely identified, matching sessions:

```bash
mutagen sync pause mapping-peak-bagger mapping-trip-routing mapping-flutter-map-tile-caching
# After reviewing retained state and restoring endpoint availability:
mutagen sync resume mapping-peak-bagger mapping-trip-routing mapping-flutter-map-tile-caching
python3 tool/mutagen_workspace.py ready --writers-stopped
```

Check each command's exit status. Prefer reviewed **exact IDs** when names are
ambiguous or configuration has drifted. Resume failure also blocks readiness;
inspect status before retrying. Mutagen pause stops synchronization, **not source
writers**. A paused session cannot pass the handover gate.

## Source-write freeze and handover

1. Choose the receiving machine. On **both Macs, in all three projects**, save
   editor buffers and stop source writers: agents, auto-save/refactoring tasks,
   formatters, generators and source-writing watchers/build/test tasks. Record the
   freeze time and responsible operator for both endpoints. Stop any source-writing
   task even if it only touches a dependency or generated source.
2. Keep those writers stopped. Run `ready --writers-stopped` on the MacBook;
   inspect native status as above. Expect a named `READY` line for **each** project
   and exit status zero. The flag attests to the freeze; it cannot stop processes
   or lock editors. No new cross-machine locking system is supplied.
3. On any failure, **do not hand over**. Record the failed session/project, keep
   writers stopped, restore connectivity or resolve the reported problems
   deliberately, then repeat the full three-session flush/check.
4. Only after success, resume source writers **on the receiving machine only**.
   Outgoing writers remain stopped. Reinstall/regenerate local dependencies and
   outputs as needed using [local build provisioning](two-mac-local-builds.md).

This applies in both directions, including a mini-to-MacBook handover. Do not
resume a background agent on the outgoing machine after switching editors.
After offline editing, edits are retained locally; they have **not been delivered**
until connectivity returns and the flush/check succeeds. Reconnection normally
restarts synchronization automatically; a timeout is not evidence of delivery.
After a failed handover there is no receiving developer until readiness is restored.

## Mini-initiated SSH Git

Git runs in the corresponding **MacBook checkout**, including its real index,
branches and hooks. An unreachable or sleeping MacBook makes owner Git unavailable.
There is no local mini Git fallback. Local editing/building/testing remains possible
after SDK/package/native dependency setup; installing missing dependencies still
needs their normal availability. Full app runtime additionally needs its Mapping
data store, as described in the Spec.

### Discover and validate the reverse connection during commissioning

The discovered `mini` alias is **MacBook-to-mini only**. Initial read-only inspection
on 2026-10-10 found no reverse alias. At the **2026-10-11 prerequisite checkpoint**,
the mini's **`macbook`** alias reaches `Adrians-MacBook.local` with noninteractive
authentication and strict host-key checking. Read-only Git resolves all three exact
MacBook owner roots. Set `MACBOOK_SSH=macbook` on this mini; full live-session Git
and handover commissioning remain pending. See the [checkpoint record](two-mac-commissioning.md).
On another machine, discover its actual SSH configuration/address and credentials;
do not assume the same alias exists or copy private keys into a project.
On the MacBook inspect its configured Remote Login/address; on the mini inspect
its existing SSH setup, set `MACBOOK_SSH` to that discovered destination and verify
the host key/authentication normally. These examples run in **Bash on the mini**:

```bash
: "${MACBOOK_SSH:?Set this to the discovered, validated MacBook SSH destination}"
ssh -G "$MACBOOK_SSH"
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" hostname
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'test -d "$HOME/Development/mapping/peak_bagger/.git" && git -C "$HOME/Development/mapping/peak_bagger" rev-parse --show-toplevel'
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'test -d "$HOME/Development/mapping/trip_routing/.git" && git -C "$HOME/Development/mapping/trip_routing" rev-parse --show-toplevel'
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'test -d "$HOME/Development/mapping/flutter_map_tile_caching/.git" && git -C "$HOME/Development/mapping/flutter_map_tile_caching" rev-parse --show-toplevel'
```

Verify the reported machine and all three exact checkout paths against the table
before writing. Here `$HOME` expands on the remote MacBook, not the mini. These
checks assume the approved regular owner checkouts; if Git layout has changed,
inspect deliberately rather than loosening the owner-path check.

### Read-only owner views

```bash
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'git -C "$HOME/Development/mapping/peak_bagger" status --short'
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'git -C "$HOME/Development/mapping/trip_routing" diff'
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'git -C "$HOME/Development/mapping/flutter_map_tile_caching" log -5 --oneline'
```

`status`, `diff`, and `log` describe the MacBook repository and **may omit pending
mini changes**. They need no mandatory flush for a deliberately stale owner view.
For an up-to-date view of saved mini edits, freeze both machines/all three projects
and flush/check first. No command above runs Git in `/Volumes/Development`.

### Shared pre-Git gate from the mini

After establishing the two-Mac/all-project freeze, use this Bash function:

```bash
workspace_ready() {
  : "${MACBOOK_SSH:?Set the validated MacBook destination}" || return
  ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
    'export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin; python3 "$HOME/Development/mapping/peak_bagger/tool/mutagen_workspace.py" ready --writers-stopped'
}
```

The MacBook's noninteractive SSH environment must find the inspected Mutagen
binary and Python 3; validate during commissioning. A missing executable,
credential failure or unavailable MacBook fails the gate. Fix that environment
rather than assuming readiness. Each `&&` below prevents the next operation on
failure; **all other source writers stay frozen throughout**.

### Stage and commit mini-originating work

Review the now-synchronized owner diff, then stage explicit intended paths. Example
for a reviewed Peak Bagger `README.md` edit:

```bash
workspace_ready &&
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'git -C "$HOME/Development/mapping/peak_bagger" diff -- README.md'
# After deliberate review, with the SAME freeze still in force:
workspace_ready &&
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'git -C "$HOME/Development/mapping/peak_bagger" add -- README.md && git -C "$HOME/Development/mapping/peak_bagger" commit -m "docs: update workspace notes"'
```

For either sibling, use its exact owner checkout from the table and its reviewed
paths, keeping the same **three-session** gate. Failure of any session prevents
staging/commit. Keep writers stopped until Git finishes, including hooks. If a
hook writes synchronized source, flush/check all three again before resuming.
After success resume only the chosen active machine; outgoing writers stay stopped.
If Git or SSH fails, inspect owner status/index/log before retrying; a disconnected
client may not know whether a remote commit completed. Do not make a mini commit.

### File-replacing Git operations

Checkout/switch, reset, merge, rebase, restore, stash application or other
file-replacing operations use **the same freeze and successful three-session
pre-check**, even when initiated directly on the MacBook. Review owner diffs and
preserve/commit/stash intended work deliberately first. Readiness does not make a
destructive Git command safe to discard changes. A branch checkout example,
after choosing a real branch on the owner:

```bash
workspace_ready &&
ssh -T -o BatchMode=yes -o ConnectTimeout=8 "$MACBOOK_SSH" \
  'git -C "$HOME/Development/mapping/peak_bagger" checkout reviewed-target-branch' &&
workspace_ready
```

`reviewed-target-branch` denotes the operator's chosen branch; replace it before
use. For reset/merge/rebase, substitute the deliberate owner Git command and keep
**both** checks. A failed pre-check prevents Git. A failed Git command or
post-operation check prevents development resumption. Keep all other writers
stopped through Git and the subsequent **all-three** flush/status check. After
success, resume only the selected development machine. The mini has no branch or
index to align separately.

If Git itself reports a merge/rebase conflict, preserve/review the owner state and
perform only deliberate resolution/recovery writes under the freeze. Inspect Git
status via SSH; complete/abort the Git operation as appropriate, then flush/check
all three before ordinary source writers resume. Git conflicts and Mutagen
conflicts are distinct; a clean sync cannot complete an unfinished Git operation.

## Deliberate Mutagen conflict recovery

Ordinary in-scope deletions propagate. Incompatible same-file edits remain on
their respective endpoints and are reported under `two-way-safe`. Unconflicted
paths may keep syncing while conflicts are present, but any conflict blocks the
workspace readiness gate. Mutagen 0.18.1 preserves/restores a modification against
a **plain deletion** instead of reporting that case as a conflict; more complex
edit/delete conflicts must be handled when actually reported. Do not assume
every edit/delete combination conflicts or that every offline deletion wins.

1. Save/freeze both Macs/all three projects. Inspect `list --long` and the helper's
   status for the named project, conflict paths and problems. Pause its **reviewed
   exact session ID** before preservation/resolution.
2. Preserve the status/conflict record and **both versions**, including deletion
   intent, file types and relevant parent trees, in private recovery folders
   outside every sync root. Confirm recovery copies before changing either side.
   Do not put temporary recovery files back under synchronized source.
3. Review both versions and explicitly choose a combined content, a retained
   version, or agreed deletion. For an ordinary same-file conflict, put the
   agreed content at the same path on **both endpoints** while paused. For agreed
   deletion, preserve both first, then deliberately remove the path at both.
   Tree/type conflicts need an agreed layout and preserved children too.
4. Resume the same reviewed ID, flush/check all three, and inspect that conflict
   paths are resolved. On failure keep the freeze and backups; investigate the
   exact remaining conflict/transition problem. On success resume writers only
   on the selected machine, retaining recovery copies until reviewed.

Do not automatically choose a winner, use `mutagen sync reset`, change to a
resolving mode, reseed from the MacBook or terminate/recreate a session to hide
conflicts. MacBook authority was a **bootstrap** rule, not a permanent preference
for MacBook edits. Configuration-drift replacement is the separate preservation
procedure in the bootstrap guide, never a shortcut for this recovery.

## Disposable verification — 2026-10-10

```bash
python3 -m unittest tool.tests.test_mutagen_operations -v
```

**4 operational tests passed** using actual Mutagen 0.18.1, an isolated daemon/
data directory, three temporary alpha/beta project pairs and committed ignores.
Git commands travel through a temporary **loopback OpenSSH server** to a temporary
alpha repository, with isolated generated test keys/known-hosts and per-command
Git identity. No user SSH/Git configuration, real repository, launch agent or live
project session is modified. The harness records and asserts the operator's
save/freeze/readiness/Git/post-check/resume sequence; these controlled fixtures
have no background editor/agent processes and are not a distributed lock test.

| Check | Evidence |
| --- | --- |
| Remote staging/commit | Saved beta edit flushed to alpha before SSH `add`/`commit`; `HEAD:tracked.dart` contains it; beta gets no `.git` |
| File replacement | A second mini edit to a tracked file reaches alpha before SSH checkout; checkout replaces another tracked file on both endpoints, preserving the edit; post-check covers all three |
| Post-operation failure | Paused dependency after checkout rejects post-check and resumption; writers remain frozen until restored three-session readiness |
| Sequential handover | Source edits in all three projects flushed/inspected before alpha-to-beta resumption; outgoing alpha writers remain stopped; both directions recorded |
| Disconnected/missing member | Real SSH connection failure on disposable loopback endpoint, separately for each project, then missing session: named readiness failure prevents `add`, `commit`, checkout and handover |
| Explicit conflict | Divergent saved versions after pause/resume reported and retained; dependency conflict blocks owner Git; unrelated path still syncs |
| Deliberate recovery | Both versions preserved outside roots, explicitly combined on both, same session ID retained, no reset/winner mode; only then full readiness and beta resumption |
| Git owner unreachable | Temporary SSH server stopped; SSH Git fails with no mirror repository created |

**Checkpoint update:** real mini-to-MacBook destination, host/authentication,
explicit owner-command PATH, attached mini volume and read-only owner Git were
verified on 2026-10-11. **Pending environmental evidence (Work Item 05):** live
sessions/migration, actual two-machine writers and handover, physical network
loss/reconnect and guarded live Git operations. Loopback SSH proves the command
boundary, not the reverse path between these Macs. Session pausing simulates
offline conflicts, not physical network behavior. Unavailable environmental
checks are pending, never passed.

Full regression checks: `python3 -m unittest discover -s tool/tests -v` **30
passed**; Ruff and Python compilation passed; `flutter analyze --no-pub` reported
no issues; `caffeinate -i flutter test --no-pub --reporter expanded` **2,173 passed,
5 skipped** (3m26s). Skipped tests remain unverified.

### PR regression recheck — 2026-10-11

Enabling MacBook Remote Login exposed a fixture assumption that loopback port 22
must be closed. The disconnected-member test now reserves a non-listening
ephemeral loopback port and uses private SSH wrappers/configuration only in its
isolated daemon. Connection refusal or timeout both establish the expected
transport failure. User SSH services, configuration and live sessions are untouched.
The focused test passed, followed by the full Python suite: **30 passed** in
22.098 seconds. Ruff passed for all seven workspace/helper/test Python files.
