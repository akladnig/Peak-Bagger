# ObjectBox Peak Admin updates
## Goal
Updates ObjectBox Admin, Peak Entity Admin to include additional fields and UI updates.

## Files to examine
ai_specs/06-objectbox-peak-admin-spec.md
ai_specs/06-objectbox-peak-admin-plan.md

Not to be confused with the "Peak Lists" screen or dialogs within.

- Add a new field to Peak entity named "Verified" which is editable by the user. It should be shown as a checkbox with a default of false (i.e. unticked). Note: User will set this to checked if peak name, height and location have been verified.
- When the users starts to edit any of the mgsrs fields (mgrs100kId, easting, or northing) clear the lat/long fields and recalculate lat/long once all the save or Recalculate button is pressed.
- When the users starts to edit any of the lat/long fields clear the mgsrs fields (mgrs100kId, easting, or northing) and recalculate the mgrs fields once the save or Recalculate button is pressed.
- Add a new field named "Alt Name" to be inserted to the right of "Name" which is used to identify any alternate names for the peak. This is an empty string by default.
- Add a new button above the save button named "Recalculate" to recalculate the missing location field values.
- double click in the text field selects all text in text field
- add x at the right hand side of the text field to clear it
