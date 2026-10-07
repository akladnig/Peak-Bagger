---
type: Work Item
title: Add Tool Manifest Resolver and Bootstrap
parent: ../spec.md
---

## What to build

Implement the shared manifest-aware resolver for Mapping-store tools and the trusted `tool_manifest.json` bootstrap/provision-or-verify commands. Runtime remains read-only and must never load `tool_manifest.json`; named-tool mode authorizes only one declared tool, while bootstrap mode may install only an absent manifest fixture.

## Required context

- Build on the fixture and safe-path boundary from Work Item 02 and the complete tool inventory from Work Item 01.
- The resolver returns authorized operations or opaque opened resources, never raw Mapping-store paths. Direct Mapping-store I/O is permitted only in the resolver and the explicit inventory-classified non-store-adapter allowlist.

## Acceptance criteria

- [x] Validate `tool_manifest.json` entries keyed by stable tool identifier. Each entry has non-empty `command.executable`, string `command.arguments`, `inputs`, `outputs`, `permittedWrites`, and `overrides`; reject malformed/undeclared literal and placeholder contracts.
- [x] Validate unique non-empty input/output IDs and safe relative paths. Inputs permit `file`, `directory`, or input-only `glob`; outputs permit only `file` or `directory`, required/replacement/atomic policy; `permittedWrites` names only declared outputs.
- [x] Expand only exact `{input:<id>}` and `{output:<id>}` placeholders after validating declarations, send argv directly without a shell, use repository-root working directory and fixed inherited environment, and expand glob inputs as lexically ordered arguments. An override may replace only its declared placeholder and remains subject to its declaration contract.
- [x] For file outputs, fail before execution when replacement is forbidden and the target exists; for permitted replacement, stage to a sibling temporary file and atomically replace. For directory outputs, stage a sibling snapshot, reject symlinks/escaped paths, validate required outputs before commit, atomically replace files where applicable, and remove stale final files only after replacement writes succeed without claiming whole-directory atomicity.
- [x] Runtime mode authorizes only the runtime manifest pair and validated references; named-tool mode requires a matching `toolId`; bootstrap mode may atomically install the version-controlled fixture only when `/Volumes/Services/Mapping/tool_manifest.json` is absent and must fail without overwrite for an existing conflicting file.
- [x] Provide a maintainer provision-or-verify command that validates mounted manifests with the shared parser against v1 retained-contract fixtures, allows only named data-derived differences initially for regional fingerprints, reports every allowed difference, and never overwrites Mapping data.
- [x] Add resolver/tool tests for all modes, path/symlink policies, glob behavior, direct argv, overrides, atomic output behavior, no-overwrite bootstrap, opaque binary readers, and source-level guards against unauthorized direct Mapping I/O.

## Implementation and verification

- Recovered the prerequisite inventory from `nas-migration` commit `a1222df` and
  documented current resolver ownership, explicit non-store adapters, tool IDs,
  v1 policies, and the subsequent Work Item 12 cutover.
- Shared pure-Dart schema/core supports both the Flutter runtime and standalone
  maintainer commands. Ready-scope source access is now catalog-authorized;
  runtime manifests cannot authorize the tool-only manifest as a dataset.
- `dart run tool/mapping_store.dart bootstrap-tool-manifest` performs atomic
  no-overwrite publication using macOS `RENAME_EXCL` (POSIX test hosts use an
  exclusive hard link). Equal existing JSON is verified without a write.
- `dart run tool/mapping_store.dart provision-or-verify` preflights and validates
  the mounted manifests against v1, reporting each allowed regional fingerprint
  difference. Automated verification uses temporary roots, not the real mount.
- Resolver/inventory tests: **62 passed**, including concurrent bootstrap,
  target-created-during-execution protection, staged snapshot failure semantics,
  opaque binary opens, argv literals, and standalone Dart command startup.
- Full suite: **2,127 passed, 5 skipped**. Final exclusive-publication and reserved
  tool-manifest symlink-alias hardening were rechecked with the focused
  resolver/inventory and runtime-boundary suites and targeted analysis.
- Targeted static analysis: clean. `flutter analyze --no-pub` reports nine
  pre-existing findings: two async-return warnings and seven style infos in
  unrelated map/GPX and route-graph code.
- Source guards prohibit direct I/O in migrated runtime readers and new tools;
  the explicitly inventoried legacy tools' I/O counts are frozen until their
  migration/removal in Work Item 12. Subprocess-internal I/O is not intercepted.

## Covers

- User Stories: 3
- Requirements: 22, 23, 28
- Technical Decisions: 5, 12-13, 19, 25, 27, 29
- Testing Strategy: 4, 9-10, 12-13, 15-16
- Interview Ledger: L3, L6, L9

## Blocked by
01-mapping-data-contract-inventory.md
02-mapping-store-manifest-boundary-and-catalog.md
