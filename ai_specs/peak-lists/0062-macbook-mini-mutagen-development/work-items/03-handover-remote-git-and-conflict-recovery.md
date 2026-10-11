---
type: Work Item
title: Document and verify handover, remote Git, and conflict recovery
parent: ../spec.md
---

## What to build

Produce an operational guide for MacBook-owned Git and the three Mutagen sessions: creation/inspection/flush/pause/resume, deliberate conflict recovery, sequential handover, and SSH Git initiated from the mini. Verify the readiness and Git procedures in disposable endpoints and a temporary repository, and link the guide from the historical migration discussion with a short supersession note.

## Required context

- Read the parent Spec and `../interview-ledger.md`, especially L1, L2, and L6; use Work Item 02's actual session identities and setup conventions.
- `docs/mac-mini-development-drive-migration.md` contains a historical mini-owned Git example and unresolved ownership questions. Preserve that history and identify it as superseded by L1/L2 and this Spec's MacBook-owned workflow.
- No local Git repository is available in a mini mirror. Mini editor/agent capabilities requiring local repository metadata are outside this arrangement.
- Native Mutagen flush/status operations define readiness; this item does not require a new cross-machine locking system. Do not automatically choose conflict winners or reset sessions to conceal conflicts.
- SSH aliases/credentials must come from discovered user setup; validate the reverse mini-to-MacBook path during real commissioning in Work Item 05.

## Acceptance criteria

- [x] The guide states the MacBook is sole Git owner for all three projects and provides mini-initiated SSH Git examples targeting the corresponding MacBook checkout. An unreachable MacBook clearly makes Git unavailable without a mini repository fallback; local editing/building/testing remain possible after setup.
- [x] Session creation, inspection, flush, pause, resume, and conflict recovery use Work Item 02's conventions. Ordinary deletions propagate; incompatible edits require deliberate resolution; unconflicted paths may continue syncing; disconnected edits are not described as delivered.
- [x] Handover requires saving edits and stopping source writers in all three projects on both machines, including agents/formatters/generators. All three sessions are flushed and inspected, with no pending synchronized changes, conflicts, connection errors, or other synchronization problems required for readiness.
- [x] Any failed/unavailable session is named and blocks handover. Writers remain stopped through the check; after success they resume only on the receiving machine, with outgoing writers stopped. Concurrent development on different branches is explicitly unsupported.
- [x] File-replacing Git operations such as checkout/reset/merge/rebase require the same two-machine source-write freeze and successful three-session flush/readiness check before running in the MacBook checkout. Afterward all three sessions are flushed/checked again before development resumes; failure prevents the operation or subsequent resumption as applicable.
- [x] Staging/committing mini-originating work requires the freeze and successful three-session flush/readiness check before Git, with writers stopped until Git finishes. Read-only status/diff/log may omit unsynchronized mini changes; an up-to-date view requires flush/check first.
- [x] Disposable verification with a temporary Git repository demonstrates a mini-originating edit reaches the owner before remote staging/commit and before a file-replacing operation. Failed readiness blocks those operations; other writers remain stopped through the operation and required post-operation checks.
- [x] Disposable handover checks cover all three sessions and reject a disconnected or conflicted member. They record the writer-freeze/resumption sequence and demonstrate explicit conflicts without automatic winner selection. Unavailable environmental verification is pending rather than passed.
- [x] `docs/mac-mini-development-drive-migration.md` has a short supersession note/link to the new guide identifying the historical mini-owned example and ownership questions as superseded by L1/L2 and the parent Spec.

## Covers

- User Stories: 2–4.
- Requirements — Workspace layout and initial migration: 5 (operational lifecycle and recovery documentation).
- Requirements — Git ownership and machine handover: 3–8.
- Requirements — Synchronization behavior and scope: 2–3.
- Testing Strategy: three-session handover readiness, source-write freeze/resumption, temporary-repository remote staging/commit and file-replacement checks, failed-readiness prevention, and explicit conflict reporting.
- Interview Ledger: L1, L2, L6.

## Blocked by

- [02-repeatable-mutagen-configuration-and-safe-bootstrap.md](02-repeatable-mutagen-configuration-and-safe-bootstrap.md)

## Implementation and verification — 2026-10-10

Completed the operational guide and disposable verification. See
[`docs/two-mac-mutagen-operations.md`](../../../../docs/two-mac-mutagen-operations.md)
for the procedures and detailed evidence matrix.

- Guide uses Work Item 02's exact session identities, captured configuration,
  drift-safe creation/activation and native three-session readiness helper. It
  covers two-machine/all-project writer freezes, sequential handover, guarded SSH
  staging/commit and file-replacing Git with mandatory post-checks, stale read-only
  owner views, and explicit conflict recovery without reset or winner selection.
- Historical migration discussion is preserved with the required L1/L2/Spec
  supersession note and guide link; the bootstrap guide also links ongoing operations.
- `tool/tests/test_mutagen_operations.py`: **4 operational tests passed** with
  actual Mutagen **0.18.1**, isolated controlling daemon/local endpoints and an
  isolated loopback OpenSSH server targeting a temporary owner Git repository.
  Existing disposable fixture infrastructure is shared with Work Item 02's tests.
- Saved mini-originating tracked edits reach the owner before remote `add`/`commit`
  and before checkout. Committed content is asserted; checkout changes propagate
  back while preserving another mini edit; beta receives no Git metadata.
- Every project is separately exercised as a real SSH-disconnected then missing
  member. Named failed readiness prevents staging/commit/checkout and handover.
  A paused dependency after successful checkout blocks post-check/resumption;
  recorded source writers remain stopped through Git and required readiness.
- Divergent same-file edits are retained/reported; a dependency conflict blocks
  owner Git while an unrelated path syncs. Both versions are backed up outside
  roots, explicitly combined on both endpoints, and flushed/checked using the
  unchanged session ID before resuming only the receiving endpoint.
- Stopping the isolated owner SSH server makes Git unavailable without creating
  a beta repository. Test SSH keys/configuration/known-hosts are disposable and
  do not modify user credentials or SSH/Git configuration.
- `ruff check` and Python compilation passed. Full
  `python3 -m unittest discover -s tool/tests -v`: **30 passed** (21.5 seconds).
  `flutter analyze --no-pub`: no issues. Required full project suite via
  `caffeinate -i flutter test --no-pub --reporter expanded`: **2,173 passed,
  5 skipped** (3m26s). Skipped checks remain unverified.

### Explicit pending environmental checks for Work Item 05

- Read-only mini inspection found no `~/.ssh/config` supplying a reverse MacBook
  alias. Discover/validate the user's actual mini-to-MacBook destination, Remote
  Login, host key/authentication and noninteractive PATH for Git/Python/Mutagen.
  The guide uses a required `MACBOOK_SSH` variable rather than inventing an alias.
- Validate live attached-volume sessions, physical disconnect/reconnect,
  mini-initiated owner Git and actual two-machine writer freeze/handover during
  commissioning. Loopback SSH verifies the remote command boundary, not this
  physical reverse connection; fixture pause/resume simulates offline conflicts.
  These environmental checks are pending, not passed.
