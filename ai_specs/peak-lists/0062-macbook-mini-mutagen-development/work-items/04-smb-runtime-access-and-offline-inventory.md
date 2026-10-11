---
type: Work Item
title: Establish SMB runtime access and preserve the offline inventory
parent: ../spec.md
---

## What to build

Inspect existing Services sharing/mount automation and establish MacBook runtime access to the mini's directly attached Mapping data store through SMB at the exact accepted path. Preserve and verify the measured runtime inventory and transfer-feasibility guidance for a later independent-offline-runtime design, while retaining current startup/failure behavior.

## Required context

- Read the parent Spec and `../interview-ledger.md`, especially L3/L4, plus `GLOSSARY.md` and `docs/mapping-data-store.md`.
- The canonical Mapping root is `/Volumes/Services/Mapping`. The mini reads the directly attached store; the MacBook must mount the Services share with that exact resulting path. Discover existing share and mount automation before changing it.
- Live SMB verification needs the relocated Services volume and reachable mini share. If unavailable, record the missing environmental prerequisite and leave that check pending rather than inventing a substitute root or claiming completion.
- Startup reads `region_manifest.json` and `Polygons/manifest.json`, checks existence/readability of every region-manifest dataset reference, and loads required regional/basemap polygon geometry before opening the normal ObjectBox-backed UI. A pre-existing local database does not bypass preflight.
- Existing Test Seams are Mapping filesystem injection, `test/services/mapping_data_store_test.dart`, and `test/widget/startup_shell_test.dart`. `test/widget/mapping_store_failure_dialog_test.dart` checks the separate in-app Retry/Dismiss flow, not startup Retry/Quit.
- The parent Spec contains the full measured 25-file inventory. Bytes are authoritative; the historical total is 4,255,657,108 bytes (3.963 GiB), not the approximately 375 GiB full Mapping directory.

## Acceptance criteria

- [x] Existing Services sharing and mount automation are inspected and their role documented. The chosen SMB setup preserves the exact MacBook runtime root `/Volumes/Services/Mapping` and direct mini access, without embedding credentials in docs/artifacts.
- [x] Mapping files stay outside all Mutagen sessions and each machine retains its own ObjectBox database. This item does not copy the Mapping store or introduce configurable runtime roots/automatic fallback.
- [x] Online startup through the SMB-mounted path is verified. Unavailable/unreadable Mapping paths retain affected-path reporting and startup Retry/Quit before normal UI; a local database is not a bypass. Existing regression tests are used where appropriate; no runtime change or new test is required merely for this operational setup.
- [x] Documentation preserves all 25 file paths and byte counts from the Spec and verifies their count and sum as 4,255,657,108 bytes. The inventory is clearly a measured planning baseline; future copying must recheck manifest references and current sizes rather than assume they remain unchanged.
- [x] Transfer guidance records the full set's feasibility, approximately 1.16 GiB of non-DEM files, approximately 89.6 MiB excluding highways and DEMs, and the approximately 120 GiB MacBook free space measured at inspection. Partial subsets do not satisfy startup while omitted files remain declared; whole-directory copies include unrelated maintainer data.
- [x] Future offline-runtime prerequisites include a local Mapping copy at an accepted root, offline basemap tiles, personal app data/settings and required GPX files, and local GDAL/PROJ for elevation sampling. A mini-only Local Topo HTTP service is unavailable while disconnected.
- [x] Guidance excludes raw ELVIS sources, topo-build DEM, raw theLIST inputs, Overpass service data, and Docker state from the current app runtime set. All three declared DEMs remain required by current preflight, even though Tasmania elevation sampling selects the ELVIS runtime DEM.
- [x] Results distinguish completed SMB/runtime checks from pending environmental checks and explain that current offline support covers source editing/builds, with independent offline runtime retained as a separate follow-up.

## Covers

