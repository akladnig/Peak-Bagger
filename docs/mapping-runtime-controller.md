# Automatic Mapping runtime refresh

Spec 0063 Item 08 supplies the installed MacBook controller. Source preparation
uses the mini's attached canonical store through its guarded publisher register.
The app only reads a selected immutable local generation; it never starts this
controller, contacts the mini, or waits for dataset freshness.

## Prerequisites and setup

Complete [publisher setup/recovery](mapping-source-publication.md) first. Both
machines need compatible [installed pinned releases](mapping-pipeline-releases.md)
with `mapping_controller.py` and `mapping_transport.py`, sealed Python/GDAL/PROJ
dependencies and normal SSH alias **`mini`**. MacBook needs Mutagen (tested with
**0.18.1**, `/opt/homebrew/bin/mutagen`), a GUI login and sufficient local space.
Normal SSH authentication/`SSH_AUTH_SOCK` is used; credentials are never stored
in configuration, payloads or logs.

The installation data base must match `mapping-runtime.json` or the app's default
Application Support replica base. Setup rejects network-backed replicas, canonical/
source-workspace paths, symlinks and any destination other than `<base>/incoming`.

On MacBook:

```sh
PYTHON=/opt/homebrew/anaconda3/bin/python3.13
LAUNCHER="$HOME/.local/share/peak-bagger-mapping-releases/mapping_release_launcher.py"
"$PYTHON" -I "$LAUNCHER" run -- controller setup \
  --remote-python /Users/adrian/.local/bin/python3.15 \
  --remote-install /Users/adrian/.local/share/peak-bagger-mapping-releases
"$PYTHON" -I "$LAUNCHER" run -- controller status
```

Setup inspects the installed peer's role/release/support/root, existing overlapping/
intended Mutagen sessions, runner configuration, plist and loaded agent before
creation. Matching setup reuses the same session/agent. Drift, duplicate sessions,
endpoint overrides, unexpected ignores/program/schedule fail actionably; nothing
is silently replaced. A create/SSH/bootstrap timeout is unknown: inspect before
retrying. A matching created paused session or written plist can be reused.

| Surface | Contract |
| --- | --- |
| Mutagen name | **`mapping-runtime-replica`** |
| Alpha | **`mini:<source base>/prepared`**, completed manifest-derived exports |
| Beta | **`<MacBook replica base>/incoming`**, transport's only writable surface |
| Mode | effective **`one-way-replica`**, no global/endpoint override or extra ignores |
| Agent | `~/Library/LaunchAgents/com.peakbagger.mapping-runtime-replica.plist` |
| Schedule | **RunAtLoad**, **StartInterval 60**, while logged in |
| Executable | stable installed dispatcher, selecting/pinning complete immutable helpers |
| Local state | `refresh/{config.json,state.json,controller.lock}`, outside beta |
| Logs | `<base>/logs/runner.{stdout,stderr}.log`, operation/policy logs outside beta |

The three source-workspace sessions, their ownership/exclusions and handover gate
are independent. Refresh never calls that gate or syncs ObjectBox databases,
personal GPX, API keys, settings, tile caches, Local Topo, Docker/Overpass state,
raw ELVIS inputs or the whole Mapping/Services tree.

## Durable single-flight stages

Each invocation holds the same nonblocking OS `refresh/controller.lock` across
mutation. Overlapping scheduled/maintainer/provisioning calls report **busy**.
One bounded transition per invocation lets later ticks continue the same identities.
**60 seconds is a trigger interval, not a dataset completion deadline.** Long
preparation/validation uses existing detached installed supervisors whose inherited
release/helper/data locks survive controller/SSH exit.

1. Pause runtime transfer before preparation, preserving existing progress/bytes.
   Persist a source-operation UUID **before** SSH dispatch.
2. Inspect that exact operation. Live supervisor/child ownership keeps it waiting.
   After release, verify its durable outcome via `reconcile-release`. Missing
   evidence is not success: reconciliation durably fences a never-dispatched UUID
   under installation ownership, preventing delayed SSH dispatch after a retry.
