---
type: Work Item
title: Contact ObjectBox Admin
parent: ../spec.md
---

## What to build

Add the independent Contact ObjectBox Admin vertical slice: entity-specific display, table, case-insensitive search, create state, edit/save/cancel behavior, selection after persistence, and confirmed permanent deletion. Contacts remain independent address-book records and must not appear in any other app domain.

## Required context

- `01-objectbox-entity-foundation.md` provides the generated `Contact` entity and repository seam.
- `lib/services/objectbox_admin_repository.dart`, `lib/screens/objectbox_admin_screen.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/screens/objectbox_admin_screen_table.dart`, and `lib/screens/objectbox_admin_screen_controls.dart` define the existing entity-specific Admin seams.
- Extend the existing ObjectBox Admin robot and journey harness with stable Contact selectors; use the injected repository seam so the journey is deterministic.

## Acceptance criteria

- [x] ObjectBox Admin displays the collection as `Contacts` and shows `Add Contact` only while Contacts is selected.
- [x] `Add Contact` opens a blank Contact in edit mode titled `New Contact` only until the record is valid; cancelling discards unsaved changes.
- [x] All Contact text inputs are trimmed. Save requires at least one non-empty `firstName`, `surname`, or `nickname`; blank records do not persist; and duplicate names and nicknames remain valid.
- [x] Saving persists the Contact with its generated ID and selects the persisted row.
- [x] The display name is the trimmed `{firstName} {surname}` with blank parts omitted, falling back to the non-empty nickname only when both name parts are blank.
- [x] The table shows distinct `firstName`, `surname`, and `nickname` columns, searches case-insensitively across exactly those fields, and retains ID-based ascending and descending sort behavior.
- [x] Contact deletion uses a confirmed ObjectBox Admin delete action and permanently removes the selected Contact.
- [x] Focused repository/widget/robot coverage verifies validation, cancellation, edit/save selection, composed display, exact search fields, sorting, and confirmed deletion using stable selectors.
- [x] Run the ObjectBox schema guard, targeted Contact repository/widget/robot tests, `flutter analyze`, and the full `flutter test` suite.

## Covers

- User Stories: 3
- Requirements: 3, 18-20
- Technical Decisions: 5-6
- Testing Strategy: 3, 5-6
- Interview Ledger: L9-L11

## Blocked by

- `01-objectbox-entity-foundation.md`
