---
type: Work Item
title: ObjectBox Admin Resolve Duplicate Flow
parent: ../spec.md
---

## What to build
Add the explicit ObjectBox Admin `Resolve Duplicate...` peak action and Flutter flow that lets an admin choose a surviving peak, review the exact confirmation copy, run the duplicate-resolution mutation, and receive distinct success or failure handling while ordinary `Delete` remains unchanged.

## Required context
- `lib/screens/objectbox_admin_screen.dart`, `lib/screens/objectbox_admin_screen_details.dart`, and the related admin table/details widgets already contain the existing peak actions, dialogs, create/edit form states, and selection refresh behavior. Extend those surfaces instead of adding a new route.
- Existing ordinary delete copy and blocked-delete behavior must remain intact. The new flow is a separate admin action, not a replacement for current delete prompts.
- Reuse current admin dialog helpers and provider-backed refresh patterns where possible. The spec requires exact confirmation wording shape: `Move references to <surviving peak> and delete <duplicate peak>?`.
- Existing widget and admin browser tests in `test/widget/objectbox_admin_shell_test.dart` and `test/widget/objectbox_admin_browser_test.dart` already cover peak action affordances and should be extended with deterministic provider overrides rather than replaced.
- Stable selectors already exist throughout ObjectBox Admin. Add new selectors only for the duplicate-resolution controls the new widget coverage needs.

## Acceptance criteria
- [ ] ObjectBox Admin exposes a `Resolve Duplicate...` action for `Peak` records as a separate action from ordinary `Delete`, within the existing admin route and peak-maintenance surface.
- [ ] The flow starts from the duplicate peak, allows the admin to choose one `Surviving peak`, and requires an explicit confirmation step before mutation.
- [ ] The confirmation dialog states the result in this exact shape: `Move references to <surviving peak> and delete <duplicate peak>?`.
- [ ] Ordinary peak `Delete` remains available for true deletion and retains the current dependency-blocked behavior when references exist.
- [ ] The Flutter flow exposes an in-progress or concurrent-action state that prevents double submission while duplicate resolution is running.
- [ ] If the app can detect an already-broken orphaned-reference case with exactly one unambiguous surviving peak candidate, the flow may prefill that candidate but still requires explicit admin confirmation before mutation.
- [ ] On failure, the UI leaves both peaks untouched, keeps them inspectable in ObjectBox Admin, and shows descriptive failure feedback naming the blocking dependency types and, when practical, affected records.
- [ ] Widget coverage proves the separate action affordance, surviving-peak selection, confirmation copy, in-progress protection, and failure feedback using fake repositories and deterministic provider overrides.

## Covers
- User Stories: 1-3
- Requirements: 2-4, 7-10, 12, 14
- Technical Decisions: 1-5
- Testing Strategy: 3
- Interview Ledger: L3-L6

## Blocked by
- `01-peak-duplicate-resolution-engine.md`