3. Read the successful export's completion/integrity inventory and idempotently
   register the recorded transfer UUID's **source-side export pin**. Pins survive
   controller exit; free locks/PIDs/timeouts/generic reconciliation cannot clear them.
4. Audit manifest-derived incoming/full-capture space plus **64 MiB reserve** before
   resume. On insufficient space preserve protected data. Resume/flush with
   `--skip-wait`, then observe across ticks: require a later completed cycle,
   connected/scanned endpoints and no conflict/scan/transition/staging errors.
5. Match incoming completed metadata to the pinned source, then dispatch a recorded
   independent capture UUID. Existing capture verifies every required path/size/
   **SHA-256**, reviewed dataset profile, immutable publication and durable witness.
   Idle alone/partial delivery never grants eligibility. Active/recovery/live data
   remain usable. Inspect/reconcile local completion before retry/continuation;
   unchanged eligible generations are reused without another copy/hash pass.
6. Send the exact durable independent receipt over bounded SSH. Lost responses
   retry the **same receipt**. Only source acknowledgement permits releasing that
   exact transfer pin. Transfer completion is not acknowledgement.
7. Run Item 06 coordinated local/source cleanup. Protect active, one recovery,
   newest pending, live-session/native and unresolved generations; source cleanup
   protects outstanding pins/unacknowledged/current exports. Finish paused so the
   next preparation receives a pretransfer space audit.

The runner reports **eligible for next app launch**. Activation remains Item 05's
local launch/preflight/selection/session transaction; running roots/DEMs do not
switch. Status exposes installed/configured releases, phase, original source/local
UUIDs, generation, transfer status, errors/cleanup, loaded schedule and selection.
It does not assert that existing app data is latest upstream.

### Noninteractive limits

| Boundary | Limit and outcome |
| --- | --- |
| Controller lock | **0 seconds**, busy deferral |
| Installation/publication/capture/selection locks | existing **5 seconds**, fail/busy, never steal/unlink |
| SSH connection | **10 seconds**, `BatchMode=yes`, keepalive **5 seconds × 2** |
| Each SSH/local process/Mutagen call | **30 seconds**, response cap **16 MiB** |
| Alias / launchctl / mount inspection | **10 / 10 / 5 seconds** |
| Controller outer installed-manager invocation | **180 seconds**, durable intent survives unknown exit |
| Transfer polling | one bounded observation per tick; no dataset completion deadline |
| No reported stage/transfer progress | **600 seconds** diagnostic, retain ownership/progress and inspect child/log |
| Detached source/native stage | existing **7,200 seconds** diagnostic budget; owner keeps inspecting/waiting |

No bound's expiry is completion, integrity, eligibility, acknowledgement or
ownership-release evidence. A quiet CPU-bound full DEM validator can exceed the
progress-warning interval: inspect its operation log and bounded child/CPU evidence
instead of assuming it ended. Unavailable/hung work remains visible/protected.

## Provisioning, pause/resume and recovery

Initial provisioning uses the same stages and app launch activation:

```sh
"$PYTHON" -I "$LAUNCHER" run -- controller provision
"$PYTHON" -I "$LAUNCHER" run -- controller status
"$PYTHON" -I "$LAUNCHER" run -- controller pause
"$PYTHON" -I "$LAUNCHER" run -- controller resume
```

`provision`/`refresh` advance one phase; scheduled triggers continue it. Pause
persistently disables future mutation and pauses only the runtime session. It
does not kill/release surviving preparation/validation. Resume continues recorded
identities and reconnects a paused transfer. Source handover is separate.

After interruption, inspect **status**, then let subsequent ticks reconcile the
original identities. Unreachable mini means blocked recovery, not permission to
prepare again. Missing dispatch evidence requires the installed manager's durable
fence. Inherited locks retain old helpers/protection. Never replay consumed UUIDs,
erase state/transfer progress, remove lock files, hand-edit completion/eligibility,
release another operation's pin or force cleanup of protected data.