- User Stories: 6.
- Requirements — Mapping runtime access and offline inventory: 1–6.
- Testing Strategy: online SMB startup and unavailable-store Retry/Quit verification through existing Test Seams; inventory count/byte-sum validation and remeasurement guidance.
- Follow-Ups: preserve the independent-offline-runtime design boundary and prerequisites.
- Interview Ledger: L3, L4.

## Blocked by

None. The Services share and MacBook SMB runtime path are now verified; see the
commissioning completion below.

## Initial implementation results — 2026-10-10

Initial result: partially implemented pending share publication. This prerequisite
was subsequently resolved; the completion evidence below supersedes that status.

- Operational guide: `docs/two-mac-mapping-runtime.md`, linked from
  `docs/mapping-data-store.md`. It records inspected sharing/automation locations,
  the selected read-only Services SMB export and Finder/Keychain mount procedure,
  exact-root checks, login mounting, startup/failure verification and offline scope.
- The relocated Services volume is now attached to the mini at `/Volumes/Services`
  (local APFS). Existing `mini` SSH access and TCP 445 from the MacBook work.
  `sharing -l` lists only the public-folder share, not Services; no existing
  Services mount automation was found in the inspected locations. Noninteractive
  administrative access reports a password is required.
- **Acceptance criteria 1 and 3 were initially pending:** inspection and the chosen
  procedure are documented, but an administrator must publish Services and enable
  the intended SMB account before MacBook authentication, exact-path mounting,
  online startup and live Retry/Quit/recovery can be verified. No alternate root
  was created and no SMB completion is claimed. The guide records the remaining
  mini UI and login/reconnect checks too.
- Re-derived the current manifest references on the mini, opened every file
  read-only and measured sizes: **25 files, 4,255,657,108 bytes**, with each path
  and size matching the Spec baseline. Non-DEM total **1,243,548,923 bytes**;
  excluding highways and DEMs **93,914,094 bytes**. Historical approximately
  120 GiB free is preserved; current `df -h /` reports approximately 132 GiB.
- `tool/mutagen-workspace.json` keeps the store outside all project roots and
  explicitly ignores live `data.mdb`/`lock.mdb`. Inspected ObjectBox local-directory
  resolution and startup coordinator ordering: a local database cannot bypass
  manifest/geometry preflight. No runtime source change or new test is needed.
- Existing Mapping/startup tests: **35 passed**. Static analysis: **no issues**.
  Full Flutter suite: **2,173 passed, 5 skipped** (skips remain unverified).
  Python suite: **30 passed**. Both documented inventory audit commands passed,
  including current mini/reference/size equality with the baseline; `git diff
  --check` passed. The guide records commands and verification scope.

## SMB commissioning completion — 2026-10-10

**Completed: all acceptance criteria satisfied.**

- After the operator published/authenticated Services, mini `sharing -l` confirms
  the share maps to `/Volumes/Services`, is SMB-enabled and read-only, and disables
  guest access. The mini retains its direct APFS access.
- The MacBook mount is SMB from `mac-mini.local/Services` at exactly
  `/Volumes/Services`. Both manifests and all **25 manifest-derived runtime files**
  were opened read-only through SMB; each current path/size equals the baseline,
  totaling **4,255,657,108 bytes**. No Mapping dataset was copied.
- Built/launched the current app with machine-local defines. A continuing-log
  launch of the same built executable confirms preflight/geometry before opening
  the existing local ObjectBox directory, schema/settings and tile-cache setup.
  A native window capture confirmed the populated normal Dashboard through SMB.
- Existing tests retain startup affected-path reporting, Retry/Quit and withheld
  normal UI; inspected coordinator/main ordering prevents a local-database bypass.
  Physical SMB ejection/failure/recovery, mini direct-disk UI and login/reconnect
  demonstrations remain unverified additional commissioning checks, explicitly
  distinguished from the completed live SMB startup and regression checks.
- Evidence and commands are recorded in `docs/two-mac-mapping-runtime.md`.
  Temporary startup logs/window captures stay outside source control; account
  mount identifiers and credentials are omitted from the report. No runtime code
  changed, so the already-passed static analysis/full regressions remain applicable.
