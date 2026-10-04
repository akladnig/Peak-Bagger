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

- [ ] Validate `tool_manifest.json` entries keyed by stable tool identifier. Each entry has non-empty `command.executable`, string `command.arguments`, `inputs`, `outputs`, `permittedWrites`, and `overrides`; reject malformed/undeclared literal and placeholder contracts.
- [ ] Validate unique non-empty input/output IDs and safe relative paths. Inputs permit `file`, `directory`, or input-only `glob`; outputs permit only `file` or `directory`, required/replacement/atomic policy; `permittedWrites` names only declared outputs.
- [ ] Expand only exact `{input:<id>}` and `{output:<id>}` placeholders after validating declarations, send argv directly without a shell, use repository-root working directory and fixed inherited environment, and expand glob inputs as lexically ordered arguments. An override may replace only its declared placeholder and remains subject to its declaration contract.
- [ ] For file outputs, fail before execution when replacement is forbidden and the target exists; for permitted replacement, stage to a sibling temporary file and atomically replace. For directory outputs, stage a sibling snapshot, reject symlinks/escaped paths, validate required outputs before commit, atomically replace files where applicable, and remove stale final files only after replacement writes succeed without claiming whole-directory atomicity.
- [ ] Runtime mode authorizes only the runtime manifest pair and validated references; named-tool mode requires a matching `toolId`; bootstrap mode may atomically install the version-controlled fixture only when `/Volumes/Services/Mapping/tool_manifest.json` is absent and must fail without overwrite for an existing conflicting file.
- [ ] Provide a maintainer provision-or-verify command that validates mounted manifests with the shared parser against v1 retained-contract fixtures, allows only named data-derived differences initially for regional fingerprints, reports every allowed difference, and never overwrites Mapping data.
- [ ] Add resolver/tool tests for all modes, path/symlink policies, glob behavior, direct argv, overrides, atomic output behavior, no-overwrite bootstrap, opaque binary readers, and source-level guards against unauthorized direct Mapping I/O.

## Covers

- User Stories: 3
- Requirements: 22, 23, 28
- Technical Decisions: 5, 12-13, 19, 25, 27, 29
- Testing Strategy: 4, 9-10, 12-13, 15-16
- Interview Ledger: L3, L6, L9

## Blocked by
01-mapping-data-contract-inventory.md
02-mapping-store-manifest-boundary-and-catalog.md