For canonical `recovery-required`, use guarded publication recovery, not a new
maintenance plan. Repair source drift through reviewed capabilities/guard setup;
repair rejected payloads through coordinated publication. Use the older validated
replica meanwhile. Automated destructive cases use disposable data only.

## Compatible upgrades and drift resolution

Pause **before** atomic release selection. Build/seal/install fresh complete UUIDs
with explicit support for all retained old identities. Existing selection preflight
checks peer and retained metadata; surviving children keep old helpers. Never patch
immutable releases. After selecting the supported pair:

```sh
"$PYTHON" -I "$LAUNCHER" run -- controller setup --upgrade \
  --remote-python /Users/adrian/.local/bin/python3.15 \
  --remote-install /Users/adrian/.local/share/peak-bagger-mapping-releases
"$PYTHON" -I "$LAUNCHER" run -- controller resume
```

`--upgrade` requires a paused runner and unchanged endpoints/scope/dependencies;
it explicitly updates supported release IDs. Other drift needs operator review,
not another overlapping session. For interpreter/plist changes, pause and inspect/
unload the exact agent before reviewed replacement. Retire old binaries only
through installed ownership-aware tooling; preserve host/Cellar dependencies while
their owners survive. Version-1 controller journal/configuration remain separate
from version-1 source completion, app eligibility/selection and receipt records.

## Verification boundary

Disposable tests exercise controlled process/status/clock/space/transport responses,
actual OS locks, independent capture fixtures and real temporary one-way Mutagen
endpoints. Existing source/capture/retention/release suites cover corruption,
publication faults, surviving children, compatible/incompatible versions and
unavailable/partial source checkouts. Flutter startup/activation and I/O guards
verify the app never dispatches/waits for this runner. Item 11 owns actual login,
handover, power-loss, multi-GB operating faults and app/performance evidence;
fixture tests do not prove those live observations.

### Installed execution checkpoint — 2026-10-14

| Surface | Observed identity/outcome |
| --- | --- |
| Controller release | `8918ed0f-54a0-4dd8-b54f-ae3147af3942` |
| Source-preparer release | `dfe2a953-e4fb-4902-8da6-4b8e37f7fdaf` |
| Persistent runtime session | `sync_LoJOvzKX3HDbPatMplTGRyoRjuGaeCg6BCN8han8lAT` |
| Validated local generation | `2be1ef1d-0f92-41a7-ae7d-722142dee4d1`, 25 required files, 4,255,657,108 bytes |
| Local capture | `29db75c0-d1b9-4b21-b595-378bf156345c`, succeeded; compact immutable report 7,804 bytes |
| Durable receipt | `2ab31b16-f029-44d4-b39d-3177c619c62f`, source acknowledged; exact transfer pin released afterwards |
| Retention | Local/source cleanup complete; one newest pending/current export, no unresolved stage owners |
| Agent | installed/loaded `gui/501`, 38 observed scheduled runs, last exit 0, runatload/60-second interval |
| Unchanged refresh | repeated completed export/eligibility/receipt reused, no new capture or generation |
| App selection | eligible for next launch; no runner-driven activation or runtime root switch |

Initial setup, repeat setup, the paused compatible upgrade, completed transfer,
full independent validation, receipt/cleanup and unchanged reuse were observed
without modifying canonical payloads to manufacture faults. Quiet validation crossed
the no-progress warning bound while CPU-active; the recorded original operation
and its helpers/candidate/export protection survived until verified completion.
An overlapping installed inspection correctly reported the bounded dispatcher lock
busy. Evidence, actual space observations and final verification commands/results
are recorded in [Work Item 08](../ai_specs/peak-lists/0063-macbook-local-mapping-runtime-replica/work-items/08-automate-refresh-and-bounded-recovery.md).
